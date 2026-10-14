extends "res://probe_second_stage_route.gd"
var pickups_diagnostic_done := false

func probe() -> void:
 if "--from-earned-stage10" in OS.get_cmdline_user_args():
  await super.probe();return
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 var fault: String=await run_stage12_extras(world)
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)

func run_stage12_extras(world: Node) -> String:
 pickups_diagnostic_done=false
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 var lives: int=world.source_pickup_counts[3]
 var prior: int=world.source_player_actor.source_angles.y
 for tick in range(12):
  Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
 release_controls()
 var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
 var fault := "" if right_delta!=0 else "Turn calibration failed"
 if fault.is_empty():fault=await collect_ordinary_boxes(world,right_delta)
 if fault.is_empty():
  var crystals: Array=world.source_actors.filter(func(a):return a.source_name=="Crystal")
  crystals.sort_custom(func(a,b):return a.position.z<b.position.z)
  var before: int=world.source_pickup_counts[1]
  for crystal in crystals:
   if not is_instance_valid(crystal):continue
   var destination: Vector3=crystal.position
   var floor_hit: Dictionary=world.source_raw_floor_query(destination)
   if floor_hit.has("height_units"):destination.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await jump_to_point(world,destination,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty() and world.source_pickup_counts[1]!=before+3:fault="Entrance crystals did not add three pickups"
 if world.source_pickup_counts[3]!=lives:fault="Opening extras lost a life"
 if fault.is_empty() and "--verify-optional-warp" in OS.get_cmdline_user_args():
  var warp: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="WarpSparkle":warp=actor;break
  if warp==null:fault="Missing authored optional warp"
  else:
   var destination: Vector3=warp.position
   var floor_hit: Dictionary=world.source_raw_floor_query(destination)
   if floor_hit.has("height_units"):destination.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await walk_to(world,destination,right_delta,true)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    for tick in range(800):
     release_controls()
     if tick%80 in [12,13,14,15,22,23]:Input.action_press("jump")
     world.sample_source_player_controls();world.tick_source_actors()
     if not world.process_source_exit():fault=world.source_transition_fault;break
     if world.map_name=="MP012_06.MAP":break
     if tick%60==0:
      print("STAGE12_WARP_TRACE: ",JSON.stringify({"tick":tick,"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"warp_counter":warp.vm.parameters[7] if is_instance_valid(warp) else -1,"room":world.map_name}))
      await process_frame
    if fault.is_empty() and world.map_name!="MP012_06.MAP":fault="Three-stomp input did not reach optional room"
   print("STAGE12_OPTIONAL_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-optional-pickups" in OS.get_cmdline_user_args():
  print("STAGE12_OPTIONAL_ARRIVAL: ",JSON.stringify({"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"flags":world.source_player_actor.secondary_flags,"floor":world.source_raw_floor_query(world.source_player_actor.position),"ground":world.source_player_actor.source_ground}))
  for tick in range(180):
   release_controls();world.sample_source_player_controls();world.tick_source_actors()
   if (int(world.source_player_actor.secondary_flags)&2)!=0:break
  if world.source_pickup_counts[3]!=lives:fault="Optional arrival lost a life before movement"
  print("STAGE12_OPTIONAL_LANDED: ",JSON.stringify({"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"flags":world.source_player_actor.secondary_flags,"inventory":world.source_pickup_counts}))
  if "--inspect-optional-floor" in OS.get_cmdline_user_args():
   for z in [18.0,17.0,16.0,15.0,14.0,13.59375,12.0,10.8]:
    for y in [0.0,0.75,3.6]:
     print("STAGE12_OPTIONAL_FLOOR: ",JSON.stringify({"x":9,"y":y,"z":z,"surfaces":world.terrain_surfaces_at(Vector3(9,y,z)),"query":world.source_raw_floor_query(Vector3(9,y,z))}))
   pickups_diagnostic_done=true
  var before: int=world.source_pickup_counts[1]
  var pickups: Array=world.source_actors.filter(func(a):return a.source_name in ["Crystal","SeedRed"])
  if not pickups_diagnostic_done:
   var approach: Dictionary=await walk_to(world,Vector3(9,3.6,16.5),right_delta)
   fault=approach.get("fault","");release_controls()
  while fault.is_empty() and not pickups_diagnostic_done and not pickups.is_empty():
   pickups=pickups.filter(func(a):return is_instance_valid(a) and not a.released)
   if pickups.is_empty():break
   pickups.sort_custom(func(a,b):return a.position.distance_squared_to(world.source_player_actor.position)<b.position.distance_squared_to(world.source_player_actor.position))
   var pickup: Node3D=pickups.pop_front()
   var destination: Vector3=pickup.position
   var floor_hit: Dictionary=world.source_raw_floor_query(destination)
   if floor_hit.has("height_units"):destination.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
   if destination.x>20 and world.source_player_actor.position.x<14:
    var crossing_index := 0
    for point in [Vector3(13.2,3.6,3),Vector3(16.8,3.6,3),Vector3(19.2,3.6,3),Vector3(22.8,3.6,3)]:
     var crossing: Dictionary=await running_gap_jump(world,point,right_delta) if crossing_index%2==1 else await walk_to(world,point-Vector3(0.7,0,0),right_delta)
     crossing_index+=1
     fault=crossing.get("fault","");release_controls()
     if not fault.is_empty():break
    if not fault.is_empty():break
   if destination.z<8 and world.source_player_actor.position.z>9 and world.source_player_actor.position.x<13:
    var approach: Dictionary=await walk_to(world,Vector3(9,3.6,10.5),right_delta)
    fault=approach.get("fault","");release_controls()
    if not fault.is_empty():break
    approach=await jump_to_point(world,Vector3(9,3.6,7.4),right_delta)
    fault=approach.get("fault","");release_controls()
    if not fault.is_empty():break
   if destination.z>9 and world.source_player_actor.position.z<8 and world.source_player_actor.position.x>20:
    var approach: Dictionary=await walk_to(world,Vector3(27,3.6,7.4),right_delta)
    fault=approach.get("fault","");release_controls()
    if not fault.is_empty():break
    approach=await jump_to_point(world,Vector3(27,3.6,10.6),right_delta)
    fault=approach.get("fault","");release_controls()
    if not fault.is_empty():break
   var reached: Dictionary=await jump_to_point(world,destination,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty() and not pickups_diagnostic_done:
   var markers: Dictionary=world.source_map_entity_flags.get("MP012_06.MAP",{})
   for index in [2,3,4,5,6,8,9,10,11,12,17,13,15]:
    if (int(markers.get(index,0))&5)==0:fault="Optional pickup marker missing at "+str(index);break
   if "--require-retained-crystals" in OS.get_cmdline_user_args() and world.source_pickup_counts[1]!=before+11:fault="Optional room did not retain all eleven crystals"
  print("STAGE12_OPTIONAL_MARKER_CHECK: ",JSON.stringify({"flags":world.source_map_entity_flags.get("MP012_06.MAP",{}),"retained_crystals":world.source_pickup_counts[1],"lives":world.source_pickup_counts[3],"expected_lives":lives+2}))
  if fault.is_empty() and not pickups_diagnostic_done and world.source_pickup_counts[3]!=lives+2:fault="Optional room did not yield two extra lives"
  print("STAGE12_OPTIONAL_PICKUPS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
  if fault.is_empty() and not pickups_diagnostic_done:print("STAGE_ENTITY_FLAGS: ",JSON.stringify(world.source_map_entity_flags))
 if fault.is_empty() and "--verify-optional-return" in OS.get_cmdline_user_args():
  var return_lives: int=world.source_pickup_counts[3]
  var warp: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="WarpSparkle":warp=actor;break
  if warp==null:fault="Optional return warp missing"
  else:
   for point in [Vector3(27,3.6,11.1),Vector3(27,3.6,13.3),Vector3(27,3.6,16.6),warp.position]:
    var reached: Dictionary=await jump_to_point(world,point,right_delta)
    fault=reached.get("fault","");release_controls()
    if not fault.is_empty():break
   if fault.is_empty():
    for tick in range(800):
     release_controls()
     if tick%80 in [12,13,14,15,22,23]:Input.action_press("jump")
     world.sample_source_player_controls();world.tick_source_actors()
     if not world.process_source_exit():fault=world.source_transition_fault;break
     if world.map_name=="MP012_00.MAP":break
     if tick%60==0:await process_frame
    if fault.is_empty() and world.map_name!="MP012_00.MAP":fault="Optional warp did not return to opening"
   if world.source_pickup_counts[3]!=return_lives:fault="Optional return lost a life"
   print("STAGE12_OPTIONAL_RETURN: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 print("STAGE12_OPENING_EXTRAS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 return fault

func running_gap_jump(world: Node,target: Vector3,right_delta: int) -> Dictionary:
 var starting_lives: int=world.source_pickup_counts[3]
 for tick in range(120):
  release_controls()
  var difference := wrapi(1024-int(world.source_player_actor.source_angles.y),-2048,2048)
  if abs(difference)<40:break
  Input.action_press("move_right" if difference*right_delta>0 else "move_left")
  world.sample_source_player_controls();world.tick_source_actors()
 var takeoff_x := target.x-3.4
 var jump_tick := -1
 for tick in range(90):
  release_controls()
  if jump_tick<0 and world.source_player_actor.position.x>=takeoff_x:jump_tick=tick
  if jump_tick>=0 and tick-jump_tick<16:Input.action_press("jump")
  if world.source_player_actor.position.x<target.x-0.25:Input.action_press("move_forward")
  world.sample_source_player_controls();world.tick_source_actors()
  if tick%5==0:print("RUNNING_GAP_TRACE: ",JSON.stringify({"tick":tick,"jump_tick":jump_tick,"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"yaw":world.source_player_actor.source_angles.y}))
  if world.source_pickup_counts[3]<starting_lives:return {"fault":"Running gap jump lost a life"}
  if jump_tick>=0 and tick-jump_tick>20 and (int(world.source_player_actor.secondary_flags)&2)!=0 and world.source_player_actor.position.x>target.x-0.6:break
 release_controls()
 return await walk_to(world,target,right_delta)
