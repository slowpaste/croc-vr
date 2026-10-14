extends SceneTree
var world
var out := ""
var frame_number := 0
var pilot := false
func _initialize() -> void: call_deferred("capture")
func inputs(stick: Vector2, jump := false, attack := false) -> void:
	for action in ["move_left","move_right","move_forward","move_back","jump","attack"]: Input.action_release(action)
	if stick.x != 0: Input.action_press("move_right" if stick.x > 0 else "move_left", absf(stick.x))
	if stick.y != 0: Input.action_press("move_back" if stick.y > 0 else "move_forward", absf(stick.y))
	if jump: Input.action_press("jump")
	if attack: Input.action_press("attack")
func tick() -> void:
	world.sample_source_player_controls()
	world.tick_source_actors()
	world.actor.position = world.source_player_actor.position
	world.update_vr_camera_anchor(1.0/30.0)
	world.update_camera()
	# Trailer spectator framing keeps the feet and action readable in a flat shot.
	var focus: Vector3 = world.source_player_actor.position
	world.camera.position=focus+Vector3(0,1.8,3.5)
	world.camera.look_at(focus+Vector3(0,0.45,0))
func save_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(out.path_join("%04d.png"%frame_number))
	assert(err == OK)
	frame_number += 1
func fresh(map: String) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
	world = load("res://imported.tscn").instantiate()
	world.map_name = map
	root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	world.vr_controls.layout = "modern"
	world.source_music_volume = 0
	world.hud.hide()
	if is_instance_valid(world.source_gameplay_hud): world.source_gameplay_hud.hide()
	world.camera.fov = 57
	inputs(Vector2.ZERO)
	for i in range(30): tick()
	print("TRAILER_ROOM ",map," player ",world.source_player_actor.position)
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[args.find("--out")+1]
	pilot = args.has("--pilot")
	root.size = Vector2i(1280,720)
	if args.has("--controls-only"):
		frame_number=240
		await capture_controls()
		print("TRAILER_CONTROLS_COMPLETE ",frame_number)
		quit(0);return
	await fresh("MP010_00.MAP")
	# An orbit around the real protagonist: foreground, middle distance, scenery.
	var anchor: Vector3 = world.source_player_actor.position
	for i in range(90 if not pilot else 1):
		var angle := -0.6+float(i)/90.0*0.8
		world.camera.position = anchor+Vector3(sin(angle)*4.0,2.4,cos(angle)*4.0)
		world.camera.look_at(anchor+Vector3(0,0.6,0))
		await save_frame()
	world.hide()
	var viewer := Camera3D.new();root.add_child(viewer);viewer.current=true;viewer.fov=48
	var display = preload("res://source_sequence_screen.gd").new();root.add_child(display)
	assert(display.setup(world.content_root,world.manifest,world.runtime_tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667},viewer))
	display.session.audio.stream.stop_stream()
	print("TRAILER_CINEMATIC_PARTS ",display.session.cached_parts.map(func(p):return p.size()))
	if args.has("--cinematic-pilot"):
		viewer.position=Vector3(0,0,-1.3);viewer.look_at(Vector3(0,-0.35,-4))
		for part in range(14):
			assert(display.session.present_frame(part,display.session.cached_parts[part].size()/2))
			display.session.player.fade.level=0;display.apply_fade();await save_frame()
		quit(0);return
	for i in range(150 if not pilot else 1):
		# Portal stays anchored while the viewpoint leans independently.
		viewer.position = Vector3(sin(float(i)/150.0*TAU)*0.28,0.08*sin(float(i)/150.0*PI),-1.3)
		viewer.look_at(Vector3(0,-0.35,-4))
		assert(display.session.present_frame(2 if i<75 else 10,60+i if i<75 else 80+i-75))
		display.session.player.fade.level=0;display.apply_fade()
		await save_frame()
	display.queue_free();viewer.queue_free();await process_frame
	world.show();world.camera.current=true
	# Analog speed, deliberate lateral footwork, and a fast stick reversal.
	for section in range(3):
		await fresh("MP010_00.MAP")
		var count: int = [150,90,90][section]
		for i in range(count if not pilot else 1):
			var stick := Vector2(0,-lerpf(0.2,1.0,minf(float(i)/70.0,1.0))) if section==0 else Vector2(0.33 if i<45 else -0.33,0) if section==1 else Vector2(0,-1 if i<32 else 1)
			inputs(stick);tick()
			await save_frame()
		print("TRAILER_CONTROL ",section," end ",world.source_player_actor.position," clip ",world.source_player_actor.clip_name)
	# Original jump and tail attack driven through the new controller.
	await fresh("MP010_00.MAP")
	for i in range(120 if not pilot else 1):
		inputs(Vector2(0,-0.65) if i<88 else Vector2.ZERO,i in range(18,23) or i in range(65,70),i in range(95,101));tick()
		await save_frame()
	# A second environment gives the adventure room to breathe.
	await fresh("MP020_00.MAP")
	anchor=world.source_player_actor.position
	for i in range(90 if not pilot else 1):
		inputs(Vector2(0,-0.5));tick()
		await save_frame()
	# Final hero orbit, held for the title reveal.
	await fresh("MP010_00.MAP")
	anchor=world.source_player_actor.position
	for i in range(120 if not pilot else 1):
		world.camera.position=anchor+Vector3(3.5-sin(float(i)/120.0)*1.2,1.7,2.5)
		world.camera.look_at(anchor+Vector3(0,0.55,0));await save_frame()
	print("TRAILER_CAPTURE_COMPLETE ",frame_number)
	quit(0)
func capture_controls() -> void:
	for section in range(3):
		await fresh("MP010_00.MAP")
		var count: int = [150,90,90][section]
		for i in range(count):
			var stick := Vector2(0,-lerpf(0.2,1.0,minf(float(i)/70.0,1.0))) if section==0 else Vector2(0.33 if i<45 else -0.33,0) if section==1 else Vector2(0,-1 if i<32 else 1)
			inputs(stick);tick();await save_frame()
	await fresh("MP010_00.MAP")
	for i in range(120):
		inputs(Vector2(0,-0.65) if i<88 else Vector2.ZERO,i in range(18,23) or i in range(65,70),i in range(95,101));tick();await save_frame()
