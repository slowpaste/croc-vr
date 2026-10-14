extends SceneTree
func _initialize() -> void: call_deferred("verify")
func quad(rgb: Vector3i, flags: int) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(0,0,0),Vector3(8,0,0),Vector3(8,8,0),Vector3(0,0,0),Vector3(8,8,0),Vector3(0,8,0)]:
		surface.set_color(Color(float(rgb.x)/255,float(rgb.y)/255,float(rgb.z)/255,float(flags)/255))
		surface.set_uv(Vector2(0.5,0.5)); surface.add_vertex(point)
	return surface.commit()
func verify() -> void:
	var target := SubViewport.new(); target.size = Vector2i(8,8); target.use_hdr_2d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(target)
	var background := MeshInstance2D.new(); background.mesh = quad(Vector3i(40,248,0),64)
	var background_material := ShaderMaterial.new(); background_material.shader = preload("res://source_sequence_canvas_material.gdshader")
	background.material = background_material; target.add_child(background)
	var copy := BackBufferCopy.new(); copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT; target.add_child(copy)
	var foreground := MeshInstance2D.new(); target.add_child(foreground)
	var material := ShaderMaterial.new(); material.shader = preload("res://source_sequence_canvas_material.gdshader")
	material.set_shader_parameter("apply_blend",true); foreground.material = material
	var math = preload("res://source_gpu_color.gd")
	var differences := 0; var cases := 0
	for mode in range(4):
		for gate in [[false,true,true],[true,true,true],[true,false,true],[true,true,false]]:
			var textured: bool = gate[0]; var stp: bool = gate[1]; var visible_pixel: bool = gate[2]
			foreground.mesh = quad(Vector3i(128,128,128) if textured else Vector3i(24,8,248),33 if textured else 96)
			var atlas := Image.create(1,1,false,Image.FORMAT_RGBA8)
			atlas.fill(Color8(roundi(3.0*255/31),roundi(1.0*255/31),255,255 if visible_pixel else 0))
			material.set_shader_parameter("actor_texture",ImageTexture.create_from_image(atlas))
			var mask := Image.create(1,1,false,Image.FORMAT_RGBA8)
			mask.fill(Color(1 if stp else 0,1 if visible_pixel else 0,0,1))
			material.set_shader_parameter("actor_mask",ImageTexture.create_from_image(mask))
			material.set_shader_parameter("blend_mode",mode)
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var rendered := target.get_texture().get_image()
			for y in range(8):
				for x in range(8):
					var pixel := rendered.get_pixel(x,y).linear_to_srgb()
					var values := Vector3i(pixel.r8,pixel.g8,pixel.b8)
					for channel in range(3):
						var b: int = [5,31,0][channel]
						var f: int = [3,1,31][channel]
						if textured: f = math.channel(f,128,true,true,math.dither_at(x,y))
						var expected := b if textured and not visible_pixel else math.blend(b,f,mode) if not textured or stp else f
						if values[channel] != roundi(float(expected)*255/31): differences += 1
			cases += 1
	target.queue_free(); await process_frame
	print("CANVAS_BLEND_REFERENCE: ",JSON.stringify({"cases":cases,"channels":cases*64*3,"differences":differences}))
	quit(0 if differences == 0 else 1)
