extends SceneTree
func _initialize() -> void: call_deferred("verify")
func color_texture(values: Vector3i, alpha: float = 1.0) -> ImageTexture:
	var image := Image.create(1,1,false,Image.FORMAT_RGBAH)
	var color := Color(float(values.x)/31.0,float(values.y)/31.0,float(values.z)/31.0,alpha).srgb_to_linear()
	image.fill(color)
	return ImageTexture.create_from_image(image)
func verify() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8,8); viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false; sprite.scale = Vector2(8,8)
	viewport.add_child(sprite)
	var material := ShaderMaterial.new()
	material.shader = preload("res://source_gpu_blend.gdshader")
	sprite.material = material
	var math = preload("res://source_gpu_color.gd")
	var differences := 0
	var cases := 0
	for mode in range(4):
		for gate in [[true,true,true,true,1.0],[true,true,false,true,1.0],[true,true,true,false,1.0],[false,true,false,false,1.0],[true,false,true,true,1.0],[true,true,true,true,0.0]]:
			var background := Vector3i(5,31,0)
			var foreground := Vector3i(3,1,31)
			var background_texture := color_texture(background)
			var foreground_texture := color_texture(foreground,float(gate[4]))
			var mask := Image.create(1,1,false,Image.FORMAT_RGBA8)
			mask.fill(Color(1 if gate[2] else 0,1 if gate[3] else 0,0,1))
			sprite.texture = foreground_texture
			material.set_shader_parameter("background_texture",background_texture)
			material.set_shader_parameter("foreground_texture",foreground_texture)
			material.set_shader_parameter("source_mask_texture",ImageTexture.create_from_image(mask))
			material.set_shader_parameter("source_textured",gate[0]); material.set_shader_parameter("source_semitransparent",gate[1]); material.set_shader_parameter("source_blend_mode",mode)
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var output := viewport.get_texture().get_image()
			for y in range(8):
				for x in range(8):
					var pixel := output.get_pixel(x,y).linear_to_srgb()
					var values := Vector3i(pixel.r8,pixel.g8,pixel.b8)
					for channel in range(3):
						var expected := int(background[channel])
						if float(gate[4]) >= 0.5 and (not gate[0] or gate[3]):
							expected = int(foreground[channel])
							if gate[1] and (not gate[0] or gate[2]): expected = math.blend(background[channel],foreground[channel],mode)
						if values[channel] != roundi(float(expected)*255.0/31.0): differences += 1
			cases += 1
	viewport.queue_free(); await process_frame
	print("GPU_BLEND_REFERENCE: ",{"cases":cases,"channels_checked":cases*64*3,"different_samples":differences})
	quit(0 if differences == 0 else 1)
