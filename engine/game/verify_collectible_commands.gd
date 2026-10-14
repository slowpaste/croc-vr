extends SceneTree
func _initialize() -> void:
	var world = preload("res://imported_main.gd").new()
	var actor = preload("res://asl_actor.gd").new()
	actor.world = world
	world.source_pickup_counts = {1:25,2:2,3:7}
	for op in [78,78,79,79]:
		assert(actor.asl_command({"op":op,"args":[]},actor.vm) == "continue")
		assert(world.source_key_collected == (1 if op == 78 else 0))
		assert(world.source_pickup_counts == {1:25,2:2,3:7})
	for expected in [1,0,0]:
		assert(actor.asl_command({"op":187,"args":[]},actor.vm) == "continue")
		assert(world.source_pickup_counts == {1:25,2:expected,3:7})
	actor.world = world
	assert(actor.asl_command({"op":204,"args":[]},actor.vm) == "continue")
	assert(world.source_gobbo_display_state == {"timer":390,"mode":0,"cursor":-1})
	world.source_gobbo_display_state.cursor = 123
	assert(actor.asl_command({"op":205,"args":[]},actor.vm) == "continue")
	assert(world.source_gobbo_display_state == {"timer":600,"mode":-1,"cursor":123})
	assert(world.source_pickup_counts == {1:25,2:0,3:7})
	actor.world = null
	for op in [78,79,187,204,205]:
		assert(actor.asl_command({"op":op,"args":[]},actor.vm) == "unsupported")
	actor.free();world.free()
	print("PASS: repeated key commands preserve boolean state; RemoveGobbo stops at zero and preserves gems/lives")
	quit(0)
