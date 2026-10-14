extends Node3D
# SPDX-License-Identifier: GPL-2.0-only
# An imported actor runs its own source entry point. Unsupported game commands
# remain visible in diagnostics; they are never silently replaced with no-ops.
const VM = preload("res://asl_vm.gd")
const SpriteFacing = preload("res://source_sprite_facing.gd")
var sprite_parts: Array[MeshInstance3D] = []
var animation_assets: Dictionary = {}
var model_asset_file := ""
var animation_asset_file := ""
var pose_banks: Dictionary = {}
var pose_bank_order: Array = []
var modern_pose = preload("res://modern_character_pose.gd").new()
var modern_velocity := Vector3.ZERO
var modern_speed := 0.0
var modern_blend_alpha := 1.0
var modern_blend_parts: Array[Transform3D] = []
var modern_blend_points: Array[Vector3] = []
var modern_traversal_remainder := Vector3.ZERO

func modern_traversal_mode() -> int:
	return world.player_traversal_mode() if modern_controlled() else 0

func advance_modern_traversal() -> void:
	var mode := modern_traversal_mode()
	var traversal = preload("res://modern_traversal.gd")
	if world == null or not traversal.locomotion(mode,clip_name) or world.source_input_suppression_count != 0:
		modern_traversal_remainder = Vector3.ZERO
		return
	var input: Dictionary = world.source_player_input_state
	var units := traversal.displacement(mode,input.get("surface_axes",Vector2.ZERO),source_angles.y,int(input.get("stick_yaw",source_angles.y)))+modern_traversal_remainder
	var delta := Vector3i(roundi(units.x),roundi(units.y),roundi(units.z))
	modern_traversal_remainder = units-Vector3(delta)
	position += Vector3(delta)*world.CELL_METERS/4096.0
	source_animation_delta_this_tick += delta

func modern_controlled() -> bool:
	return world != null and world.has_method("sample_source_player_controls") and source_name == "Croc" and self == world.source_player_actor and world.vr_controls.layout == "modern" and world.source_main_mode == 4 and bool(world.source_player_input_state.get("modern",false))

func update_modern_motion() -> void:
	if not modern_controlled():
		modern_velocity = Vector3.ZERO
		modern_speed = 0.0
		modern_pose.reset()
		modern_blend_alpha = 1.0
		return
	var displacement: Vector3 = position-Vector3(previous_source_position)*world.CELL_METERS/4096.0
	var owner_id := int(source_ground.get("actor",-1))
	if owner_id >= 0 and world.source_pool.slots.has(owner_id):
		var owner = world.source_pool.slots[owner_id].node
		if is_instance_valid(owner): displacement -= owner.position-Vector3(owner.previous_source_position)*world.CELL_METERS/4096.0
	modern_velocity = displacement*30.0
	modern_speed = Vector2(displacement.x,displacement.z).length()*4096.0/world.CELL_METERS

func _process(_delta: float) -> void:
	if modern_controlled():
		modern_blend_alpha = minf(1.0,modern_blend_alpha+_delta/0.1)
		apply_pose()
		refresh_source_render_pose()
		modern_pose.apply(self,_delta)
	if world == null or sprite_parts.is_empty():
		return
	var view: Camera3D = world.get("head") if bool(world.get("xr_active")) else world.get("camera")
	if not is_instance_valid(view):
		return
	# Effects briefly collapse their root scale to zero. A global-basis write
	# would invert that singular parent transform; keep the collapsed pose.
	if not is_instance_valid(visual_root) or absf(visual_root.global_basis.determinant()) <= 0.000000000001:
		return
	# One shared head-center orientation for both eyes, with world-up keeping
	# sprites upright when the user rolls their head. No physics pose is changed.
	for part in sprite_parts:
		if is_instance_valid(part) and part.is_inside_tree() and part.global_position.distance_squared_to(view.global_position) > 0.000001:
			var parent := part.get_parent() as Node3D
			if parent != null and absf(parent.global_basis.determinant()) <= 0.000000000001:
				continue # Animated submodels can collapse independently of visual_root.
			part.global_basis = SpriteFacing.facing_basis(part.global_position,view.global_position,part.global_basis.get_scale())
var vm = VM.new()
var world: Node3D
var bindings: Array = []
var handles: Array[Dictionary] = [{}]
var mesh_parts: Array[MeshInstance3D] = []
var camera_bodies: Array[StaticBody3D] = []
var visual_root: Node3D
var model_name := ""
var bonus_door_material: ShaderMaterial

func refresh_bonus_door_feedback() -> void:
	if bonus_door_material != null and world != null:
		bonus_door_material.set_shader_parameter("collected_mask",int(world.source_bonus_mask))
var source_name := ""
var source_shadow_size: Variant = null
var source_shadow_type := 0
var contact_shadow: MeshInstance3D
var source_map_entity_index := -1
var tick_accumulator := 0.0
var source_animation_delta_this_tick := Vector3i.ZERO
var secondary_flags := 0
var primary_flags := 1
var source_scale := Vector3i(4096,4096,4096)
var source_rotation_y := 0
var source_angles := Vector3i.ZERO
var source_field_180 := 0
var source_field_180_valid := true
var source_field_184 := 0
var source_movement_status := 0
var source_movement_ground_height: Variant = null
var source_wall_angle := 0
var source_ceiling_type := 0
var source_contact_owner := 0
var source_last_platform_owner_id := -1
var source_upper_terrain_cache: Dictionary = {"tile":-1}
var source_vertical_speed := 0
var source_rise_remaining := 0
var source_pool_id := -1
var source_player_distance := 0
var source_player_distance_valid := false
var source_render_position := Vector3i.ZERO
var source_render_matrix: Array = []
var source_parent_id := -1
var source_child_id := -1 # Native actor word20, latest attached child.
var source_reference_slots: Dictionary = {}
var source_references_registered := false
var source_waypoints: Array = []
var source_waypoint_chain: Dictionary = {}
var source_waypoint_index := 0
func ensure_source_waypoint_chain() -> void:
	if not source_waypoint_chain.has("head") or source_waypoint_chain.get("nodes",{}).size() != source_waypoints.size():
		source_waypoint_chain = preload("res://source_waypoint_chain.gd").initialize(source_waypoints.size())
var source_spawn_y_units := 0
var source_saved_position := Vector3i.ZERO
var source_saved_angles := Vector3i.ZERO
var source_saved_pose_valid := false
var source_pose_padding: Array = [null,null] # Opaque actor878 halfword /892 word.
var source_saved_pose_padding: Array = [null,null]
func source_camera_pose_words() -> Array:
	# Camera42750 copies all24 bytes. Unknown padding remains opaque; the
	# camera's transform consumers only read the three angles and XYZ.
	var units := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
	var angle_word := (int(source_angles.x)&65535)|((int(source_angles.y)&65535)<<16)
	var roll_word: Variant = {"value":int(source_angles.z)&65535,"known_mask":65535} if source_pose_padding[0] == null else (int(source_angles.z)&65535)|((int(source_pose_padding[0])&65535)<<16)
	return [angle_word,roll_word,int(units.x)&0xffffffff,int(units.y)&0xffffffff,int(units.z)&0xffffffff,source_pose_padding[1]]
var source_blink_counter := 0
var source_blink_parts: Array[int] = []
var source_initial_primary_flags := 1
var source_terrain_cache: Dictionary = {"tile":-2}
var source_point_caches: Array[Dictionary] = [{"lower":{"tile":-1},"upper":{"tile":-1}},{"lower":{"tile":-1},"upper":{"tile":-1}},{"lower":{"tile":-1},"upper":{"tile":-1}},{"lower":{"tile":-1},"upper":{"tile":-1}},{"lower":{"tile":-1},"upper":{"tile":-1}},{"lower":{"tile":-1},"upper":{"tile":-1}}]
var source_ground: Dictionary = {"mode":0,"surface_type":0,"height_units":-65536}
var previous_source_position := Vector3i.ZERO
var previous_source_yaw := 0
# Source SVECTOR slots (seven records at actor offsets 64..119).
var collision_points: Array[Vector3i] = [Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO]
var collision_point_count := 0
var event_triggers: Array[Dictionary] = []
var released := false
var model_data: Dictionary = {}
var model_texture: Dictionary = {}
var clip: Dictionary = {}
var clip_name := ""
var clip_playing := false
var clip_frame := 0
var clip_fraction := 0
var clip_speed_offset := 0
var animation_triggers := 0

func evaluate_player_contact(points: Array, radii: Array, player_primary: int) -> Dictionary:
	var result := {"contact":false,"actor":primary_flags,"secondary":secondary_flags,"player":player_primary}
	if (primary_flags & 0x800) != 0 or model_data.is_empty():
		return result
	if (secondary_flags & 0x20) != 0:
		if (secondary_flags & 0x40) == 0:
			return result
		result.secondary = secondary_flags & ~0x40
		result.contact = true
	else:
		if not source_player_distance_valid or points.size() != radii.size():
			return {"fault":"Missing source player contact inputs"}
		var root_table: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[])
		var quarter: Array = world.runtime_tables.get("trigonometry",{}).get("quarterSine",[])
		if root_table.size() != 192:
			return {"fault":"Missing source contact root table"}
		var simple := (secondary_flags & 12) != 0
		var slab := not simple and (secondary_flags & 0x400) != 0
		if (simple or slab) and not source_field_180_valid:
			return {"fault":"Unknown source contact field 180"}
		var limit := 4096 if simple else (8192 if slab else (6656 if clip.is_empty() else 6144))
		if source_player_distance > limit:
			return result
		var actor_points: Dictionary = {}
		if not simple and not slab:
			actor_points = Rotation.model_contact_points(Rotation.scaled_matrix(source_render_matrix,source_scale),source_render_position,model_data.models,clip,clip_frame)
			if actor_points.has("fault"):
				return actor_points
		for index in range(points.size()):
			var delta := Vector3i(VM.signed32(points[index].x-source_render_position.x),VM.signed32(points[index].y-source_render_position.y),VM.signed32(points[index].z-source_render_position.z))
			if simple:
				result.contact = Collision.player_point_contact(delta,radii[index],source_field_180,source_field_184,source_scale.y,primary_flags,secondary_flags,player_primary,root_table)
			elif slab:
				if quarter.size() != 1025:
					return {"fault":"Missing source slab rotation table"}
				result.contact = Collision.player_slab_contact(delta,radii[index],source_field_180,source_field_184,source_scale.x,source_angles.y,primary_flags,player_primary,root_table,quarter)
			else:
				for other in range(actor_points.points.size()):
					var center: Vector3i = actor_points.points[other]
					var relative := Vector3i(VM.signed32(points[index].x-center.x),VM.signed32(points[index].y-center.y),VM.signed32(points[index].z-center.z))
					if Collision.model_pair_contact(relative,radii[index],roundi(float(model_data.models[other].radius)*4096.0),source_scale.y,primary_flags,player_primary,root_table):
						result.contact = true
						break
			if result.contact:
				break
	if result.contact:
		var flags := Collision.player_contact_flags(primary_flags,player_primary)
		result.actor = flags.actor
		result.player = flags.player
	return result

func source_point_cache(index: int) -> Dictionary:
	if index == 6:
		if not source_field_180_valid:
			return {"lower":{},"upper":{"tile":VM.signed32(source_field_184 << 16) >> 16,"record":(source_field_184 >> 16) & 65535}}
		return {"lower":{"tile":VM.signed32(source_field_180 << 16) >> 16,"record":(source_field_180 >> 16) & 65535},"upper":{"tile":VM.signed32(source_field_184 << 16) >> 16,"record":(source_field_184 >> 16) & 65535}}
	return source_point_caches[index] if index >= 0 and index < source_point_caches.size() else {}

func store_source_movement_cache(index: int, lower: Dictionary, upper: Dictionary) -> bool:
	if index < 0 or index > 6:
		return false
	var cached := Collision.movement_point_cache(lower,upper)
	if cached.has("fault"):
		return false
	if index == 6:
		if not cached.lower.has("record") or not cached.upper.has("record"):
			return false
		source_field_180 = VM.signed32((int(cached.lower.tile) & 65535) | (int(cached.lower.record) << 16))
		source_field_180_valid = true
		source_field_184 = VM.signed32((int(cached.upper.tile) & 65535) | (int(cached.upper.record) << 16))
	else:
		source_point_caches[index] = cached
	return true

func store_source_height_cache(index: int, lower: Dictionary) -> bool:
	if index < 0 or index > 6:
		return false
	var cached := source_point_cache(index).duplicate(true)
	if lower.is_empty():
		# Query miss writes tile -1; raw unwritten record contents remain unknown.
		cached["lower"] = {"tile":-1}
	elif lower.has("tile") and lower.has("record"):
		cached["lower"] = {"tile":VM.signed32(int(lower.tile) << 16) >> 16,"record":int(lower.record) & 65535}
	else:
		return false
	if index == 6:
		if not source_field_180_valid and not cached.lower.has("record"):
			return false
		var record := int(cached.lower.get("record",(source_field_180 >> 16) & 65535))
		source_field_180 = VM.signed32((int(cached.lower.tile) & 65535) | (record << 16))
		source_field_180_valid = true
	else:
		source_point_caches[index] = cached
	return true

func commit_source_movement(result: Dictionary) -> bool:
	if result.has("fault"):
		return false
	var owner: Node3D = null
	if int(result.ceiling_owner_secondary_set) != 0:
		var id := int(result.ceiling_owner)
		if not world.source_pool.slots.has(id):
			return false
		owner = world.source_pool.slots[id].node
		if owner == null or not is_instance_valid(owner) or not owner.has_method("source_point_cache"):
			return false
	position = Vector3(result.actor_position)*world.CELL_METERS/4096.0
	source_ground = result.ground.duplicate(true)
	source_movement_status = int(result.status) & 65535
	source_movement_ground_height = int(result.ground_height)
	source_ceiling_type = int(result.ceiling_type) & 255
	if result.has("wall_angle"):
		source_wall_angle = int(result.wall_angle) & 65535
	if result.has("contact_owner"):
		source_contact_owner = int(result.contact_owner) & 255
	source_terrain_cache = result.center_cache.lower.duplicate(true)
	source_upper_terrain_cache = result.center_cache.upper.duplicate(true)
	source_field_180_valid = result.field_180 != null
	if source_field_180_valid:
		source_field_180 = VM.signed32(int(result.field_180))
	if owner != null:
		owner.secondary_flags |= int(result.ceiling_owner_secondary_set)
	return true

func source_platform_owner() -> Node3D:
	if not source_ground.has("actor") or world == null:
		return null
	var index := int(source_ground.actor) & 255
	if not world.source_pool.slots.has(index):
		return null
	var owner = world.source_pool.slots[index].node
	if owner != null and is_instance_valid(owner) and owner.has_method("source_point_cache"):
		source_last_platform_owner_id = index
		return owner
	return null

func clear_source_platform_contact() -> bool:
	if (primary_flags & 0x48000) == 0 or (int(source_ground.mode) & 2) == 0:
		return true
	var owner := source_platform_owner()
	if owner == null:
		# Original actor slots remain addressable after Remove. Native removal
		# clears/frees that node, so cleanup of a previously resolved, released
		# slot has no flags left to clear. Continue into the fresh ground query.
		var old_id := int(source_ground.get("actor",-1))
		return world != null and old_id == source_last_platform_owner_id and world.source_pool.free_slots.has(old_id)
	owner.primary_flags = VM.signed32(int(owner.primary_flags) & ~0x400000)
	if (primary_flags & 0x800) != 0:
		owner.secondary_flags &= ~0x200
	return true

func apply_source_platform_response() -> bool:
	if (primary_flags & 0x48000) == 0 or (int(source_ground.mode) & 2) == 0:
		return true
	var owner := source_platform_owner()
	if owner == null:
		return false
	var flags := Collision.platform_contact_flags(int(owner.primary_flags),int(owner.secondary_flags),primary_flags,secondary_flags,source_movement_status,source_ceiling_type)
	owner.primary_flags = flags.primary
	owner.secondary_flags = flags.secondary
	var current := Vector3i(roundi(owner.position.x/world.CELL_METERS*4096.0),roundi(owner.position.y/world.CELL_METERS*4096.0),roundi(owner.position.z/world.CELL_METERS*4096.0))
	var rider := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
	var carried := Collision.platform_pose(rider,source_angles.y,current,owner.previous_source_position,owner.source_angles.y,owner.previous_source_yaw,(secondary_flags & 2) != 0,world.runtime_tables.get("trigonometry",{}).get("quarterSine",[]))
	if carried.has("fault"):
		return false
	position = Vector3(carried.position)*world.CELL_METERS/4096.0
	source_angles.y = carried.yaw
	source_rotation_y = source_angles.y
	rotation = Vector3(source_angles)*TAU/4096.0
	return true

func run_source_collision_response(query_buffers: Dictionary = {}) -> bool:
	# Dispatcher 0x8002d374..0x8002d748: old owner cleanup, height, movement, carry.
	if not clear_source_platform_contact():
		vm.fail("Unresolved previous platform owner")
		return false
	if (primary_flags & 0x8000) != 0 and not update_source_ground():
		return false
	if (primary_flags & 0x40000) != 0:
		var previous := source_ground.duplicate(true)
		var center := {"lower":source_terrain_cache.duplicate(true),"upper":source_upper_terrain_cache.duplicate(true)}
		var origin := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
		var state := {"actor_position":origin,"primary":primary_flags,"secondary":secondary_flags,"previous_mode":int(source_ground.mode),"ground_type":int(source_ground.get("surface_type",0)),"ground_height":int(source_ground.height_units),"contact_owner":source_contact_owner,"status":0,"contact_bits":0}
		for key in ["lower","upper"]:
			if query_buffers.has(key):
				state[key] = query_buffers[key].duplicate(true)
		state = world.source_movement_sample_loop(self,state)
		if not state.has("fault"):
			state = world.source_finalize_movement(self,state,center,previous)
		if state.has("fault"):
			vm.fail(str(state.fault))
			return false
		if not commit_source_movement(state):
			vm.fail("Unresolved final movement owner/state")
			return false
	if not apply_source_platform_response():
		vm.fail("Unresolved platform response")
		return false
	return true

func update_source_vertical(map_type: int, jump_held: bool) -> bool:
	var y := roundi(position.y / world.CELL_METERS * 4096.0)
	var result: Dictionary
	var vertical = preload("res://source_vertical.gd")
	if (primary_flags & 0x400) != 0:
		result = vertical.fall(y,source_vertical_speed,int(source_ground.height_units),primary_flags,secondary_flags,map_type)
		secondary_flags = result.secondary
	elif (primary_flags & 0x200) != 0:
		result = vertical.rise(y,source_vertical_speed,source_rise_remaining,primary_flags,jump_held)
		source_rise_remaining = result.remaining
	else:
		return false
	position.y = int(result.y) * world.CELL_METERS / 4096.0
	source_vertical_speed = result.speed
	primary_flags = result.primary
	return true

func initialize_source_player() -> bool:
	if world == null or not world.source_player_entry_state.has("present"):
		vm.fail("Unresolved source player entry globals")
		return false
	var entry: Dictionary = world.source_player_entry_state
	if bool(entry.present) and (not entry.has("position") or not entry.has("restore_yaw") or not entry.has("flags") or not world.room_data.has("style") or (bool(entry.restore_yaw) and not entry.has("yaw"))):
		vm.fail("Incomplete source player arrival state")
		return false
	primary_flags = VM.signed32(primary_flags | 0x02000800)
	secondary_flags &= ~2
	source_ground.height_units = 0
	if bool(entry.present):
		position = Vector3(entry.position)*world.CELL_METERS/4096.0
		if bool(entry.restore_yaw):
			source_angles.y = int(entry.yaw) & 4095
			source_rotation_y = source_angles.y
			rotation = Vector3(source_angles)*TAU/4096.0
		if not run_source_collision_response():
			return false
		if int(world.room_data.style) == 1:
			var y := roundi(position.y/world.CELL_METERS*4096.0)
			position.y = VM.signed32(y+2600)*world.CELL_METERS/4096.0
		elif (int(entry.flags) & 4) == 0:
			position.y = int(source_ground.height_units)*world.CELL_METERS/4096.0
			secondary_flags |= 2
	world.source_player_actor = self
	world.source_player_id = source_pool_id
	return true

func initialize_source_crystal() -> bool:
	if world == null:
		return false
	var old_secondary := secondary_flags
	var handle := asl_asset({"kind":1,"name":"CRYSTAL1.MOD"},vm)
	if vm.status == "unsupported" or asl_command({"op":58,"args":[[{"op":4,"value":handle},{"op":18}]]},vm) != "continue":
		return false
	primary_flags = VM.signed32(primary_flags|0x280a0)
	secondary_flags = old_secondary|4
	source_field_180 = 320
	source_field_180_valid = true
	if not run_source_collision_response():
		return false
	var parameter: int = int(vm.parameters[0]) if not vm.parameters.is_empty() else 0
	var y := ((parameter&0xffffffff)>>4) if parameter != 0 else VM.signed32(int(source_ground.height_units)+451)
	position.y = y*world.CELL_METERS/4096.0
	primary_flags = VM.signed32(primary_flags&~0x8000)
	while vm.parameters.size() < 3:
		vm.parameters.append(0)
	vm.parameters[1] = 0
	vm.parameters[2] = (world.source_random.bios_rand()&511)+200
	return true

func animation_trigger_matches(index: int) -> bool:
	# Mode 7 uses a one-based bit number and the CPU's low-five-bit shift count.
	return ((animation_triggers >> ((index - 1) & 31)) & 1) != 0
var pose_cache: Dictionary = {}
const Collision = preload("res://source_collision.gd")
const Rotation = preload("res://source_rotation.gd")

func apply_root_frame() -> bool:
	if world == null or not clip.has("frameInfo"):
		vm.fail("Missing animation root-frame data")
		return false
	var info: Array = clip.frameInfo[clip_frame]
	if modern_controlled() and preload("res://modern_traversal.gd").locomotion(modern_traversal_mode(),clip_name):
		return true # Continuous surface movement replaces travel and steering roots.
	if modern_controlled() and preload("res://modern_motion_palette.gd").motion_driven(clip_name) and not preload("res://modern_motion_palette.gd").reversal(clip_name):
		return true # Ordinary locomotion clips never steer or displace modern input.
	var matrix := Rotation.matrix(source_angles,world.runtime_tables.get("rotation",{}).get("pairs",[]))
	if matrix.is_empty():
		vm.fail("Missing source rotation table")
		return false
	matrix = Rotation.scaled_matrix(matrix,source_scale)
	var delta := Rotation.frame_delta(matrix,Vector3i(int(info[2]),int(info[3]),int(info[4])))
	if modern_controlled() and clip_name in ["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI","CROCJ180.ANI"]:
		# Keep the authored rotation/vertical arc; stick input owns horizontal travel.
		delta.position.x = 0
		delta.position.z = 0
	var current := Vector3i(roundi(position.x / world.CELL_METERS * 4096.0),roundi(position.y / world.CELL_METERS * 4096.0),roundi(position.z / world.CELL_METERS * 4096.0))
	for i in range(3):
		current[i] = VM.signed32(current[i] + delta.position[i])
		source_animation_delta_this_tick[i] = VM.signed32(source_animation_delta_this_tick[i]+delta.position[i])
	position = Vector3(current) * world.CELL_METERS / 4096.0
	var increments := Vector3i(int(info[0]) & 65535,(int(info[0]) >> 16) & 65535,int(info[1]) & 65535)
	for i in range(3):
		source_angles[i] = (source_angles[i] + increments[i]) & 4095
	source_rotation_y = source_angles.y
	rotation = Vector3(source_angles) * TAU / 4096.0
	return true

func model_surface_candidates_at(location: Vector3, query_actor: Node3D = null) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if query_actor == self or (secondary_flags & 0x20) == 0 or source_scale.x == 0 or source_scale.z == 0 or model_data.is_empty():
		return hits
	var model: Dictionary = model_data.models[0]
	var point := Vector2i(roundi(location.x / world.CELL_METERS * 4096.0),roundi(location.z / world.CELL_METERS * 4096.0))
	var origin := Vector2i(roundi(global_position.x / world.CELL_METERS * 4096.0),roundi(global_position.z / world.CELL_METERS * 4096.0))
	var delta := Vector2i(VM.signed32(point.x - origin.x),VM.signed32(point.y - origin.y))
	if not Collision.actor_radius_contains(delta,roundi(float(model.radius) * 4096.0)):
		return hits
	var quarter: Array = world.runtime_tables.get("trigonometry",{}).get("quarterSine",[])
	var index := 0
	for group in model.get("collision",{}).get("groups",[]):
		for record in group:
			var hit := Collision.actor_surface(record,delta,source_rotation_y,source_scale,roundi(global_position.y / world.CELL_METERS * 4096.0),quarter)
			if not hit.is_empty():
				hit["record"] = index
				hits.append(hit)
			index += 1
	return hits

func update_source_ground() -> bool:
	var terrain_hit: Dictionary = world.source_cached_floor_at(global_position,source_terrain_cache)
	source_terrain_cache = terrain_hit.duplicate(true) if not terrain_hit.is_empty() else {"tile":-1}
	var contacts: Dictionary = world.source_contacts_at(global_position,self)
	var y_units := roundi(global_position.y / world.CELL_METERS * 4096.0)
	source_ground = Collision.choose_ground(terrain_hit,contacts.lower,y_units)
	if (primary_flags & 0x1000000) == 0:
		return true
	var matrix := Rotation.matrix(source_angles,world.runtime_tables.get("rotation",{}).get("pairs",[]))
	if matrix.is_empty():
		vm.fail("Missing source collision-point rotation table")
		return false
	var samples: Array = []
	var height := int(source_ground.height_units)
	var origin := Vector3i(roundi(global_position.x / world.CELL_METERS * 4096.0),y_units,roundi(global_position.z / world.CELL_METERS * 4096.0))
	for index in range(collision_point_count):
		if height == y_units:
			break
		var offset := Rotation.point_offset(matrix,collision_points[index],source_scale)
		var point := Vector3i(VM.signed32(origin.x + offset.position.x),VM.signed32(origin.y + offset.position.y),VM.signed32(origin.z + offset.position.z))
		var location: Vector3 = Vector3(point) * world.CELL_METERS / 4096.0
		var floor_hit: Dictionary = world.source_cached_floor_at(location,source_point_cache(index).get("lower",{}))
		store_source_height_cache(index,floor_hit)
		var point_contacts: Dictionary = world.source_contacts_at(location,self)
		samples.append({"terrain":floor_hit,"actor_lower":point_contacts.lower})
		for hit in [floor_hit,point_contacts.lower]:
			if not hit.is_empty() and height < int(hit.height_units):
				height = int(hit.height_units)
	source_ground = Collision.refine_ground_points(source_ground,samples,y_units,true)
	return true

func advance_animation() -> void:
	if not model_data.is_empty():
		animation_triggers = 0
	if not clip_playing or clip.is_empty():
		return
	var traversal_mode := modern_traversal_mode()
	var traversal = preload("res://modern_traversal.gd")
	if traversal.locomotion(traversal_mode,clip_name):
		var requested := traversal.animation_button(traversal_mode,world.source_player_input_state.get("surface_axes",Vector2.ZERO))
		if traversal.clip_button(traversal_mode,clip_name) != requested:
			clip_playing = false
			primary_flags &= ~8
			return
	if modern_controlled() and preload("res://modern_character_pose.gd").gait(clip_name):
		var input: Dictionary = world.source_player_input_state
		var stopped := int(input.get("magnitude",0))<=int(input.get("idle_threshold",16)) or bool(input.get("turn_only",false))
		var intended_role := "run" if int(input.get("magnitude",0))>int(input.get("run_threshold",90))-(6 if int(world.source_player_movement_state.get("mode",0))==2 else 0) else "walk"
		if bool(input.get("turn_step",false)): intended_role = "turn"
		if bool(input.get("natural_step",false)):
			var f := float(input.get("local_forward",0.0))
			var s := float(input.get("local_side",0.0))
			intended_role = "backward" if f < -0.35 and absf(f)>=absf(s) else "sidestep"
		if bool(input.get("precision",false)):
			var buttons := int(world.source_input_held_mask)
			intended_role = "sidestep" if (buttons&0x180)!=0 else "backward" if (buttons&2)!=0 else "walk"
		var role := preload("res://modern_motion_palette.gd").family(clip_name)
		if stopped or (role in ["walk","run","backward","sidestep"] and role != intended_role):
			# Let the source script select skid/settle/idle immediately rather than
			# waiting for a slow locomotion loop to finish at near-zero cadence.
			clip_playing = false
			primary_flags &= ~8
			return
	# Header rate plus unsigned halfword offset, with a halfword accumulator.
	var rate := (int(clip.speed)+clip_speed_offset)&65535
	if traversal.locomotion(traversal_mode,clip_name) and traversal.clip_button(traversal_mode,clip_name) != 0:
		rate = roundi(float(clip.speed)*Vector2(world.source_player_input_state.get("surface_axes",Vector2.ZERO)).length())
	if modern_controlled() and clip_name in ["CROC1801.ANI","CROC1802.ANI","CROCT180.ANI","CROCJ180.ANI"]:
		rate = int(clip.speed)
	if modern_controlled() and preload("res://modern_character_pose.gd").gait(clip_name) and clip_name != "CROCPUSH.ANI" and (secondary_flags&2) != 0:
		var reference := 140.0 if clip_name == "CROCRUN.ANI" else 48.0 if clip_name in ["CROCSLT2.ANI","CROCSRT2.ANI"] else 60.0
		rate = clampi(roundi(float(clip.speed)*modern_speed/reference),0,512)
	elif modern_controlled() and clip_name in ["CROCLEFT.ANI","CROCRGHT.ANI"]:
		var turning := preload("res://source_player_movement.gd").halfword(int(world.source_player_movement_state.get("turn_history",0))>>16)
		rate = clampi(roundi(float(clip.speed)*absf(float(turning))/63.0),16,512)
	clip_fraction = (clip_fraction + rate) & 65535
	while clip_fraction >= 256:
		clip_fraction -= 256
		if not apply_root_frame():
			clip_playing = false
			primary_flags &= ~8
			return
		# Retail 0x8002ca44..0x8002ca74 ORs matching masks before frame increment.
		for trigger in clip.get("triggers",[]):
			if int(trigger[0]) == clip_frame:
				animation_triggers = (animation_triggers | int(trigger[1])) & 255
		clip_frame += 1
		if clip_frame >= int(clip.frameCount):
			clip_frame = int(clip.frameCount) - 1
			clip_playing = false
			primary_flags &= ~8
	apply_pose()

func select_animation(handle: int, start_playing: bool) -> bool:
	if handle <= 0 or handle >= handles.size() or int(handles[handle].kind) != 4:
		return false
	var file:String=str(handles[handle].file)
	if not animation_assets.has(file):animation_assets[file]=world.read_source_asset(file) if world.has_method("read_source_asset") else world.read_json(file)
	var data: Dictionary = animation_assets[file]
	if data.is_empty() or int(data.get("frameCount",0)) <= 0:
		return false
	var deforming := int(data.vertexCount) > 0
	if model_data.is_empty() or int(data.boneCount) + int(deforming) != mesh_parts.size():
		return false
	if deforming and int(data.vertexCount) != model_data.models[0].vertices.size():
		return false
	var palette = preload("res://modern_motion_palette.gd")
	modern_blend_alpha = 1.0
	if modern_controlled() and palette.blendable(clip_name) and palette.blendable(str(handles[handle].name)) and palette.family(clip_name) != palette.family(str(handles[handle].name)):
		modern_blend_parts.clear()
		for part in mesh_parts: modern_blend_parts.append(part.transform)
		modern_blend_points = modern_pose.last_points.duplicate()
		if modern_blend_points.size() == 100: modern_blend_alpha = 0.0
	clip = data
	animation_asset_file=file
	if world.has_method("source_animation_feedback"):
		world.source_animation_feedback(self,clip_name,str(handles[handle].name))
	clip_name = handles[handle].name
	clip_frame = 0
	clip_fraction = 0
	if start_playing:
		clip_playing = true
		primary_flags |= 8
	if not pose_banks.has(file):pose_banks[file]={}
	pose_bank_order.erase(file);pose_bank_order.append(file)
	if pose_bank_order.size()>8:pose_banks.erase(pose_bank_order.pop_front())
	pose_cache=pose_banks[file]
	apply_pose()
	return true

func advance_source_blink() -> void:
	if model_data.is_empty() or (primary_flags & 0x100) == 0:
		return
	source_blink_counter = VM.signed32(source_blink_counter+1)
	if source_blink_counter == 4:
		source_blink_counter = 0
		primary_flags &= ~0x100

func source_blink_matrix(values: Array, model_index: int) -> Array:
	var phase := source_blink_counter & 3
	if phase == 0 or not source_blink_parts.has(model_index):
		return values
	var table: Array = world.runtime_tables.get("blink",{}).get("yScaleUnits",[])
	if table.size() != 4:
		vm.fail("Missing source blink matrices")
		return values
	return Rotation.scaled_matrix(values,Vector3i(4096,int(table[phase]),4096))

func apply_pose() -> void:
	if clip.is_empty() or model_data.is_empty():
		return
	var deforming := int(clip.vertexCount) > 0
	if deforming:
		if not pose_cache.has(clip_frame):
			var posed: Dictionary = model_data.models[0].duplicate()
			var vertices: Array = []
			for packed_value in clip.vertices[clip_frame]:
				var packed := int(packed_value)
				var point: Array = []
				for shift in [0,10,20]:
					var value: int = (packed >> int(shift)) & 1023
					if value >= 512:
						value -= 1024
					point.append(float(value) / 1024.0)
				vertices.append(point)
			posed.vertices = vertices
			var key:=model_asset_file+":"+animation_asset_file+":"+str(clip_frame)
			pose_cache[clip_frame] = world.source_deformed_mesh(key,posed,model_texture) if world.has_method("source_deformed_mesh") and not model_asset_file.is_empty() else world.geometry(posed,model_texture)
		mesh_parts[0].mesh = pose_cache[clip_frame]
		var body_matrix := source_blink_matrix([4096,0,0,0,4096,0,0,0,4096],0)
		mesh_parts[0].basis = Basis(Vector3(body_matrix[0],body_matrix[3],body_matrix[6])/4096.0,Vector3(body_matrix[1],body_matrix[4],body_matrix[7])/4096.0,Vector3(body_matrix[2],body_matrix[5],body_matrix[8])/4096.0)
	for i in range(int(clip.boneCount)):
		var m: Array = clip.bones[clip_frame][i]
		var matrix := source_blink_matrix(m.slice(0,9),i+int(deforming))
		var basis := Basis(Vector3(matrix[0],matrix[3],matrix[6])/4096.0,Vector3(matrix[1],matrix[4],matrix[7])/4096.0,Vector3(matrix[2],matrix[5],matrix[8])/4096.0)
		mesh_parts[i + int(deforming)].transform = Transform3D(basis,Vector3(m[9],m[10],m[11]) * world.CELL_METERS / 4096.0)
		if modern_controlled() and clip_playing and clip_frame+1 < int(clip.frameCount) and absf(basis.determinant())>0.01:
			var following: Array = clip.bones[clip_frame+1][i]
			var next_basis := Basis(Vector3(following[0],following[3],following[6])/4096.0,Vector3(following[1],following[4],following[7])/4096.0,Vector3(following[2],following[5],following[8])/4096.0)
			if absf(next_basis.determinant())>0.01:
				var fraction := float(clip_fraction)/256.0
				mesh_parts[i+int(deforming)].transform = mesh_parts[i+int(deforming)].transform.interpolate_with(Transform3D(next_basis,Vector3(following[9],following[10],following[11])*world.CELL_METERS/4096.0),fraction)
		if modern_controlled() and modern_blend_alpha<1.0 and modern_blend_parts.size()==mesh_parts.size():
			var part_index := i+int(deforming)
			mesh_parts[part_index].transform = modern_blend_parts[part_index].interpolate_with(mesh_parts[part_index].transform,modern_blend_alpha)

func _physics_process(delta: float) -> void:
	tick_accumulator += delta
	while tick_accumulator >= 1.0 / 30.0:
		tick_accumulator -= 1.0 / 30.0
		begin_source_tick()
		run_source_scripts()

func begin_source_tick() -> void:
	refresh_bonus_door_feedback()
	source_animation_delta_this_tick = Vector3i.ZERO
	previous_source_position = Vector3i(roundi(position.x / world.CELL_METERS * 4096.0),roundi(position.y / world.CELL_METERS * 4096.0),roundi(position.z / world.CELL_METERS * 4096.0))
	previous_source_yaw = source_rotation_y
	advance_modern_traversal()
	advance_animation()

func refresh_source_render_pose() -> bool:
	var rendered := Vector3i(roundi(position.x / world.CELL_METERS * 4096.0),roundi(position.y / world.CELL_METERS * 4096.0),roundi(position.z / world.CELL_METERS * 4096.0))
	var pairs: Array = world.runtime_tables.get("rotation",{}).get("pairs",[])
	var matrix := Rotation.matrix(source_angles,pairs)
	var current: Node3D = self
	var visited: Array[int] = []
	while (int(current.primary_flags) & 0x4000000) != 0:
		var index := int(current.source_parent_id)
		if visited.has(index) or not world.source_pool.slots.has(index) or matrix.is_empty():
			vm.fail("Unresolved source child transform chain")
			return false
		visited.append(index)
		var parent = world.source_pool.slots[index].node
		if parent == null or not is_instance_valid(parent) or not parent.has_method("refresh_source_render_pose"):
			vm.fail("Unimplemented source child parent pose")
			return false
		var parent_position := Vector3i(roundi(parent.position.x / world.CELL_METERS * 4096.0),roundi(parent.position.y / world.CELL_METERS * 4096.0),roundi(parent.position.z / world.CELL_METERS * 4096.0))
		var composed := Rotation.parent_pose(Rotation.matrix(parent.source_angles,pairs),parent_position,matrix,rendered)
		if composed.has("fault"):
			vm.fail(str(composed.fault))
			return false
		rendered = composed.position
		matrix = composed.matrix
		current = parent
	source_render_position = rendered
	source_render_matrix = matrix
	if is_instance_valid(visual_root) and not matrix.is_empty():
		var scaled := Rotation.scaled_matrix(matrix,source_scale)
		var basis := Basis(Vector3(scaled[0],scaled[3],scaled[6])/4096.0,Vector3(scaled[1],scaled[4],scaled[7])/4096.0,Vector3(scaled[2],scaled[5],scaled[8])/4096.0)
		visual_root.global_transform = Transform3D(basis,Vector3(rendered) * world.CELL_METERS / 4096.0)
	preload("res://source_contact_shadow.gd").update(self)
	return true

func run_source_scripts(vertical_context: Dictionary = {}) -> void:
	# Retail 0x8002cc4c..0x8002cc60 clears transient bits before the trigger scan.
	primary_flags = VM.signed32(primary_flags & ~0x3002)
	if not vertical_context.is_empty():
		update_source_vertical(int(vertical_context.map_style),bool(vertical_context.jump_held))
	for index in range(event_triggers.size()):
		var trigger: Dictionary = event_triggers[index]
		if (primary_flags & 0x40) != 0 or (secondary_flags & 0x80) == 0:
			break
		if int(trigger.mode) == 1 and (primary_flags & 0x100000) != 0:
			if queue_trigger(index):
				primary_flags &= ~0x100000
		elif int(trigger.mode) == 11 and (int(source_ground.get("mode",0)) & 0x0c) != 0:
			# Retail2cd64 tests actor byte62: ground structure+6, not status+62.
			# This dispatches the original ledge/wall-grab procedure.
			queue_trigger(index)
		elif int(trigger.mode) in [8,9] and (primary_flags & (0x2000 if int(trigger.mode) == 8 else 0x1000)) != 0:
			queue_trigger(index)
		elif int(trigger.mode) == 2:
			trigger.counter = VM.signed32(int(trigger.counter)+1)
			if int(trigger.counter) == int(trigger.period):
				trigger.counter = 0
				queue_trigger(index)
		elif int(trigger.mode) == 7 and animation_trigger_matches(int(trigger.bit)):
			queue_trigger(index)
		elif int(trigger.mode) == 6 and world != null and is_instance_valid(world.source_player_actor):
			if not source_player_distance_valid:
				vm.fail("Missing source cached distance for trigger6")
				break
			if (VM.signed32(source_player_distance<<4)&0xffffffff) < (int(trigger.threshold)&0xffffffff):
				queue_trigger(index)
	if vm.status in ["ready","yielded"]:
		vm.run()
	# 0x8002cf9c..0x8002cfb4 invokes response after script execution has yielded.
	if world != null and vm.status in ["yielded","finished"] and (primary_flags & 0x78000) != 0:
		run_source_collision_response()

func asl_file_end(_machine: RefCounted) -> void:
	# Retail 0x8002b104..0x8002b110; pointer remains on FileEnd until removal.
	primary_flags = VM.signed32(primary_flags | 6)

func queue_trigger(index: int) -> bool:
	if vm.status in ["unsupported","finished"]:
		return false
	vm.frames.append({"kind":"trigger","pc":vm.pc,"index":index})
	vm.pc = int(event_triggers[index].pc)
	vm.status = "yielded"
	event_triggers[index].active = true
	primary_flags |= 0x20000000
	return true

func dispatch_event(mode: int) -> bool:
	var dispatched := false
	for index in range(event_triggers.size()):
		if int(event_triggers[index].mode) != mode:
			continue
		dispatched = queue_trigger(index) or dispatched
	if dispatched:
		vm.run()
	return dispatched

func configure(owner: Node3D, definition: Dictionary, program: Dictionary, entity: Dictionary, assets: Array, run_initial: bool = true) -> void:
	world = owner
	if world.has_method("source_resource_handle_bank"):
		handles=world.source_resource_handle_bank()
	source_waypoints = entity.get("waypoints",[])
	source_waypoint_chain = entity.runtime_waypoint_chain.duplicate(false) if entity.has("runtime_waypoint_chain") else preload("res://source_waypoint_chain.gd").initialize(source_waypoints.size())
	source_waypoint_index = int(source_waypoint_chain.head)
	source_name = entity.name
	source_map_entity_index = int(entity.get("source_map_index",-1))
	bindings = assets
	vm.configure(program,int(definition.pc),self,entity.params)
	var pose: Dictionary = {"position":entity.runtime_position} if entity.has("runtime_position") else world.source_map_position(entity.position)
	if pose.has("fault"):
		vm.fail(str(pose.fault))
		return
	source_render_position = pose.position
	position = Vector3(source_render_position)*world.CELL_METERS/4096.0
	source_spawn_y_units = source_render_position.y
	source_initial_primary_flags = primary_flags
	rotation = Vector3(entity.rotation[0],entity.rotation[1],entity.rotation[2]) * TAU
	source_rotation_y = roundi(float(entity.rotation[1]) * 4096.0)
	source_angles = Vector3i(roundi(float(entity.rotation[0]) * 4096.0),source_rotation_y,roundi(float(entity.rotation[2]) * 4096.0))
	source_saved_position = source_render_position
	source_saved_angles = source_angles
	source_saved_pose_valid = true
	if world.has_method("register_source_actor_references") and not bool(entity.get("runtime_skip_reference_queue",false)):
		world.register_source_actor_references(self)
	if run_initial:
		vm.run()

func asl_asset(term: Dictionary, machine: RefCounted) -> int:
	var kind := int(term.kind)
	if kind in [142,81]:
		if world == null or not world.room_data.has("waitAnimation"):
			machine.fail("Unknown source room idle resource")
			return 0
		var idle := int(world.room_data.waitAnimation)
		if idle == 0:
			return 0
		return asl_asset({"kind":3 if kind == 142 else 4,"name":"CROCWA%d.ANI" % idle if kind == 142 else "CROCWA%d" % idle},machine)
	if kind == 9:
		if world == null:
			machine.fail("Missing source sound world")
			return 0
		var mode := int(term.mode)
		var arguments: Array = term.args
		var handle: int = machine.evaluate(arguments[0]) >> 16
		var volume: int = 100 if mode < 2 else machine.evaluate(arguments[1]) >> 16
		var pitch := 0
		if mode >= 4:
			pitch = machine.evaluate(arguments[2]) >> 16
			machine.evaluate(arguments[3]) # Source consumes this expression but ignores its value.
		if machine.status == "unsupported" or handle <= 0 or handle >= handles.size():
			machine.fail("Missing source sound sample handle")
			return 0
		return world.play_imported_sound_voice(handles[handle],global_position,float(volume),pitch)
	var wanted := 2 if kind in [1,2] else 4 if kind in [3,5] else 3 if kind in [4,80] else -1
	if wanted < 0:
		machine.fail("Unsupported resource expression kind %d" % kind)
		return 0
	for asset in bindings:
		if asset.name == term.name and (int(asset.kind) == wanted or (wanted == 2 and int(asset.kind) == 5)):
			for i in range(1,handles.size()):
				if handles[i].get("file","") == asset.get("file","") and handles[i].name == asset.name:
					return i * 65536 if wanted == 3 else i
			handles.append(asset)
			return (handles.size() - 1) * 65536 if wanted == 3 else handles.size() - 1
	if kind in [5,80] and world != null and world.room_data.has("flags"):
		for reference in machine.program.get("references",[]):
			if int(reference.kind) != (7 if kind == 5 else 8) or reference.name != term.name:
				continue
			var condition: Array = reference.get("condition",[])
			if condition.size() == 3 and int(condition[0].op) == 4 and int(condition[1].op) == 35 and int(condition[2].op) == 18 and (int(world.room_data.flags) & int(condition[0].value)) == 0:
				return 0
	machine.fail("Missing named resource: " + str(term.get("name","")))
	return 0

func source_waypoint_position(point: Dictionary) -> Dictionary:
	if point.has("runtime_position"):
		return {"position":Vector3i(point.runtime_position)}
	if world == null:
		return {"fault":"Missing source waypoint world"}
	return world.source_map_position(point.get("position",[]))

func asl_expression(term: Dictionary, stack: Array, machine: RefCounted) -> bool:
	if int(term.op)==34:
		# Retail30500..30568: pop target Z/Y/X, pose-distance38e8c, then <<4.
		if world==null or stack.size()<3:
			machine.fail("Missing source target distance operands")
			return true
		var target_z: int=stack.pop_back()
		var target_y: int=stack.pop_back()
		var target_x: int=stack.pop_back()
		var roots: Array=world.runtime_tables.get("distanceRoot",{}).get("values",[])
		if roots.size()!=192:
			machine.fail("Missing source target distance root table")
			return true
		var origin := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
		var delta := Vector3i(VM.signed32(target_x-origin.x),VM.signed32(target_y-origin.y),VM.signed32(target_z-origin.z))
		stack.append(VM.signed32(Collision.player_distance(delta,roots)<<4))
		return true
	if int(term.op) == 46:
		if world == null or stack.is_empty():
			machine.fail("Missing source pickup-slot read input")
		else:
			var index := int(stack.pop_back())
			if index < 0 or index >= world.source_stage_pickup_slots.size():
				machine.fail("Invalid source pickup-slot read index")
			else:
				stack.append(VM.signed32(int(world.source_stage_pickup_slots[index])))
		return true
	if int(term.op) == 1:
		if world != null and world.has_method("source_parent_global_bank"):
			var retained: Dictionary=world.source_parent_global_bank(source_parent_id)
			if retained.has("bank"):stack.append(VM.signed32(int(retained.bank.get(int(term.index),0))))
			else:machine.fail("Missing source parent global bank")
			return true
		if world == null or not world.source_pool.slots.has(source_parent_id):
			machine.fail("Missing source parent for global read")
		else:
			var parent = world.source_pool.slots[source_parent_id].node
			if parent == null or not is_instance_valid(parent) or not parent.has_method("asl_expression"):
				machine.fail("Invalid source parent for global read")
			else:
				stack.append(VM.signed32(int(parent.vm.globals.get(int(term.index),0))))
		return true
	if int(term.op) in [20,21]:
		var quarter: Array = world.runtime_tables.get("trigonometry",{}).get("quarterSine",[]) if world != null else []
		if stack.is_empty() or quarter.size() != 1025:
			machine.fail("Missing source trigonometric expression input/table")
		else:
			var angle := (int(stack.pop_back())>>16)&4095
			stack.append(VM.signed32(Collision.sine(angle+(1024 if int(term.op) == 21 else 0),quarter)<<4))
		return true
	if int(term.op) == 28:
		var index := int(term.index)
		if world == null or not world.source_extended_globals.has(index):
			machine.fail("Unknown source extended global %d" % index)
		else:
			stack.append(VM.signed32(int(world.source_extended_globals[index])))
		return true
	if int(term.op) == 35:
		# Retail 0x8003056c drops the loading-condition operand outside loading.
		if stack.is_empty():
			machine.fail("Conditional resource expression stack underflow")
		elif (primary_flags & 0x08000000) == 0:
			stack.pop_back()
		return true
	if int(term.op) == 25:
		if world == null or stack.is_empty():
			machine.fail("Missing source random world or bound")
			return true
		var result: Dictionary = world.source_random.bounded(int(stack.pop_back()))
		if result.has("fault"):
			machine.fail(str(result.fault))
		else:
			stack.append(result.value)
		return true
	if int(term.op) == 45:
		var index := int(term.index)
		if index < 0 or index >= 8 or world == null:
			machine.fail("Missing source parent parameter")
			return true
		var state: Dictionary = world.source_parent_parameters(source_parent_id)
		if state.is_empty():
			machine.fail("Missing source parent parameter")
			return true
		stack.append(VM.signed32(int(state.parameters[index])) if index < state.parameters.size() else 0)
		return true
	if int(term.op) == 3:
		var index := int(term.index)
		if index in [49,50]:
			# Native2f818/2f830 reads registered player word372, raw bit masks.
			var player = world.source_player_actor if world != null else null
			if not is_instance_valid(player): machine.fail("Missing source player flag owner")
			else: stack.append(int(player.primary_flags)&(0x200 if index == 49 else 0x400))
			return true
		if index in [78,79]:
			if index == 78:
				stack.append(secondary_flags&0x800)
			elif world != null and world.source_pool.slots.has(source_parent_id):
				var parent = world.source_pool.slots[source_parent_id].get("node",null)
				if is_instance_valid(parent): stack.append(int(parent.secondary_flags)&0x800)
				else: machine.fail("Missing source parent flags")
			elif world != null and world.source_actor_parameter_memory.has(source_parent_id):
				stack.append(0) # Native Free clears both flag words before reuse.
			else: machine.fail("Missing source parent flags")
			return true
		if index == 63:
			var player = world.source_player_actor if world != null else null
			if not is_instance_valid(player):
				stack.append(0) # Native getter's missing-player path.
				return true
			var delta := Vector2i(VM.signed32(roundi(player.position.x/world.CELL_METERS*4096.0)-roundi(position.x/world.CELL_METERS*4096.0)),VM.signed32(roundi(player.position.z/world.CELL_METERS*4096.0)-roundi(position.z/world.CELL_METERS*4096.0)))
			var angle := Collision.wall_normal_angle(delta,world.runtime_tables.get("wallAngles",{}).get("values",[]))
			if angle.has("fault"): machine.fail(str(angle.fault))
			else: stack.append(VM.signed32((int(angle.angle)&4095)<<16))
			return true
		if index == 82:
			if world == null:
				machine.fail("Missing source menu reveal state")
			else:
				stack.append(VM.signed32(int(world.source_menu_reveal_state)))
			return true
		if index == 48:
			var flags := 0
			if world != null and source_map_entity_index >= 0:
				flags = int(world.source_map_entity_flags.get(world.map_name,{}).get(source_map_entity_index,0))
			stack.append(flags&2)
			return true
		if index in [68,80,81,87,88]:
			if world == null:
				machine.fail("Missing source level/menu state")
			elif index == 68:
				stack.append(VM.signed32(int(world.source_level_script_state)<<16))
			elif index == 81:
				stack.append(VM.signed32(((int(world.source_menu_state.selected_index)&0xffffffff)%10)<<16))
			elif index in [87,88]:
				stack.append(VM.signed32(int(world.source_menu_state["return_mode" if index == 87 else "secret_return"])<<16))
			else:
				stack.append(VM.signed32(int(world.source_menu_state.selection_changes)))
				world.source_menu_state.selection_changes = 0
			return true
		if index == 11:
			var roots: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[]) if world != null else []
			if roots.size() != 192:
				machine.fail("Missing source motion-distance root table")
			else:
				var delta := Vector3i(VM.signed32(roundi(position.x/world.CELL_METERS*4096.0)-previous_source_position.x),0,VM.signed32(roundi(position.z/world.CELL_METERS*4096.0)-previous_source_position.z))
				stack.append(VM.signed32(Collision.player_distance(delta,roots)<<4))
			return true
		if index in [18,19,20]:
			var player = world.source_player_actor if world != null else null
			if player == null or not is_instance_valid(player):
				machine.fail("Missing registered source player angles")
			else:
				stack.append(VM.signed32((int(player.source_angles[index-18])&4095)<<16))
			return true
		if index == 45:
			if world == null or not world.source_camera_state.has("yaw"):
				machine.fail("Unknown source camera yaw")
			else:
				stack.append(VM.signed32((int(world.source_camera_state.yaw)&4095)<<16))
			return true
		if index in [15,16,17]:
			var player = world.source_player_actor if world != null else null
			if player == null or not is_instance_valid(player):
				machine.fail("Missing registered source player position")
			else:
				stack.append(VM.signed32(roundi(player.position[index-15]/world.CELL_METERS*4096.0)))
			return true
		if index == 86:
			# Retail2fc60 reads current room word16 without fixed-point shifting.
			if world == null or not world.room_data.has("flags"):
				machine.fail("Missing source room flags")
			else:
				stack.append(VM.signed32(int(world.room_data.flags)))
			return true
		if index in [72,73]:
			var key := "mode" if index == 72 else "turn_history"
			if world == null or not world.source_player_movement_state.has(key):
				machine.fail("Unknown source movement mode")
			else:
				stack.append(VM.signed32(int(world.source_player_movement_state[key])))
			return true
		if index == 65:
			stack.append(secondary_flags&2)
			return true
		if index == 36:
			stack.append(primary_flags&0x400000)
			return true
		if index in [46,67]:
			if world == null:
				machine.fail("Missing source pickup/bonus state")
			else:
				stack.append(VM.signed32(int(world.source_pickup_counts[2])<<16) if index == 46 else int(world.source_bonus_mask == 31))
			return true
		if index == 41:
			if world == null:
				machine.fail("Missing source crystal count")
			else:
				stack.append(VM.signed32(int(world.source_pickup_counts[1])<<16))
			return true
		if index in [24,25]:
			stack.append(primary_flags & (0x200 if index == 24 else 0x400))
			return true
		if index in [12,13]:
			if world == null:
				machine.fail("Missing source input backend")
			elif world.source_input_suppression_count != 0:
				stack.append(0)
			elif (world.source_input_held_mask if index == 12 else world.source_input_pressed_mask) == null:
				machine.fail("Unknown source button word")
			else:
				var buttons := int(world.source_input_held_mask if index == 12 else world.source_input_pressed_mask)
				if index == 12 and self == world.source_player_actor and source_name == "Croc":
					buttons = world.vr_controls.animation_buttons(buttons,int(world.source_player_input_state.get("pad_mode",1)),int(world.source_player_movement_state.get("mode",0)),secondary_flags,int(world.source_player_movement_state.get("turn_history",0)),world.player_traversal_mode(),world.source_player_input_state.get("surface_axes",Vector2.ZERO))
				stack.append(VM.signed32(buttons))
			return true
		if index == 84:
			var player = world.source_player_actor if world != null else null
			if player == null or not is_instance_valid(player):
				machine.fail("Missing source player for ground-mode query")
			elif (int(player.source_ground.get("surface_type",0))&0x80) == 0:
				stack.append(0)
			elif world.source_ground_mode_80_value == null:
				machine.fail("Unknown source ground-mode-0x80 global")
			else:
				stack.append(VM.signed32(int(world.source_ground_mode_80_value)))
			return true
		if index == 61:
			# Retail2f748..2f7bc projects player-minus-owner onto owner forward.
			var player = world.source_player_actor if world != null else null
			var quarter: Array=world.runtime_tables.get("trigonometry",{}).get("quarterSine",[]) if world != null else []
			if not is_instance_valid(player) or quarter.size()!=1025:
				machine.fail("Missing source forward-position player/table")
				return true
			var dx: int=VM.signed32(roundi(player.position.x/world.CELL_METERS*4096.0)-roundi(position.x/world.CELL_METERS*4096.0))
			var dz: int=VM.signed32(roundi(player.position.z/world.CELL_METERS*4096.0)-roundi(position.z/world.CELL_METERS*4096.0))
			var angle: int=-int(source_angles.y)
			var cosine: int=Collision.sine(angle+1024,quarter)
			var sine: int=Collision.sine(angle,quarter)
			stack.append(VM.signed32(VM.signed32(dz*cosine)-VM.signed32(dx*sine))>>12)
			return true
		if index == 57:
			# Retail2f888 reads word74ac0 (CollectKey78/UncollectKey79 latch).
			if world==null:machine.fail("Missing source collected-key latch")
			else:stack.append(VM.signed32(int(world.source_key_collected)<<16))
			return true
		if index == 58:
			if world == null or not world.source_player_entry_state.has("flags"):
				machine.fail("Unknown source arrival flags")
			else:
				stack.append(VM.signed32(int(world.source_player_entry_state.flags)))
			return true
		if index in [37,38,39]:
			if world == null or not world.source_camera_offset_words.has(index):
				machine.fail("Unknown source camera offset word")
			else:
				stack.append(VM.signed32(int(world.source_camera_offset_words[index])))
			return true
		if index == 40:
			if world == null or not world.room_data.has("style"):
				machine.fail("Unknown source current map style")
			else:
				stack.append(VM.signed32((int(world.room_data.style)&65535)<<16))
			return true
		if index in [69,70]:
			var pattern := RegEx.new()
			pattern.compile("^MP([0-9]{3})_([0-9]{2})\\.MAP$")
			var matched = pattern.search(world.map_name) if world != null else null
			if matched == null:
				machine.fail("Unknown source current level/room")
			else:
				stack.append(VM.signed32(int(matched.get_string(1 if index == 69 else 2))<<16))
			return true
		if index == 26:
			stack.append(primary_flags & 8)
			return true
		if index == 34:
			ensure_source_waypoint_chain()
			if source_waypoint_index < 0 or source_waypoint_index >= source_waypoints.size():
				machine.fail("Missing source waypoint link flags")
			else:
				var links: Dictionary = source_waypoint_chain.nodes[source_waypoint_index]
				stack.append((65536 if int(links.next) < 0 else 0) | (131072 if int(links.previous) < 0 else 0))
			return true
		if index in [29,62]:
			if world == null or source_waypoint_index < 0 or source_waypoint_index >= source_waypoints.size():
				machine.fail("Missing source waypoint distance owner")
				return true
			var target: Dictionary = source_waypoint_position(source_waypoints[source_waypoint_index])
			if target.has("fault"):
				machine.fail("Missing source waypoint distance data")
				return true
			var origin := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
			var delta := Vector3i(VM.signed32(target.position.x-origin.x),VM.signed32(target.position.y-origin.y),VM.signed32(target.position.z-origin.z))
			if index == 29:
				var roots: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[])
				if roots.size() != 192:
					machine.fail("Missing source waypoint root table")
				else:
					stack.append(VM.signed32(Collision.player_distance(delta,roots) << 4))
			else:
				var angle := Collision.wall_normal_angle(Vector2i(delta.x,delta.z),world.runtime_tables.get("wallAngles",{}).get("values",[]))
				if angle.has("fault"):
					machine.fail(str(angle.fault))
				else:
					stack.append(VM.signed32((int(angle.angle) & 4095) << 16))
			return true
		if index in [30,31,32,33]:
			if source_waypoint_index < 0 or source_waypoint_index >= source_waypoints.size():
				machine.fail("Missing source current waypoint")
				return true
			var point: Dictionary = source_waypoints[source_waypoint_index]
			if index == 33:
				if not point.has("value"):
					machine.fail("Missing source waypoint value")
				else:
					stack.append(VM.signed32(int(point.value)))
				return true
			if world == null or not world.room_data.has("style"):
				machine.fail("Missing source waypoint room")
				return true
			var table: Array = world.runtime_tables.get("mapYScale",{}).get("values",[])
			var style := int(world.room_data.style)
			if style < 0 or style >= table.size():
				machine.fail("Missing source map Y scale")
				return true
			var coordinate := source_waypoint_position(point)
			if coordinate.has("fault"):
				machine.fail(str(coordinate.fault))
			else:
				stack.append(coordinate.position[index-30])
			return true
		if index == 77:
			stack.append(1)
			return true
		if index == 78:
			# Retail 0x8002fbec returns raw secondary word376 bit0x800.
			stack.append(secondary_flags & 0x800)
			return true
		if index == 0:
			stack.append(VM.signed32(int(source_ground.height_units)))
			return true
		if index == 1:
			stack.append(int(source_ground.get("surface_type",0)) & 255)
			return true
		if index == 22:
			stack.append(VM.signed32((source_wall_angle & 65535) << 16))
			return true
		if index == 23:
			stack.append(VM.signed32((source_movement_status & 65535) << 16))
			return true
		if index == 35:
			# Native2f8f0 returns actor word112: movement wall-height result.
			if source_movement_ground_height == null:
				machine.fail("Unknown source movement ground height")
			else:
				stack.append(VM.signed32(int(source_movement_ground_height)))
			return true
		if index == 27:
			stack.append(source_ceiling_type & 255)
			return true
		if index in [8,10,74] and not source_field_180_valid:
			machine.fail("Unknown source actor field 180")
			return true
		if index in [74,75,76]:
			var raw: int = source_field_180 if index == 74 else source_field_184
			if index != 74:
				raw = ((raw >> (16 if index == 76 else 0)) & 65535)
				if raw >= 32768:
					raw -= 65536
			stack.append(VM.signed32(raw << 4))
			return true
		if index in [8,9,10]:
			stack.append(VM.signed32((source_field_184 if index == 9 else source_field_180) << 4))
			return true
		if index in [51,52,53,54,55,56]:
			if not world.source_pool.slots.has(source_parent_id):
				machine.fail("Missing source parent pose")
				return true
			var parent = world.source_pool.slots[source_parent_id].node
			if parent == null or not is_instance_valid(parent) or not parent.has_method("refresh_source_render_pose"):
				machine.fail("Unimplemented source parent pose owner")
				return true
			if index <= 53:
				stack.append(VM.signed32(roundi(parent.position[index - 51] / world.CELL_METERS * 4096.0)))
			else:
				stack.append(VM.signed32((parent.source_angles[index - 54] & 4095) << 16))
			return true
		if index in [5,6,7]:
			stack.append(VM.signed32((source_angles[index - 5] & 4095) << 16))
			return true
		if index in [2,3,4]:
			stack.append(VM.signed32(roundi(position[index - 2] / world.CELL_METERS * 4096.0)))
			return true
		if index == 47:
			stack.append(int((secondary_flags & 512) != 0))
			return true
		if index == 28:
			if not source_player_distance_valid:
				machine.fail("Missing source cached player-distance update")
				return true
			stack.append(VM.signed32(source_player_distance << 4))
			return true
	return false

func asl_increment_parent_parameter(index: int, amount: int) -> bool:
	if world == null or index < 0 or index >= 8:
		return false
	var state: Dictionary = world.source_parent_parameters(source_parent_id)
	if state.is_empty():
		return false
	while state.parameters.size() <= index:
		state.parameters.append(0)
	state.parameters[index] = VM.signed32(int(state.parameters[index])+amount)
	return true

func asl_increment_extended_global(index: int, amount: int) -> bool:
	if world == null or not world.source_extended_globals.has(index):
		return false
	world.source_extended_globals[index] = VM.signed32(int(world.source_extended_globals[index])+amount)
	return true

func asl_command(instruction: Dictionary, machine: RefCounted) -> String:
	var args: Array = instruction.args
	match int(instruction.op):
		177:
			if world == null or int(args[0]) < 2 or int(args[0]) > 10: return "unsupported"
			var origin_index: int = machine.evaluate(args[2]) >> 16
			var params := []
			for index in range(3,args.size()): params.append(machine.evaluate(args[index]))
			if machine.status == "unsupported": return "unsupported"
			while params.size() < 8: params.append(0)
			var scratch: Dictionary = world.source_spawn_scratch.pose()
			if scratch.has("fault"): machine.fail(str(scratch.fault));return "unsupported"
			var point := preload("res://source_spawn_from.gd").point(source_render_matrix,source_render_position,source_scale,model_data.get("models",[]),clip,clip_frame,origin_index)
			if point.has("fault"): machine.fail(str(point.fault));return "unsupported"
			# Native2a238/2a260 keeps owner/waypoints, uses independent pose and flags2.
			if world.source_pool.free_slots.is_empty(): return "continue"
			var child = world.spawn_source_actor(self,str(args[1]),params,{"position":point.position,"angles":scratch.angles,"retain_parent":true,"retain_waypoints":true,"refresh_references":true})
			return "continue" if child != null else "unsupported"
		96,197:
			var level: int = int(world.map_name.substr(2,3)) if world != null else 0
			var room: int
			if int(instruction.op) == 96:
				level = machine.evaluate(args[0]) >> 16
				room = machine.evaluate(args[1]) >> 16
			else:
				room = (machine.evaluate(args[0])&0xffffffff) >> 16
			if world == null or machine.status == "unsupported": return "unsupported"
			return "continue" if world.request_source_script_room(level,room,int(instruction.op) == 197) else "unsupported"
		204,205:
			# Native2c1d8/2c210 stores three independent display control words.
			if world == null: return "unsupported"
			world.source_gobbo_display_state.timer = 390 if int(instruction.op) == 204 else 600
			world.source_gobbo_display_state.mode = 0 if int(instruction.op) == 204 else -1
			if int(instruction.op) == 204: world.source_gobbo_display_state.cursor = -1
			return "continue"
		165:
			# Native4a828: eight independent DeathFX, source sound, counter/flags.
			if world == null: return "unsupported"
			var sound: Dictionary = {}
			for asset in world.manifest.get("linkage",{}).get("bootstrap",[]):
				if int(asset.kind) == 3 and asset.name == "DEATHFX": sound = asset;break
			if sound.is_empty(): return "unsupported"
			var origin := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
			for index in range(8):
				var angles := Vector3i(source_angles.x,(source_angles.y+index*512)&65535,source_angles.z)
				# Original ignores factory allocation failure and the sound result.
				world.spawn_source_actor(self,"DeathFX",[],{"position":origin,"angles":angles,"retain_parent":true})
			world.play_imported_sound(sound,global_position,40,0)
			# Actor340 is parameter0, also visible to script/parent parameter reads.
			while machine.parameters.size() < 8: machine.parameters.append(0)
			machine.parameters[0] = 0
			primary_flags = VM.signed32(primary_flags|0x80040)
			return "continue"
		166:
			# Native4a944: retry same command eight times, Y+=20 source units.
			var counter: int = int(machine.parameters[0]) if not machine.parameters.is_empty() else 0
			if (counter&0xffffffff) < 8:
				if world == null: return "unsupported"
				while machine.parameters.size() < 8: machine.parameters.append(0)
				machine.parameters[0] = VM.signed32(counter+1)
				var y := VM.signed32(roundi(position.y/world.CELL_METERS*4096.0)+20)
				position.y = float(y)*world.CELL_METERS/4096.0
				machine.pc = int(instruction.pc)
			return "continue"
		77:
			# Native2897c: raw expression words, caller yaw, low-word products.
			var offset := Vector3i.ZERO
			for axis in range(3): offset[axis] = machine.evaluate(args[axis])
			if world == null or machine.status == "unsupported": return "unsupported"
			var player = world.source_player_actor
			var pairs: Array = world.runtime_tables.get("rotation",{}).get("pairs",[])
			if player == null or not is_instance_valid(player) or pairs.size() != 4096: return "unsupported"
			var trig := Rotation.trig(source_angles.y&65535,pairs)
			var dx := VM.signed32(VM.signed32(offset.z*trig.x)+VM.signed32(offset.x*trig.y)) >> 12
			var dz := VM.signed32(VM.signed32(offset.z*trig.y)-VM.signed32(offset.x*trig.x)) >> 12
			var origin := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
			player.position = Vector3(Vector3i(VM.signed32(origin.x+dx),VM.signed32(origin.y+offset.y),VM.signed32(origin.z+dz)))*world.CELL_METERS/4096.0
			return "continue"
		14:
			# Retail27e14 consumes its string into a temporary buffer, then returns.
			return "continue"
		99,100,124:
			# Retail430a4/430b8/430cc only advance PC; no movement side effect.
			return "continue"
		138,144:
			# Native296f0 feeds evaluated position words directly to38ffc.
			var target_position := Vector3i.ZERO
			for axis in range(3): target_position[axis] = machine.evaluate(args[axis])
			var step: int = machine.evaluate(args[3]) >> 16
			var pitch_step := 0
			if int(instruction.op) == 138: pitch_step = machine.evaluate(args[4]) >> 16
			if world == null or machine.status == "unsupported": return "unsupported"
			var delta := Vector2i(VM.signed32(target_position.x-roundi(position.x/world.CELL_METERS*4096.0)),VM.signed32(target_position.z-roundi(position.z/world.CELL_METERS*4096.0)))
			var target := Collision.wall_normal_angle(delta,world.runtime_tables.get("wallAngles",{}).get("values",[]))
			if target.has("fault"): return "unsupported"
			source_angles.y = Rotation.approach_angle(source_angles.y,int(target.angle)&4095,step)
			if int(instruction.op) == 138:
				# Native2980c uses3905c and the fifth expression as pitch rate.
				var roots: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[])
				if roots.size() != 192: return "unsupported"
				var dy := VM.signed32(target_position.y-roundi(position.y/world.CELL_METERS*4096.0))
				var horizontal := Collision.distance_root(Collision.square_ir(delta.x)+Collision.square_ir(delta.y),roots)
				var pitch := Collision.wall_normal_angle(Vector2i(dy,horizontal),world.runtime_tables.get("wallAngles",{}).get("values",[]))
				if pitch.has("fault"): return "unsupported"
				source_angles.x = Rotation.approach_angle(source_angles.x,(4096-int(pitch.angle))&4095,pitch_step)
			source_rotation_y = source_angles.y
			rotation = Vector3(source_angles)*TAU/4096.0
			return "continue"
		199:
			# Native2b2c8 calls BIOS srand with frame word80075170.
			if world == null: return "unsupported"
			world.source_random.bios_seed = int(world.source_frame_clock.counter) & 0xffffffff
			return "continue"
		163,164,171,172:
			# Native2c358/2c37c and2c3ec/2c410 only toggle actor word376.
			var mask := 0x1000 if int(instruction.op) in [163,164] else 1
			secondary_flags = VM.signed32(secondary_flags | mask) if int(instruction.op) in [163,171] else VM.signed32(secondary_flags & ~mask)
			return "continue"
		78,79:
			# Native446e8..44720 writes a boolean latch, not a key counter.
			if world == null: return "unsupported"
			world.source_key_collected = 1 if int(instruction.op) == 78 else 0
			return "continue"
		187:
			# Native2c1ac..2c1d4 decrements gp+140 only when nonzero.
			if world == null: return "unsupported"
			var gobbos := int(world.source_pickup_counts[2])
			if gobbos != 0: world.source_pickup_counts[2] = VM.signed32(gobbos-1)
			return "continue"
		185:
			# This executable's2bd48 evaluates the argument and returns; no rumble
			# or camera-shake side effect is present in the supported revision.
			machine.evaluate(args[0])
			return "unsupported" if machine.status == "unsupported" else "continue"
		153:
			var angle: int = machine.evaluate(args[0])
			if machine.status == "unsupported" or world == null: return "unsupported"
			var applied: bool = world.accelerate_source_player_angle(angle>>16)
			return "continue" if applied else "unsupported"
		149:
			if world == null: return "unsupported"
			var count: int = machine.evaluate(args[0])
			if machine.status == "unsupported": return "unsupported"
			world.source_camera_hold_counter = count>>16
			return "continue"
		182,207:
			if world == null: return "unsupported"
			if int(instruction.op) == 207 and not world.initialize_source_stage_stats(): return "unsupported"
			return "continue" if world.request_source_next_level() else "unsupported"
		198:
			if world == null or not world.initialize_source_stage_stats():
				return "unsupported"
			return "continue"
		168,169:
			if world == null:
				return "unsupported"
			world.source_input_suppression_count = VM.signed32(world.source_input_suppression_count+(1 if int(instruction.op) == 168 else -1))
			return "continue"
		179:
			if world == null:
				return "unsupported"
			world.source_pickup_counts[1] = VM.signed32(int(world.source_pickup_counts[1])-1)
			return "continue"
		180:
			var index: int = machine.evaluate(args[0])>>16
			if world == null or machine.status == "unsupported":
				return "unsupported"
			if index >= 0 and index < 8:
				world.source_stage_pickup_slots[index] = 1
			return "continue" # Source prints for invalid index, with no slot mutation.
		159:
			if world == null:
				return "unsupported"
			world.record_source_stage_result()
			world.source_transition_state = 4
			return "continue"
		186:
			# PlayerNoStood at0x80027410 clears only registered-player secondary bit1.
			var player = world.source_player_actor if world != null else null
			if player == null or not is_instance_valid(player):
				return "unsupported"
			player.secondary_flags &= ~2
			return "continue"
		71:
			var requested: int = machine.evaluate(args[0])
			if world == null or machine.status == "unsupported":
				return "unsupported"
			# The VR spectator camera deliberately stays steady during impacts.
			# Consume the source request so its actor can spawn the impact effects.
			world.source_camera_state["wobble_request"] = {"value":requested,"renderer":"suppressed_for_vr_comfort"}
			return "continue"
		160:
			if world == null:
				return "unsupported"
			world.source_player_movement_state = preload("res://source_player_movement.gd").stop_dead(world.source_player_movement_state)
			return "continue"
		154:
			var angle: int = machine.evaluate(args[0])>>16
			if world == null or machine.status == "unsupported":
				return "unsupported"
			var player = world.source_player_actor
			if player == null or (int(player.secondary_flags)&0x1000) != 0:
				return "continue"
			var quarter: Array = world.runtime_tables.get("trigonometry",{}).get("quarterSine",[])
			if quarter.size() != 1025:
				return "unsupported"
			var motion: Vector2i = world.source_player_movement_state.motion
			motion.x = VM.signed32(VM.signed32(Collision.sine(angle,quarter)*35)+motion.x-(motion.x>>2))
			motion.y = VM.signed32(VM.signed32(Collision.sine(angle+1024,quarter)*35)+motion.y-(motion.y>>2))
			var position_units := Vector3i(roundi(player.position.x/world.CELL_METERS*4096.0),roundi(player.position.y/world.CELL_METERS*4096.0),roundi(player.position.z/world.CELL_METERS*4096.0))
			var result: Dictionary = preload("res://source_player_movement.gd").final_position(position_units,motion,world.runtime_tables.get("distanceRoot",{}).get("values",[]))
			if result.has("fault"):
				return "unsupported"
			world.source_player_movement_state.motion = motion
			world.source_player_movement_state.magnitude = result.magnitude
			player.position = Vector3(result.position)*world.CELL_METERS/4096.0
			return "continue"
		255:
			# Source0x80042e08 skips the debug byte, evaluates, then discards the value.
			machine.evaluate(args[1])
			return "continue" if machine.status != "unsupported" else "unsupported"
		178:
			var index := int(args[0])&65535
			var value: int = machine.evaluate(args[1])
			if machine.status == "unsupported" or world == null or index >= 8:
				return "unsupported"
			var state: Dictionary = world.source_parent_parameters(source_parent_id)
			if state.is_empty():
				return "unsupported"
			while state.parameters.size() <= index:
				state.parameters.append(0)
			state.parameters[index] = VM.signed32(value)
			return "continue"
		183,208:
			if world == null:
				return "unsupported"
			world.source_camera_override_one = self if int(instruction.op) == 183 else null
			return "continue"
		203:
			if world == null:
				return "unsupported"
			primary_flags = VM.signed32(primary_flags|0x800)
			secondary_flags &= ~2
			source_ground.height_units = 0
			if not run_source_collision_response():
				return "unsupported"
			world.source_player_actor = self
			world.source_player_id = source_pool_id
			return "continue"
		123:
			return "continue" if world != null and world.lose_source_pickups() else "unsupported"
		6,7,64,196:
			var player_target := int(instruction.op) == 196
			var reference_index := int(args[0])&65535 if not player_target else -1
			var step: int = machine.evaluate(args[0 if player_target else 1]) >> 16
			var pitch_step := step
			if int(instruction.op) in [64,196]: pitch_step = machine.evaluate(args[1 if player_target else 2]) >> 16
			if world == null or machine.status == "unsupported":
				return "unsupported"
			if not player_target and not source_references_registered and not source_reference_slots.has(reference_index):
				var actor_references: Array = machine.program.get("references",[]).filter(func(item): return int(item.kind) == 0)
				if reference_index >= actor_references.size():
					return "unsupported"
				for candidate in world.source_actors:
					if candidate.source_name == str(actor_references[reference_index].name):
						source_reference_slots[reference_index] = candidate.source_pool_id
			if not player_target and (not source_reference_slots.has(reference_index) or not world.source_pool.slots.has(source_reference_slots[reference_index])):
				return "unsupported"
			var target_actor = world.source_player_actor if player_target else world.source_pool.slots[source_reference_slots[reference_index]].node
			if target_actor == null or not is_instance_valid(target_actor):
				return "unsupported"
			var delta := Vector3i(VM.signed32(roundi(target_actor.position.x/world.CELL_METERS*4096.0)-roundi(position.x/world.CELL_METERS*4096.0)),VM.signed32(roundi(target_actor.position.y/world.CELL_METERS*4096.0)-roundi(position.y/world.CELL_METERS*4096.0)),VM.signed32(roundi(target_actor.position.z/world.CELL_METERS*4096.0)-roundi(position.z/world.CELL_METERS*4096.0)))
			var angular_delta := Vector2i(delta.x,delta.z)
			if int(instruction.op) in [64,196]:
				# Native2904c/29414: first rate controls yaw, second controls pitch.
				var roots: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[])
				var angles: Array = world.runtime_tables.get("wallAngles",{}).get("values",[])
				if roots.size() != 192: return "unsupported"
				var horizontal := Collision.distance_root(Collision.square_ir(delta.x)+Collision.square_ir(delta.z),roots)
				var yaw := Collision.wall_normal_angle(angular_delta,angles)
				var pitch := Collision.wall_normal_angle(Vector2i(delta.y,horizontal),angles)
				if yaw.has("fault") or pitch.has("fault"): return "unsupported"
				source_angles.y = Rotation.approach_angle(source_angles.y,int(yaw.angle)&4095,step)
				source_angles.x = Rotation.approach_angle(source_angles.x,(4096-int(pitch.angle))&4095,pitch_step)
				source_rotation_y = source_angles.y
				rotation = Vector3(source_angles)*TAU/4096.0
				return "continue"
			if int(instruction.op) == 6:
				# Native28e14/3905c: SQR(sf1), source root, then negated pitch.
				var roots: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[])
				if roots.size() != 192: return "unsupported"
				var horizontal := Collision.distance_root(Collision.square_ir(delta.x)+Collision.square_ir(delta.z),roots)
				angular_delta = Vector2i(delta.y,horizontal)
			var target := Collision.wall_normal_angle(angular_delta,world.runtime_tables.get("wallAngles",{}).get("values",[]))
			if target.has("fault"):
				return "unsupported"
			var axis := 0 if int(instruction.op) == 6 else 1
			var angle := (4096-int(target.angle))&4095 if axis == 0 else int(target.angle)&4095
			source_angles[axis] = Rotation.approach_angle(source_angles[axis],angle,step)
			source_rotation_y = source_angles.y
			rotation = Vector3(source_angles)*TAU/4096.0
			return "continue"
		111:
			source_blink_counter = 0
			return "continue"
		195:
			var step: int = machine.evaluate(args[0]) >> 16
			if machine.status == "unsupported" or world == null:
				return "unsupported"
			var player = world.source_player_actor if is_instance_valid(world.source_player_actor) else world.actor
			if player == null:
				return "unsupported"
			var delta := Vector2i(VM.signed32(roundi(player.position.x/world.CELL_METERS*4096.0)-roundi(position.x/world.CELL_METERS*4096.0)),VM.signed32(roundi(player.position.z/world.CELL_METERS*4096.0)-roundi(position.z/world.CELL_METERS*4096.0)))
			var target := Collision.wall_normal_angle(delta,world.runtime_tables.get("wallAngles",{}).get("values",[]))
			if target.has("fault"):
				return "unsupported"
			source_angles.y = Rotation.approach_angle(source_angles.y,int(target.angle) & 4095,step)
			source_rotation_y = source_angles.y
			rotation = Vector3(source_angles)*TAU/4096.0
			return "continue"
		104:
			var mode := int(args[0])
			if mode < 0 or mode > 3:
				return "unsupported"
			var ready := (primary_flags & 8) == 0 if mode == 0 else (primary_flags & 0x400000) != 0 if mode == 1 else (primary_flags & 0x20000000) != 0 if mode == 2 else (secondary_flags & 0x200) != 0
			if not ready:
				primary_flags |= 2
				machine.pc = int(instruction.pc)
				return "yield"
			return "continue"
		147:
			var sample: int = machine.evaluate(args[0]) >> 16
			var voice: int = machine.evaluate(args[1])
			if machine.status == "unsupported" or world == null or sample <= 0 or sample >= handles.size():
				return "unsupported"
			return "continue" if world.update_imported_loop_sound(handles[sample],voice,global_position) else "unsupported"
		161:
			var voice: int = machine.evaluate(args[0])
			var delta: int = machine.evaluate(args[1]) >> 16
			if machine.status == "unsupported" or world == null:
				return "unsupported"
			return "continue" if world.shift_imported_sound_pitch(voice,delta) else "unsupported"
		10:
			var voice: int = machine.evaluate(args[0])
			if machine.status == "unsupported" or world == null:
				return "unsupported"
			return "continue" if world.stop_imported_sound_voice(voice) else "unsupported"
		60,112:
			var count := int(args[0])
			if count < 0 or count > 3 or args.size() != count+1:
				return "unsupported"
			source_blink_parts.clear()
			for index in range(count):
				source_blink_parts.append(Rotation.halfword(int(args[index+1])))
			if int(instruction.op) == 60:
				source_blink_counter = 0
				primary_flags |= 0x100
			else:
				source_blink_counter = 2
			return "continue"
		91,137:
			var yaw_step: int = machine.evaluate(args[0]) >> 16
			var pitch_step: int = machine.evaluate(args[1]) >> 16 if int(instruction.op) == 137 else 0
			if machine.status == "unsupported" or world == null or source_waypoint_index < 0 or source_waypoint_index >= source_waypoints.size():
				return "unsupported"
			var target: Dictionary = source_waypoint_position(source_waypoints[source_waypoint_index])
			var roots: Array = world.runtime_tables.get("distanceRoot",{}).get("values",[])
			var table: Array = world.runtime_tables.get("wallAngles",{}).get("values",[])
			if target.has("fault") or (int(instruction.op) == 137 and roots.size() != 192):
				return "unsupported"
			var origin := Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
			var delta := Vector3i(VM.signed32(target.position.x-origin.x),VM.signed32(target.position.y-origin.y),VM.signed32(target.position.z-origin.z))
			var yaw_target := Collision.wall_normal_angle(Vector2i(delta.x,delta.z),table)
			if yaw_target.has("fault"):
				return "unsupported"
			source_angles.y = Rotation.approach_angle(source_angles.y,int(yaw_target.angle) & 4095,yaw_step)
			if int(instruction.op) == 137:
				var horizontal := Collision.player_distance(Vector3i(delta.x,0,delta.z),roots)
				var pitch_target := Collision.wall_normal_angle(Vector2i(delta.y,horizontal),table)
				if pitch_target.has("fault"):
					return "unsupported"
				source_angles.x = Rotation.approach_angle(source_angles.x,4096-(int(pitch_target.angle) & 4095),pitch_step)
			source_rotation_y = source_angles.y
			rotation = Vector3(source_angles)*TAU/4096.0
			return "continue"
		86:
			if world == null:
				return "unsupported"
			source_saved_position = Vector3i(roundi(position.x/world.CELL_METERS*4096.0),roundi(position.y/world.CELL_METERS*4096.0),roundi(position.z/world.CELL_METERS*4096.0))
			source_saved_angles = Vector3i(Rotation.halfword(source_angles.x),Rotation.halfword(source_angles.y),Rotation.halfword(source_angles.z))
			source_saved_pose_padding = source_pose_padding.duplicate(true)
			source_saved_pose_valid = true
			return "continue"
		87:
			return "continue" if initialize_source_player() else "unsupported"
		72:
			return "continue" if world != null and world.reset_source_camera(self) else "unsupported"
		191:
			return "continue" if world != null and world.move_source_player(self) else "unsupported"
		106,107:
			primary_flags = VM.signed32(primary_flags|0x200000) if int(instruction.op) == 106 else VM.signed32(primary_flags&~0x200000)
			return "continue"
		69,70:
			primary_flags = VM.signed32(primary_flags|0x10000000) if int(instruction.op) == 69 else VM.signed32(primary_flags&~0x10000000)
			return "continue"
		85:
			primary_flags &= ~0x40
			return "continue"
		84:
			primary_flags |= 0x40
			return "continue"
		181:
			if world == null:
				return "unsupported"
			world.source_bonus_mask = VM.signed32(int(world.source_bonus_mask)|(1<<(int(args[0])&31)))
			return "continue"
		189,200,201:
			if world == null:
				return "unsupported"
			world.source_bonus_display_timer = 60 if int(instruction.op) == 189 else -1 if int(instruction.op) == 200 else 0
			world.source_hud_bonus_revision += 1
			return "continue"
		122:
			var kind: int = machine.evaluate(args[0])>>16
			if world == null or machine.status == "unsupported":
				return "unsupported"
			world.add_source_pickup(kind)
			return "continue"
		156:
			return "continue" if world != null and world.remove_source_map_entity(self) else "unsupported"
		175:
			# Native273d8 marks map-entity word20 mask4, with null pointer no-op.
			return "continue" if world != null and world.remove_source_map_entity(self,4) else "unsupported"
		162:
			# Native27368..2739c marks the source entity activated (word20 bit2).
			return "continue" if world != null and world.remove_source_map_entity(self,2) else "unsupported"
		206:
			# Native273a0..273d4 clears only word20 bit2; null entity is a no-op.
			return "continue" if world != null and world.remove_source_map_entity(self,2,true) else "unsupported"
		157:
			return "continue" if initialize_source_crystal() else "unsupported"
		170:
			return "continue" if world != null and world.request_source_death() else "unsupported"
		158:
			if world == null or machine.parameters.size() < 3:
				return "unsupported"
			var timer := int(machine.parameters[2])
			if timer == 0:
				world.spawn_source_actor(self,"CrystalSpark",[0,0,0,0])
				timer = (world.source_random.bios_rand()&511)+120
			else:
				timer = VM.signed32(timer-1)
			machine.parameters[2] = timer
			var phase := int(machine.parameters[1])
			var y := roundi(position.y/world.CELL_METERS*4096.0)
			position.y = VM.signed32(y+(12 if (phase&0xffffffff) < 10 else -12))*world.CELL_METERS/4096.0
			phase = VM.signed32(phase+1)
			machine.parameters[1] = 0 if phase == 20 else phase
			var collected_now := (primary_flags&0x100000) != 0
			if collected_now:
				world.source_pickup_counts[1] = VM.signed32(int(world.source_pickup_counts[1])+1)
				world.source_pickup_display_timer = 0
				if not world.remove_source_map_entity(self,4) or not world.play_named_sound("CRYS",global_position,72):
					return "unsupported"
				machine.parameters[1] = 0
				primary_flags = VM.signed32(primary_flags&~0x8000)
			else:
				machine.pc = int(instruction.pc)
			primary_flags |= 2
			return "yield"
		167:
			if machine.parameters.size() < 2:
				return "unsupported"
			var phase := VM.signed32(int(machine.parameters[1])+512)
			machine.parameters[1] = phase
			var size := Rotation.halfword(4096-(phase&65535))
			source_scale = Vector3i(size,size,size)
			scale = Vector3(source_scale)/4096.0
			source_shadow_size = VM.signed32(size<<4)
			if (phase&0xffffffff) < 4096:
				machine.pc = int(instruction.pc)
			primary_flags |= 2
			return "yield"
		128,129:
			primary_flags = VM.signed32(primary_flags|0x80000000) if int(instruction.op) == 128 else VM.signed32(primary_flags&0x7fffffff)
			return "continue"
		50:
			if (int(args[0])&65535) != 65535 or machine.frames.is_empty() or machine.frames.back().kind != "trigger":
				return "unsupported"
			var index := int(machine.frames.back().index)
			if index < 0 or index >= event_triggers.size():
				return "unsupported"
			event_triggers[index].mode = 255
			return "continue"
		192:
			return "continue" if world != null and world.turn_source_player(self) else "unsupported"
		95,102:
			var height: int = machine.evaluate(args[0])
			if machine.status == "unsupported" or world == null:
				return "unsupported"
			if int(instruction.op) == 95:
				world.source_camera_height_units = height >> 4
			else:
				world.source_camera_distance_units = height >> 4
				world.source_camera_distance_copy_units = height >> 4
			return "continue"
		94:
			var index := int(args[0])
			var value: int = machine.evaluate(args[1])
			if machine.status == "unsupported" or world == null or index < 0 or index >= 256:
				return "unsupported"
			# Source 0x8002a980 writes the shared word bank at 0x80086240.
			world.source_extended_globals[index] = VM.signed32(value)
			return "continue"
		29:
			if world == null or not source_saved_pose_valid:
				return "unsupported"
			position = Vector3(source_saved_position)*world.CELL_METERS/4096.0
			source_angles = source_saved_angles
			source_pose_padding = source_saved_pose_padding.duplicate(true)
			source_rotation_y = source_angles.y
			rotation = Vector3(source_angles)*TAU/4096.0
			return "continue"
		135,136:
			ensure_source_waypoint_chain()
			if source_waypoints.is_empty() or source_waypoint_index < 0 or source_waypoint_index >= source_waypoints.size():
				return "unsupported"
			var links: Dictionary = source_waypoint_chain.nodes[source_waypoint_index]
			var adjacent := int(links.next if int(instruction.op) == 135 else links.previous)
			source_waypoint_index = adjacent if adjacent >= 0 else int(source_waypoint_chain.head if int(instruction.op) == 135 else source_waypoint_chain.tail)
			return "continue"
		173:
			ensure_source_waypoint_chain()
			# Retail 0x8002b898 copies the head pointer even when it is null.
			source_waypoint_index = int(source_waypoint_chain.get("head",-1))
			return "continue"
		141:
			ensure_source_waypoint_chain()
			var removed: Dictionary = preload("res://source_waypoint_chain.gd").delete_current(source_waypoint_chain,source_waypoint_index)
			if removed.has("fault"):
				machine.fail(str(removed.fault))
				return "unsupported"
			source_waypoint_index = int(removed.current)
			return "continue"
		88,89:
			if (primary_flags & (0x200 if int(instruction.op) == 88 else 0x400)) == 0:
				machine.pc = int(args[0])
			return "continue"
		34:
			var value: int = machine.evaluate(args[0])
			if machine.status == "unsupported":
				return "unsupported"
			source_rise_remaining = value >> 16
			source_vertical_speed = 261
			primary_flags = VM.signed32((primary_flags & ~0x400) | 0x200)
			secondary_flags &= ~2
			return "continue"
		35,76,115,118:
			var op := int(instruction.op)
			if op == 35:
				if (primary_flags & 0x400) == 0:
					source_vertical_speed = 0
			elif op == 115:
				source_vertical_speed = 384
			primary_flags = VM.signed32((primary_flags & ~0x200) | 0x400) if op in [35,115] else VM.signed32(primary_flags & ~0x600)
			secondary_flags = secondary_flags | 2 if op == 76 else secondary_flags & ~2
			return "continue"
		113,114:
			primary_flags = VM.signed32(primary_flags | 0x2000000) if int(instruction.op) == 113 else VM.signed32(primary_flags & ~0x2000000)
			return "continue"
		56:
			var index := int(args[0])
			if index not in [2,3,4,5,6,7,8,9,10,15,16,17,18,19,20,30,31,32,33,37,38,39,68,74,75,76]:
				return "unsupported"
			var value: int = machine.evaluate(args[1])
			if machine.status == "unsupported":
				return "unsupported"
			if index in [15,16,17,18,19,20]:
				# Retail2ac4c..2aca8 targets the registered player at gp+1812.
				var player = world.source_player_actor if world != null else null
				if player == null or not is_instance_valid(player):return "unsupported"
				if index <= 17:
					player.position[index-15]=VM.signed32(value)*world.CELL_METERS/4096.0
				else:
					player.source_angles[index-18]=(value>>16)&4095
					player.source_rotation_y=player.source_angles.y
					player.rotation=Vector3(player.source_angles)*TAU/4096.0
				return "continue"
			if index == 68:
				if world == null:
					return "unsupported"
				world.source_level_script_state = value>>16
				return "continue"
			if index in [30,31,32,33]:
				if source_waypoint_index < 0 or source_waypoint_index >= source_waypoints.size():
					return "unsupported"
				var point: Dictionary = source_waypoints[source_waypoint_index]
				if index == 33:
					point["value"] = VM.signed32(value)
				else:
					var pose := source_waypoint_position(point)
					if pose.has("fault"):
						return "unsupported"
					var units: Vector3i = pose.position
					units[index-30] = VM.signed32(value)
					point["runtime_position"] = units
				return "continue"
			if index in [37,38,39]:
				if world == null:
					return "unsupported"
				world.source_camera_offset_words[index] = VM.signed32(value)
				if world.source_camera_state.has("offset"):
					world.source_camera_state.offset[index-37] = VM.signed32(value)
				return "continue"
			if index in [2,3,4]:
				position[index - 2] = VM.signed32(value) * world.CELL_METERS / 4096.0
			elif index <= 7:
				source_angles[index - 5] = (value >> 16) & 4095
				source_rotation_y = source_angles.y
				rotation = Vector3(source_angles) * TAU / 4096.0
			elif index >= 74:
				var raw: int = value >> 4
				if index == 74:
					source_field_180 = raw
					source_field_180_valid = true
				elif index == 75:
					source_field_184 = VM.signed32((source_field_184 & 0xffff0000) | (raw & 65535))
				else:
					source_field_184 = VM.signed32((source_field_184 & 65535) | ((raw & 65535) << 16))
				secondary_flags |= 0x400
			else:
				if index == 9:
					source_field_184 = value >> 4
				else:
					source_field_180 = value >> 4
					source_field_180_valid = true
				secondary_flags |= 4 if index == 8 else 8
			return "continue"
		38,40,143:
			var distance: int = machine.evaluate(args[0]) >> 4
			if machine.status == "unsupported":
				return "unsupported"
			var quarter: Array = world.runtime_tables.get("trigonometry",{}).get("quarterSine",[])
			if quarter.size() != 1025:
				return "unsupported"
			var angle := (source_rotation_y + 1024) & 4095
			if int(instruction.op) == 143:
				angle = machine.evaluate(args[1]) >> 16
				if machine.status == "unsupported":
					return "unsupported"
			var x_delta := VM.signed32(distance * Collision.sine(angle,quarter)) >> 12
			var z_delta := VM.signed32(distance * Collision.sine(angle + 1024,quarter)) >> 12
			var direction := -1 if int(instruction.op) == 38 else 1
			position.x = VM.signed32(roundi(position.x / world.CELL_METERS * 4096.0) + direction * x_delta) * world.CELL_METERS / 4096.0
			position.z = VM.signed32(roundi(position.z / world.CELL_METERS * 4096.0) + direction * z_delta) * world.CELL_METERS / 4096.0
			return "continue"
		42,43:
			var amount: int = machine.evaluate(args[0]) >> 16
			if machine.status == "unsupported":
				return "unsupported"
			source_rotation_y = (source_rotation_y + (-amount if int(instruction.op) == 42 else amount)) & 4095
			source_angles.y = source_rotation_y
			rotation = Vector3(source_angles) * TAU / 4096.0
			return "continue"
		44,45,46,47:
			var amount: int = machine.evaluate(args[0])>>16
			if machine.status == "unsupported":
				return "unsupported"
			var axis := 0 if int(instruction.op) in [44,45] else 2
			source_angles[axis] = (int(source_angles[axis])+(-amount if int(instruction.op) in [44,47] else amount))&4095
			rotation = Vector3(source_angles)*TAU/4096.0
			return "continue"
		73:
			var value: int = machine.evaluate(args[0])
			if machine.status == "unsupported":
				return "unsupported"
			source_shadow_size = VM.signed32(value)
			return "continue"
		74:
			# Native2c2f0..2c308 copies the unsigned command byte to actor984.
			source_shadow_type = int(args[0])&255
			return "continue"
		55:
			# Native2a8c0..2a908 writes the evaluated word into parent's global bank.
			var index := int(args[0])&65535
			var value: int = machine.evaluate(args[1])
			if world != null and world.has_method("source_parent_global_bank") and machine.status != "unsupported":
				var retained: Dictionary=world.source_parent_global_bank(source_parent_id)
				if not retained.has("bank"):return "unsupported"
				retained.bank[index]=VM.signed32(value)
				return "continue"
			if machine.status == "unsupported" or world == null or not world.source_pool.slots.has(source_parent_id): return "unsupported"
			var parent = world.source_pool.slots[source_parent_id].get("node",null)
			if not is_instance_valid(parent): return "unsupported"
			parent.vm.globals[index] = VM.signed32(value)
			return "continue"
		36,37,145,146:
			# These native handlers have frame88; their evaluator's register saves
			# overlap the words later reused by SpawnFrom (dispatcher2cc1c/2cc20).
			if world != null:
				world.source_spawn_scratch.evaluator_frame(88,0x20000000,0x04000000)
			var distance: int = machine.evaluate(args[0]) >> 4
			if machine.status == "unsupported":
				return "unsupported"
			if world == null: return "unsupported"
			var moving_actor = world.source_player_actor if int(instruction.op) in [145,146] else self
			if moving_actor == null or not is_instance_valid(moving_actor): return "unsupported"
			# Native2883c moves the registered player using its full pose matrix.
			var matrix := Rotation.matrix(moving_actor.source_angles,world.runtime_tables.get("rotation",{}).get("pairs",[]))
			if matrix.is_empty():
				return "unsupported"
			var delta := Rotation.transform_long(matrix,Vector3i(0,0,distance))
			var direction := -1 if int(instruction.op) in [36,146] else 1
			var units := Vector3i(roundi(moving_actor.position.x / world.CELL_METERS * 4096.0),roundi(moving_actor.position.y / world.CELL_METERS * 4096.0),roundi(moving_actor.position.z / world.CELL_METERS * 4096.0))
			for i in range(3):
				units[i] = VM.signed32(units[i] + direction * delta.position[i])
			moving_actor.position = Vector3(units) * world.CELL_METERS / 4096.0
			return "continue"
		48,119:
			if int(args[0]) > 9:
				return "unsupported"
			var params: Array = []
			for i in range(2,args.size()):
				params.append(machine.evaluate(args[i]))
			if machine.status == "unsupported":
				return "unsupported"
			while params.size() < 8:
				params.append(0)
			return "continue" if world.spawn_source_actor(self,str(args[1]),params,{},int(instruction.op) == 119) != null else "unsupported"
		53,253:
			if int(instruction.op) == 253:
				# Native2a86c emits a diagnostic, leaves PC and sets removal bits6.
				print("SOURCE_SCRIPT_TRAP: ",JSON.stringify({"actor":source_name,"pc":int(instruction.pc),"op":253}))
			primary_flags |= 6
			machine.pc = int(instruction.pc)
			return "yield"
		82:
			var mask: int = machine.evaluate(args[0])
			if machine.status == "unsupported":
				return "unsupported"
			var next_flags := VM.signed32(primary_flags | mask)
			if world == null and (next_flags & 0x40000) == 0 and (next_flags & 0x8000) != 0:
				return "unsupported"
			primary_flags = next_flags
			secondary_flags &= ~64
			# 0x800271d0..0x800271e8 skips immediate response only for 0x40000.
			if (primary_flags & 0x40000) == 0 and not run_source_collision_response():
				return "unsupported"
			return "continue"
		83:
			var mask: int = machine.evaluate(args[0])
			if machine.status == "unsupported":
				return "unsupported"
			primary_flags = VM.signed32(primary_flags & ~mask)
			return "continue"
		105,125:
			primary_flags = VM.signed32(primary_flags & ~0x40000000) if int(instruction.op) == 105 else VM.signed32(primary_flags | 0x40000000)
			return "continue"
		126:
			var index: int = (machine.evaluate(args[0]) >> 16) - 1
			var components: Array[int] = []
			for i in range(1,4):
				var value: int = (machine.evaluate(args[i]) >> 16) & 65535
				components.append(value - 65536 if value >= 32768 else value)
			if machine.status == "unsupported" or index < 0 or index >= collision_points.size():
				return "unsupported"
			collision_points[index] = Vector3i(components[0],components[1],components[2])
			return "continue"
		127:
			var count: int = (machine.evaluate(args[0]) >> 16) & 255
			if machine.status == "unsupported" or count > collision_points.size():
				return "unsupported"
			collision_point_count = count
			return "continue"
		39,41:
			var delta_units: int = machine.evaluate(args[0]) >> 4
			if machine.status == "unsupported":
				return "unsupported"
			var source_y := roundi(position.y / world.CELL_METERS * 4096.0)
			var direction := -1 if int(instruction.op) == 39 else 1
			position.y = VM.signed32(source_y + direction * delta_units) * world.CELL_METERS / 4096.0
			return "continue"
		148:
			var mode := int(args[0])
			var index := int(args[1]) & 65535
			var table: Array = world.runtime_tables.get("wobble",{}).get("verticalDeltas",[])
			if mode not in [2,29] or table.size() != 60 or (mode == 29 and index >= 8):
				return "unsupported"
			var counter: int = int(machine.globals.get(index,0)) if mode == 2 else int(machine.parameters[index]) if index < machine.parameters.size() else 0
			# Retail compares the counter unsigned and wraps before table lookup.
			if (counter & 0xffffffff) >= 60:
				counter = 0
			if mode == 2:
				machine.globals[index] = counter + 1
			else:
				while machine.parameters.size() <= index:
					machine.parameters.append(0)
				machine.parameters[index] = counter + 1
			var source_y := roundi(position.y / world.CELL_METERS * 4096.0)
			position.y = VM.signed32(source_y + int(table[counter])) * world.CELL_METERS / 4096.0
			return "continue"
		11,63:
			var handle: int = machine.evaluate(args[0])
			return "continue" if machine.status != "unsupported" and select_animation(handle,int(instruction.op) == 11) else "unsupported"
		12:
			clip_playing = false
			primary_flags &= ~8
			return "continue"
		97:
			# Retail 0x8002c26c changes word372; drawing consumes this separately.
			primary_flags |= 0x20
			return "continue"
		98:
			# Retail 0x8002c290 preserves every other primary flag.
			primary_flags &= ~0x20
			return "continue"
		75:
			clip_playing = false
			primary_flags &= ~8
			clip = {}
			clip_name = ""
			return "continue"
		13:
			if (primary_flags & 8) != 0:
				machine.pc = int(instruction.pc)
				return "yield"
			return "continue"
		101:
			clip_speed_offset = (machine.evaluate(args[0]) >> 8) & 65535
			return "continue"
		49:
			var mode := int(args[0])
			if mode not in [1,2,6,7,8,9,11]:
				return "unsupported"
			var bit := 0
			if mode in [2,6,7]:
				bit = machine.evaluate(args[1])
				if mode != 6: bit >>= 16
				if machine.status == "unsupported":
					return "unsupported"
			event_triggers.append({"mode":mode,"pc":int(args[2] if mode in [2,6,7] else args[1]),"bit":bit,"period":bit,"threshold":bit,"counter":0,"active":false})
			secondary_flags |= 128
			return "continue"
		52:
			if machine.frames.is_empty() or machine.frames.back().kind != "trigger":
				return "unsupported"
			var frame: Dictionary = machine.frames.pop_back()
			var index: int = int(frame.index)
			if index < 0 or index >= event_triggers.size():
				return "unsupported"
			machine.pc = int(frame.pc)
			event_triggers[index].active = false
			for remaining in machine.frames:
				if remaining.kind == "trigger" and int(remaining.index) == index:
					event_triggers[index].active = true
			primary_flags &= ~0x20000000
			return "continue"
		66:
			if released:
				released = false
				return "continue"
			machine.pc = int(instruction.pc)
			return "yield"
		9:
			var mode := int(args[0])
			if mode not in [1,2,4]:
				return "unsupported"
			var handle: int = machine.evaluate(args[1]) >> 16
			var volume := 100.0 if mode == 1 else float(machine.evaluate(args[2]) >> 16)
			var pitch := 0
			if mode == 4:
				pitch = machine.evaluate(args[3]) >> 16
				var random_mask: int = machine.evaluate(args[4]) >> 16
				if machine.status == "unsupported" or world == null:
					return "unsupported"
				var variation: Dictionary = world.source_random.sound_variation(int(volume),pitch,random_mask)
				pitch = variation.pitch
				volume = float(variation.volume)
			if machine.status == "unsupported" or handle <= 0 or handle >= handles.size():
				return "unsupported"
			return "continue" if world.play_imported_sound(handles[handle],global_position,volume,pitch,true) else "unsupported"
		184:
			secondary_flags |= 256
			return "continue"
		58:
			bonus_door_material = null
			var handle: int = machine.evaluate(args[0])
			if handle < 0 or handle >= handles.size() or machine.status == "unsupported":
				return "unsupported"
			if handle == 0:
				# Retail2af54..2af8c stores null model32 and clears secondary0x30.
				# It preserves primary flags and animation state (unlike NoModel202).
				secondary_flags &= ~0x30
				model_data={};model_name="";model_texture={};pose_cache.clear()
				for body in camera_bodies:
					if is_instance_valid(body):body.collision_layer=0
				for part in mesh_parts:
					part.hide();part.queue_free()
				mesh_parts.clear();sprite_parts.clear();camera_bodies.clear()
				return "continue"
			var resource: Dictionary = handles[handle]
			var data: Dictionary = world.read_source_asset(resource.file).duplicate() if world.has_method("read_source_asset") else world.read_json(resource.file)
			var texture: Dictionary = world.material_for_texture("TK%02d_ENM.BIN" % int(world.room_data.style))
			if data.is_empty() or texture.is_empty():
				return "unsupported"
			for body in camera_bodies:
				if is_instance_valid(body):
					body.collision_layer = 0
			for part in mesh_parts:
				part.queue_free()
			mesh_parts.clear()
			sprite_parts.clear()
			camera_bodies.clear()
			model_data = data
			model_asset_file=str(resource.file)
			if not is_instance_valid(visual_root):
				visual_root = Node3D.new()
				visual_root.top_level = true
				add_child(visual_root)
			var collision_counts: Array = data.models[0].get("collision",{}).get("counts",[0,0])
			if int(collision_counts[0]) != 0 or int(collision_counts[1]) != 0:
				secondary_flags |= 0x30
			else:
				secondary_flags &= ~0x30
			model_texture = texture.data
			if str(resource.name) in ["BONDOORL.MOD","BONDOORR.MOD"]:
				# Original decorations are unconditional; this port adds collection feedback.
				# Isolate the door's material so other actors keep their shared animation.
				model_texture = texture.data.duplicate()
				model_texture["bonus_door_feedback"] = true
				bonus_door_material = ShaderMaterial.new()
				bonus_door_material.shader = preload("res://bonus_door_feedback.gdshader")
				bonus_door_material.set_shader_parameter("atlas_texture",texture.material.albedo_texture)
				bonus_door_material.set_shader_parameter("atlas_size",Vector2(model_texture.width,model_texture.height))
				var origins := PackedVector4Array()
				for panel in range(416,422):
					var uv: Array = model_texture.polygons[panel].uv
					origins.append(Vector4(float(uv[2][0])*float(model_texture.width)-0.5,float(uv[2][1])*float(model_texture.height)-0.5,[0,48,96,144,96,144][panel-416],44 if panel>=420 else 12))
				bonus_door_material.set_shader_parameter("panel_origins",origins)
				for entry in world.manifest.textures:
					if entry.name == "TK%02d_ENM.BIN" % int(world.room_data.style):
						bonus_door_material.set_shader_parameter("still_texture",ImageTexture.create_from_image(Image.load_from_file(world.content_root.path_join(entry.image))))
				model_texture["runtime_material"] = bonus_door_material
				refresh_bonus_door_feedback()
			pose_cache.clear()
			pose_banks.clear();pose_bank_order.clear()
			for model_index in range(data.models.size()):
				var model:Dictionary=data.models[model_index]
				var part := MeshInstance3D.new()
				if not model.vertices.is_empty():
					part.mesh = world.geometry(model,model_texture) if bonus_door_material != null else world.source_static_mesh(str(resource.file),model_index,model,texture.data) if world.has_method("source_static_mesh") else world.geometry(model,texture.data)
				# Per-surface materials preserve each face's original blend flag.
				visual_root.add_child(part)
				if SpriteFacing.is_actor_sprite(data,model_index,str(resource.name)):
					sprite_parts.append(part)
				if (secondary_flags&0x20) != 0 and part.mesh != null and not part.mesh.get_faces().is_empty():
					var body := StaticBody3D.new()
					body.collision_layer = 256
					body.collision_mask = 0
					var collision := CollisionShape3D.new()
					collision.shape = part.mesh.create_trimesh_shape()
					body.add_child(collision)
					part.add_child(body)
					camera_bodies.append(body)
				mesh_parts.append(part)
			model_name = resource.name
			return "continue"
		31,32,33,90:
			var packed: int = (machine.evaluate(args[0]) >> 4) & 65535
			if machine.status == "unsupported":
				return "unsupported"
			var value: int = packed - 65536 if packed >= 32768 else packed
			if int(instruction.op) == 90:
				source_scale = Vector3i(value,value,value)
			else:
				source_scale[int(instruction.op) - 31] = value
			scale = Vector3(source_scale) / 4096.0
			return "continue"
		92:
			primary_flags = VM.signed32(primary_flags | 0x80000)
			hide()
			return "continue"
		202:
			# Retail27474..274a8 clears model32 and collision/promotion bits0x30.
			primary_flags = VM.signed32(primary_flags | 0x80000)
			secondary_flags &= ~0x30
			model_data.clear()
			model_name = ""
			for body in camera_bodies:
				if is_instance_valid(body): body.collision_layer = 0
			for part in mesh_parts: part.queue_free()
			mesh_parts.clear(); sprite_parts.clear(); camera_bodies.clear()
			hide()
			return "continue"
		130,131:
			# Native2c3a0/2c3c4 toggles only actor word372 bit0x01000000.
			primary_flags = VM.signed32(primary_flags | 0x01000000) if int(instruction.op) == 130 else VM.signed32(primary_flags & ~0x01000000)
			return "continue"
		93:
			primary_flags = VM.signed32(primary_flags & ~0x80000)
			show()
			return "continue"
	return "unsupported"
