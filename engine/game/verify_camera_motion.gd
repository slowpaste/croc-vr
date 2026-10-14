extends SceneTree
func _initialize() -> void:
	var motion = preload("res://source_camera_motion.gd")
	for path in ["original-camera-yaw-neptuna.json","original-camera-yaw-boundaries.json"]:
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/"+path))
		assert(fixture.observations.size() == 16)
		for observation in fixture.observations:
			var result: Dictionary = motion.yaw_step(int(observation.current),int(observation.target),int(observation.velocity),int(observation.accel),int(observation.ease),int(observation.limit))
			assert(not result.has("fault"))
			assert(result.yaw == int(observation.result) and result.velocity == int(observation.next_velocity))
	assert(motion.yaw_step(0,10,0,-1,4,128).has("fault"))
	assert(motion.yaw_step(0,10,0,6,32,128).has("fault"))
	assert(motion.yaw_step(0,10,0,6,4,-1).has("fault"))
	var rates_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-rates.json"))
	assert(rates_fixture.observations.size() == 16)
	for observation in rates_fixture.observations:
		var rates: Dictionary = motion.rates(int(observation.stage),int(observation.mode),int(observation.manual),int(observation.orbit),int(observation.override)!=0,int(observation.collision))
		assert(rates.acceleration_shift == int(observation.accel) and rates.easing_shift == int(observation.ease))
		assert(rates.yaw_limit == int(observation.limit) and rates.position_shift == int(observation.position) and rates.height_shift == int(observation.height))
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-targets.json"))
	assert(targets.observations.size() == 16)
	for observation in targets.observations:
		var result: Dictionary = motion.target_state(int(observation.actor),int(observation.bearing),int(observation.measured),int(observation.manual),int(observation.orbit),int(observation.base),int(observation.held),int(observation.pressed))
		assert(result.target_yaw == int(observation.target) and result.distance == int(observation.distance))
		assert(result.manual_yaw == int(observation.next_manual) and result.obstruction_enabled == (int(observation.obstruction)!=0))
	var overrides: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-overrides.json"))
	assert(overrides.observations.size() == 16)
	for observation in overrides.observations:
		var result: Dictionary = motion.target_state(int(observation.actor),0,0,int(observation.manual),0,int(observation.base),0x400a0000,0x40000000,{"bearing":int(observation.bearing),"distance":int(observation.measured)})
		assert(result.target_yaw == int(observation.target) and result.distance == int(observation.distance))
		assert(result.manual_yaw == int(observation.next_manual) and result.obstruction_enabled == (int(observation.obstruction)!=0))
	var distances: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-distances.json"))
	assert(distances.observations.size() == 16)
	for observation in distances.observations:
		var result: Dictionary = motion.distance_step(int(observation.current),int(observation.target),int(observation.velocity),int(observation.accel),int(observation.ease))
		assert(result.distance == int(observation.distance) and result.velocity == int(observation.next_velocity))
	var heights: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-heights.json"))
	assert(heights.observations.size() == 16)
	for observation in heights.observations:
		var result: Dictionary = motion.height_step(int(observation.current),int(observation.desired),int(observation.minimum),int(observation.velocity))
		assert(result.height == int(observation.height) and result.velocity == int(observation.next_velocity))
	var orbits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-orbits.json"))
	assert(orbits.observations.size() == 16)
	for observation in orbits.observations:
		var result: Dictionary = motion.orbit_step(int(observation.offset),int(observation.counter),int(observation.bits),int(observation.enabled)!=0,int(observation.ceiling)!=0)
		assert(result.orbit_offset == int(observation.result) and result.query_counter == int(observation.next_counter))
	print("PASS: camera motion matches128 native yaw/rate/target/override/distance/height/orbit cases")
	quit(0)
