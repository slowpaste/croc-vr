extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8,8); viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 8
	viewport.add_child(camera)
	var node := MeshInstance3D.new(); viewport.add_child(node)
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_cutscene_mask_material.gdshader")
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color(0,0,0,0))
	material.set_shader_parameter("source_mask_texture",ImageTexture.create_from_image(image))
	node.material_override = material
	for flags in [0x20,0x21]:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
		for point in [Vector3(-8,-8,-1),Vector3(8,-8,-1),Vector3(8,8,-1),Vector3(-8,-8,-1),Vector3(8,8,-1),Vector3(-8,8,-1)]:
			surface.set_custom(0,Color(float(flags),0,0,0)); surface.set_uv(Vector2(0.5,0.5))
			surface.set_uv2(Vector2(512,0)); surface.add_vertex(point)
		node.mesh = surface.commit()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var pixel := rendered.get_pixel(4,4)
		if flags == 0x20 and (pixel.r < 0.99 or pixel.g < 0.99): push_error("Untextured mask sampled transparent atlas"); quit(1); return
		if flags == 0x21 and pixel.a > 0.01: push_error("Textured transparent mask was not discarded"); quit(1); return
	viewport.queue_free(); await process_frame
	print("PASS: rendered untextured coverage ignores transparent atlas; textured coverage still discards it")
	quit(0)
