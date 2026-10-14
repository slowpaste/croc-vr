extends RefCounted
const Rotation = preload("res://source_rotation.gd")
const VM = preload("res://asl_vm.gd")
static func normal_scale(scale: int) -> int:
	# Native187b4..1880c: preserve zero and near-unity; otherwise signed reciprocal.
	var value := Rotation.halfword(scale)
	if value == 0 or value >= 4092 and value <= 4100: return value
	return Rotation.halfword(int(16777216.0/float(value)))
# Native16a60: current view translation + rotated part translation,
# then current view rotation composed with the part matrix. Scale stays separate.
static func compose_view(part: Dictionary, view: Dictionary) -> Dictionary:
	if not part.has_all(["matrix","position","scale"]) or not view.has_all(["matrix","position"]): return {"fault":"Missing source cutscene transform"}
	if part.matrix.size() != 9 or view.matrix.size() != 9 or part.position.size() != 3 or view.position.size() != 3: return {"fault":"Invalid source cutscene transform span"}
	var position := Vector3i(int(part.position[0]),int(part.position[1]),int(part.position[2]))
	var translation := Vector3i(int(view.position[0]),int(view.position[1]),int(view.position[2]))
	var composed := Rotation.parent_pose(view.matrix,translation,part.matrix,position)
	return {"matrix":composed.matrix,"position":composed.position,"scale":Rotation.halfword(int(part.scale))}

static func vertices(part: Dictionary, model: Dictionary, view: Dictionary, facing_image: bool = false) -> Dictionary:
	if not model.has("vertices"): return {"fault":"Missing source cutscene model vertices"}
	var values: Array = part.get("vertices",model.vertices)
	if values.size() != model.vertices.size(): return {"fault":"Cutscene replacement vertex count mismatch"}
	var composed := compose_view(part,view)
	if composed.has("fault"): return composed
	if facing_image and preload("res://source_sprite_facing.gd").is_image_quad(model):
		# Native1872c..18784 sets the image matrix at angle2048, preserving
		# composed translation; 187ac dispatches the dedicated image renderer.
		var scale := int(composed.scale)
		composed.matrix = [-scale,0,0,0,-scale,0,0,0,scale]
	var points: Array = []
	var units := 1.0 if part.has("vertices") else 4096.0 # Imported static model vertices are normalized.
	for value in values:
		if value.size() < 3: return {"fault":"Invalid source cutscene vertex"}
		var rotated := Rotation.transform_short(composed.matrix,Vector3i(roundi(float(value[0])*units),roundi(float(value[1])*units),roundi(float(value[2])*units)))
		var point: Vector3i = rotated.position
		for axis in range(3): point[axis] = VM.signed32(point[axis]+composed.position[axis])
		points.append(point)
	return {"vertices":points,"normal_scale":normal_scale(int(composed.scale))}
