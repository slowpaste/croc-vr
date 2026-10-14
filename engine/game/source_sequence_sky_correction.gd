extends RefCounted
# Native3b778..3b798 rotates TB43 using the room halfword at +116
# (the imported startRotation). Repair only sky meshes in legacy caches.
static func apply(frame: Dictionary, part: Dictionary, index: int) -> Dictionary:
	if int(part.room.get("background",0)) != 43: return frame
	var camera: Dictionary = part.data.frames[index].camera
	var pairs: Array = part.tables.rotation.pairs
	var anchored := preload("res://source_cutscene_view.gd").anchored_camera(camera,part.anchor.position,int(part.anchor.yaw),pairs)
	var view := preload("res://source_cutscene_view.gd").camera_view(anchored,pairs)
	var sky_frame := preload("res://source_cutscene_sky.gd").frame(anchored,part.sky_models.models.size(),roundi(float(part.room.startRotation)*4096.0),pairs)
	if sky_frame.has("fault"): return sky_frame
	var sky := preload("res://source_cutscene_mesh.gd").build(sky_frame,part.sky_models.models,view,part.sky_atlas,{}, {"ordering":true,"commands":true,"gpu_color":true})
	if sky.has("fault"): return sky
	for command in sky.commands:
		command.source = "sky"; command.bucket = 1022; command.global_serial = int(command.serial)
	var result := frame.duplicate(true)
	var inserted := false
	for pass_data in result.passes:
		if pass_data.kind == "opaque":
			if pass_data.meshes.has("sky"):
				pass_data.meshes.sky = preload("res://source_cutscene_passes.gd").mesh(sky.commands,int(frame.commands))
				inserted = true
	if not inserted and not sky.commands.is_empty(): return {"fault":"Cached frame has no sky stage"}
	return result
