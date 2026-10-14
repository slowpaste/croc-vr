extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var panel = preload("res://source_menu_text_renderer.gd").new()
	camera.add_child(panel)
	panel.configure_vr_panel(true)
	var quad := QuadMesh.new(); quad.size = Vector2(2,2)
	panel.mesh = quad; panel.visible = true
	var pixels := Image.create(8,8,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	panel.text_material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(pixels))
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	var bright := 0
	for y in range(512):
		for x in range(512):
			if rendered.get_pixel(x,y).r > 0.8: bright += 1
	if bright < 10000 or bright > 150000:
		push_error("Four-metre panel is missing or fills the view: %d pixels" % bright)
		quit(1); return
	print("PASS: physical panel renders visibly with bounded viewing size (%d pixels)" % bright)
	quit(0)
