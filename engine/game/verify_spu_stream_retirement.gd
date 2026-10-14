extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1);return
	var wav := AudioStreamWAV.load_from_file(str(args[option+1]).path_join("audio/0279-MP033_02.WAD-311512.wav"))
	var references: Array[WeakRef] = []
	for room_index in range(16):
		var room := Node3D.new();root.add_child(room)
		var voice = preload("res://source_spu_voice_node.gd").new();room.add_child(voice)
		for replacement in range(2):
			if not voice.start_voice(wav,1000,-1000,0 if room_index%2 == 0 else 2048): quit(1);return
			references.append(weakref(voice.player.stream))
			references.append(weakref(voice.player.generator_playback))
		paused = room_index%3 == 0
		room.queue_free();await process_frame
	paused = false
	var retirement := root.get_node("SourceSpuStreamRetirement")
	var deadline := Time.get_ticks_msec()+2000
	while not retirement.pending.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not retirement.pending.is_empty(): push_error("Removed rooms retained generator playbacks");quit(1);return
	for reference in references:
		if reference.get_ref() != null: push_error("Retired generator or playback remained alive");quit(1);return
	print("PASS: 32 replaced voices across16 removed rooms release generators and playbacks, including pitch0 and paused scene exit")
	quit(0)
