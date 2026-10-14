extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
class QueryWorld extends World:
	var queries: Array[String] = []
	var floors: Array = []
	var lowers: Array = []
	var floor_index := 0
	var actor_index := 0
	func source_floor_at(_location: Vector3, _skip_type_17: bool = false) -> Dictionary:
		queries.append("floor")
		var result: Dictionary = floors[floor_index] if floor_index < floors.size() else {}
		floor_index += 1
		return result
	func source_contacts_at(_location: Vector3, _query_actor: Node3D = null, _clearance_units: int = 256) -> Dictionary:
		queries.append("actors")
		var result: Dictionary = lowers[actor_index] if actor_index < lowers.size() else {}
		actor_index += 1
		return {"lower":result,"upper":{}}
func _initialize() -> void:
	var world = QueryWorld.new()
	var owner = Actor.new()
	world.add_child(owner)
	var pairs: Array = []
	pairs.resize(4096)
	pairs.fill([0,4096]) # Only zero-angle identity entries are used in this fixture.
	world.runtime_tables = {"rotation":{"pairs":pairs}}
	owner.collision_point_count = 3
	owner.collision_points[1] = Vector3i(64,0,0)
	world.floors = [{},{"height_units":0,"surface_type":9},{}]
	var response := world.source_actor_push_probes(owner,Vector2i(10,20))
	if response.move_owner or response.tested != 2 or response.failed_probe != 1 or world.queries != ["floor","actors","floor","actors"] or response.probes[1].position != Vector3i(54,0,-20) or owner.position != Vector3.ZERO:
		world.free()
		quit(1)
		return
	world.queries.clear()
	var collision_math = preload("res://source_collision.gd")
	var pending := {"needs_push_probes":true,"world_delta":Vector2i(10,20),"rider_position":Vector3i(100,200,300),"forward":Vector3i(110,200,300),"opposite":Vector3i(90,200,300)}
	var resolved := collision_math.resolve_actor_push(pending,Vector3i.ZERO,response)
	if resolved.rider_position != Vector3i(110,200,320) or resolved.forward != Vector3i(64,0,0) or resolved.owner_position != Vector3i.ZERO:
		world.free()
		quit(1)
		return
	world.floor_index = 0
	world.actor_index = 0
	world.floors = [{"height_units":0,"surface_type":10}]
	world.lowers = [{"height_units":32}]
	owner.collision_point_count = 1
	if not world.source_actor_push_probes(owner,Vector2i.ZERO).move_owner:
		world.free()
		quit(1)
		return
	world.floor_index = 0
	world.actor_index = 0
	resolved = world.source_resolve_actor_push(pending,owner)
	if resolved.owner_position != Vector3i(-10,0,-20) or resolved.rider_position != pending.rider_position or resolved.forward != Vector3i(-10,0,-20) or resolved.needs_push_probes or owner.position != Vector3.ZERO:
		world.free()
		quit(1)
		return
	var quarter: Array = []
	quarter.resize(1025)
	quarter.fill(0)
	quarter[1024] = 4096 # These stage fixtures use only zero-angle axes.
	var angles: Array = []
	angles.resize(1025)
	angles.fill(0)
	world.runtime_tables.trigonometry = {"quarterSine":quarter}
	world.runtime_tables.wallAngles = {"values":angles}
	var halfwords: Array = []
	halfwords.resize(22)
	halfwords.fill(0)
	halfwords[1] = 1
	halfwords[2] = 4096
	owner.model_data = {"models":[{"collision":{"groups":[[{"halfwords":halfwords}],[]]}}]}
	world.source_pool.slots[42] = {"node":owner}
	world.lowers = [{"actor":42,"record":0,"height_units":356}]
	world.actor_index = 0
	var rider := Node3D.new()
	world.add_child(rider)
	var stage := {"actor_position":Vector3i(-100,0,0),"forward":Vector3i(-200,0,0),"opposite":Vector3i(-300,0,0),"sample_index":0,"primary":1,"status":0,"contact_bits":0,"ground_height":0,"lower":{"tile":-1}}
	var stage_result := world.source_actor_wall_stage(stage,rider)
	if stage_result.actor_position != Vector3i(113,0,0) or stage_result.contact_owner != 42 or owner.secondary_flags != 0x40:
		world.free()
		quit(1)
		return
	world.actor_index = 0
	stage.secondary = 0x1000
	stage.previous_mode = 8
	stage.contact_owner = 42
	stage_result = world.source_actor_wall_stage(stage,rider)
	if not stage_result.edge_transition or stage_result.actor_position != stage.actor_position:
		world.free()
		quit(1)
		return
	world.actor_index = 0
	stage.secondary = 0
	stage.primary = 0x80000001
	owner.primary_flags = 0x1000001
	owner.collision_point_count = 0
	stage_result = world.source_actor_wall_stage(stage,rider)
	if owner.position.x != -213.0*world.CELL_METERS/4096.0 or stage_result.actor_position != stage.actor_position:
		world.free()
		quit(1)
		return
	var platform_rider = Actor.new()
	world.add_child(platform_rider)
	platform_rider.world = world
	platform_rider.primary_flags = 0x40801
	platform_rider.secondary_flags = 2
	platform_rider.source_ground = {"mode":2,"height_units":100,"surface_type":0,"actor":42}
	owner.position = Vector3(100.0*world.CELL_METERS/4096.0,0,0)
	owner.previous_source_position = Vector3i.ZERO
	if not platform_rider.apply_source_platform_response() or roundi(platform_rider.position.x/world.CELL_METERS*4096.0) != 100 or (owner.primary_flags & 0x400000) == 0 or (owner.secondary_flags & 0x240) != 0x240:
		world.free()
		quit(1)
		return
	if not platform_rider.clear_source_platform_contact() or (owner.primary_flags & 0x400000) != 0 or (owner.secondary_flags & 0x200) != 0:
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: special actor probe construction, terrain/actor query order and first-failure stop")
	quit(0)
