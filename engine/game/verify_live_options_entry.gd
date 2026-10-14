extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_main_mode=1;world.source_menu_state.dialog_mode=1
	if not world.process_source_main_menu_confirmation(0x800000) or world.source_fade_state.kind!=12:push_error("Options confirmation did not start original outgoing12");quit(1);return
	for tick in range(150):
		if world.source_fade_phase=="":break
		if not world.advance_source_transition():push_error(world.source_transition_fault);quit(1);return
	if world.source_main_mode!=8 or not is_instance_valid(world.source_options_screen) or not world.source_options_screen.visible or not world.source_fade_phase.is_empty():push_error("Live Options entry failed");quit(1);return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	for tick in range(10):
		if not world.process_source_options(0,0):push_error(world.source_transition_fault);quit(1);return
	if not world.process_source_options(0,0x100000) or world.source_main_mode!=1 or world.source_menu_state.dialog_mode!=1 or world.source_options_screen.visible:push_error("Original Options cancel return differs");quit(1);return
	world.queue_free();await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):quit(1);return
	print("PASS: live title Options confirmation, outgoing12/incoming7, visible mode8 panel and cancel to menu1/selection1")
	quit(0)
