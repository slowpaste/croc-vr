extends MeshInstance3D
var fade_material := ShaderMaterial.new()
var white_material := ShaderMaterial.new()
var fade_quad: QuadMesh
var effect: CompositorEffect
var effect_camera: Camera3D
var canvas: CanvasLayer
var canvas_copy: BackBufferCopy
var canvas_rect: ColorRect
var source_value:=0
var source_white:=false
var polygons:=false
func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	fade_quad=quad
	mesh = quad
	fade_material.shader = preload("res://source_fade.gdshader")
	fade_material.render_priority = 127
	white_material.shader = preload("res://source_white_fade.gdshader")
	white_material.render_priority = 127
	material_override = fade_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384
	visible = false
func _ready() -> void:
	if RenderingServer.get_rendering_device()!=null:
		effect_camera=get_parent() as Camera3D
		if effect_camera==null:effect_camera=get_viewport().get_camera_3d()
		if effect_camera!=null:
			effect=preload("res://source_fade_effect.gd").new()
			if effect_camera.compositor==null:effect_camera.compositor=Compositor.new()
			var effects:=effect_camera.compositor.compositor_effects.duplicate()
			effects.append(effect);effect_camera.compositor.compositor_effects=effects
	elif RenderingServer.get_current_rendering_method()=="gl_compatibility":
		canvas=CanvasLayer.new();canvas.layer=128;add_child(canvas)
		canvas_copy=BackBufferCopy.new();canvas_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;canvas.add_child(canvas_copy)
		canvas_rect=ColorRect.new();canvas_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(canvas_rect)
		var canvas_material:=ShaderMaterial.new();canvas_material.shader=preload("res://source_canvas_fade.gdshader")
		canvas_rect.material=canvas_material
	visibility_changed.connect(sync_rendering)
	sync_rendering()
func _process(_delta: float) -> void:
	if canvas_rect!=null:canvas_rect.size=get_viewport().get_visible_rect().size
func _exit_tree() -> void:
	if effect!=null and is_instance_valid(effect_camera) and effect_camera.compositor!=null:
		var effects:=effect_camera.compositor.compositor_effects.duplicate();effects.erase(effect)
		effect_camera.compositor.compositor_effects=effects
	effect=null
func sync_rendering() -> void:
	var active:=is_visible_in_tree() and not polygons and source_value>=8
	if effect!=null:
		effect.configure(source_value,source_white);effect.enabled=active
	if canvas_rect!=null:
		canvas_rect.size=get_viewport().get_visible_rect().size;canvas_rect.visible=active
		canvas_rect.material.set_shader_parameter("amount",float(source_value>>3))
		canvas_rect.material.set_shader_parameter("direction",1.0 if source_white else -1.0)
		canvas_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT if active else BackBufferCopy.COPY_MODE_DISABLED
	mesh=fade_quad if polygons or (effect==null and canvas==null) else null
func set_source_level(level: int) -> void:
	material_override = fade_material
	var value := clampi(level,0,255)
	source_value=value;source_white=false;polygons=false
	fade_material.set_shader_parameter("polygon_mode",false)
	fade_material.set_shader_parameter("source_level",float(value)/255.0)
	visible = value != 0
	if is_inside_tree():sync_rendering()
func set_source_white_level(level: int) -> void:
	var value := clampi(level,0,255)
	source_value=value;source_white=true;polygons=false
	material_override = white_material
	white_material.set_shader_parameter("source_level",float(value)/255.0)
	visible = value != 0
	if is_inside_tree():sync_rendering()
func set_source_polygons(triangles: Array, complete: bool = false) -> bool:
	polygons=true
	material_override = fade_material
	fade_material.set_shader_parameter("physical_polygons",get_viewport().use_xr or OS.get_cmdline_user_args().has("--frame-menu-preview"))
	fade_material.set_shader_parameter("physical_full_black",complete)
	if triangles.size() > 10:
		return false
	var vertices := PackedVector2Array()
	vertices.resize(30)
	for index in range(triangles.size()):
		if triangles[index].size() != 3:
			return false
		for point in range(3):
			vertices[index*3+point] = Vector2(triangles[index][point])/Vector2(512,240)
	fade_material.set_shader_parameter("polygon_vertices",vertices)
	fade_material.set_shader_parameter("triangle_count",triangles.size())
	fade_material.set_shader_parameter("polygon_mode",true)
	visible = not triangles.is_empty()
	if is_inside_tree():sync_rendering()
	return true
