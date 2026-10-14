extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var viewport := SubViewport.new();viewport.size = Vector2i(512,240)
	viewport.own_world_3d = true;viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera := Camera3D.new();camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 240.0;viewport.add_child(camera)
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	var material := ShaderMaterial.new();material.shader = preload("res://source_cutscene_screen_material.gdshader")
	material.set_shader_parameter("source_texture",ImageTexture.create_from_image(image))
	material.set_shader_parameter("source_black_level",0)
	var quad := QuadMesh.new();quad.size = Vector2(512,240)
	var screen := MeshInstance3D.new();screen.mesh = quad;screen.position.z = -1
	screen.material_override = material;viewport.add_child(screen)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	for y in [0,20,39,200,220,239]: assert(rendered.get_pixel(256,y).r < 0.01)
	for y in [40,120,199]: assert(rendered.get_pixel(256,y).r > 0.99)
	viewport.queue_free();await process_frame
	print("PASS: cinematic screen copies native Y40..199 while retaining black borders")
	quit(0)
