extends Node3D
const APERTURE := Vector2(3.2,1.6)
var nodes: Dictionary = {}
var materials: Dictionary = {}
var shaders: Dictionary = {}
var viewer_distance := 4.0
var black_level := 0
var white_level := 0
var frame_draws := 0
func _init() -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	frame_material.albedo_color=Color(0.025,0.04,0.045)
	for edge in range(4):
		var frame := MeshInstance3D.new();var box := BoxMesh.new()
		box.size=Vector3(APERTURE.x+0.07,0.035,0.035) if edge < 2 else Vector3(0.035,APERTURE.y,0.035)
		frame.mesh=box;frame.material_override=frame_material
		frame.position=Vector3(0,(APERTURE.y+0.035)*0.5*(1 if edge==0 else -1),0) if edge < 2 else Vector3((APERTURE.x+0.035)*0.5*(1 if edge==2 else -1),0,0)
		frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(frame)
func material(key: String, textures: Dictionary, masks: Dictionary) -> ShaderMaterial:
	var source := key.get_slice(":",0)
	var mode := int(key.get_slice(":",1))
	if not materials.has(key):
		var shader: Shader = preload("res://source_portal_material.gdshader")
		if mode >= 0:
			if not shaders.has(mode):
				var blended := Shader.new()
				var code := shader.code.replace("render_mode unshaded, cull_disabled, fog_disabled;","render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;")
				code = code.replace("/*BLEND_DECL*/","uniform sampler2D background_texture : hint_screen_texture, filter_nearest;")
				var formula: String = ["floor(back5/2.0)+floor(front5/2.0)","back5+front5","back5-front5","back5+floor(front5/4.0)"][mode]
				code = code.replace("/*BLEND_FRAGMENT*/","if (!textured || !has_mask || texture(mask_texture,uv).r > 0.5) { vec3 back5 = floor(clamp(encode(textureLod(background_texture,SCREEN_UV,0.0).rgb),vec3(0.0),vec3(1.0))*31.0+0.5); front5 = "+formula+"; }")
				blended.code = code;shaders[mode] = blended
			shader = shaders[mode]
		var mat := ShaderMaterial.new();mat.shader=shader;materials[key]=mat
	var mat: ShaderMaterial = materials[key]
	mat.set_shader_parameter("atlas_texture",textures[source])
	mat.set_shader_parameter("sky_background",source == "sky")
	mat.set_shader_parameter("has_mask",masks.has(source))
	if masks.has(source):mat.set_shader_parameter("mask_texture",masks[source])
	return mat
func set_source_background(colors:Dictionary,h:float) -> void:
	var palette=preload("res://source_background_colors.gd")
	for key in materials:
		if str(key).begins_with("sky:"):
			materials[key].set_shader_parameter("has_sky_color",true)
			materials[key].set_shader_parameter("sky_fill_color",palette.quantized(colors.dome))
	if not nodes.has("clear"):
		var node:=MeshInstance3D.new();node.extra_cull_margin=16384;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [Vector3(-100,-100,-1),Vector3(100,-100,-1),Vector3(100,100,-1),Vector3(-100,-100,-1),Vector3(100,100,-1),Vector3(-100,100,-1)]:
			builder.set_color(Color(0,0,0,1));builder.set_uv(Vector2.ZERO);builder.set_uv2(Vector2.ZERO);builder.add_vertex(point)
		node.mesh=builder.commit();add_child(node);nodes["clear"]=node
		var mat:=ShaderMaterial.new();mat.shader=preload("res://source_portal_material.gdshader")
		mat.set_shader_parameter("sky_background",true);mat.set_shader_parameter("sky_clear_background",true);mat.set_shader_parameter("has_sky_color",true)
		var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.BLACK);mat.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(image))
		materials["clear"]=mat;node.material_override=mat
	materials["clear"].set_shader_parameter("sky_fill_color",palette.quantized(colors["clear"]))
	materials["clear"].set_shader_parameter("source_h",h)
	nodes["clear"].show();update_anchor()
static func prepare(frame: Dictionary) -> Dictionary:
	var builders: Dictionary = {}
	var counts: Dictionary = {}
	for pass_data in frame.passes:
		var entries: Dictionary = pass_data.meshes if pass_data.kind == "opaque" else {str(pass_data.source):pass_data.mesh}
		for source in entries:
			var mesh: ArrayMesh = entries[source]
			if mesh == null:continue
			var key := str(source)+":"+str(-1 if pass_data.kind == "opaque" else int(pass_data.mode))
			if not builders.has(key):
				var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT);builders[key]=builder
				counts[key]=0
			counts[key]+=preload("res://source_portal_geometry.gd").append(builders[key],mesh)
	var meshes:Dictionary={}
	for key in builders:
		if counts[key]>0:meshes[key]=builders[key].commit()
	return {"h":frame.h,"meshes":meshes,"order":meshes.keys()}
func present(frame: Dictionary, textures: Dictionary, masks: Dictionary) -> bool:
	return present_prepared(prepare(frame),textures,masks)
func present_prepared(frame: Dictionary, textures: Dictionary, masks: Dictionary) -> bool:
	for node in nodes.values():node.hide()
	for key in frame.get("order",frame.meshes.keys()):
		if not textures.has(str(key).get_slice(":",0)):return false
		if not nodes.has(key):
			var node := MeshInstance3D.new();node.extra_cull_margin=16384;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);nodes[key]=node
		var node: MeshInstance3D=nodes[key];node.mesh=frame.meshes[key];node.material_override=material(key,textures,masks);node.show()
		node.material_override.set_shader_parameter("source_h",float(frame.h))
	frame_draws += 1;update_anchor();return true
func update_anchor() -> void:
	if not is_inside_tree():return
	for mat in materials.values():
		mat.set_shader_parameter("portal_inverse",global_transform.affine_inverse())
		mat.set_shader_parameter("viewer_distance",viewer_distance)
		mat.set_shader_parameter("aperture",APERTURE)
		mat.set_shader_parameter("black_level",float(black_level))
		mat.set_shader_parameter("white_level",float(white_level))
func _process(_delta: float) -> void:update_anchor()
