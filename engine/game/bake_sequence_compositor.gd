extends SceneTree
func _initialize() -> void: call_deferred("bake")
func bake() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1]); option = args.find("--scene")
	if option < 0: quit(1); return
	var scene := int(args[option+1])
	var manifest_path := content.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config.fault)); quit(1); return
	var fingerprint := preload("res://source_sequence_cache_identity.gd").fingerprint(config,tables)
	var directory := "resources/sequence-%02d-compositor/"%scene+fingerprint
	if DirAccess.make_dir_recursive_absolute(content.path_join(directory)) != OK: quit(1); return
	var parts: Array = []; var meshes := 0
	for part_index in range(config.parts.size()):
		var part: Dictionary = config.parts[part_index]; var frames: Array = []
		for index in range(part.data.frames.size()):
			var plan := preload("res://source_cutscene_frame_plan.gd").build(part,part.room_atlas,index)
			if plan.has("fault") or bool(plan.point_lighting_required): push_error("Unqualified sequence frame: "+str(plan)); quit(1); return
			var passes: Array = []
			for pass_index in range(plan.passes.size()):
				var pass_data: Dictionary = plan.passes[pass_index]
				if pass_data.kind == "opaque":
					var entries := {}
					for source in ["actor","room","sky"]:
						var commands: Array = []
						for command in pass_data.commands:
							if command.source == source: commands.append(command)
						if commands.is_empty(): continue
						var file := directory+"/%02d-%04d-%02d-%s.res"%[part_index,index,pass_index,source]
						if ResourceSaver.save(preload("res://source_cutscene_passes.gd").mesh(commands,int(plan.commands)),content.path_join(file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
						entries[source] = {"file":file,"sha256":FileAccess.get_sha256(content.path_join(file))}; meshes += 1
					passes.append({"kind":"opaque","meshes":entries})
				else:
					var file := directory+"/%02d-%04d-%02d-blend.res"%[part_index,index,pass_index]
					if ResourceSaver.save(preload("res://source_cutscene_passes.gd").mesh([pass_data.command],int(plan.commands)),content.path_join(file),ResourceSaver.FLAG_COMPRESS) != OK: quit(1); return
					passes.append({"kind":"blend","source":pass_data.command.source,"mode":int(pass_data.mode),"mesh":{"file":file,"sha256":FileAccess.get_sha256(content.path_join(file))}}); meshes += 1
			frames.append({"index":index,"h":int(plan.h),"passes":passes,"commands":int(plan.commands),"blended":int(plan.blended)})
		parts.append({"frames":frames})
		print("SEQUENCE_CACHE_PART: ",scene,"/",part_index," frames=",frames.size())
	var descriptor := directory+"/index.json"
	var output := FileAccess.open(content.path_join(descriptor),FileAccess.WRITE); output.store_string(JSON.stringify({"scene_id":scene,"fingerprint":fingerprint,"parts":parts})); output.close()
	# Cache generation can outlast other imports; publish against current metadata.
	manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var entries: Array = manifest.get("cutsceneSequenceCaches",[])
	entries = entries.filter(func(entry): return int(entry.scene_id) != scene)
	entries.append({"scene_id":scene,"file":descriptor,"fingerprint":fingerprint})
	manifest.cutsceneSequenceCaches = entries
	output = FileAccess.open(manifest_path,FileAccess.WRITE); output.store_string(JSON.stringify(manifest)); output.close()
	print("SEQUENCE_CACHE: ",{"scene":scene,"parts":parts.size(),"meshes":meshes,"fingerprint":fingerprint})
	quit(0)
