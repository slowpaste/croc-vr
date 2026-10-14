extends Node
var stages: Array[SubViewport] = []
var output: SubViewport = null
var bindings: Array = []
var cameras: Array[Camera3D] = []
var textures: Dictionary = {}
var masks: Dictionary = {}
func viewport_2d() -> SubViewport:
	var target := SubViewport.new()
	target.size = Vector2i(512,240); target.use_hdr_2d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(target); stages.append(target)
	return target
func sprite(target: SubViewport, texture: Texture2D, material: ShaderMaterial) -> Sprite2D:
	var node := Sprite2D.new()
	node.centered = false; node.texture = texture; node.material = material
	node.scale = Vector2(512,240)/Vector2(texture.get_size())
	target.add_child(node)
	return node
func viewport_3d(h: int, previous: SubViewport = null) -> SubViewport:
	var target := viewport_2d()
	target.own_world_3d = true; target.transparent_bg = previous == null
	var camera := Camera3D.new()
	camera.near = 0.01; camera.fov = rad_to_deg(2.0*atan(120.0/float(h)))
	target.add_child(camera)
	cameras.append(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	if previous != null:
		environment.environment.background_mode = Environment.BG_CANVAS
		environment.environment.background_canvas_max_layer = -1
		var layer := CanvasLayer.new(); layer.layer = -1; target.add_child(layer)
		var copy := ShaderMaterial.new(); copy.shader = preload("res://source_gpu_copy.gdshader")
		copy.set_shader_parameter("source_texture",previous.get_texture())
		var node := Sprite2D.new(); node.centered = false; node.texture = previous.get_texture(); node.material = copy
		layer.add_child(node)
	else: environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	target.add_child(environment)
	return target
func draw(target: SubViewport, commands: Array, total: int, texture: Texture2D, mask: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if not commands.is_empty(): node.mesh = preload("res://source_cutscene_passes.gd").mesh(commands,total)
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_cutscene_mask_material.gdshader") if mask else preload("res://source_cutscene_gpu_material.gdshader")
	material.set_shader_parameter("source_vertical_scale",0.625)
	material.set_shader_parameter("source_mask_texture" if mask else "atlas_texture",texture)
	node.material_override = material; target.add_child(node)
	return node
func setup(plan: Dictionary, h: int, textures: Dictionary, masks: Dictionary) -> bool:
	if bool(plan.get("point_lighting_required",false)): return false
	if not stages.is_empty() or not plan.has_all(["passes","commands"]): return false
	var current: SubViewport = null
	self.textures = textures.duplicate(); self.masks = masks.duplicate()
	for pass_data in plan.passes:
		if pass_data.kind == "opaque":
			var target := viewport_3d(h,current)
			var nodes := {}
			for source in textures.keys():
				var commands: Array = []
				for command in pass_data.commands:
					if command.source == source: commands.append(command)
				nodes[source] = draw(target,commands,int(plan.commands),textures[source])
			bindings.append({"kind":"opaque","nodes":nodes})
			current = target
		else:
			var source := str(pass_data.command.source)
			if current == null or not textures.has(source) or not masks.has(source): return false
			var foreground := viewport_3d(h)
			var foreground_node := draw(foreground,[pass_data.command],int(plan.commands),textures[source])
			var mask := viewport_3d(h)
			var mask_node := draw(mask,[pass_data.command],int(plan.commands),masks[source],true)
			var blended := viewport_2d()
			var material := ShaderMaterial.new(); material.shader = preload("res://source_gpu_blend.gdshader")
			material.set_shader_parameter("background_texture",current.get_texture())
			material.set_shader_parameter("foreground_texture",foreground.get_texture())
			material.set_shader_parameter("source_mask_texture",mask.get_texture())
			material.set_shader_parameter("source_blend_mode",int(pass_data.mode))
			sprite(blended,current.get_texture(),material)
			bindings.append({"kind":"blend","foreground":foreground_node,"mask":mask_node,"material":material})
			current = blended
	output = current
	return output != null

func present(plan: Dictionary, h: int) -> bool:
	if not plan.has_all(["passes","commands"]) or plan.passes.size() != bindings.size() or h <= 0: return false
	for index in range(bindings.size()):
		if str(plan.passes[index].kind) != str(bindings[index].kind): return false
	for camera in cameras: camera.fov = rad_to_deg(2.0*atan(120.0/float(h)))
	for index in range(bindings.size()):
		var binding: Dictionary = bindings[index]
		var pass_data: Dictionary = plan.passes[index]
		if binding.kind == "opaque":
			for source in binding.nodes:
				var commands: Array = []
				for command in pass_data.commands:
					if command.source == source: commands.append(command)
				binding.nodes[source].mesh = preload("res://source_cutscene_passes.gd").mesh(commands,int(plan.commands)) if not commands.is_empty() else null
		else:
			var source := str(pass_data.command.source)
			if not textures.has(source) or not masks.has(source): return false
			var mesh := preload("res://source_cutscene_passes.gd").mesh([pass_data.command],int(plan.commands))
			binding.foreground.mesh = mesh; binding.mask.mesh = mesh
			binding.foreground.material_override.set_shader_parameter("atlas_texture",textures[source])
			binding.mask.material_override.set_shader_parameter("source_mask_texture",masks[source])
			binding.material.set_shader_parameter("source_blend_mode",int(pass_data.mode))
	return true

func setup_cached(frame: Dictionary, textures: Dictionary, masks: Dictionary) -> bool:
	var passes: Array = []
	for pass_data in frame.passes:
		if pass_data.kind == "opaque": passes.append({"kind":"opaque","commands":[]})
		else: passes.append({"kind":"blend","mode":int(pass_data.mode),"command":{"source":pass_data.source,"vertices":[],"bucket":0,"flags":0x21,"global_serial":0}})
	if not setup({"passes":passes,"commands":int(frame.commands)},int(frame.h),textures,masks): return false
	return present_cached(frame)

func present_cached(frame: Dictionary) -> bool:
	if not frame.has_all(["passes","h"]) or frame.passes.size() != bindings.size() or int(frame.h) <= 0: return false
	for index in range(bindings.size()):
		if str(frame.passes[index].kind) != str(bindings[index].kind): return false
	for camera in cameras: camera.fov = rad_to_deg(2.0*atan(120.0/float(frame.h)))
	for index in range(bindings.size()):
		var binding: Dictionary = bindings[index]
		var pass_data: Dictionary = frame.passes[index]
		if binding.kind == "opaque":
			for source in binding.nodes: binding.nodes[source].mesh = pass_data.meshes.get(source,null)
		else:
			var source := str(pass_data.source)
			if not textures.has(source) or not masks.has(source): return false
			binding.foreground.mesh = pass_data.mesh; binding.mask.mesh = pass_data.mesh
			binding.foreground.material_override.set_shader_parameter("atlas_texture",textures[source])
			binding.mask.material_override.set_shader_parameter("source_mask_texture",masks[source])
			binding.material.set_shader_parameter("source_blend_mode",int(pass_data.mode))
	return true
