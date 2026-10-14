extends SceneTree
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
	var args:=OS.get_cmdline_user_args();var content:String=args[args.find("--content")+1]
	var manifest_path:=content.path_join("manifest.json")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var tables:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config:=preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"):push_error(config.fault);quit(1);return
	var original:Dictionary={}
	for entry in manifest.cutsceneCompositor:
		if entry.name=="SAD":original=entry
	var folder:String="resources/SAD-portals-r1/"+str(original.fingerprint)
	DirAccess.make_dir_recursive_absolute(content.path_join(folder))
	var frames:Array=[]
	for index in range(config.compositor_frames.size()):
		var prepared:=preload("res://source_cutscene_portal.gd").prepare(config.compositor_frames[index])
		var meshes:Dictionary={}
		for key in prepared.meshes:
			var path:String=folder+"/%04d-%s.res"%[index,str(key).replace(":","-")]
			if ResourceSaver.save(prepared.meshes[key],content.path_join(path),ResourceSaver.FLAG_COMPRESS)!=OK:quit(2);return
			meshes[key]={"file":path,"sha256":FileAccess.get_sha256(content.path_join(path))}
		frames.append({"h":prepared.h,"meshes":meshes,"order":prepared.order})
	var file:=FileAccess.open(content.path_join(folder+"/index.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"name":"SAD","revision":1,"fingerprint":original.fingerprint,"frames":frames}));file.close()
	manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	manifest.cutscenePortalMeshes=[{"name":"SAD","revision":1,"fingerprint":original.fingerprint,"file":folder+"/index.json"}]
	file=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(JSON.stringify(manifest));file.close()
	print("PASS: prepared SAD portal frames=",frames.size());quit(0)
