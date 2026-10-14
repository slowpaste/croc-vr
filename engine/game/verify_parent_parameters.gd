extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")

func _initialize() -> void:
	var world = World.new()
	world.source_pool.reset(128)
	var parent = Actor.new()
	var child = Actor.new()
	world.add_child(parent)
	world.add_child(child)
	parent.world = world
	child.world = world
	child.position = Vector3(3,6,9)
	parent.source_pool_id = world.source_pool.allocate({"node":parent})
	child.source_parent_id = parent.source_pool_id
	parent.position = Vector3(6,9,12)
	parent.source_angles = Vector3i(-1,1024,8193)
	parent.vm.parameters = [65536]
	parent.vm.globals[0] = 65536
	child.vm.configure({"instructions":[]},0,child,[0])
	if child.asl_command({"op":178,"args":[7,[{"op":4,"value":-2147483648},{"op":18}]]},child.vm) != "continue" or parent.vm.parameters.size() != 8 or parent.vm.parameters[7] != -2147483648 or child.vm.parameters != [0]:
		world.free()
		quit(1)
		return
	if child.vm.evaluate([{"op":45,"index":7},{"op":18}]) != -2147483648:
		world.free()
		quit(1)
		return
	parent.vm.parameters[7] = 0
	if child.vm.evaluate([{"op":1,"index":0},{"op":18}]) != 65536 or child.vm.evaluate([{"op":1,"index":7},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	parent.vm.globals[0] = 4294967295
	if child.vm.evaluate([{"op":1,"index":0},{"op":18}]) != -1:
		world.free()
		quit(1)
		return
	if child.asl_command({"op":55,"args":[3,[{"op":4,"value":4294967295},{"op":18}]]},child.vm) != "continue" or parent.vm.globals.get(3,0) != -1 or child.vm.globals.has(3):
		push_error("LetPGVar did not write only the parent's signed global word"); world.free(); quit(1); return
	parent.secondary_flags = 0x840; child.secondary_flags = 0x40
	if child.vm.evaluate([{"op":3,"index":79},{"op":18}]) != 0x800 or child.vm.evaluate([{"op":3,"index":78},{"op":18}]) != 0:
		push_error("Native parent/own secondary0x800 getters were conflated"); world.free(); quit(1); return
	if child.asl_command({"op":74,"args":[-1]},child.vm) != "continue" or child.source_shadow_type != 255 or child.secondary_flags != 0x40:
		push_error("ShadowType did not preserve its unsigned byte or changed unrelated flags"); world.free(); quit(1); return
	child.source_waypoints = [{"position":[0,0,0]},{"position":[1,0,0]}]
	if child.asl_command({"op":135,"args":[]},child.vm) != "continue" or child.source_waypoint_index != 1:
		world.free()
		quit(1)
		return
	child.asl_command({"op":135,"args":[]},child.vm)
	if child.source_waypoint_index != 0:
		world.free()
		quit(1)
		return
	var map_factors: Array = []
	map_factors.resize(25)
	map_factors.fill(512)
	map_factors[5] = 614
	world.runtime_tables = {"mapYScale":{"values":map_factors}}
	world.room_data = {"style":5}
	var placed = Actor.new()
	world.add_child(placed)
	var placement := {"name":"fixture","position":[-1.0/65536.0,1,-2],"rotation":[0,0,0],"params":[]}
	placed.configure(world,{"pc":0},{"instructions":[]},placement,[],false)
	if placed.source_render_position != Vector3i(-1,4912,-8192) or placed.source_spawn_y_units != 4912:
		world.free()
		quit(1)
		return
	placement.runtime_position = Vector3i(123,4096,456)
	placed.configure(world,{"pc":0},{"instructions":[]},placement,[],false)
	if placed.source_render_position != Vector3i(123,4096,456) or placed.position.y != 3.0:
		world.free()
		quit(1)
		return
	placed.position = Vector3.ZERO
	placed.source_angles = Vector3i(1,2,3)
	placed.asl_command({"op":29,"args":[]},placed.vm)
	if placed.position.y != 3.0 or placed.source_angles != Vector3i.ZERO:
		world.free()
		quit(1)
		return
	placed.source_angles = Vector3i(-1,1024,4097)
	placed.asl_command({"op":86,"args":[]},placed.vm)
	placed.position = Vector3.ZERO
	placed.source_angles = Vector3i.ZERO
	placed.source_scale = Vector3i(8192,4096,2048)
	placed.asl_command({"op":29,"args":[]},placed.vm)
	if placed.source_angles != Vector3i(-1,1024,4097) or placed.source_rotation_y != 1024 or placed.position.y != 3.0 or placed.source_scale != Vector3i(8192,4096,2048):
		world.free()
		quit(1)
		return
	child.source_waypoints[0] = {"position":[-1.0/65536.0,1,-2],"value":4294967295}
	for pair in [[30,-1],[31,4912],[32,-8192],[33,-1]]:
		if child.vm.evaluate([{"op":3,"index":pair[0]},{"op":18}]) != pair[1]:
			world.free()
			quit(1)
			return
	for index in [2,3,4]:
		if child.vm.evaluate([{"op":3,"index":index},{"op":18}]) != (index - 1) * 4096:
			world.free()
			quit(1)
			return
	child.asl_command({"op":56,"args":[2,[{"op":4,"value":-8192},{"op":18}]]},child.vm)
	if child.position.x != -6.0 or child.vm.evaluate([{"op":3,"index":2},{"op":18}]) != -8192:
		world.free()
		quit(1)
		return
	child.source_angles = Vector3i(-1,1024,8193)
	child.source_ground = {"height_units":-8192,"surface_type":0x181,"mode":1}
	child.source_wall_angle = -1
	child.source_movement_status = 65535
	child.source_ceiling_type = 0x105
	for pair in [[0,-8192],[1,129],[22,-65536],[23,-65536],[27,5],[77,1]]:
		if child.vm.evaluate([{"op":3,"index":pair[0]},{"op":18}]) != pair[1]:
			world.free()
			quit(1)
			return
	child.asl_command({"op":56,"args":[3,[{"op":3,"index":0},{"op":18}]]},child.vm)
	if child.position.y != -6.0:
		world.free()
		quit(1)
		return
	child.asl_command({"op":56,"args":[8,[{"op":4,"value":-17},{"op":18}]]},child.vm)
	if child.source_field_180 != -2 or (child.secondary_flags & 4) == 0 or child.vm.evaluate([{"op":3,"index":10},{"op":18}]) != -32:
		world.free()
		quit(1)
		return
	child.asl_command({"op":56,"args":[9,[{"op":4,"value":65536},{"op":18}]]},child.vm)
	if child.source_field_184 != 4096 or (child.secondary_flags & 8) == 0 or child.vm.evaluate([{"op":3,"index":9},{"op":18}]) != 65536:
		world.free()
		quit(1)
		return
	child.asl_command({"op":56,"args":[76,[{"op":4,"value":-17},{"op":18}]]},child.vm)
	child.asl_command({"op":56,"args":[75,[{"op":4,"value":524288},{"op":18}]]},child.vm)
	child.asl_command({"op":56,"args":[74,[{"op":4,"value":-33},{"op":18}]]},child.vm)
	if child.source_field_184 != -98304 or child.vm.evaluate([{"op":3,"index":75},{"op":18}]) != -524288 or child.vm.evaluate([{"op":3,"index":76},{"op":18}]) != -32 or child.vm.evaluate([{"op":3,"index":8},{"op":18}]) != -48 or (child.secondary_flags & 0x400) == 0:
		world.free()
		quit(1)
		return
	if child.vm.evaluate([{"op":3,"index":5},{"op":18}]) != (4095 << 16) or child.vm.evaluate([{"op":3,"index":7},{"op":18}]) != 65536:
		world.free()
		quit(1)
		return
	child.asl_command({"op":56,"args":[6,[{"op":4,"value":-65537},{"op":18}]]},child.vm)
	if child.source_rotation_y != 4094 or child.source_angles.y != 4094 or child.vm.evaluate([{"op":3,"index":6},{"op":18}]) != (4094 << 16):
		world.free()
		quit(1)
		return
	var expression := [{"op":45,"index":0},{"op":18}]
	for index in [51,52,53]:
		if child.vm.evaluate([{"op":3,"index":index},{"op":18}]) != (index - 49) * 4096:
			world.free()
			quit(1)
			return
	if child.vm.evaluate([{"op":3,"index":54},{"op":18}]) != (4095 << 16) or child.vm.evaluate([{"op":3,"index":56},{"op":18}]) != 65536:
		world.free()
		quit(1)
		return
	parent.position.x = -3
	if child.vm.evaluate([{"op":3,"index":51},{"op":18}]) != -4096:
		world.free()
		quit(1)
		return
	if child.vm.evaluate(expression) != 65536:
		world.free()
		quit(1)
		return
	parent.vm.parameters[0] = -131072
	if child.vm.evaluate(expression) != -131072 or child.vm.evaluate([{"op":45,"index":7},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	parent.vm.parameters[0] = 4294967295
	if child.vm.evaluate(expression) != -1:
		world.free()
		quit(1)
		return
	world.source_pool.release(parent.source_pool_id)
	if child.asl_command({"op":178,"args":[0,[{"op":4,"value":65536},{"op":18}]]},child.vm) != "unsupported":
		world.free()
		quit(1)
		return
	child.vm.evaluate(expression)
	if child.vm.status != "unsupported":
		world.free()
		quit(1)
		return
	child.vm.status = "ready"
	child.vm.fault = ""
	child.vm.evaluate([{"op":1,"index":0},{"op":18}])
	if child.vm.status != "unsupported":
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: source parent globals/parameters remain live, signed values, zero defaults and missing-parent failure")
	quit(0)
