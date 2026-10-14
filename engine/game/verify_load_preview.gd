extends SceneTree
func visible_pixels(image: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var color := image.get_pixel(x,y)
			if color.a>0.1 and maxf(color.r,maxf(color.g,color.b))>0.1:count+=1
	return count
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var preview=preload("res://source_load_preview.gd").new();root.add_child(preview)
	var session := preload("res://source_load_session.gd").initialize([{"slot":0,"path":"fixture","percentage":13}])
	assert(preview.present(world,0,world.source_options_font_data(),session),preview.fault)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(preview.output.get_texture().get_image().save_png("res://../build/load-preview.png")==OK)
	assert(preview.heading.visible and preview.legend.visible and preview.actions.visible)
	assert(preview.icon_frame==1 and preview.icon_timer==25)
	for tick in range(25):assert(preview.present(world,0,world.source_options_font_data(),session))
	assert(preview.icon_frame==1 and preview.icon_timer==0)
	assert(preview.present(world,0,world.source_options_font_data(),session) and preview.icon_frame==2)
	for tick in range(26):assert(preview.present(world,0,world.source_options_font_data(),session))
	assert(preview.icon_frame==0)
	preview.reset_icon_animation()
	assert(preview.present(world,0,world.source_options_font_data(),session) and preview.icon_frame==1 and preview.icon_timer==25)
	var compositor: int = preview.compositor_id
	assert(preview.present(world,16,world.source_options_font_data(),session) and preview.compositor_id==compositor)
	var saving := preload("res://source_save_session.gd").initialize([{"path":"fixture","percentage":13}],"new")
	assert(preview.present(world,0,world.source_options_font_data(),saving),preview.fault)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(preview.output.get_texture().get_image().save_png("res://../build/save-preview.png")==OK)
	saving=preload("res://source_save_session.gd").advance(saving,0,0x800000)
	assert(preview.present(world,0,world.source_options_font_data(),saving))
	for frame in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var overwrite_image: Image=preview.output.get_texture().get_image()
	assert(visible_pixels(overwrite_image,Rect2i(100,24,312,24))>100,"Save heading disappeared after redraw")
	assert(visible_pixels(overwrite_image,Rect2i(190,100,105,55))>100,"Save card disappeared after redraw")
	assert(visible_pixels(overwrite_image,Rect2i(120,190,272,40))>100,"Overwrite choices disappeared after redraw")
	assert(overwrite_image.save_png("res://../build/save-overwrite-preview.png")==OK)
	preview.queue_free();world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: Load memory-card model/heading/legend renders with reusable original GPU compositor; slot UI still pending")
	quit(0)
