extends Node3D
# Original room background selection and camera-following dome (0x8003b7bc).
var world: Node3D
func setup(owner_world: Node3D) -> bool:
	world=owner_world
	var background:=int(world.room_data.get("background",0))
	var colors:=preload("res://source_background_colors.gd").lookup(world.manifest,"TB%02d.BIN"%background)
	var clear_rgb:=preload("res://source_background_colors.gd").quantized(colors["clear"])
	for node in world.get_children():
		if node is WorldEnvironment:node.environment.background_color=Color(clear_rgb.x,clear_rgb.y,clear_rgb.z)
	if background==0:return true
	var dome:=2 if background==42 else 3 if background==48 else 1
	var asset:Dictionary={}
	for entry in world.manifest.models:
		if entry.name=="TB%02d_DOM.MOD"%dome:asset=entry;break
	var binding:Dictionary=world.material_for_texture("TB%02d.BIN"%background)
	if asset.is_empty() or binding.is_empty():push_error("Missing original gameplay background");return false
	var pack:Dictionary=world.read_shared_content(asset.file)
	var material:=ShaderMaterial.new();material.shader=preload("res://source_gameplay_sky.gdshader")
	material.set_shader_parameter("atlas_texture",binding.material.albedo_texture)
	material.set_shader_parameter("dome_color",preload("res://source_background_colors.gd").quantized(colors.dome))
	for model in pack.models:
		var node:=MeshInstance3D.new();node.mesh=world.geometry(model,binding.data)
		node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin=16384;add_child(node)
	scale=Vector3.ONE*2.0
	rotation.y=float(world.room_data.startRotation)*TAU if background==43 else 0.0
	_process(0);return true
func _process(_delta:float) -> void:
	if world==null:return
	var camera:Camera3D=world.head if world.xr_active else world.camera
	if not is_instance_valid(camera):return
	var view:=camera.global_position
	global_position=Vector3(view.x,view.y*0.25-world.CELL_METERS*0.5,view.z)
