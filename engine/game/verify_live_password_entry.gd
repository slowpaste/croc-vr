extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false); world.set_process(false)
	world.source_main_mode = 1
	world.source_menu_state.dialog_mode = 3
	if not world.process_source_main_menu_confirmation(0) or world.source_fade_phase != "": quit(1); return
	if not world.process_source_main_menu_confirmation(0x800000) or world.source_fade_phase != "password-menu-out" or world.source_fade_state.kind != 5: quit(1); return
	for tick in range(100):
		if not world.advance_source_transition(): quit(1); return
		if world.source_main_mode == 13: break
	if world.source_main_mode != 13 or world.source_fade_state.kind != 7 or not world.source_password_entry_renderer.visible: quit(1); return
	for tick in range(9):
		if not world.advance_source_transition(): quit(1); return
	var flags: Array = []; flags.resize(80); flags.fill(0)
	var encoded := preload("res://source_password.gd").encode(flags,1,[0,0,0,0,0,0,0,0])
	var masks := [0,0x10000,0x80000,0x40000,0x20000]
	world.source_stage_crystal_bank = 17
	for symbol in encoded.symbols:
		if not world.advance_source_password_entry(masks[int(symbol)]): quit(1); return
	if world.source_menu_state.selected_index != 0 or world.source_password_entry_state.has("progress"): quit(1); return
	if not world.advance_source_password_entry(0): quit(1); return
	if world.source_password_entry_state.return_flag != 2 or world.source_menu_state.selected_index != 1 or world.source_password_entry_destination.level != 11 or world.source_stage_crystal_bank != 17: quit(1); return
	world.source_menu_progress_flags[7] = 123
	if not world.advance_source_password_entry(0) or world.source_menu_progress_flags[7] != 123: quit(1); return
	world.update_source_input(0,0)
	if not world.process_source_password_entry() or world.source_fade_phase != "password-out": quit(1); return
	for tick in range(13):
		if not world.advance_source_transition(): quit(1); return
	if world.source_main_mode != 5 or world.source_password_entry_renderer != null or world.source_fade_state.kind != 7: quit(1); return
	for tick in range(9):
		if not world.advance_source_transition(): quit(1); return
	if not world.enter_source_password_entry(): quit(1); return
	var bad: Array = encoded.symbols.duplicate(); bad[5] = ((int(bad[5])-1)^1)+1
	for symbol in bad:
		if not world.advance_source_password_entry(masks[int(symbol)]): quit(1); return
	if not world.advance_source_password_entry(0): quit(1); return
	if world.source_password_entry_state.return_flag != 1 or world.source_menu_state.selected_index != 0 or world.source_stage_crystal_bank != 0 or world.source_password_entry_destination.level != 10: quit(1); return
	world.update_source_input(0,0)
	if not world.process_source_password_entry(): quit(1); return
	for tick in range(13):
		if not world.advance_source_transition(): quit(1); return
	if world.source_main_mode != 0 or world.source_password_entry_renderer != null or world.source_fade_state.kind != 7: quit(1); return
	if not world.load_room("MP010_01.MAP") or world.source_password_entry_renderer != null: quit(1); return
	await create_timer(0.1).timeout
	world.queue_free(); await process_frame
	print("PASS: live15-symbol password success/rejection, delayed commit, original bank behavior and screen cleanup")
	quit(0)
