extends RefCounted
static func board(route: SceneTree,world: Node,right_delta: int) -> String:
	var reached: Dictionary=await route.jump_to_actor(world,Vector3(17,0,10.5),right_delta,60,0,35)
	var fault: String=reached.get("fault","")
	route.release_controls()
	if not fault.is_empty():return fault
	if int(world.source_player_actor.source_ground.get("mode",0))!=1 or int(world.source_player_actor.source_ground.get("surface_type",-1))!=13 or (int(world.source_player_actor.secondary_flags)&2)==0:return "Wheel approach ground ledge not reached"
	print("STAGE18_WHEEL_GROUND_LEDGE: ",JSON.stringify({"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts}))
	var arms: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformRotate" and a.source_map_entity_index in [16,17,18])
	var stone: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index==20:stone=actor;break
	if arms.size()!=3 or stone==null:return "First vertical wheel supports missing"
	var lives: int=world.source_pickup_counts[3]
	var selected: Node3D=null
	for tick in range(300):
		for arm in arms:
			var previous_y: float=arm.previous_source_position.y*world.CELL_METERS/4096.0
			if arm.position.x<18.4 and arm.position.y>=0.1 and arm.position.y<=0.25 and arm.position.y>previous_y:selected=arm;break
		if selected!=null:break
		route.release_controls();world.sample_source_player_controls();world.tick_source_actors()
		if tick%10==0:print("STAGE18_WHEEL_WAIT: ",JSON.stringify({"tick":tick,"player":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"ground":world.source_player_actor.source_ground,"arms":arms.map(func(a):return {"index":a.source_map_entity_index,"position":str(a.position),"previous_y":a.previous_source_position.y*world.CELL_METERS/4096.0,"phase":a.vm.globals.get(0,0)})}))
		if world.source_pickup_counts[3]<lives:return "Vertical wheel waiting lost a life"
	if selected==null:return "Rising first wheel boarding window missing"
	print("STAGE18_WHEEL_BOARD_START: ",JSON.stringify({"player":str(world.source_player_actor.position),"arm":str(selected.position),"index":selected.source_map_entity_index,"phase":selected.vm.globals.get(0,0)}))
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==selected.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	reached=await route.jump_to_actor(world,selected,right_delta,30,0,35,supported,supported)
	fault=reached.get("fault","");route.release_controls()
	if fault.is_empty() and not supported.call():fault="First wheel arm standing support not reached"
	if fault.is_empty():
		reached=await route.jump_to_actor(world,stone,right_delta,30,0,18)
		fault=reached.get("fault","");route.release_controls()
		if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=stone.source_pool_id or int(world.source_player_actor.source_ground.get("mode",0))!=2 or (int(world.source_player_actor.secondary_flags)&2)==0):fault="First wheel central stone standing support missing"
	print("STAGE18_FIRST_WHEEL: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"key_latch":world.source_key_collected}))
	return fault

static func middle(route: SceneTree,world: Node,right_delta: int) -> String:
	var target: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformCrumble" and actor.source_map_entity_index==19:target=actor;break
	if target==null:return "Jigsaw middle crumble missing"
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==target.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	var reached: Dictionary=await route.jump_to_actor(world,target,right_delta,30,0,35,supported,supported)
	var fault: String=reached.get("fault","")
	route.release_controls()
	if fault.is_empty() and not supported.call():fault="Jigsaw middle crumble standing support missing"
	print("STAGE18_WHEEL_MIDDLE: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"key_latch":world.source_key_collected,"arms":world.source_actors.filter(func(a):return a.source_name=="PlatformRotate" and a.source_map_entity_index in [13,14,15]).map(func(a):return {"position":str(a.position),"phase":a.vm.globals.get(0,0)})}))
	return fault

static func second(route: SceneTree,world: Node,right_delta: int) -> String:
	var arms: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformRotate" and a.source_map_entity_index in [13,14,15])
	var stone: Node3D=null
	for actor in world.source_actors:
		if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index==21:stone=actor;break
	if arms.size()!=3 or stone==null:return "Second vertical wheel supports missing"
	var selected: Node3D=null
	var lives: int=world.source_pickup_counts[3]
	for tick in range(90):
		for arm in arms:
			var previous_y: float=arm.previous_source_position.y*world.CELL_METERS/4096.0
			if arm.position.x<24.6 and arm.position.y>=2.0 and arm.position.y<=3.1 and arm.position.y>previous_y:selected=arm;break
		if selected!=null:break
		route.release_controls();world.sample_source_player_controls();world.tick_source_actors()
		if world.source_pickup_counts[3]<lives:return "Second wheel waiting lost a life"
	if selected==null:return "Second wheel boarding window missing"
	print("STAGE18_SECOND_WHEEL_START: ",JSON.stringify({"player":str(world.source_player_actor.position),"arm":str(selected.position),"index":selected.source_map_entity_index,"phase":selected.vm.globals.get(0,0)}))
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==selected.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	var reached: Dictionary=await route.jump_to_actor(world,selected,right_delta,30,0,18,supported,supported)
	var fault: String=reached.get("fault","");route.release_controls()
	if fault.is_empty() and not supported.call():fault="Second wheel arm standing support missing"
	if fault.is_empty():
		reached=await route.jump_to_actor(world,stone,right_delta,30,0,18)
		fault=reached.get("fault","");route.release_controls()
		if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=stone.source_pool_id or int(world.source_player_actor.source_ground.get("mode",0))!=2 or (int(world.source_player_actor.secondary_flags)&2)==0):fault="Second wheel central stone standing support missing"
	print("STAGE18_SECOND_WHEEL: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"key_latch":world.source_key_collected}))
	return fault

static func leave(route: SceneTree,world: Node,right_delta: int) -> String:
	var arms: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformRotate" and a.source_map_entity_index in [13,14,15])
	var selected: Node3D=null
	var lives: int=world.source_pickup_counts[3]
	for tick in range(300):
		for arm in arms:
			var previous_y: float=arm.previous_source_position.y*world.CELL_METERS/4096.0
			if arm.position.x>=26.7 and arm.position.y>=3.1 and arm.position.y<=3.9 and arm.position.y<previous_y:selected=arm;break
		if selected!=null:break
		route.release_controls();world.sample_source_player_controls();world.tick_source_actors()
		if world.source_pickup_counts[3]<lives:return "Second wheel exit waiting lost a life"
	if selected==null:return "Second wheel exit window missing"
	print("STAGE18_WHEEL_EXIT_START: ",JSON.stringify({"player":str(world.source_player_actor.position),"arm":str(selected.position),"phase":selected.vm.globals.get(0,0)}))
	var supported := func():return int(world.source_player_actor.source_ground.get("actor",-1))==selected.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
	var reached: Dictionary=await route.jump_to_actor(world,selected,right_delta,30,0,18,supported,supported)
	var fault: String=reached.get("fault","");route.release_controls()
	if fault.is_empty() and not supported.call():fault="Second wheel exit arm standing support missing"
	if fault.is_empty():
		var high := false
		for tick in range(300):
			route.release_controls()
			if selected.position.y>=4.05 and selected.position.x>=25.8 and selected.position.x<=26.2:high=true;break
			world.sample_source_player_controls();world.tick_source_actors()
			if tick%20==0:print("STAGE18_WHEEL_EXIT_RIDE: ",JSON.stringify({"tick":tick,"player":str(world.source_player_actor.position),"arm":str(selected.position),"ground":world.source_player_actor.source_ground,"lives":world.source_pickup_counts[3]}))
			if world.source_pickup_counts[3]<lives:fault="Second wheel exit ride lost a life";break
		if fault.is_empty() and not high:fault="Second wheel high exit window missing"
	if fault.is_empty():
		var destination := Vector3(29.4,3.6,10.5)
		var hit: Dictionary=world.source_raw_floor_query(destination)
		if hit.has("height_units"):destination.y=int(hit.height_units)*world.CELL_METERS/4096.0
		reached=await route.jump_to_actor(world,destination,right_delta,60,0,35)
		fault=reached.get("fault","");route.release_controls()
	print("STAGE18_WHEEL_EXIT: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"key_latch":world.source_key_collected}))
	return fault
