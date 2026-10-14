extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("music/index.json")))
	var record: Dictionary = catalog.streams[0]
	var retired: Array[WeakRef] = []
	for index in range(16):
		var player = preload("res://source_xa_stream_player.gd").new();root.add_child(player)
		if not player.start_stream(content,record,int(record.sourceLba),[[0,0],[0,0]],{},index%2 == 0):quit(1);return
		retired.append(weakref(player.playback));retired.append(weakref(player.stream))
		player.pump(1)
		if index%2 == 1:
			if player.seek_stream(int(record.sourceLba),[[0,0],[0,0]]).has("fault"):push_error("XA retirement seek failed");quit(1);return
			retired.append(weakref(player.playback))
		await create_timer(0.01).timeout
		player.stream_paused = index%3 == 0
		player.stop_stream();player.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("XA retirement queue did not drain");quit(1);return
	var deadline := Time.get_ticks_msec()+2000
	while retired.any(func(reference):return reference.get_ref()!=null) and Time.get_ticks_msec()<deadline:await process_frame
	if retired.any(func(reference):return reference.get_ref()!=null):push_error("XA generators or playbacks remained alive after removal");quit(1);return
	print("PASS:16 XA stops and8 seeks release generators/playbacks for threaded and synchronous decoding, including paused streams")
	quit(0)
