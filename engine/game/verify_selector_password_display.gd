extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();world.source_menu_state.selected_index=12
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	world.source_pickup_counts[3]=7;world.source_menu_progress_flags={0:0x8006,4:0x8000}
	var old_flags: Dictionary=world.source_menu_progress_flags.duplicate()
	assert(world.process_source_menu_confirmation(0x800000,0,0,3))
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.source_main_mode==12 and world.source_game_over_renderer.visible)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://../build/selector-password-display.png")==OK)
	world.source_input_pressed_mask=0x200
	assert(world.process_source_password_display() and world.source_fade_phase=="")
	world.source_input_pressed_mask=0x800000
	assert(world.process_source_password_display() and world.source_fade_phase=="password-display-out")
	for tick in range(150):
		if world.source_fade_phase=="":break
		assert(world.advance_source_transition())
	assert(world.source_main_mode==5 and world.map_name=="MP100_02.MAP" and (not is_instance_valid(world.source_game_over_renderer) or not world.source_game_over_renderer.visible))
	assert(world.source_pickup_counts[3]==7 and world.source_menu_progress_flags==old_flags and world.source_menu_state.selected_index==12)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: selector Show Password enters original rendered mode12, uses native exit mask/fades and preserves selector/progress/lives")
	quit(0)
