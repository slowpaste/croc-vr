extends "res://probe_first_room_route.gd"
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
	for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
	var prior: int=world.source_player_actor.source_angles.y
	Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors();release_controls()
	var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
	var boxes: Array=world.source_actors.filter(func(actor):return actor.source_name=="SmashBlock")
	var fault := ""
	for box in boxes:
		var instance: int=box.get_instance_id()
		var gems: int=world.source_pickup_counts[1]
		var expected: int=(int(box.vm.parameters[3])>>16)-1
		var reached: Dictionary=await walk_to(world,box.position,right_delta,false,box)
		fault=reached.get("fault","");release_controls()
		if not fault.is_empty():break
		for tick in range(180):
			release_controls()
			if tick in [12,13,14,15,22,23]:Input.action_press("jump")
			world.sample_source_player_controls();world.tick_source_actors()
			if tick%30==0:await process_frame
		release_controls()
		if world.source_actors.any(func(actor):return actor.get_instance_id()==instance):fault="Box remains after stomp"
		if world.source_pickup_counts[1]!=gems+expected:fault="Spawned crystal count differs from box reward"
		print("ORDINARY_BOX_REWARD: ",JSON.stringify({"fault":fault,"expected":expected,"before":gems,"after":world.source_pickup_counts[1]}))
		if not fault.is_empty():break
	print("ORDINARY_BOX_ROUTE: ",JSON.stringify({"fault":fault,"boxes":boxes.size(),"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0 if fault.is_empty() else 1)

