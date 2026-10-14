extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1]); option = args.find("--map")
	if option < 0: quit(1); return
	var level := int(str(args[option+1]).substr(2,3))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var selected: int = tables.menuLevels.values.find(float(level))
	var world = load("res://imported.tscn").instantiate()
	world.source_menu_state.selected_index = selected
	root.add_child(world)
	await process_frame; world.set_physics_process(false)
	if not world.imported or world.source_player_actor == null: push_error("Jigsaw fixture did not load source player"); quit(1); return
	world.source_stage_pickup_slots.fill(0)
	world.update_source_input(0,0)
	for tick in range(60): world.tick_source_actors()
	var piece: Node3D = null
	for candidate in world.source_actors:
		if candidate.source_name == "Jigsaw": piece = candidate; break
	if piece == null: push_error("Missing authored Jigsaw actor"); quit(1); return
	var position: Vector3 = piece.position
	var collected := false
	for tick in range(180):
		world.source_player_actor.position = position
		world.source_player_actor.refresh_source_render_pose()
		world.tick_source_actors()
		for source_actor in world.source_actors:
			if not source_actor.vm.fault.is_empty(): push_error(source_actor.source_name+": "+source_actor.vm.fault); quit(1); return
		if world.source_stage_pickup_slots.count(1) == 1: collected = true; break
		await process_frame
	print("JIGSAW_CONTACT: ",JSON.stringify({"collected":collected,"slots":world.source_stage_pickup_slots,"status":piece.vm.status if is_instance_valid(piece) else "retired","fault":piece.vm.fault if is_instance_valid(piece) else ""}))
	if not collected or int(world.source_stage_pickup_slots[int(selected/5)]) != 1: push_error("Player contact did not record the original stage's jigsaw slot"); quit(1); return
	world.stop_imported_audio()
	world.queue_free(); await process_frame; await create_timer(0.25).timeout
	print("PASS: player overlap executes authored Jigsaw strategy and records one persistent pickup; route to object not simulated")
	quit(0)
