extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world); await process_frame
	world.set_process(false); world.set_physics_process(false)
	var binding: Dictionary = world.material_for_texture("TK00_ENM.BIN")
	assert(not binding.is_empty())
	var material: StandardMaterial3D = binding.material.duplicate()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if OS.get_cmdline_user_args().has("--legacy-colors"): material.vertex_color_is_srgb = false
	var bitmap := Image.create(2,1,false,Image.FORMAT_RGBA8)
	bitmap.set_pixel(0,0,Color.WHITE)
	bitmap.set_pixel(1,0,Color(91.0/255.0,179.0/255.0,0))
	material.albedo_texture = ImageTexture.create_from_image(bitmap)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64,32); viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 2
	viewport.add_child(camera)
	var fixture := {"vertices":[[-2,-1,-2],[0,-1,-2],[-2,1,-2],[0,1,-2],[0,-1,-2],[2,-1,-2],[0,1,-2],[2,1,-2]],"faces":[{"indices":[0,1,2,3],"flags":0,"color":[91,179,0],"material":0},{"indices":[4,5,6,7],"flags":17,"color":[0,0,0],"material":0}]}
	# geometry() converts source model units to meters.
	for point in fixture.vertices:
		for axis in range(3): point[axis] /= world.CELL_METERS
	var node := MeshInstance3D.new()
	node.mesh = world.geometry(fixture,{"width":2,"height":1,"polygons":[{"uv":[[0.75,0.5],[0.75,0.5],[0.75,0.5],[0.75,0.5]]}],"runtime_material":material})
	viewport.add_child(node)
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	var solid := rendered.get_pixel(16,16)
	var textured := rendered.get_pixel(48,16)
	var difference := Vector3(solid.r-textured.r,solid.g-textured.g,solid.b-textured.b).length()
	var valid := difference < 0.015 and textured.g > 0.5 and textured.r > 0.2
	print("PLAYER_COLOR_PIXELS: solid=",solid," textured=",textured," difference=",difference)
	if not valid: push_error("Solid player RGB and identical atlas RGB render differently")
	viewport.queue_free(); world.queue_free(); await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	if valid: print("PASS: original Croc green renders consistently across solid and textured faces")
	quit(0 if valid else 1)
