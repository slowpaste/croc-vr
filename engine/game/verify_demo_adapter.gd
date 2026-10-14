extends SceneTree
const VM = preload("res://asl_vm.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.vr_controls.layout = "modern"
	for recording in world.manifest.demos:
		if not world.load_source_demo_recording(str(recording.name).replace(".DEM",".MAP")):
			quit(1)
			return
		world.update_source_input(0,0)
		for tick in range(900):
			var previous := int(world.source_input_held_mask)
			var expected := VM.signed32(int(world.source_demo_frames[tick]))
			if not world.sample_source_demo_controls(tick) or world.source_input_held_mask != expected or world.source_input_pressed_mask != VM.signed32((~previous)&expected) or world.source_input_released_mask != VM.signed32((~expected)&previous) or world.source_player_input_state != {"pad_mode":1} or world.jump_held != ((expected&0x800000) != 0):
				push_error("Recorded-input adapter changed source buttons or edges")
				quit(1)
				return
		if not world.sample_source_demo_controls(900) or world.source_input_held_mask != 0:
			quit(1)
			return
	world.queue_free()
	await process_frame
	print("PASS: all5400 recorded frames reach native input state unchanged, including edges and digital mode under Modern layout")
	quit(0)
