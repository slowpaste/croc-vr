extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	for frame in range(30):
		await physics_frame
	world.source_main_menu_animation_state.cooldown = 6
	if world.source_title_logo_state.positions[0].z <= 0 or world.source_title_logo_state.positions[0] != world.source_title_logo_state.positions[1]:
		push_error("Live title did not advance both original logo transforms")
		quit(1)
		return
	world.source_tick_count = 16
	if not world.refresh_source_title_prompt() or not world.source_main_menu_text.visible or world.source_main_menu_text.mesh.surface_get_array_len(0) != 60:
		push_error("Title blink-on phase did not draw the original ten glyphs")
		quit(1)
		return
	world.source_tick_count = 32
	if not world.refresh_source_title_prompt() or world.source_main_menu_text.visible:
		push_error("Title blink-off phase left the prompt visible")
		quit(1)
		return
	if world.source_main_mode != 0:
		push_error("Original rotating title scene did not enter mode0")
		quit(1)
		return
	Input.action_press("jump")
	for frame in range(8):
		await physics_frame
	Input.action_release("jump")
	if world.source_main_mode != 1 or world.source_menu_state.dialog_mode != 0 or int(world.source_main_menu_animation_state.cooldown) > 6 or world.source_main_menu_animation_state.sizes[0] != 65536 or world.source_fade_phase != "":
		quit(1)
		return
	for frame in range(30):
		await physics_frame
	if world.source_main_menu_text == null or not world.source_main_menu_text.visible or world.source_main_menu_text.mesh.surface_get_array_len(0) != 276:
		push_error("Live main menu did not draw the original46 glyphs")
		quit(1)
		return
	if world.source_title_logo_nodes.size() != 2 or not world.source_title_logo_nodes[0].visible or world.source_title_logo_nodes[0].get_parent() != world.camera:
		push_error("Original 3D title logo was not visible with the main menu")
		quit(1)
		return
	if world.source_title_effect_nodes.size() != 2 or int(world.source_title_effect_state.phase) == 0 or not world.source_title_effect_nodes[0].visible:
		push_error("Original title banner/trail did not activate with the logo")
		quit(1)
		return
	Input.action_press("move_back")
	for frame in range(8):
		await physics_frame
	Input.action_release("move_back")
	if world.source_menu_state.dialog_mode != 1:
		push_error("Physical main-menu down input failed")
		quit(1)
		return
	for frame in range(5):
		await physics_frame
	Input.action_press("move_forward")
	for frame in range(8):
		await physics_frame
	Input.action_release("move_forward")
	if world.source_menu_state.dialog_mode != 0:
		quit(1)
		return
	world.source_pickup_counts[3] = 99
	for frame in range(5):
		await physics_frame
	Input.action_press("jump")
	for frame in range(100):
		await physics_frame
	Input.action_release("jump")
	if world.source_main_mode != 5 or world.map_name != "MP100_01.MAP" or world.source_pickup_counts[3] != 3 or world.source_transition_fault != "":
		push_error("Physical main-menu confirm did not complete star transition to fresh selector")
		quit(1)
		return
	if not world.source_main_menu_text.visible or world.source_main_menu_text.rendered_labels != ["START LEVEL","OPTIONS","SAVE GAME","SHOW LEVEL PASSWORD",""]:
		push_error("Selector entry did not replace title glyphs with original selector action rows")
		quit(1)
		return
	for logo in world.source_title_logo_nodes:
		if logo.visible:
			push_error("Original logo remained visible after selector entry")
			quit(1)
			return
	for effect in world.source_title_effect_nodes:
		if effect.visible:
			push_error("Title effect remained visible after selector entry")
			quit(1)
			return
	world.queue_free()
	await process_frame
	print("PASS: main-menu entry reset, live sampled navigation and star-confirmed New Game to first island")
	quit(0)
