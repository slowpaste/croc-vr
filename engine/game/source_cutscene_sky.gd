extends RefCounted
# Native3b7bc: background follows camera X/Z, quarter cameraY minus2048.
# The constant matrix80011020 has8192 on its diagonal (double dome scale).
static func frame(camera: Dictionary, model_count: int, yaw: int = 0, pairs: Array = []) -> Dictionary:
	if not camera.has("position") or camera.position.size() != 3 or model_count < 1: return {"fault":"Missing cutscene sky resources"}
	var parts: Array = []
	var matrix := [8192,0,0,0,8192,0,0,0,8192]
	if yaw != 0:
		if pairs.size() != 4096: return {"fault":"Missing sky rotation table"}
		matrix = preload("res://source_rotation.gd").scaled_matrix(preload("res://source_rotation.gd").matrix(Vector3i(0,yaw,0),pairs),Vector3i(8192,8192,8192))
	for index in range(model_count):
		parts.append({"id":index,"matrix":matrix,"position":[int(camera.position[0]),(int(camera.position[1])>>2)-2048,int(camera.position[2])],"scale":4096})
	return {"parts":parts}
