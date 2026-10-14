extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.source_main_mode = 1
	world.source_pickup_counts[3] = 99
	world.source_fade_overlay = preload("res://source_fade_overlay.gd").new()
	world.camera.add_child(world.source_fade_overlay)
	world.advance_source_main_menu_navigation(0x40000,0x40000)
	if world.source_menu_state.dialog_mode != 1:
		quit(1)
		return
	world.advance_source_main_menu_navigation(0x10000,0x10000)
	if world.source_menu_state.dialog_mode != 0:
		quit(1)
		return
	if not world.process_source_main_menu_confirmation(0) or world.source_fade_phase != "":
		quit(1)
		return
	if not world.process_source_main_menu_confirmation(0x200) or world.source_fade_phase != "new-game-out":
		quit(1)
		return
	for tick in range(35):
		if not world.process_source_main_menu_confirmation(0) or world.source_main_mode != 1 or world.source_pickup_counts[3] != 99:
			push_error("New Game reset occurred before original polygon transition readiness")
			quit(1)
			return
	if not world.process_source_main_menu_confirmation(0) or world.source_main_mode != 5 or world.source_pickup_counts[3] != 3 or world.map_name != "MP100_01.MAP" or world.source_fade_phase != "in":
		push_error("Original confirmed main-menu New Game transition failed")
		quit(1)
		return
	world.queue_free()
	await process_frame
	if not await preload("res://source_spu_stream_retirement.gd").drain(self):
		push_error("Main-menu confirmation audio did not retire");quit(1);return
	print("PASS: main-menu press edge, original star transition and deferred New Game reset/selector load")
	quit(0)
