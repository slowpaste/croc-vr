extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var world = World.new()
	world.source_pool.reset(128)
	var parent = Actor.new()
	world.add_child(parent)
	parent.world = world
	parent.vm.parameters = [0,0,0,0,0,0,0,65536]
	parent.source_pool_id = world.source_pool.allocate({"node":parent})
	world.source_actors.append(parent)
	var slot := int(parent.source_pool_id)
	var child = Actor.new()
	world.add_child(child)
	child.world = world
	child.vm.host = child
	child.source_parent_id = slot
	if not world.remove_source_actor(parent) or child.vm.evaluate([{"op":45,"index":7},{"op":18}]) != 65536:
		push_error("Freed source parent slot lost inline parameter memory")
		quit(1)
		return
	if child.asl_command({"op":178,"args":[7,[{"op":4,"value":-65536},{"op":18}]]},child.vm) != "continue" or not child.asl_increment_parent_parameter(7,65536) or child.vm.evaluate([{"op":45,"index":7},{"op":18}]) != 0:
		quit(1)
		return
	var replacement = Actor.new()
	world.add_child(replacement)
	replacement.world = world
	replacement.vm.parameters = [0,0,0,0,0,0,0,123]
	replacement.source_pool_id = world.source_pool.allocate({"node":replacement})
	world.source_actors.append(replacement)
	if replacement.source_pool_id != slot or child.vm.evaluate([{"op":45,"index":7},{"op":18}]) != 123:
		push_error("Parent pointer did not observe source slot reuse")
		quit(1)
		return
	if not world.remove_source_actor(replacement) or child.vm.evaluate([{"op":45,"index":7},{"op":18}]) != 123:
		quit(1)
		return
	child.source_parent_id = 999
	child.vm.evaluate([{"op":45,"index":7},{"op":18}])
	if child.vm.fault == "":
		quit(1)
		return
	world.free()
	print("PASS: inline parent parameters survive removal, allow writes, follow slot reuse and reject unknown parents")
	quit(0)
