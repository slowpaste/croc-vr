extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var asset: Dictionary = manifest.cutscenePoses[0]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.model)))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var atlas: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == "INTRO.BIN": atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
	var frame: Dictionary = data.frames[0]
	var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
	var geometry := preload("res://source_cutscene_mesh.gd").build(frame,models.models,view,atlas,tables.gameOver.sequenceLighting,{"gpu_color":true})
	assert(not geometry.has("fault") and geometry.vertices == 1620)
	var custom: PackedFloat32Array = geometry.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	assert(custom.size() == 1620)
	var vertex := 0
	for part in frame.parts:
		for face in models.models[int(part.id)].faces:
			for corner in range(6 if face.indices.size() == 4 else 3):
				assert(custom[vertex] == float(int(face.flags)&0x61))
				vertex += 1
	assert(vertex == 1620)
	print("PASS: native textured/blended/flat flags reach every mesh corner without normalized-byte clamping")
	quit(0)
