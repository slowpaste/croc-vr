extends SceneTree
func vertex(p: Vector3, uv: Vector2) -> Dictionary:
	return {"position":p,"uv":uv,"uv2":Vector2(1022,4),"color":Color(0.5,0.5,0.5,0)}
func _initialize() -> void:
	var clip = preload("res://source_portal_geometry.gd")
	var behind := [vertex(Vector3(-1,-1,1),Vector2.ZERO),vertex(Vector3(1,-1,1),Vector2.RIGHT),vertex(Vector3(0,1,1),Vector2(0,1))]
	assert(clip.clip_triangle(behind).is_empty())
	var crossing := [vertex(Vector3(-0.2,-0.2,-1),Vector2.ZERO),vertex(Vector3(0.2,-0.2,-1),Vector2.RIGHT),vertex(Vector3(0,0.2,1),Vector2(0,1))]
	var result: Array=clip.clip_triangle(crossing)
	assert(result.size()==4)
	var boundary := 0
	for point in result:
		assert(point.position.is_finite() and point.position.z<=-clip.NEAR+0.000001)
		if is_equal_approx(point.position.z,-clip.NEAR):
			boundary+=1;assert(point.uv.y>0 and point.uv.y<1)
	assert(boundary==2)
	var source := SurfaceTool.new();source.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in behind:
		source.set_color(point.color);source.set_uv(point.uv);source.set_uv2(point.uv2);source.add_vertex(point.position)
	var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
	assert(clip.append(builder,source.commit())==0)
	print("PASS: behind-camera triangles removed; crossing triangles clipped with finite, interpolated attributes")
	quit(0)
