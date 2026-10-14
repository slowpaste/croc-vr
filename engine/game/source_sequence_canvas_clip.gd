extends RefCounted
static func distance(vertex: Dictionary, plane: int, h: int) -> float:
	var point: Vector3 = vertex.position
	var z := -point.z
	match plane:
		0: return z-0.00000001
		1: return 256.0*z+float(h)*point.x
		2: return 256.0*z-float(h)*point.x
		3: return 192.0*z-float(h)*point.y
		4: return 48.0*z+float(h)*point.y
	return -1.0
static func intersection(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var az := -float(a.position.z); var bz := -float(b.position.z)
	var z := lerpf(az,bz,t)
	# Spatial shader outputs attribute*w before hardware clipping, then divides
	# by interpolated w. Preserve that value without an RGB8 re-quantization.
	var point := Vector3(lerpf(float(a.position.x),float(b.position.x),t),lerpf(float(a.position.y),float(b.position.y),t),-z)
	return {"position":point,"uv":(a.uv*az*(1.0-t)+b.uv*bz*t)/z,"color":(a.color*az*(1.0-t)+b.color*bz*t)/z}
static func triangles(vertices: Array, h: int) -> Array:
	var result: Array = []
	for start in range(0,vertices.size(),3):
		var polygon: Array = [vertices[start],vertices[start+1],vertices[start+2]]
		for plane in range(5):
			if polygon.is_empty(): break
			var clipped: Array = []
			var previous: Dictionary = polygon.back()
			var prior_distance := distance(previous,plane,h)
			for current in polygon:
				var current_distance := distance(current,plane,h)
				if (prior_distance >= 0) != (current_distance >= 0):
					clipped.append(intersection(previous,current,prior_distance/(prior_distance-current_distance)))
				if current_distance >= 0: clipped.append(current)
				previous = current; prior_distance = current_distance
			polygon = clipped
		for index in range(1,polygon.size()-1): result.append_array([polygon[0],polygon[index],polygon[index+1]])
	return result
