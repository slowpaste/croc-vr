extends "res://probe_secret_stage_route.gd"

func probe() -> void:
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 if world.map_name!="MP014_00.MAP":push_error("Expected stage14 opening");quit(1);return
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 var prior: int=world.source_player_actor.source_angles.y
 for tick in range(12):Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
 release_controls()
 var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
 var fault := "" if right_delta!=0 else "Stage14 turn calibration failed"
 var targets := {}
 for actor in world.source_actors:
  if actor.source_name in ["Crystal","Crystal_B"]:targets[actor.source_map_entity_index]=actor.position
 var lives: int=world.source_pickup_counts[3]
 for index in [4,5,6,7,8,11,9,10]:
  if not fault.is_empty():break
  if not targets.has(index):fault="Opening pickup missing: "+str(index);break
  var expected_marker := 1 if index==11 else 4
  var marker := func():return int(world.source_map_entity_flags.get("MP014_00.MAP",{}).get(index,0))==expected_marker
  if marker.call():continue
  var reached: Dictionary=await walk_to(world,targets[index],right_delta,false,null,1.8,"",40,marker)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty() and not marker.call():fault="Opening pickup marker missing: "+str(index)
 if fault.is_empty() and "--verify-stage14-opening-box" in OS.get_cmdline_user_args():
  var box: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SmashBlockFloatGobbo" and actor.source_map_entity_index==3:box=actor;break
  if box==null:fault="Opening Gobbo box missing"
  else:
   var before_gobbos: int=world.source_pickup_counts[2]
   var boarded: Dictionary=await jump_to_actor(world,box,right_delta,60,0,18)
   fault=boarded.get("fault","");release_controls()
   if fault.is_empty():
    for tick in range(240):
     release_controls()
     if tick in range(12,16) or tick in range(22,100):Input.action_press("jump")
     world.sample_source_player_controls();world.tick_source_actors()
     if world.source_pickup_counts[2]==before_gobbos+1:break
     if world.source_pickup_counts[3]<lives:fault="Opening box stomp lost a life";break
   release_controls()
   if fault.is_empty() and world.source_pickup_counts[2]!=before_gobbos+1:fault="Opening box Gobbo reward missing"
  print("STAGE14_OPENING_BOX: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"key_latch":world.source_key_collected,"player":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage14-upper-wall" in OS.get_cmdline_user_args():
  var staged: Dictionary=await walk_to(world,Vector3(12,-0.164795,18),right_delta)
  fault=staged.get("fault","");release_controls()
  if fault.is_empty():
   var on_wall := func():return int(world.source_player_actor.source_ground.get("mode",0))==5 and world.source_player_actor.position.y>0.3
   var climbed: Dictionary=await jump_to_actor(world,Vector3(12,0.8,22),right_delta,60,0,35,on_wall,on_wall)
   fault=climbed.get("fault","");release_controls()
  if fault.is_empty():
   var rim: Dictionary=await walk_to(world,Vector3(12,3.432861,24),right_delta)
   fault=rim.get("fault","");release_controls()
  print("STAGE14_UPPER_WALL: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"player_state":int(world.source_extended_globals.get(0,0))>>16}))
 if fault.is_empty() and "--verify-stage14-first-door" in OS.get_cmdline_user_args():
  for z in [16,17,18,19,20,21,22,23,24]:
   print("STAGE14_DOOR_FLOOR: ",JSON.stringify({"z":z,"samples":[6,9,12].map(func(x):return {"x":x,"floor":world.source_raw_floor_query(Vector3(x,0,z))})}))
  print("STAGE14_DOOR_ACTORS: ",JSON.stringify(world.source_actors.map(func(a):return {"name":a.source_name,"position":str(a.position),"pc":a.vm.pc})))
  var takeoff: Dictionary=await walk_to(world,Vector3(9,-0.164795,17.8),right_delta)
  fault=takeoff.get("fault","");release_controls()
  if fault.is_empty():
   var crossed: Dictionary=await jump_to_actor(world,Vector3(9,0,22.5),right_delta,60,0,45,func():return world.source_player_actor.position.z>22.1 and (int(world.source_player_actor.secondary_flags)&2)!=0)
   fault=crossed.get("fault","");release_controls()
  if fault.is_empty():
   var entered: Dictionary=await walk_to(world,Vector3(9,0,24),right_delta,false,null,1.8,"MP014_01.MAP")
   fault=entered.get("fault","");release_controls()
  print("STAGE14_FIRST_DOOR: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"key_latch":world.source_key_collected,"player":str(world.source_player_actor.position)}))
  if fault.is_empty():print("STAGE14_ROOM1_LAYOUT: ",JSON.stringify(world.source_actors.map(func(a):return {"index":a.source_map_entity_index,"name":a.source_name,"position":str(a.position),"pc":a.vm.pc})))
 if world.source_pickup_counts[3]<lives:fault="Stage14 opening lost a life"
 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 print("STAGE14_OPENING_CHECK: ",JSON.stringify({"fault":fault,"flags":world.source_map_entity_flags,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"player":str(world.source_player_actor.position),"scope":"Direct entrance sampled-input routes selected by flags; remaining rooms/collectibles, earned progression, visual and physical VR unverified"}))
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)
