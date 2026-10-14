extends SceneTree
func _initialize() -> void: call_deferred("verify")
func command(color8: int, flags: int, bucket: int, serial: int) -> Dictionary:
	var vertices: Array = []
	for point in [Vector3(-2,-2,-1),Vector3(2,-2,-1),Vector3(2,2,-1),Vector3(-2,-2,-1),Vector3(2,2,-1),Vector3(-2,2,-1)]:
		vertices.append({"position":point,"color":Color(float(color8)/255.0,float(color8)/255.0,float(color8)/255.0,0),"uv":Vector2(0.5,0.5)})
	return {"bucket":bucket,"serial":serial,"vertices":vertices,"flags":flags,"blend":2}
func plan(background8: int) -> Dictionary:
	return preload("res://source_cutscene_passes.gd").plan([command(background8,64,300,0)],[command(128,33,100,0)])
func verify() -> void:
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color8(66,66,66,255)) # Eight source five-bit units.
	var texture := ImageTexture.create_from_image(image)
	image.fill(Color.WHITE)
	var mask := ImageTexture.create_from_image(image)
	var graph := preload("res://source_cutscene_compositor.gd").new()
	root.add_child(graph)
	assert(graph.setup(plan(64),320,{"room":texture,"actor":texture},{"actor":mask}))
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var first := graph.output.get_texture().get_image().get_pixel(256,192).linear_to_srgb().r8
	assert(first == 8)
	assert(graph.present(plan(128),320))
	await process_frame
	await RenderingServer.frame_post_draw
	var second := graph.output.get_texture().get_image().get_pixel(256,192).linear_to_srgb().r8
	graph.queue_free(); await process_frame
	print("COMPOSITOR_FRAME_UPDATE: ",{"before":first,"after_one_render":second,"expected":74})
	quit(0 if second == 74 else 1)
