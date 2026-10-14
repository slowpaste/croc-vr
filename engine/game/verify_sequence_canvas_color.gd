extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var target := SubViewport.new(); target.size = Vector2i(8,8); target.use_hdr_2d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(target)
	var node := MeshInstance2D.new(); target.add_child(node)
	var material := ShaderMaterial.new(); material.shader = preload("res://source_sequence_canvas_material.gdshader")
	node.material = material
	var math = preload("res://source_gpu_color.gd")
	var differences := 0; var cases := 0
	for source in range(3):
		for flags in [0,64,1,65,33,96]:
			for intensity in [8,127,128,255]:
				var rgb := Vector3i(intensity,(intensity*5)&255,255-intensity)
				var texture5 := Vector3i(7,15,31)
				var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
				image.fill(Color8(roundi(7.0*255/31),roundi(15.0*255/31),255,255))
				var other := Image.create(1,1,false,Image.FORMAT_RGBA8); other.fill(Color8(255,0,0,255))
				var names := ["actor_texture","room_texture","sky_texture"]
				for index in range(3): material.set_shader_parameter(names[index],ImageTexture.create_from_image(image if index == source else other))
				var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for point in [Vector3(0,0,0),Vector3(8,0,0),Vector3(8,8,0),Vector3(0,0,0),Vector3(8,8,0),Vector3(0,8,0)]:
					surface.set_color(Color(float(rgb.x)/255,float(rgb.y)/255,float(rgb.z)/255,float(flags|(source<<2))/255))
					surface.set_uv(Vector2(0.5,0.5)); surface.add_vertex(point)
				node.mesh = surface.commit()
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				var rendered := target.get_texture().get_image()
				for y in range(8):
					for x in range(8):
						var pixel := rendered.get_pixel(x,y).linear_to_srgb()
						var values := Vector3i(pixel.r8,pixel.g8,pixel.b8)
						var textured: bool = (flags&1) != 0
						var dither: int = math.dither_at(x,y) if (flags&64) == 0 or textured else 0
						for channel in range(3):
							var expected := roundi(float(math.channel(texture5[channel],rgb[channel],textured,true,dither))*255/31)
							if values[channel] != expected: differences += 1
				cases += 1
	target.queue_free(); await process_frame
	print("CANVAS_COLOR_REFERENCE: ",JSON.stringify({"cases":cases,"channels":cases*64*3,"differences":differences}))
	quit(0 if differences == 0 else 1)
