extends SceneTree
const Worker = preload("res://source_xa_worker.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[0]
	var reader := preload("res://source_xa_channel_reader.gd").new()
	reader.open_channel(content,record)
	reader.seek_sector(int(record.sourceLba),[[0,0],[0,0]])
	var filter := preload("res://source_xa_zigzag.gd").new()
	var worker := Worker.new()
	if worker.start(content,record,int(record.sourceLba),[[0,0],[0,0]],filter.snapshot()) != OK: quit(1); return
	var count := 0
	var deadline := Time.get_ticks_msec()+5000
	while count < 10 and Time.get_ticks_msec() < deadline:
		if worker.queued() > Worker.CAPACITY: push_error("XA worker exceeded queue bound"); quit(1); return
		var packet := worker.take()
		if packet.is_empty(): await process_frame; continue
		var source := reader.read_sector()
		var expected := filter.process_pcm(source.pcm,int(source.rate))
		if packet.has("fault") or packet.pcm != expected.pcm or packet.source_sector != source.source_sector or packet.predictor_history != reader.history_snapshot() or packet.interpolation_state != filter.snapshot():
			push_error("Threaded XA output/order differs from synchronous source")
			worker.stop()
			quit(1)
			return
		count += 1
	await create_timer(0.1).timeout # Allow producer to block on its full queue.
	if count != 10 or worker.queued() != Worker.CAPACITY: worker.stop(); quit(1); return
	var old_thread := worker.thread.get_instance_id()
	var old_queue: Array = worker.snapshot_packets()
	if worker.start(content,record,int(record.sourceLba),[[0,0],null],filter.snapshot()) != ERR_INVALID_PARAMETER or worker.thread.get_instance_id() != old_thread or worker.snapshot_packets() != old_queue:
		push_error("Invalid history restart destroyed the existing full XA worker queue")
		worker.stop()
		quit(1)
		return
	var invalid_filter := filter.snapshot()
	invalid_filter.sixstep = 0
	if worker.start(content,record,int(record.sourceLba),[[0,0],[0,0]],invalid_filter) != ERR_INVALID_PARAMETER or worker.thread.get_instance_id() != old_thread or worker.snapshot_packets() != old_queue:
		push_error("Invalid filter restart destroyed the existing XA worker")
		worker.stop()
		quit(1)
		return
	worker.stop()
	if worker.thread != null or worker.queued() != 0: quit(1); return
	var last := int(record.sourceLba)+int(record.firstSector)+(int(record.sectors)-1)*8
	worker.start(content,record,last,[[0,0],[0,0]])
	var terminal_packets: Array[Dictionary] = []
	deadline = Time.get_ticks_msec()+2000
	while terminal_packets.size() < 2 and Time.get_ticks_msec() < deadline:
		var packet := worker.take()
		if not packet.is_empty(): terminal_packets.append(packet)
		else: await process_frame
	if terminal_packets.size() != 2 or terminal_packets[0].get("source_sector",-1) != last or not bool(terminal_packets[1].get("end",false)):
		push_error("Threaded XA end packet did not follow final audio sector")
		worker.stop()
		quit(1)
		return
	worker.stop()
	var missing := record.duplicate(true)
	missing.compressedFile = "music/missing-probe.sectors"
	worker.start(content,missing,last,[[0,0],[0,0]])
	deadline = Time.get_ticks_msec()+2000
	var fault: Dictionary = {}
	while fault.is_empty() and Time.get_ticks_msec() < deadline:
		fault = worker.take()
		if fault.is_empty(): await process_frame
	worker.stop()
	if not fault.has("fault"): push_error("Worker source error was not delivered"); quit(1); return
	reader.close_channel()
	reader = null
	filter = null
	worker = null
	print("PASS: threaded XA PCM/order, bounded queue and full-queue shutdown/join")
	quit(0)
