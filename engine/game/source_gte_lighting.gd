extends RefCounted
const Rotation = preload("res://source_rotation.gd")
# RGB result of NCCS(sf=1,lm=1), as used by native183f0. Does not emulate FLAG/FIFO.
static func positive_stage(matrix: Array, vector: Array, background: Array) -> Array:
	var result: Array = []
	for row in range(3):
		var total := int(background[row]) << 12
		for column in range(3): total += Rotation.halfword(int(matrix[row*3+column])) * Rotation.halfword(int(vector[column]))
		result.append(clampi(total >> 12,0,32767))
	return result

static func nccs_rgb(normal: Vector3i, light: Array, color: Array, ambient: Array, base: Array) -> Dictionary:
	if light.size() != 9 or color.size() != 9 or ambient.size() != 3 or base.size() != 3: return {"fault":"Invalid original lighting register spans"}
	var light_ir := positive_stage(light,[normal.x,normal.y,normal.z],[0,0,0])
	var background: Array = []
	for value in ambient: background.append((int(value)&255) << 4)
	var color_ir := positive_stage(color,light_ir,background)
	var rgb: Array = []
	for channel in range(3):
		var mac: int = (((int(base[channel])&255)*int(color_ir[channel])) << 4) >> 12
		rgb.append(clampi(mac >> 4,0,255))
	return {"rgb":rgb,"light_ir":light_ir,"color_ir":color_ir}
