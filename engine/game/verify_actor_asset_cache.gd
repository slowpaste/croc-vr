extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var player=world.source_player_actor
	var handle:=-1
	for i in range(player.handles.size()):
		if player.handles[i].get("name","")=="CROCJMP2.ANI":handle=i;break
	assert(handle>0 and player.select_animation(handle,true))
	var mesh:Mesh=player.mesh_parts[0].mesh
	assert(player.select_animation(handle,true) and player.mesh_parts[0].mesh==mesh)
	var atlas:Dictionary=world.material_for_texture("TK00_ENM.BIN")
	assert(atlas.material==world.material_for_texture("TK00_ENM.BIN").material)
	var source_vertices:Array=player.model_data.models[0].vertices.duplicate(true)
	player.clip_frame=mini(1,int(player.clip.frameCount)-1);player.apply_pose()
	assert(player.model_data.models[0].vertices==source_vertices)
	var old:Array=world.source_actors.duplicate()
	world.source_pickup_counts[1]=10
	assert(world.lose_source_pickups())
	for tick in range(3):world.tick_source_actors()
	var dropped:Array=[]
	for actor in world.source_actors:
		if not old.has(actor) and not actor.mesh_parts.is_empty():dropped.append(actor)
	assert(dropped.size()>=2)
	var shared:=false
	for first in dropped:
		for second in dropped:
			if first!=second and first.model_asset_file==second.model_asset_file and first.animation_asset_file==second.animation_asset_file and first.clip_frame==second.clip_frame:
				assert(first.mesh_parts[0].mesh==second.mesh_parts[0].mesh)
				shared=true
	assert(shared)
	var original:Dictionary=world.read_source_asset(dropped[0].handles.filter(func(item):return item.get("name","")==dropped[0].model_name)[0].file)
	dropped[0].model_data.clear()
	assert(not original.is_empty() and not dropped[1].model_data.is_empty())
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: replayed animation mesh reuse, shared effect meshes/materials and independent actor model lifetime")
	quit(0)
