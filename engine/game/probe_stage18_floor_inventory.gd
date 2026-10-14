extends SceneTree
func _initialize() -> void:call_deferred("inspect_floors")
func inspect_floors() -> void:
	var world=load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false);world.set_physics_process(false)
	if world.map_name!="MP018_04.MAP":push_error("Expected stage18 silver-key room");quit(1);return
	for z in [12,15,16.5,18,19.5,21,22.5,24]:
		var row: Array=[]
		for x in [3,4.5,6,7.5,9,10.5,12,13.5,15,16.5,18]:
			var hit: Dictionary=world.source_raw_floor_query(Vector3(x,10,z))
			row.append({"x":x,"surface":hit.get("surface_type",-1),"height":hit.get("height_units",-1),"tile":hit.get("tile",-1)})
		print("STAGE18_FLOOR_ROW: ",JSON.stringify({"z":z,"samples":row}))
	print("STAGE18_FLOOR_SCOPE: direct room geometry inspection only; no traversal or pickup proof")
	world.stop_imported_audio();world.queue_free();await process_frame
	await preload("res://source_spu_stream_retirement.gd").drain(self)
	quit(0)
