extends SceneTree
func _initialize() -> void:
	call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var level := int(str(world.map_name).substr(2,3))
	var levels: Array = world.runtime_tables.menuLevels.values
	for index in range(levels.size()):
		if int(levels[index]) == level: world.source_menu_state.selected_index = index; break
	var expected_selected: int = preload("res://source_stage_end.gd").next_level_selection(int(world.source_menu_state.selected_index),world.source_menu_progress_flags)
	var expected_map := "MP100_%02d.MAP"%int(int(levels[expected_selected])/10)
	var exit_actor = null
	for actor in world.source_actors:
		if actor.source_name == "FinalExit": exit_actor = actor
	if exit_actor == null: push_error("FinalExit fixture actor is missing"); quit(1); return
	var player = world.source_player_actor
	var yaw: int = int(exit_actor.source_angles.y)
	var approach := Vector3(sin(float(yaw)*TAU/4096.0),0,cos(float(yaw)*TAU/4096.0))
	var distance := 0.05 if OS.get_cmdline_user_args().has("--touch") else 0.3 if OS.get_cmdline_user_args().has("--close") else 0.6
	var placed: Vector3 = exit_actor.position+approach*distance*world.CELL_METERS
	var floor_hit: Dictionary = world.source_floor_at(placed+Vector3(0,10,0))
	print("EXIT_FLOOR_DIAGNOSTIC: exit=",exit_actor.position," placed=",placed," floor=",floor_hit)
	if not floor_hit.has("height_units"): world.queue_free(); quit(1); return
	placed.y = float(floor_hit.height_units)*world.CELL_METERS/4096.0
	player.position = placed
	player.source_angles.y = (yaw+2048)&4095
	player.refresh_source_render_pose()
	world.actor.position = player.position
	for warmup in range(90):
		world.sample_source_player_controls()
		world.tick_source_actors()
	var walk_in := OS.get_cmdline_user_args().has("--walk-in")
	var walked_contact := false
	if walk_in:
		world.camera.global_position = player.position+approach*3.0+Vector3(0,1.6,0)
		world.camera.look_at(player.position+Vector3(0,1,0))
		Input.action_press("move_forward")
		for step in range(120):
			world.sample_source_player_controls()
			world.tick_source_actors()
			if int(world.source_player_contact_counts.get(exit_actor.source_pool_id,0)) > 0:
				walked_contact = true
				break
			if player.vm.fault != "" or world.source_transition_state != 0: break
		Input.action_release("move_forward")
		for settle in range(15):
			world.sample_source_player_controls()
			world.tick_source_actors()
		var expected_pad := 2 if world.vr_controls.layout == "modern" else 1
		if int(world.source_player_input_state.get("pad_mode",0)) != expected_pad: walked_contact = false
		print("EXIT_WALK_CONTACT: ",walked_contact," position=",player.position," layout=",world.vr_controls.layout," pad_mode=",world.source_player_input_state.get("pad_mode",0))
	print("EXIT_ATTACK_POSE: ",player.position," yaw=",player.source_angles.y," exit_yaw=",yaw)
	Input.action_press("attack")
	var ticks := 0
	var attack_clips: Array = []
	var attack_tags: Array = []
	while ticks < 300 and world.source_transition_state == 0:
		world.sample_source_player_controls()
		world.tick_source_actors()
		ticks += 1
		if ticks < 30 and not attack_clips.has(player.clip_name): attack_clips.append(player.clip_name)
		if ticks < 30 and not attack_tags.has(world.source_extended_globals[1]): attack_tags.append(world.source_extended_globals[1])
		if ticks == 3: Input.action_release("attack")
		if player.vm.fault != "": break
	print("FINAL_EXIT_CONTACT: ticks=",ticks," state=",world.source_transition_state," exit_pc=",exit_actor.vm.pc," exit_params=",exit_actor.vm.parameters," XG0=",world.source_extended_globals[0]," XG1=",world.source_extended_globals[1]," XG28=",world.source_extended_globals[28]," player_fault=",player.vm.fault)
	for actor in world.source_actors:
		if actor.source_name.begins_with("FinalExit"): print("FINAL_EXIT_ACTOR: ",actor.source_name," pc=",actor.vm.pc," contacts=",world.source_player_contact_counts.get(actor.source_pool_id,0)," flags=",actor.primary_flags," secondary=",actor.secondary_flags," scale=",actor.source_scale," fault=",actor.vm.fault)
	print("FINAL_EXIT_ENGINE_FAULT: ",world.source_transition_fault)
	print("FINAL_EXIT_ATTACK: clips=",attack_clips," tags=",attack_tags)
	var okay: bool = world.source_transition_state == 3 and player.vm.fault == ""
	if walk_in and not walked_contact: okay = false
	for actor in world.source_actors:
		if actor.vm.fault != "":
			print("FINAL_EXIT_OTHER_FAULT: ",actor.source_name," pc=",actor.vm.pc," ",actor.vm.fault)
			okay = false
	if okay:
		world.source_fade_state = {}
		world.source_fade_phase = ""
		Input.action_press("jump")
		world.sample_source_player_controls()
		world.tick_source_actors()
		Input.action_release("jump")
		okay = world.source_stage_stats_state.busy == 1
		for tick in range(13):
			if world.source_main_mode != 4: okay = false; break
			world.sample_source_player_controls()
			world.tick_source_actors()
			for actor in world.source_actors:
				if actor.vm.fault != "": okay = false
			okay = world.process_source_exit() and okay
		okay = okay and world.source_main_mode == 5 and world.map_name == expected_map and world.source_menu_state.selected_index == expected_selected
		print("FINAL_EXIT_NATURAL_RETURN: ",okay)
	Input.action_release("attack")
	for voice in world.source_voice_nodes.values().duplicate():
		if is_instance_valid(voice): world.retire_imported_voice(voice)
	await create_timer(0.1).timeout
	world.queue_free()
	await process_frame
	quit(0 if okay else 1)
