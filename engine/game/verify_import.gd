extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var room = load("res://imported.tscn").instantiate()
	root.add_child(room)
	for i in range(120):
		await physics_frame
	if not room.imported or not room.actor.is_on_floor():
		push_error("Imported room must load and support the actor on its floor")
		fail_check()
		return
	var quarter: Array = room.runtime_tables.trigonometry.quarterSine
	var wall_plane: Array = []
	wall_plane.resize(22)
	wall_plane.fill(0)
	wall_plane[1] = 0x110
	wall_plane[2] = 4096
	var wall_math = preload("res://source_collision.gd")
	var upper_miss_response := wall_math.solve_cached_tile_wall({"halfwords":wall_plane},Vector3i(100,200,0),Vector3i(0,200,0),Vector3i(50,200,0),Vector3i.ZERO,0,0,1,quarter,room.runtime_tables.wallAngles.values,true,true)
	if upper_miss_response.actor_position != Vector3i(-75,200,0) or upper_miss_response.contact_bits != 0 or upper_miss_response.status_set != 0 or not upper_miss_response.moved:
		push_error("Style1 upper miss must preserve ordered correction without adding contact status")
		fail_check()
		return
	wall_plane[1] = 1
	var wall_owner := {"position":Vector3i.ZERO,"scale":Vector2i(4096,4096),"yaw":0,"primary":1,"secondary":0}
	var actor_response := wall_math.actor_wall_response({"halfwords":wall_plane},{"height_units":356,"actor":42},{},Vector3i(-200,0,0),Vector3i(-300,0,0),Vector3i(-100,0,0),1,wall_owner,0,quarter,room.runtime_tables.wallAngles.values)
	if actor_response.rider_position != Vector3i(113,0,0) or actor_response.forward != Vector3i(13,0,0) or actor_response.opposite != Vector3i(-87,0,0) or actor_response.status != 0xa01 or actor_response.contact_owner != 42 or actor_response.owner_secondary != 0x40 or actor_response.wall_angle != 1024:
		push_error("Actor wall response must combine coordinate, plane, status, owner and world stages")
		fail_check()
		return
	wall_owner.primary = 0x1000001
	actor_response = wall_math.actor_wall_response({"halfwords":wall_plane},{"height_units":356,"actor":42},{},Vector3i(-200,0,0),Vector3i(-300,0,0),Vector3i(-100,0,0),0x80000001,wall_owner,0,quarter,room.runtime_tables.wallAngles.values)
	if not actor_response.needs_push_probes or actor_response.rider_position != Vector3i(-100,0,0):
		fail_check()
		return
	wall_plane[1] = 0x110
	if wall_math.actor_wall_world_delta(Vector2i(213,0),Vector2i(8192,4096),1024,quarter).delta != Vector2i(0,-426) or wall_math.actor_wall_world_delta(Vector2i(1048576,0),Vector2i(4096,4096),0,quarter).delta != Vector2i.ZERO:
		push_error("Actor wall world delta must scale before rotation with wrapped products")
		fail_check()
		return
	if wall_math.actor_wall_local(Vector2i(-1,0),Vector2i.ZERO,512,Vector2i(4096,4096),quarter).position != Vector2i.ZERO or wall_math.actor_wall_local(Vector2i(4096,0),Vector2i.ZERO,0,Vector2i(8192,4096),quarter).position != Vector2i(2048,0):
		push_error("Actor wall coordinate division must preserve source truncation and scale")
		fail_check()
		return
	if not wall_math.actor_wall_local(Vector2i(-524288,0),Vector2i.ZERO,0,Vector2i(-1,4096),quarter).has("fault"):
		fail_check()
		return
	wall_plane[1] = 1
	var upper_rear_response := wall_math.solve_upper_opposite_tile_wall({"halfwords":wall_plane},Vector3i(0,200,-200),Vector3i(0,200,-100),Vector3i(0,200,-150),Vector3i.ZERO,1024,quarter)
	if upper_rear_response.actor_position != Vector3i(0,200,100) or upper_rear_response.forward != Vector3i(0,200,50) or upper_rear_response.opposite != Vector3i(0,200,150) or not upper_rear_response.requery_upper:
		push_error("Upper opposite correction must use separate mask and rotate one delta across positions")
		fail_check()
		return
	wall_plane[1] = 0x110
	var upper_cached_response := wall_math.solve_upper_cached_tile_wall({"halfwords":wall_plane},Vector3i(0,200,-100),Vector3i(0,200,-300),Vector3i(0,200,-150),Vector3i.ZERO,1024,quarter,room.runtime_tables.wallAngles.values)
	if upper_cached_response.actor_position != Vector3i(0,200,-25) or upper_cached_response.forward != Vector3i(0,200,25) or upper_cached_response.opposite != Vector3i(0,200,-175) or upper_cached_response.wall_angle != 2048 or not upper_cached_response.requery_upper or upper_cached_response.current_record_fallback:
		push_error("Upper cached world response must rotate correction and request upper requery")
		fail_check()
		return
	upper_cached_response = wall_math.solve_upper_cached_tile_wall({"halfwords":wall_plane},Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO,0,quarter,room.runtime_tables.wallAngles.values)
	if upper_cached_response.requery_upper or not upper_cached_response.current_record_fallback or not upper_cached_response.wall_angle_valid:
		fail_check()
		return
	wall_plane[1] = 0x710
	var rear_response := wall_math.solve_opposite_tile_wall({"halfwords":wall_plane},Vector3i(0,0,200),Vector3i(0,0,100),Vector3i(0,0,150),Vector3i.ZERO,1024,356,quarter,room.runtime_tables.wallAngles.values)
	if rear_response.actor_position != Vector3i(0,0,-63) or rear_response.forward != Vector3i(0,0,-13) or rear_response.opposite != Vector3i(0,0,-113) or rear_response.wall_angle != 2048 or rear_response.requery or rear_response.status != 0x200:
		push_error("Opposite wall response must preserve rotated positions, reversed facing and requery gate")
		fail_check()
		return
	rear_response = wall_math.solve_opposite_tile_wall({"halfwords":wall_plane},Vector3i(0,0,200),Vector3i(0,0,100),Vector3i(0,0,150),Vector3i.ZERO,1024,1024,quarter,room.runtime_tables.wallAngles.values)
	if not rear_response.requery or rear_response.wall_angle_valid:
		fail_check()
		return
	wall_plane[1] = 0x110
	var slope_plane: Array = []
	slope_plane.resize(22)
	slope_plane.fill(0)
	slope_plane[0] = 2
	slope_plane[18] = 256
	var upper_response := wall_math.solve_upper_slope_wall({"halfwords":slope_plane},{"height_units":924},{},Vector3i.ZERO,Vector3i(100,0,0),Vector3i.ZERO,Vector3i.ZERO,0,1,quarter)
	if not upper_response.handled or upper_response.actor_position != Vector3i(100,0,0) or upper_response.opposite != Vector3i(200,0,0):
		fail_check()
		return
	slope_plane[2] = 4096
	upper_response = wall_math.solve_upper_slope_wall({"halfwords":slope_plane},{"height_units":924},{},Vector3i.ZERO,Vector3i(100,0,0),Vector3i.ZERO,Vector3i.ZERO,0,1,quarter)
	if upper_response.handled or upper_response.actor_position != Vector3i.ZERO or upper_response.opposite != Vector3i(100,0,0):
		fail_check()
		return
	slope_plane[19] = 256
	upper_response = wall_math.solve_upper_slope_wall({"halfwords":slope_plane},{"height_units":924},{},Vector3i.ZERO,Vector3i(100,0,0),Vector3i.ZERO,Vector3i.ZERO,0,1,quarter)
	if upper_response.handled or upper_response.opposite != Vector3i(50,0,50):
		fail_check()
		return
	slope_plane[2] = 0
	slope_plane[19] = 0
	slope_plane[18] = 4096
	var slope_response := wall_math.solve_fresh_slope_wall({"halfwords":slope_plane},{"surface_type":0,"height_units":356},Vector3i.ZERO,Vector3i(100,0,0),Vector3i.ZERO,Vector3i.ZERO,0,1,quarter,room.runtime_tables.wallAngles.values)
	if not slope_response.handled or slope_response.actor_position != Vector3i(-6,0,0) or slope_response.opposite != Vector3i(94,0,0) or slope_response.wall_angle != 3072:
		fail_check()
		return
	slope_plane[2] = 4096
	slope_response = wall_math.solve_fresh_slope_wall({"halfwords":slope_plane},{"surface_type":0,"height_units":356},Vector3i.ZERO,Vector3i(100,0,0),Vector3i.ZERO,Vector3i.ZERO,0,1,quarter,room.runtime_tables.wallAngles.values)
	if slope_response.handled or slope_response.actor_position != Vector3i.ZERO or slope_response.opposite != Vector3i(100,0,0):
		fail_check()
		return
	slope_response = wall_math.solve_fresh_slope_wall({"halfwords":slope_plane},{"surface_type":7,"height_units":356},Vector3i.ZERO,Vector3i(100,0,0),Vector3i.ZERO,Vector3i.ZERO,0,0,quarter,room.runtime_tables.wallAngles.values)
	if not slope_response.handled or slope_response.status_set != 0x401 or slope_response.actor_position != Vector3i(-6,0,0):
		fail_check()
		return
	for pair in [[Vector2i.ZERO,0],[Vector2i(0,4096),0],[Vector2i(4096,0),1024],[Vector2i(0,-4096),2048],[Vector2i(-4096,0),-1024],[Vector2i(4096,4096),512],[Vector2i(-4096,-4096),-1536]]:
		if wall_math.wall_normal_angle(pair[0],room.runtime_tables.wallAngles.values).angle != pair[1]:
			push_error("Original wall angle lookup must preserve quadrant signs and table boundaries")
			fail_check()
			return
	var tile_response := wall_math.solve_cached_tile_wall({"halfwords":wall_plane},Vector3i(0,200,100),Vector3i(0,200,300),Vector3i(0,200,200),Vector3i.ZERO,1024,2,0,quarter,room.runtime_tables.wallAngles.values)
	if tile_response.world_delta != Vector2i(0,-125) or tile_response.actor_position != Vector3i(0,200,75) or tile_response.forward != Vector3i(0,200,-25) or tile_response.opposite != Vector3i(0,200,175) or tile_response.status_set != 0x804 or tile_response.wall_angle != 0 or not tile_response.wall_angle_valid:
		push_error("Cached tile wall response must rotate and apply one correction to actor and both samples")
		fail_check()
		return
	var root_table: Array = room.runtime_tables.distanceRoot.values
	var sound_math = preload("res://source_audio_math.gd")
	if sound_math.listener_metrics(Vector3i(4096,0,0),Vector3i.ZERO,root_table).distance != 4096 or sound_math.listener_metrics(Vector3i(0,4096,0),Vector3i.ZERO,root_table).distance != 8192:
		push_error("Source sound distance must half X/Z before squaring and double the root")
		fail_check()
		return
	var waypoint_actor = preload("res://asl_actor.gd").new()
	room.add_child(waypoint_actor)
	waypoint_actor.world = room
	var saved_player_position: Vector3 = room.actor.position
	room.actor.position = Vector3(room.CELL_METERS,0,0)
	waypoint_actor.source_angles = Vector3i(123,0,456)
	if waypoint_actor.asl_command({"op":195,"args":[[{"op":4,"value":50 << 16},{"op":18}]]},waypoint_actor.vm) != "continue" or waypoint_actor.source_angles != Vector3i(123,50,456):
		fail_check()
		return
	room.actor.position = saved_player_position
	waypoint_actor.source_angles = Vector3i.ZERO
	waypoint_actor.source_waypoints = [{"position":[1,0,0],"value":0},{"position":[0,0,0],"value":0}]
	waypoint_actor.vm.configure({"instructions":[]},0,waypoint_actor)
	if waypoint_actor.asl_command({"op":137,"args":[[{"op":4,"value":100 << 16},{"op":18}],[{"op":4,"value":100 << 16},{"op":18}]]},waypoint_actor.vm) != "continue" or waypoint_actor.source_angles.y != 100 or waypoint_actor.source_angles.x != 0:
		fail_check()
		return
	if waypoint_actor.vm.evaluate([{"op":3,"index":62},{"op":18}]) != (1024 << 16) or waypoint_actor.vm.evaluate([{"op":3,"index":34},{"op":18}]) != 131072:
		fail_check()
		return
	if waypoint_actor.vm.evaluate([{"op":3,"index":29},{"op":18}]) != 65536:
		fail_check()
		return
	waypoint_actor.position.x = room.CELL_METERS
	waypoint_actor.source_waypoints[0].position = [1,1,0]
	waypoint_actor.source_angles = Vector3i(0,0,123)
	waypoint_actor.asl_command({"op":137,"args":[[{"op":4,"value":100 << 16},{"op":18}],[{"op":4,"value":50 << 16},{"op":18}]]},waypoint_actor.vm)
	if waypoint_actor.source_angles != Vector3i(4046,0,123):
		push_error("Waypoint XY turn must derive pitch from vertical distance and preserve roll")
		fail_check()
		return
	waypoint_actor.source_waypoints[0].position = [1,0,0]
	if waypoint_actor.vm.evaluate([{"op":3,"index":29},{"op":18}]) != 0:
		fail_check()
		return
	waypoint_actor.asl_command({"op":135,"args":[]},waypoint_actor.vm)
	if waypoint_actor.vm.evaluate([{"op":3,"index":62},{"op":18}]) != (3072 << 16) or waypoint_actor.vm.evaluate([{"op":3,"index":34},{"op":18}]) != 65536:
		fail_check()
		return
	if waypoint_actor.vm.evaluate([{"op":3,"index":29},{"op":18}]) != 65536:
		fail_check()
		return
	waypoint_actor.free()
	var distance_math = preload("res://source_collision.gd")
	var contact_actor = preload("res://asl_actor.gd").new()
	contact_actor.world = room
	contact_actor.position.y = 1000.0 * room.CELL_METERS / 4096.0
	contact_actor.asl_command({"op":34,"args":[[{"op":4,"value":52428800},{"op":18}]]},contact_actor.vm)
	if not contact_actor.update_source_vertical(0,true) or roundi(contact_actor.position.y / room.CELL_METERS * 4096.0) != 1261 or contact_actor.source_rise_remaining != 539 or contact_actor.source_vertical_speed != 188:
		push_error("Original Jump state must feed the reconstructed actor rise update")
		fail_check()
		return
	contact_actor.position = Vector3.ZERO
	var landing_program := {"instructions":[{"pc":8,"op":49,"args":[9,30],"next":12},{"pc":12,"op":66,"args":[],"next":13},{"pc":30,"op":108,"args":[0,[{"op":4,"value":65536},{"op":18}]],"next":38},{"pc":38,"op":52,"args":[],"next":39}]}
	contact_actor.vm.configure(landing_program,8,contact_actor,[0])
	contact_actor.vm.run()
	contact_actor.primary_flags = 0x401
	contact_actor.source_ground.height_units = 0
	contact_actor.source_vertical_speed = 10
	contact_actor.position.y = 10.0 * room.CELL_METERS / 4096.0
	contact_actor.run_source_scripts({"map_style":0,"jump_held":true})
	if contact_actor.vm.parameters[0] != 65536 or contact_actor.position.y != 0 or (contact_actor.primary_flags & 0x1000) == 0:
		push_error("Landing controller must set its event after transient cleanup and before trigger scan")
		fail_check()
		return
	contact_actor.vm.parameters[0] = 0
	contact_actor.run_source_scripts({"map_style":0,"jump_held":true})
	if contact_actor.vm.parameters[0] != 0 or (contact_actor.primary_flags & 0x1000) != 0:
		fail_check()
		return
	contact_actor.event_triggers.clear()
	landing_program.instructions[0].args[0] = 8
	contact_actor.vm.configure(landing_program,8,contact_actor,[0])
	contact_actor.vm.run()
	contact_actor.primary_flags = 0x201
	contact_actor.source_vertical_speed = 100
	contact_actor.source_rise_remaining = 103
	contact_actor.run_source_scripts({"map_style":0,"jump_held":true})
	if contact_actor.vm.parameters[0] != 65536 or (contact_actor.primary_flags & 0x2400) != 0x2400:
		push_error("Apex transition must generate mode8 before scripts in the same tick")
		fail_check()
		return
	contact_actor.model_data = {"models":[{"radius":1,"bounds":[[0,0,0]]}]}
	contact_actor.source_render_matrix = [4096,0,0,0,4096,0,0,0,4096]
	contact_actor.source_player_distance_valid = true
	contact_actor.primary_flags = 0x20001
	contact_actor.secondary_flags = 4
	contact_actor.source_field_180 = 1
	var contact := contact_actor.evaluate_player_contact([Vector3i.ZERO],[0],1)
	if not contact.contact or contact.actor != 0x120001 or contact.player != 1:
		push_error("Actor contact evaluator must combine geometry and source response")
		fail_check()
		return
	contact_actor.source_player_distance = 4097
	if contact_actor.evaluate_player_contact([Vector3i.ZERO],[0],1).contact:
		fail_check()
		return
	contact_actor.secondary_flags = 0x60
	contact = contact_actor.evaluate_player_contact([],[],1)
	if not contact.contact or contact.secondary != 0x20:
		fail_check()
		return
	contact_actor.secondary_flags = 0
	contact_actor.source_player_distance = 0
	if not contact_actor.evaluate_player_contact([Vector3i.ZERO],[4096],1).contact:
		fail_check()
		return
	contact_actor.free()
	var pair_cases := [
		[Vector3i(4096,0,0),4096,4096,4096,0,0,false],
		[Vector3i(4095,0,0),4096,4096,4096,0,0,true],
		[Vector3i(4096,0,0),4096,4096,4096,0x10000,0x10000000,true],
		[Vector3i(8192,0,0),4096,4096,4096,0x10000,0x10000000,false],
		[Vector3i(4096,0,0),4096,4096,8192,0,0,true],
		[Vector3i.ZERO,1,1,4096,0,0,true],
		[Vector3i.ZERO,0,-1,4096,0,0,true],
		[Vector3i.ZERO,0,524288,8192,0,0,false]]
	for sample in pair_cases:
		if distance_math.model_pair_contact(sample[0],sample[1],sample[2],sample[3],sample[4],sample[5],root_table) != sample[6]:
			push_error("Model-pair contact must preserve summed radius rounding, scale multiplication and unsigned strict limits")
			fail_check()
			return
	var slab_cases := [
		[Vector3i(4095,0,0),4096,0,true],
		[Vector3i(4096,0,0),4096,0,false],
		[Vector3i(-4096,0,0),4096,0,false],
		[Vector3i(2048,0,0),2048,0,false],
		[Vector3i(0,0,4095),4096,1024,true],
		[Vector3i(0,0,4096),4096,1024,false],
		[Vector3i(0,4096,0),4096,0,false]]
	for sample in slab_cases:
		if distance_math.player_slab_contact(sample[0],0,4096,0x10001000,sample[1],sample[2],0,0,root_table,quarter) != sample[3]:
			push_error("Player slab contact must preserve local-axis rotation, scaled strict limits and radial boundary")
			fail_check()
			return
	var contact_cases := [
		[Vector3i(4096,0,0),4096,2048,4096,4096,0,4,0,false],
		[Vector3i(4096,0,0),4096,2048,4096,4096,0x10000,4,0x10000000,true],
		[Vector3i(0,4096,0),0,1,4096,4096,0,8,0,false],
		[Vector3i(0,4095,0),0,1,4096,4096,0,8,0,true],
		[Vector3i.ZERO,0,1,4096,4096,0,8,0,false],
		[Vector3i(0,2048,0),0,1,4096,2048,0,8,0,false],
		[Vector3i(0,1,0),0,1,4096,4096,0,12,0,true],
		[Vector3i.ZERO,0,-1,0,4096,0,4,0,true]]
	for sample in contact_cases:
		if distance_math.player_point_contact(sample[0],sample[1],sample[2],sample[3],sample[4],sample[5],sample[6],sample[7],root_table) != sample[8]:
			push_error("Player point contact must preserve strict radius, height, mode priority and unsigned threshold")
			fail_check()
			return
	if distance_math.player_distance(Vector3i(4096,0,0),root_table) != 4096 or distance_math.player_distance(Vector3i(63,0,0),root_table) != 0 or distance_math.player_distance(Vector3i(65536,0,0),root_table) != 0:
		push_error("Player distance must preserve source square-root scaling and IR truncation")
		fail_check()
		return
	var door_parent: Node3D
	var animation_actor: Node3D = null
	for candidate in room.source_actors:
		if not candidate.clip.is_empty() and candidate.vm.status in ["ready","yielded"]:
			animation_actor = candidate
			break
	if animation_actor == null:
		fail_check()
		return
	var animation_handle := -1
	var model_handle := -1
	for index in range(1,animation_actor.handles.size()):
		if str(animation_actor.handles[index].get("name","")) == animation_actor.clip_name:
			animation_handle = index
		if str(animation_actor.handles[index].get("name","")) == animation_actor.model_name:
			model_handle = index
	if animation_handle < 0 or model_handle < 0:
		fail_check()
		return
	assert(animation_actor.asl_command({"op":11,"args":[[{"op":4,"value":animation_handle},{"op":18}]]},animation_actor.vm)=="continue")
	if (animation_actor.primary_flags & 8) == 0 or animation_actor.vm.evaluate([{"op":3,"index":26},{"op":18}]) != 8:
		fail_check()
		return
	var retained_clip := str(animation_actor.clip_name)
	assert(animation_actor.asl_command({"op":58,"args":[[{"op":4,"value":model_handle},{"op":18}]]},animation_actor.vm)=="continue")
	if not animation_actor.clip_playing or animation_actor.clip_name != retained_clip or (animation_actor.primary_flags & 8) == 0:
		push_error("SetModel must preserve current animation pointer/state like the source")
		fail_check()
		return
	animation_actor.asl_command({"op":12,"args":[]},animation_actor.vm)
	if (animation_actor.primary_flags & 8) != 0 or animation_actor.clip.is_empty() or animation_actor.vm.evaluate([{"op":3,"index":26},{"op":18}]) != 0:
		fail_check()
		return
	var left_door_found := false
	var right_door_found := false
	for source_actor in room.source_actors:
		if source_actor.source_name == "NormalDoor":
			door_parent = source_actor
		left_door_found = left_door_found or source_actor.source_name == "SquareDoorL"
		right_door_found = right_door_found or source_actor.source_name == "SquareDoorR"
	if door_parent == null or not left_door_found or not right_door_found:
		push_error("Original NormalDoor script must spawn both imported door actors")
		fail_check()
		return
	var spawn_params: Array = [65536,131072,0,0,0,0,0,0]
	var saved_waypoints: Array = door_parent.source_waypoints
	var saved_waypoint_index := int(door_parent.source_waypoint_index)
	door_parent.source_waypoints = [{"position":[0,0,0]},{"position":[1,0,0]}]
	door_parent.source_waypoint_index = 1
	var spawned: Node3D = room.spawn_source_actor(door_parent,"SquareDoorL",spawn_params)
	if spawned == null or spawned.vm.status != "ready" or spawned.position != door_parent.position or spawned.source_angles != door_parent.source_angles or spawned.vm.parameters != spawn_params or spawned.source_parent_id != door_parent.source_pool_id:
		push_error("Spawn must copy source pose/parameters and defer script execution")
		fail_check()
		return
	door_parent.source_waypoints.append({"position":[2,0,0]})
	if spawned.source_waypoints.size() != 3 or spawned.source_waypoint_index != 0:
		push_error("Spawn must inherit the shared waypoint head rather than the caller cursor")
		fail_check()
		return
	spawned.asl_command({"op":135,"args":[]},spawned.vm)
	spawned.asl_command({"op":135,"args":[]},spawned.vm)
	if spawned.source_waypoint_index != 2 or door_parent.source_waypoint_index != 1:
		fail_check()
		return
	door_parent.source_waypoints = saved_waypoints
	door_parent.source_waypoint_index = saved_waypoint_index
	var pairs: Array = room.runtime_tables.rotation.pairs
	var wall_rotation = preload("res://source_rotation.gd")
	var wall_pair := wall_rotation.wall_sample_pair(1024,Vector3i(100,200,300),Vector3i(4096,12345,8192),pairs)
	if wall_pair.forward != Vector3i(8292,200,-3796) or wall_pair.opposite != Vector3i(-8092,200,4396):
		push_error("Wall sample pair must use yaw only and preserve actor Y on both sides")
		fail_check()
		return
	wall_pair = wall_rotation.wall_sample_pair(0,Vector3i(2147483647,0,-2147483648),Vector3i(32768,999,1),pairs)
	if wall_pair.forward != Vector3i(2147450879,0,-2147483647) or wall_pair.opposite != Vector3i(-2147450881,0,2147483647):
		fail_check()
		return
	var pose_parent = preload("res://asl_actor.gd").new()
	var pose_child = preload("res://asl_actor.gd").new()
	pose_parent.world = room
	pose_child.world = room
	pose_parent.position = Vector3(6,3,12)
	pose_parent.source_angles = Vector3i(0,1024,0)
	pose_parent.source_scale = Vector3i(8192,8192,8192)
	pose_parent.source_pool_id = room.source_pool.allocate({"node":pose_parent})
	pose_child.source_parent_id = pose_parent.source_pool_id
	pose_child.primary_flags |= 0x4000000
	pose_child.position = Vector3(3,0,0)
	if not pose_child.refresh_source_render_pose() or pose_child.position != Vector3(3,0,0) or pose_child.source_render_position != Vector3i(8192,4096,12288):
		push_error("Child render pose must compose source parents without changing logical pose or inheriting scale")
		fail_check()
		return
	pose_parent.primary_flags |= 0x4000000
	pose_parent.source_parent_id = pose_parent.source_pool_id
	if pose_child.refresh_source_render_pose() or pose_child.vm.status != "unsupported":
		fail_check()
		return
	room.source_pool.release(pose_parent.source_pool_id)
	pose_child.free()
	pose_parent.free()
	var rotation_builder = preload("res://source_rotation.gd")
	var root_actor = preload("res://asl_actor.gd").new()
	root_actor.world = room
	root_actor.clip = {"frameInfo":[[1024 << 16,0,100,200,300,0]]}
	if not root_actor.apply_root_frame() or root_actor.position != Vector3(100,200,300) * room.CELL_METERS / 4096.0 or root_actor.source_rotation_y != 1024:
		root_actor.free()
		push_error("Root frame must apply source movement before angular increments")
		fail_check()
		return
	root_actor.clip.frameInfo[0] = [0,0,100,200,300,0]
	if not root_actor.apply_root_frame() or root_actor.position != Vector3(400,400,200) * room.CELL_METERS / 4096.0:
		root_actor.free()
		fail_check()
		return
	root_actor.free()
	var mover = preload("res://asl_actor.gd").new()
	mover.world = room
	mover.vm.configure({"instructions":[]},0,mover)
	var movement_arg := [[{"op":4,"value":65536},{"op":18}]]
	mover.asl_command({"op":38,"args":movement_arg},mover.vm)
	if mover.position != Vector3(-room.CELL_METERS,0,0):
		mover.free()
		fail_check()
		return
	mover.asl_command({"op":40,"args":movement_arg},mover.vm)
	mover.asl_command({"op":43,"args":[[{"op":4,"value":1024 << 16},{"op":18}]]},mover.vm)
	mover.asl_command({"op":38,"args":movement_arg},mover.vm)
	if mover.position != Vector3(0,0,room.CELL_METERS) or mover.source_rotation_y != 1024:
		mover.free()
		fail_check()
		return
	mover.position = Vector3.ZERO
	mover.source_angles = Vector3i(1024,0,0)
	mover.source_rotation_y = 0
	mover.asl_command({"op":37,"args":movement_arg},mover.vm)
	if mover.position != Vector3(0,-room.CELL_METERS,0):
		mover.free()
		push_error("MoveForward must use the full source rotation matrix")
		fail_check()
		return
	mover.asl_command({"op":36,"args":movement_arg},mover.vm)
	if mover.position != Vector3.ZERO:
		mover.free()
		fail_check()
		return
	mover.asl_command({"op":143,"args":[movement_arg[0],[{"op":4,"value":1024 << 16},{"op":18}]]},mover.vm)
	if mover.position != Vector3(room.CELL_METERS,0,0) or mover.source_angles != Vector3i(1024,0,0):
		mover.free()
		push_error("Explicit-angle movement must preserve actor orientation and move in world X/Z")
		fail_check()
		return
	mover.asl_command({"op":42,"args":[[{"op":4,"value":1 << 16},{"op":18}]]},mover.vm)
	if mover.source_rotation_y != 4095:
		mover.free()
		fail_check()
		return
	mover.free()
	var point_actor = preload("res://asl_actor.gd").new()
	root.add_child(point_actor)
	point_actor.set_physics_process(false)
	point_actor.world = room
	point_actor.position = room.actor.position + Vector3(0,1,0)
	point_actor.primary_flags |= 0x1000000
	point_actor.collision_point_count = 1
	if not point_actor.update_source_ground() or int(point_actor.source_ground.mode) != 1 or point_actor.source_point_caches[0].is_empty():
		point_actor.free()
		push_error("Source collision points must query original room surfaces and retain their caches")
		fail_check()
		return
	point_actor.free()
	if rotation_builder.matrix(Vector3i.ZERO,pairs) != [4096,0,0,0,4096,0,0,0,4096] or rotation_builder.matrix(Vector3i(0,1024,0),pairs) != [0,0,4096,0,4096,0,-4096,0,0]:
		push_error("Source matrix must preserve identity and quarter-turn Y rotation")
		fail_check()
		return
	if rotation_builder.matrix(Vector3i(0,512,0),pairs) != [2892,0,2896,0,4096,0,-2896,0,2892]:
		push_error("Rotation matrices must use the distinct packed cosine table")
		fail_check()
		return
	if rotation_builder.matrix(Vector3i(0,-1024,0),pairs) != [0,0,-4096,0,4096,0,4096,0,0] or rotation_builder.matrix(Vector3i(1024,0,0),pairs) != [4096,0,0,0,0,-4096,0,4096,0]:
		fail_check()
		return
	var collision = preload("res://source_collision.gd")
	var carried: Dictionary = collision.platform_pose(Vector3i(4096,100,0),500,Vector3i(100,200,300),Vector3i.ZERO,1024,0,true,quarter)
	if carried.get("position",Vector3i.ZERO) != Vector3i(100,300,-3796) or int(carried.get("yaw",0)) != 1524:
		push_error("Platform pose must preserve source translation, yaw rotation and rider heading")
		fail_check()
		return
	carried = collision.platform_pose(Vector3i(4096,100,0),500,Vector3i(100,200,300),Vector3i.ZERO,1024,0,false,quarter)
	if carried.position != Vector3i(4196,100,300) or int(carried.yaw) != 500:
		fail_check()
		return
	for angle in [0,512,1024,2048,3072,4096,-1024]:
		var expected: int = {0:0,512:2896,1024:4096,2048:0,3072:-4096,4096:0,-1024:-4096}[angle]
		if collision.sine(angle,quarter) != expected:
			push_error("Imported source trigonometry must preserve cardinal and diagonal values")
			fail_check()
			return
	if collision.local_point(Vector2i(4096,0),1024,quarter) != Vector2i(0,4096):
		fail_check()
		return
	if collision.local_point(Vector2i(-1,0),512,quarter) != Vector2i(-1,-1):
		push_error("Inverse rotation must use arithmetic shifts for negative sub-unit points")
		fail_check()
		return
	var terrain_hits: Array = room.terrain_surfaces_at(room.actor.position)
	if terrain_hits.is_empty():
		push_error("The player landing location must resolve original terrain collision surfaces")
		fail_check()
		return
	var floor_matched := false
	for hit in terrain_hits:
		if int(hit.group) == 0 and absf(float(hit.height_units) * room.CELL_METERS / 4096.0 - room.actor.position.y) < 0.01:
			floor_matched = true
	if not floor_matched:
		push_error("Original surface height must agree with the first-room landing floor")
		fail_check()
		return
	var selected_floor: Dictionary = room.source_floor_at(room.actor.position)
	var selected_ground: Dictionary = room.source_ground_at(room.actor.position,room.actor)
	if int(selected_ground.mode) != 1 or selected_ground.height_units != selected_floor.get("height_units",0):
		push_error("Source ground selection must preserve the opening-room terrain contact")
		fail_check()
		return
	if selected_floor.is_empty() or absf(float(selected_floor.height_units) * room.CELL_METERS / 4096.0 - room.actor.position.y) >= 0.01:
		push_error("Source fallback selection must identify the opening-room landing floor")
		fail_check()
		return
	var synthetic := {"halfwords":[4,0,4096,0,128,0,-4096,0,128,0,0,4096,128,0,0,-4096,128,0,0,0,1177,0]}
	var sample_model := {"collision":{"groups":[[synthetic],[]]}}
	var saved_tracks: Array = room.room_data.tracks
	var saved_models: Array = room.terrain_models
	var cache_low: Dictionary = synthetic.duplicate(true)
	cache_low.halfwords[20] = 100
	var cache_high: Dictionary = synthetic.duplicate(true)
	cache_high.halfwords[20] = 1024
	cache_high.halfwords[0] = 4 | (17 << 8)
	room.room_data.tracks = [{"position":[0,0,0],"rotation":0,"index":0},{"position":[0,0,0],"rotation":0,"index":1}]
	room.terrain_models = [{"collision":{"groups":[[cache_low],[]]}},{"collision":{"groups":[[cache_high],[]]}}]
	var cached_surface: Dictionary = room.source_cached_floor_at(Vector3.ZERO,{"tile":0,"record":0})
	cache_low.halfwords[1] = 0xf00
	var lower_stage := {"actor_position":Vector3i(200,0,0),"forward":Vector3i(200,0,0),"opposite":Vector3i.ZERO,"sample_index":0,"cache":{"lower":{"tile":0,"record":0}},"lower":{"tile":0,"record":0,"height_units":100},"status":0,"contact_bits":0,"ground_type":0,"ground_height":100}
	var lower_response: Dictionary = room.source_lower_wall_stage(lower_stage)
	if lower_response.get("actor_position",Vector3i.ZERO) != Vector3i(110,0,0) or lower_response.lower.tile != 0 or lower_response.contact_bits != 4:
		push_error("Lower wall stage must combine raw query miss, cached solver and world correction")
		fail_check()
		return
	lower_stage.actor_position = Vector3i.ZERO
	lower_stage.forward = Vector3i.ZERO
	lower_response = room.source_lower_wall_stage(lower_stage)
	if lower_response.contact_bits != 0 or lower_response.lower.query_field_6 != 1:
		fail_check()
		return
	cache_low.halfwords[20] = 356
	lower_response = room.source_lower_wall_stage(lower_stage)
	if lower_response.contact_bits != 4 or lower_response.status != 1:
		push_error("Fresh blocked lower stage must preserve entry status even without a correction")
		fail_check()
		return
	cache_low.halfwords[20] = 100
	cache_low.halfwords[1] = 0
	var sample_tracks: Array = room.room_data.tracks
	var sample_actors: Array[Node3D] = room.source_actors.duplicate()
	room.room_data.tracks = [sample_tracks[0]]
	room.source_actors.clear()
	cache_low.halfwords[1] = 0xf00
	var loop_actor = preload("res://asl_actor.gd").new()
	loop_actor.world = room
	room.add_child(loop_actor)
	loop_actor.set_physics_process(false)
	loop_actor.collision_point_count = 2
	loop_actor.collision_points[0] = Vector3i(200,0,0)
	loop_actor.store_source_movement_cache(0,{"tile":0,"record":0},{"tile":-1,"record":0})
	var sample_loop: Dictionary = room.source_movement_sample_loop(loop_actor,{"actor_position":Vector3i.ZERO,"primary":1,"status":0,"contact_bits":0,"ground_type":0,"ground_height":100,"lower":{"tile":0,"record":0,"height_units":100}})
	if sample_loop.get("actor_position",Vector3i.ZERO) != Vector3i(-90,0,0) or sample_loop.samples_processed != 2 or loop_actor.source_point_cache(1).lower.tile != 0 or roundi(loop_actor.position.x/room.CELL_METERS*4096.0) != -90:
		push_error("Movement sample loop must carry correction into subsequent samples and shared caches")
		fail_check()
		return
	var finalized: Dictionary = room.source_finalize_movement(loop_actor,sample_loop,{"lower":{"tile":-2},"upper":{"tile":-1}},{"height_units":100,"surface_type":0})
	if finalized.ground.height_units != 100 or finalized.ground.mode != 5 or finalized.center_cache.lower.tile != 0 or finalized.actor_position != Vector3i(-90,0,0) or finalized.field_180 != null:
		push_error("Final movement response must combine center queries, contact bits and explicit unknown ceiling height")
		fail_check()
		return
	if not loop_actor.commit_source_movement(finalized) or loop_actor.source_ground.mode != 5 or loop_actor.source_field_180_valid or loop_actor.source_terrain_cache.tile != 0:
		fail_check()
		return
	loop_actor.vm.configure({"instructions":[]},0,loop_actor)
	loop_actor.vm.evaluate([{"op":3,"index":8},{"op":18}])
	if loop_actor.vm.status != "unsupported":
		fail_check()
		return
	loop_actor.vm.configure({"instructions":[]},0,loop_actor)
	loop_actor.asl_command({"op":56,"args":[8,[{"op":4,"value":65536},{"op":18}]]},loop_actor.vm)
	if not loop_actor.source_field_180_valid or loop_actor.source_field_180 != 4096:
		fail_check()
		return
	loop_actor.primary_flags = 0x48001
	if not loop_actor.run_source_collision_response() or loop_actor.source_ground.mode != 1 or loop_actor.source_movement_status != 0 or loop_actor.source_terrain_cache.tile != 0:
		push_error("Collision dispatcher must run height then movement then commit the final ground state")
		fail_check()
		return
	loop_actor.vm.configure({"instructions":[{"pc":8,"op":66,"name":"Hold","args":[],"next":9}]},8,loop_actor)
	loop_actor.source_movement_status = 0x1234
	loop_actor.run_source_scripts()
	if loop_actor.vm.status != "yielded" or loop_actor.source_movement_status != 0 or loop_actor.source_ground.mode != 1:
		push_error("Yielded actor tick must invoke live collision response before returning")
		fail_check()
		return
	loop_actor.primary_flags = 1
	loop_actor.secondary_flags = 0x40
	if loop_actor.asl_command({"op":82,"args":[[{"op":4,"value":32768},{"op":18}]]},loop_actor.vm) != "continue" or loop_actor.source_ground.height_units != 100 or loop_actor.primary_flags != 0x8001 or (loop_actor.secondary_flags & 0x40) != 0:
		push_error("CollisionOn must apply its mask and immediate height response before continuing")
		fail_check()
		return
	loop_actor.primary_flags = 1
	loop_actor.source_ground.height_units = 777
	if loop_actor.asl_command({"op":82,"args":[[{"op":4,"value":262144},{"op":18}]]},loop_actor.vm) != "continue" or loop_actor.source_ground.height_units != 777:
		push_error("CollisionOn bit0x40000 must defer its immediate helper")
		fail_check()
		return
	loop_actor.free()
	room.room_data.tracks = sample_tracks
	room.source_actors.assign(sample_actors)
	cache_low.halfwords[1] = 0
	lower_stage.secondary = 0x1000
	lower_stage.previous_mode = 4
	lower_response = room.source_lower_wall_stage(lower_stage)
	if not lower_response.get("edge_transition",false) or lower_response.contact_bits != 0:
		push_error("First-sample guard must retain query state while bypassing lower wall response")
		fail_check()
		return
	if cached_surface.get("height_units",0) != 100 or cached_surface.get("query_field_6",0) != 1:
		push_error("A cached hit with no secondary group must short-circuit fallback")
		fail_check()
		return
	room.terrain_models[0].collision.groups[1] = [synthetic]
	cached_surface = room.source_cached_floor_at(Vector3.ZERO,{"tile":0,"record":0})
	if cached_surface.get("height_units",0) != 100:
		push_error("A non-type-17 cached record must exclude type 17 during fallback")
		fail_check()
		return
	cache_low.halfwords[0] = 4 | (17 << 8)
	cached_surface = room.source_cached_floor_at(Vector3.ZERO,{"tile":0,"record":0})
	if cached_surface.get("height_units",0) != 1024 or cached_surface.get("query_field_6",0) != 1:
		push_error("A type-17 cached record must allow type 17 during fallback")
		fail_check()
		return
	cache_low.halfwords[0] = 4
	room.room_data.tracks[0].position = [100,0,0]
	if not room.source_cached_floor_at(Vector3.ZERO,{"tile":0,"record":0}).is_empty() or room.source_cached_floor_at(Vector3.ZERO).get("height_units",0) != 1024:
		push_error("Cached misses must retain the source filter; absent caches must allow type 17")
		fail_check()
		return
	if room.source_cached_floor_at(Vector3.ZERO).get("query_field_6",-1) != 0:
		push_error("Fresh floor queries must clear cached-path metadata")
		fail_check()
		return
	var upper_halfwords: Array = []
	upper_halfwords.resize(22)
	upper_halfwords.fill(0)
	for edge in range(3):
		upper_halfwords[4+edge*4] = -1
		upper_halfwords[5+edge*4] = -1
	var cached_upper := {"halfwords":upper_halfwords.duplicate()}
	# Cached upper validation ignores flag8; fresh selection still requires it.
	upper_halfwords[0] = 8
	upper_halfwords[20] = 100
	room.room_data.tracks[0].position = [0,0,0]
	room.terrain_models[0].collision.groups = [[cached_upper],[]]
	room.terrain_models[1].collision.groups = [[{"halfwords":upper_halfwords}],[]]
	var upper_result: Dictionary = room.source_cached_ceiling_at(Vector3.ZERO,{"tile":0,"record":0})
	if upper_result.get("tile",-1) != 1 or upper_result.get("query_field_18",0) != 1 or room.source_ceiling_at(Vector3.ZERO).get("query_field_18",-1) != 0:
		push_error("Upper cache must mark metadata without seeding selection or requiring flag8")
		fail_check()
		return
	cached_upper.halfwords[4] = 0
	var upper_stage := {"actor_position":Vector3i.ZERO,"forward":Vector3i.ZERO,"opposite":Vector3i.ZERO,"sample_index":0,"cache":{"upper":{"tile":0,"record":0}},"lower":{"tile":-1},"status":0,"contact_bits":0}
	var upper_stage_result: Dictionary = room.source_upper_wall_stage(upper_stage)
	if upper_stage_result.contact_bits != 4 or upper_stage_result.status != 1 or upper_stage_result.upper.tile != 1:
		push_error("Upper wall stage must combine query metadata, entry and opposite fallback")
		fail_check()
		return
	upper_stage.lower = {"tile":0,"height_units":-156}
	upper_stage_result = room.source_upper_wall_stage(upper_stage)
	if upper_stage_result.contact_bits != 0:
		fail_check()
		return
	var saved_style := int(room.room_data.style)
	room.room_data.style = 1
	upper_halfwords[0] = 0
	cached_upper.halfwords[2] = 4096
	cached_upper.halfwords[4] = -1
	upper_stage.lower = {"tile":-1}
	upper_stage.actor_position = Vector3i(2,0,0)
	upper_stage.forward = Vector3i(2,0,0)
	upper_stage_result = room.source_upper_wall_stage(upper_stage)
	if upper_stage_result.actor_position != Vector3i(1,0,0) or upper_stage_result.upper.tile != 0 or upper_stage_result.contact_bits != 0 or upper_stage_result.status != 0:
		push_error("Style1 upper miss stage must restore cache identity without contact bits")
		fail_check()
		return
	room.room_data.style = saved_style
	cached_upper.halfwords[2] = 0
	cached_upper.halfwords[4] = 0
	upper_halfwords[0] = 0
	var raw_upper: Dictionary = room.source_raw_ceiling_query(Vector3.ZERO,{"tile":0,"record":0},{"record":77,"height_units":123})
	if raw_upper.tile != -1 or raw_upper.record != 77 or raw_upper.height_units != 123 or raw_upper.query_field_18 != 1:
		push_error("Raw upper miss must retain cache-path mark and unwritten prior result words")
		fail_check()
		return
	upper_halfwords[0] = 8
	cached_upper.halfwords[5] = 0
	if room.source_cached_ceiling_at(Vector3.ZERO,{"tile":0,"record":0}).get("query_field_18",-1) != 0:
		push_error("Upper cached boundary equality must reject reuse")
		fail_check()
		return
	room.room_data.tracks = saved_tracks
	room.terrain_models = saved_models
	var sloped: Dictionary = synthetic.duplicate(true)
	sloped.halfwords[0] = 2
	for offset in [2,6,10,14]:
		sloped.halfwords[offset] = 0
		sloped.halfwords[offset + 1] = 0
	sloped.halfwords[18] = 256
	sloped.halfwords[20] = 0
	if collision.actor_surface(sloped,Vector2i(-1,0),512,Vector3i(8192,4096,8192),100,quarter).get("height_units",0) != 100 or collision.actor_surface(sloped,Vector2i(-1,0),512,Vector3i(4096,8192,4096),100,quarter).get("height_units",0) != 98:
		push_error("Actor transforms must preserve scaled division versus unit-scale arithmetic shift")
		fail_check()
		return
	if not collision.actor_surface(sloped,Vector2i.ZERO,0,Vector3i(0,4096,4096),0,quarter).is_empty():
		fail_check()
		return
	var sample_tile := {"position":[2,3,4],"rotation":0.25}
	var translated: Array = collision.tile_surfaces(sample_tile,sample_model,Vector3i(8192,0,16384),quarter)
	if translated.size() != 1 or int(translated[0].height_units) != 13465:
		push_error("Tile query must preserve source vertical translation")
		fail_check()
		return
	if collision.tile_surfaces({"position":[0,0,0],"rotation":0},sample_model,Vector3i(-2147483648,0,0),quarter).size() != 1:
		push_error("Cached broadphase must preserve the source signed negation overflow")
		fail_check()
		return
	if not collision.tile_surfaces(sample_tile,sample_model,Vector3i(8192+2176,0,16384),quarter).is_empty():
		push_error("Source broadphase must reject its exact outer border")
		fail_check()
		return
	if collision.tile_surfaces(sample_tile,sample_model,Vector3i(8192+128,0,16384),quarter).size() != 1 or not collision.tile_surfaces(sample_tile,sample_model,Vector3i(8192+129,0,16384),quarter).is_empty():
		push_error("Rotated source surface must preserve inclusive halfplane borders")
		fail_check()
		return
	if room.character_parts.size() != 11 or room.texture_cache.size() < 2:
		push_error("Imported character and terrain textures must be bound")
		fail_check()
		return
	if room.idle_animation != "CROCWA3.ANI":
		push_error("First room must use its source-selected idle animation")
		fail_check()
		return
	var scripted_lid := false
	var scripted_platform := false
	var scripted_dead_platform := false
	var source_gobbo: Node3D
	for source_actor in room.source_actors:
		if source_actor.source_pool_id < 0 or room.source_pool.slots[source_actor.source_pool_id].node != source_actor:
			push_error("Source actor identity must survive list sorting")
			fail_check()
			return
		if source_actor.is_physics_processing():
			push_error("Imported actors must use the shared source clock without duplicate per-node ticks")
			fail_check()
			return
		if source_actor.source_name == "SmashLid":
			if not is_instance_valid(source_actor.visual_root) or not source_actor.visual_root.top_level or source_actor.mesh_parts[0].get_parent() != source_actor.visual_root:
				push_error("Imported actor meshes must use a separate source-driven visual root")
				fail_check()
				return
			var logical_position: Vector3 = source_actor.position
			if not source_actor.refresh_source_render_pose() or source_actor.position != logical_position or source_actor.visual_root.global_position != Vector3(source_actor.source_render_position) * room.CELL_METERS / 4096.0:
				push_error("Visual updates must preserve actor logical position")
				fail_check()
				return
			if (source_actor.primary_flags & 0x20000) == 0 or source_actor.vm.pc == 142:
				push_error("Source stump-lid CollisionOn must preserve its flags and advance past the state-only command")
				fail_check()
				return
			scripted_lid = source_actor.model_name == "STUMPLID.MOD" and source_actor.source_scale.x == 4915 and is_equal_approx(source_actor.scale.x, 4915.0 / 4096.0) and (source_actor.secondary_flags & 0x30) == 0x30
			var surface_model: Dictionary = source_actor.model_data.models[0]
			var hit := preload("res://source_collision.gd").surface(surface_model.collision.groups[0][0],Vector2i.ZERO)
			var underside := collision.actor_surface(surface_model.collision.groups[1][0],Vector2i.ZERO,0,Vector3i(4096,4096,4096),0,quarter)
			var actor_records: Array = []
			var actual_candidates: Array = source_actor.model_surface_candidates_at(source_actor.global_position)
			var source_y := roundi(source_actor.global_position.y / room.CELL_METERS * 4096.0)
			var world_contacts: Dictionary = room.source_contacts_at(source_actor.global_position + Vector3(0,1177 * room.CELL_METERS / 4096.0,0))
			if world_contacts.lower.is_empty():
				push_error("Ordered room actor queries must find a source contact above the stump lid")
				fail_check()
				return
			var actual_contacts: Dictionary = collision.select_actor_contacts([actual_candidates],source_y + 1177)
			if actual_contacts.lower.get("height_units",0) != source_y + 1177 or not source_actor.model_surface_candidates_at(source_actor.global_position,source_actor).is_empty():
				push_error("Actor radius query must retain the imported top and reject self contact")
				fail_check()
				return
			if not source_actor.model_surface_candidates_at(source_actor.global_position + Vector3(room.CELL_METERS,0,0)).is_empty():
				push_error("Original actor radius must reject a distant point")
				fail_check()
				return
			for group in surface_model.collision.groups:
				for record in group:
					var actor_hit: Dictionary = collision.actor_surface(record,Vector2i.ZERO,0,source_actor.source_scale,0,quarter)
					if not actor_hit.is_empty():
						actor_records.append(actor_hit)
			var contacts: Dictionary = collision.select_actor_contacts([actor_records],1177)
			if contacts.lower.get("height_units",0) != 1177 or not contacts.upper.is_empty():
				push_error("Imported stump-lid records must select their original top contact above the lid")
				fail_check()
				return
			if underside.get("height_units",0) != 870 or not collision.actor_surface(surface_model.collision.groups[1][0],Vector2i(4096,4096),0,Vector3i(4096,4096,4096),0,quarter).is_empty():
				push_error("Original underside must use reversed halfplane inclusion")
				fail_check()
				return
			if hit.get("height_units",0) != 1177 or not preload("res://source_collision.gd").surface(surface_model.collision.groups[0][0],Vector2i(4096,4096)).is_empty():
				push_error("Imported STUMPLID surface must retain its source height and halfplane bounds")
				fail_check()
				return
		if source_actor.source_name == "PlatformCheat1":
			scripted_platform = source_actor.vm.status == "yielded" and source_actor.vm.fault.is_empty()
		if source_actor.source_name == "PlatformDead":
			scripted_dead_platform = source_actor.vm.status == "yielded" and source_actor.vm.fault.is_empty() and int(source_actor.vm.parameters[7]) > 0
		if source_actor.source_name == "Gobbo":
			source_gobbo = source_actor
	if not scripted_lid:
		push_error("SmashLid source initializer must select and scale its real model")
		fail_check()
		return
	if not scripted_platform:
		push_error("Source platform must wait in its original player-contact loop")
		fail_check()
		return
	if not scripted_dead_platform:
		push_error("PlatformDead must execute its source wobble and vertical movement loop")
		fail_check()
		return
	if room.runtime_tables.get("wobble",{}).get("verticalDeltas",[]).size() != 60:
		push_error("The selected backup's runtime motion table must be imported")
		fail_check()
		return
	var original_position: Vector3 = source_gobbo.position
	source_gobbo.position.y = roundi(original_position.y / room.CELL_METERS * 4096.0) * room.CELL_METERS / 4096.0
	var original_units := roundi(source_gobbo.position.y / room.CELL_METERS * 4096.0)
	var original_params: Array = source_gobbo.vm.parameters.duplicate()
	var machine = preload("res://asl_vm.gd").new()
	machine.configure({"instructions":[]},0,source_gobbo,original_params)
	machine.parameters.resize(8)
	machine.parameters[7] = 0
	var total_delta := 0
	for step in range(60):
		var before := roundi(source_gobbo.position.y / room.CELL_METERS * 4096.0)
		var expected: int = int(room.runtime_tables.wobble.verticalDeltas[step])
		if source_gobbo.asl_command({"op":148,"args":[29,7]},machine) != "continue" or machine.parameters[7] != step + 1:
			fail_check()
			return
		if roundi(source_gobbo.position.y / room.CELL_METERS * 4096.0) - before != expected:
			push_error("Wobble must apply the exact imported vertical delta")
			fail_check()
			return
		total_delta += expected
	if roundi(source_gobbo.position.y / room.CELL_METERS * 4096.0) - original_units != total_delta:
		fail_check()
		return
	source_gobbo.asl_command({"op":148,"args":[29,7]},machine)
	if machine.parameters[7] != 1:
		fail_check()
		return
	machine.globals[123] = -1
	source_gobbo.asl_command({"op":148,"args":[2,123]},machine)
	if machine.globals[123] != 1:
		push_error("Negative wobble counters must wrap using the unsigned source comparison")
		fail_check()
		return
	machine.globals.erase(123)
	machine.parameters = original_params
	source_gobbo.position = original_position
	var starting_units := roundi(original_position.y / room.CELL_METERS * 4096.0)
	source_gobbo.asl_command({"op":39,"args":[[{"op":4,"value":655},{"op":18}]]},machine)
	if roundi(source_gobbo.position.y / room.CELL_METERS * 4096.0) != starting_units - 40:
		push_error("MoveDown must use the original arithmetic shift to 4.12 units")
		fail_check()
		return
	source_gobbo.asl_command({"op":41,"args":[[{"op":4,"value":655},{"op":18}]]},machine)
	if roundi(source_gobbo.position.y / room.CELL_METERS * 4096.0) != starting_units:
		fail_check()
		return
	source_gobbo.position = original_position
	var clip_handle: int = source_gobbo.asl_asset({"kind":3,"name":"GOBBO1.ANI"},source_gobbo.vm)
	if not source_gobbo.select_animation(clip_handle,true):
		push_error("Gobbo animation must bind all twelve imported limb matrices")
		fail_check()
		return
	source_gobbo.clip_speed_offset = 65408
	source_gobbo.advance_animation()
	if source_gobbo.clip_frame != 0 or source_gobbo.clip_fraction != 128:
		push_error("Half-speed actor animation must retain fractional ticks")
		fail_check()
		return
	source_gobbo.advance_animation()
	if source_gobbo.clip_frame != 1 or source_gobbo.clip_fraction != 0:
		fail_check()
		return
	source_gobbo.select_animation(clip_handle,true)
	source_gobbo.clip_speed_offset = 256
	source_gobbo.advance_animation()
	if source_gobbo.clip_frame != 2 or source_gobbo.mesh_parts.size() != 12:
		fail_check()
		return
	for i in range(int(source_gobbo.clip.frameCount)):
		source_gobbo.advance_animation()
	if source_gobbo.clip_playing or source_gobbo.clip_frame != int(source_gobbo.clip.frameCount) - 1:
		fail_check()
		return
	if not room.play_named_sound("CRYS",room.actor.global_position):
		push_error("Original crystal sound must load and start through the native audio path")
		fail_check()
		return
	var initial: Vector3 = room.actor.position
	Input.action_press("jump")
	for i in range(10):
		await physics_frame
	Input.action_release("jump")
	if room.actor.position.y <= initial.y + 0.4:
		push_error("Jump must work against imported geometry")
		fail_check()
		return
	if not room.load_room("MP010_01.MAP"):
		fail_check()
		return
	for i in range(90):
		await physics_frame
	if not room.actor.is_on_floor():
		push_error("Second imported room must support the actor")
		fail_check()
		return
	if room.terrain_surfaces_at(room.actor.position).is_empty():
		push_error("Room transition must replace source terrain-query geometry")
		fail_check()
		return
	if room.source_floor_at(room.actor.position).is_empty():
		push_error("Source fallback must find the second-room floor")
		fail_check()
		return
	print("PASS: imported rooms, terrain collision, source world surfaces and rotations, jump, actor animation and wobble")
	room.stop_imported_audio()
	await process_frame
	quit(0)

func fail_check() -> void:
	push_error('Imported verification check failed: ' + str(get_stack()))
	quit(1)
