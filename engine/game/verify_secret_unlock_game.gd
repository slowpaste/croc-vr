extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	world.source_menu_state.selected_index = 39
	root.add_child(world)
	await process_frame; world.set_physics_process(false)
	if not world.imported or world.source_player_actor == null: push_error("Jigsaw test requires source gameplay"); quit(1); return
	world.source_stage_pickup_slots = [1,1,1,1,1,1,1,0]
	world.source_stage_crystal_bank = 42; world.source_pickup_counts[3] = 7
	world.update_source_input(0,0)
	for tick in range(60): world.tick_source_actors()
	var piece: Node3D = null
	for candidate in world.source_actors:
		if candidate.source_name == "Jigsaw": piece = candidate; break
	if piece == null: push_error("Missing final authored jigsaw"); quit(1); return
	var piece_position: Vector3 = piece.position
	for tick in range(180):
		world.source_player_actor.position = piece_position
		world.source_player_actor.refresh_source_render_pose(); world.tick_source_actors()
		if world.source_stage_pickup_slots[7] != 0: break
	if world.source_stage_pickup_slots[7] == 0: push_error("Final jigsaw contact did not collect slot7"); quit(1); return
	world.source_pending_exit = {"source_level":49,"target_level":49,"target_room":0}
	if not world.apply_source_next_level_return(): push_error(world.source_transition_fault); quit(1); return
	if world.source_menu_progress_flags.get(40,0) != 0 or int(world.source_cutscene_progress.scene) != 7: push_error("Premature secret unlock"); quit(1); return
	for tick in range(1500):
		if not is_instance_valid(world.source_cutscene_screen): break
		if not world.process_source_sad_cutscene(1.0/30.0): push_error(world.source_transition_fault); quit(1); return
		await process_frame
	if int(world.source_cutscene_progress.presented_index) != 1255 or world.source_main_mode != 5 or world.map_name != "MP100_05.MAP" or world.source_menu_state.selected_index != 40 or world.source_menu_progress_flags[40] != 0x4000:
		push_error("JIG7 did not complete its original secret selector handoff"); quit(1); return
	for tick in range(20):
		if world.source_fade_phase.is_empty(): break
		if not world.advance_source_transition(): push_error(world.source_transition_fault); quit(1); return
	if not world.process_source_menu_confirmation(0x800000,0,0,0): push_error(world.source_transition_fault); quit(1); return
	for tick in range(30):
		if world.source_main_mode == 4: break
		if not world.advance_source_transition(): push_error(world.source_transition_fault); quit(1); return
	if world.map_name != "MP050_00.MAP" or not world.source_controller_enabled or world.source_player_actor == null or not world.source_player_actor.vm.fault.is_empty() or world.source_stage_pickup_slots != [1,1,1,1,1,1,1,1] or world.source_stage_crystal_bank != 42 or world.source_pickup_counts[3] != 7:
		push_error("Unlocked secret island did not launch playable stage50 with retained campaign awards"); quit(1); return
	world.queue_free(); await process_frame; await create_timer(0.25).timeout
	print("PASS: authored final jigsaw contact -> all1256 JIG7 poses -> secret selector40 -> playable stage50 with retained inventory; travel/combat not simulated")
	quit(0)
