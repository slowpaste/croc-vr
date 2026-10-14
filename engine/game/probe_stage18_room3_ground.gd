extends SceneTree
func _initialize() -> void:call_deferred("inspect_ground")
func inspect_ground() -> void:
	var world=load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	if world.map_name!="MP018_03.MAP":push_error("Expected original room3");quit(1);return
	for z in [5,7,9,11,13]:
		var samples: Array=[]
		for x in [3,4.5,6,7.5,9,10.5,12,13.5,15,16.5,18,19.5,21]:
			var hit: Dictionary=world.source_raw_floor_query(Vector3(x,0,z))
			samples.append({"x":x,"surface":hit.get("surface_type",-1),"height":hit.get("height_units",null)})
		print("STAGE18_ROOM3_GROUND: ",JSON.stringify({"z":z,"samples":samples}))
	print("STAGE18_ROOM3_GROUND_SCOPE: direct original geometry only; no traversal or pickup proof")
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0)
