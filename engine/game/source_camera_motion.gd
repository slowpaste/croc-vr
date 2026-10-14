extends RefCounted
const Rotation = preload("res://source_rotation.gd")
const VM = preload("res://asl_vm.gd")
const Collision = preload("res://source_collision.gd")
const SHAKE_WAVEFORM = [0,-220,-251,-117,60,159,135,31,-70,-104,-65,6,57,60,24,-19,-41,-32,-6,18,25,0xface]
static func desired_look_offset(actor_yaw: int, control_bearing: int, quarter_sine: Array) -> Dictionary:
	# Native41d48..41dd0: abs(sin(bearing-heading))>>2 magnitude, then
	# actor-relative sine/cosine; signed low32 products before>>12.
	if quarter_sine.size() != 1025: return {"fault":"Missing look-offset trigonometry"}
	var magnitude := absi(Collision.sine(control_bearing-actor_yaw,quarter_sine))>>2
	var angle := actor_yaw-control_bearing
	return {"offset":Vector2i(VM.signed32(Collision.sine(angle,quarter_sine)*magnitude)>>12,VM.signed32(Collision.sine(angle+1024,quarter_sine)*magnitude)>>12)}
static func look_offset_step(current: int, desired: int, velocity: int) -> Dictionary:
	# Native41dd4..42090, identical X/Z scalar paths.
	var position := VM.signed32(current);var target := VM.signed32(desired);var speed := VM.signed32(velocity)
	if speed == 0:
		var delta := VM.signed32(target-position)
		var magnitude := VM.signed32(-delta) if delta < 0 else delta
		if magnitude < 17: return {"position":target,"velocity":0}
		return {"position":position,"velocity":delta>>8}
	position = VM.signed32(position+speed)
	var residual := VM.signed32(target-position)
	var magnitude := VM.signed32(-residual) if residual < 0 else residual
	if magnitude < 17: return {"position":target,"velocity":0}
	if residual > 0: speed = mini(mini(VM.signed32(speed+8),residual>>3),32)
	elif residual < 0: speed = maxi(maxi(VM.signed32(speed-8),residual>>3),-32)
	return {"position":position,"velocity":speed}
static func look_height_step(current: int, desired: int, velocity: int) -> Dictionary:
	# Native421fc..422f0, distinct from camera-height smoothing.
	var position := VM.signed32(current);var target := VM.signed32(desired);var speed := VM.signed32(velocity)
	if speed == 0:
		var delta := VM.signed32(target-position)
		var magnitude := VM.signed32(-delta) if delta < 0 else delta
		if magnitude < 65: return {"height":target,"velocity":0}
		return {"height":position,"velocity":delta>>4}
	position = VM.signed32(position+speed)
	var residual := VM.signed32(target-position)
	var magnitude := VM.signed32(-residual) if residual < 0 else residual
	if magnitude < 17: return {"height":target,"velocity":0}
	if residual > 0: speed = mini(VM.signed32(speed+32),residual>>2)
	elif residual < 0: speed = maxi(VM.signed32(speed-32),residual>>2)
	return {"height":position,"velocity":speed}
static func shake_step(index: int, strength: int, camera_y: int, target_y: int, waveform: Array) -> Dictionary:
	# Native426a0..42724: low32 product, arithmetic>>16, paired Y offset.
	if index == 0: return {"index":0,"camera_y":VM.signed32(camera_y),"target_y":VM.signed32(target_y),"offset":0}
	if index < 0 or index+1 >= waveform.size() or int(waveform[index]) == 0xface:
		return {"fault":"Camera shake index outside waveform"}
	var offset := VM.signed32(int(waveform[index])*VM.signed32(strength))>>16
	var next_index := VM.signed32(index+1)
	if int(waveform[next_index]) == 0xface: next_index = 0
	return {"index":next_index,"camera_y":VM.signed32(camera_y+offset),"target_y":VM.signed32(target_y+offset),"offset":offset}
static func swimming_override_target(actor_y: int, override_y: int, height_copy: int, upper_height: int) -> int:
	# Native4235c..423d0 always caps against upperheight; unlike normal
	# swimming it does not require a valid actor lower-tile cache.
	var copy := VM.signed32(height_copy)
	var relative := copy if VM.signed32(actor_y-override_y) >= 0 and copy >= 0 else VM.signed32(-copy)
	relative = mini(relative,VM.signed32(VM.signed32(upper_height-actor_y)-2048))
	return VM.signed32(actor_y+relative)
static func vertical_target(actor_y: int, height_copy: int, style: int, secondary_flags: int, last_ground_y: int, lower_tile: int, upper_height: int) -> int:
	# Native422fc..42440, no override: normal ground retains last-ground
	# reference unless flag2; swimming styles1/11 cap against upper height.
	var relative := VM.signed32(height_copy)
	if style == 1 or style == 11:
		if lower_tile != -1: relative = mini(relative,VM.signed32(VM.signed32(upper_height-actor_y)-2048))
	elif (secondary_flags&2) == 0:
		relative = maxi(VM.signed32(relative-VM.signed32(actor_y-last_ground_y)),0)
	return VM.signed32(actor_y+relative)
static func height_copy_step(requested_height: int, current_copy: int, pad_kind: int, override_present: bool, held: int, pressed: int) -> int:
	# Native4169c..41750. Rates use the prior manual offset; this separate
	# word is adjusted before yaw/distance and supplies the vertical target.
	if override_present: return VM.signed32(requested_height)
	if (pressed&0x40000000) != 0 and pad_kind != 2: return 1365
	if (held&0x40000000) == 0: return VM.signed32(requested_height)
	var copy := VM.signed32(current_copy)
	if (held&0x10000) != 0 and copy < 3172: copy = VM.signed32(copy+128)
	if (held&0x40000) != 0 and copy >= 1366: copy = VM.signed32(copy-128)
	return copy

static func orbit_step(offset: int, query_counter: int, collision_bits: int, obstruction_enabled: bool, ceiling_blocked: bool) -> Dictionary:
	# Native42460..42564. Query counter is the value AFTER41d28 decrement;
	# reaching zero through the obstruction path arms15 alternate-query updates.
	var angle := Rotation.halfword(offset)
	var counter := VM.signed32(query_counter)
	if ceiling_blocked or ((collision_bits&1)!=0 and obstruction_enabled):
		var prior := angle&65535
		angle = Rotation.halfword(prior+64)
		if angle > 2048: angle = Rotation.halfword(prior-4032)
		if not ceiling_blocked and angle == 0: counter = 15
	elif (collision_bits&2)!=0 and obstruction_enabled:
		var prior := angle&65535
		angle = Rotation.halfword(prior-64)
		if angle < -2048: angle = Rotation.halfword(prior+4032)
		if angle == 0: counter = 15
	else:
		if angle > 0: angle = Rotation.halfword(angle-64)
		if angle < 0: angle = Rotation.halfword(angle+64)
	return {"orbit_offset":angle,"query_counter":counter}

static func height_step(current: int, desired: int, minimum: int, velocity: int) -> Dictionary:
	# Native4256c..4269c. Terrain minimum snaps upward; otherwise velocity
	# advances height before the residual is used for acceleration and clamps.
	var height := VM.signed32(current)
	var floor_height := VM.signed32(minimum)
	var target := maxi(VM.signed32(desired),floor_height)
	var speed := VM.signed32(velocity)
	if height < floor_height: return {"height":floor_height,"velocity":0}
	if speed == 0:
		var delta := VM.signed32(target-height)
		var magnitude := VM.signed32(-delta) if delta < 0 else delta
		if magnitude >= 17: speed = delta>>4
		return {"height":height,"velocity":speed}
	height = VM.signed32(height+speed)
	var residual := VM.signed32(target-height)
	var magnitude := VM.signed32(-residual) if residual < 0 else residual
	if magnitude < 17: return {"height":target,"velocity":0}
	speed = VM.signed32(speed+(residual>>4))
	var bound := VM.signed32((residual>>3)+(residual>>4))
	speed = mini(speed,bound) if speed > 0 else maxi(speed,bound)
	return {"height":height,"velocity":speed}

static func distance_step(current: int, target: int, velocity: int, acceleration_shift: int, easing_shift: int) -> Dictionary:
	# Native41b34..41bf4. A zero velocity is initialized without moving until
	# the following update; signed32 overflow also applies to absolute delta.
	if acceleration_shift < 0 or acceleration_shift > 31 or easing_shift < 0 or easing_shift > 31:
		return {"fault":"Invalid original camera distance rates"}
	var delta := VM.signed32(target-current)
	var magnitude := VM.signed32(-delta) if delta < 0 else delta
	var speed := VM.signed32(velocity)
	if speed == 0:
		if magnitude >= 65: speed = delta>>acceleration_shift
		return {"distance":VM.signed32(current),"velocity":speed}
	speed = VM.signed32(speed+(delta>>acceleration_shift))
	var bound := delta>>easing_shift
	speed = mini(speed,bound) if speed > 0 else maxi(speed,bound)
	var distance := VM.signed32(current+speed)
	if magnitude < 32: speed = 0
	return {"distance":distance,"velocity":speed}

static func override_query(target_position: Vector3i, override_position: Vector3i, roots: Array, angles: Array) -> Dictionary:
	# Original38ffc/39118 compare override-target in X/Z; height is excluded.
	if roots.size() != 192: return {"fault":"Missing source camera distance-root table"}
	var delta := Vector3i(VM.signed32(override_position.x-target_position.x),0,VM.signed32(override_position.z-target_position.z))
	var bearing := Collision.wall_normal_angle(Vector2i(delta.x,delta.z),angles)
	if bearing.has("fault"): return bearing
	return {"bearing":int(bearing.angle)&4095,"distance":Collision.player_distance(delta,roots)}

static func horizontal_position(actor_position: Vector3i, yaw: int, distance: int, quarter_sine: Array) -> Dictionary:
	# Native41a44..41ab0 takes the low32 product before arithmetic>>12.
	if quarter_sine.size() != 1025: return {"fault":"Missing source camera trigonometry table"}
	var dx := VM.signed32(Collision.sine(yaw,quarter_sine)*VM.signed32(distance))>>12
	var dz := VM.signed32(Collision.sine(yaw+1024,quarter_sine)*VM.signed32(distance))>>12
	return {"position":Vector2i(VM.signed32(actor_position.x-dx),VM.signed32(actor_position.z-dz))}

static func target_state(actor_yaw: int, current_bearing: int, measured_distance: int, manual_yaw: int, orbit_offset: int, base_distance: int, held: int, pressed: int, override: Dictionary = {}) -> Dictionary:
	# Native41764..418fc, after source distance/bearing queries.
	if not override.is_empty():
		if not override.has_all(["bearing","distance"]): return {"fault":"Incomplete source camera override query"}
		return {"target_yaw":int(override.bearing)&65535 if VM.signed32(int(override.distance))>2048 else actor_yaw&65535,"distance":VM.signed32(base_distance),"manual_yaw":manual_yaw&65535,"obstruction_enabled":false}
	var manual := manual_yaw&65535
	if (pressed&0x40000000) != 0: manual = current_bearing&65535
	if (held&0x40000000) != 0:
		if (held&0x20000) != 0: manual = (manual+64)&4095
		if (held&0x80000) != 0: manual = (manual-64)&4095
		return {"target_yaw":manual,"distance":VM.signed32((VM.signed32(base_distance)>>1)+(VM.signed32(base_distance)>>2)),"manual_yaw":manual,"obstruction_enabled":false}
	return {"target_yaw":(actor_yaw+orbit_offset)&65535,"distance":VM.signed32(base_distance),"manual_yaw":manual,"obstruction_enabled":VM.signed32(base_distance<<1)<VM.signed32(measured_distance)}

static func rates(pad_kind: int, main_mode: int, manual_yaw: int, orbit_offset: int, override_present: bool, collision_status: int) -> Dictionary:
	# Native415fc..41688. Two offsets are loaded as signed halfwords;
	# the collision-status and override tests consume complete words.
	var gentle := pad_kind == 2 and main_mode == 4 and Rotation.halfword(manual_yaw) == 0 and Rotation.halfword(orbit_offset) == 0 and not override_present
	if gentle or collision_status != 0:
		return {"acceleration_shift":7,"easing_shift":6,"yaw_limit":16,"position_shift":4,"height_shift":3}
	return {"acceleration_shift":6,"easing_shift":4,"yaw_limit":128,"position_shift":5,"height_shift":4}

static func yaw_step(current: int, target: int, velocity: int, acceleration_shift: int, easing_shift: int, limit: int) -> Dictionary:
	# Native41918..41a40: signed12 delta, halfword angular velocity, asymmetric
	# arithmetic shifts and direction-specific clamps. Preserve the near-target
	# raw halfword assignment rather than imposing a new angle normalization.
	if acceleration_shift < 0 or acceleration_shift > 31 or easing_shift < 0 or easing_shift > 31 or limit < 0:
		return {"fault":"Invalid original camera yaw rates"}
	var delta := Rotation.halfword((target-current)<<4)>>4
	if absi(delta) < 3:
		return {"yaw":target&65535,"velocity":0}
	var speed := Rotation.halfword(Rotation.halfword(velocity)+(delta>>acceleration_shift))
	if delta > 0:
		speed = Rotation.halfword(speed+1)
		speed = mini(speed,delta>>easing_shift)
		speed = mini(speed,limit)
		speed = mini(speed,delta)
	else:
		speed = Rotation.halfword(speed-1)
		speed = maxi(speed,delta>>easing_shift)
		speed = maxi(speed,-limit)
		speed = maxi(speed,delta)
	return {"yaw":(current+speed)&4095,"velocity":speed}
