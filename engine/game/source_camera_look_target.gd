extends RefCounted
const Motion = preload("res://source_camera_motion.gd")
const Collision = preload("res://source_collision.gd")
const VM = preload("res://asl_vm.gd")
static func step(target: Vector3i, actor_yaw: int, bearing: int, offset_y: int, current_offset: Vector2i, offset_velocity: Vector2i, current_y: int, velocity_y: int, style: int, secondary: int, last_ground_y: int, quarter: Array) -> Dictionary:
	var desired := Motion.desired_look_offset(actor_yaw,bearing,quarter)
	if desired.has("fault"): return desired
	var x := Motion.look_offset_step(current_offset.x,desired.offset.x,offset_velocity.x)
	var z := Motion.look_offset_step(current_offset.y,desired.offset.y,offset_velocity.y)
	var offset := Vector2i(int(x.position),int(z.position))
	var rotated := Collision.local_point(offset,-bearing,quarter)
	var relative_y := VM.signed32(offset_y)
	if style != 1 and style != 11 and (secondary&2) == 0:
		relative_y = VM.signed32(relative_y-mini(VM.signed32(target.y-last_ground_y),1408))
	var desired_y := VM.signed32(target.y+relative_y)
	var y := Motion.look_height_step(current_y,desired_y,velocity_y)
	return {"position":Vector3i(VM.signed32(target.x+rotated.x),int(y.height),VM.signed32(target.z+rotated.y)),"offset":offset,"offset_velocity":Vector2i(int(x.velocity),int(z.velocity)),"velocity_y":int(y.velocity),"desired_offset":desired.offset,"desired_y":desired_y}
