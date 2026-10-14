extends SceneTree
func playback_released(reference: WeakRef) -> bool:
	# Keep the temporary strong result of get_ref outside any awaited frame.
	return reference.get_ref() == null
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var player := preload("res://source_cutscene_audio_player.gd").new()
	root.add_child(player)
	assert(player.configure(content,manifest.cutsceneAudio[0],[128,128,0,0],[[0,0],[0,0]],{},false))
	assert(not player.configure(content,manifest.cutsceneAudio[0],[0,0,0,0],[[0,0],[0,0]],{"invalid":true},false) and player.stream.cd_mix == [128,128,0,0])
	assert(player.receive({"paused":false,"complete":false,"audio_frames":0}).waiting and not player.started)
	var begun: Dictionary = player.receive({"paused":false,"complete":false,"audio_frames":2016})
	assert(not begun.has("fault") and player.started and player.stream.queued_frames > 0)
	var playback_reference: WeakRef = weakref(player.stream.playback)
	var queued: int = player.stream.queued_frames
	assert(player.receive({"paused":true,"complete":false,"audio_frames":2016}).paused and player.stream.stream_paused and player.stream.queued_frames == queued)
	assert(not player.receive({"paused":false,"complete":false,"audio_frames":4032}).has("fault") and not player.stream.stream_paused)
	assert(player.receive({"paused":false,"complete":true,"audio_frames":4032}).stopped and not player.started and player.stream.playback == null)
	assert(player.receive({"paused":false,"complete":false,"audio_frames":4032}).stopped)
	await create_timer(0.1).timeout
	player.queue_free(); await process_frame
	var deadline := Time.get_ticks_msec()+1000
	while not playback_released(playback_reference) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		await process_frame
	if not playback_released(playback_reference):
		push_error("Stopped cutscene audio playback was not released within one second")
		quit(1)
		return
	print("PASS: original SAD audio waits for sector8, starts with explicit mix/history, pauses and stops without restart")
	quit(0)
