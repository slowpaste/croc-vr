extends SceneTree
func _initialize() -> void:
	var world = preload("res://imported_main.gd").new()
	var actor = preload("res://asl_actor.gd").new()
	actor.world = world
	world.source_frame_clock.counter = 123456
	world.source_random.accumulator = 0x12345678
	world.source_random.draws = 42
	assert(actor.asl_command({"op":199,"args":[]},actor.vm) == "continue")
	assert(world.source_random.bios_seed == 123456)
	assert(world.source_random.accumulator == 0x12345678 and world.source_random.draws == 42)
	var first: int = world.source_random.bios_rand()
	assert(actor.asl_command({"op":199,"args":[]},actor.vm) == "continue")
	assert(world.source_random.bios_rand() == first)
	world.source_frame_clock.counter += 1
	assert(actor.asl_command({"op":199,"args":[]},actor.vm) == "continue")
	assert(world.source_random.bios_seed == 123457)
	actor.free();world.free()
	print("PASS: ReSeed restores the frame-seeded BIOS stream while preserving the source random accumulator")
	quit(0)
