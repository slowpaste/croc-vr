extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args();var option:=args.find("--bundle")
	assert(option>=0);var directory:=str(args[option+1])
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
	for pack in index.packs:assert(ProjectSettings.load_resource_pack(directory.path_join(str(pack.file)),false))
	ProjectSettings.set_setting("croc/bundled_content_root","res://imported_data")
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	assert(world.imported and world.content_root=="res://imported_data")
	world.set_process(false);world.set_physics_process(false)
	assert(world.load_room("MP010_00.MAP"))
	for tick in range(100):world.tick_source_actors()
	var gobbo:Node=null
	for actor in world.source_actors:
		if actor.source_name=="Gobbo":gobbo=actor;break
	assert(gobbo!=null and gobbo.sprite_parts.size()==2 and gobbo.mesh_parts.size()==12)
	world.xr_active=true
	for part in gobbo.sprite_parts:
		for offset in [Vector3(3,0,0),Vector3(0,2,3),Vector3(-3,1,0),Vector3(0,0,-3)]:
			world.head.global_position=part.global_position+offset;gobbo._process(0)
			assert(part.global_basis.z.normalized().dot(offset.normalized())>0.9999)
	world.xr_active=false
	assert(world.load_room("MP011_00.MAP"))
	for tick in range(30):world.tick_source_actors()
	var butterfly:Node=null
	for actor in world.source_actors:
		if actor.source_name=="SceneryButterfly":butterfly=actor;break
	assert(butterfly!=null and butterfly.mesh_parts.size()==3 and butterfly.sprite_parts.is_empty())
	assert(world.load_room("MP012_00.MAP"))
	var player=world.active_texture_animations["TK05_TRK.BIN"]
	var before:PackedByteArray=player.bitmap.get_data()
	for tick in range(3):player.advance()
	assert(before!=player.bitmap.get_data())
	var binding:Dictionary=world.material_for_texture("TK00_ENM.BIN")
	assert(binding.material.vertex_color_is_srgb)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: full bundled import starts; Quest snapshot Gobbo head-facing parts, solid limbs, butterfly rig, lava palettes and sRGB materials")
	quit()
