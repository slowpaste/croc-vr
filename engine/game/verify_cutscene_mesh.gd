extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var asset: Dictionary = manifest.cutscenePoses[0]
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.model)))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var atlas: Dictionary = {}
	for candidate in manifest.textures:
		if candidate.name == "INTRO.BIN": atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(candidate.file)))
	var builder = preload("res://source_cutscene_mesh.gd")
	for index in [0,100,200,290]:
		var frame: Dictionary = poses.frames[index]
		var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
		var result: Dictionary = builder.build(frame,models.models,view,atlas,tables.gameOver.sequenceLighting)
		assert(not result.has("fault") and result.vertices == 1620 and result.mesh.surface_get_array_len(0) == 1620)
		var colors: PackedColorArray = result.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var textured := 0
		for color in colors:
			assert(color.r >= 0.0 and color.r <= 1.0 and color.a in [0.0,1.0])
			if color.a == 0.0: textured += 1
		assert(textured > 0 and textured < colors.size())
	assert(builder.build(poses.frames[0],models.models,{"matrix":[4096,0,0,0,4096,0,0,0,4096],"position":[0,0,0]},{}).has("fault"))
	print("PASS: original SAD face topology and INTRO atlas bind1620 triangle vertices across four poses")
	quit(0)
