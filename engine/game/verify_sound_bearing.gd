extends SceneTree
func _initialize() -> void:
	var content := OS.get_cmdline_user_args()[1]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var cases := [[Vector3i(4096,0,0),0,1024],[Vector3i(0,9999,4096),0,0],[Vector3i(0,0,-4096),0,2048],[Vector3i(-4096,0,0),0,3072],[Vector3i(4096,0,0),1024,0],[Vector3i(1,0,0),0,0],[Vector3i(-1,0,0),0,3072],[Vector3i.ZERO,4095,1]]
	for sample in cases:
		var result := preload("res://source_audio_math.gd").listener_bearing(sample[0],Vector3i.ZERO,sample[1],tables.wallAngles.values)
		if result.has("fault") or result.angle!=sample[2]:push_error("Original sound bearing source-derived case mismatch");quit(1);return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-sound-bearing.json"))
	for index in range(0,fixture.observations.size(),2):
		var before: Dictionary = fixture.observations[index]
		var after: Dictionary = fixture.observations[index+1]
		var position := Vector3i(int(before.x),int(before.y),int(before.z))
		var bearing := preload("res://source_audio_math.gd").listener_bearing(position,Vector3i.ZERO,int(before.yaw),tables.wallAngles.values)
		var distance := preload("res://source_audio_math.gd").listener_metrics(position,Vector3i.ZERO,tables.distanceRoot.values)
		if bearing.has("fault") or distance.has("fault") or bearing.angle!=int(after.angle) or distance.distance!=int(after.distance):
			push_error("Original sound distance/bearing runtime mismatch");quit(1);return
	print("PASS: eight complete original sound distance/bearing routine captures")
	quit(0)
