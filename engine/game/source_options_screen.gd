extends MeshInstance3D
var panel := preload("res://source_options_panel.gd").new()
var material := ShaderMaterial.new()
func _init() -> void:
	add_child(panel)
	var quad := QuadMesh.new();quad.size=preload("res://vr_frontend_panel.gd").SIZE;mesh=quad
	position=Vector3(0,0,-preload("res://vr_frontend_panel.gd").DISTANCE)
	material.shader=preload("res://source_options_screen.gdshader")
	material.render_priority=126;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible=false
func present(world: Node, state: Dictionary, pose: Dictionary, font: Dictionary) -> bool:
	var view := {"matrix":[-4096,0,0,0,-4096,0,0,0,4096],"position":[0,0,0]}
	var projection := {"h":288,"offset":Vector2i(256<<16,192<<16)}
	if not panel.present(world,state,pose,font,view,projection):return false
	material.set_shader_parameter("source_texture",panel.output_texture());visible=true
	return true
