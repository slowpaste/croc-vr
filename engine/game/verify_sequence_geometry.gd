extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var builder = preload("res://source_cutscene_mesh.gd")
	var checked := 0
	for entry in manifest.cutsceneSequences:
		var scene_id := -1
		for index in range(tables.gameOver.sequenceScenes.records.size()):
			if tables.gameOver.sequenceScenes.records[index].prefix == entry.name: scene_id = index; break
		var binding := preload("res://source_cutscene_resources.gd").resolve(scene_id,tables,manifest)
		if binding.has("fault"): push_error(str(binding.fault)); quit(1); return
		var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(binding.texture.file)))
		var sequence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(entry.file)))
		for part in sequence.parts:
			var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(part.model)))
			for index in [0,int(part.frames.size()/2),part.frames.size()-1]:
				var frame: Dictionary = part.frames[index]
				var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
				var projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
				projection.ordering = true; projection.commands = true; projection.gpu_color = true
				var mesh := builder.build(frame,pack.models,view,atlas,tables.gameOver.sequenceLighting,projection)
				if mesh.has("fault") or int(mesh.vertices) <= 0:
					push_error("Sequence pose/atlas/lighting failed: "+part.name+" frame "+str(index)+" "+str(mesh.get("fault","Empty geometry"))); quit(1); return
				checked += 1
		print("SEQUENCE_GEOMETRY: ",entry.name," parts=",sequence.parts.size())
	print("PASS: ",checked," first/middle/last poses across every original sequence part bind actor instances, atlas, lighting and projection")
	quit(0)
