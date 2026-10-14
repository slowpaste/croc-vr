extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	print("ROOM_ACTOR_SURVEY: ",JSON.stringify(world.source_actors.map(func(a):return {"name":a.source_name,"model":a.model_name,"position":str(a.position),"pc":a.vm.pc,"instruction":a.vm.instructions.get(a.vm.pc,{})})))
	for a in world.source_actors:
		if a.source_name == "DantiniWalk":
			print("DANTINI_SPAWNS: ",JSON.stringify(a.vm.instructions.values().filter(func(i):return int(i.op) in [48,94,176])))
		if a.source_name == "Croc":
			print("PLAYER_ATTACK_TAG_WRITES: ",JSON.stringify(a.vm.instructions.values().filter(func(i):return int(i.pc)>=5749 and int(i.pc)<6030)))
		if a.source_name == "SmashBlockFloatGobbo":
			print("FLOATING_BOX_STRATEGY: ",JSON.stringify(a.vm.instructions.values().filter(func(i):return int(i.pc)<247)))
	var rows: Array=[]
	for z in range(3,19):
		var samples: Array=[]
		for x in range(3,19):
			var floor: Dictionary=world.source_raw_floor_query(Vector3(x,5,z))
			samples.append([x,int(floor.get("surface_type",-1)),int(floor.get("height_units",0))])
		rows.append({"z":z,"samples":samples})
	print("ROOM_FLOOR_GRID: ",JSON.stringify({"room":world.map_name,"rows":rows,"scope":"geometry survey only; direct room entry, no earned traversal claim"}))
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self);quit(0)










