extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
# Source 44-byte surface evaluation, traced from retail 0x800307e8..0x80030960.
# Inputs are model-local 4.12 coordinates; tile selection/contact response is separate.
const VM = preload("res://asl_vm.gd")

static func distance_root(value: int, table: Array) -> int:
	if value == 0:
		return 0
	var leading := 0
	var mask := 0x80000000
	while (value & mask) == 0 and leading < 32:
		leading += 1
		mask >>= 1
	var even := leading & ~1
	var exponent := (19 - even) >> 1
	var normalized := value << (even - 24) if even >= 24 else value >> (24 - even)
	var result := int(table[normalized - 64])
	return result << exponent if exponent >= 0 else result >> -exponent

static func player_distance(delta: Vector3i, table: Array) -> int:
	return distance_root(square_ir(delta.x) + square_ir(delta.y) + square_ir(delta.z),table)

static func player_point_contact(delta: Vector3i, point_radius: int, actor_radius: int, actor_height: int, scale_y: int, actor_primary: int, actor_secondary: int, player_primary: int, table: Array) -> bool:
	# Modes 4/8 at 0x80038054..0x80038300; caller supplies transformed player points.
	var column := (actor_secondary & 4) == 0
	if column and (actor_secondary & 8) == 0:
		return false
	if column:
		var height := VM.signed32(scale_y * actor_height) >> 12
		if delta.y <= 0 or delta.y >= height:
			return false
	var radius := point_radius
	if (player_primary & 0x10000000) == 0 or (actor_primary & 0x10000) == 0:
		radius >>= 1
	var threshold := VM.signed32(radius + actor_radius) & 0xffffffff
	var distance := player_distance(Vector3i(delta.x,0 if column else delta.y,delta.z),table)
	return (distance & 0xffffffff) < threshold

static func player_slab_contact(delta: Vector3i, point_radius: int, actor_radius: int, packed_limits: int, scale_x: int, angle: int, actor_primary: int, player_primary: int, table: Array, quarter: Array) -> bool:
	# Secondary mode 0x400, 0x80038304..0x80038598: local X slab, radial Y/Z.
	var local := local_point(Vector2i(delta.x,delta.z),angle,quarter)
	var lower := packed_limits & 65535
	var upper := (packed_limits >> 16) & 65535
	lower = lower - 65536 if lower >= 32768 else lower
	upper = upper - 65536 if upper >= 32768 else upper
	var low_limit := VM.signed32(- (VM.signed32(lower * scale_x) >> 12))
	var high_limit := VM.signed32(upper * scale_x) >> 12
	if local.x <= low_limit or local.x >= high_limit:
		return false
	var radius := point_radius
	if (player_primary & 0x10000000) == 0 or (actor_primary & 0x10000) == 0:
		radius >>= 1
	var threshold := VM.signed32(radius + actor_radius) & 0xffffffff
	var distance := distance_root(square_ir(delta.y) + square_ir(local.y),table)
	return (distance & 0xffffffff) < threshold

static func model_pair_contact(delta: Vector3i, player_radius: int, actor_radius: int, actor_scale_y: int, actor_primary: int, player_primary: int, table: Array) -> bool:
	# Default contact path 0x80038788..0x80038aec scales actor radius by Y only.
	var scaled_radius := actor_radius
	if actor_scale_y != 4096:
		scaled_radius = VM.signed32(actor_scale_y * actor_radius) >> 12
	var threshold := VM.signed32(player_radius + scaled_radius)
	if (player_primary & 0x10000000) == 0 or (actor_primary & 0x10000) == 0:
		threshold >>= 1
	return (player_distance(delta,table) & 0xffffffff) < (threshold & 0xffffffff)

static func player_contact_flags(actor_primary: int, player_primary: int) -> Dictionary:
	# Successful contact response 0x80038af8..0x80038bc4, in source order.
	if (actor_primary & 0x10000) != 0:
		if (player_primary & 0x10000000) != 0:
			actor_primary |= 0x100000
		elif (player_primary & 0x40000000) == 0:
			player_primary |= 0x100000
	if (actor_primary & 0x20000) != 0:
		actor_primary |= 0x100000
	if (actor_primary & 0x4000) != 0:
		if (player_primary & 0x40000000) == 0:
			player_primary |= 0x100000
		actor_primary |= 0x100000
	return {"actor":VM.signed32(actor_primary),"player":VM.signed32(player_primary)}

static func platform_contact_flags(primary: int, secondary: int, rider_primary: int, rider_secondary: int, contact_flags: int, contact_type: int) -> Dictionary:
	# 0x8002d4c4..0x8002d550; motion may still be carried when these bits are not set.
	if (rider_secondary & 2) != 0 or ((contact_flags & 0x100) != 0 and contact_type == 5):
		primary = VM.signed32(primary | 0x400000)
		if (rider_primary & 0x800) != 0:
			secondary |= 0x200
		if (rider_primary & 0x40000) != 0:
			secondary |= 0x40
	return {"primary":primary,"secondary":secondary}

static func platform_motion_allowed(current: Vector3i, previous: Vector3i) -> bool:
	# Retail proximity gate 0x80038f18..0x80038fe8 uses inclusive component limits.
	var total := 0
	for i in range(3):
		var delta := VM.signed32(current[i] - previous[i])
		if delta > 2048 or delta < -2048:
			return false
		total += square_ir(delta)
	return total < 1024

static func platform_translation(rider: Vector3i, current: Vector3i, previous: Vector3i, carry_y: bool) -> Vector3i:
	if not platform_motion_allowed(current,previous):
		return rider
	return Vector3i(VM.signed32(rider.x + VM.signed32(current.x - previous.x)),VM.signed32(rider.y + VM.signed32(current.y - previous.y)) if carry_y else rider.y,VM.signed32(rider.z + VM.signed32(current.z - previous.z)))

static func platform_pose(rider: Vector3i, rider_yaw: int, current: Vector3i, previous: Vector3i, current_yaw: int, previous_yaw: int, carry_full: bool, quarter: Array) -> Dictionary:
	if not platform_motion_allowed(current,previous):
		return {"position":rider,"yaw":rider_yaw,"carried":false}
	var position := platform_translation(rider,current,previous,carry_full)
	var yaw := rider_yaw
	if carry_full and current_yaw != previous_yaw:
		if quarter.size() != 1025:
			return {"fault":"Missing source trigonometry"}
		var relative := Vector2i(VM.signed32(position.x - current.x),VM.signed32(position.z - current.z))
		var local := local_point(relative,previous_yaw,quarter)
		var rotated := local_point(local,-current_yaw,quarter)
		position.x = VM.signed32(current.x + rotated.x)
		position.z = VM.signed32(current.z + rotated.y)
		yaw = (rider_yaw + current_yaw - previous_yaw) & 4095
	return {"position":position,"yaw":yaw,"carried":true}

static func refine_ground_points(ground: Dictionary, point_contacts: Array, y_units: int, enabled: bool) -> Dictionary:
	# 0x80031ca8..0x80031e30 samples terrain and actor tops independently.
	var result := ground.duplicate()
	if not enabled:
		return result
	var height := int(ground.height_units)
	for contacts in point_contacts:
		if height == y_units:
			break
		for key in ["terrain","actor_lower"]:
			var hit: Dictionary = contacts.get(key,{})
			if not hit.is_empty() and height < int(hit.height_units):
				height = int(hit.height_units)
	result["mode"] = 1
	result["height_units"] = height
	return result

static func actor_wall_response(record: Dictionary, lower: Dictionary, upper: Dictionary, forward: Vector3i, opposite: Vector3i, rider_position: Vector3i, rider_primary: int, owner: Dictionary, sample_index: int, quarter: Array, angle_table: Array, clearance: int = 256, status: int = 0, ground_height: int = -40960) -> Dictionary:
	var result := {"entered":false,"rider_position":rider_position,"forward":forward,"opposite":opposite,"owner_secondary":int(owner.secondary),"status":status,"contact_bits":0,"ground_height":ground_height,"wall_angle_valid":false,"write_contact_owner":false,"needs_push_probes":false}
	if not actor_wall_entry(lower,upper,rider_position.y,clearance):
		return result
	result.entered = true
	result.contact_bits = 8
	result.owner_secondary = int(owner.secondary) | 0x40
	status |= (1 << (sample_index & 31)) & 65535
	var center: Vector3i = owner.position
	var scale: Vector2i = owner.scale
	var tested: Vector3i = rider_position if sample_index == 0 else opposite
	var test_local := actor_wall_local(Vector2i(tested.x,tested.z),Vector2i(center.x,center.z),int(owner.yaw),scale,quarter)
	var front_local := actor_wall_local(Vector2i(forward.x,forward.z),Vector2i(center.x,center.z),int(owner.yaw),scale,quarter)
	if test_local.has("fault"):
		return test_local
	if front_local.has("fault"):
		return front_local
	var solved := solve_actor_wall(record,front_local.position,test_local.position,int(lower.height_units))
	if solved.has("fault"):
		return solved
	if solved.ground_override != null:
		result.ground_height = int(solved.ground_override)
	if int(solved.angle_edge) >= 0:
		var h: Array = record.halfwords
		var edge := int(solved.angle_edge)
		var angle := wall_normal_angle(Vector2i(int(h[2+edge*4]),int(h[3+edge*4])),angle_table)
		if angle.has("fault"):
			return angle
		result.wall_angle = (int(owner.yaw)-int(angle.angle)+2048) & 4095
		result.wall_angle_valid = true
	var post := actor_wall_post_state(int(owner.primary),int(result.owner_secondary),rider_primary,rider_position.y,int(result.ground_height),solved.edges.size(),status)
	result.status = post.status
	result.write_contact_owner = post.write_contact_owner
	if post.write_contact_owner:
		result.contact_owner = int(lower.get("actor",-1)) & 255
	var corrected := actor_wall_world_delta(solved.delta,scale,int(owner.yaw),quarter)
	if corrected.has("fault"):
		return corrected
	result.world_delta = corrected.delta
	if post.special_response:
		result.needs_push_probes = true
		return result
	for key in ["rider_position","forward","opposite"]:
		var point: Vector3i = result[key]
		result[key] = Vector3i(VM.signed32(point.x+corrected.delta.x),point.y,VM.signed32(point.z+corrected.delta.y))
	return result

static func lower_sample_guard(sample_index: int, secondary: int, tile: int, cached_tile: int, previous_mode: int) -> bool:
	# 0x80032058..0x800320b8; equality also applies to absent tile -1.
	return sample_index == 0 and (secondary & 0x1000) != 0 and tile == cached_tile and (previous_mode & 4) != 0

static func movement_edge_transition(response: Dictionary, previous_mode: int, point0_lower_cache: Dictionary, contact_owner: int, edge_transition: bool) -> Dictionary:
	# 0x8003618c..0x80036210 runs only when movement status is still zero.
	var result := response.duplicate(true)
	if not edge_transition or int(result.status) != 0:
		return result
	if (previous_mode & 4) != 0:
		if not point0_lower_cache.has("tile") or not point0_lower_cache.has("record"):
			return {"fault":"Missing source edge-transition cache words"}
		result.ground.mode = 5
		result.ground.actor = int(point0_lower_cache.tile) & 255
		result.ground.record = int(point0_lower_cache.record) & 65535
	else:
		result.ground.mode = 10
		result.ground.actor = contact_owner & 255
		result.ground.record = 0
	result.status = 0x201
	return result

static func terrain_query_state(previous: Dictionary, hit: Dictionary, metadata_field: String, metadata_value: int) -> Dictionary:
	# Queries initialize tile and cache marker; other output words survive misses.
	var result := previous.duplicate(true)
	result["tile"] = -1
	if not hit.is_empty():
		result.merge(hit,true)
	result[metadata_field] = metadata_value & 65535
	return result

static func movement_point_cache(lower: Dictionary, upper: Dictionary) -> Dictionary:
	# Four SH writes at 0x80035c78..0x80035ca4; raw query identity required.
	var result := {}
	for key in ["lower","upper"]:
		var query: Dictionary = lower if key == "lower" else upper
		if not query.has("tile") or (int(query.tile) >= 0 and not query.has("record")):
			return {"fault":"Missing raw movement query cache identity"}
		var identity := {"tile":VM.signed32(int(query.tile) << 16) >> 16}
		if query.has("record"):
			identity.record = int(query.record) & 65535
		result[key] = identity
	return result

static func resolve_actor_push(response: Dictionary, owner_position: Vector3i, probes: Dictionary) -> Dictionary:
	# 0x80035bc4..0x80035c60; probe queries overwrite the temporary forward sample.
	if probes.has("fault"):
		return probes
	var result := response.duplicate(true)
	var correction: Vector2i = response.world_delta
	result.owner_position = owner_position
	result.needs_push_probes = false
	if not probes.probes.is_empty():
		result.forward = probes.probes.back().position
		result.last_push_probe = probes.probes.back()
	if probes.move_owner:
		result.owner_position = Vector3i(VM.signed32(owner_position.x-correction.x),owner_position.y,VM.signed32(owner_position.z-correction.y))
	else:
		for key in ["rider_position","forward","opposite"]:
			var point: Vector3i = result[key]
			result[key] = Vector3i(VM.signed32(point.x+correction.x),point.y,VM.signed32(point.z+correction.y))
	result.push_queries = int(probes.tested)
	return result

static func actor_push_probe_clear(terrain: Dictionary, actor_lower: Dictionary, owner_y: int) -> bool:
	# 0x80035b44..0x80035bac: compare against owner center Y, not probe Y.
	if not terrain.is_empty() and (int(terrain.height_units) > owner_y or int(terrain.surface_type) != 10):
		return false
	return actor_lower.is_empty() or int(actor_lower.height_units) <= VM.signed32(owner_y+32)

static func actor_push_probes(probes: Array, owner_y: int) -> Dictionary:
	for index in range(probes.size()):
		if not actor_push_probe_clear(probes[index].get("terrain",{}),probes[index].get("actor_lower",{}),owner_y):
			return {"move_owner":false,"tested":index+1,"failed_probe":index}
	return {"move_owner":true,"tested":probes.size(),"failed_probe":-1}

static func actor_wall_post_state(owner_primary: int, owner_secondary: int, rider_primary: int, y_units: int, ground_height: int, contacts: int, status: int = 0) -> Dictionary:
	# 0x80035854..0x80035908; the special branch performs additional queries later.
	var special := (owner_primary & 0x1000000) != 0 and VM.signed32(rider_primary) < 0
	var write_owner := false
	if not special and ground_height < VM.signed32(y_units+1024) and (owner_secondary & 0x100) == 0 and contacts == 1:
		status |= 0x200
		write_owner = true
	return {"status":(status | 0x800) & 65535,"write_contact_owner":write_owner,"special_response":special}

static func actor_wall_world_delta(delta: Vector2i, scale: Vector2i, yaw: int, quarter: Array) -> Dictionary:
	# 0x80035908..0x8003599c: signed scale products shift before CPU yaw rotation.
	if quarter.size() != 1025:
		return {"fault":"Missing source actor wall trigonometry"}
	var scaled := Vector2i(VM.signed32(delta.x*scale.x) >> 12,VM.signed32(delta.y*scale.y) >> 12)
	return {"delta":local_point(scaled,-yaw,quarter)}

static func solve_actor_wall(record: Dictionary, forward: Vector2i, test_point: Vector2i, height: int) -> Dictionary:
	# 0x8003563c..0x80035854: strict negative test-point planes, fixed forward input.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source actor wall record"}
	var delta := Vector2i.ZERO
	var contacts: Array[int] = []
	var ground_override = null
	for edge in range(4 if (int(h[0]) & 4) != 0 else 3):
		var a := int(h[2+edge*4])
		var b := int(h[3+edge*4])
		var constant := word(h,4+edge*4)
		var distance := VM.signed32((VM.signed32(VM.signed32(a*test_point.x)-VM.signed32(b*test_point.y)) >> 12)+constant)
		if distance >= 0 or (int(h[1]) & (17 << edge)) == 0:
			continue
		contacts.append(edge)
		ground_override = height
		var front := VM.signed32((VM.signed32(VM.signed32(a*forward.x)-VM.signed32(b*forward.y)) >> 12)+constant)
		var margin := VM.signed32(front+(front >> 4))
		var denominator := square_ir(a)+square_ir(b)
		if denominator == 0:
			continue
		delta.x = VM.signed32(delta.x+int(float(VM.signed32(-VM.signed32(margin*a)))/denominator))
		delta.y = VM.signed32(delta.y+int(float(VM.signed32(margin*b))/denominator))
	return {"delta":delta,"edges":contacts,"angle_edge":int(contacts.back()) if not contacts.is_empty() else -1,"ground_override":ground_override}

static func actor_wall_entry(lower: Dictionary, upper: Dictionary, y_units: int, clearance: int = 256) -> bool:
	# Source 0x80035274..0x800352dc.
	if lower.is_empty() or y_units >= VM.signed32(int(lower.height_units)-clearance):
		return false
	if not upper.is_empty() and int(upper.get("surface_type",0)) == 5 and int(lower.height_units) >= VM.signed32(y_units+1024):
		return false
	return true

static func actor_wall_local(point: Vector2i, actor_position: Vector2i, yaw: int, scale: Vector2i, quarter: Array) -> Dictionary:
	# 0x80035354..0x8003548c divides full CPU rotation products, truncating toward zero.
	if quarter.size() != 1025 or scale.x == 0 or scale.y == 0:
		return {"fault":"Missing actor wall scale or trigonometry"}
	var inverse := (-yaw) & 65535
	if inverse >= 32768:
		inverse -= 65536
	var s := sine(inverse,quarter)
	var c := sine(inverse+1024,quarter)
	var x := VM.signed32(point.x-actor_position.x)
	var z := VM.signed32(point.y-actor_position.y)
	var nx := VM.signed32(VM.signed32(z*s)+VM.signed32(x*c))
	var nz := VM.signed32(VM.signed32(z*c)-VM.signed32(x*s))
	if (nx == -2147483648 and scale.x == -1) or (nz == -2147483648 and scale.y == -1):
		return {"fault":"Source actor wall division overflow"}
	return {"position":Vector2i(int(float(nx)/scale.x),int(float(nz)/scale.y))}

static func solve_upper_opposite_wall(record: Dictionary, forward: Vector2i, opposite: Vector2i) -> Dictionary:
	# Upper mode2, 0x80034f04..0x800350bc; low edge masks and fixed input samples.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source upper opposite wall record"}
	var delta := Vector2i.ZERO
	var edges: Array[int] = []
	for edge in range(4 if (int(h[0]) & 4) != 0 else 3):
		var normal := Vector2i(int(h[2+edge*4]),int(h[3+edge*4]))
		var constant := word(h,4+edge*4)
		var rear := VM.signed32((VM.signed32(VM.signed32(normal.x*opposite.x)-VM.signed32(normal.y*opposite.y)) >> 12)+constant)
		if rear < 0 or (int(h[1]) & (17 << edge)) == 0:
			continue
		var front := VM.signed32((VM.signed32(VM.signed32(normal.x*forward.x)-VM.signed32(normal.y*forward.y)) >> 12)+constant)
		var corrected := wall_project(Vector2i.ZERO,normal,front)
		delta = Vector2i(VM.signed32(delta.x+corrected.position.x),VM.signed32(delta.y+corrected.position.y))
		edges.append(edge)
	return {"delta":delta,"edges":edges}

static func solve_upper_opposite_tile_wall(record: Dictionary, forward: Vector3i, opposite: Vector3i, actor_position: Vector3i, tile_position: Vector3i, tile_angle: int, quarter: Array) -> Dictionary:
	if quarter.size() != 1025:
		return {"fault":"Missing source upper opposite trigonometry"}
	var front := local_point(Vector2i(VM.signed32(forward.x-tile_position.x),VM.signed32(forward.z-tile_position.z)),tile_angle,quarter)
	var rear := local_point(Vector2i(VM.signed32(opposite.x-tile_position.x),VM.signed32(opposite.z-tile_position.z)),tile_angle,quarter)
	var solved := solve_upper_opposite_wall(record,front,rear)
	if solved.has("fault"):
		return solved
	var delta := local_point(solved.delta,-tile_angle,quarter)
	var positions: Array[Vector3i] = []
	for point in [actor_position,forward,opposite]:
		positions.append(Vector3i(VM.signed32(point.x+delta.x),point.y,VM.signed32(point.z+delta.y)))
	return {"actor_position":positions[0],"forward":positions[1],"opposite":positions[2],"world_delta":delta,"requery_upper":solved.delta != Vector2i.ZERO,"edges":solved.edges}

static func solve_upper_cached_tile_wall(record: Dictionary, forward: Vector3i, opposite: Vector3i, actor_position: Vector3i, tile_position: Vector3i, tile_angle: int, quarter: Array, angle_table: Array) -> Dictionary:
	# Cached upper mode3 response, 0x80034b54..0x80034c98.
	if quarter.size() != 1025:
		return {"fault":"Missing source upper wall trigonometry"}
	var local := local_point(Vector2i(VM.signed32(forward.x-tile_position.x),VM.signed32(forward.z-tile_position.z)),tile_angle,quarter)
	var solved := solve_upper_cached_wall(record,local)
	if solved.has("fault"):
		return solved
	var angle_value := 0
	if int(solved.angle_edge) >= 0:
		var edge := int(solved.angle_edge)
		var h: Array = record.halfwords
		var angle := wall_normal_angle(Vector2i(int(h[2+edge*4]),int(h[3+edge*4])),angle_table)
		if angle.has("fault"):
			return angle
		angle_value = (tile_angle-int(angle.angle)+2048) & 4095
	var world_delta := local_point(solved.delta,-tile_angle,quarter)
	var positions: Array[Vector3i] = []
	for point in [actor_position,forward,opposite]:
		positions.append(Vector3i(VM.signed32(point.x+world_delta.x),point.y,VM.signed32(point.z+world_delta.y)))
	var moved: bool = solved.delta != Vector2i.ZERO
	return {"actor_position":positions[0],"forward":positions[1],"opposite":positions[2],"world_delta":world_delta,"wall_angle":angle_value,"wall_angle_valid":int(solved.angle_edge)>=0,"requery_upper":moved,"current_record_fallback":not moved}

static func upper_wall_route(previous_upper_tile: int, query_field_18: int, slope_handled: bool) -> int:
	# 0x80034754..0x800347b4.
	return 1 if slope_handled else (2 if previous_upper_tile < 0 or (query_field_18 & 65535) != 0 else 3)

static func solve_upper_cached_wall(record: Dictionary, point: Vector2i) -> Dictionary:
	# Mode3 upper cached edge scan, 0x80034964..0x80034b50, fixed sample position.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source upper cached wall record"}
	var delta := Vector2i.ZERO
	var angle_edge := -1
	var contacts: Array[int] = []
	for edge in range(4 if (int(h[0]) & 4) != 0 else 3):
		if (int(h[1]) & (1 << (edge+8))) == 0:
			continue
		var normal := Vector2i(int(h[2+edge*4]),int(h[3+edge*4]))
		var distance := VM.signed32((VM.signed32(VM.signed32(normal.x*point.x)-VM.signed32(normal.y*point.y)) >> 12)+word(h,4+edge*4))
		if distance < 0:
			continue
		angle_edge = edge
		contacts.append(edge)
		var corrected := wall_project(Vector2i.ZERO,normal,distance)
		delta = Vector2i(VM.signed32(delta.x+corrected.position.x),VM.signed32(delta.y+corrected.position.y))
	return {"delta":delta,"angle_edge":angle_edge,"edges":contacts}

static func solve_upper_slope_wall(record: Dictionary, upper: Dictionary, lower: Dictionary, forward: Vector3i, opposite: Vector3i, actor_position: Vector3i, tile_position: Vector3i, tile_angle: int, sample_index: int, quarter: Array, clearance: int = 256) -> Dictionary:
	# Upper slope stage 0x8003422c..0x80034754; no lower-path type7 exception.
	var result := {"actor_position":actor_position,"forward":forward,"opposite":opposite,"entered":false,"handled":false,"status_set":0,"contact_bits":0}
	if not upper_wall_entry(upper,lower,actor_position.y,clearance):
		return result
	result.entered = true
	result.status_set = (1 << (sample_index & 31)) & 65535
	result.contact_bits = 4
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or quarter.size() != 1025:
		return {"fault":"Missing source upper slope inputs"}
	if (int(h[0]) & 2) == 0:
		return result
	var projected := upper_slope_wall_delta(record,actor_position.y,int(upper.height_units))
	if not projected.projected:
		return result
	var relative := Vector2i(VM.signed32(forward.x-tile_position.x),VM.signed32(forward.z-tile_position.z))
	var local := local_point(relative,tile_angle,quarter)
	var target := Vector2i(VM.signed32(local.x+projected.delta.x),VM.signed32(local.y+projected.delta.y))
	var inside := true
	for edge in range(4 if (int(h[0]) & 4) != 0 else 3):
		var distance := VM.signed32((VM.signed32(VM.signed32(int(h[2+edge*4])*target.x)-VM.signed32(int(h[3+edge*4])*target.y)) >> 12)+word(h,4+edge*4))
		if distance > 0:
			inside = false
			break
	var delta := local_point(projected.delta,-tile_angle,quarter)
	if inside:
		for key in ["actor_position","forward","opposite"]:
			var point: Vector3i = result[key]
			result[key] = Vector3i(VM.signed32(point.x+delta.x),point.y,VM.signed32(point.z+delta.y))
		result.handled = true
	elif int(h[18]) != 0 and int(h[19]) != 0:
		result.opposite = Vector3i(VM.signed32(forward.x+delta.x),opposite.y,VM.signed32(forward.z+delta.y))
	return result

static func upper_wall_entry(upper: Dictionary, lower: Dictionary, y_units: int, clearance: int = 256) -> bool:
	# 0x8003422c..0x80034290, strict upper clearance and lower separation.
	if upper.is_empty() or int(upper.height_units) >= VM.signed32(y_units+1024):
		return false
	return lower.is_empty() or VM.signed32(int(lower.height_units)+clearance) < int(upper.height_units)

static func upper_slope_wall_delta(record: Dictionary, y_units: int, height: int) -> Dictionary:
	# 0x8003441c..0x80034540 uses gradient<<4 SQR and product<<4 numerators.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source upper slope record"}
	var x := int(h[18])
	var z := int(h[19])
	var denominator := square_ir(VM.signed32(x << 4))+square_ir(VM.signed32(z << 4))
	var penetration := VM.signed32(y_units-VM.signed32(height-1024))
	penetration = VM.signed32(penetration+(penetration >> 8))
	if denominator <= 0 or penetration == 0:
		return {"projected":false,"delta":Vector2i.ZERO}
	var nx := VM.signed32(VM.signed32(penetration*x) << 4)
	var nz := VM.signed32(VM.signed32(penetration*z) << 4)
	return {"projected":true,"delta":Vector2i(int(float(nx)/denominator),int(float(nz)/denominator))}

static func solve_fresh_slope_wall(record: Dictionary, terrain: Dictionary, forward: Vector3i, opposite: Vector3i, actor_position: Vector3i, tile_position: Vector3i, tile_angle: int, sample_index: int, quarter: Array, angle_table: Array) -> Dictionary:
	# Source 0x80032974..0x80032d94, slope stage before the flat-wall fallback.
	var result := {"actor_position":actor_position,"forward":forward,"opposite":opposite,"handled":false,"entered":false,"status_set":0,"contact_bits":0,"wall_angle":0,"wall_angle_valid":false}
	var entry := fresh_wall_entry(terrain,actor_position.y,sample_index)
	if not entry.blocked:
		return result
	result.entered = true
	result.status_set = (1 << (sample_index & 31)) & 65535
	result.contact_bits = 4
	var h: Array = record.get("halfwords",[])
	if h.size() != 22 or quarter.size() != 1025:
		return {"fault":"Missing source fresh slope inputs"}
	if (int(h[0]) & 2) == 0:
		return result
	var special := int(terrain.surface_type) == 7 and sample_index == 0
	var projected := slope_wall_delta(record,actor_position.y,int(terrain.height_units),int(entry.clearance))
	if projected.projected:
		var normal := Vector2i(int(h[18]),int(h[19]))
		var angle := wall_normal_angle(normal,angle_table)
		if angle.has("fault"):
			return angle
		result.wall_angle = (tile_angle - int(angle.angle)) & 4095
		result.wall_angle_valid = true
		var relative := Vector2i(VM.signed32(forward.x-tile_position.x),VM.signed32(forward.z-tile_position.z))
		var local := local_point(relative,tile_angle,quarter)
		var target := Vector2i(VM.signed32(local.x+projected.delta.x),VM.signed32(local.y+projected.delta.y))
		var inside := true
		for edge in range(4 if (int(h[0]) & 4) != 0 else 3):
			var distance := VM.signed32((VM.signed32(VM.signed32(int(h[2+edge*4])*target.x)-VM.signed32(int(h[3+edge*4])*target.y)) >> 12)+word(h,4+edge*4))
			if distance < 0:
				inside = false
				break
		var delta := local_point(projected.delta,-tile_angle,quarter)
		if inside or special:
			for key in ["actor_position","forward","opposite"]:
				var point: Vector3i = result[key]
				result[key] = Vector3i(VM.signed32(point.x+delta.x),point.y,VM.signed32(point.z+delta.y))
			result.handled = true
		elif normal.x != 0 and normal.y != 0:
			result.opposite = Vector3i(VM.signed32(forward.x+delta.x),opposite.y,VM.signed32(forward.z+delta.y))
	if special:
		result.status_set |= 0x400
		result.handled = true
	return result

static func solve_opposite_tile_wall(record: Dictionary, forward: Vector3i, opposite: Vector3i, actor_position: Vector3i, tile_position: Vector3i, tile_angle: int, height: int, quarter: Array, angle_table: Array, status: int = 0) -> Dictionary:
	# Mode2 world response and requery decision, 0x80033a84..0x80033bc4.
	if quarter.size() != 1025:
		return {"fault":"Missing source opposite wall trigonometry"}
	var front_local := local_point(Vector2i(VM.signed32(forward.x-tile_position.x),VM.signed32(forward.z-tile_position.z)),tile_angle,quarter)
	var rear_local := local_point(Vector2i(VM.signed32(opposite.x-tile_position.x),VM.signed32(opposite.z-tile_position.z)),tile_angle,quarter)
	var solved := solve_opposite_wall(record,front_local,rear_local,height,actor_position.y,status)
	if solved.has("fault"):
		return solved
	var world_delta := local_point(solved.delta,-tile_angle,quarter)
	var wall_angle := 0
	if int(solved.angle_edge) >= 0:
		var edge := int(solved.angle_edge)
		var h: Array = record.halfwords
		var angle := wall_normal_angle(Vector2i(int(h[2+edge*4]),int(h[3+edge*4])),angle_table)
		if angle.has("fault"):
			return angle
		wall_angle = (tile_angle-int(angle.angle)+2048) & 4095
	var positions: Array[Vector3i] = []
	for point in [actor_position,forward,opposite]:
		positions.append(Vector3i(VM.signed32(point.x+world_delta.x),point.y,VM.signed32(point.z+world_delta.y)))
	return {"actor_position":positions[0],"forward":positions[1],"opposite":positions[2],"world_delta":world_delta,"status":solved.status,"wall_angle":wall_angle,"wall_angle_valid":int(solved.angle_edge)>=0,"ground_override":solved.ground_override,"requery":solved.delta != Vector2i.ZERO and (int(solved.status) & 0x200)==0,"contacts":solved.contacts}

static func solve_opposite_wall(record: Dictionary, forward: Vector2i, opposite: Vector2i, height: int, y_units: int, status: int = 0) -> Dictionary:
	# Source mode2, 0x80033728..0x80033a84. Inputs stay fixed while deltas accumulate.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source opposite wall record"}
	var delta := Vector2i.ZERO
	var contacts := 0
	var angle_edge := -1
	var ground_override = null
	for edge in range(4 if (int(h[0]) & 4) != 0 else 3):
		var bits := int(h[1]) & 65535
		if (bits & (17 << (edge+4))) == (1 << (edge+8)):
			continue
		var a := int(h[2+edge*4])
		var b := int(h[3+edge*4])
		var constant := word(h,4+edge*4)
		var rear_distance := VM.signed32((VM.signed32(VM.signed32(a*opposite.x)-VM.signed32(b*opposite.y)) >> 12)+constant)
		if rear_distance > 0:
			continue
		contacts += 1
		var distance := VM.signed32((VM.signed32(VM.signed32(a*forward.x)-VM.signed32(b*forward.y)) >> 12)+constant)
		if (bits & (1 << (edge+4))) != 0 and VM.signed32(height-y_units) < 1024:
			if (int(h[0]) & 2) == 0:
				status |= 0x200
			angle_edge = edge
			ground_override = height
		var denominator := square_ir(a)+square_ir(b)
		if denominator == 0:
			continue
		var margin := VM.signed32(distance+(distance >> 4))
		delta.x = VM.signed32(delta.x+int(float(VM.signed32(-VM.signed32(margin*a)))/denominator))
		delta.y = VM.signed32(delta.y+int(float(VM.signed32(margin*b))/denominator))
	if contacts != 1:
		status &= ~0x200
	return {"delta":delta,"status":status,"contacts":contacts,"angle_edge":angle_edge,"ground_override":ground_override}

static func fresh_wall_route(record: Dictionary, previous_tile: int, previous_ground_type: int, query_field_6: int, slope_handled: bool) -> int:
	# 0x80032d8c..0x80032e34. Query field +6 remains unnamed raw source data.
	if slope_handled:
		return 1
	if previous_tile < 0 or (query_field_6 & 65535) != 0 or (previous_ground_type & 255) == 7:
		return 2
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return -1
	return 2 if (int(h[1]) & 0xa0) == 0xa0 else 3

static func fresh_wall_entry(terrain: Dictionary, y_units: int, sample_index: int) -> Dictionary:
	# 0x80032028..0x80032054 and 0x800327d0..0x80032824.
	if terrain.is_empty():
		return {"blocked":false,"clearance":256}
	var type := int(terrain.surface_type)
	var clearance := 512 if type in [13,14] else 256
	var height := int(terrain.height_units)
	return {"blocked":y_units < VM.signed32(height-clearance) or (type == 7 and sample_index == 0 and y_units < height),"clearance":clearance}

static func slope_wall_delta(record: Dictionary, y_units: int, height: int, clearance: int) -> Dictionary:
	# Initial slope response 0x800329ac..0x80032b18; later exit checks are separate.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source slope wall record"}
	var x := int(h[18])
	var z := int(h[19])
	var denominator := square_ir(VM.signed32(x << 2)) + square_ir(VM.signed32(z << 2))
	if denominator <= 0:
		return {"projected":false,"delta":Vector2i.ZERO}
	var penetration := VM.signed32(VM.signed32(y_units-height) + clearance)
	penetration = VM.signed32(penetration + (penetration >> 8))
	return {"projected":true,"delta":Vector2i(int(float(VM.signed32(penetration*x))/denominator),int(float(VM.signed32(penetration*z))/denominator))}

static func wall_normal_angle(normal: Vector2i, table: Array) -> Dictionary:
	# Retail 0x8005558c..0x80055708, signed angle for atan2(normal.x, normal.y).
	if table.size() != 1025:
		return {"fault":"Missing source wall angle table"}
	var x := absi(normal.x)
	var z := absi(normal.y)
	if x == 0 and z == 0:
		return {"angle":0}
	var small := mini(x,z)
	var large := maxi(x,z)
	var index := int(float(small) / (large >> 10)) if (small & 0x7fe00000) != 0 else int(float(VM.signed32(small << 10)) / large)
	if index < 0 or index >= table.size():
		return {"fault":"Source wall angle lookup outside table"}
	var angle := int(table[index])
	if x >= z:
		angle = 1024 - angle
	if normal.y < 0:
		angle = 2048 - angle
	if normal.x < 0:
		angle = -angle
	return {"angle":angle}

static func solve_cached_tile_wall(record: Dictionary, forward: Vector3i, opposite: Vector3i, actor_position: Vector3i, tile_position: Vector3i, tile_angle: int, sample_index: int, style: int, quarter: Array, angle_table: Array, allow_style_override: bool = true, style1_upper_miss: bool = false) -> Dictionary:
	# Cached-tile local conversion and world response, 0x800320f4..0x800327cc.
	if quarter.size() != 1025:
		return {"fault":"Missing source wall trigonometry"}
	var relative := Vector2i(VM.signed32(forward.x-tile_position.x),VM.signed32(forward.z-tile_position.z))
	var local := local_point(relative,tile_angle,quarter)
	var solved := solve_cached_wall(record,local,style,allow_style_override,style1_upper_miss)
	if solved.has("fault"):
		return solved
	var wall_angle := 0
	if not solved.edges.is_empty():
		var edge := int(solved.edges.back())
		var h: Array = record.halfwords
		var angle := wall_normal_angle(Vector2i(int(h[2 + edge * 4]),int(h[3 + edge * 4])),angle_table)
		if angle.has("fault"):
			return angle
		wall_angle = (tile_angle - int(angle.angle)) & 4095
	var world_delta := local_point(solved.delta,-tile_angle,quarter)
	var status := int(solved.status_set)
	if solved.delta != Vector2i.ZERO and not style1_upper_miss:
		status |= (1 << (sample_index & 31)) & 65535
	var changed: Array[Vector3i] = []
	for position in [actor_position,forward,opposite]:
		changed.append(Vector3i(VM.signed32(position.x+world_delta.x),position.y,VM.signed32(position.z+world_delta.y)))
	return {"actor_position":changed[0],"forward":changed[1],"opposite":changed[2],"world_delta":world_delta,"status_set":status,"contact_bits":0 if style1_upper_miss else solved.contact_bits,"moved":solved.delta != Vector2i.ZERO,"edges":solved.edges,"local_position":solved.position,"wall_angle":wall_angle,"wall_angle_valid":not solved.edges.is_empty()}

static func solve_cached_wall(record: Dictionary, point: Vector2i, style: int, allow_style_override: bool = true, style1_upper_miss: bool = false) -> Dictionary:
	# Retail 0x8003224c..0x800326d0, ordered first-contact rescan then intersections.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source wall plane record"}
	var count := 4 if (int(h[0]) & 4) != 0 else 3
	var current := point
	var first_edge := -1
	var contacts: Array[int] = []
	var status := 0
	var edge := 0
	while edge < count:
		var contact := wall_plane_contact(record,current,edge,style,first_edge,allow_style_override,style1_upper_miss)
		if contact.has("fault"):
			return contact
		if contact.is_empty():
			edge += 1
			continue
		status |= int(contact.status_set)
		var corrected: Dictionary
		if first_edge < 0:
			first_edge = edge
			corrected = wall_project(current,contact.normal,int(contact.distance))
			edge = 0
		else:
			var old_normal := Vector2i(int(h[2 + first_edge * 4]),int(h[3 + first_edge * 4]))
			corrected = wall_intersection(current,old_normal,word(h,4 + first_edge * 4),contact.normal,word(h,4 + edge * 4),int(contact.distance))
			edge += 1
		if corrected.has("fault"):
			return corrected
		contacts.append(int(contact.edge))
		current = corrected.position
	var delta := Vector2i(VM.signed32(current.x-point.x),VM.signed32(current.y-point.y))
	return {"position":current,"delta":delta,"status_set":status,"contact_bits":4 if delta != Vector2i.ZERO else 0,"edges":contacts}

static func wall_project(point: Vector2i, normal: Vector2i, distance: int) -> Dictionary:
	# First plane correction, 0x8003251c..0x8003264c.
	var denominator := square_ir(normal.x) + square_ir(normal.y)
	if denominator == 0:
		return {"position":point}
	var margin := VM.signed32(distance + (distance >> 2))
	var x_numerator := VM.signed32(-VM.signed32(margin * normal.x))
	var z_numerator := VM.signed32(margin * normal.y)
	return {"position":Vector2i(VM.signed32(point.x + int(float(x_numerator)/denominator)),VM.signed32(point.y + int(float(z_numerator)/denominator)))}

static func wall_intersection(point: Vector2i, old_normal: Vector2i, old_constant: int, normal: Vector2i, constant: int, distance: int) -> Dictionary:
	# Subsequent plane intersection, 0x800323f0..0x80032518.
	var determinant := VM.signed32(VM.signed32(old_normal.x * normal.y) - VM.signed32(old_normal.y * normal.x)) >> 12
	if determinant == 0:
		return {"position":point}
	var margin := VM.signed32(-(distance >> 2))
	var current := VM.signed32(constant - margin)
	var previous := VM.signed32(old_constant - margin)
	var x_numerator := VM.signed32(VM.signed32(current * old_normal.y) - VM.signed32(previous * normal.y))
	var z_numerator := VM.signed32(VM.signed32(current * old_normal.x) - VM.signed32(previous * normal.x))
	if determinant == -1 and (x_numerator == -2147483648 or z_numerator == -2147483648):
		return {"fault":"Source wall intersection division overflow"}
	return {"position":Vector2i(int(float(x_numerator)/determinant),int(float(z_numerator)/determinant))}

static func wall_plane_contact(record: Dictionary, point: Vector2i, edge: int, style: int, skip_edge: int = -1, allow_style_override: bool = true, style1_upper_miss: bool = false) -> Dictionary:
	# Retail 0x80032210..0x80032378, cached-tile boundary path.
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {"fault":"Missing source wall plane record"}
	var count := 4 if (int(h[0]) & 4) != 0 else 3
	if edge < 0 or edge >= count or edge == skip_edge:
		return {}
	var bits := int(h[1]) & 65535
	if not style1_upper_miss and (bits & (1 << (edge + 8))) == 0 and not (style == 1 and allow_style_override):
		return {}
	var a := int(h[2 + edge * 4])
	var b := int(h[3 + edge * 4])
	var distance := VM.signed32((VM.signed32(VM.signed32(a * point.x) - VM.signed32(b * point.y)) >> 12) + word(h,4 + edge * 4))
	if (distance < 0) if style1_upper_miss else (distance > 0):
		return {}
	return {"edge":edge,"distance":distance,"normal":Vector2i(a,b),"status_set":0x800 if not style1_upper_miss and (bits & (1 << (edge + 4))) != 0 else 0}

static func movement_ceiling(y_units: int, terrain_upper: Dictionary, actor_upper: Dictionary, style: int, clearance_units: int = 256, status: int = 0, contact_bits: int = 0) -> Dictionary:
	# Retail 0x80035e0c..0x80036018, actor correction precedes terrain windows.
	var result := {"y":y_units,"status":status,"contact_bits":contact_bits,"surface_type":0,"actor":-1,"actor_secondary_set":0,"force_actor_ground":false}
	if not actor_upper.is_empty() and VM.signed32(y_units + clearance_units) < int(actor_upper.height_units):
		result.status |= 0x1100
		result.contact_bits |= 8
		result.y = VM.signed32(int(actor_upper.height_units) - 1024)
		result.surface_type = int(actor_upper.get("surface_type",0)) & 255
		result.actor = int(actor_upper.get("actor",-1))
		result.actor_secondary_set = 0x40
		result.force_actor_ground = result.surface_type == 5
	if not terrain_upper.is_empty():
		var height := int(terrain_upper.height_units)
		if VM.signed32(int(result.y) + 512) < height and height < VM.signed32(int(result.y) + 1024):
			result.status |= 0x100
			result.contact_bits |= 4
			result.y = VM.signed32(height - 1024)
			result.surface_type = int(terrain_upper.get("surface_type",0)) & 255
		if style == 1 and VM.signed32(int(result.y) - 1024) < height and height < VM.signed32(int(result.y) + 1024):
			result.status |= 0x100
			result.contact_bits |= 4
			result.y = VM.signed32(height - 1024)
			result.surface_type = int(terrain_upper.get("surface_type",0)) & 255
	return result

static func movement_cache_fallback(terrain: Dictionary, previous_lower: Dictionary, previous_ground: Dictionary, y_units: int) -> Dictionary:
	# Retail 0x80035d40..0x80035dd0 restores only lower-hit identity/type/height.
	var selected := terrain.duplicate()
	var old_tile := int(previous_lower.get("tile",-2))
	if old_tile != -2 and not terrain.is_empty() and int(terrain.get("tile",0)) >= 0 and VM.signed32(y_units + 1024) < int(terrain.height_units):
		selected.tile = old_tile
		selected.record = int(previous_lower.get("record",0)) & 65535
		selected.surface_type = int(previous_ground.get("surface_type",0)) & 255
		selected.height_units = int(previous_ground.get("height_units",-40960))
	var cache := {"tile":int(selected.get("tile",-1))}
	if selected.has("record"):
		cache.record = int(selected.record) & 65535
	return {"terrain":selected if int(cache.tile) >= 0 else {},"lower_cache":cache}

static func movement_response_tail(y_units: int, terrain: Dictionary, terrain_upper: Dictionary, actor_lower: Dictionary, actor_upper: Dictionary, style: int, clearance_units: int = 256, status: int = 0, contact_bits: int = 0, previous_lower: Dictionary = {}, previous_ground: Dictionary = {}) -> Dictionary:
	var selected_terrain := terrain
	var lower_cache: Dictionary = {}
	if not previous_lower.is_empty():
		var fallback := movement_cache_fallback(terrain,previous_lower,previous_ground,y_units)
		selected_terrain = fallback.terrain
		lower_cache = fallback.lower_cache
	var ceiling := movement_ceiling(y_units,terrain_upper,actor_upper,style,clearance_units,status,contact_bits)
	var ground := choose_movement_ground(selected_terrain,actor_lower,int(ceiling.y),clearance_units,int(ceiling.contact_bits))
	# 0x8003614c..0x80036188 overwrites ownership/mode, retaining selected height/type.
	if ceiling.force_actor_ground:
		ground.mode = int(ceiling.contact_bits) | 2
		ground.actor = int(actor_upper.get("actor",-1)) & 255
		ground.record = int(actor_upper.get("record",0)) & 65535
	return {"y":ceiling.y,"ground":ground,"status":ceiling.status,"ceiling_type":ceiling.surface_type,"contact_actor":ceiling.actor,"actor_secondary_set":ceiling.actor_secondary_set,"lower_cache":lower_cache}

static func choose_movement_ground(terrain: Dictionary, actor_lower: Dictionary, y_units: int, clearance_units: int = 256, contact_bits: int = 0) -> Dictionary:
	# Movement response 0x80036018..0x80036148 differs from the height-only query.
	var use_actor := false
	if not actor_lower.is_empty():
		var actor_limit := VM.signed32(int(actor_lower.height_units) - clearance_units)
		if actor_limit <= VM.signed32(y_units + 768):
			use_actor = true
			if not terrain.is_empty():
				var terrain_limit := VM.signed32(int(terrain.height_units) - 256)
				if actor_limit < terrain_limit and y_units >= terrain_limit:
					use_actor = false
	if use_actor:
		var result := actor_lower.duplicate()
		result.mode = contact_bits | 2
		return result
	if not terrain.is_empty():
		var result := terrain.duplicate()
		result.mode = contact_bits | 1
		return result
	return {"mode":contact_bits,"surface_type":0,"height_units":-40960}

static func choose_ground(terrain: Dictionary, actor_lower: Dictionary, y_units: int, clearance_units: int = 256) -> Dictionary:
	# 0x80031bc0..0x80031c90 selects terrain/actor metadata before optional movement.
	if actor_lower.is_empty():
		if terrain.is_empty():
			return {"mode":0,"surface_type":0,"height_units":-65536}
		var result := terrain.duplicate()
		result["mode"] = 1
		return result
	var use_actor := terrain.is_empty()
	if not terrain.is_empty():
		var floor_limit := VM.signed32(int(terrain.height_units) - 256)
		var actor_limit := VM.signed32(int(actor_lower.height_units) - clearance_units)
		use_actor = floor_limit < actor_limit or (y_units < floor_limit and actor_limit < floor_limit)
	var result: Dictionary = actor_lower.duplicate() if use_actor else terrain.duplicate()
	result["mode"] = 2 if use_actor else 1
	return result

static func square_ir(value: int) -> int:
	# LWC2 IR1..3 stores signed low halfwords; SQR(sf=1) returns MAC, not IR.
	var signed_value := value & 65535
	if signed_value >= 32768:
		signed_value -= 65536
	return (signed_value * signed_value) >> 12

static func actor_radius_contains(delta: Vector2i, radius_units: int) -> bool:
	# Source 0x80031548..0x800315b0 and SQR helper 0x80054ecc.
	return VM.signed32(square_ir(delta.x) + square_ir(delta.y)) < square_ir(radius_units)

static func select_actor_contacts(actors: Array, y_units: int, clearance_units: int = 256) -> Dictionary:
	# Input order is the original actor linked-list order, then concatenated model
	# collision records. Radius/eligibility filtering is performed by the caller.
	# Retail 0x8003189c..0x80031aec keeps the last matching record within each actor.
	var lower: Dictionary = {}
	var upper: Dictionary = {}
	var limit := VM.signed32(y_units + 1024)
	for records in actors:
		var top: Dictionary = {}
		var underside: Dictionary = {}
		for hit in records:
			if (int(hit.flags) & 8) != 0:
				if int(hit.height_units) > limit:
					top = {}
					underside = {}
					break
				underside = hit
			else:
				top = hit
		if not underside.is_empty():
			var height := int(underside.height_units)
			if (upper.is_empty() or height < int(upper.height_units)) and (lower.is_empty() or int(lower.height_units) < height) and y_units < height:
				upper = underside
		if not top.is_empty():
			var threshold := VM.signed32(int(top.height_units) - clearance_units)
			if lower.is_empty() or int(lower.height_units) < threshold:
				lower = top
	return {"lower":lower.duplicate(),"upper":upper.duplicate()}

static func select_ceiling(candidates: Array, y_units: int, query_field_18: int = 0) -> Dictionary:
	# 0x80031388..0x80031420: nearest above Y, otherwise highest below; ties retain order.
	var best: Dictionary = {}
	for hit in candidates:
		if int(hit.get("group",-1)) != 0 or (int(hit.flags) & 8) == 0:
			continue
		var height := int(hit.height_units)
		if best.is_empty() or (int(best.height_units) > y_units and height > y_units and height < int(best.height_units)) or (int(best.height_units) <= y_units and height > int(best.height_units)):
			best = hit
	var result := best.duplicate()
	if not result.is_empty():
		result["query_field_18"] = query_field_18 & 65535
	return result

static func select_floor(candidates: Array, y_units: int, skip_type_17: bool = false, initial: Dictionary = {}) -> Dictionary:
	# Retail fallback scan 0x80030b2c..0x80030de4, in tile/record order.
	var best: Dictionary = initial.duplicate()
	var limit := VM.signed32(y_units + 1024)
	for hit in candidates:
		if int(hit.get("group",-1)) != 0 or (int(hit.flags) & 8) != 0:
			continue
		if skip_type_17 and int(hit.surface_type) == 17:
			continue
		var height := int(hit.height_units)
		if best.is_empty():
			best = hit
		elif int(best.height_units) > limit:
			if height < int(best.height_units):
				best = hit
		elif height > int(best.height_units) and height <= limit:
			best = hit
	var result := best.duplicate()
	if not result.is_empty():
		result["query_field_6"] = int(initial.get("query_field_6",0))
	return result

static func sine(angle: int, quarter: Array) -> int:
	if quarter.size() != 1025:
		return 0
	var a := absi(angle) & 4095
	var value: int
	if a <= 1024:
		value = int(quarter[a])
	elif a <= 2048:
		value = int(quarter[2048 - a])
	elif a <= 3072:
		value = -int(quarter[a - 2048])
	else:
		value = -int(quarter[4096 - a])
	return -value if angle < 0 else value

static func local_point(point: Vector2i, angle: int, quarter: Array) -> Vector2i:
	# The cached retail tile query uses the signed 16-bit inverse tile angle.
	var inverse := (-angle) & 65535
	if inverse >= 32768:
		inverse -= 65536
	var s := sine(inverse,quarter)
	var c := sine(inverse + 1024,quarter)
	var x := VM.signed32(VM.signed32(point.y * s) + VM.signed32(point.x * c)) >> 12
	var z := VM.signed32(VM.signed32(point.y * c) - VM.signed32(point.x * s)) >> 12
	return Vector2i(x,z)

static func actor_surface(record: Dictionary, point: Vector2i, angle: int, scale_units: Vector3i, y_units: int, quarter: Array) -> Dictionary:
	# Actor helper 0x800315b8..0x800319dc rotates before dividing by X/Z scale.
	if quarter.size() != 1025 or scale_units.x == 0 or scale_units.z == 0:
		return {}
	var inverse := (-angle) & 65535
	if inverse >= 32768:
		inverse -= 65536
	var s := sine(inverse,quarter)
	var c := sine(inverse + 1024,quarter)
	var x := VM.signed32(VM.signed32(point.y * s) + VM.signed32(point.x * c))
	var z := VM.signed32(VM.signed32(point.y * c) - VM.signed32(point.x * s))
	if (x == -2147483648 and scale_units.x == -1) or (z == -2147483648 and scale_units.z == -1):
		return {}
	x = (x >> 12) if scale_units.x == 4096 else int(float(x) / float(scale_units.x))
	z = (z >> 12) if scale_units.z == 4096 else int(float(z) / float(scale_units.z))
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {}
	var hit := surface(record,Vector2i(x,z),(int(h[0]) & 8) != 0)
	if hit.is_empty():
		return hit
	hit["height_units"] = VM.signed32((VM.signed32(int(hit.height_units) * scale_units.y) >> 12) + y_units)
	return hit

static func tile_surfaces(tile: Dictionary, model: Dictionary, point: Vector3i, quarter: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if quarter.size() != 1025:
		return hits
	var origin: Array = tile.position
	var x := VM.signed32(point.x - int(origin[0]) * 4096)
	var z := VM.signed32(point.z - int(origin[2]) * 4096)
	# Cached-query broadphase from 0x80030718..0x80030764; equality is rejected.
	var x_magnitude := VM.signed32(-x) if x < 0 else x
	var z_magnitude := VM.signed32(-z) if z < 0 else z
	if x_magnitude >= 2176 or z_magnitude >= 2176:
		return hits
	var local := local_point(Vector2i(x,z),roundi(float(tile.rotation) * 4096.0),quarter)
	var groups: Array = model.get("collision",{}).get("groups",[])
	for group in range(groups.size()):
		for index in range(groups[group].size()):
			var record: Dictionary = groups[group][index]
			var underside := (int(record.halfwords[0]) & 8) != 0
			var hit := surface(record,local,underside,underside)
			if hit.is_empty():
				continue
			hit["height_units"] = VM.signed32(int(hit.height_units) + roundi(float(origin[1]) * 4096.0))
			hit["group"] = group
			hit["record"] = index
			hits.append(hit)
	return hits

static func word(halfwords: Array, index: int) -> int:
	return VM.signed32((int(halfwords[index]) & 65535) | ((int(halfwords[index + 1]) & 65535) << 16))

static func surface(record: Dictionary, point: Vector2i, inverted_edges: bool = false, strict_edges: bool = false) -> Dictionary:
	var h: Array = record.get("halfwords",[])
	if h.size() != 22:
		return {}
	var flags: int = int(h[0]) & 255
	var edges := 4 if (flags & 4) != 0 else 3
	for i in range(edges):
		var offset := 2 + i * 4
		var x_product := VM.signed32(int(h[offset]) * point.x)
		var z_product := VM.signed32(int(h[offset + 1]) * point.y)
		var distance := VM.signed32((VM.signed32(x_product - z_product) >> 12) + word(h,offset + 2))
		if ((distance >= 0) if strict_edges else (distance > 0)) if inverted_edges else (distance < 0):
			return {}
	var height := word(h,20)
	if (flags & 2) != 0:
		var x_product := VM.signed32(point.x * int(h[18]))
		var z_product := VM.signed32(point.y * int(h[19]))
		height = VM.signed32((VM.signed32(x_product + z_product) >> 8) + height)
	return {"height_units":height,"surface_type":(int(h[0]) >> 8) & 255,"flags":flags}
