extends SceneTree
func _initialize() -> void:
	call_deferred("probe")
func probe() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(30):
		await physics_frame
	world.set_physics_process(false)
	var factor: int = world.runtime_tables.mapYScale.values[int(world.room_data.style)]
	var request: Dictionary = {}
	var destination_filter := ""
	var arguments := OS.get_cmdline_user_args()
	var option := arguments.find("--probe-destination")
	if option >= 0 and option+1 < arguments.size():
		destination_filter = arguments[option+1]
	for door in world.room_data.doors:
		var position: Vector3 = Vector3(int(door.position[0])*4096,int(door.position[1])*factor*8,int(door.position[2])*4096)*world.CELL_METERS/4096.0
		var floor_hit: Dictionary = world.source_floor_at(position)
		print("SOURCE_DOOR_SURFACE: ",JSON.stringify({"door":door,"floor":floor_hit}))
		if int(floor_hit.get("surface_type",0)) == 128 and world.source_player_actor != null:
			var player = world.source_player_actor
			player.position = position
			var collision_ok: bool = player.run_source_collision_response()
			var candidate: Dictionary = world.source_exit_request(player)
			if destination_filter.is_empty() or str(candidate.get("destination","")) == destination_filter:
				request = candidate
			print("SOURCE_EXIT_REQUEST: ",JSON.stringify({"collision_ok":collision_ok,"ground":player.source_ground,"request":candidate}))
	if OS.get_cmdline_user_args().has("--probe-load") and bool(request.get("transition",false)):
		var player = world.source_player_actor
		world.source_ground_mode_80_value = request.counter
		var loaded: bool = world.load_room(request.destination,int(request.origin.id),request.origin)
		var arrival_player = world.create_source_player() if loaded else null
		var valid: bool = arrival_player != null and arrival_player != player and world.source_actors.count(arrival_player) == 1 and world.source_pool.slots[world.source_player_id].node == arrival_player and arrival_player.vm.fault == ""
		if valid:
			for tick in range(10):
				world.tick_source_actors()
			valid = arrival_player.vm.fault == ""
		if arrival_player != null:
			print("SOURCE_ARRIVAL_SCRIPT: ",JSON.stringify({"pc":arrival_player.vm.pc,"fault":arrival_player.vm.fault,"status":arrival_player.vm.status}))
		var actor_faults: Array = []
		for candidate in world.source_actors:
			if candidate.vm.fault != "":
				actor_faults.append({"name":candidate.source_name,"pc":candidate.vm.pc,"fault":candidate.vm.fault})
		print("SOURCE_ARRIVAL_ACTORS: ",JSON.stringify(actor_faults))
		print("SOURCE_ARRIVAL_ROOM: ",JSON.stringify({"loaded":loaded,"new_player_valid":valid,"map":world.map_name,"arrival":world.source_player_entry_state,"position":str(arrival_player.position) if arrival_player != null else "","yaw":arrival_player.source_angles.y if arrival_player != null else -1}))
		if not loaded or not valid:
			world.queue_free()
			await process_frame
			quit(1)
			return
	world.queue_free()
	await process_frame
	quit(0)
