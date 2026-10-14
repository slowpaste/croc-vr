extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for kind in [1,2]:
		world.source_main_mode=1;world.source_menu_state.dialog_mode=1
		if not world.enter_source_title_options(kind):push_error(world.source_transition_fault);quit(1);return
		var slot := 1316 if kind==2 else 1252
		if world.source_options_state.pad_kind!=kind or world.source_options_pose.slot!=slot:quit(1);return
		for tick in range(2):
			if not world.process_source_options(0,0):quit(1);return
		if world.source_options_pose.slot!=slot or not world.source_options_screen.panel.models.has(slot):push_error("Controller preview loaded wrong native group");quit(1);return
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		if world.source_options_screen.panel.output_texture().get_image().save_png("res://../build/options-pad-%d.png"%kind)!=OK:quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: explicit regular/analog Options entry renders native1252/1316 controller model groups")
	quit(0)
