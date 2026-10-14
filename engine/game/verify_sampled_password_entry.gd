extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world); await process_frame
	world.set_physics_process(false); world.set_process(false)
	Input.action_press("jump")
	if not world.enter_source_password_entry(): quit(1); return
	world._physics_process(1.0/30.0)
	if world.source_password_entry_state.count != 0: push_error("Held entry button edited the password"); quit(1); return
	Input.action_release("jump")
	world._physics_process(1.0/30.0)
	var flags: Array = []; flags.resize(80); flags.fill(0)
	var code := preload("res://source_password.gd").encode(flags,1,[0,0,0,0,0,0,0,0])
	var actions := ["","move_forward","move_right","move_back","move_left"]
	var actor_ticks: int = world.source_tick_count
	for index in range(15):
		var action: String = actions[int(code.symbols[index])]
		Input.action_press(action)
		world._physics_process(1.0/30.0)
		if index < 14:
			for frame in range(3): world._physics_process(1.0/30.0)
			if world.source_password_entry_state.count != index+1: push_error("Held direction repeated a password symbol"); quit(1); return
		Input.action_release(action)
		if index < 14: world._physics_process(1.0/30.0)
	if world.source_password_entry_state.count != 16 or world.source_password_entry_state.has("progress") or world.source_tick_count != actor_ticks: quit(1); return
	world._physics_process(1.0/30.0)
	if world.source_password_entry_state.return_flag != 2 or world.source_menu_state.selected_index != 1 or world.source_fade_phase != "password-out": quit(1); return
	for frame in range(13): world._physics_process(1.0/30.0)
	if world.source_main_mode != 5 or world.source_password_entry_renderer != null: quit(1); return
	await create_timer(0.1).timeout
	world.queue_free(); await process_frame
	print("PASS: sampled cardinal controls enter15 original symbols once per press, protect held entry input and return to selector")
	quit(0)
