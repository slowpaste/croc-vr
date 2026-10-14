extends SceneTree
const Actor = preload("res://asl_actor.gd")
var failures := 0

func check(value: bool) -> void:
	if not value:
		failures += 1
		push_error("Collision state check failed")

func literal(value: int) -> Array:
	return [{"op":4,"value":value},{"op":18}]

func _initialize() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	if actor.source_point_caches.size() != 6 or actor.source_point_cache(5).lower.tile != -1 or actor.source_point_cache(5).upper.tile != -1:
		quit(1)
		return
	actor.store_source_movement_cache(6,{"tile":-1,"record":1},{"tile":-2,"record":2})
	if actor.source_field_180 != 131071 or actor.source_field_184 != 196606 or actor.source_point_cache(6).lower.tile != -1:
		quit(1)
		return
	actor.source_field_184 = -1
	if actor.source_point_cache(6).upper.record != 65535:
		quit(1)
		return
	if not actor.store_source_movement_cache(0,{"tile":65534,"record":65537},{"tile":65535,"record":131074}) or actor.source_point_caches[0] != {"lower":{"tile":-2,"record":1},"upper":{"tile":-1,"record":2}}:
		quit(1)
		return
	if actor.store_source_movement_cache(7,{"tile":0,"record":0},{"tile":0,"record":0}) or actor.store_source_movement_cache(0,{},{}) or actor.source_point_caches[0].lower.tile != -2:
		quit(1)
		return
	actor.primary_flags = 0x401
	if not actor.store_source_height_cache(0,{"tile":7,"record":8}) or actor.source_point_caches[0].upper != {"tile":-1,"record":2}:
		quit(1)
		return
	actor.store_source_height_cache(0,{})
	if actor.source_point_caches[0].lower != {"tile":-1} or actor.source_point_caches[0].upper.record != 2:
		quit(1)
		return
	actor.vm.pc = 100
	actor.asl_command({"op":88,"args":[200]},actor.vm)
	if actor.vm.pc != 200:
		quit(1)
		return
	actor.vm.pc = 100
	actor.asl_command({"op":89,"args":[200]},actor.vm)
	if actor.vm.pc != 100:
		quit(1)
		return
	actor.primary_flags = 0x201
	actor.asl_command({"op":88,"args":[200]},actor.vm)
	if actor.vm.pc != 100:
		quit(1)
		return
	actor.asl_command({"op":89,"args":[200]},actor.vm)
	if actor.vm.pc != 200:
		quit(1)
		return
	actor.primary_flags = 0x401
	actor.secondary_flags = 2
	actor.asl_command({"op":34,"args":[literal(-65537)]},actor.vm)
	if actor.source_rise_remaining != -2 or actor.source_vertical_speed != 261 or actor.primary_flags != 0x201 or actor.secondary_flags != 0:
		quit(1)
		return
	actor.asl_command({"op":35,"args":[]},actor.vm)
	if actor.primary_flags != 0x401 or actor.source_vertical_speed != 0:
		quit(1)
		return
	actor.asl_command({"op":115,"args":[]},actor.vm)
	actor.asl_command({"op":35,"args":[]},actor.vm)
	if actor.source_vertical_speed != 384:
		quit(1)
		return
	actor.asl_command({"op":76,"args":[]},actor.vm)
	if actor.primary_flags != 1 or actor.secondary_flags != 2 or actor.source_vertical_speed != 384:
		quit(1)
		return
	actor.asl_command({"op":118,"args":[]},actor.vm)
	if actor.secondary_flags != 0:
		quit(1)
		return
	actor.primary_flags = -2147483647
	if actor.asl_command({"op":113,"args":[]},actor.vm) != "continue" or actor.primary_flags != -2113929215:
		quit(1)
		return
	actor.asl_command({"op":113,"args":[]},actor.vm)
	actor.asl_command({"op":114,"args":[]},actor.vm)
	if actor.primary_flags != -2147483647:
		quit(1)
		return
	actor.primary_flags = 0x40028000
	var instructions := [
		{"pc":8,"op":83,"name":"CollisionOff","args":[literal(0x8000)],"next":16},
		{"pc":16,"op":105,"name":"PlayerCollisionOn","args":[],"next":17},
		{"pc":17,"op":126,"name":"SetCollPoint","args":[literal(7 << 16),literal(0x7fffffff),literal(-65537),literal(-2147483648)],"next":48},
		{"pc":48,"op":127,"name":"SetCollPoints","args":[literal(7 << 16)],"next":56},
		{"pc":56,"op":59,"name":"FileEnd","args":[],"next":57}]
	actor.vm.configure({"instructions":instructions},8,actor)
	check(actor.vm.run() == "finished")
	check(actor.primary_flags == 0x20006)
	check(actor.collision_points[6] == Vector3i(32767,-2,-32768))
	check(actor.collision_points[0] == Vector3i.ZERO and actor.collision_point_count == 7)
	actor.vm.configure({"instructions":[{"pc":8,"op":125,"name":"PlayerCollisionOff","args":[],"next":9},{"pc":9,"op":59,"name":"FileEnd","args":[],"next":10}]},8,actor)
	check(actor.vm.run() == "finished" and actor.primary_flags == 0x40020006)
	actor.vm.configure({"instructions":[{"pc":8,"op":126,"name":"SetCollPoint","args":[literal(0),literal(0),literal(0),literal(0)],"next":40}]},8,actor)
	check(actor.vm.run() == "unsupported" and actor.vm.pc == 8)
	actor.vm.configure({"instructions":[{"pc":8,"op":31,"name":"ScaleX","args":[literal(78643)],"next":16},{"pc":16,"op":32,"name":"ScaleY","args":[literal(-65537)],"next":24},{"pc":24,"op":59,"name":"FileEnd","args":[],"next":25}]},8,actor)
	check(actor.vm.run() == "finished" and actor.source_scale == Vector3i(4915,-4097,4096))
	actor.vm.configure({"instructions":[{"pc":8,"op":90,"name":"Scale","args":[literal(1048592)],"next":16},{"pc":16,"op":59,"name":"FileEnd","args":[],"next":17}]},8,actor)
	check(actor.vm.run() == "finished" and actor.source_scale == Vector3i.ONE)
	check(actor.collision_points[6] == Vector3i(32767,-2,-32768))
	actor.vm.configure({"instructions":[{"pc":8,"op":127,"name":"SetCollPoints","args":[literal(8 << 16)],"next":16}]},8,actor)
	check(actor.vm.run() == "unsupported" and actor.collision_point_count == 7)
	# Terrain/contact generation remains unsupported; setup alone is not collision.
	actor.vm.configure({"instructions":[{"pc":8,"op":82,"name":"CollisionOn","args":[literal(0x8000)],"next":16}]},8,actor)
	check(actor.vm.run() == "unsupported" and actor.vm.pc == 8)
	actor.primary_flags = 1
	actor.secondary_flags = 0x140
	actor.vm.configure({"instructions":[{"pc":8,"op":82,"name":"CollisionOn","args":[literal(0x20000)],"next":16},{"pc":16,"op":59,"name":"FileEnd","args":[],"next":17}]},8,actor)
	check(actor.vm.run() == "finished" and actor.primary_flags == 0x20007 and actor.secondary_flags == 0x100)
	if failures == 0:
		print("PASS: collision masks, player exclusion, signed point storage, slot bounds and explicit pending CollisionOn")
	quit(1 if failures else 0)
