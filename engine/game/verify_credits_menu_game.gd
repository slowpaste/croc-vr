extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame; world.set_physics_process(false)
	if not world.imported or world.source_main_mode != 0: push_error("Credits menu test requires title"); quit(1); return
	world.source_main_menu_credits_available = true
	world.enter_source_main_menu()
	world.source_menu_state.dialog_mode = 3
	world.source_main_menu_animation_state.selected = 3
	if not world.refresh_source_main_menu_text() or not world.process_source_main_menu_confirmation(0x800000): push_error(world.source_transition_fault); quit(1); return
	for tick in range(100):
		if is_instance_valid(world.source_credits_screen): break
		if not world.advance_source_transition(): push_error(world.source_transition_fault); quit(1); return
	if world.source_main_mode != 7 or world.map_name != "MP094_00.MAP" or not is_instance_valid(world.source_credits_screen) or world.source_main_menu_text.visible or not world.terrain.visible or not world.source_credits_screen.has_world_background:
		push_error("Unlocked credits did not retire menu/fade presentation"); quit(1); return
	for tick in range(10000):
		if not is_instance_valid(world.source_credits_screen): break
		if not world.process_source_credits(1.0/30.0): push_error(world.source_transition_fault); quit(1); return
		if tick%60 == 0: await process_frame
		for source_actor in world.source_actors:
			if not source_actor.vm.fault.is_empty(): push_error(source_actor.vm.fault); quit(1); return
	if world.source_main_mode != 0 or world.source_main_menu_credits_available or not world.terrain.visible:
		push_error("Credits menu playback did not restore title and availability"); quit(1); return
	world.queue_free(); await process_frame
	print("PASS: actual unlocked Credits menu uses original polygon fade, plays regular credits and restores title")
	quit(0)
