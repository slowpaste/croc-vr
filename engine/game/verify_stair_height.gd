extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	assert(world.load_room("MP011_01.MAP"))
	var elevated := 0
	for tile in world.room_data.tracks:
		if int(tile.source_height) != 8: continue
		elevated += 1
		assert(is_equal_approx(float(tile.position[1])*world.CELL_METERS,5.25))
		var hits = world.terrain_surfaces_at(Vector3(float(tile.position[0])+0.5,0,float(tile.position[2])+0.5)*world.CELL_METERS)
		for hit in hits:
			assert(int(hit.height_units)<20000,"Collision still uses unscaled upper terrain")
	assert(elevated==26)
	world.queue_free()
	await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: second-level upper terrain uses original 896-unit height scale in rendering and collision")
	quit(0)
