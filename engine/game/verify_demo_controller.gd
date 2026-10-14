extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	if world.source_player_actor == null or not world.load_source_demo_recording(world.map_name):
		quit(1)
		return
	world.source_main_mode = 3
	world.vr_controls.layout = "modern"
	world.update_source_input(0,0)
	var start: Vector3 = world.source_player_actor.position
	var recorded_directions: bool = world.source_demo_frames.any(func(mask): return (int(mask)&0xf0000) != 0)
	var moved := false
	var actor_history: Dictionary = {}
	var arguments := OS.get_cmdline_user_args()
	var option := arguments.find("--probe-ticks")
	var ticks := clampi(int(arguments[option+1]),1,900) if option >= 0 and option+1 < arguments.size() else 120
	for tick in range(ticks):
		var previous := int(world.source_input_held_mask)
		if not world.sample_source_demo_controls(tick) or world.source_input_held_mask != int(world.source_demo_frames[tick]) or world.source_input_pressed_mask != ((~previous)&int(world.source_demo_frames[tick])) or world.source_player_input_state.pad_mode != 1:
			push_error("Original recording was remapped or changed by live controls")
			quit(1)
			return
		world.tick_source_actors()
		moved = moved or world.source_player_actor.position.distance_to(start) > 0.05
		for actor in world.source_actors:
			actor_history[int(actor.source_pool_id)] = actor.source_name
			if actor.vm.fault != "":
				push_error("Recorded-input actor failed at tick%d: %s PC%d parent%d (%s): %s" % [tick,actor.source_name,actor.vm.pc,actor.source_parent_id,str(actor_history.get(int(actor.source_parent_id),"unknown")),actor.vm.fault])
				quit(1)
				return
	if recorded_directions and not moved:
		push_error("Original recorded input did not move the native controller")
		quit(1)
		return
	if not world.sample_source_demo_controls(900) or world.source_input_held_mask != 0:
		quit(1)
		return
	world.stop_imported_audio()
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):
		push_error("Recorded demo audio did not retire");quit(1);return
	print("PASS: original demo recording drives native controller with exact masks/edges and digital input under Modern layout; directional recording=",recorded_directions)
	quit(0)
