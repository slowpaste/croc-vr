extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var loader = preload("res://source_sequence_content.gd")
	var state := {"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667}
	var parts := 0; var point_rooms := {}
	for scene in range(24):
		var config: Dictionary = loader.load_sequence(content,manifest,tables,scene,state)
		if config.has("fault"): push_error("Scene "+str(scene)+": "+str(config.fault)); quit(1); return
		if config.parts.size() != int(tables.gameOver.sequenceScenes.records[scene].modelCount) or config.data.scene_id != scene:
			push_error("Scene part binding differs"); quit(1); return
		for index in range(config.parts.size()):
			var part: Dictionary = config.parts[index]
			if part.models.models.is_empty() or part.data.frames.is_empty() or part.background_texture == null or part.actor_mask == null:
				push_error("Incomplete sequence scenery binding"); quit(1); return
			if part.point_lighting_required: point_rooms[config.resources.parts[index].room.name] = true
			if scene in [15,16,19,20]:
				var plan := preload("res://source_cutscene_frame_plan.gd").build(part,part.room_atlas,0)
				if plan.has("fault") or int(plan.commands) <= 0:
					push_error("Ending scenery plan failed: "+str(scene)+" part "+str(index)+" "+str(plan.get("fault","empty"))); quit(1); return
				if bool(plan.point_lighting_required) != (bool(part.point_lighting_required) and not bool(part.point_lighting_implemented)):
					push_error("Scenery plan silently lost original point-light requirements"); quit(1); return
			parts += 1
		print("SEQUENCE_CONTENT: ",scene," parts=",config.parts.size())
	if not loader.load_sequence(content,manifest,tables,20,{}).has("fault"):
		push_error("Sequence guessed missing CD state"); quit(1); return
	print("PASS: all24 descriptors bind ",parts," actor/room parts, actual atlases/domes/anchors and explicit audio state; retained point-light rooms=",point_rooms.size())
	quit(0)
