extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var target := SubViewport.new(); target.size = Vector2i(8,8); target.own_world_3d = true; target.use_hdr_2d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(target)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 2; target.add_child(camera)
	var quad := MeshInstance3D.new(); var shape := QuadMesh.new(); shape.size = Vector2(2,2); quad.mesh = shape; quad.position.z = -1; target.add_child(quad)
	var image := Image.create(1,1,false,Image.FORMAT_RGBAF); image.fill(Color(12.0/31.0,12.0/31.0,12.0/31.0).srgb_to_linear())
	var material := ShaderMaterial.new(); material.shader = preload("res://source_cutscene_screen_material.gdshader")
	material.set_shader_parameter("source_texture",ImageTexture.create_from_image(image)); quad.material_override = material
	for sample in [[0,0,12],[0,8,13],[0,64,20],[8,0,11],[64,0,4],[248,0,0],[0,248,31]]:
		material.set_shader_parameter("source_black_level",sample[0]); material.set_shader_parameter("source_white_level",sample[1])
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var output := target.get_texture().get_image()
		var actual := roundi(output.get_pixel(4,4).linear_to_srgb().r*31.0)
		if actual != int(sample[2]): push_error("Source white/black screen fade differs: "+str(sample)+" actual="+str(actual)); quit(1); return
	target.queue_free(); await process_frame
	print("PASS: rendered sequence screen uses RGB5 white addition/black subtraction, saturation and encoded-space levels")
	quit(0)
