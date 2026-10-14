extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value,message)

func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.update_source_input(0,0)
	world.source_pickup_counts = {1:7,2:1,3:3}
	world.source_extended_globals[250] = -12345
	for destination in ["MP016_05.MAP","MP016_04.MAP"]:
		var outgoing = world.create_source_player()
		check(outgoing != null,"Missing outgoing water-transition controller")
		world.source_player_entry_state.present = false
		world.source_ground_mode_80_value = 0
		var door: Dictionary = {}
		for candidate in world.room_data.doors:
			if "MP%03d_%02d.MAP" % [int(candidate.level),int(candidate.room)] == destination:
				door = candidate
				break
		check(not door.is_empty(),"Missing original connecting door")
		var factor: int = world.runtime_tables.mapYScale.values[int(world.room_data.style)]
		outgoing.position = Vector3(int(door.position[0])*4096,int(door.position[1])*factor*8,int(door.position[2])*4096)*world.CELL_METERS/4096.0
		var floor_hit: Dictionary = world.source_floor_at(outgoing.position)
		outgoing.position.y = maxf(outgoing.position.y,(int(floor_hit.get("height_units",0))+128)*world.CELL_METERS/4096.0)
		check(outgoing.run_source_collision_response(),"Original door collision failed")
		check((int(outgoing.source_ground.get("surface_type",0))&128) != 0,"Connecting door lacks original exit surface")
		world.source_player_movement_state.motion = Vector2i(123,-456)
		world.source_player_movement_state.magnitude = 789
		world.source_input_suppression_count = 7
		var old_map: String = world.map_name
		for step in range(10 if destination == "MP016_05.MAP" else 0):
			check(world.process_source_exit(),"Swimming-entry delay failed")
			check(world.map_name == old_map and world.source_transition_state == 0,"Swimming-entry delay changed room early")
		check(world.process_source_exit(),"Water-transition request failed")
		check(world.source_transition_state == 5 and world.source_fade_phase == "out","Water-transition state/fade mismatch")
		for step in range(11):
			check(world.process_source_exit(),"Water-transition fade failed")
		check(world.map_name == old_map,"Water-transition loaded before fade readiness")
		check(world.process_source_exit(),"Water-transition destination failed")
		var incoming = world.source_player_actor
		check(world.map_name == destination and incoming != outgoing and incoming.vm.fault == "","Water-transition destination controller invalid")
		check(incoming.source_name == ("SwimmingCroc" if destination == "MP016_05.MAP" else "Croc"),"Water-transition selected wrong controller")
		check(world.source_player_movement_state.motion == Vector2i.ZERO and world.source_player_movement_state.magnitude == 0,"Water-transition retained movement")
		check(world.source_input_suppression_count < 7,"Water-transition retained suppression")
		check(world.source_pickup_counts == {1:7,2:1,3:3} and world.source_extended_globals[250] == -12345,"Water-transition lost persistent progress")
		for step in range(120):
			world.tick_source_actors()
			check(world.process_source_exit(),"Water-transition destination update failed")
		check(world.map_name == destination and world.source_fade_phase == "" and world.source_audio_master_gain == 127,"Water-transition arrival bounced or fade did not finish")
		for candidate in world.source_actors:
			check(candidate.vm.fault == "","Water-transition destination actor fault: "+str(candidate.vm.fault))
	world.queue_free()
	await process_frame
	print("PASS: original land/water delay, fades, controller replacement, movement reset and persistent progress")
	quit(0)
