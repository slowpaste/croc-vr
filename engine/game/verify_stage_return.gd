extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var ordinary: bool = world.map_name == "MP010_00.MAP"
	var level := int(world.map_name.substr(2,3))
	var selected: int = world.runtime_tables.menuLevels.values.find(float(level))
	world.source_menu_state.selected_index = selected
	world.source_menu_progress_flags = {0:0x8006,1:0x8006,2:0x8006}
	if not ordinary:
		for previous in range(selected-3,selected): world.source_menu_progress_flags[previous] = 0x8006
	var expected_index: int = world.source_stage_end_selection(level)
	var expected_level: int = world.runtime_tables.menuLevels.values[expected_index]
	var expected_selector := "MP100_%02d.MAP"%int(expected_level/10)
	world.source_pickup_counts[3] = 7
	world.source_stage_crystal_bank = 42
	world.source_input_suppression_count = 2
	world.source_voice_pool.reserved[5] = true
	var player = world.source_player_actor
	if player.asl_command({"op":198,"args":[]},player.vm) != "continue" or player.asl_command({"op":159,"args":[]},player.vm) != "continue": quit(1); return
	world.source_fade_phase = ""
	world.source_fade_state = {}
	if not ordinary:
		if not world.process_source_exit() or world.source_fade_phase != "" or world.source_transition_state != 4:
			push_error("Sequence results did not wait for confirmation")
			quit(1)
			return
		world.advance_source_stage_stats(0x200)
	if not world.process_source_exit() or world.source_fade_phase != "stage-out" or world.source_fade_state.kind != (8 if ordinary else 2): quit(1); return
	var overlay = world.source_fade_overlay
	for tick in range(12 if ordinary else 9):
		if world.source_main_mode != 4 or not world.process_source_exit(): quit(1); return
		if not ordinary and tick == 5 and overlay.material_override != overlay.white_material:
			push_error("Story results exit did not use original additive-white fade"); quit(1); return
	if ordinary and overlay.material_override != overlay.fade_material:
		push_error("Source story results exit did not use additive-white presentation")
		quit(1)
		return
	if not ordinary:
		if not is_instance_valid(world.source_cutscene_screen) or int(world.source_cutscene_progress.scene) != preload("res://source_stage_end.gd").sequence_id(level):
			push_error("Story stage skipped its original sequence"); quit(1); return
		for tick in range(600):
			if not is_instance_valid(world.source_cutscene_screen): break
			if not world.process_source_sad_cutscene(1.0/30.0): push_error(world.source_transition_fault); quit(1); return
			await process_frame
	if world.map_name != expected_selector or world.source_main_mode != 5 or world.source_menu_state.selected_index != expected_index or world.source_controller_enabled or world.source_fade_phase != "in":
		push_error("Original stage-return selection/selector handoff failed")
		quit(1)
		return
	if world.source_pickup_counts[3] != 7 or world.source_stage_crystal_bank != 42 or world.source_input_suppression_count != 0 or world.source_voice_pool.reserved[5] or not world.source_resume_input_baseline_pending:
		push_error("Stage return lost awards or retained held voices/input state")
		quit(1)
		return
	if not world.advance_source_transition() or overlay.material_override != overlay.fade_material:
		push_error("Selector incoming fade retained outgoing white shader")
		quit(1)
		return
	for voice in world.source_voice_nodes.values().duplicate():
		if is_instance_valid(voice): world.retire_imported_voice(voice)
	await create_timer(0.1).timeout
	world.queue_free()
	await process_frame
	print("PASS: original stage-return selection, selector scene, retained lives/bank, voice/input reset")
	quit(0)
