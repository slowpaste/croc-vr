extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var wav := AudioStreamWAV.load_from_file(content.path_join("audio/0279-MP033_02.WAD-311512.wav"))
	var player = preload("res://source_spu_voice_player.gd").new();root.add_child(player)
	var events: Array = [];player.pcm_completed.connect(func():events.append(true))
	var start := Time.get_ticks_usec()
	if not player.start_pcm(wav,250,-250,true):quit(1);return
	while not player.completed and Time.get_ticks_usec()-start < 3000000:
		await create_timer(0.005).timeout
	var elapsed := float(Time.get_ticks_usec()-start)/1000000.0
	var duration := float(wav.data.size()/2)/float(wav.mix_rate)
	if not player.completed or events.size()!=1 or player.submitted!=int(wav.data.size()/2) or player.generator_playback!=null or elapsed<duration-0.1 or elapsed>duration+0.6:
		push_error("Streaming voice completion mismatch: "+str({"elapsed":elapsed,"duration":duration,"submitted":player.submitted,"events":events.size()}));quit(1);return
	player.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: complete decoded one-shot auto-pumps, drains and signals completion once")
	quit(0)
