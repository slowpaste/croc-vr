extends SceneTree
func _initialize() -> void: call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate(); root.add_child(world)
	await process_frame; world.set_physics_process(false)
	if not world.imported or world.source_player_actor == null: quit(1); return
	var enemy: Node3D = null
	var args := OS.get_cmdline_user_args();var option := args.find("--enemy")
	var enemy_name := str(args[option+1]) if option >= 0 else "DantiniWalk"
	for candidate in world.source_actors:
		if candidate.source_name == enemy_name: enemy = candidate; break
	if enemy == null: push_error("Missing authored enemy"); quit(1); return
	Input.action_release("attack")
	for tick in range(60): world.sample_source_player_controls(); world.tick_source_actors()
	var player: Node3D = world.source_player_actor
	var enemy_id: int = enemy.source_pool_id
	var entity_index: int = enemy.source_map_entity_index
	var origin: Vector3 = enemy.position
	var initial_enemy_flags: int = enemy.primary_flags
	var initial_lives: int = world.source_pickup_counts[3]
	var no_attack := OS.get_cmdline_user_args().has("--no-attack")
	player.position = origin+Vector3(0,0,2); player.refresh_source_render_pose()
	var clips: Array = []; var peak_contacts := 0
	var peak_death_effects := 0
	for tick in range(90):
		if tick < 3 and not no_attack: Input.action_press("attack")
		else: Input.action_release("attack")
		if tick in range(4,16) and is_instance_valid(enemy):
			player.position = enemy.position; player.refresh_source_render_pose()
		world.sample_source_player_controls(); world.tick_source_actors()
		peak_death_effects = maxi(peak_death_effects,world.source_actors.filter(func(candidate): return candidate.source_name == "DeathFX").size())
		if not clips.has(player.clip_name): clips.append(player.clip_name)
		peak_contacts = maxi(peak_contacts,int(world.source_player_contact_counts.get(enemy_id,0)))
		for candidate in world.source_actors:
			if not candidate.vm.fault.is_empty():
				Input.action_release("attack"); push_error(candidate.source_name+": "+candidate.vm.fault); world.queue_free(); await process_frame; quit(1); return
		await process_frame
	Input.action_release("attack")
	var verified := true
	if args.has("--verify-source-death"):
		verified = peak_contacts > 0 and peak_death_effects >= 8 and (int(world.source_map_entity_flags.get(world.map_name,{}).get(entity_index,0))&1) != 0 and int(world.source_pickup_counts[3]) == initial_lives
		print("AUTHORED_DEATH: ",JSON.stringify({"enemy":enemy_name,"effects":peak_death_effects,"map_flags":int(world.source_map_entity_flags.get(world.map_name,{}).get(entity_index,0)),"verified":verified}))
	if OS.get_cmdline_user_args().has("--verify-contact"):
		if no_attack:
			verified = clips.has("CROCDIE1.ANI") and int(world.source_pickup_counts[3]) == initial_lives-1 and peak_contacts > 0
		else:
			# DT01 authored death path hides/disables collision, emits DeathFX,
			# then waits280 ticks at PC72 before regenerating; node persists.
			verified = clips.has("CROCATK2.ANI") and clips.has("CROCATK3.ANI") and peak_contacts > 0 and int(world.source_pickup_counts[3]) == initial_lives and is_instance_valid(enemy) and int(enemy.vm.pc) == 72 and (int(enemy.primary_flags)&0x80000) != 0
	print("TAIL_ATTACK_PROBE: ",JSON.stringify({"attack":not no_attack,"clips":clips,"contacts":peak_contacts,"initial_enemy_flags":initial_enemy_flags,"enemy_present":world.source_pool.slots.has(enemy_id),"enemy_flags":int(enemy.primary_flags) if is_instance_valid(enemy) else 0,"enemy_pc":int(enemy.vm.pc) if is_instance_valid(enemy) else -1,"lives":world.source_pickup_counts[3],"scope":"input and overlap fixture; player travel not simulated"}))
	world.stop_imported_audio(); world.queue_free(); await process_frame; await create_timer(0.25).timeout
	if not verified: push_error("Authored tail/enemy contact outcome differs")
	quit(0 if verified else 1)
