extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.sample_source_player_controls();world.tick_source_actors()
	var box: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="SmashBlock":box=actor;break
	assert(box!=null)
	var box_id: int=box.source_pool_id;var position: Vector3=box.position
	var player: Node3D=world.source_player_actor
	var top: Dictionary=world.source_contacts_at(position,player)
	assert(not top.lower.is_empty() and int(top.lower.get("actor",-1))==box_id)
	player.position=Vector3(position.x,int(top.lower.height_units)*world.CELL_METERS/4096.0,position.z)
	player.refresh_source_render_pose();player.run_source_collision_response()
	var placed:=true;var hidden:=false;var ghost_contacts:=0;var retirement_contacts:=0
	Input.action_press("jump")
	for tick in range(180):
		if tick==3:Input.action_release("jump")
		if tick==8:Input.action_press("jump")
		if tick==12:Input.action_release("jump")
		world.sample_source_player_controls()
		world.tick_source_actors()
		if not is_instance_valid(box) or (box.primary_flags&0x80000)!=0:hidden=true
		if hidden:
			var contacts: Dictionary=world.source_contacts_at(position,player)
			for side in ["lower","upper"]:
				if int(contacts[side].get("actor",-1))==box_id:
					if is_instance_valid(box) and (box.primary_flags&4)!=0:retirement_contacts+=1
					else:ghost_contacts+=1
	Input.action_release("jump")
	Input.action_release("attack")
	print("BOX_BREAK_STATE: placed=",placed," hidden=",hidden," player_flags=",player.primary_flags," box_pc=",box.vm.pc if is_instance_valid(box) else -1," params=",box.vm.parameters if is_instance_valid(box) else [])
	if not placed or not hidden:
		push_error("Authored box was not hit/hidden; contact fixture not qualified")
		world.queue_free();await process_frame
		await preload("res://source_spu_stream_retirement.gd").drain(self)
		quit(1);return
	assert(ghost_contacts==0 and retirement_contacts<=1 and not world.source_pool.slots.has(box_id),"Broken underground box retained collision beyond retirement")
	assert(player.vm.fault=="" and world.source_transition_fault=="")
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	print("PASS: sampled double-jump smash with controlled initial standing breaks underground box and clears collision at next native retirement tick")
	quit(0)
