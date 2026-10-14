extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.actor.position = Vector3(3,7,4)
	world.vr_camera_anchor_initialized = false
	world.update_vr_camera_anchor(0.1)
	assert(world.vr_camera_anchor == Vector3(3,7,4))
	world.source_camera_hold_counter = 1
	world.actor.position.y = 10
	world.update_vr_camera_anchor(0.1)
	assert(world.vr_camera_anchor.y > 8 and world.vr_camera_anchor.x == 3)
	var text = preload("res://source_menu_text_renderer.gd").new()
	root.add_child(text)
	text.configure_vr_panel(true)
	assert(text.position.z == -4 and text.text_material.get_shader_parameter("physical_panel"))
	assert(is_equal_approx(text.scale.x/text.scale.y,512.0/240.0))
	var results = preload("res://source_stage_stats_renderer.gd").new()
	root.add_child(results)
	results.configure_vr_panel(true)
	for sprite in [results.labels,results.track,results.shared]:
		assert(sprite.position.z == -4 and sprite.text_material.get_shader_parameter("physical_panel"))
	var dialog = preload("res://source_game_over_renderer.gd").new()
	root.add_child(dialog)
	dialog.configure_vr_panel(true)
	assert(dialog.labels.position.z == -4 and dialog.backdrop.position.z == -4)
	assert(dialog.clear.position.z == -4 and dialog.clear_material.get_shader_parameter("physical_panel"))
	dialog.configure_vr_panel(false)
	assert(dialog.labels.position == Vector3.ZERO and not dialog.labels.text_material.get_shader_parameter("physical_panel"))
	results.queue_free(); dialog.queue_free()
	var viewer := Camera3D.new()
	root.add_child(viewer)
	viewer.position = Vector3(4,2,8)
	viewer.rotation.y = PI
	var screen = preload("res://source_sequence_screen.gd").new()
	root.add_child(screen)
	screen.viewer_camera = viewer
	screen.reanchor()
	assert(screen.global_position.is_equal_approx(viewer.global_position-viewer.global_basis.z*2.5-Vector3(0,0.35,0)))
	assert(is_equal_approx(screen.screen.mesh.size.x/screen.screen.mesh.size.y,4.0/3.0))
	viewer.rotation.y = 0
	screen.reanchor()
	assert(screen.global_position.z < viewer.global_position.z)
	world.queue_free(); text.queue_free(); screen.queue_free(); viewer.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("PASS: elevated camera including held anchors, physical menu depth, 4:3 cinematic and reanchor")
	quit(0)
