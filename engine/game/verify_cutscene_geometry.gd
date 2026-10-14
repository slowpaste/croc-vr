extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var asset: Dictionary = {}
	for candidate in manifest.cutscenePoses:
		if candidate.name == "SAD": asset = candidate
	if asset.is_empty(): quit(1); return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.file)))
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(asset.model)))
	var transform = preload("res://source_cutscene_transform.gd")
	var view := {"matrix":[4096,0,0,0,4096,0,0,0,4096],"position":[0,0,0]}
	var point_count := 0
	for frame in data.frames:
		for part in frame.parts:
			var result: Dictionary = transform.vertices(part,models.models[int(part.id)],view)
			if result.has("fault") or result.vertices.size() != models.models[int(part.id)].vertices.size(): quit(1); return
			point_count += result.vertices.size()
			if int(frame.tag) == 290 and int(part.id) == 9 and result.vertices[0] != Vector3i(-4082,-537,457): quit(1); return
			if int(frame.tag) == 290 and int(part.id) == 2 and result.vertices[0] != Vector3i(-4055,49,-103): quit(1); return
	if data.frames.size() != 291 or point_count != 95157: quit(1); return
	print("PASS: all291 imported SAD poses apply rigid/deformed source vertices with exact first-group coordinates")
	quit(0)
