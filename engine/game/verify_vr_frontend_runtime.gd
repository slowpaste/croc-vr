extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false); world.set_physics_process(false)
	world.xr_active = true # Exercise stereo placement without a physical headset.
	assert(world.refresh_source_main_menu_text())
	assert(world.source_main_menu_text.get_parent() == world.head)
	assert(world.source_main_menu_text.position.z == -4)
	world.source_continue_state = preload("res://source_main_menu.gd").initialize(0,1)
	assert(world.refresh_source_continue_screen())
	assert(world.source_game_over_renderer.get_parent() == world.head)
	assert(world.source_game_over_renderer.labels.position.z == -4)
	assert(world.source_game_over_renderer.labels.text_material.get_shader_parameter("physical_panel"))
	assert(world.refresh_source_game_over_screen())
	assert(world.source_game_over_renderer.backdrop.position.z == -4)
	assert(world.initialize_source_stage_stats())
	assert(world.source_stage_stats_renderer.get_parent() == world.head)
	for sprite in [world.source_stage_stats_renderer.labels,world.source_stage_stats_renderer.track,world.source_stage_stats_renderer.shared]:
		assert(sprite.position.z == -4)
		assert(sprite.text_material.get_shader_parameter("physical_panel"))
	world.queue_free()
	await process_frame
	print("PASS: live main menu, Continue/password and results use the four-metre stereo panel")
	quit(0)
