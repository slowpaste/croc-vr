extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0:quit(1);return
	var content := str(args[option+1])
	var wav := AudioStreamWAV.load_from_file(content.path_join("audio/0279-MP033_02.WAD-311512.wav"))
	var player = preload("res://source_spu_voice_player.gd").new();root.add_child(player)
	if not player.start_pcm(wav,250,-250):quit(1);return
	var amount: int = player.pump(512)
	if amount<=0 or player.cursor!=amount or player.last_submitted.size()!=amount:quit(1);return
	var expected := preload("res://source_spu_voice_mix.gd").mono16_block(wav.data,0,amount,250,-250)
	if player.last_submitted!=expected.frames:push_error("Signed stereo frames changed before generator submission");quit(1);return
	var old_cursor: int = player.cursor;var old_playback: int = player.generator_playback.get_instance_id()
	player.set_channels(0,0)
	if player.cursor!=old_cursor or player.generator_playback.get_instance_id()!=old_playback:quit(1);return
	amount = player.pump(512)
	if amount<=0:quit(1);return
	for frame in player.last_submitted:
		if frame!=Vector2.ZERO:quit(1);return
	player.stop_pcm()
	if player.generator_playback!=null or player.stream!=null or not player.pcm.is_empty():quit(1);return
	player.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: actual decoded sound submits signed stereo/mute frames without restarting channel updates")
	quit(0)
