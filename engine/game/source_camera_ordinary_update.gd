extends RefCounted
const Motion = preload("res://source_camera_motion.gd")
const VM = preload("res://asl_vm.gd")
# Qualified ordinary pre-render branch; unsupported branches remain explicit.
static func step(world: Node, state: Dictionary, target: Vector3i, target_yaw: int, distance_target: int, height_target: int, pad_kind: int, prepared_override: Dictionary = {}) -> Dictionary:
	# Native415b0..415cc: hold returns before target, rates, queries or motion.
	if int(state.get("hold_counter",0)) != 0:
		var held_state := state.duplicate(true)
		held_state.hold_counter = VM.signed32(int(held_state.hold_counter)-1)
		return {"camera_state":held_state,"held":true}
	for key in ["shake_index"]:
		if int(state.get(key,0)) != 0: return {"fault":"Ordinary camera branch does not cover "+key}
	var override_present := bool(state.get("override_present",false))
	if override_present and not state.has("override_position"):
		return {"fault":"Missing camera override position"}
	if not state.has("position"): return {"fault":"Missing ordinary camera position"}
	var position: Vector3i = state.position
	var tables: Dictionary = world.runtime_tables
	var height_copy := Motion.height_copy_step(height_target,int(state.get("height_copy",height_target)),pad_kind,override_present,int(state.get("held",0)),int(state.get("pressed",0)))
	var requested: Dictionary = {"manual_yaw":int(state.get("manual_yaw",0)),"distance":int(state.get("distance_target",0)),"obstruction_enabled":false}
	var yaw: Dictionary = {"velocity":int(state.get("yaw_velocity",0))}
	var distance: Dictionary = {"velocity":int(state.get("distance_velocity",0))}
	var adjusted: Dictionary = {}
	var first: Dictionary = {}
	var second: Dictionary = {}
	var query_modes: Array[bool] = []
	if distance_target == 0:
		# Native4175c jumps to41c98: copy target X/Z, query once, retain
		# angular/distance motion and prior first-query collision status.
		if not state.has("target_roll"): return {"fault":"Zero-distance camera requires target roll"}
		var query_state := state.duplicate(true)
		query_state.position = Vector3i(target.x,position.y,target.z)
		query_modes.append(int(query_state.get("query_counter",0)) != 0)
		second = world.source_camera_collision_phase(query_state)
		if second.has("fault"): return second
		first = {"collision_bits":0}
		adjusted = {"bearing":int(state.target_roll)&65535}
	else:
		var measured := Motion.override_query(position,target,tables.distanceRoot.values,tables.wallAngles.values)
		if measured.has("fault"): return measured
		var rates := Motion.rates(pad_kind,int(state.get("main_mode",4)),int(state.get("manual_yaw",0)),int(state.get("orbit_offset",0)),override_present,int(state.get("collision_status",0)))
		var override_query := Motion.override_query(target,state.override_position,tables.distanceRoot.values,tables.wallAngles.values) if override_present else {}
		if override_query.has("fault"): return override_query
		if not prepared_override.is_empty():
			if not override_present or not prepared_override.has_all(["bearing","distance"]): return {"fault":"Invalid prepared camera override query"}
			override_query = prepared_override
		requested = Motion.target_state(target_yaw,int(measured.bearing),int(measured.distance),int(state.get("manual_yaw",0)),int(state.get("orbit_offset",0)),distance_target,int(state.get("held",0)),int(state.get("pressed",0)),override_query)
		yaw = Motion.yaw_step(int(measured.bearing),int(requested.target_yaw),int(state.get("yaw_velocity",0)),int(rates.acceleration_shift),int(rates.easing_shift),int(rates.yaw_limit))
		var horizontal := Motion.horizontal_position(target,int(yaw.yaw),int(measured.distance),tables.trigonometry.quarterSine)
		var query_state := state.duplicate(true)
		query_state.position = Vector3i(horizontal.position.x,position.y,horizontal.position.y)
		query_modes.append(int(query_state.get("query_counter",0)) != 0)
		first = world.source_camera_collision_phase(query_state)
		if first.has("fault"): return first
		distance = Motion.distance_step(int(measured.distance),int(requested.distance),int(state.get("distance_velocity",0)),int(rates.position_shift),int(rates.height_shift))
		adjusted = Motion.override_query(first.position,target,tables.distanceRoot.values,tables.wallAngles.values)
		if adjusted.has("fault"): return adjusted
		horizontal = Motion.horizontal_position(target,int(adjusted.bearing),int(distance.distance),tables.trigonometry.quarterSine)
		query_state = first.camera_state
		query_state.position = Vector3i(horizontal.position.x,position.y,horizontal.position.y)
		query_modes.append(int(query_state.get("query_counter",0)) != 0)
		second = world.source_camera_collision_phase(query_state)
		if second.has("fault"): return second
	var desired_height := Motion.vertical_target(target.y,height_copy,int(world.room_data.style),int(state.get("secondary_flags",0)),int(state.get("last_ground_y",target.y)),int(state.get("lower_tile_actor",-1)),int(state.get("upper_height_actor",0)))
	if override_present and int(world.room_data.style) in [1,11]:
		desired_height = Motion.swimming_override_target(target.y,int(state.override_position.y),height_copy,int(state.get("upper_height_actor",0)))
	var vertical_enabled := (int(state.get("primary_flags",0x800))&0x800) != 0
	if not vertical_enabled: desired_height = VM.signed32(target.y+height_copy)
	var ceiling_blocked := VM.signed32(desired_height+3072) < position.y
	var height := Motion.height_step(position.y,desired_height,VM.signed32(int(second.height)+1365),int(state.get("height_velocity",0))) if vertical_enabled else {"height":desired_height,"velocity":int(state.get("height_velocity",0))}
	var next: Dictionary = second.camera_state
	if int(next.get("query_counter",0)) != 0: next.query_counter = VM.signed32(int(next.query_counter)-1)
	if vertical_enabled:
		var orbit := Motion.orbit_step(int(state.get("orbit_offset",0)),int(next.get("query_counter",0)),int(second.collision_bits),bool(requested.obstruction_enabled),ceiling_blocked)
		next.orbit_offset = int(orbit.orbit_offset);next.query_counter = int(orbit.query_counter)
	next.position.y = int(height.height)
	next.yaw_velocity = int(yaw.velocity);next.distance_velocity = int(distance.velocity);next.height_velocity = int(height.velocity)
	next.control_bearing = int(adjusted.bearing)
	next.manual_yaw = int(requested.manual_yaw);next.distance_target = int(requested.distance)
	next.height_copy = height_copy
	next.collision_status = int(state.get("collision_status",0)) if distance_target == 0 else int(int(first.collision_bits) != 0)
	if not vertical_enabled:
		if not state.has("target_pose_words") or state.target_pose_words.size() != 6:
			return {"fault":"Direct camera branch requires the complete target pose"}
		next.target_pose_cache = state.target_pose_words.duplicate(true)
	return {"camera_state":next,"query_modes":query_modes,"first_collision_bits":int(first.collision_bits),"second_collision_bits":int(second.collision_bits),"obstruction_enabled":bool(requested.obstruction_enabled),"ceiling_blocked":ceiling_blocked,"desired_height":desired_height,"terrain_minimum":VM.signed32(int(second.height)+1365)}

