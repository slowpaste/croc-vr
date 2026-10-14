extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var room = load("res://imported.tscn").instantiate()
	root.add_child(room)
	for i in range(120):
		await physics_frame
	room.set_physics_process(false)
	var parent: Node3D
	var left: Node3D
	var right: Node3D
	for actor in room.source_actors:
		if actor.source_name == "NormalDoor":
			parent = actor
		elif actor.source_name == "SquareDoorL":
			left = actor
		elif actor.source_name == "SquareDoorR":
			right = actor
	if parent == null or left == null or right == null:
		quit(1)
		return
	# This controlled door test must not select concurrent lava-particle audio.
	room.source_actors.assign([parent,left,right])
	room.stop_imported_audio()
	room.actor.position = parent.position + Vector3(room.CELL_METERS * 4,0,0)
	for i in range(80):
		room.tick_source_actors()
	var closed_left := int(left.source_rotation_y)
	var closed_right := int(right.source_rotation_y)
	if parent.vm.parameters[0] != 131072 or left.vm.parameters[0] != 0 or right.vm.parameters[0] != 0:
		quit(1)
		return
	room.actor.position = parent.position
	for i in range(80):
		room.tick_source_actors()
	if parent.vm.parameters[0] != 65536 or left.vm.parameters[0] != 131072 or right.vm.parameters[0] != 131072 or left.source_rotation_y != ((closed_left + 896) & 4095) or right.source_rotation_y != ((closed_right - 896) & 4095):
		push_error("Original door scripts must open both leaves through fourteen 64-unit turns")
		quit(1)
		return
	room.actor.position = parent.position + Vector3(room.CELL_METERS * 4,0,0)
	for i in range(80):
		room.tick_source_actors()
	if left.source_rotation_y != closed_left or right.source_rotation_y != closed_right or left.vm.parameters[0] != 0 or right.vm.parameters[0] != 0:
		push_error("Original door scripts must close back to their source headings")
		quit(1)
		return
	for actor in [parent,left,right]:
		if not actor.vm.fault.is_empty():
			quit(1)
			return
	if room.sound_voices.is_empty():
		push_error("Original door sound must start through its script command")
		quit(1)
		return
	var voice = room.sound_voices.back()
	if voice.player.pitch_register != 1028 or not is_equal_approx(voice.player.pitch_scale,1028.0*44100.0/4096.0/float(voice.player.stream.mix_rate)):
		push_error("Door pitch must preserve the source 2048+85*step SPU calculation")
		quit(1)
		return
	print("PASS: original door spawning, far/near distance state, opening turns, closing and fault-free scripts")
	room.stop_imported_audio()
	await process_frame
	var retirement := root.get_node("SourceSpuStreamRetirement")
	var deadline := Time.get_ticks_msec()+2000
	while not retirement.pending.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not retirement.pending.is_empty():push_error("Door sounds did not retire");quit(1);return
	quit(0)
