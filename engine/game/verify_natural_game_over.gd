extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.update_source_input(0,0)
	world.source_player_input_state = {"pad_mode":1}
	var player = world.create_source_player()
	if player == null: quit(1); return
	world.source_pickup_counts[3] = 1
	world.source_pickup_counts[1] = 0
	var enemy: Node3D = null
	for candidate in world.source_actors:
		if candidate.source_name == "DantiniWalk": enemy = candidate; break
	if enemy == null: quit(1); return
	var requested := false
	for tick in range(400):
		if tick == 30:
			player.position = enemy.position
			player.refresh_source_render_pose()
		world.update_source_input(0,0)
		world.tick_source_actors()
		requested = requested or world.source_transition_state == 1
		if world.source_fade_phase == "out" and int(world.source_fade_state.counter) == 288 and world.source_pickup_counts[3] == 0:
			world.source_controller_enabled = true
			var frame_start_ticks: int = world.source_tick_count
			world._physics_process(0.2)
			if world.source_tick_count != frame_start_ticks+1: push_error("Queued gameplay ticks continued after game-over entry"); quit(1); return
		else:
			if not world.process_source_exit(): push_error(world.source_transition_fault); quit(1); return
		if world.source_main_mode == 14: break
	if not requested or world.source_main_mode != 14 or world.source_pickup_counts[3] != 0 or player.vm.fault != "" or not world.source_game_over_renderer.visible:
		push_error("Natural last-life death failed: "+str({"mode":world.source_main_mode,"lives":world.source_pickup_counts[3],"fault":player.vm.fault,"state":world.source_transition_state}))
		quit(1); return
	var stopped_ticks: int = world.source_tick_count
	world._physics_process(1.0/30.0)
	if world.source_tick_count != stopped_ticks: push_error("Game-over screen kept advancing gameplay actors"); quit(1); return
	Input.action_press("jump")
	world._physics_process(1.0/30.0)
	Input.action_release("jump")
	if world.source_fade_phase != "game-over-out": push_error("Live confirmation did not begin game-over return"); quit(1); return
	for tick in range(13): world._physics_process(1.0/30.0)
	if world.source_main_mode != 5 or world.source_pickup_counts[3] != 3 or world.source_game_over_renderer != null: push_error("Natural game-over did not return to selector"); quit(1); return
	world.queue_free()
	await process_frame
	print("PASS: original last-life enemy death, paused gameplay actors, physical confirmation and selector return")
	quit(0)
