extends SceneTree
func _initialize() -> void:call_deferred("inspect_ground")
func inspect_ground() -> void:
	var world=load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	if world.map_name!="MP018_05.MAP":push_error("Expected original room5");quit(1);return
	for z in [6,7.35,9,10.5,12]:
		var row: Array=[]
		for x in [27,28,28.5,29,29.4,30,31.875,33]:
			var point := Vector3(x,3.6,z)
			row.append({"x":x,"query":world.source_raw_floor_query(point)})
		print("STAGE18_EAST_GROUND: ",JSON.stringify({"z":z,"samples":row}))
	print("STAGE18_EAST_SCOPE: direct room geometry inspection only; no traversal, key or pickup proof")
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0)
