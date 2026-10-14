extends SceneTree
func _initialize() -> void:
	call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var player = world.source_player_actor
	var player_sequence := OS.get_cmdline_user_args().has("--player-sequence")
	if player == null: quit(1); return
	var bird: Node3D = null
	if player_sequence:
		for warmup in range(90):
			world.update_source_input(0,0)
			world.tick_source_actors()
		world.source_extended_globals[0] = 65536
		if OS.get_cmdline_user_args().has("--entry-flag"): world.source_extended_globals[28] = 65536
	else:
		if not world.initialize_source_stage_stats(): quit(1); return
		bird = world.spawn_source_actor(player,"Bird_Victory",[])
		if bird == null: push_error("Original victory actor could not be created"); quit(1); return
	var ticks := 0
	while ticks < 900 and world.source_transition_state == 0 and (player_sequence or is_instance_valid(bird)):
		world.update_source_input(0,0)
		world.tick_source_actors()
		ticks += 1
		if player_sequence and not is_instance_valid(bird):
			for actor in world.source_actors:
				if actor.source_name == "Bird_Victory": bird = actor
		if (is_instance_valid(bird) and bird.vm.fault != "") or player.vm.fault != "": break
	print("VICTORY_SCRIPT_PROBE: ticks=",ticks," state=",world.source_transition_state," selected=",world.source_menu_state.selected_index," bird_pc=",bird.vm.pc if is_instance_valid(bird) else -1," bird_fault=",bird.vm.fault if is_instance_valid(bird) else "removed"," player_pc=",player.vm.pc," level_script_state=",world.source_level_script_state," player_fault=",player.vm.fault)
	if player_sequence: print("VICTORY_PLAYER_GLOBALS: XG0=",world.source_extended_globals[0]," XG28=",world.source_extended_globals[28]," camera_hold=",world.source_camera_hold_counter)
	var okay: bool = world.source_transition_state == 3 and player.vm.fault == "" and (not is_instance_valid(bird) or bird.vm.fault == "")
	if okay:
		world.source_fade_state = {}
		world.source_fade_phase = ""
		okay = world.process_source_exit() and world.source_fade_phase == ""
		world.update_source_input(0x800000,0)
		world.tick_source_actors()
		okay = okay and world.source_stage_stats_state.busy == 1
		for tick in range(13):
			okay = world.process_source_exit() and okay
		okay = okay and world.map_name == "MP100_01.MAP" and world.source_menu_state.selected_index == 1 and world.source_main_mode == 5
	print("VICTORY_SCRIPT_RETURN: ",okay)
	for voice in world.source_voice_nodes.values().duplicate():
		if is_instance_valid(voice): world.retire_imported_voice(voice)
	await create_timer(0.1).timeout
	world.queue_free()
	await process_frame
	quit(0 if okay else 1)
