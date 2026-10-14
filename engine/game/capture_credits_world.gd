extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame; world.set_physics_process(false)
	if not world.enter_source_credits(0,true): push_error(world.source_transition_fault); quit(1); return
	for tick in range(20):
		if not world.process_source_credits(1.0/30.0): push_error(world.source_transition_fault); quit(1); return
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var overlay: Image = world.source_credits_screen.viewport.get_texture().get_image()
	if overlay.get_pixel(0,0).a > 0.01: push_error("Credits overlay obscures scenery"); quit(1); return
	var image := root.get_texture().get_image()
	if image.save_png("res://../build/credits-original-room.png") != OK: quit(1); return
	print("CREDITS_WORLD_CAPTURE: ",JSON.stringify({"map":world.map_name,"actors":world.source_actors.size(),"tick":world.source_tick_count,"overlay_corner_alpha":overlay.get_pixel(0,0).a}))
	world.queue_free(); await process_frame
	quit(0)
