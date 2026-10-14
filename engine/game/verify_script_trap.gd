extends SceneTree
func _initialize() -> void:
	var world = preload("res://imported_main.gd").new()
	world.source_pool.reset(4)
	var actor = preload("res://asl_actor.gd").new();world.add_child(actor)
	actor.world = world
	actor.source_pool_id = world.source_pool.allocate({"node":actor})
	world.source_actors.assign([actor])
	actor.source_name = "TrapFixture";actor.primary_flags = 0x1001
	actor.position = Vector3(3,4,5);actor.vm.pc = 124
	assert(actor.asl_command({"op":253,"pc":123,"args":[]},actor.vm) == "yield")
	assert(actor.vm.pc == 123 and actor.primary_flags == 0x1007)
	assert(actor.position == Vector3(3,4,5))
	var slot: int = actor.source_pool_id
	world.tick_source_actors()
	assert(not world.source_pool.slots.has(slot) and world.source_pool.free_slots.has(slot))
	world.free()
	print("PASS: source script trap preserves PC/pose, marks removal and is retired on the next source sweep")
	quit(0)
