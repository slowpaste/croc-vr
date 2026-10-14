extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	assert(world.load_room("MP011_00.MAP"))
	for tick in range(30):world.tick_source_actors()
	var butterfly:Node=null
	for actor in world.source_actors:
		if actor.source_name=="SceneryButterfly":butterfly=actor;break
	assert(butterfly!=null and butterfly.mesh_parts.size()==3 and butterfly.sprite_parts.is_empty())
	butterfly.apply_pose()
	var transforms:Array=[]
	for part in butterfly.mesh_parts:transforms.append(part.transform)
	world.camera.position+=Vector3(5,3,4);butterfly._process(1.0/60.0)
	for index in range(3):assert(butterfly.mesh_parts[index].transform.is_equal_approx(transforms[index]))
	var sheet:=Image.create(1,3,false,Image.FORMAT_RGBA8);sheet.set_pixel(0,0,Color.RED);sheet.set_pixel(0,1,Color.GREEN);sheet.set_pixel(0,2,Color.BLUE)
	var file:="user://palette-cycle-test.png";sheet.save_png(file)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.RED)
	var texture:=ImageTexture.create_from_image(image)
	var cycle=preload("res://source_texture_animation.gd").new()
	assert(cycle.setup(texture,image,[{"paletteCycle":true,"delay":2,"frames":3,"interval":1,"width":1,"height":1,"x":0,"y":0,"rectangles":[{"x":0,"y":0,"width":1,"height":1}],"image":"palette-cycle-test.png"}],ProjectSettings.globalize_path("user://")))
	assert(not cycle.advance() and not cycle.advance());assert(cycle.advance() and image.get_pixel(0,0)==Color.GREEN)
	for tick in range(3):cycle.advance()
	assert(image.get_pixel(0,0)==Color.BLUE)
	for tick in range(3):cycle.advance(true)
	assert(image.get_pixel(0,0)==Color.GREEN)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	assert(world.load_room("MP012_00.MAP"))
	assert(world.active_texture_animations.has("TK05_TRK.BIN"))
	var before:PackedByteArray=world.active_texture_animations["TK05_TRK.BIN"].bitmap.get_data()
	for tick in range(3):world.active_texture_animations["TK05_TRK.BIN"].advance()
	assert(before!=world.active_texture_animations["TK05_TRK.BIN"].bitmap.get_data())
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: butterfly wing rig survives head motion; native palette delay/direction; live lava terrain colors animate")
	quit(0)
