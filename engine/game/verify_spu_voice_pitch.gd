extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var wav := AudioStreamWAV.load_from_file(content.path_join("audio/0279-MP033_02.WAD-311512.wav"))
	var player = preload("res://source_spu_voice_player.gd").new();root.add_child(player)
	if not player.start_pcm(wav,1000,1000,true) or not player.set_source_pitch(2048):quit(1);return
	var start := Time.get_ticks_usec()
	await create_timer(0.1).timeout
	var identity: int = player.generator_playback.get_instance_id()
	if not player.set_source_pitch(0):quit(1);return
	await create_timer(0.05).timeout
	var cursor: int = player.cursor;var position: float = player.get_playback_position()
	await create_timer(0.1).timeout
	if player.cursor!=cursor or not is_equal_approx(player.get_playback_position(),position) or player.generator_playback.get_instance_id()!=identity:push_error("Pitch0 advanced or restarted source voice");quit(1);return
	if not player.set_source_pitch(2048) or not is_equal_approx(player.pitch_scale,0.5):quit(1);return
	while not player.completed and Time.get_ticks_usec()-start<3000000:await create_timer(0.005).timeout
	var active := float(Time.get_ticks_usec()-start)/1000000.0-0.15
	var expected := float(wav.data.size()/2)/22050.0
	if not player.completed or absf(active-expected)>0.2:push_error("Generator source pitch duration mismatch: "+str(active)+" expected="+str(expected));quit(1);return
	player.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: streaming SPU pitch2048 playback duration and pitch0 cursor-preserving pause/resume")
	quit(0)
