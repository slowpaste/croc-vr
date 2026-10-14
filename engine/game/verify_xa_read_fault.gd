extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[0].duplicate(true)
	var source := FileAccess.open(content.path_join(record.compressedFile),FileAccess.READ)
	var raw := source.get_buffer(2352)
	var valid := source.get_buffer(2352)
	source = null
	raw[152] ^= 1 # Second group parameter copy; first group already decodes.
	var filename := "xa-read-fault-%d.sectors"%Time.get_ticks_usec()
	var target := "user://"+filename
	if FileAccess.file_exists(target): quit(1); return
	var output := FileAccess.open(target,FileAccess.WRITE)
	output.store_buffer(raw)
	output.store_buffer(valid)
	output = null
	record.compressedFile = filename
	record.sectors = 2
	var reader := preload("res://source_xa_channel_reader.gd").new()
	var history := [[1,2],[3,4]]
	if not reader.open_channel("user://",record) or reader.seek_sector(int(record.sourceLba),history).has("fault"): quit(1); return
	var result := reader.read_sector()
	if not result.has("fault") or reader.sector_index != 0 or reader.file.get_position() != 0 or reader.history_snapshot() != history:
		push_error("Late XA sector error changed reader position or predictor history")
		quit(1)
		return
	if reader.read_sector() != result or reader.file.get_position() != 0: quit(1); return
	var first := int(record.sourceLba)+int(record.firstSector)
	if not reader.seek_sector(first+16,history).has("fault") or reader.read_sector() != result or reader.sector_index != 0: quit(1); return
	if reader.seek_sector(first+8,[[0,0],[0,0]]).has("fault"): quit(1); return
	var recovered := reader.read_sector()
	var expected := preload("res://source_xa_decoder.gd").new().decode(valid)
	if recovered.has("fault") or recovered.pcm != expected.pcm or recovered.source_sector != first+8:
		push_error("Accepted source seek did not clear fault and recover valid PCM")
		quit(1)
		return
	reader.close_channel()
	var worker := preload("res://source_xa_worker.gd").new()
	worker.start("user://",record,int(record.sourceLba),history)
	var deadline := Time.get_ticks_msec()+2000
	var packet: Dictionary = {}
	while packet.is_empty() and Time.get_ticks_msec() < deadline:
		packet = worker.take()
		if packet.is_empty(): await process_frame
	worker.stop()
	if not packet.has("fault"): quit(1); return
	worker.start("user://",record,first+8,[[0,0],[0,0]])
	deadline = Time.get_ticks_msec()+2000
	packet = {}
	while packet.is_empty() and Time.get_ticks_msec() < deadline:
		packet = worker.take()
		if packet.is_empty(): await process_frame
	worker.stop()
	if packet.has("fault") or packet.get("pcm",PackedByteArray()) != expected.pcm: quit(1); return
	worker = null
	reader = null
	var player := preload("res://source_xa_stream_player.gd").new()
	root.add_child(player)
	if not player.start_stream("user://",record,first,history,{},true): quit(1); return
	await create_timer(0.05).timeout
	result = player.pump(1)
	if not result.has("fault") or player.pump(1) != result:
		push_error("Worker decoder error disappeared from subsequent stream pumps")
		quit(1)
		return
	if player.seek_stream(first+8,[[0,0],[0,0]]).has("fault"): quit(1); return
	await create_timer(0.05).timeout
	result = player.pump(1)
	if result.has("fault") or result.pushed_frames != 2016 or not player.stream_fault.is_empty(): quit(1); return
	player.stop_stream()
	await create_timer(0.1).timeout
	player.queue_free()
	await process_frame
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) != OK: quit(1); return
	print("PASS: late XA read failure rollback/sticky fault, worker delivery/shutdown and temporary fixture cleanup")
	quit(0)
