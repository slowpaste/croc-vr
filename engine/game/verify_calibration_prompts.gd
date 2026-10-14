extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	if not world.enter_source_title_options(2):quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000):quit(1);return
	world.source_options_state.navigation.selected=0
	if not world.process_source_options(0,0x800000) or world.source_options_state.page!=6:push_error(world.source_transition_fault);quit(1);return
	for phase in [0,1]:
		world.source_options_state.capture.phase=phase
		if not world.source_options_screen.present(world,world.source_options_state,world.source_options_pose,world.source_options_font):quit(1);return
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/calibration-phase-%d.png"%phase)!=OK:quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: actual analog Calibrate menu route renders both original prompt phases; no input capture/commit proof")
	quit(0)
