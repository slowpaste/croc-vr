extends Node
func _ready() -> void:
	print("SAD_CACHE_CHECK_STARTED")
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0 or option+1 >= args.size(): fail("Missing content path"); return
	var content := str(args[option+1])
	if not FileAccess.file_exists(content.path_join("manifest.json")): fail("Missing content manifest"); return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	if manifest.is_empty() or not manifest.has("runtimeTables") or not manifest.has("cutsceneCompositor"): fail("Invalid content manifest"); return
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_cutscene_content.gd").load_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): fail(str(config.fault)); return
	if not config.has("data") or not config.data.has("frames") or config.data.frames.size()!=291: fail("Missing original SAD frames"); return
	var room_atlas: Dictionary = {}
	for entry in manifest.textures:
		if entry.name == "TK05_TRK.BIN": room_atlas = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
	var cache: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.cutsceneCompositor[0].file)))
	if not cache.has("frames") or cache.frames.size()!=291: fail("Missing compositor frames"); return
	if cache.frames.size() != config.data.frames.size(): fail("Compositor frame count mismatch"); return
	var checked := 0
	for index in range(cache.frames.size()):
		if index%30==0:print("SAD_CACHE_CHECK_FRAME: ",index)
		var plan := preload("res://source_cutscene_frame_plan.gd").build(config,room_atlas,index)
		var frame: Dictionary = cache.frames[index]
		if plan.has("fault") or int(frame.h) != int(plan.h) or frame.passes.size() != plan.passes.size(): fail("Compositor frame plan mismatch at " + str(index)); return
		for pass_index in range(frame.passes.size()):
			var stored: Dictionary = frame.passes[pass_index]
			var fresh: Dictionary = plan.passes[pass_index]
			if stored.kind != fresh.kind: fail("Compositor pass kind mismatch"); return
			if stored.kind == "opaque":
				for source in stored.meshes:
					var commands: Array = []
					for command in fresh.commands:
						if command.source == source: commands.append(command)
					if not check_mesh(content,stored.meshes[source],commands,int(plan.commands)): return
					checked += 1
			else:
				if stored.source != fresh.command.source or int(stored.mode) != int(fresh.mode): fail("Compositor source or mode mismatch"); return
				if not check_mesh(content,stored.mesh,[fresh.command],int(plan.commands)): return
				checked += 1
	if checked!=2619: fail("Unexpected checked mesh count: " + str(checked)); return
	print("PASS: all291 cached compositor plans and",checked," stage meshes retain source order, flags, geometry and SHA256")
	get_tree().quit(0)
func fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
func check_mesh(content: String, entry: Dictionary, commands: Array, total: int) -> bool:
	var path := content.path_join(entry.file)
	if FileAccess.get_sha256(path) != str(entry.sha256): fail("Compositor mesh SHA256 mismatch: " + path); return false
	var stored: ArrayMesh = load(path)
	var fresh := preload("res://source_cutscene_passes.gd").mesh(commands,total)
	if stored == null or stored.surface_get_arrays(0) != fresh.surface_get_arrays(0): fail("Compositor mesh geometry mismatch: " + path); return false
	return true
