extends RefCounted
const Rotation = preload("res://source_rotation.gd")
static func part_light_matrix(part: Dictionary, view: Dictionary, lighting: Dictionary) -> Dictionary:
	if not lighting.has("lightMatrix") or lighting.lightMatrix.size() != 9 or not view.has("matrix") or view.matrix.size() != 9: return {"fault":"Missing original cutscene light matrix"}
	if bool(lighting.get("staticWorld",false)):
		#20700 bakes terrain colors with the zero view16588 before camera playback.
		return {"matrix":Rotation.compose(lighting.lightMatrix,part.matrix)}
	var transformed := preload("res://source_cutscene_transform.gd").compose_view(part,view)
	if transformed.has("fault"): return transformed
	var inverse: Array = []
	for row in range(3):
		for column in range(3): inverse.append(int(view.matrix[column*3+row]))
	#166f0 prepares world-light*transpose(view);1635c then includes the part view.
	var matrix := Rotation.compose(Rotation.compose(lighting.lightMatrix,inverse),transformed.matrix)
	var scale := 4096 if part.has("vertices") else preload("res://source_cutscene_transform.gd").normal_scale(int(transformed.scale))
	if scale != 4096: matrix = Rotation.compose(matrix,[scale,0,0,0,scale,0,0,0,scale])
	return {"matrix":matrix}

static func face_rgb(face: Dictionary, vertex: int, model: Dictionary, light_matrix: Array, lighting: Dictionary) -> Dictionary:
	if not lighting.has_all(["colorMatrix","ambientBytes","textureBase"]): return {"fault":"Missing original cutscene color setup"}
	var flags := int(face.flags)
	var textured := (flags&1) != 0
	var base: Array = lighting.textureBase if textured else face.color
	if textured and (flags&0x40) != 0 and (flags&0x20) != 0: return {"rgb":base.duplicate()}
	var values: Array
	if flags&0x40:
		if not face.has("sourceHeader"): return {"fault":"Missing original face normal"}
		values = face.sourceHeader
	else:
		if not model.has("sourceNormals") or vertex < 0 or vertex >= model.sourceNormals.size(): return {"fault":"Missing original vertex normal"}
		values = model.sourceNormals[vertex]
	if values.size() < 3: return {"fault":"Invalid original normal span"}
	return preload("res://source_gte_lighting.gd").nccs_rgb(Vector3i(int(values[0]),int(values[1]),int(values[2])),light_matrix,lighting.colorMatrix,lighting.ambientBytes,base)
