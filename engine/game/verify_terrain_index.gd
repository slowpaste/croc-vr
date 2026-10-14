extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var full:Dictionary={"tracks":world.room_data.tracks,"models":world.terrain_models}
	var samples:=0
	for tile in world.room_data.tracks:
		for dx in [-2176,-2175,-2048,0,2048,2175,2176]:
			for dz in [-2176,-2175,0,2175,2176]:
				var point:Vector3=Vector3(int(tile.position[0])*4096+dx,0,int(tile.position[2])*4096+dz)*world.CELL_METERS/4096.0
				assert(world.terrain_surfaces_at(point)==world.terrain_surfaces_at(point,full))
				samples+=1
	world.queue_free();await process_frame
	print("PASS: indexed terrain matches full native scan at ",samples," tile centers, seams and strict-radius boundaries")
	quit(0)
