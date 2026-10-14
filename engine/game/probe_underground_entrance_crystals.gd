extends "res://probe_first_room_route.gd"
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var prior: int=world.source_player_actor.source_angles.y
	Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors();release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var fault := ""
	for waypoint in [Vector3(1.5,0,4.5),Vector3(10.5,0,4.5)]:
		var reached: Dictionary=await walk_to(world,waypoint,right_delta)
		fault=reached.get("fault","");release_controls()
		if not fault.is_empty():break
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	for index in range(13,19):
		if (int(world.source_map_entity_flags.get(world.map_name,{}).get(index,0))&4)==0:fault="Missing entrance crystal marker "+str(index)
	print("UNDERGROUND_ENTRANCE_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if fault.is_empty() else 1)
