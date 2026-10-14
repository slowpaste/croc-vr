extends SceneTree
const Collision = preload("res://source_collision.gd")
var failures := 0

func hit(height: int, underside: bool = false, actor: int = 0) -> Dictionary:
	return {"height_units":height,"flags":12 if underside else 4,"actor":actor}

func check(condition: bool) -> void:
	if not condition:
		failures += 1
		push_error("Source actor contact selection check failed")

func _initialize() -> void:
	check(Collision.lower_sample_guard(0,0x1000,-1,-1,4))
	check(not Collision.lower_sample_guard(1,0x1000,0,0,4))
	check(not Collision.lower_sample_guard(0,0x1000,0,1,4))
	var edge_state := {"status":0,"ground":{"mode":1,"height_units":100,"surface_type":128}}
	var transitioned := Collision.movement_edge_transition(edge_state,4,{"tile":298,"record":65537},7,true)
	check(transitioned.status == 0x201 and transitioned.ground.mode == 5 and transitioned.ground.actor == 42 and transitioned.ground.record == 1 and transitioned.ground.height_units == 100)
	check(Collision.movement_edge_transition(edge_state,8,{},263,true).ground == {"mode":10,"height_units":100,"surface_type":128,"actor":7,"record":0})
	edge_state.status = 1
	check(Collision.movement_edge_transition(edge_state,4,{},0,true) == edge_state)
	check(Collision.actor_push_probe_clear({}, {},0))
	check(Collision.actor_push_probe_clear({"height_units":0,"surface_type":10},hit(32),0))
	check(not Collision.actor_push_probe_clear({"height_units":1,"surface_type":10},{},0))
	check(not Collision.actor_push_probe_clear({"height_units":0,"surface_type":9},{},0))
	check(not Collision.actor_push_probe_clear({},hit(33),0))
	check(Collision.actor_push_probes([],0).move_owner)
	check(Collision.actor_push_probes([{}, {"actor_lower":hit(33)},{}],0) == {"move_owner":false,"tested":2,"failed_probe":1})
	check(Collision.actor_wall_post_state(1,0,1,0,1023,1).status == 0xa00)
	check(Collision.actor_wall_post_state(1,0,1,0,1024,1).status == 0x800)
	check(Collision.actor_wall_post_state(1,0x100,1,0,0,1).status == 0x800)
	check(Collision.actor_wall_post_state(1,0,1,0,0,2).status == 0x800)
	check(Collision.actor_wall_post_state(0x1000001,0,0x80000001,0,0,1).special_response)
	check(not Collision.actor_wall_post_state(0x1000001,0,0x80000001,0,0,1).write_contact_owner)
	check(Collision.actor_wall_post_state(1,0,1,0,0,0,0x200).status == 0xa00)
	check(not Collision.actor_wall_entry(hit(256),{},0))
	check(Collision.actor_wall_entry(hit(257),{},0))
	check(not Collision.actor_wall_entry(hit(1024),{"surface_type":5},0))
	check(Collision.actor_wall_entry(hit(1024),{"surface_type":4},0))
	check(not Collision.upper_wall_entry(hit(1024),{},0))
	check(Collision.upper_wall_entry(hit(1023),hit(500),0))
	check(not Collision.upper_wall_entry(hit(756),hit(500),0))
	check(Collision.upper_wall_entry(hit(756),{},0))
	check(not Collision.upper_wall_entry({},hit(0),0))
	check(not Collision.fresh_wall_entry({"surface_type":0,"height_units":256},0,0).blocked)
	check(Collision.fresh_wall_entry({"surface_type":0,"height_units":257},0,0).blocked)
	check(not Collision.fresh_wall_entry({"surface_type":13,"height_units":512},0,0).blocked)
	check(Collision.fresh_wall_entry({"surface_type":14,"height_units":513},0,0).blocked)
	check(Collision.fresh_wall_entry({"surface_type":7,"height_units":1},0,0).blocked)
	check(not Collision.fresh_wall_entry({"surface_type":7,"height_units":1},0,1).blocked)
	var slope: Array = []
	slope.resize(22)
	slope.fill(0)
	slope[18] = 256
	check(Collision.upper_slope_wall_delta({"halfwords":slope},0,924).delta == Vector2i(100,0))
	slope[18] = -256
	check(Collision.upper_slope_wall_delta({"halfwords":slope},0,924).delta == Vector2i(-100,0))
	check(not Collision.upper_slope_wall_delta({"halfwords":slope},0,1024).projected)
	slope[18] = 4096
	check(not Collision.upper_slope_wall_delta({"halfwords":slope},0,924).projected)
	slope[18] = 4096
	check(Collision.slope_wall_delta({"halfwords":slope},0,356,256).delta == Vector2i(-6,0))
	slope[18] = 0
	slope[19] = -4096
	check(Collision.slope_wall_delta({"halfwords":slope},0,356,256).delta == Vector2i(0,6))
	slope[19] = 16384
	check(not Collision.slope_wall_delta({"halfwords":slope},0,356,256).projected)
	check(Collision.wall_project(Vector2i(-100,0),Vector2i(4096,0),-100).position == Vector2i(25,0))
	check(Collision.wall_project(Vector2i(0,100),Vector2i(0,4096),-100).position == Vector2i(0,-25))
	check(Collision.wall_project(Vector2i(-1,0),Vector2i(4096,0),-1).position == Vector2i(1,0))
	check(Collision.wall_project(Vector2i(5,6),Vector2i(63,0),-100).position == Vector2i(5,6))
	check(Collision.wall_intersection(Vector2i.ZERO,Vector2i(4096,0),0,Vector2i(0,4096),0,-100).position == Vector2i(25,-25))
	check(Collision.wall_intersection(Vector2i(1,2),Vector2i(4096,0),0,Vector2i(4096,0),0,-100).position == Vector2i(1,2))
	check(Collision.wall_intersection(Vector2i.ZERO,Vector2i(1,0),524288,Vector2i(0,-4096),0,0).has("fault"))
	var plane: Array = []
	plane.resize(22)
	plane.fill(0)
	plane[1] = 0x110
	plane[2] = 4096
	var wall := {"halfwords":plane}
	plane[1] = 1
	var actor_wall := Collision.solve_actor_wall(wall,Vector2i(-200,0),Vector2i(-1,0),356)
	check(actor_wall.delta == Vector2i(213,0) and actor_wall.edges == [0] and actor_wall.ground_override == 356)
	check(Collision.solve_actor_wall(wall,Vector2i(-200,0),Vector2i.ZERO,356).edges.is_empty())
	plane[1] = 0x100
	check(Collision.solve_actor_wall(wall,Vector2i(-200,0),Vector2i(-1,0),356).edges.is_empty())
	plane[1] = 3
	plane[7] = 4096
	actor_wall = Collision.solve_actor_wall(wall,Vector2i(-200,200),Vector2i(-1,1),356)
	check(actor_wall.delta == Vector2i(213,-213) and actor_wall.angle_edge == 1)
	plane[7] = 0
	plane[1] = 1
	check(Collision.solve_upper_opposite_wall(wall,Vector2i(200,0),Vector2i(100,0)).delta == Vector2i(-250,0))
	check(Collision.solve_upper_opposite_wall(wall,Vector2i(200,0),Vector2i(-1,0)).edges.is_empty())
	check(Collision.solve_upper_opposite_wall(wall,Vector2i(200,0),Vector2i.ZERO).edges == [0])
	plane[1] = 0x100
	check(Collision.solve_upper_opposite_wall(wall,Vector2i(200,0),Vector2i(100,0)).edges.is_empty())
	plane[1] = 0x110
	check(Collision.upper_wall_route(0,0,true) == 1)
	check(Collision.upper_wall_route(-1,0,false) == 2)
	check(Collision.upper_wall_route(0,1,false) == 2)
	check(Collision.upper_wall_route(0,0,false) == 3)
	var upper_wall := Collision.solve_upper_cached_wall(wall,Vector2i(100,0))
	check(upper_wall.delta == Vector2i(-125,0) and upper_wall.edges == [0])
	check(Collision.solve_upper_cached_wall(wall,Vector2i(-100,0)).edges.is_empty())
	check(Collision.solve_upper_cached_wall(wall,Vector2i.ZERO).edges == [0])
	plane[1] = 0x300
	plane[7] = 4096
	upper_wall = Collision.solve_upper_cached_wall(wall,Vector2i(100,-100))
	check(upper_wall.delta == Vector2i(-125,125) and upper_wall.angle_edge == 1)
	plane[7] = 0
	plane[1] = 0x110
	# Ignore other edges by making their enable-only bit patterns match the skip gate.
	plane[1] |= 0x600
	var rear := Collision.solve_opposite_wall(wall,Vector2i(-200,0),Vector2i(-100,0),356,0)
	check(rear.delta == Vector2i(213,0) and rear.contacts == 1 and rear.status == 0x200 and rear.ground_override == 356)
	check(Collision.solve_opposite_wall(wall,Vector2i(-200,0),Vector2i(-100,0),1024,0).status == 0)
	plane[1] = 0x730
	plane[7] = 4096
	rear = Collision.solve_opposite_wall(wall,Vector2i(-200,200),Vector2i(-100,100),356,0)
	check(rear.delta == Vector2i(213,-213) and rear.contacts == 2 and rear.status == 0 and rear.angle_edge == 1)
	plane[7] = 0
	plane[1] = 0x100
	check(Collision.solve_opposite_wall(wall,Vector2i.ZERO,Vector2i.ZERO,0,0).delta == Vector2i.ZERO)
	plane[1] = 0x110
	check(Collision.fresh_wall_route(wall,2,0,0,true) == 1)
	check(Collision.fresh_wall_route(wall,-1,0,0,false) == 2)
	check(Collision.fresh_wall_route(wall,2,7,0,false) == 2)
	check(Collision.fresh_wall_route(wall,2,0,1,false) == 2)
	check(Collision.fresh_wall_route(wall,2,0,0,false) == 3)
	plane[1] = 0xa0
	check(Collision.fresh_wall_route(wall,2,0,0,false) == 2)
	plane[1] = 0
	check(Collision.solve_cached_wall(wall,Vector2i.ZERO,1,false).edges.is_empty())
	check(not Collision.solve_cached_wall(wall,Vector2i.ZERO,1,true).edges.is_empty())
	plane[1] = 0x330
	plane[7] = 4096
	var solved := Collision.solve_cached_wall(wall,Vector2i(-100,100),0)
	check(solved.position == Vector2i(25,-25) and solved.delta == Vector2i(125,-125) and solved.edges == [0,1] and solved.status_set == 0x800 and solved.contact_bits == 4)
	solved = Collision.solve_cached_wall(wall,Vector2i.ZERO,0)
	check(solved.position == Vector2i.ZERO and solved.edges == [0,1] and solved.contact_bits == 0)
	plane[1] = 0
	check(Collision.solve_cached_wall(wall,Vector2i(-100,100),0).edges.is_empty())
	plane[1] = 0x110
	check(Collision.wall_plane_contact(wall,Vector2i.ZERO,0,0).distance == 0)
	check(Collision.wall_plane_contact(wall,Vector2i(-1,0),0,0).status_set == 0x800)
	check(Collision.wall_plane_contact(wall,Vector2i(1,0),0,0).is_empty())
	check(Collision.wall_plane_contact(wall,Vector2i.ZERO,0,0,0).is_empty())
	plane[1] = 0
	check(Collision.wall_plane_contact(wall,Vector2i.ZERO,0,0).is_empty())
	check(Collision.wall_plane_contact(wall,Vector2i.ZERO,0,1).distance == 0)
	check(Collision.wall_plane_contact(wall,Vector2i.ZERO,3,1).is_empty())
	plane[0] = 4
	check(Collision.wall_plane_contact(wall,Vector2i.ZERO,3,1).distance == 0)
	check(Collision.wall_plane_contact(wall,Vector2i(1048576,0),0,1).distance == 0)
	var fresh := {"tile":7,"record":8,"height_units":1025,"surface_type":9,"flags":4}
	var cached := {"tile":2,"record":65537}
	var prior := {"height_units":100,"surface_type":261}
	var fallback := Collision.movement_cache_fallback(fresh,cached,prior,0)
	check(fallback.terrain.tile == 2 and fallback.terrain.record == 1 and fallback.terrain.height_units == 100 and fallback.terrain.surface_type == 5 and fallback.terrain.flags == 4)
	check(Collision.movement_cache_fallback(fresh,{"tile":-2},prior,0).terrain == fresh)
	check(Collision.movement_cache_fallback(fresh,{"tile":-1},prior,0).terrain.is_empty())
	check(Collision.movement_cache_fallback(fresh,cached,prior,1).terrain == fresh)
	var cached_tail := Collision.movement_response_tail(0,fresh,{}, {},{},0,256,0,0,cached,prior)
	check(cached_tail.ground.height_units == 100 and cached_tail.lower_cache == {"tile":2,"record":1})
	var tail := Collision.movement_response_tail(0,{"height_units":100,"surface_type":128},{},{},{"height_units":800,"surface_type":5,"actor":298,"record":65537},0)
	check(tail.y == -224 and tail.ground.height_units == 100 and tail.ground.surface_type == 128 and tail.ground.mode == 10 and tail.ground.actor == 42 and tail.ground.record == 1)
	check(tail.status == 0x1100 and tail.ceiling_type == 5 and tail.actor_secondary_set == 0x40)
	tail = Collision.movement_response_tail(0,{}, {},{}, {"height_units":800,"surface_type":5,"actor":42},0)
	check(tail.ground.height_units == -40960 and tail.ground.mode == 10 and tail.ground.actor == 42)
	tail = Collision.movement_response_tail(0,hit(100),{}, {},{"height_units":800,"surface_type":4,"actor":42},0)
	check(tail.ground.mode == 9 and tail.ground.actor == 0)
	check(Collision.movement_ceiling(0,hit(512),{},0).y == 0)
	check(Collision.movement_ceiling(0,hit(513),{},0).y == -511)
	check(Collision.movement_ceiling(0,hit(1024),{},0).contact_bits == 0)
	check(Collision.movement_ceiling(0,hit(0),{},1).y == -1024)
	check(Collision.movement_ceiling(0,hit(-1024),{},1).contact_bits == 0)
	check(Collision.movement_ceiling(0,{},hit(256),0).actor_secondary_set == 0)
	var ceiling := Collision.movement_ceiling(0,{}, {"height_units":257,"surface_type":5,"actor":42},0,256,2,1)
	check(ceiling.y == -767 and ceiling.status == 0x1102 and ceiling.contact_bits == 9 and ceiling.actor == 42 and ceiling.actor_secondary_set == 0x40 and ceiling.force_actor_ground)
	# Actor correction changes Y before terrain's strict window is evaluated.
	ceiling = Collision.movement_ceiling(0,{"height_units":700,"surface_type":9},{"height_units":800,"surface_type":5,"actor":42},0)
	check(ceiling.y == -324 and ceiling.contact_bits == 12 and ceiling.surface_type == 9 and ceiling.force_actor_ground)
	check(Collision.choose_movement_ground({}, {},0) == {"mode":0,"surface_type":0,"height_units":-40960})
	check(Collision.choose_movement_ground({},hit(1024),0).mode == 2)
	check(Collision.choose_movement_ground({},hit(1025),0).mode == 0)
	check(Collision.choose_movement_ground(hit(2000),hit(1025),0).height_units == 2000)
	check(Collision.choose_movement_ground(hit(1000),hit(500),744).mode == 1)
	check(Collision.choose_movement_ground(hit(1000),hit(500),743).mode == 2)
	check(Collision.choose_movement_ground(hit(1000),hit(1000),744).mode == 2)
	check(Collision.choose_movement_ground({},hit(1000),744,256,8).mode == 10)
	check(Collision.choose_movement_ground(hit(1000),{},744,256,4).mode == 5)
	check(Collision.player_contact_flags(1,1) == {"actor":1,"player":1})
	check(Collision.player_contact_flags(0x10001,1) == {"actor":0x10001,"player":0x100001})
	check(Collision.player_contact_flags(0x10001,0x10000001) == {"actor":0x110001,"player":0x10000001})
	check(Collision.player_contact_flags(0x10001,0x40000001) == {"actor":0x10001,"player":0x40000001})
	check(Collision.player_contact_flags(0x10001,0x50000001) == {"actor":0x110001,"player":0x50000001})
	check(Collision.player_contact_flags(0x20001,0x40000001) == {"actor":0x120001,"player":0x40000001})
	check(Collision.player_contact_flags(0x4001,1) == {"actor":0x104001,"player":0x100001})
	check(Collision.player_contact_flags(0x4001,0x40000001) == {"actor":0x104001,"player":0x40000001})
	check(Collision.player_contact_flags(0x80034001,0x80000001) == {"actor":-2146222079,"player":-2146435071})
	var flags := Collision.platform_contact_flags(1,0x30,0x40800,2,0,0)
	check(flags == {"primary":0x400001,"secondary":0x270})
	check(Collision.platform_contact_flags(1,0x30,0x40800,0,0,0) == {"primary":1,"secondary":0x30})
	check(Collision.platform_contact_flags(1,0x30,0x800,0,0x100,5).secondary == 0x230)
	check(Collision.platform_contact_flags(1,0x30,0x800,0,0x100,4).secondary == 0x30)
	check(Collision.platform_motion_allowed(Vector3i(100,200,300),Vector3i.ZERO))
	check(not Collision.platform_motion_allowed(Vector3i(2049,0,0),Vector3i.ZERO))
	check(not Collision.platform_motion_allowed(Vector3i(2048,0,0),Vector3i.ZERO))
	check(Collision.platform_motion_allowed(Vector3i(1183,1183,1183),Vector3i.ZERO))
	check(not Collision.platform_motion_allowed(Vector3i(1184,1184,1184),Vector3i.ZERO))
	check(Collision.platform_translation(Vector3i(10,20,30),Vector3i(100,200,300),Vector3i.ZERO,false) == Vector3i(110,20,330))
	check(Collision.platform_translation(Vector3i(10,20,30),Vector3i(100,200,300),Vector3i.ZERO,true) == Vector3i(110,220,330))
	var base := {"mode":2,"height_units":100,"surface_type":9}
	var sampled := [{"terrain":hit(200),"actor_lower":hit(300)},{"terrain":hit(900)}]
	var refined := Collision.refine_ground_points(base,sampled,300,true)
	check(refined.height_units == 300 and refined.mode == 1 and refined.surface_type == 9)
	check(Collision.refine_ground_points(base,sampled,1000,true).height_units == 900)
	check(Collision.refine_ground_points(base,sampled,1000,false) == base)
	check(Collision.refine_ground_points(base,[],1000,true).mode == 1)
	check(Collision.refine_ground_points(base,[{"terrain":hit(50)}],1000,true).height_units == 100)
	check(Collision.choose_ground({}, {},0) == {"mode":0,"surface_type":0,"height_units":-65536})
	check(Collision.choose_ground(hit(1000),{},0).mode == 1)
	check(Collision.choose_ground({},hit(500),0).mode == 2)
	check(Collision.choose_ground(hit(1000),hit(1500),1000).mode == 2)
	check(Collision.choose_ground(hit(1000),hit(500),1000).mode == 1)
	# Below terrain's biased height, the lower actor surface wins instead.
	check(Collision.choose_ground(hit(1000),hit(500),0).mode == 2)
	check(Collision.choose_ground(hit(1000),hit(1000),0).mode == 1)
	check(Collision.square_ir(4096) == 4096)
	check(Collision.square_ir(-32768) == 262144)
	check(Collision.square_ir(65537) == 0)
	check(Collision.actor_radius_contains(Vector2i(4095,0),4096))
	check(not Collision.actor_radius_contains(Vector2i(4096,0),4096))
	check(not Collision.actor_radius_contains(Vector2i(0,0),0))
	# Shift each square separately; small radii can collapse to zero.
	check(not Collision.actor_radius_contains(Vector2i.ZERO,63))
	check(Collision.actor_radius_contains(Vector2i(63,63),64))
	check(Collision.actor_radius_contains(Vector2i(65536,0),4096))
	# Record order wins within one actor, even when a preceding top is higher.
	var pair := Collision.select_actor_contacts([[hit(500),hit(100),hit(600,true)]],0)
	check(pair.lower.height_units == 100 and pair.upper.height_units == 600)
	# Across actors, compare against the selected raw height using clearance bias.
	pair = Collision.select_actor_contacts([[hit(100,false,1)],[hit(356,false,2)],[hit(357,false,3)]],0)
	check(pair.lower.actor == 3)
	pair = Collision.select_actor_contacts([[hit(100,false,1)],[hit(356,false,2)]],0)
	check(pair.lower.actor == 1)
	# An underside above y+1024 discards every candidate from that actor.
	pair = Collision.select_actor_contacts([[hit(500),hit(1025,true),hit(900)]],0)
	check(pair.lower.is_empty() and pair.upper.is_empty())
	pair = Collision.select_actor_contacts([[hit(500),hit(1024,true)]],0)
	check(pair.lower.height_units == 500 and pair.upper.height_units == 1024)
	# Upper contact must be above both the point and the previously selected lower.
	pair = Collision.select_actor_contacts([[hit(700)],[hit(600,true)],[hit(900,true)],[hit(800,true)]],0)
	check(pair.lower.height_units == 700 and pair.upper.height_units == 800)
	pair = Collision.select_actor_contacts([[hit(0,true)], [hit(-1,true)]],0)
	check(pair.upper.is_empty())
	# Preserve the source's order-sensitive upper-before-lower update.
	pair = Collision.select_actor_contacts([[hit(900),hit(800,true)]],0)
	check(pair.lower.height_units == 900 and pair.upper.height_units == 800)
	pair = Collision.select_actor_contacts([],0)
	check(pair.lower.is_empty() and pair.upper.is_empty())
	if failures == 0:
		print("PASS: actor record order, clearance bias, underside cutoff, upper selection and empty contacts")
	quit(1 if failures else 0)
