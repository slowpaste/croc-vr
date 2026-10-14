extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0: quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-horizontal.json"))
	assert(fixture.sourceSha256 == manifest.sourceSha256 and fixture.observations.size() == 16)
	var motion = preload("res://source_camera_motion.gd")
	for observation in fixture.observations:
		var result: Dictionary = motion.horizontal_position(Vector3i(int(observation.x),0,int(observation.z)),int(observation.yaw),int(observation.distance),tables.trigonometry.quarterSine)
		assert(not result.has("fault"))
		assert(result.position == Vector2i(int(observation.result_x),int(observation.result_z)))
	assert(motion.horizontal_position(Vector3i.ZERO,0,4096,[]).has("fault"))
	print("PASS: camera horizontal placement matches16 corrected native varied-angle/overflow observations")
	quit(0)
