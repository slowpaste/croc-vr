extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-view-direction.json"))
	for index in range(0,fixture.observations.size(),2):
		var before: Dictionary = fixture.observations[index]
		var after: Dictionary = fixture.observations[index+1]
		var result := preload("res://source_camera_view_direction.gd").angles(Vector3i(int(before.x),int(before.y),int(before.z)),Vector3i(int(before.tx),int(before.ty),int(before.tz)),int(before.yaw),world.runtime_tables.distanceRoot.values,world.runtime_tables.wallAngles.values)
		if result.has("fault") or int(result.pitch)!=int(after.pitch) or int(result.yaw)!=int(after.yaw) or int(result.roll)!=int(after.roll):
			push_error("Original view direction mismatch: "+str(before)+" result="+str(result)+" expected="+str(after));quit(1);return
		world.source_camera_state = {"position":Vector3i(int(before.x),int(before.y),int(before.z)),"look_position":Vector3i(int(before.tx),int(before.ty),int(before.tz)),"yaw":int(before.yaw)}
		if not world.publish_source_camera_view_direction() or world.source_camera_state.pitch!=int(after.pitch) or world.source_camera_state.yaw!=int(after.yaw) or world.source_camera_state.roll!=0:
			push_error("World view-direction publication mismatch");quit(1);return
	world.queue_free();await process_frame
	print("PASS: all eight original final view pitch/yaw/roll outputs match")
	quit(0)
