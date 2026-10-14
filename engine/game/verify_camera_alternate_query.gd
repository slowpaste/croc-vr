extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(world.map_name == "MP033_02.MAP")
	var geometry: Dictionary = world.source_camera_geometry()
	assert(not geometry.has("fault") and int(geometry.tracks[7].index) == 2)
	assert(int(geometry.models[2].collision.counts[0]) == 1)
	# Native protected33/2 frame1841, normal query yaw90 (camera-normal-probes.log).
	var expected: Array[Vector3i] = [Vector3i(16756,8192,12181),Vector3i(15996,8192,12287),Vector3i(16376,8192,12234),Vector3i(16585,8192,11882),Vector3i(16078,8192,11952),Vector3i(16332,8192,11917)]
	assert(world.source_camera_probe_points(Vector3i(16350,8704,12044),90) == expected)
	var probes: Dictionary = world.source_camera_probe_lower_queries(Vector3i(16350,8704,12044),90)
	assert(not probes.has("fault") and probes.lower_blocking_bits == 0)
	for index in range(6):
		assert(int(probes.lower[index].tile) == 7 and int(probes.lower[index].record) == 0 and int(probes.lower[index].height_units) == 0)
	# Controlled native normal query: same X/Z/yaw, camera Y0 => flags63.
	var below_floor: Dictionary = world.source_camera_probe_lower_queries(Vector3i(16350,0,12044),90)
	assert(not below_floor.has("fault") and below_floor.lower_blocking_bits == 63)
	# Native cached crossing: camera18200/0/12288 ->17982/0/12288, flags63.
	var crossing: Array[Vector3i] = world.source_camera_probe_points(Vector3i(18200,0,12288),90)
	var local_point := Vector2i(crossing[0].x-16384,crossing[0].z-12288)
	var push := preload("res://source_camera_wall.gd").edge_push(geometry.models[2].collision.groups[0][0],local_point,0)
	assert(not push.has("fault") and push.delta == Vector2i(-218,0))
	var accumulated := preload("res://source_camera_wall.gd").accumulated_edge_push(geometry.models[2].collision.groups[0][0],local_point,0,world.runtime_tables.trigonometry.quarterSine)
	assert(not accumulated.has("fault") and accumulated.world_delta == Vector2i(-218,0))
	# Captured native corner returns17982/0/14066 from18200/0/14200.
	var corner_points: Array[Vector3i] = world.source_camera_probe_points(Vector3i(18200,0,14200),90)
	var corner := preload("res://source_camera_wall.gd").accumulated_probe_pushes(geometry.models[2].collision.groups[0][0],corner_points,Vector2i(16384,12288),0,world.runtime_tables.trigonometry.quarterSine)
	assert(not corner.has("fault") and corner.delta == Vector2i(-218,-134))
	var prior: Array = []
	for index in range(6): prior.append({"tile":7,"record":0})
	var cached_crossing: Dictionary = world.source_camera_probe_lower_queries(Vector3i(18200,0,12288),90,prior)
	assert(cached_crossing.routes[0] == 3 and below_floor.routes[0] == 2)
	# Fresh native crossing selects tile8 centered at20480/12288, model2.
	var fresh := preload("res://source_camera_wall.gd").fresh_accumulated_push(geometry.models[2].collision.groups[0][0],Vector2i(18200-20480,0),Vector2i(crossing[0].x-20480,crossing[0].z-12288),0,world.runtime_tables.trigonometry.quarterSine)
	assert(not fresh.has("fault") and fresh.world_delta == Vector2i(-176,0))
	var normal_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-normal-cases.json"))
	assert(normal_fixture.sourceSha256 == world.manifest.sourceSha256)
	for observation in normal_fixture.observations:
		var point_caches: Array = []
		for index in range(6): point_caches.append({"lower":{"tile":7 if int(observation.cached) != 0 else -1,"record":0},"upper":{"tile":-1,"record":0}})
		var query: Dictionary = world.source_camera_collision_phase({"position":Vector3i(int(observation.x),int(observation.y),int(observation.z)),"yaw":int(observation.yaw),"point_caches":point_caches,"query_counter":0})
		assert(not query.has("fault"))
		assert(query.position.x == int(observation.next_x) and query.position.z == int(observation.next_z))
		assert(query.height == int(observation.height) and query.collision_bits == int(observation.bits))
		assert(query.camera_state.query_counter == 0)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-alternate-queries.json"))
	assert(fixture.sourceSha256 == world.manifest.sourceSha256 and fixture.observations.size() == 16)
	for observation in fixture.observations:
		var point_caches: Array = []
		for index in range(6): point_caches.append({"lower":{"tile":7,"record":77},"upper":{"tile":-1,"record":23}})
		var result: Dictionary = world.source_camera_collision_phase({"position":Vector3i(int(observation.x),int(observation.y),int(observation.z)),"query_counter":1,"point_caches":point_caches,"center_cache":{"lower":{"tile":int(observation.lt),"record":int(observation.lr)},"upper":{"tile":int(observation.ut),"record":int(observation.ur)}}})
		assert(result.camera_state.query_counter == 1)
		for point in result.camera_state.point_caches:
			assert(point.lower.tile == -1 and point.lower.record == 77 and point.upper.record == 23)
		if result.has("fault") or result.height != int(observation.height) or result.collision_bits != int(observation.bits) or result.cache.lower.tile != int(observation.next_lt) or result.cache.upper.tile != int(observation.next_ut):
			push_error("Alternate camera query differs from native: "+JSON.stringify({"original":observation,"actual":result}));quit(1);return
		if int(observation.next_lt) >= 0: assert(result.cache.lower.record == int(observation.next_lr))
		if int(observation.next_ut) >= 0: assert(result.cache.upper.record == int(observation.next_ur))
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: 16 native alternate and 16 fresh/retained normal queries, state phase, positions/heights/flags and edge primitives")
	quit(0)
