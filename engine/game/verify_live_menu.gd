extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(30):
		await physics_frame
	world.source_menu_progress_flags[0] = 0x8000 # Controlled completed predecessor.
	Input.action_press("move_right")
	for frame in range(90):
		await physics_frame
	if world.source_menu_state.selected_index != 1 or world.source_fade_phase != "":
		push_error("Sampled right input did not select once or repeated while held")
		quit(1)
		return
	Input.action_release("move_right")
	for frame in range(5):
		await physics_frame
	Input.action_press("move_left")
	for frame in range(10):
		await physics_frame
	Input.action_release("move_left")
	if world.source_menu_state.selected_index != 0:
		push_error("Sampled left input did not select backward")
		quit(1)
		return
	for frame in range(10):
		await physics_frame
	Input.action_press("jump")
	for frame in range(60):
		await physics_frame
	Input.action_release("jump")
	if world.map_name != "MP010_00.MAP" or world.source_main_mode != 4 or not world.source_controller_enabled or world.source_player_actor == null or world.source_player_actor.vm.fault != "":
		push_error("Sampled confirm did not launch the original controller")
		quit(1)
		return
	for frame in range(30):
		await physics_frame
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Live menu audio did not retire");quit(1);return
	print("PASS: live keyboard menu press edges/directions and confirm-to-native-gameplay route")
	quit(0)
