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
	for candidate in manifest.textures:
		if candidate.name == "INTRO.BIN": atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(candidate.file)))
	var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutsceneMeshes[0].file)))
	assert(cache.files.size() == data.frames.size())
	for index in range(data.frames.size()):
		var file: Dictionary = cache.files[index]
		assert(FileAccess.get_sha256(content.path_join(file.file)) == file.sha256)
		var cached: ArrayMesh = load(content.path_join(file.file))
		var frame: Dictionary = data.frames[index]
		var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
		var projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
		projection.ordering = true
		var fresh := preload("res://source_cutscene_mesh.gd").build(frame,models.models,view,atlas,tables.gameOver.sequenceLighting,projection)
		assert(not fresh.has("fault") and cached.surface_get_arrays(0) == fresh.mesh.surface_get_arrays(0))
	print("PASS: all291 compressed private mesh caches preserve exact original generated surface arrays")
	quit(0)
