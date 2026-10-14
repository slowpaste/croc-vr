extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var option := args.find("--content")
	if option < 0: quit(1); return
	var content := str(args[option+1])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var world := preload("res://imported_main.gd").new()
	world.runtime_tables = JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	world.source_pool.reset(8)
	var caller := preload("res://asl_actor.gd").new(); world.add_child(caller)
	var target := preload("res://asl_actor.gd").new(); world.add_child(target)
	caller.world = world; caller.vm.host = caller
	target.source_pool_id = world.source_pool.allocate({"node":target})
	caller.source_reference_slots[0] = target.source_pool_id
	caller.source_angles = Vector3i(0,123,456); target.position = Vector3(3,3,0)
	assert(caller.asl_command({"op":6,"args":[0,[{"op":4,"value":16777216},{"op":18}]]},caller.vm) == "continue")
	assert(caller.source_angles == Vector3i(3840,123,456))
	target.position.y = -3; caller.source_angles.x = 0
	assert(caller.asl_command({"op":6,"args":[0,[{"op":4,"value":16777216},{"op":18}]]},caller.vm) == "continue")
	assert(caller.source_angles == Vector3i(256,123,456))
	target.position = Vector3(3,3,0)
	caller.source_angles = Vector3i(0,0,456)
	var yaw_rate := [{"op":4,"value":32<<16},{"op":18}]
	var pitch_rate := [{"op":4,"value":128<<16},{"op":18}]
	assert(caller.asl_command({"op":64,"args":[0,yaw_rate,pitch_rate]},caller.vm) == "continue")
	assert(caller.source_angles == Vector3i(3968,32,456))
	world.source_player_actor = target
	caller.source_angles = Vector3i(0,0,456)
	assert(caller.asl_command({"op":196,"args":[yaw_rate,pitch_rate]},caller.vm) == "continue")
	assert(caller.source_angles == Vector3i(3968,32,456))
	world.source_player_actor = null
	assert(caller.asl_command({"op":196,"args":[yaw_rate,pitch_rate]},caller.vm) == "unsupported")
	assert(caller.source_angles == Vector3i(3968,32,456))
	world.free()
	print("PASS: source pitch and combined aiming preserve angle tables, independent yaw/pitch rates, roll and registered-player targeting")
	quit(0)
