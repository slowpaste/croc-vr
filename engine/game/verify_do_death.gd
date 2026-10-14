extends SceneTree
func _initialize() -> void:
	var world = preload("res://imported_main.gd").new()
	var actor = preload("res://asl_actor.gd").new();actor.world = world
	actor.position = Vector3(3,0,7)
	actor.vm.parameters = [0,11,22,33,44,55,66,77]
	var command := {"op":166,"pc":8,"args":[]}
	for tick in range(8):
		actor.vm.pc = 9
		assert(actor.asl_command(command,actor.vm) == "continue")
		assert(actor.vm.pc == 8 and actor.vm.parameters == [tick+1,11,22,33,44,55,66,77])
		assert(actor.vm.evaluate([{"op":29,"index":0},{"op":18}]) == tick+1)
	assert(is_equal_approx(actor.position.y,160.0*world.CELL_METERS/4096.0))
	assert(actor.position.x == 3 and actor.position.z == 7)
	actor.vm.pc = 9
	assert(actor.asl_command(command,actor.vm) == "continue" and actor.vm.pc == 9)
	actor.vm.parameters[0] = -1
	assert(actor.asl_command(command,actor.vm) == "continue" and actor.vm.pc == 9)
	assert(is_equal_approx(actor.position.y,160.0*world.CELL_METERS/4096.0))
	actor.free();world.free()
	print("PASS: DoDeath repeats eight source-unit rises, then advances; unsigned counter and X/Z remain exact")
	quit(0)
