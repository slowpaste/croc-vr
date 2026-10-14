extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("audio/0153-MP010_03.WAD-76104.json")))
	var wav := AudioStreamWAV.load_from_file(content.path_join(info.file))
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD;wav.loop_begin = int(info.loopBegin);wav.loop_end = int(info.loopEnd)
	var player = preload("res://source_spu_voice_player.gd").new();root.add_child(player)
	var events: Array = [];player.pcm_completed.connect(func():events.append(true))
	if not player.start_pcm(wav,1000,1000,true):quit(1);return
	var start := Time.get_ticks_usec()
	while player.loop_count < 3 and Time.get_ticks_usec()-start < 3000000:
		await create_timer(0.005).timeout
	var span := int(info.loopEnd)-int(info.loopBegin)
	if player.loop_count < 3 or player.completed or not events.is_empty() or player.submitted!=int(info.loopEnd)+(player.loop_count-1)*span+(player.cursor-int(info.loopBegin)):
		push_error("Actual looping sample lost boundary/cursor continuity");quit(1);return
	var old_playback: int = player.generator_playback.get_instance_id()
	var invalid := wav.duplicate() as AudioStreamWAV;invalid.loop_end = invalid.loop_begin
	if player.start_pcm(invalid,1,1,true) or player.generator_playback.get_instance_id()!=old_playback:quit(1);return
	player.stop_pcm()
	if player.looping or player.generator_playback!=null:quit(1);return
	if not player.start_pcm(wav,1000,-1000,true):quit(1);return
	await create_timer(0.05).timeout
	root.remove_child(player)
	if player.generator_playback!=null or player.stream!=null or not player.pcm.is_empty() or player.automatic:
		push_error("Scene exit retained a streaming loop");quit(1);return
	player.free();await process_frame;await create_timer(0.1).timeout
	print("PASS: actual MRFB decoded loop repeats from sample280 with continuous cursor and explicit stop")
	quit(0)
