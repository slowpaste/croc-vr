extends RefCounted
const VM = preload("res://asl_vm.gd")
const Collision = preload("res://source_collision.gd")
# Polygon handler3d620..3d9a8: signed products, staged shifts and screen clamps.
static func project(triangles: Array, angle: int, render_scale: int, quarter: Array) -> Dictionary:
	if quarter.size() != 1025:
		return {"fault":"Missing source transition trigonometry"}
	var sine := Collision.sine(angle,quarter)
	var cosine := Collision.sine(angle+1024,quarter)
	var result: Array = []
	for triangle in triangles:
		if triangle.size() != 3:
			return {"fault":"Invalid source transition triangle"}
		var projected: Array = []
		for point in triangle:
			if point.size() != 2:
				return {"fault":"Invalid source transition vertex"}
			var x := VM.signed32(int(point[0]))>>8
			var y := VM.signed32(int(point[1]))>>8
			var rotated_x := VM.signed32((VM.signed32(x*cosine)>>4)-(VM.signed32(y*sine)>>4))
			var rotated_y := VM.signed32((VM.signed32(x*sine)>>4)+(VM.signed32(y*cosine)>>4))
			var scaled_x := VM.signed32((rotated_x>>12)*render_scale)>>16
			var scaled_y := VM.signed32((rotated_y>>12)*render_scale)>>16
			var screen_x := VM.signed32(int(VM.signed32(scaled_x*160)/100)+256)
			var screen_y := VM.signed32(scaled_y+120)
			projected.append(Vector2i(clampi(screen_x,-128,768),clampi(screen_y,-120,360)))
		result.append(projected)
	return {"triangles":result}
