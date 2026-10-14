extends SceneTree
func _initialize() -> void: call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	world.source_menu_state.selected_index = 3
	root.add_child(world);await process_frame;world.set_physics_process(false)
	var boss: Node3D = null
	for candidate in world.source_actors:
		if candidate.source_name == "Weeble": boss = candidate;break
	if boss == null or world.source_player_actor == null: quit(1);return
	Input.action_release("attack")
	for tick in range(60): world.sample_source_player_controls();world.tick_source_actors()
	var player: Node3D = world.source_player_actor
	var safe_points: Array[Vector3] = []
	for track in world.room_data.tracks:
		var point := Vector3(float(track.position[0])*world.CELL_METERS,1,float(track.position[2])*world.CELL_METERS)
		var floor_sample: Dictionary = world.source_raw_floor_query(point)
		if int(floor_sample.get("tile",-1)) >= 0 and int(floor_sample.get("surface_type",-1)) == 0:
			point.y = float(floor_sample.height_units)*world.CELL_METERS/4096.0
			safe_points.append(point)
	if safe_points.is_empty(): push_error("No authored safe arena floor");quit(1);return
	print("WEEBLE_INITIAL: ",JSON.stringify({"player":player.position,"boss":boss.position,"ground":player.source_ground}))
	var attacks := 0;var attack_age := -1;var cooldown := 0;var hits := []
	var initial_lives: int = world.source_pickup_counts[3]
	var victory := false;var failure := "";var vulnerable_ticks := 0
	for tick in range(3600):
		var safe := safe_points[0]
		for point in safe_points:
			if point.distance_squared_to(boss.position) > safe.distance_squared_to(boss.position): safe = point
		var vulnerable: bool = int(boss.vm.globals.get(5,0)) != 0 and int(boss.vm.parameters[4]) == 0
		if vulnerable: vulnerable_ticks += 1
		if attack_age < 0 and cooldown == 0 and vulnerable:
			attack_age = 0;attacks += 1
		if attack_age >= 0:
			if attack_age < 3: Input.action_press("attack")
			else: Input.action_release("attack")
			player.position = boss.position if attack_age in range(4,16) else safe
			attack_age += 1
			if attack_age == 45: attack_age = -1;cooldown = 60
		else:
			Input.action_release("attack");player.position = safe
			cooldown = maxi(0,cooldown-1)
		player.refresh_source_render_pose();world.sample_source_player_controls();world.tick_source_actors()
		var health: int = int(boss.vm.globals.get(8,0))
		if not hits.has(health): hits.append(health)
		for candidate in world.source_actors:
			if not candidate.vm.fault.is_empty(): failure = candidate.source_name+": "+candidate.vm.fault;break
		if not failure.is_empty() or int(world.source_pickup_counts[3]) != initial_lives:
			print("WEEBLE_STOP: ",JSON.stringify({"tick":tick,"player":player.position,"boss":boss.position,"ground":player.source_ground,"clip":player.clip_name}));break
		if world.source_transition_state == 3 and health == 0: victory = true;break
		if tick%30 == 0: await process_frame
	Input.action_release("attack")
	if victory and OS.get_cmdline_user_args().has("--verify-return"):
		var last_scene := -1;var last_frame := -1
		for tick in range(1600):
			if is_instance_valid(world.source_cutscene_screen):
				var display: Node3D = world.source_cutscene_screen
				last_scene = int(world.source_cutscene_progress.scene)
				if not world.process_source_sad_cutscene(1.0/30.0): failure = world.source_transition_fault;break
				last_frame = int(display.session.player.last_index)
				await process_frame
			else:
				if not world.source_stage_stats_state.is_empty(): world.advance_source_stage_stats(0x800200 if tick%60 == 30 else 0)
				if not world.process_source_exit(): failure = world.source_transition_fault;break
				if world.source_main_mode == 5 and world.source_fade_phase == "": break
				if tick%30 == 0: await process_frame
		victory = failure.is_empty() and last_scene == 17 and last_frame == 390 and world.source_main_mode == 5 and world.map_name == "MP100_01.MAP" and int(world.source_menu_state.selected_index) == 5 and int(world.source_pickup_counts[3]) == initial_lives
		print("WEEBLE_RETURN: ",JSON.stringify({"scene":last_scene,"frame":last_frame,"mode":world.source_main_mode,"room":world.map_name,"selected":world.source_menu_state.selected_index,"verified":victory,"failure":failure}))
		if victory and OS.get_cmdline_user_args().has("--verify-next-stage"):
			for tick in range(60):
				if not world.process_source_menu_confirmation(0x800000 if tick == 0 else 0,int(world.source_menu_state.input_lock),int(world.source_menu_state.save_mode),int(world.source_menu_state.dialog_mode)):
					failure = world.source_transition_fault;break
				if world.source_main_mode == 4 and world.source_fade_phase == "": break
				if tick%15 == 0: await process_frame
			victory = failure.is_empty() and world.source_main_mode == 4 and world.map_name == "MP014_00.MAP" and world.source_player_actor != null and world.source_controller_enabled and int(world.source_pickup_counts[3]) == initial_lives and (int(world.source_menu_progress_flags.get(4,0))&0x8000) != 0
			if victory:
				for tick in range(60):
					world.sample_source_player_controls();world.tick_source_actors()
					for candidate in world.source_actors:
						if not candidate.vm.fault.is_empty(): failure = candidate.source_name+": "+candidate.vm.fault;break
					if not failure.is_empty(): victory = false;break
			print("WEEBLE_NEXT_STAGE: ",JSON.stringify({"room":world.map_name,"mode":world.source_main_mode,"lives":world.source_pickup_counts[3],"verified":victory,"failure":failure}))
	print("WEEBLE_FIGHT: ",JSON.stringify({"attacks":attacks,"health_words":hits,"vulnerable_ticks":vulnerable_ticks,"lives":world.source_pickup_counts[3],"transition":world.source_transition_state,"victory":victory,"failure":failure,"scope":"authored fight with controlled positions; travel not simulated"}))
	world.stop_imported_audio();world.queue_free();await process_frame;await create_timer(0.25).timeout
	quit(0 if victory and failure.is_empty() else 1)
