extends RefCounted
const NEAR := 0.05
static func clip_triangle(vertices: Array) -> Array:
	var result: Array = []
	var previous: Dictionary = vertices.back()
	var previous_inside: bool = previous.position.z <= -NEAR
	for vertex in vertices:
		var inside: bool = vertex.position.z <= -NEAR
		if inside != previous_inside:
			var t: float = (-NEAR-previous.position.z)/(vertex.position.z-previous.position.z)
			result.append({"position":previous.position.lerp(vertex.position,t),"uv":previous.uv.lerp(vertex.uv,t),"uv2":previous.uv2.lerp(vertex.uv2,t),"color":previous.color.lerp(vertex.color,t)})
		if inside:result.append(vertex)
		previous=vertex;previous_inside=inside
	return result
static func append(builder: SurfaceTool, mesh: ArrayMesh) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var all_front := true
	var any_front := false
	for position in positions:
		if not position.is_finite():all_front=false;continue
		if position.z <= -NEAR:any_front=true
		else:all_front=false
	if all_front:
		builder.append_from(mesh,0,Transform3D.IDENTITY)
		return mesh.surface_get_array_index_len(0) if mesh.surface_get_array_index_len(0)>0 else positions.size()
	if not any_front:return 0
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else positions.size()
	var emitted := 0
	for start in range(0,count,3):
		var triangle: Array = []
		for corner in range(3):
			var index: int = indices[start+corner] if not indices.is_empty() else start+corner
			var position: Vector3 = positions[index]
			if not position.is_finite():triangle.clear();break
			triangle.append({"position":position,"uv":arrays[Mesh.ARRAY_TEX_UV][index] if arrays[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO,"uv2":arrays[Mesh.ARRAY_TEX_UV2][index] if arrays[Mesh.ARRAY_TEX_UV2] != null else Vector2.ZERO,"color":arrays[Mesh.ARRAY_COLOR][index] if arrays[Mesh.ARRAY_COLOR] != null else Color.WHITE})
		if triangle.size()!=3:continue
		var polygon := clip_triangle(triangle)
		for index in range(1,polygon.size()-1):
			var a: Vector3=polygon[0].position;var b: Vector3=polygon[index].position;var c: Vector3=polygon[index+1].position
			if (b-a).cross(c-a).length_squared()<0.000000000001:continue
			for vertex in [polygon[0],polygon[index],polygon[index+1]]:
				builder.set_color(vertex.color);builder.set_uv(vertex.uv);builder.set_uv2(vertex.uv2);builder.set_custom(0,Color(0,0,0,0));builder.add_vertex(vertex.position);emitted+=1
	return emitted
