extends SceneTree
var viewport: SubViewport
var environment: Environment
var node: MeshInstance3D
var failures := 0
func _initialize() -> void: call_deferred("verify")
func sample() -> Color:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var pixel:=viewport.get_texture().get_image().get_pixel(32,32)
	return pixel.linear_to_srgb() if viewport.use_hdr_2d and RenderingServer.get_current_rendering_method()!="gl_compatibility" else pixel
func compare(label: String, actual: Color, expected: Color) -> void:
	for channel in range(3):
		# Measured Compatibility output loses up to one RGB5 step near black.
		# Production Mobile/Forward+ retains the tighter RGB8 tolerance.
		var tolerance:=0.012
		if RenderingServer.get_current_rendering_method()=="gl_compatibility" and expected[channel]<0.1:tolerance=1.0/31.0
		if absf(actual[channel]-expected[channel]) > tolerance:
			push_error(label+": actual="+str(actual)+" expected="+str(expected)); failures+=1;return
func texture(color: Color) -> ImageTexture:
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(color)
	return ImageTexture.create_from_image(image)
func geometry(tint: Color, flags: int, mode: int) -> ArrayMesh:
	var builder := SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-1,-1,-2),Vector3(1,-1,-2),Vector3(1,1,-2),Vector3(-1,-1,-2),Vector3(1,1,-2),Vector3(-1,1,-2)]:
		builder.set_color(tint);builder.set_uv(Vector2(0.5,0.5));builder.set_uv2(Vector2(flags,mode));builder.add_vertex(point)
	return builder.commit()
func quantize(color: Color) -> Vector3i:
	return Vector3i(roundi(color.r*31),roundi(color.g*31),roundi(color.b*31))
func color5(value: Vector3i) -> Color:
	return Color(clampi(value.x,0,31)/31.0,clampi(value.y,0,31)/31.0,clampi(value.z,0,31)/31.0)
func verify() -> void:
	if RenderingServer.get_video_adapter_name().is_empty():push_error("Color checks require a real renderer");quit(2);return
	viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;viewport.add_child(camera)
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR
	var environment_node:=WorldEnvironment.new();environment_node.environment=environment;viewport.add_child(environment_node)
	node=MeshInstance3D.new();viewport.add_child(node)
	var green:=Color(91.0/255.0,179.0/255.0,0)
	var gold:=Color(1,0.85,0.35)
	for shader_name in ["source_menu_text","source_gameplay_sky"]:
		var material:=ShaderMaterial.new();material.shader=load("res://"+shader_name+".gdshader")
		material.set_shader_parameter("atlas_texture",texture(Color.WHITE))
		if shader_name=="source_menu_text":material.set_shader_parameter("physical_panel",true)
		node.material_override=material
		for tint in [green,gold,Color.WHITE]:
			node.mesh=geometry(tint,1,0)
			compare(shader_name+" tint",await sample(),tint)
		if shader_name=="source_gameplay_sky":
			node.mesh=geometry(Color.WHITE,0,0);material.set_shader_parameter("dome_color",Vector3(gold.r,gold.g,gold.b))
			compare("sky dome",await sample(),gold)
	for background in [Color.BLACK,Color(0.6,0.4,0.2)]:
		node.visible=false;environment.background_color=background
		var back5:=quantize(await sample());node.visible=true
		for tint in [green,Color(240.0/255.0,95.0/255.0,136.0/255.0),Color.WHITE]:
			var front5:=quantize(tint)
			for mode in [0,1,2,3]:
				var material:=ShaderMaterial.new()
				material.shader=load("res://source_gameplay_additive.gdshader" if mode==1 else "res://source_gameplay_blend.gdshader")
				material.set_shader_parameter("atlas_texture",texture(Color.WHITE))
				node.material_override=material;node.mesh=geometry(tint,32,mode)
				var expected:=Vector3i.ZERO
				for axis in range(3):
					if mode==0:expected[axis]=(back5[axis]>>1)+(front5[axis]>>1)
					elif mode==1:expected[axis]=back5[axis]+front5[axis]
					elif mode==2:expected[axis]=back5[axis]-front5[axis]
					else:expected[axis]=back5[axis]+(front5[axis]>>2)
				compare("gameplay blend %d"%mode,await sample(),color5(expected))
		# STP-clear textured pixels bypass blending but retain their source tint.
		var material:=ShaderMaterial.new();material.shader=load("res://source_gameplay_blend.gdshader")
		material.set_shader_parameter("atlas_texture",texture(Color.WHITE))
		material.set_shader_parameter("source_mask",texture(Color.BLACK));material.set_shader_parameter("has_mask",true)
		node.material_override=material;node.mesh=geometry(green,33,0)
		compare("STP-clear tint",await sample(),green)
	var overlay:=preload("res://source_fade_overlay.gd").new();camera.add_child(overlay)
	var ui:=ShaderMaterial.new();ui.shader=preload("res://source_menu_text.gdshader")
	ui.set_shader_parameter("physical_panel",true);ui.set_shader_parameter("atlas_texture",texture(Color(1,1,1,0.5)))
	node.material_override=ui;node.mesh=geometry(gold,1,0)
	for hdr in [false,true]:
		if hdr and RenderingServer.get_current_rendering_method()=="gl_compatibility":continue
		viewport.use_hdr_2d=hdr
		for msaa in [Viewport.MSAA_DISABLED,Viewport.MSAA_2X]:
			viewport.msaa_3d=msaa
			for background in [Color.BLACK,Color.WHITE,Color(0.6,0.4,0.2)]:
				environment.background_color=background
				for transparent_ui in [false,true]:
					overlay.set_source_level(0);node.visible=transparent_ui
					var baseline:=await sample();var back5:=quantize(baseline)
					for white in [false,true]:
						for level in [0,7,8,64,128,248,255]:
							if white:overlay.set_source_white_level(level)
							else:overlay.set_source_level(level)
							var expected:=baseline if level<8 else color5(back5+Vector3i.ONE*(level>>3)*(1 if white else -1))
							compare("%s fade level %d HDR=%s MSAA=%d UI=%s"%["white" if white else "black",level,hdr,msaa,transparent_ui],await sample(),expected)
					overlay.hide();compare("hidden fade",await sample(),baseline)
					overlay.set_source_level(0)
	viewport.queue_free();await process_frame
	if failures==0:print("PASS: menu/sky RGB, gameplay blends/STP; RGB5 fades over transparent UI, LDR/HDR, MSAA, saturation and visibility")
	quit(0 if failures==0 else 1)
