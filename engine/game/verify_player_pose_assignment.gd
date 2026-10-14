extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.sample_source_player_controls();world.tick_source_actors()
	var owner: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="DeathSlide":owner=actor;break
	assert(owner!=null and world.source_player_actor!=null)
	# Original room10/5 observer reads word16=4 at 80013f40.
	assert(int(world.room_data.flags)==4)
	assert(owner.vm.evaluate([{"op":3,"index":86},{"op":18}])==4)
	var room_data: Dictionary=world.room_data
	world.room_data=room_data.duplicate(true)
	world.room_data.flags=0x80000004
	assert(owner.vm.evaluate([{"op":3,"index":86},{"op":18}])==-2147483644)
	world.room_data=room_data
	var player: Node3D=world.source_player_actor
	var owner_position: Vector3=owner.position
	var owner_angles: Vector3i=owner.source_angles
	var primary: int=player.primary_flags
	var secondary: int=player.secondary_flags
	var velocity: int=player.source_vertical_speed
	for axis in range(3):
		var value: int=[-8192,12345,4097][axis]
		assert(owner.asl_command({"op":56,"args":[15+axis,[{"op":4,"value":value},{"op":18}]]},owner.vm)=="continue")
		assert(roundi(player.position[axis]/world.CELL_METERS*4096.0)==value)
		assert(owner.vm.evaluate([{"op":3,"index":15+axis},{"op":18}])==value)
	for axis in range(3):
		var value: int=[-65536,4097<<16,2048<<16][axis]
		assert(owner.asl_command({"op":56,"args":[18+axis,[{"op":4,"value":value},{"op":18}]]},owner.vm)=="continue")
		assert(player.source_angles[axis]==((value>>16)&4095))
	assert(player.source_rotation_y==player.source_angles.y)
	assert(owner.position==owner_position and owner.source_angles==owner_angles)
	assert(player.primary_flags==primary and player.secondary_flags==secondary and player.source_vertical_speed==velocity)
	world.source_player_actor=null
	assert(owner.asl_command({"op":56,"args":[15,[{"op":38}]]},owner.vm)=="unsupported")
	world.source_player_actor=player
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: actor script assigns registered-player position/angles with source units and wrapping; owner and player flags/velocity unchanged")
	quit(0)
