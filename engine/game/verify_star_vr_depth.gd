extends SceneTree
func _initialize() -> void:call_deferred("verify")
func center(image:Image) -> float:
	var count:=0;var total:=0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).r<0.05:count+=1;total+=x
	assert(count>100 and count<image.get_width()*image.get_height()/4)
	return total/count
func verify() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.3,0.55,0.8)
	viewport.add_child(environment)
	var camera:=Camera3D.new();viewport.add_child(camera)
	var overlay=preload("res://source_fade_overlay.gd").new();viewport.add_child(overlay)
	var triangles:Array=[[Vector2(180,75),Vector2(332,75),Vector2(256,165)]]
	assert(overlay.set_source_polygons(triangles));overlay.fade_material.set_shader_parameter("physical_polygons",true)
	var centers:Array=[]
	for eye in [-0.032,0.032]:
		camera.position.x=eye
		for frame in range(3):await process_frame
		await RenderingServer.frame_post_draw
		centers.append(center(viewport.get_texture().get_image()))
	assert(centers[0]-centers[1]>2 and centers[0]-centers[1]<8,"VR star has incorrect stereo depth")
	assert(overlay.set_source_polygons(triangles,true));overlay.fade_material.set_shader_parameter("physical_polygons",true)
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var black:=viewport.get_texture().get_image()
	for point in [Vector2i(5,5),Vector2i(320,240),Vector2i(635,475)]:assert(black.get_pixelv(point).r<0.05)
	print("PASS: star at 4m has stereo disparity=",centers[0]-centers[1],"; completed transition covers both eyes")
	viewport.queue_free();await process_frame;quit(0)
