extends RefCounted
const Rotation = preload("res://source_rotation.gd")
static func scratch_angles(first_word: int, second_word: int) -> Vector3i:
	# Native factory copies the first three halfwords of the surviving pose buffer.
	return Vector3i(Rotation.halfword(first_word),Rotation.halfword(first_word>>16),Rotation.halfword(second_word))
static func point(matrix: Array, origin: Vector3i, scale: Vector3i, models: Array, animation: Dictionary, frame: int, index: int) -> Dictionary:
	if matrix.size() != 9 or models.is_empty(): return {"fault":"Missing SpawnFrom render pose/model"}
	var local := Vector3i.ZERO
	var animated := not animation.is_empty()
	if not animated:
		# Native2a0f4..2a124 uses first model bounds, independent of origin index.
		var bounds: Array = models[0].get("bounds",[])
		if bounds.is_empty(): return {"fault":"Missing SpawnFrom static origin"}
		for axis in range(3): local[axis] = roundi(float(bounds[0][axis])*4096.0)
	else:
		var vertex_animation := int(animation.get("vertexCount",0)) != 0
		if vertex_animation and index == 0: return {"position":origin}
		var bone := index-(1 if vertex_animation else 0)
		var frames: Array = animation.get("bones",[])
		if frame < 0 or frame >= frames.size() or bone < 0 or bone >= frames[frame].size(): return {"fault":"Missing SpawnFrom animated origin"}
		for axis in range(3): local[axis] = Rotation.halfword(int(frames[frame][bone][9+axis]))
	return Rotation.contact_point(Rotation.scaled_matrix(matrix,scale),origin,local,animated)
