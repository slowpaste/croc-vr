extends SceneTree
func _initialize() -> void:
	call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.update_source_input(0,0)
	var arguments := OS.get_cmdline_user_args()
	var ticks := 120
	var option := arguments.find("--probe-ticks")
	if option >= 0 and option+1 < arguments.size():
		ticks = clampi(int(arguments[option+1]),1,3600)
	var selected_index := -1
	option = arguments.find("--probe-select-index")
	if option >= 0 and option+1 < arguments.size():
		selected_index = int(arguments[option+1])
	var avatar_start: Variant = null
	for tick in range(ticks):
		if tick == 120 and selected_index >= 0:
			for actor in world.source_actors:
				if actor.source_name == "MapCroc":
					avatar_start = actor.position
			world.source_menu_state.selected_index = selected_index
			world.source_menu_state.selection_changes += 1
		if tick == 120 and arguments.has("--probe-navigate"):
			for actor in world.source_actors:
				if actor.source_name == "MapCroc":
					avatar_start = actor.position
			world.source_menu_progress_flags[0] = 0x8000 # Controlled completed-stage fixture.
			world.apply_source_menu_navigation(0x80000,0)
		world.tick_source_actors()
	var actors: Array = []
	for actor in world.source_actors:
		actors.append({"name":actor.source_name,"pc":actor.vm.pc,"status":actor.vm.status,"fault":actor.vm.fault})
	print("MENU_ACTORS: ",JSON.stringify(actors))
	var verified := true
	if arguments.has("--verify"):
		verified = world.source_player_actor != null and world.source_player_actor.source_name == "TitleCamera" and (world.source_player_actor.primary_flags&0x800) != 0 and actors.all(func(item): return item.fault == "")
		verified = verified and world.source_main_mode == (7 if world.map_name == "MP094_00.MAP" else 0)
		if not verified:
			push_error("Original idle title actor execution failed")
	if arguments.has("--verify-island"):
		var avatar = null
		for candidate in world.source_actors:
			if candidate.source_name == "MapCroc":
				avatar = candidate
		verified = avatar != null and actors.all(func(item): return item.fault == "")
		if verified:
			var parent = world.source_pool.slots.get(avatar.source_parent_id,{}).get("node",null)
			verified = parent != null and parent.source_name == "IslandCamera" and world.source_camera_override_one == parent
		if (selected_index >= 0 or arguments.has("--probe-navigate")) and avatar != null:
			print("MENU_SELECTION: ",JSON.stringify({"start":str(avatar_start),"end":str(avatar.position),"counter":world.source_menu_state.selection_changes,"pc":avatar.vm.pc}))
			verified = verified and avatar_start != null and avatar.position.distance_to(avatar_start) > 0.1 and world.source_menu_state.selection_changes == 0
		if not verified:
			push_error("Original idle island actor execution/parent link failed")
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Menu audio did not retire");quit(1);return
	quit(0 if verified else 1)
