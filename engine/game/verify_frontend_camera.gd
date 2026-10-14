extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate();root.add_child(world)
	for frame in range(60):await physics_frame
	world.set_process(false);world.set_physics_process(false)
	assert(is_instance_valid(world.source_player_actor) and world.source_player_actor.source_name == "TitleCamera")
	world.update_camera()
	var pose = world.source_player_actor
	assert(world.camera.global_position.y >= pose.global_position.y+1.5)
	var values: Array = preload("res://source_cutscene_view.gd").matrix(pose.source_angles,world.runtime_tables.rotation.pairs)
	var native_view := Basis(Vector3(values[0],values[3],values[6])/4096.0,Vector3(values[1],values[4],values[7])/4096.0,Vector3(values[2],values[5],values[8])/4096.0)
	var point := Vector3(1.0,2.0,3.0)
	var native_point := native_view*point
	var godot_point: Vector3 = world.camera.global_basis.inverse()*point
	assert(world.camera.global_basis.is_equal_approx(Basis.from_euler(Vector3(pose.source_angles)*TAU/4096.0)))
	world.xr_active=true;world.head.current=true
	world.update_camera()
	if is_instance_valid(world.source_main_menu_text):world.source_main_menu_text.reparent(world.head,false)
	for logo in world.source_title_logo_nodes:logo.reparent(world.head,false)
	for effect in world.source_title_effect_nodes:
		effect.reparent(world.head,false);effect.configure_vr_panel(true)
	world.source_title_logo_state.positions=[Vector3i(0,-175,1800),Vector3i(0,-175,1800)]
	assert(world.refresh_source_title_logo())
	assert(world.refresh_source_main_menu_text())
	var placement:Transform3D=preload("res://source_title_logo.gd").vr_effect_transform(world.source_title_logo_nodes)
	for effect in world.source_title_effect_nodes:effect.transform=placement
	for frame in range(40):assert(world.refresh_source_title_effects())
	var subtitle=world.source_title_effect_nodes[0]
	var subtitle_bounds:AABB=subtitle.mesh.get_aabb()
	var subtitle_left:float=subtitle.position.x+subtitle_bounds.position.x*subtitle.scale.x
	var subtitle_bottom:float=subtitle.position.y+subtitle_bounds.position.y*subtitle.scale.y
	var c_logo=world.source_title_logo_nodes[0]
	var c_bounds:AABB=c_logo.mesh.get_aabb()
	assert(absf(subtitle_left-(c_logo.position.x+c_bounds.end.x))<0.06)
	assert(absf(subtitle_bottom-(c_logo.position.y+c_bounds.position.y))<0.04)
	# Original title sprites: source x210..466, y130..146; 512x240 at 4:3.
	assert(absf(subtitle.scale.x/subtitle.scale.y-4.0/3.0)<0.08)
	assert(subtitle_left>c_logo.position.x+c_bounds.end.x)
	assert(subtitle.transform.is_equal_approx(placement))
	var menu_top: float = world.source_main_menu_text.position.y+world.source_main_menu_text.mesh.get_aabb().end.y*world.source_main_menu_text.scale.y
	for logo in world.source_title_logo_nodes:
		assert(is_equal_approx(logo.position.z,-4))
		assert(logo.position.y+logo.mesh.get_aabb().position.y > menu_top)
	world.head.position.y=1.6;world.update_camera()
	var head_y: float=world.head.global_position.y
	assert(head_y>=pose.global_position.y+1.2)
	world.head.position.y=1.8;world.update_camera()
	assert(is_equal_approx(world.head.global_position.y-head_y,0.2))
	if OS.get_cmdline_user_args().has("--no-capture"):
		print("PASS: title floor clearance, physical head motion, authored camera and separated menu/logo")
		world.queue_free();await process_frame;quit(0);return
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var content := str(args[args.find("--content")+1])
	root.get_texture().get_image().save_png(content.get_base_dir().path_join("build/frame-title-layout.png"))
	print("PASS: authored title camera projection/orientation, common four-metre depth and separated logo/menu bounds")
	world.queue_free();await process_frame;quit(0)
