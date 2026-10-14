extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8,8)
	viewport.own_world_3d = true
	viewport.use_hdr_2d = OS.get_cmdline_user_args().has("--hdr")
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	viewport.add_child(environment)
	var node := MeshInstance3D.new()
	viewport.add_child(node)
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_cutscene_gpu_material.gdshader")
	material.set_shader_parameter("source_vertical_offset",0.0)
	material.set_shader_parameter("source_ordered_depth",false)
	node.material_override = material
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color8(8,8,8,255))
	material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(image))
	var math = preload("res://source_gpu_color.gd")
	var differences := 0
	var maximum := 0
	var samples: Array = [[65,Vector3i(128,128,128),Vector3i.ONE],[65,Vector3i(127,127,127),Vector3i.ONE],[257,Vector3i(128,128,128),Vector3i.ONE],[64,Vector3i(8,8,8),Vector3i.ONE]]
	if OS.get_cmdline_user_args().has("--sweep"):
		samples.clear()
		for texture in [0,1,7,15,30,31]:
			for intensity in [0,8,64,127,128,129,255]:
				for flags in [65,1,257,64,0,33]: samples.append([flags,Vector3i(intensity,(intensity*5)&255,255-intensity),Vector3i(texture,(texture*3)&31,31-texture)])
	# Untextured primitives ignore the atlas, including its transparent texels.
	samples.append([96,Vector3i(128,64,192),Vector3i.ZERO,0])
	for sample in samples:
		var texture5: Vector3i = sample[2]
		var color8: Vector3i = sample[1]
		image.fill(Color8(roundi(float(texture5.x)*255.0/31.0),roundi(float(texture5.y)*255.0/31.0),roundi(float(texture5.z)*255.0/31.0),int(sample[3]) if sample.size() > 3 else 255))
		material.set_shader_parameter("atlas_texture",ImageTexture.create_from_image(image))
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
		for point in [Vector3(-4,-4,-1),Vector3(4,-4,-1),Vector3(4,4,-1),Vector3(-4,-4,-1),Vector3(4,4,-1),Vector3(-4,4,-1)]:
			surface.set_color(Color(float(color8.x)/255.0,float(color8.y)/255.0,float(color8.z)/255.0,0))
			surface.set_custom(0,Color(float(sample[0]),0,0,0))
			surface.set_uv(Vector2(0.5,0.5)); surface.add_vertex(point)
		node.mesh = surface.commit()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var output := viewport.get_texture().get_image()
		for y in range(8):
			for x in range(8):
				var pixel := output.get_pixel(x,y)
				if viewport.use_hdr_2d: pixel = pixel.linear_to_srgb()
				var flags := int(sample[0])
				var textured := (flags&1) != 0
				var modulate := (flags&256) == 0
				var dither := math.dither_at(x,y) if (flags&64) == 0 or (textured and modulate) else 0
				var values := Vector3i(pixel.r8,pixel.g8,pixel.b8)
				for channel in range(3):
					var expected := roundi(float(math.channel(texture5[channel],color8[channel],textured,modulate,dither))*255.0/31.0)
					var delta := absi(values[channel]-expected)
					if delta != 0: differences += 1
					maximum = maxi(maximum,delta)
	viewport.queue_free(); await process_frame
	print("GPU_COLOR_REFERENCE: ",{"different_samples":differences,"maximum_byte_error":maximum,"hdr":OS.get_cmdline_user_args().has("--hdr"),"cases":samples.size(),"channels_checked":samples.size()*64*3})
	quit(0 if differences == 0 else 1)
