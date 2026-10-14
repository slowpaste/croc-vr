extends Node
var compositor: Node = null
var fault := ""
func present(pose: Dictionary, models: Dictionary, atlas: Dictionary, texture: Texture2D, pairs: Array, view: Dictionary, projection: Dictionary) -> bool:
	fault = ""
	if texture == null or int(projection.get("h",0))<=0 or projection.get("offset",Vector2i.ZERO)!=Vector2i(256<<16,192<<16):fault="Unsupported Options atlas or projection";return false
	var settings := projection.duplicate(true)
	settings.merge({"ordering":true,"gpu_color":true,"commands":true},true)
	var built := preload("res://source_options_preview_mesh.gd").build(pose,models,atlas,pairs,view,settings)
	if built.has("fault"):fault=str(built.fault);return false
	var plan := preload("res://source_cutscene_passes.gd").plan([],built.commands)
	if is_instance_valid(compositor) and compositor.present(plan,int(projection.h)):return true
	var next := preload("res://source_cutscene_compositor.gd").new();add_child(next)
	if not next.setup(plan,int(projection.h),{"actor":texture},{}):next.queue_free();fault="Options preview requires unsupported blend-mask data";return false
	if is_instance_valid(compositor):compositor.queue_free()
	compositor=next
	return true
func output_texture() -> Texture2D:
	return compositor.output.get_texture() if is_instance_valid(compositor) and compositor.output!=null else null
