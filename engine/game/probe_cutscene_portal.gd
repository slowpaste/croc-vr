extends Node3D
var root: Viewport
func _ready() -> void:
	root=get_tree().root;call_deferred("verify")
func centers(image: Image) -> Vector2:
	var sums := Vector2.ZERO;var counts := Vector2.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x,y)
			if c.r>0.6 and c.g<0.2 and c.b<0.2:sums.x+=x;counts.x+=1
			if c.b>0.6 and c.g<0.2 and c.r<0.2:sums.y+=x;counts.y+=1
	assert(counts.x>100 and counts.y>100)
	return sums/counts
func verify() -> void:
	root.size=Vector2i(640,480)
	var viewer := Camera3D.new();root.add_child(viewer)
	var portal := preload("res://source_cutscene_portal.gd").new();root.add_child(portal);portal.position.z=-4
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_custom_format(0,SurfaceTool.CUSTOM_R_FLOAT)
	for item in [[1.0,-0.2,Color.RED],[5.0,0.2,Color.BLUE]]:
		var depth: float=item[0]
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			surface.set_color(item[2]);surface.set_custom(0,Color(0,0,0,0));surface.set_uv(Vector2.ZERO)
			surface.add_vertex(Vector3((float(item[1])+corner.x*0.05)*depth,corner.y*0.05*depth,-depth))
	# Regression: a behind-camera triangle used to expand over the whole aperture.
	for point in [Vector3(-100,-100,1),Vector3(100,-100,1),Vector3(0,100,1)]:
		surface.set_color(Color(1,0,1));surface.set_custom(0,Color(0,0,0,0));surface.set_uv(Vector2.ZERO);surface.add_vertex(point)
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	assert(portal.present({"h":480,"passes":[{"kind":"opaque","meshes":{"actor":surface.commit()}}]},{"actor":ImageTexture.create_from_image(image)},{}))
	for frame in range(4):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var first := centers(root.get_texture().get_image())
	viewer.position.x=0.2
	for frame in range(4):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var second := centers(root.get_texture().get_image())
	assert(first.x-second.x>first.y-second.y+2.0,"Portal has no depth-dependent head-motion parallax")
	portal.queue_free();await get_tree().process_frame;viewer.position=Vector3.ZERO
	var args := OS.get_cmdline_user_args();var content := str(args[args.find("--content")+1])
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join("manifest.json")))
	var tables: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(content.path_join(manifest.runtimeTables)))
	var display := preload("res://source_sequence_screen.gd").new();root.add_child(display)
	assert(display.setup(content,manifest,tables,0,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667},viewer))
	assert(display.uses_portal and not display.screen.visible and display.session.compositor==null)
	display.session.audio.stream.stop_stream()
	assert(display.session.present_frame(0,299));display.session.player.fade.level=0;display.apply_fade()
	var sky_arrays: Array=display.session.portal.nodes["sky:-1"].mesh.surface_get_arrays(0)
	print("PORTAL_SKY_SAMPLE: ",sky_arrays[Mesh.ARRAY_COLOR][0]," uv=",sky_arrays[Mesh.ARRAY_TEX_UV][0]," order=",sky_arrays[Mesh.ARRAY_TEX_UV2][0])
	for frame in range(4):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("frame-portal-opening.png"))
	assert(display.session.portal.nodes.size()>0)
	display.queue_free()
	for frame in range(3):await get_tree().process_frame
	var sad := preload("res://source_cutscene_screen.gd").new();root.add_child(sad)
	assert(sad.setup_sad(content,manifest,tables,{"mix":[80,80,0,0],"history":[[0,0],[0,0]],"filter":{},"threaded":false,"prefill":0,"phase_us":6667},viewer))
	assert(sad.uses_portal and not sad.screen.visible and sad.session.compositor==null)
	assert(not sad.advance(33334,0).has("fault"))
	assert(sad.session.audio.get_parent()==sad.session and sad.session.player.get_parent()==sad.session)
	assert(sad.session.present_portal(20))
	sad.session.portal.black_level=0;sad.session.portal.update_anchor()
	for frame in range(4):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("frame-portal-sad.png"))
	sad.session.audio.stream.stop_stream()
	print("PASS: depth-dependent rendered head parallax, real opening geometry, clipped portal and no flat screen")
	sad.queue_free();viewer.queue_free();surface=null;image=null
	for frame in range(5):await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)
