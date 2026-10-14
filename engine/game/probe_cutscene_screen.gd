extends Node3D
# A scene entry point works in release templates, which do not accept --script.
var report := {"phase":"starting","fault":"","complete":false}
func capture_playback_id(stream: Node) -> int:
	return stream.playback.get_instance_id()
func write_report() -> void:
	var file := FileAccess.open("user://cutscene-screen-check.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
func fail(message: String) -> void:
	report.fault = message; write_report(); get_tree().quit(1)
func _ready() -> void:
	write_report()
	call_deferred("verify_renderer_only" if OS.get_cmdline_user_args().has("--renderer-only") else "verify")
func verify_renderer_only() -> void:
	for frame in range(3): await get_tree().process_frame
	report.phase = "renderer-only-finished"; report.complete = true
	report.renderer = RenderingServer.get_video_adapter_name(); write_report()
	get_tree().quit(0)
func verify() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): fail("Missing content path"); return
	var content := str(args[option+1])
	option = args.find("--scene")
	var scene_id := int(args[option+1]) if option >= 0 and option+1 < args.size() else 20
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var viewer := Camera3D.new(); add_child(viewer); viewer.position = Vector3(1,1.6,2)
	var display: Node3D = preload("res://source_cutscene_screen.gd").new() if scene_id == 20 else preload("res://source_sequence_screen.gd").new()
	add_child(display)
	var cd_state := {"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":true,"prefill":0,"phase_us":6667}
	var configured: bool = display.setup_sad(content,manifest,tables,cd_state,viewer) if scene_id == 20 else display.setup(content,manifest,tables,scene_id,cd_state,viewer)
	if not configured:
		if scene_id != 20 and not display.session.config.has("fault"):
			report.cache_components = preload("res://source_sequence_cache_identity.gd").components(display.session.config,tables)
			report.cache_components_full = preload("res://source_sequence_cache_identity.gd").components(display.session.config,tables,true)
			report.cache_expected = preload("res://source_sequence_cache_identity.gd").fingerprint(display.session.config,tables)
			report.room_texts = {}
			for index in [8,9]:
				if index < display.session.config.parts.size(): report.room_texts[str(index)] = JSON.stringify(display.session.config.parts[index].room)
		fail("Screen setup failed: "+display.session.fault); return
	var anchor := display.global_transform
	viewer.position += Vector3(0.3,0.1,-0.2); viewer.rotation.y += 0.8
	report.phase = "playing"; report.renderer = RenderingServer.get_video_adapter_name(); write_report()
	var playback_id := 0
	var samples: Array = []
	var expected_frames: int = display.session.player.frames.size()
	var started_us := Time.get_ticks_usec(); var cpu_max_us := 0
	for index in range(expected_frames):
		var before_us := Time.get_ticks_usec()
		var result: Dictionary = display.advance(33334,0,1)
		cpu_max_us = maxi(cpu_max_us,Time.get_ticks_usec()-before_us)
		if result.has("fault"): fail(str(result.fault)); return
		if display.global_transform != anchor: fail("Screen moved with viewer"); return
		if display.session.audio.started and playback_id == 0:
			playback_id = capture_playback_id(display.session.audio.stream)
		if index == 5:
			display.set_paused(true)
			var paused: Dictionary = display.advance(1000000,0,1)
			if not paused.get("paused",false): fail("Pause did not hold timeline"); return
			display.set_paused(false)
		await get_tree().process_frame
		if index%120 == 0:
			report.presented_index = int(display.session.player.last_index)
			if scene_id != 20:
				report.loaded_frames = display.session.loaded_frames.size()
				report.retained_stages = 0
				for graph in display.session.graph_cache.values(): report.retained_stages += graph.stages.size()
			report.elapsed_us = Time.get_ticks_usec()-started_us; report.cpu_max_us = cpu_max_us
			write_report()
		if index in [20,100,200,expected_frames-2]:
			await RenderingServer.frame_post_draw
			var image: Image = display.session.compositor.output.get_texture().get_image()
			if image == null or image.is_empty(): fail("Empty compositor output"); return
			var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data())
			samples.append({"index":index,"sha256":hash.finish().hex_encode()})
			if index == 20:
				for y in range(image.get_height()):
					for x in range(image.get_width()): image.set_pixel(x,y,image.get_pixel(x,y).linear_to_srgb())
				if image.save_png("user://cutscene-screen-check.png") != OK: fail("Capture failed"); return
	if display.session.player.last_index != expected_frames-1 or not display.session.complete: fail("Incomplete cutscene"); return
	if playback_id == 0: fail("Sequence audio never started"); return
	display.queue_free(); viewer.queue_free(); await get_tree().process_frame
	# Allow queued GPU resource retirement before shutting down the native renderer.
	await get_tree().create_timer(0.25).timeout
	var deadline := Time.get_ticks_msec()+2000
	while is_instance_id_valid(playback_id) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if is_instance_id_valid(playback_id): fail("Audio playback did not retire"); return
	report.phase = "finished"; report.complete = true; report.scene_id = scene_id; report.frames = expected_frames; report.samples = samples
	report.presented_index = expected_frames-1
	report.elapsed_us = Time.get_ticks_usec()-started_us; report.cpu_max_us = cpu_max_us
	write_report(); get_tree().quit(0)
