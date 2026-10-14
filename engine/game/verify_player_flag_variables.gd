extends SceneTree
func _initialize() -> void:
	var world := preload("res://imported_main.gd").new()
	var player := preload("res://asl_actor.gd").new(); world.add_child(player)
	var caller := preload("res://asl_actor.gd").new(); world.add_child(caller)
	world.source_player_actor = player; caller.world = world; caller.vm.host = caller
	caller.primary_flags = 0x600
	for flags in [0,0x200,0x400,0x600,-1,0x8000]:
		player.primary_flags = flags
		assert(caller.vm.evaluate([{"op":3,"index":49},{"op":18}]) == (flags&0x200))
		assert(caller.vm.evaluate([{"op":3,"index":50},{"op":18}]) == (flags&0x400))
	world.source_player_actor = null
	caller.vm.evaluate([{"op":3,"index":49},{"op":18}])
	assert(caller.vm.fault == "Missing source player flag owner")
	world.free()
	print("PASS: native variables49/50 read live registered-player masks0x200/0x400, independent of caller flags, and reject missing owner")
	quit(0)
