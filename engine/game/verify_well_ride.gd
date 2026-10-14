extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var save_path := "user://well-ride-save-test-"+str(OS.get_process_id())+".bin"
	assert(not FileAccess.file_exists(save_path))
	var world=load("res://imported.tscn").instantiate();world.source_options_save_path=save_path;root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	for tick in range(30):world.update_source_input(0,0);world.tick_source_actors()
	var elevator: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="UpExit":elevator=actor;break
	assert(elevator!=null and world.source_player_actor!=null)
	world.source_pickup_counts={1:7,2:2,3:5}
	var player: Node3D=world.source_player_actor
	var contacts: Dictionary=world.source_contacts_at(elevator.position,player)
	assert(not contacts.lower.is_empty() and int(contacts.lower.get("actor",-1))==int(elevator.source_pool_id),"Elevator top not found")
	player.position=Vector3(elevator.position.x,int(contacts.lower.height_units)*world.CELL_METERS/4096.0,elevator.position.z)
	player.refresh_source_render_pose();player.run_source_collision_response()
	var start_y: float=player.position.y;var rise:=0.0;var paused:=false;var returned:=false
	for tick in range(1800):
		world.sample_source_player_controls();world.tick_source_actors()
		if is_instance_valid(player):rise=maxf(rise,player.position.y-start_y)
		paused=paused or world.source_input_suppression_count>0
		assert(world.process_source_exit(),world.source_transition_fault)
		if world.map_name=="MP010_00.MAP" and world.source_fade_phase=="":returned=true;break
	assert(returned and paused and rise>0.2,"Authored ride did not return: rise="+str(rise)+" map="+world.map_name+" pc="+str(elevator.vm.pc if is_instance_valid(elevator) else -1))
	assert(world.source_input_suppression_count==0)
	assert(world.source_pickup_counts=={1:7,2:2,3:5})
	player=world.source_player_actor
	var returned_position: Vector3=player.position
	Input.action_press("move_forward")
	for tick in range(45):world.sample_source_player_controls();world.tick_source_actors()
	Input.action_release("move_forward")
	assert(Vector2(player.position.x-returned_position.x,player.position.z-returned_position.z).length()>0.1 and player.vm.fault=="")
	assert(world.write_source_campaign().written)
	var saved := preload("res://source_save_store.gd").new(save_path).read_record()
	var state := preload("res://source_campaign_save.gd").decode(saved.record)
	assert(state.level==10 and state.room==0 and state.lives==5)
	world.queue_free();await process_frame
	assert(await preload("res://source_spu_stream_retirement.gd").drain(self))
	assert(DirAccess.remove_absolute(save_path)==OK)
	print("PASS: controlled platform contact triggers authored UpExit ride, pause/fade/return and sampled movement away from well; room traversal not simulated")
	quit(0)
