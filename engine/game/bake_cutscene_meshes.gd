extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1]).simplify_path()
	var manifest_path := content.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var asset: Dictionary = manifest.cutscenePoses[0]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.model)))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var texture: Dictionary = {}
	for candidate in manifest.textures:
		if candidate.name == "INTRO.BIN": texture = candidate
	if texture.is_empty(): quit(1); return
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(texture.file)))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for file in [asset.file,asset.model,manifest.runtimeTables,texture.file]: hash.update(FileAccess.get_file_as_bytes(content.path_join(file)))
	for file in ["source_cutscene_mesh.gd","source_cutscene_lighting.gd","source_gte_lighting.gd","source_cutscene_transform.gd","source_cutscene_view.gd","source_rotation.gd","asl_vm.gd","source_gte_projection.gd","source_cutscene_culling.gd","source_cutscene_frame.gd"]: hash.update(FileAccess.get_file_as_bytes("res://"+file))
	hash.update(FileAccess.get_file_as_bytes("res://source_cutscene_depth.gd"))
	var fingerprint := hash.finish().hex_encode()
	var directory := "resources/cutscene-SAD-meshes/"+fingerprint
	if DirAccess.make_dir_recursive_absolute(content.path_join(directory)) != OK: quit(1); return
	var files: Array = []
	for index in range(data.frames.size()):
		var frame: Dictionary = data.frames[index]
		var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
		var projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
		projection.ordering = true
		var geometry := preload("res://source_cutscene_mesh.gd").build(frame,models.models,view,atlas,tables.gameOver.sequenceLighting,projection)
		if geometry.has("fault"): push_error(str(geometry)); quit(1); return
		var file := directory+"/%04d.res"%index
		if ResourceSaver.save(geometry.mesh,content.path_join(file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
		files.append({"file":file,"sha256":FileAccess.get_sha256(content.path_join(file))})
	var descriptor := directory+"/index.json"
	var output := FileAccess.open(content.path_join(descriptor),FileAccess.WRITE)
	if output == null: quit(1); return
	output.store_string(JSON.stringify({"fingerprint":fingerprint,"files":files,"records":files.size(),"ordering":true})); output.close()
	manifest.cutsceneMeshes = [{"name":"SAD","file":descriptor,"fingerprint":fingerprint}]
	output = FileAccess.open(manifest_path,FileAccess.WRITE)
	if output == null: quit(1); return
	output.store_string(JSON.stringify(manifest)); output.close()
	print("CUTSCENE_MESH_CACHE: ",{"records":files.size(),"fingerprint":fingerprint})
	quit(0)
