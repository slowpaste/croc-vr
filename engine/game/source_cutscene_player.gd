extends Node3D
var camera := Camera3D.new()
var model := MeshInstance3D.new()
var overlay := preload("res://source_fade_overlay.gd").new()
var frames: Array = []
var models: Array = []
var tables: Dictionary = {}
var atlas: Dictionary = {}
var availability: Dictionary = {}
var flow: Dictionary = {}
var fade: Dictionary = {}
var complete := false
var last_index := -1
var fault := ""
var cached_meshes: Array = []
var sequence_models: Array = []
var scene_count := 1
var current_part := -1
var draw_geometry := true
func _init() -> void:
	camera.near = 0.01
	add_child(camera)
	add_child(model)
	camera.add_child(overlay)
	visible = false

func setup(data: Dictionary, model_pack: Dictionary, runtime: Dictionary, texture_atlas: Dictionary, texture: Texture2D, prefilled_sectors: int, mesh_cache: Array = []) -> bool:
	if not data.has("frames") or not model_pack.has("models") or not runtime.has_all(["rotation","gameOver"]) or texture == null: return false
	var scene_id := int(data.get("scene_id",20))
	if scene_id < 0 or scene_id >= 24: return false
	var stream := preload("res://source_cutscene_availability.gd").initialize(data.frames,prefilled_sectors)
	if stream.has("fault"): return false
	if not mesh_cache.is_empty():
		if mesh_cache.size() != data.frames.size(): return false
		for mesh in mesh_cache:
			if not mesh is ArrayMesh or mesh.get_surface_count() != 1: return false
	frames = data.frames
	sequence_models.clear(); scene_count = 1; current_part = -1
	models = model_pack.models
	tables = runtime
	atlas = texture_atlas
	cached_meshes = mesh_cache.duplicate()
	availability = stream
	flow = preload("res://source_cutscene_flow.gd").initialize()
	# SAD is native scene20; 50368..50388 selects kind1 outside scenes10..18.
	fade = preload("res://source_transition_fade.gd").start(preload("res://source_cutscene_flow.gd").entry_fade(scene_id))
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_cutscene_material.gdshader")
	material.set_shader_parameter("source_vertical_offset",preload("res://source_cutscene_frame.gd").vertical_offset())
	material.set_shader_parameter("source_vertical_scale",0.625)
	material.set_shader_parameter("source_ordered_depth",true)
	material.set_shader_parameter("atlas_texture",texture)
	model.material_override = material
	model.mesh = null
	complete = false
	last_index = -1
	fault = ""
	visible = true
	return true

func setup_sequence(data: Dictionary, packs: Array, runtime: Dictionary, texture_atlas: Dictionary, texture: Texture2D, prefilled_sectors: int, mesh_cache: Array = []) -> bool:
	if not data.has_all(["parts","scene_id"]) or data.parts.is_empty() or packs.size() != data.parts.size(): return false
	var flattened: Array = []
	var banks: Array = []
	for part_index in range(data.parts.size()):
		var part: Dictionary = data.parts[part_index]
		if not part.has("frames") or part.frames.is_empty() or not bool(part.frames[-1].get("end",false)) or not packs[part_index].has("models"): return false
		banks.append(packs[part_index].models)
		for index in range(part.frames.size()):
			if bool(part.frames[index].get("end",false)) != (index == part.frames.size()-1): return false
			var frame: Dictionary = part.frames[index].duplicate(false)
			frame.part_index = part_index
			flattened.append(frame)
	if not setup({"frames":flattened,"scene_id":data.scene_id},packs[0],runtime,texture_atlas,texture,prefilled_sectors,mesh_cache): return false
	sequence_models = banks; scene_count = banks.size()
	return true

func present_next(processed_sectors: int, held: int) -> Dictionary:
	if not fault.is_empty(): return {"fault":fault}
	if complete: return {"complete":true,"waiting":false}
	if availability.is_empty(): return {"fault":"Cutscene player is not initialized"}
	var stream := preload("res://source_cutscene_availability.gd").consume_ready(availability,processed_sectors,1)
	if stream.has("fault"): return stream
	if stream.ready_indices.is_empty():
		availability = stream
		return {"complete":false,"waiting":true}
	var index := int(stream.ready_indices[0])
	var frame: Dictionary = frames[index]
	var part_index := int(frame.get("part_index",0))
	if part_index < 0 or part_index >= scene_count or (current_part >= 0 and part_index != current_part and (part_index != current_part+1 or not bool(frames[last_index].end))):
		fault = "Invalid original cutscene part transition"; return {"fault":fault}
	if not sequence_models.is_empty(): models = sequence_models[part_index]
	current_part = part_index
	var view := preload("res://source_cutscene_view.gd").parts_view(frame.camera,tables.rotation.pairs)
	if view.has("fault"):
		fault = "Original cutscene view construction failed"
		return {"fault":fault}
	var projection := preload("res://source_cutscene_frame.gd").projection(int(frame.camera.projectionDistance))
	projection.ordering = true
	var geometry: Dictionary = {"mesh":null}
	if draw_geometry:
		geometry = {"mesh":cached_meshes[index]} if not cached_meshes.is_empty() else preload("res://source_cutscene_mesh.gd").build(frame,models,view,atlas,tables.gameOver.sequenceLighting,projection)
	if geometry.has("fault") or int(frame.camera.projectionDistance) <= 0:
		fault = "Original cutscene pose rendering failed"
		return {"fault":fault}
	availability = stream
	fade = preload("res://source_transition_fade.gd").advance(fade,0)
	flow = preload("res://source_cutscene_flow.gd").before_frame(flow,int(frame.tag),part_index,scene_count)
	if int(flow.start) != 0: fade = preload("res://source_transition_fade.gd").start(int(flow.start))
	model.mesh = geometry.mesh
	camera.fov = rad_to_deg(2.0*atan(120.0/float(projection.h)))
	if int(fade.kind) == 3: overlay.set_source_white_level(int(fade.level))
	else: overlay.set_source_level(int(fade.level))
	flow = preload("res://source_cutscene_flow.gd").after_frame(flow,held,bool(fade.ready),bool(frame.end))
	if int(flow.start) != 0: fade = preload("res://source_transition_fade.gd").start(int(flow.start))
	# Native50af0..50b74 exits the whole file for a ready user/terminal fade;
	# ordinary part end markers instead advance to the next model/room bank.
	complete = bool(flow.advance_scene) and (part_index == scene_count-1 or bool(flow.ending) and bool(fade.ready))
	last_index = index
	return {"complete":complete,"waiting":false,"index":index,"part_index":part_index,"tag":int(frame.tag)}
