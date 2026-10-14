extends SceneTree
func bounds(command: Dictionary, h: int) -> Rect2:
	var low := Vector2(1e12,1e12); var high := Vector2(-1e12,-1e12)
	for vertex in command.vertices:
		var point: Vector3 = vertex.position
		if -point.z <= 0.01: return Rect2(Vector2(-1e12,-1e12),Vector2(2e12,2e12))
		# Common screen translation/reflection does not affect overlap. Do not
		# clip bounds to the viewport, so this also conservatively covers edges.
		var projected := Vector2(point.x,point.y)*float(h)/(-point.z)
		low = low.min(projected); high = high.max(projected)
	return Rect2(low-Vector2(2,2),high-low+Vector2(4,4))
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var config := preload("res://source_sequence_content.gd").load_sequence(content,manifest,tables,15,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667})
	if config.has("fault"): push_error(str(config.fault)); quit(1); return
	for part in config.parts:
		var plan := preload("res://source_cutscene_frame_plan.gd").build(part,part.room_atlas,0)
		if plan.has("fault"): push_error(str(plan.fault)); quit(1); return
		var regions: Array[Rect2] = []; var mode := -1; var source := ""
		var groups := 0; var max_group := 0
		for pass_data in plan.passes:
			if pass_data.kind == "opaque": regions.clear(); mode = -1; continue
			var rectangle := bounds(pass_data.command,int(plan.h))
			var overlaps: bool = mode != int(pass_data.mode) or source != str(pass_data.command.source)
			for prior in regions:
				if prior.intersects(rectangle,true): overlaps = true; break
			if regions.is_empty() or overlaps:
				groups += 1; regions.clear()
			regions.append(rectangle); max_group = maxi(max_group,regions.size())
			mode = int(pass_data.mode); source = str(pass_data.command.source)
		print("DISJOINT_BLEND_AUDIT: ",JSON.stringify({"original_blend_passes":plan.blended,"conservative_groups":groups,"largest_group":max_group}))
	quit(0)
