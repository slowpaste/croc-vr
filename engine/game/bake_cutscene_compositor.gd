extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest_path := content.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config)); quit(1); return
	var room_atlas: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == "TK05_TRK.BIN": room_atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	for value in [config.data,config.models,config.room,config.track_models,config.anchor,config.room_lighting,config.atlas,config.sky_models,config.sky_atlas,room_atlas,tables]: hash.update(JSON.stringify(value).to_utf8_buffer())
	for file in ["source_cutscene_frame_plan.gd","source_cutscene_passes.gd","source_cutscene_mesh.gd","source_cutscene_depth.gd","source_gte_projection.gd","source_cutscene_culling.gd","source_cutscene_frame.gd","source_cutscene_view.gd","source_cutscene_transform.gd","source_rotation.gd","source_cutscene_lighting.gd","source_gte_lighting.gd","source_cutscene_sky.gd","asl_vm.gd"]: hash.update(FileAccess.get_file_as_bytes("res://"+file))
	var fingerprint := hash.finish().hex_encode()
	var directory := "resources/cutscene-SAD-compositor/"+fingerprint
	if DirAccess.make_dir_recursive_absolute(content.path_join(directory)) != OK: quit(1); return
	var frames: Array = []
	var mesh_count := 0
	for index in range(config.data.frames.size()):
		var plan := preload("res://source_cutscene_frame_plan.gd").build(config,room_atlas,index)
		if plan.has("fault"): push_error(str(plan)); quit(1); return
		var passes: Array = []
		for pass_index in range(plan.passes.size()):
			var pass_data: Dictionary = plan.passes[pass_index]
			if pass_data.kind == "opaque":
				var meshes := {}
				for source in ["sky","room","actor"]:
					var commands: Array = []
					for command in pass_data.commands:
						if command.source == source: commands.append(command)
					if commands.is_empty(): continue
					var file := directory+"/%04d-%02d-%s.res" % [index,pass_index,source]
					var mesh := preload("res://source_cutscene_passes.gd").mesh(commands,int(plan.commands))
					if ResourceSaver.save(mesh,content.path_join(file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
					meshes[source] = {"file":file,"sha256":FileAccess.get_sha256(content.path_join(file))}; mesh_count += 1
				passes.append({"kind":"opaque","meshes":meshes})
			else:
				var file := directory+"/%04d-%02d-blend.res" % [index,pass_index]
				var mesh := preload("res://source_cutscene_passes.gd").mesh([pass_data.command],int(plan.commands))
				if ResourceSaver.save(mesh,content.path_join(file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
				passes.append({"kind":"blend","source":pass_data.command.source,"mode":int(pass_data.mode),"mesh":{"file":file,"sha256":FileAccess.get_sha256(content.path_join(file))}}); mesh_count += 1
		frames.append({"index":index,"h":int(plan.h),"passes":passes,"commands":int(plan.commands),"blended":int(plan.blended)})
	var descriptor := directory+"/index.json"
	var output := FileAccess.open(content.path_join(descriptor),FileAccess.WRITE)
	output.store_string(JSON.stringify({"fingerprint":fingerprint,"frames":frames})); output.close()
	manifest.cutsceneCompositor = [{"name":"SAD","file":descriptor,"fingerprint":fingerprint}]
	output = FileAccess.open(manifest_path,FileAccess.WRITE); output.store_string(JSON.stringify(manifest)); output.close()
	print("SAD_COMPOSITOR_CACHE: ",{"frames":frames.size(),"meshes":mesh_count,"fingerprint":fingerprint})
	quit(0)
