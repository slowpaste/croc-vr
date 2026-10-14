extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.update_source_input(0,0)
	for collect in [false,true]:
		if not world.load_room("MP010_00.MAP"):
			quit(1)
			return
		var player = world.create_source_player()
		world.source_pickup_counts[1] = 1
		if not world.lose_source_pickups():
			quit(1)
			return
		var piece = world.source_actors[0]
		var start: Vector3 = piece.position
		# Keep the registered contact pose while excluding player scripts in this fixture.
		world.source_actors.assign([piece])
		player.position = start+Vector3(30,0,30)
		player.refresh_source_render_pose()
		var max_distance := 0.0
		var collected := false
		var ticks := 0
		for tick in range(1200):
			if not world.source_actors.has(piece):
				break
			if collect and not collected and int(piece.vm.parameters[2]) >= (25<<16):
				player.position = piece.position
				player.refresh_source_render_pose()
				collected = true
			world.tick_source_actors()
			ticks += 1
			max_distance = maxf(max_distance,piece.position.distance_to(start))
			if piece.vm.fault != "" or world.source_player_contact_fault != "":
				push_error("Scattered crystal runtime fault: "+str(piece.vm.fault))
				quit(1)
				return
		print("SCATTER_LIFECYCLE: ",JSON.stringify({"collect":collect,"placed":collected,"contacts":world.source_player_contact_counts.get(piece.source_pool_id,0),"params":piece.vm.parameters,"triggers":piece.event_triggers,"flags":piece.primary_flags,"secondary":piece.secondary_flags,"removed":not world.source_actors.has(piece),"ticks":ticks,"distance":max_distance,"crystals":world.source_pickup_counts[1],"pc":piece.vm.pc}))
		if world.source_actors.has(piece) or max_distance <= 0.1 or world.source_pickup_counts[1] != (1 if collect else 0):
			push_error("Scattered crystal flight, expiry or recovery failed")
			quit(1)
			return
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):push_error("Scatter lifecycle audio did not retire");quit(1);return
	print("PASS: original scattered crystal flight, expiry and registered-player recovery")
	quit(0)
