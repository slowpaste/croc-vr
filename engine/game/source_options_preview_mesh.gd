extends RefCounted
static func build(pose: Dictionary, models: Dictionary, atlas: Dictionary, pairs: Array, view: Dictionary, projection: Dictionary) -> Dictionary:
	if not pose.has_all(["position","angles","scale"]) or not pose.position is Vector3i or not pose.angles is Vector3i or not pose.scale is Vector3i or not models.get("models",null) is Array: return {"fault":"Missing Options preview geometry or explicit scale"}
	if not projection.has_all(["h","offset"]): return {"fault":"Options preview requires explicit active GTE projection"}
	if not view.has_all(["matrix","position"]): return {"fault":"Options preview requires explicit view transform"}
	var matrix := preload("res://source_rotation.gd").matrix(pose.angles,pairs)
	matrix = preload("res://source_rotation.gd").scaled_matrix(matrix,pose.scale)
	var parts: Array = []
	for index in range(models.models.size()):
		parts.append({"id":index,"matrix":matrix.duplicate(),"position":[pose.position.x,pose.position.y,pose.position.z],"scale":4096})
	# Original4fab0 invokes generic183f0 with all components and RGB unity128.
	return preload("res://source_cutscene_mesh.gd").build({"parts":parts},models.models,view,atlas,{},projection)
