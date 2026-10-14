extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.source_menu_state.selected_index = 44
	world.source_menu_progress_flags[44] = 0x8000
	world.source_stage_pickup_slots[7] = 1
	var before: Array = world.source_stage_pickup_slots.duplicate()
	if not world.refresh_source_game_over_screen() or not world.source_game_over_renderer.visible or world.source_game_over_renderer.get_parent() != world.camera: quit(1); return
	if world.source_stage_pickup_slots != before: quit(1); return
	var saved: Dictionary = world.manifest.levelNames
	world.manifest.erase("levelNames")
	if world.refresh_source_game_over_screen() or world.source_game_over_renderer.visible: quit(1); return
	world.manifest.levelNames = saved
	if not world.refresh_source_game_over_screen(): quit(1); return
	world.source_pickup_counts[3] = 0
	world.source_menu_state.dialog_mode = 7
	world.source_voice_pool.reserved[0] = true
	world.source_voice_pool.reserved[20] = true
	world.play_source_menu_sound("SELECT")
	if world.source_voice_nodes.is_empty(): push_error("Sound fixture did not bind the original sample"); quit(1); return
	world.source_stage_crystal_bank = 42
	world.source_transition_state = 1
	world.source_fade_state = preload("res://source_transition_fade.gd").start(8)
	world.source_fade_phase = "out"
	for tick in range(13):
		if not world.advance_source_transition(): quit(1); return
	if world.source_main_mode != 14 or not world.source_game_over_renderer.visible or world.source_fade_phase != "" or world.source_pickup_counts[3] != 0: quit(1); return
	if world.source_menu_state.dialog_mode != 0 or world.source_voice_pool.reserved[20] or not world.source_voice_pool.reserved[0] or not world.source_voice_nodes.is_empty(): quit(1); return
	if world.source_game_over_renderer.backdrop.visible or world.source_continue_state.selected != 0: quit(1); return
	var choice := preload("res://source_continue_text.gd").layout(world.runtime_tables.gameOver,world.source_continue_state)
	if choice.has("fault") or choice.labels[0].text != "CONTINUE GAME" or choice.labels[1].text != "YES" or choice.labels[2].text != "NO": quit(1); return
	world.update_source_input(0x40000,0)
	if not world.process_source_game_over() or world.source_menu_state.dialog_mode != 1 or world.source_fade_phase != "": quit(1); return
	world.update_source_input(0x10000,0x40000)
	if not world.process_source_game_over() or world.source_menu_state.dialog_mode != 0: quit(1); return
	world.source_menu_state.dialog_mode = 0
	world.vr_settings.toggle()
	Input.action_press("jump")
	world._physics_process(1.0)
	if world.source_fade_phase != "" or world.source_main_mode != 14: quit(1); return
	world.vr_settings.toggle()
	world._physics_process(1.0/30.0)
	if world.source_fade_phase != "": push_error("Held resume input confirmed game over"); quit(1); return
	Input.action_release("jump")
	world._physics_process(1.0/30.0)
	if world.source_game_over_confirm_requires_release: quit(1); return
	world.update_source_input(0x800000,0x800000)
	if not world.process_source_game_over() or world.source_fade_phase != "game-over-out": quit(1); return
	for tick in range(13):
		if not world.advance_source_transition(): quit(1); return
	if world.source_main_mode != 5 or world.source_game_over_renderer != null or world.source_pickup_counts[3] != 3 or world.source_stage_crystal_bank != 0 or world.source_fade_state.kind != 7 or world.source_stage_pickup_slots != before: quit(1); return
	for tick in range(9):
		if not world.advance_source_transition(): quit(1); return
	if world.source_fade_phase != "": quit(1); return
	if not world.load_room("MP010_01.MAP") or world.source_game_over_renderer != null: quit(1); return
	await create_timer(0.1).timeout
	world.queue_free()
	await process_frame
	print("PASS: live password screen binds current progress and pickup state, hides failed refresh and clears on room load")
	quit(0)
