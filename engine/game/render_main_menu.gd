extends SceneTree
func _initialize() -> void:
	call_deferred("render_probe")
func render_probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.enter_source_main_menu()
	for tick in range(59):
		world.source_title_logo_state = preload("res://source_title_logo.gd").advance(world.source_title_logo_state)
		if not world.refresh_source_title_effects():
			push_error(world.source_transition_fault)
			quit(1)
			return
	if not world.refresh_source_title_logo():
		push_error(world.source_transition_fault)
		quit(1)
		return
	world.advance_source_main_menu_navigation(0,0)
	if not world.refresh_source_main_menu_text():
		push_error(world.source_transition_fault)
		quit(1)
		return
	if world.source_main_menu_text.mesh.surface_get_array_len(0) != 276:
		push_error("Original five menu labels did not produce46 glyph quads")
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../build/main-menu-font.png")
	if screenshot.save_png(output) != OK:
		quit(1)
		return
	print("PASS: original five menu labels rendered from font sprites; screenshot "+output)
	quit(0)
