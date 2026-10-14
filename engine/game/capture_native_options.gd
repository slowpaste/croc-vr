extends SceneTree
const Menu=preload("res://source_main_menu.gd")
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world)
	await process_frame;world.set_process(false);world.set_physics_process(false)
	world.vr_settings.settings_path="user://native-menu-capture.cfg"
	assert(world.enter_source_title_options())
	world.source_options_state.navigation=Menu.initialize(0,3)
	assert(world.process_source_options(0,0x800000))
	var args:=OS.get_cmdline_user_args();var content:=str(args[args.find("--content")+1])
	for page in [2,21,22]:
		world.source_options_state.page=page;world.source_options_state.navigation=Menu.initialize(0,4 if page==21 else 3 if page==2 else 2)
		assert(world.process_source_options(0,0))
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		assert(world.source_options_screen.panel.output_texture().get_image().save_png(content.get_base_dir().path_join("build/native-options-%d.png"%page))==OK)
	print("PASS: native controller, camera and display menu pages rendered")
	world.queue_free()
	for frame in range(4):await process_frame
	quit(0)
