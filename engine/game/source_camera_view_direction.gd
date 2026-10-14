extends RefCounted
const VM = preload("res://asl_vm.gd")
const Collision = preload("res://source_collision.gd")
const Rotation = preload("res://source_rotation.gd")

static func angles(position: Vector3i, target: Vector3i, prior_yaw: int, roots: Array, angle_table: Array) -> Dictionary:
	# Native167a8..16960: signed low32 horizontal squares, then arithmetic
	# shift before the original root-table lookup. This is not GTE SQR.
	if roots.size() != 192: return {"fault":"Missing view-direction root table"}
	var dx := VM.signed32(target.x-position.x)
	var dy := VM.signed32(target.y-position.y)
	var dz := VM.signed32(target.z-position.z)
	var square := VM.signed32(VM.signed32(dx*dx)+VM.signed32(dz*dz))>>12
	if square < 0: return {"fault":"View-direction signed square overflow is not qualified"}
	var horizontal := Collision.distance_root(square,roots)
	var pitch := Collision.wall_normal_angle(Vector2i(dy,horizontal),angle_table)
	var yaw := Collision.wall_normal_angle(Vector2i(dx,dz),angle_table)
	if pitch.has("fault"): return pitch
	if yaw.has("fault"): return yaw
	var heading := Rotation.halfword(int(yaw.angle))
	# Close-range retention compares raw signed halfwords, without wrapping
	# the difference to the shortest angular path.
	if horizontal < 384 and absi(heading-Rotation.halfword(prior_yaw)) >= 17:
		heading = Rotation.halfword(prior_yaw)
	return {"pitch":Rotation.halfword(-int(pitch.angle)),"yaw":heading,"roll":0,"horizontal":horizontal}
