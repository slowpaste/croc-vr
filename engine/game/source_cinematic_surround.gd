extends MeshInstance3D
func _init() -> void:
	var sphere:=SphereMesh.new();sphere.radius=60;sphere.height=120;mesh=sphere
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_FRONT
	material.albedo_color=Color(0.008,0.008,0.008)
	material.disable_fog=true;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
