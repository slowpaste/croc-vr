extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var wav := AudioStreamWAV.load_from_file(content.path_join("audio/0279-MP033_02.WAD-311512.wav"))
	var voice = preload("res://source_spu_voice_node.gd").new();root.add_child(voice)
	voice.position = Vector3(1,2,3)
	var completions: Array = [];voice.finished.connect(func():completions.append(true))
	if not voice.start_voice(wav,250,-250,4096):quit(1);return
	var start := Time.get_ticks_usec()
	while completions.is_empty() and Time.get_ticks_usec()-start < 2000000:await create_timer(0.005).timeout
	if completions.size()!=1 or voice.position!=Vector3(1,2,3) or voice.player.generator_playback!=null:quit(1);return
	if not voice.start_voice(wav,1000,1000,0):quit(1);return
	await create_timer(0.05).timeout
	if voice.player.cursor!=0 or not voice.player.zero_pitch:quit(1);return
	root.remove_child(voice)
	if voice.player.generator_playback!=null or voice.player.stream!=null:push_error("Positioned voice scene exit leaked playback");quit(1);return
	voice.free();await process_frame;await create_timer(0.1).timeout
	print("PASS: positioned streaming voice forwards completion, pitch0 and scene teardown")
	quit(0)
