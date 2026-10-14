extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): quit(1); return
	var content := str(args[option+1])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = index.streams[0]
	var filter := preload("res://source_xa_zigzag.gd").new()
	var state := filter.snapshot()
	var player := preload("res://source_xa_stream_player.gd").new()
	root.add_child(player)
	player.set_cd_mix([128,128,0,0])
	if not player.start_stream(content,record,int(record.sourceLba),[[0,0],[0,0]],state,true): quit(1); return
	await create_timer(0.05).timeout
	var result := player.pump(1)
	if result.has("fault") or result.pushed_frames != 2352 or player.worker.queued() > 3: quit(1); return
	var old_worker := player.worker.get_instance_id()
	var old_frames := player.queued_frames
	var old_playback := player.playback.get_instance_id()
	if player.start_stream(content,record,int(record.sourceLba),[[0,0],null],state,true) or player.worker.get_instance_id() != old_worker or player.playback.get_instance_id() != old_playback or player.queued_frames != old_frames:
		push_error("Invalid predictor start stopped existing threaded playback")
		quit(1)
		return
	var invalid_state := state.duplicate(true)
	invalid_state.position = 32
	if player.start_stream(content,record,int(record.sourceLba),[[0,0],[0,0]],invalid_state,true) or player.worker.get_instance_id() != old_worker or player.playback.get_instance_id() != old_playback or player.queued_frames != old_frames:
		push_error("Invalid filter start stopped existing playback")
		quit(1)
		return
	if not player.seek_stream(int(record.sourceLba),[[0,0],[0,0]]).has("fault") or player.worker.get_instance_id() != old_worker or player.queued_frames != old_frames:
		push_error("Rejected threaded seek changed playback")
		quit(1)
		return
	var first := int(record.sourceLba)+int(record.firstSector)
	var mapped := player.seek_stream(first+8,[[0,0],[0,0]],state)
	if mapped.has("fault") or player.pending.size() != 0 or player.queued_frames != 0: quit(1); return
	await create_timer(0.05).timeout
	result = player.pump(1)
	var reader := preload("res://source_xa_channel_reader.gd").new()
	reader.open_channel(content,record)
	reader.seek_sector(first+8,[[0,0],[0,0]])
	var source := reader.read_sector()
	var expected: PackedByteArray = filter.process_pcm(source.pcm,37800).pcm
	if result.has("fault") or result.pushed_frames != 2352: quit(1); return
	for frame in range(player.pending.size()):
		if player.pending[frame] != Vector2(expected.decode_s16(frame*4),expected.decode_s16(frame*4+2))/32768.0:
			push_error("Threaded seek submitted stale/pre-seek audio")
			quit(1)
			return
	reader.close_channel()
	reader = null
	filter = null
	player.stop_stream()
	if player.worker != null or player.playback != null or player.reader.file != null: quit(1); return
	await create_timer(0.1).timeout
	player.queue_free()
	await process_frame
	print("PASS: threaded audio submission, bounded queue, explicit-state seek, stale PCM rejection and shutdown")
	quit(0)
