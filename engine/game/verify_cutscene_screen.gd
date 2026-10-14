extends SceneTree
func capture_playback_id(stream: Node) -> int: return stream.playback.get_instance_id()
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var viewer := Camera3D.new()
	root.add_child(viewer)
	viewer.position = Vector3(1,1.6,2)
	viewer.rotation.y = 0.4
	var display := preload("res://source_cutscene_screen.gd").new()
	root.add_child(display)
	assert(display.setup_sad(content,manifest,tables,{"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667},viewer))
	var initial := display.global_transform
	assert(display.viewport.own_world_3d and not display.viewport.use_xr and display.viewport.size == Vector2i(512,240))
	assert(display.viewport.use_hdr_2d)
	assert(display.viewport.world_3d != root.world_3d)
	viewer.position += Vector3(0.3,0.1,-0.2)
	viewer.rotation.y += 0.8
	var head := viewer.global_transform
	assert(display.advance(33334,0).presented == [0])
	assert(display.global_transform == initial and viewer.global_transform == head)
	assert(not display.advance(20000,0).has("fault") and display.session.audio.started)
	var playback_id := capture_playback_id(display.session.audio.stream)
	display.set_paused(true)
	assert(display.advance(1000000,0).paused and display.session.player.last_index == 0)
	display.set_paused(false)
	var result := display.advance(10000000,0,64)
	for tick in range(400):
		if result.has("fault"): push_error(str(result.fault));quit(1);return
		if result.complete: break
		await process_frame
		result = display.advance(33334,0,64)
	if not result.get("complete",false): push_error("Cutscene screen did not finish bounded fast-forward");quit(1);return
	assert(display.session.player.last_index == 290 and display.global_transform == initial and viewer.global_transform == head)
	display.queue_free(); viewer.queue_free(); await process_frame
	await create_timer(0.1).timeout
	var deadline := Time.get_ticks_msec()+1000
	while is_instance_id_valid(playback_id) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10); await process_frame
	if is_instance_id_valid(playback_id): push_error("Screen audio playback did not retire"); quit(1); return
	print("PASS: isolated512x240 cutscene screen stays world anchored through head motion, pause and all291 source frames")
	quit(0)
