extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
# Retail matrix builder 0x800552fc..0x80055584, signed 4.12 elements.
const VM = preload("res://asl_vm.gd")

static func approach_angle(current: int, target: int, step: int) -> int:
	# 0x80029c34..0x80029d6c, including positive choice at an exact half-turn.
	var delta := (target & 65535)-(current & 65535)
	if halfword(delta) >= 2048:
		delta -= 4096
	if halfword(delta) < -2047:
		delta += 4096
	var amount := absi(halfword(delta))
	if step < halfword(amount):
		amount = step
	return (current+(amount if halfword(delta) > 0 else -amount)) & 4095

static func map_position(position: Array, y_factor: int) -> Dictionary:
	if position.size() != 3:
		return {"fault":"Missing source map position"}
	var result := Vector3i.ZERO
	for axis in range(3):
		result[axis] = VM.signed32(roundi(float(position[axis])*65536.0)) >> 4
	result.y = VM.signed32(VM.signed32(result.y*y_factor) << 3) >> 12
	return {"position":result}

static func halfword(value: int) -> int:
	var packed := value & 65535
	return packed - 65536 if packed >= 32768 else packed

static func transform_long(values: Array, point: Vector3i) -> Dictionary:
	if values.size() != 9:
		return {"fault":"Missing source rotation matrix"}
	var high := Vector3i.ZERO
	var low := Vector3i.ZERO
	for i in range(3):
		var value := VM.signed32(point[i])
		var magnitude := absi(value)
		var sign_value := -1 if value < 0 else 1
		high[i] = halfword((magnitude >> 15) * sign_value)
		low[i] = halfword((magnitude & 32767) * sign_value)
	var result := Vector3i.ZERO
	for row in range(3):
		var high_sum := 0
		var low_sum := 0
		for column in range(3):
			var coefficient := halfword(int(values[row * 3 + column]))
			high_sum += coefficient * high[column]
			low_sum += coefficient * low[column]
		result[row] = VM.signed32(VM.signed32(VM.signed32(high_sum) << 3) + VM.signed32(low_sum >> 12))
	return {"position":result}

static func frame_delta(values: Array, delta: Vector3i) -> Dictionary:
	var scaled := Vector3i(VM.signed32(delta.x << 2),VM.signed32(delta.y << 2),VM.signed32(delta.z << 2))
	var transformed := transform_long(values,scaled)
	if transformed.has("fault"):
		return transformed
	var result: Vector3i = transformed.position
	for i in range(3):
		result[i] = VM.signed32(result[i] + 2) >> 2
	return {"position":result}

static func scaled_matrix(values: Array, scale: Vector3i) -> Array:
	var result := values.duplicate()
	for row in range(3):
		for column in range(3):
			result[row * 3 + column] = clampi((int(values[row * 3 + column]) * scale[column]) >> 12,-32768,32767)
	return result

static func transform_short(values: Array, point: Vector3i) -> Dictionary:
	if values.size() != 9:
		return {"fault":"Missing source point rotation matrix"}
	var result := Vector3i.ZERO
	for row in range(3):
		var total := 0
		for column in range(3):
			total += halfword(int(values[row * 3 + column])) * halfword(point[column])
		result[row] = VM.signed32(total >> 12)
	return {"position":result}

static func wall_sample_pair(yaw: int, origin: Vector3i, point: Vector3i, pairs: Array) -> Dictionary:
	# Retail 0x80031f40..0x80031ffc: yaw only, no actor scale, origin Y unchanged.
	var values := matrix(Vector3i(0,yaw,0),pairs)
	var transformed := transform_short(values,point)
	if transformed.has("fault"):
		return transformed
	var offset: Vector3i = transformed.position
	return {"forward":Vector3i(VM.signed32(origin.x + offset.x),origin.y,VM.signed32(origin.z + offset.z)),"opposite":Vector3i(VM.signed32(origin.x - offset.x),origin.y,VM.signed32(origin.z - offset.z))}

static func contact_point(values: Array, origin: Vector3i, point: Vector3i, use_long: bool) -> Dictionary:
	# 0x80037a80 and 0x800379e4 use different GTE vector paths.
	var transformed := transform_long(values,point) if use_long else transform_short(values,point)
	if transformed.has("fault"):
		return transformed
	var result: Vector3i = transformed.position
	for i in range(3):
		result[i] = VM.signed32(result[i] + origin[i])
	return {"position":result}

static func model_contact_points(values: Array, origin: Vector3i, models: Array, animation: Dictionary = {}, frame: int = 0) -> Dictionary:
	# Source 0x80037e6c..0x80037fe8 preserves model order and one point per model.
	var points: Array[Vector3i] = []
	for index in range(models.size()):
		var local := Vector3i.ZERO
		var use_long := not animation.is_empty()
		if not use_long:
			var bounds: Array = models[index].get("bounds",[])
			if bounds.is_empty():
				return {"fault":"Missing source model contact point"}
			for axis in range(3):
				local[axis] = roundi(float(bounds[0][axis]) * 4096.0)
		elif int(animation.get("vertexCount",0)) != 0 and index == 0:
			points.append(origin)
			continue
		else:
			var bone_index := index - (1 if int(animation.get("vertexCount",0)) != 0 else 0)
			var frames: Array = animation.get("bones",[])
			if frame < 0 or frame >= frames.size() or bone_index >= frames[frame].size():
				return {"fault":"Missing source contact limb pose"}
			for axis in range(3):
				local[axis] = halfword(int(frames[frame][bone_index][9 + axis]))
		var transformed := contact_point(values,origin,local,use_long)
		if transformed.has("fault"):
			return transformed
		points.append(transformed.position)
	return {"points":points}

static func point_offset(values: Array, point: Vector3i, scale: Vector3i) -> Dictionary:
	var transformed := transform_short(values,point)
	if transformed.has("fault"):
		return transformed
	var result: Vector3i = transformed.position
	for row in range(3):
		result[row] = VM.signed32(result[row] * halfword(scale[row])) >> 12
	return {"position":result}

static func compose(parent: Array, child: Array) -> Array:
	if parent.size() != 9 or child.size() != 9:
		return []
	var result: Array = []
	for row in range(3):
		for column in range(3):
			var total := 0
			for axis in range(3):
				total += halfword(int(parent[row * 3 + axis])) * halfword(int(child[axis * 3 + column]))
			result.append(clampi(total >> 12,-32768,32767))
	return result

static func actor_push_probe(values: Array, point: Vector3i, scale: Vector3i, owner_position: Vector3i, correction: Vector2i) -> Dictionary:
	# 0x80035a4c..0x80035b08: rotate, scale axes, then subtract correction in X/Z.
	var offset := point_offset(values,point,scale)
	if offset.has("fault"):
		return offset
	var value: Vector3i = offset.position
	return {"position":Vector3i(VM.signed32(VM.signed32(owner_position.x+value.x)-correction.x),VM.signed32(owner_position.y+value.y),VM.signed32(VM.signed32(owner_position.z+value.z)-correction.y))}

static func parent_pose(parent_matrix: Array, parent_position: Vector3i, child_matrix: Array, child_position: Vector3i) -> Dictionary:
	var rotated := transform_long(parent_matrix,child_position)
	if rotated.has("fault"):
		return rotated
	var position: Vector3i = rotated.position
	for i in range(3):
		position[i] = VM.signed32(position[i] + parent_position[i])
	return {"position":position,"matrix":compose(parent_matrix,child_matrix)}

static func trig(angle: int, pairs: Array) -> Vector2i:
	var a := angle & 65535
	if a >= 32768:
		a -= 65536
	var pair: Array = pairs[absi(a) & 4095]
	return Vector2i(-int(pair[0]) if a < 0 else int(pair[0]),int(pair[1]))

static func multiply(a: int, b: int) -> int:
	return VM.signed32(a * b) >> 12

static func matrix(angles: Vector3i, pairs: Array) -> Array:
	if pairs.size() != 4096:
		return []
	var x := trig(angles.x,pairs)
	var y := trig(angles.y,pairs)
	var z := trig(angles.z,pairs)
	var sx := x.x
	var cx := x.y
	var sy := y.x
	var cy := y.y
	var sz := z.x
	var cz := z.y
	var a := multiply(sy,sx)
	var b := multiply(cy,sx)
	var values := [multiply(cy,cz)+multiply(a,sz),-multiply(cy,sz)+multiply(a,cz),multiply(sy,cx),multiply(sz,cx),multiply(cz,cx),-sx,-multiply(sy,cz)+multiply(b,sz),multiply(b,cz)+multiply(sy,sz),multiply(cy,cx)]
	for i in range(values.size()):
		var packed := int(values[i]) & 65535
		values[i] = packed - 65536 if packed >= 32768 else packed
	return values
