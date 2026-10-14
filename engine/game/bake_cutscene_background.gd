extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest_path := content.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[128,128,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config)); quit(1); return
	var texture: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == "TK05_TRK.BIN": texture = entry
	if texture.is_empty(): quit(1); return
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(texture.file)))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for value in [config.data,config.room,config.track_models,config.anchor,config.room_lighting,atlas,tables,config.sky_models,config.sky_atlas]: hash.update(JSON.stringify(value).to_utf8_buffer())
	hash.update(FileAccess.get_file_as_bytes("res://source_cutscene_sky.gd"))
	for file in ["source_cutscene_mesh.gd","source_cutscene_lighting.gd","source_gte_lighting.gd","source_cutscene_transform.gd","source_cutscene_view.gd","source_rotation.gd","asl_vm.gd","source_cutscene_tiles.gd"]: hash.update(FileAccess.get_file_as_bytes("res://"+file))
	for file in ["source_cutscene_depth.gd","source_gte_projection.gd","source_cutscene_culling.gd","source_cutscene_frame.gd"]: hash.update(FileAccess.get_file_as_bytes("res://"+file))
	var fingerprint := hash.finish().hex_encode()
	var directory := "resources/cutscene-SAD-background/"+fingerprint
	if DirAccess.make_dir_recursive_absolute(content.path_join(directory)) != OK: quit(1); return
	var files: Array = []
	for index in range(config.data.frames.size()):
		var camera: Dictionary = config.data.frames[index].camera
		var anchored := preload("res://source_cutscene_view.gd").anchored_camera(camera,config.anchor.position,int(config.anchor.yaw),tables.rotation.pairs)
		var view := preload("res://source_cutscene_view.gd").camera_view(anchored,tables.rotation.pairs)
		var actor_projection := preload("res://source_cutscene_frame.gd").projection(int(camera.projectionDistance))
		actor_projection.ordering = true
		var actor_view := preload("res://source_cutscene_view.gd").parts_view(camera,tables.rotation.pairs)
		var actor_mesh := preload("res://source_cutscene_mesh.gd").build(config.data.frames[index],config.models.models,actor_view,config.atlas,tables.gameOver.sequenceLighting,actor_projection)
		if actor_mesh.has("fault"): push_error(str(actor_mesh)); quit(1); return
		var projection := actor_projection.duplicate()
		projection.terrain = true
		projection.tie_base = int(actor_mesh.primitive_count)
		var geometry := preload("res://source_cutscene_mesh.gd").build(config.tiles,config.track_models.models,view,atlas,config.room_lighting,projection)
		if geometry.has("fault"): push_error(str(geometry)); quit(1); return
		var file := directory+"/%04d.res"%index
		if ResourceSaver.save(geometry.mesh,content.path_join(file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
		var sky_frame := preload("res://source_cutscene_sky.gd").frame(anchored,config.sky_models.models.size())
		var sky := preload("res://source_cutscene_mesh.gd").build(sky_frame,config.sky_models.models,view,config.sky_atlas)
		if sky.has("fault"): push_error(str(sky)); quit(1); return
		var sky_file := directory+"/sky-%04d.res"%index
		if ResourceSaver.save(sky.mesh,content.path_join(sky_file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
		files.append({"file":file,"sha256":FileAccess.get_sha256(content.path_join(file)),"vertices":geometry.vertices,"sky_file":sky_file,"sky_sha256":FileAccess.get_sha256(content.path_join(sky_file))})
	var descriptor := directory+"/index.json"
	var output := FileAccess.open(content.path_join(descriptor),FileAccess.WRITE)
	output.store_string(JSON.stringify({"fingerprint":fingerprint,"files":files,"records":files.size(),"ordering":true})); output.close()
	manifest.cutsceneBackgroundMeshes = [{"name":"SAD","file":descriptor,"fingerprint":fingerprint,"texture":"TK05_TRK.BIN"}]
	output = FileAccess.open(manifest_path,FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest)); output.close()
	print("CUTSCENE_BACKGROUND_CACHE: ",{"records":files.size(),"fingerprint":fingerprint})
	quit(0)
