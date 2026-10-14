extends RefCounted
const VM = preload("res://asl_vm.gd")
const VR_HEIGHT := 0.15
const ORIGINAL_WORDMARK := Rect2(50,13,411,132)
static func vr_effect_transform(logo_nodes: Array) -> Transform3D:
	# Measured from the original executable's settled title capture, rather
	# than a box-art logo: wordmark x50..461/y13..145, subtitle x210..466/
	# y130..146. Map both axes separately: PS1 pixels are not square.
	var depth:float=preload("res://vr_frontend_panel.gd").DISTANCE
	var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
	for logo in logo_nodes:
		var settled:Transform3D=logo.transform
		settled.origin.z=-depth
		for surface in range(logo.mesh.get_surface_count()):
			for vertex in logo.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point:Vector3=settled*vertex
				var projected:=Vector2(point.x,point.y)*(-depth/point.z)
				minimum=minimum.min(projected);maximum=maximum.max(projected)
	var pixel:Vector2=(maximum-minimum)/ORIGINAL_WORDMARK.size
	var origin:=Vector3(minimum.x+(256.0-ORIGINAL_WORDMARK.position.x)*pixel.x,maximum.y-(120.0-ORIGINAL_WORDMARK.position.y)*pixel.y,-depth)
	return Transform3D(Basis.from_scale(Vector3(256.0*pixel.x,120.0*pixel.y,1.0)),origin)
static func vr_position(pose: Vector3i, cell_meters: float) -> Vector3:
	# Preserve the original approach animation with a readable four-metre
	# endpoint in stereo, rather than beginning inside the viewer's head.
	return Vector3(float(pose.x)*cell_meters/4096.0,VR_HEIGHT+float(pose.y)*cell_meters/4096.0,-preload("res://vr_frontend_panel.gd").DISTANCE-float(1800-pose.z)*cell_meters/4096.0)
static func initialize() -> Dictionary:
	# Main13218..13248 initializes both logo transforms.
	return {"positions":[Vector3i(0,-175,0),Vector3i(0,-175,0)],"angles":[Vector3i(0,2048,0),Vector3i(0,2048,0)]}
static func advance(state: Dictionary) -> Dictionary:
	# Main13d38..13ddc. Near-target overshoot clamps on the following update.
	var result := state.duplicate(true)
	for index in range(2):
		var position: Vector3i = result.positions[index]
		var step := maxi(VM.signed32(1800-position.z)>>4,8)
		position.z = VM.signed32(position.z+step) if position.z < 1800 else 1800
		result.positions[index] = position
	return result
