extends SceneTree
func _initialize() -> void: call_deferred("probe")
func probe() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1]); option = args.find("--map")
	if option < 0: quit(1); return
	var level := int(str(args[option+1]).substr(2,3))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var world = load("res://imported.tscn").instantiate()
	world.source_menu_state.selected_index = tables.menuLevels.values.find(float(level))
	root.add_child(world); await process_frame; world.set_physics_process(false)
	if not world.imported or world.source_player_actor == null: push_error("Boss room did not initialize source player"); quit(1); return
	world.update_source_input(0,0)
	var probe_ticks := 900
	option = args.find("--probe-ticks")
	if option >= 0 and option+1 < args.size(): probe_ticks = int(args[option+1])
	if probe_ticks < 1 or probe_ticks > 9000: push_error("Boss probe ticks must be1..9000");quit(1);return
	var protected := args.has("--protect-triggers")
	if args.has("--near-boss"):
		for tick in range(60): world.tick_source_actors()
		var boss: Node3D = null
		option = args.find("--boss")
		var wanted := str(args[option+1]) if option >= 0 else ""
		for candidate in world.source_actors:
			if (not wanted.is_empty() and candidate.source_name == wanted) or (wanted.is_empty() and ("Boss" in candidate.source_name or candidate.source_name == "Chumley")): boss = candidate; break
		if boss == null: push_error("No authored boss actor for proximity probe"); quit(1); return
		world.source_player_actor.position = boss.position+Vector3(0,0,2)
		world.source_player_actor.refresh_source_render_pose()
	var visited := {}; var peak_actors: int = world.source_actors.size()
	var actor_names := {}
	var first_transition_tick := -1
	var initial_lives: int = world.source_pickup_counts[3]
	var timeline_path := ""
	option = args.find("--timeline")
	if option >= 0 and option+1 < args.size(): timeline_path = str(args[option+1])
	var timeline: Array = []
	var previous_states := {}
	var programs := {}
	for tick in range(probe_ticks):
		# Controlled coverage only: original PauseTriggers84 flag, no health,
		# lives, boss state or source script changes. Never counts as victory.
		if protected and is_instance_valid(world.source_player_actor): world.source_player_actor.primary_flags |= 0x40
		world.tick_source_actors(); peak_actors = maxi(peak_actors,world.source_actors.size())
		if first_transition_tick < 0 and world.source_transition_state != 0: first_transition_tick = tick
		for candidate in world.source_actors:
			actor_names[candidate.source_name] = true
			if not timeline_path.is_empty() and (args.has("--timeline-all") or "Boss" in candidate.source_name or "Gong" in candidate.source_name or candidate.source_name in ["SwimmingCroc","PlatCrys"]):
				if not programs.has(candidate.source_name): programs[candidate.source_name] = candidate.vm.instructions.duplicate(true)
				var state := {"pc":candidate.vm.pc,"parameters":candidate.vm.parameters.duplicate(),"globals":candidate.vm.globals.duplicate(),"primary_flags":candidate.primary_flags}
				var identity := str(candidate.source_pool_id)
				if previous_states.get(identity,{}) != state:
					previous_states[identity] = state.duplicate(true)
					timeline.append({"tick":tick,"actor":candidate.source_name,"pool_id":candidate.source_pool_id,"state":state,"position":[candidate.position.x,candidate.position.y,candidate.position.z]})
			if not candidate.vm.fault.is_empty():
				print("BOSS_FAULT_INSTRUCTION: ",JSON.stringify(candidate.vm.instructions.get(candidate.vm.pc,{})))
				push_error(candidate.source_name+" PC"+str(candidate.vm.pc)+": "+candidate.vm.fault); world.queue_free(); await process_frame; quit(1); return
			visited[candidate.source_name+":"+str(candidate.vm.pc)] = true
		if tick%30 == 0: await process_frame
	if not timeline_path.is_empty():
		var output := FileAccess.open(timeline_path,FileAccess.WRITE)
		if output == null: push_error("Cannot write boss timeline");world.queue_free();await process_frame;quit(1);return
		output.store_string(JSON.stringify({"map":world.map_name,"ticks":probe_ticks,"protected_triggers":protected,"events":timeline,"programs":programs,"scope":"observed actor state changes; no player attack or victory evidence"}));output.close()
	print("BOSS_RUNTIME_PROBE: ",JSON.stringify({"map":world.map_name,"ticks":probe_ticks,"near_boss":args.has("--near-boss"),"protected_triggers":protected,"script_positions":visited.size(),"actor_names":actor_names.keys(),"peak_actors":peak_actors,"initial_lives":initial_lives,"lives":world.source_pickup_counts[3],"first_transition_tick":first_transition_tick,"transition":world.source_transition_state,"scope":"controlled encounter script coverage; player actions and victory not simulated"}))
	world.stop_imported_audio(); world.queue_free(); await process_frame; await create_timer(0.25).timeout
	quit(0)
