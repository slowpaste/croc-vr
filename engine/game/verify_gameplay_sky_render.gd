extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	root.size=Vector2i(640,480)
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for room in ["MP010_00.MAP","MP100_01.MAP"]:
		assert(world.load_room(room))
		var sky:Node3D=null
		for child in world.terrain.get_children():
			if child.get_script()==preload("res://source_gameplay_sky.gd"):sky=child
			else:child.hide()
		for actor in world.source_actors:actor.hide()
		world.visual.hide()
		world.camera.position=Vector3(0,1.6,0);world.camera.rotation=Vector3.ZERO;world.camera.current=true
		for frame in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var before:=root.get_texture().get_image()
		before.save_png(ProjectSettings.globalize_path("res://../build/sky-"+room+".png"))
		sky.hide()
		for frame in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var after:=root.get_texture().get_image()
		var changed:=0
		for y in range(before.get_height()):
			for x in range(before.get_width()):
				if before.get_pixel(x,y)!=after.get_pixel(x,y):changed+=1
		assert(changed>before.get_width()*before.get_height()/4,"Gameplay background did not render")
		print("SKY_RENDER: ",room," changed pixels=",changed)
	world.queue_free();await process_frame;print("PASS: original gameplay and level-selector skies render");quit(0)
