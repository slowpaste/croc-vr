extends SceneTree
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var scene:=int(args[args.find("--scene")+1]) if args.has("--scene") else 0
	var manifest_path:=content.path_join("manifest.json")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config:=preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,scene,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"):push_error(config.fault);quit(1);return
	var descriptor:Dictionary={}
	for entry in manifest.cutsceneSequenceCaches:
		if int(entry.scene_id)==scene:descriptor=entry
	var cache:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(descriptor.file)))
	var folder:String="resources/sequence-%02d-portals-r1/"%scene+str(descriptor.fingerprint)
	DirAccess.make_dir_recursive_absolute(content.path_join(folder))
	var parts:Array=[]
	for part_index in range(cache.parts.size()):
		var frames:Array=[]
		for index in range(cache.parts[part_index].frames.size()):
			var loaded:=preload("res://source_cutscene_compositor_cache.gd").frames(content,{"frames":[cache.parts[part_index].frames[index]]})
			if loaded.has("fault"):push_error(loaded.fault);quit(2);return
			var corrected:=preload("res://source_sequence_sky_correction.gd").apply(loaded.frames[0],config.parts[part_index],index)
			if corrected.has("fault"):push_error(corrected.fault);quit(3);return
			var prepared:=preload("res://source_cutscene_portal.gd").prepare(corrected)
			var meshes:Dictionary={}
			for key in prepared.meshes:
				var file:String=folder+"/%02d-%04d-%s.res"%[part_index,index,str(key).replace(":","-")]
				if ResourceSaver.save(prepared.meshes[key],content.path_join(file),ResourceSaver.FLAG_COMPRESS)!=OK:quit(4);return
				meshes[key]={"file":file,"sha256":FileAccess.get_sha256(content.path_join(file))}
			frames.append({"h":prepared.h,"meshes":meshes,"order":prepared.order})
		parts.append({"frames":frames})
		print("PORTAL_BAKE_PART: ",part_index," frames=",frames.size())
	var file:=FileAccess.open(content.path_join(folder+"/index.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene_id":scene,"revision":1,"fingerprint":descriptor.fingerprint,"parts":parts}));file.close()
	var entry:Dictionary={"scene_id":scene,"revision":1,"fingerprint":descriptor.fingerprint,"file":folder+"/index.json"}
	manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	manifest.cutsceneSequencePortalCaches=manifest.get("cutsceneSequencePortalCaches",[]).filter(func(existing):return int(existing.scene_id)!=scene)
	manifest.cutsceneSequencePortalCaches.append(entry)
	file=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest));file.close()
	print("PASS: prepared opening portal meshes with original clipping, sky, UVs, colors and depth")
	quit(0)
