extends RefCounted
static func build(config: Dictionary, room_atlas: Dictionary, index: int) -> Dictionary:
	if index < 0 or index >= config.data.frames.size(): return {"fault":"Invalid cutscene compositor frame"}
	var frame: Dictionary = config.data.frames[index]
	var tables: Dictionary = config.tables
	var anchored := preload("res://source_cutscene_view.gd").anchored_camera(frame.camera,config.anchor.position,int(config.anchor.yaw),tables.rotation.pairs)
	var room_view := preload("res://source_cutscene_view.gd").camera_view(anchored,tables.rotation.pairs)
	var actor_view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
	var projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
	projection.ordering = true; projection.commands = true; projection.gpu_color = true
	projection.facing_images = true
	var actors := preload("res://source_cutscene_mesh.gd").build(frame,config.models.models,actor_view,config.atlas,tables.gameOver.sequenceLighting,projection)
	var room_projection := projection.duplicate(); room_projection.terrain = true
	room_projection.facing_images = false
	var room := preload("res://source_cutscene_mesh.gd").build(config.tiles,config.track_models.models,room_view,room_atlas,config.room_lighting,room_projection)
	if actors.has("fault"): return actors
	if room.has("fault"): return room
	var sky := {"commands":[]}
	if not config.sky_models.models.is_empty():
		var sky_frame := preload("res://source_cutscene_sky.gd").frame(anchored,config.sky_models.models.size())
		sky = preload("res://source_cutscene_mesh.gd").build(sky_frame,config.sky_models.models,room_view,config.sky_atlas,{}, {"ordering":true,"commands":true,"gpu_color":true})
		if sky.has("fault"): return sky
	var world_commands: Array = []
	for command in sky.commands:
		command.source = "sky"; command.bucket = 1022
		world_commands.append(command)
	for command in room.commands:
		command.serial = int(command.serial)+sky.commands.size()
		world_commands.append(command)
	var plan := preload("res://source_cutscene_passes.gd").plan(world_commands,actors.commands)
	plan.h = int(projection.h)
	plan.point_lighting_required = bool(config.get("point_lighting_required",false)) and not bool(config.get("point_lighting_implemented",false))
	return plan
