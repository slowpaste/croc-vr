extends RefCounted
const Movement = preload("res://source_camera_ordinary_update.gd")
const Look = preload("res://source_camera_look_target.gd")
const Motion = preload("res://source_camera_motion.gd")
static func step(world: Node, state: Dictionary, target: Vector3i, heading: int, distance_target: int, height_target: int, pad_kind: int, waveform: Array = [], prepared_override: Dictionary = {}) -> Dictionary:
	var movement_input := state.duplicate(true)
	movement_input.shake_index = 0 # Shake is the later stage, not movement.
	var result := Movement.step(world,movement_input,target,heading,distance_target,height_target,pad_kind,prepared_override)
	if result.has("fault"): return result
	var next: Dictionary = result.camera_state
	next.shake_index = int(state.get("shake_index",0))
	if bool(result.get("held",false)):
		return {"camera_state":next,"held":true}
	if (int(state.get("primary_flags",0x800))&0x800) == 0:
		next.look_position = target
		result.camera_state = next
		result.direct_pose = true
		return result
	if not state.has_all(["look_position","look_offset_y"]): return {"fault":"Missing full camera look-target state"}
	var look := Look.step(target,heading,int(next.control_bearing),int(state.look_offset_y),state.get("look_offset",Vector2i.ZERO),state.get("look_offset_velocity",Vector2i.ZERO),int(state.look_position.y),int(state.get("look_velocity_y",0)),int(world.room_data.style),int(state.get("secondary_flags",0)),int(state.get("last_ground_y",target.y)),world.runtime_tables.trigonometry.quarterSine)
	if look.has("fault"): return look
	next.look_position = look.position;next.look_offset = look.offset;next.look_offset_velocity = look.offset_velocity;next.look_velocity_y = look.velocity_y
	next.desired_look_offset = look.desired_offset
	var shaken := Motion.shake_step(int(next.shake_index),int(state.get("shake_strength",0)),int(next.position.y),int(next.look_position.y),waveform)
	if shaken.has("fault"): return shaken
	next.position.y = int(shaken.camera_y);next.look_position.y = int(shaken.target_y);next.shake_index = int(shaken.index)
	result.camera_state = next
	return result
