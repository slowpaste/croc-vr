extends SceneTree
func expression(value: int) -> Array:
	return [{"op":4,"value":value},{"op":18}]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args();var option := args.find("--content")
	if option < 0: quit(1);return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var world := preload("res://imported_main.gd").new()
	world.runtime_tables = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var actor := preload("res://asl_actor.gd").new();world.add_child(actor)
	actor.world = world;actor.vm.host = actor
	actor.source_angles = Vector3i(123,4090,456)
	var command := {"op":144,"args":[expression(65536),expression(-65536),expression(0),expression(20<<16)]}
	assert(actor.asl_command(command,actor.vm) == "continue")
	assert(actor.source_angles == Vector3i(123,14,456))
	# Evaluated target words are source pose units, not converted a second time.
	actor.position.x = 16*world.CELL_METERS;actor.source_angles.y = 0
	command.args[2] = expression(65536);command.args[3] = expression(4096<<16)
	assert(actor.asl_command(command,actor.vm) == "continue")
	assert(actor.source_angles == Vector3i(123,0,456))
	actor.position = Vector3.ZERO;actor.source_angles = Vector3i(0,0,456)
	command = {"op":138,"args":[expression(12288),expression(12288),expression(0),expression(32<<16),expression(128<<16)]}
	assert(actor.asl_command(command,actor.vm) == "continue")
	assert(actor.source_angles == Vector3i(3968,32,456))
	var player := preload("res://asl_actor.gd").new();world.add_child(player)
	world.source_player_actor = player;player.source_angles = Vector3i(0,1024,0)
	actor.position = Vector3(5,6,7)*world.CELL_METERS
	world.source_spawn_scratch.camera_query(0x80080f78)
	world.source_spawn_scratch.sound_header(0x429b0)
	assert(actor.asl_command({"op":145,"args":[expression(65536)]},actor.vm) == "continue")
	assert(world.source_spawn_scratch.pose().words == [0x20000000,0x04000000])
	assert(world.source_spawn_scratch.pose().writers == ["evaluator_s2","evaluator_s3"])
	assert(player.position.is_equal_approx(Vector3(world.CELL_METERS,0,0)))
	world.source_spawn_scratch.sound_header(123)
	assert(actor.asl_command({"op":146,"args":[expression(65536)]},actor.vm) == "continue")
	assert(player.position.is_equal_approx(Vector3.ZERO))
	assert(world.source_spawn_scratch.pose().words == [0x20000000,0x04000000])
	# Backward movement uses the full pitch/yaw/roll matrix, like the native
	# RotMatrix/ApplyMatrixLV path at288dc; negative distance reverses it.
	player.source_angles = Vector3i(512,1024,256)
	assert(actor.asl_command({"op":145,"args":[expression(65536)]},actor.vm) == "continue")
	var full_displacement: Vector3 = player.position
	assert(not is_zero_approx(full_displacement.y))
	assert(actor.asl_command({"op":146,"args":[expression(65536)]},actor.vm) == "continue")
	assert(player.position.is_equal_approx(Vector3.ZERO))
	assert(actor.asl_command({"op":146,"args":[expression(-65536)]},actor.vm) == "continue")
	assert(player.position.is_equal_approx(full_displacement))
	assert(actor.position == Vector3(5,6,7)*world.CELL_METERS)
	for movement in [36,37]:
		world.source_spawn_scratch.sound_header(0x429b0)
		assert(actor.asl_command({"op":movement,"args":[expression(0)]},actor.vm) == "continue")
		assert(world.source_spawn_scratch.pose().words == [0x20000000,0x04000000])
	actor.source_angles = Vector3i(123,1024,456)
	assert(actor.asl_command({"op":77,"args":[expression(4096),expression(8192),expression(12288)]},actor.vm) == "continue")
	var expected := actor.position+Vector3(3,2,-1)*world.CELL_METERS
	assert(player.position.is_equal_approx(expected))
	assert(actor.position == Vector3(5,6,7)*world.CELL_METERS)
	for op in [99,100,124]:
		assert(actor.asl_command({"op":op,"args":[]},actor.vm) == "continue")
	assert(actor.asl_command({"op":14,"args":["source diagnostic"]},actor.vm) == "continue")
	assert(player.position.is_equal_approx(expected))
	world.source_player_actor = null
	assert(actor.asl_command({"op":145,"args":[expression(65536)]},actor.vm) == "unsupported")
	assert(actor.asl_command({"op":146,"args":[expression(65536)]},actor.vm) == "unsupported")
	world.free()
	print("PASS: explicit target yaw/combined aiming preserves raw pose words, separate turn rates and roll")
	quit(0)
