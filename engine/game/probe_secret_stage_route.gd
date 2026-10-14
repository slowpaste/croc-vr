extends "res://probe_fourth_stage_route.gd"

func probe() -> void:
 if "--from-earned-stage10" in OS.get_cmdline_user_args():
  await super.probe();return
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 var fault: String=await run_stage18(world)
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)

func continue_earned_stage(world: Node) -> String:
 var fault: String=await super.continue_earned_stage(world)
 if not fault.is_empty():return fault
 if world.source_main_mode!=5 or world.source_menu_state.selected_index!=4:return "Earned boss did not leave secret stage selected"
 world.set_process(true);world.set_physics_process(true)
 for frame in range(60):await physics_frame
 Input.action_press("jump")
 for frame in range(4):await physics_frame
 Input.action_release("jump")
 for frame in range(180):
  await physics_frame
  if world.map_name=="MP018_00.MAP" and world.source_fade_phase=="":break
 if world.map_name!="MP018_00.MAP" or world.source_menu_state.selected_index!=4:return "Earned selector did not enter first secret stage"
 print("STAGE18_EARNED_ENTRY: ",JSON.stringify({"progress":world.source_menu_progress_flags,"inventory":world.source_pickup_counts,"selection":world.source_menu_state.selected_index}))
 fault=await run_stage18(world)
 if fault.is_empty() and "--verify-stage18-jigsaw-return" in OS.get_cmdline_user_args():
  for index in range(3):
   if int(world.source_menu_progress_flags.get(index,0))!=0x8006:fault="Prior earned rescues lost at index "+str(index);break
  if fault.is_empty() and (int(world.source_menu_progress_flags.get(3,0))!=0x8000 or int(world.source_menu_progress_flags.get(4,0))!=0x8000 or world.source_menu_state.selected_index!=5):fault="Earned secret completion/next selection missing"
  if fault.is_empty() and "--verify-stage18-save" in OS.get_cmdline_user_args():fault=await verify_earned_campaign_roundtrip(world,"MP014_00.MAP")
 print("STAGE18_EARNED_RESULT: ",JSON.stringify({"fault":fault,"progress":world.source_menu_progress_flags,"inventory":world.source_pickup_counts,"selection":world.source_menu_state.selected_index}))
 return fault

func run_stage18(world: Node) -> String:
 if world.map_name!="MP018_00.MAP":return "Secret route requires first secret entrance"
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 var lives: int=world.source_pickup_counts[3]
 var prior: int=world.source_player_actor.source_angles.y
 for tick in range(12):
  Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
 release_controls()
 var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
 var fault := "" if right_delta!=0 else "Secret-stage turn calibration failed"
 var crumble: Node3D=null
 for actor in world.source_actors:
  if actor.source_name=="PlatformCrumble":crumble=actor;break
 if crumble==null:fault="Secret entrance crumble platform missing"
 if fault.is_empty():
  print("STAGE18_ENTRANCE: ",JSON.stringify({"player":str(world.source_player_actor.position),"crumble":str(crumble.position)}))
  var reached: Dictionary=await walk_to(world,Vector3(17.1,0,3),right_delta)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await jump_to_actor(world,crumble,right_delta,30)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await jump_to_actor(world,Vector3(22.3,0,2.6),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
 if fault.is_empty() and "--verify-stage18-opening-crystals" in OS.get_cmdline_user_args():
  var crystals: Array=world.source_actors.filter(func(a):return a.source_name=="Crystal" and a.source_map_entity_index in [1,2,3,4,5])
  crystals.sort_custom(func(a,b):return a.position.x<b.position.x)
  for crystal in crystals:
   if not is_instance_valid(crystal):continue
   var point: Vector3=crystal.position
   var floor_hit: Dictionary=world.source_raw_floor_query(point)
   if floor_hit.has("height_units"):point.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty():
   for index in range(1,6):
    if (int(world.source_map_entity_flags.get("MP018_00.MAP",{}).get(index,0))&5)==0:fault="Opening secret crystal missing at "+str(index);break
 if fault.is_empty() and "--inspect-stage18-curve" in OS.get_cmdline_user_args():
  for x in [29.0,29.5,30.0,30.5,31.0,31.5]:
   for z in range(3,10):
    print("STAGE18_CURVE_FLOOR: ",JSON.stringify({"x":x,"z":z,"floor":world.source_raw_floor_query(Vector3(x,0,z))}))
 if fault.is_empty() and "--verify-stage18-first-box" in OS.get_cmdline_user_args():
  var step_index := 0
  for point in [Vector3(30,0,3),Vector3(30,0,4.8),Vector3(30,0,7.2),Vector3(30,0,9),Vector3(33,0,9),Vector3(36,0,9),Vector3(37.5,0,9)]:
   var reached: Dictionary=await jump_to_point(world,point,right_delta) if step_index==2 else await walk_to(world,point,right_delta)
   step_index+=1
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  var crate: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SmashBlock":crate=actor;break
  if crate==null:fault="Secret first box missing"
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,crate,right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():fault=await stomp_reward_box(world,crate)
  print("STAGE18_FIRST_BOX: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-arrow" in OS.get_cmdline_user_args():
  var runner: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="RunningPlatform":runner=actor;break
  if runner==null:fault="Secret arrow platform missing"
  else:
   var reached: Dictionary=await walk_to(world,Vector3(36,0,11.6),right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,runner,right_delta,60,0)
    fault=reached.get("fault","");release_controls()
   var start_x: float=runner.position.x
   if fault.is_empty():
    for tick in range(120):
     release_controls()
     var difference := wrapi(3072-int(world.source_player_actor.source_angles.y),-2048,2048)
     if abs(difference)<40:break
     Input.action_press("move_right" if difference*right_delta>0 else "move_left")
     world.sample_source_player_controls();world.tick_source_actors()
    for tick in range(600):
     release_controls()
     if world.source_player_actor.position.x-runner.position.x> -0.35:Input.action_press("move_forward")
     world.sample_source_player_controls();world.tick_source_actors()
     if tick%30==0:print("STAGE18_ARROW_RIDE: ",JSON.stringify({"tick":tick,"platform":str(runner.position),"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground}));await process_frame
     if runner.position.x<20:break
    if runner.position.x>=start_x-2:fault="Secret arrow did not travel left"
   print("STAGE18_ARROW_CHECK: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"platform":str(runner.position)}))
   if fault.is_empty() and "--inspect-stage18-dismount" in OS.get_cmdline_user_args():
    for x in [21.0,22.0,22.5,23.0,24.0,25.0]:
     for z in [13.0,14.0,14.5,15.0,16.0]:
      print("STAGE18_DISMOUNT_FLOOR: ",JSON.stringify({"x":x,"z":z,"floor":world.source_raw_floor_query(Vector3(x,0,z))}))
   if fault.is_empty() and "--verify-stage18-dismount" in OS.get_cmdline_user_args():
    reached=await jump_to_actor(world,Vector3(22.5,0,14),right_delta)
    fault=reached.get("fault","");release_controls()
    print("STAGE18_DISMOUNT_CHECK: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"inventory":world.source_pickup_counts}))
   if fault.is_empty() and "--verify-stage18-west-crystals" in OS.get_cmdline_user_args():
    if "--inspect-stage18-west-curve" in OS.get_cmdline_user_args():
     for x in [19.0,19.5,20.0,20.5,21.0,21.5,22.0,22.5]:
      for z in [11.5,12.0,12.5,13.0,13.5,14.0]:
       print("STAGE18_WEST_CURVE_FLOOR: ",JSON.stringify({"x":x,"z":z,"floor":world.source_raw_floor_query(Vector3(x,0,z))}))
    var crystals: Array=world.source_actors.filter(func(a):return a.source_name=="Crystal" and a.source_map_entity_index in [6,7,8,14])
    reached=await walk_to(world,Vector3(22,0,12),right_delta)
    fault=reached.get("fault","");release_controls()
    crystals.sort_custom(func(a,b):return a.position.x>b.position.x)
    for crystal in crystals:
     if not fault.is_empty():break
     if not is_instance_valid(crystal):continue
     var index: int=crystal.source_map_entity_index
     if index==7:
      reached=await jump_to_actor(world,Vector3(16.8,0,12.6),right_delta,60,0)
      fault=reached.get("fault","");release_controls()
      if not fault.is_empty():break
     var point: Vector3=crystal.position
     var floor_hit: Dictionary=world.source_raw_floor_query(point)
     if floor_hit.has("height_units"):point.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
     reached=await walk_to(world,point,right_delta,true,null,1.8,"",40,func():return (int(world.source_map_entity_flags.get("MP018_00.MAP",{}).get(index,0))&5)!=0)
     fault=reached.get("fault","");release_controls()
     if not fault.is_empty():break
    print("STAGE18_WEST_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-next-room" in OS.get_cmdline_user_args():
  var reached: Dictionary=await walk_to(world,Vector3(6,0,18),right_delta,false,null,1.8,"MP018_01.MAP")
  fault=reached.get("fault","");release_controls()
  print("STAGE18_NEXT_ROOM: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-key-room" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var floor_y: float=world.source_player_actor.position.y
  print("STAGE18_SECOND_ROOM: ",JSON.stringify({"player":str(world.source_player_actor.position),"actors":world.source_actors.map(func(a):return {"name":a.source_name,"position":str(a.position)})}))
  for point in [Vector3(9,floor_y,9),Vector3(15,floor_y,9)]:
   var reached: Dictionary=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(25.5,floor_y,9),right_delta,false,null,1.8,"MP018_04.MAP")
   fault=reached.get("fault","");release_controls()
  print("STAGE18_KEY_ROOM_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-key-platforms" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var platforms: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformCrumble")
  platforms.sort_custom(func(a,b):return a.position.z<b.position.z)
  print("STAGE18_KEY_PLATFORMS: ",JSON.stringify({"player":str(world.source_player_actor.position),"platforms":platforms.map(func(a):return {"position":str(a.position),"pc":a.vm.pc})}))
  var reached: Dictionary=await walk_to(world,Vector3(11.4,0,3.6),right_delta)
  fault=reached.get("fault","");release_controls()
  for platform in platforms:
   if not fault.is_empty():break
   reached=await jump_to_actor(world,platform,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await jump_to_actor(world,Vector3(16.5,0,10),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  print("STAGE18_KEY_PLATFORM_CHECK: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-silver-key" in OS.get_cmdline_user_args():
  var base: Node3D=null
  var floating: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SmashBlock" and (base==null or actor.position.z<base.position.z):base=actor
   if actor.source_name=="SmashBlockFloat":floating=actor
  if base==null or floating==null:fault="Silver pedestal boxes missing"
  else:
   print("STAGE18_SILVER_PEDESTAL: ",JSON.stringify({"base":str(base.position),"float":str(floating.position),"player":str(world.source_player_actor.position)}))
   var pedestal_point := Vector3(16.5,0,16.5)
   var floor_hit: Dictionary=world.source_raw_floor_query(pedestal_point)
   if floor_hit.has("height_units"):pedestal_point.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await walk_to(world,pedestal_point,right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,base,right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,floating,right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,floating,right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty() and world.source_level_script_state==0:fault="Silver key was not collected"
   print("STAGE18_SILVER_KEY_CHECK: ",JSON.stringify({"fault":fault,"key_state":world.source_level_script_state,"flags":world.source_map_entity_flags,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-pedestal-rewards" in OS.get_cmdline_user_args():
  var before_crystals: int=world.source_pickup_counts[1]
  var boxes: Array=world.source_actors.filter(func(a):return a.source_name in ["SmashBlockFloat","SmashBlock"])
  boxes.sort_custom(func(a,b):return a.position.y>b.position.y)
  if boxes.size()!=5:fault="Silver-key pedestal reward boxes incomplete"
  for box in boxes:
   if not fault.is_empty():break
   if not is_instance_valid(box):fault="Unverified pedestal box retired before collection";break
   if (int(world.source_map_entity_flags.get("MP018_04.MAP",{}).get(box.source_map_entity_index,0))&4)!=0:continue
   print("STAGE18_PEDESTAL_BOX_START: ",JSON.stringify({"position":str(box.position),"pc":box.vm.pc,"parameters":box.vm.parameters,"flags":world.source_map_entity_flags,"inventory":world.source_pickup_counts}))
   var reached: Dictionary=await jump_to_actor(world,box,right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():fault=await stomp_reward_box(world,box)
  if fault.is_empty():
   for index in range(5,10):
    if (int(world.source_map_entity_flags.get("MP018_04.MAP",{}).get(index,0))&4)==0:fault="Pedestal authored box marker missing: "+str(index);break
   if world.source_pickup_counts[1]!=before_crystals+25:fault="Five pedestal boxes did not yield all25 crystals"
  print("STAGE18_PEDESTAL_REWARDS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-worm-crystals" in OS.get_cmdline_user_args():
  var worm: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="BigWorm":worm=actor;break
  if worm==null:fault="Crystal-cluster worm missing"
  var crystals: Array=world.source_actors.filter(func(a):return a.source_name=="Crystal").map(func(a):return {"index":a.source_map_entity_index,"position":a.position})
  crystals.sort_custom(func(a,b):return a.index<b.index)
  for crystal in crystals:
   if not fault.is_empty():break
   var index: int=crystal.index
   if (int(world.source_map_entity_flags.get("MP018_04.MAP",{}).get(index,0))&4)!=0:continue
   var retreat_x: float=1.0 if world.source_player_actor.position.x<2.9 else 6.0
   var approach_x: float=1.0 if crystal.position.x<2.9 else 5.0
   var reached: Dictionary={}
   for point in [Vector3(retreat_x,5.25,world.source_player_actor.position.z),Vector3(retreat_x,5.25,18.3),Vector3(approach_x,5.25,18.3),Vector3(approach_x,5.25,clampf(crystal.position.z,20,22))]:
    reached=await walk_to(world,point,right_delta)
    fault=reached.get("fault","");release_controls()
    if not fault.is_empty():break
   if not fault.is_empty():break
   for tick in range(500):
    if worm.vm.pc==411 and worm.vm.wait_counter>90 and (int(worm.primary_flags)&0x10000)==0:break
    world.sample_source_player_controls();world.tick_source_actors()
   if worm.vm.pc!=411 or (int(worm.primary_flags)&0x10000)!=0:fault="Worm recovery window missing";break
   reached=await walk_to(world,crystal.position,right_delta,false,null,1.8,"",40,func():return (int(world.source_map_entity_flags.get("MP018_04.MAP",{}).get(index,0))&4)!=0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   for index in range(14,22):
    if (int(world.source_map_entity_flags.get("MP018_04.MAP",{}).get(index,0))&4)==0:fault="Worm crystal marker missing: "+str(index);break
  print("STAGE18_WORM_CRYSTALS: ",JSON.stringify({"fault":fault,"flags":world.source_map_entity_flags,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-red-seed" in OS.get_cmdline_user_args():
  var seed: Node3D=null
  var worm: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SeedRed":seed=actor
   if actor.source_name=="BigWorm":worm=actor
  var before_lives: int=world.source_pickup_counts[3]
  if seed==null or worm==null:fault="Red seed or worm missing"
  if fault.is_empty():
   for point in [Vector3(1,5.25,world.source_player_actor.position.z),Vector3(1,5.25,18.3),Vector3(6,5.25,18.3),Vector3(6,5.25,21)]:
    var reached: Dictionary=await walk_to(world,point,right_delta)
    fault=reached.get("fault","");release_controls()
    if not fault.is_empty():break
  if fault.is_empty():
   for tick in range(500):
    if worm.vm.pc==411 and (int(worm.primary_flags)&0x10000)==0:break
    world.sample_source_player_controls();world.tick_source_actors()
   print("STAGE18_RED_SEED_WORM: ",JSON.stringify({"pc":worm.vm.pc,"wait":worm.vm.wait_counter,"distance":worm.vm.evaluate([{"op":3,"index":28},{"op":18}]),"position":str(worm.position),"player":str(world.source_player_actor.position)}))
   if worm.vm.pc!=411:fault="Red seed worm recovery missing"
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(4.5,5.25,21),right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(3,4.274414,21),right_delta,60,0,16,Callable(),func():return world.source_pickup_counts[3]>before_lives)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and world.source_pickup_counts[3]!=before_lives+1:fault="Red seed did not yield extra life"
  print("STAGE18_RED_SEED: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"player":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--return-stage18-worm-loot" in OS.get_cmdline_user_args():
  var reached: Dictionary=await jump_to_actor(world,Vector3(1.5,5.25,21),right_delta,60,0)
  fault=reached.get("fault","");release_controls()
  for point in [Vector3(1,5.25,18.3),Vector3(6,5.25,18.3),Vector3(16.5,2.625,19.5),Vector3(16.5,2.625,16.5)]:
   if not fault.is_empty():break
   reached=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
  print("STAGE18_WORM_LOOT_RETURN: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage18-key-return" in OS.get_cmdline_user_args():
  var point := Vector3(16.5,0,16.5)
  var floor_hit: Dictionary=world.source_raw_floor_query(point)
  if floor_hit.has("height_units"):point.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
  var reached: Dictionary=await jump_to_actor(world,point,right_delta)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await walk_to(world,Vector3(16.5,0,10),right_delta)
   fault=reached.get("fault","");release_controls()
  var platforms: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformCrumble")
  platforms.sort_custom(func(a,b):return a.position.z>b.position.z)
  for platform in platforms:
   if not fault.is_empty():break
   reached=await jump_to_actor(world,platform,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await jump_to_actor(world,Vector3(11.1,0,3),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await walk_to(world,Vector3(3,0,3),right_delta,false,null,1.8,"MP018_01.MAP")
   fault=reached.get("fault","");release_controls()
  if fault.is_empty() and world.source_level_script_state==0:fault="Return lost collected silver key"
  print("STAGE18_KEY_RETURN: ",JSON.stringify({"fault":fault,"room":world.map_name,"key_state":world.source_level_script_state,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-cage" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var cage: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="GobboCage":cage=actor;break
  if cage==null:fault="Switch-covering cage missing"
  else:
   var reached: Dictionary=await walk_to(world,Vector3(9,world.source_player_actor.position.y,9),right_delta)
   fault=reached.get("fault","");release_controls()
   print("STAGE18_CAGE_PLATFORMS: ",JSON.stringify(world.source_actors.filter(func(a):return a.source_name in ["PlatformSpin","PlatformStepStone"]).map(func(a):return {"name":a.source_name,"position":str(a.position),"pc":a.vm.pc,"angles":str(a.source_angles)})))
   if fault.is_empty() and "--cross-stage18-cage-platforms" in OS.get_cmdline_user_args():
    reached=await walk_to(world,Vector3(8.5,3.6,9.2),right_delta)
    fault=reached.get("fault","");release_controls()
    print("STAGE18_CAGE_TAKEOFF: ",JSON.stringify({"player":str(world.source_player_actor.position),"floor":world.source_raw_floor_query(world.source_player_actor.position),"ceiling":world.source_ceiling_query_result(world.source_player_actor.position),"ground":world.source_player_actor.source_ground}))
    var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin")
    spins.sort_custom(func(a,b):return a.position.distance_squared_to(world.source_player_actor.position)<b.position.distance_squared_to(world.source_player_actor.position))
    var stone: Node3D=null
    for actor in world.source_actors:
     if actor.source_name=="PlatformStepStone":stone=actor;break
    if spins.is_empty() or stone==null:fault="Cage crossing supports missing"
    if fault.is_empty():
     if "--time-stage18-spinner" in OS.get_cmdline_user_args():fault=await board_stage18_spinner(world,spins,right_delta)
     else:
      reached=await jump_to_actor(world,spins[0],right_delta,30,0)
      fault=reached.get("fault","");release_controls()
    if fault.is_empty():
     reached=await jump_to_actor(world,stone,right_delta,30,0)
     fault=reached.get("fault","");release_controls()
    if fault.is_empty():
     fault=await board_stage18_spinner(world,spins,right_delta,Vector3(4.8,4.047363,12.3),350,18)
    if fault.is_empty():
     var button: Node3D=null
     for actor in world.source_actors:
      if actor.source_name=="SwitchPlatformSingle":button=actor;break
     if button==null:fault="Cage switch support missing"
     else:
      reached=await jump_to_actor(world,button.position,right_delta,60,0)
      fault=reached.get("fault","");release_controls()
      print("STAGE18_SWITCH_CHECK: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"trigger_platforms":world.source_actors.filter(func(a):return a.source_name=="SwitchTriggerPlat").size()}))
      if fault.is_empty() and world.source_actors.filter(func(a):return a.source_name=="SwitchTriggerPlat").is_empty():fault="Cage switch did not spawn authored trigger platform"
   if fault.is_empty() and world.source_level_script_state!=0:
    reached=await walk_to(world,cage.position+Vector3(1,0,0),right_delta,true,null,1.8,"",40,func():return world.source_level_script_state==0)
    fault=reached.get("fault","");release_controls()
   for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
   print("STAGE18_TRIGGER_PLATFORMS: ",JSON.stringify(world.source_actors.filter(func(a):return a.source_name=="SwitchTriggerPlat").map(func(a):return {"position":str(a.position),"pc":a.vm.pc,"globals":a.vm.globals})))
   if fault.is_empty() and world.source_level_script_state!=0:fault="Cage did not consume silver key"
   print("STAGE18_CAGE_CHECK: ",JSON.stringify({"fault":fault,"key_state":world.source_level_script_state,"cage":str(cage.position) if is_instance_valid(cage) else "retired","pc":cage.vm.pc if is_instance_valid(cage) else -1,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--return-stage18-switch" in OS.get_cmdline_user_args():
  var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin")
  var stone: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformStepStone":stone=actor;break
  if stone==null or spins.size()!=2:fault="Switch return supports missing"
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(4.5,4.047363,12.3),350,18)
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,stone.position+Vector3(0.5,0,0),right_delta,30,0,21,func():return int(world.source_player_actor.source_ground.get("actor",-1))==stone.source_pool_id and (int(world.source_player_actor.secondary_flags)&2)!=0)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=stone.source_pool_id or (int(world.source_player_actor.secondary_flags)&2)==0):fault="Return did not land on central stone"
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(6.3,4.047363,10.0),1400,18)
  if fault.is_empty():
   var spinner: Node3D=null
   for actor in spins:
    if actor.source_pool_id==int(world.source_player_actor.source_ground.get("actor",-1)):spinner=actor;break
   if spinner==null:fault="Return dismount spinner support missing"
   else:
    for tick in range(300):
     release_controls()
     var angle: int=int(spinner.source_angles.y)&4095
     if angle>=1500 and angle<=1545:break
     world.sample_source_player_controls();world.tick_source_actors()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(8.5,3.6,9.2),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  print("STAGE18_SWITCH_RETURN: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-heart-platform" in OS.get_cmdline_user_args():
  var platform: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SwitchTriggerPlat":platform=actor;break
  if platform==null:fault="Heart-box access platform missing"
  for point in [Vector3(15,3.6,9),Vector3(18.375,3.6,9.4)]:
   if not fault.is_empty():break
   var reached: Dictionary=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,platform,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=platform.source_pool_id or (int(world.source_player_actor.secondary_flags)&2)==0):fault="Heart-box platform support not reached"
  print("STAGE18_HEART_PLATFORM: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-heart-box" in OS.get_cmdline_user_args():
  var box: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SmashBlock_Red":box=actor;break
  if box==null:fault="Heart box missing"
  var before_lives: int=world.source_pickup_counts[3]
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(18.375,3.746338,12.4),right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,box,right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   for tick in range(240):
    release_controls()
    if tick in [12,13,14,15] or (tick>=22 and tick<100):Input.action_press("jump")
    world.sample_source_player_controls();world.tick_source_actors()
    if world.source_pickup_counts[3]!=before_lives:break
   release_controls()
   if world.source_pickup_counts[3]!=before_lives+1:fault="Heart box did not yield extra life"
  print("STAGE18_HEART_BOX: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position),"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-heart-return" in OS.get_cmdline_user_args():
  var platform: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SwitchTriggerPlat":platform=actor;break
  if platform==null:fault="Heart return platform missing"
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(18.375,3.6,14.7),right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,platform,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
   print("STAGE18_HEART_RETURN_PLATFORM: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"inventory":world.source_pickup_counts}))
  if fault.is_empty() and "--wait-stage18-heart-dismount" in OS.get_cmdline_user_args():
   var wait_lives: int=world.source_pickup_counts[3]
   var clear := false
   for tick in range(900):
    release_controls()
    var enemies: Array=world.source_actors.filter(func(a):return a.source_name.begins_with("Dantini"))
    if enemies.is_empty() or enemies.all(func(a):return a.position.x<15.0):clear=true;break
    world.sample_source_player_controls();world.tick_source_actors()
    if world.source_pickup_counts[3]<wait_lives:fault="Heart dismount wait lost a life";break
   if fault.is_empty() and not clear:fault="Heart dismount enemy window missing"
   print("STAGE18_HEART_DISMOUNT_WINDOW: ",JSON.stringify({"fault":fault,"clear":clear,"inventory":world.source_pickup_counts}))
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(18.375,3.6,9.4),right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(25.5,3.6,9),right_delta,false,null,1.8,"MP018_04.MAP")
   fault=reached.get("fault","");release_controls()
  print("STAGE18_HEART_RETURN: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-room5-entry" in OS.get_cmdline_user_args():
  if world.map_name!="MP018_04.MAP":fault="Room5 route must begin in silver-key room"
  if fault.is_empty() and "--fight-stage18-revisit-fire" in OS.get_cmdline_user_args():fault=await fight_stage18_fire(world,right_delta)
  var platforms: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformCrumble")
  platforms.sort_custom(func(a,b):return a.position.z<b.position.z)
  if fault.is_empty():
   var reached: Dictionary={}
   if "--dodge-stage18-revisit-fire" in OS.get_cmdline_user_args():
    reached=await walk_to(world,Vector3(7.5,0,3.6),right_delta)
    if reached.get("fault","").is_empty():reached=await jump_to_actor(world,Vector3(11.4,0,3.6),right_delta,30,0,35)
   else:reached=await walk_to(world,Vector3(11.4,0,3.6),right_delta)
   fault=reached.get("fault","");release_controls()
  for platform in platforms:
   if not fault.is_empty():break
   var reached: Dictionary=await jump_to_actor(world,platform,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(16.5,0,10),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty() and "--fight-stage18-raised-fire" in OS.get_cmdline_user_args():fault=await fight_stage18_fire(world,right_delta,11,Vector3(16.5,0,14.3))
  for point in [Vector3(16.5,2.625,16.5),Vector3(18,2.7,16.5),Vector3(18,2.7,20.5),Vector3(6,5.25,20.5),Vector3(6,5.25,18.3),Vector3(3,5.25,18.3)]:
   if not fault.is_empty():break
   var reached: Dictionary=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(3,5.25,15),right_delta,false,null,1.8,"MP018_05.MAP")
   fault=reached.get("fault","");release_controls()
  print("STAGE18_ROOM5_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage18-room5-crystals" in OS.get_cmdline_user_args():
  if world.map_name!="MP018_05.MAP":fault="Room5 crystals require normal room5 arrival"
  var crystals: Dictionary={}
  for actor in world.source_actors:
   if actor.source_name=="Crystal":crystals[actor.source_map_entity_index]=actor.position
  for index in [0,1,2,3]:
   if not fault.is_empty():break
   var reached: Dictionary=await walk_to(world,crystals[index],right_delta,false,null,1.8,"",40,func():return (int(world.source_map_entity_flags.get("MP018_05.MAP",{}).get(index,0))&4)!=0)
   fault=reached.get("fault","");release_controls()
  var stone: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index==11:stone=actor;break
  if stone==null:fault="Room5 central crossing stone missing"
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,stone,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var destination := Vector3(12,0,13.5)
   var hit: Dictionary=world.source_raw_floor_query(destination)
   if hit.has("height_units"):destination.y=int(hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await jump_to_actor(world,destination,right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  for index in [7,6,5,4]:
   if not fault.is_empty():break
   if (int(world.source_map_entity_flags.get("MP018_05.MAP",{}).get(index,0))&4)!=0:continue
   var reached: Dictionary=await walk_to(world,crystals[index],right_delta,false,null,1.8,"",40,func():return (int(world.source_map_entity_flags.get("MP018_05.MAP",{}).get(index,0))&4)!=0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   for index in range(8):
    if (int(world.source_map_entity_flags.get("MP018_05.MAP",{}).get(index,0))&4)==0:fault="Room5 crystal marker missing: "+str(index);break
  print("STAGE18_ROOM5_CRYSTALS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-gold-room" in OS.get_cmdline_user_args():
  var reached: Dictionary=await walk_to(world,Vector3(6,0,18),right_delta,false,null,1.8,"MP018_02.MAP")
  fault=reached.get("fault","");release_controls()
  print("STAGE18_GOLD_ROOM: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-gold-room-boxes" in OS.get_cmdline_user_args():
  var boxes: Array=world.source_actors.filter(func(a):return a.source_name=="SmashBlock" and a.source_map_entity_index in [3,4])
  boxes.sort_custom(func(a,b):return a.position.z<b.position.z)
  if boxes.size()!=2:fault="Gold-room entrance boxes missing"
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(12,0,24),right_delta)
   fault=reached.get("fault","");release_controls()
  for box in boxes:
   if not fault.is_empty():break
   var reached: Dictionary=await jump_to_actor(world,box,right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():fault=await stomp_reward_box(world,box)
  print("STAGE18_GOLD_ROOM_BOXES: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-gold-first-spinner" in OS.get_cmdline_user_args():
  var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [7,8])
  var stone: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index==9:stone=actor;break
  if spins.size()!=2 or stone==null:fault="Gold-room first spinner supports missing"
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(10.8,0,24),right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(9,0.449707,24),1400,18)
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,stone,right_delta,30,0,18)
   fault=reached.get("fault","");release_controls()
  print("STAGE18_GOLD_FIRST_SPINNER: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-gold-crumble" in OS.get_cmdline_user_args():
  var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [7,8])
  var gold_crumble: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformCrumble" and actor.source_map_entity_index==13:gold_crumble=actor;break
  if spins.size()!=2 or gold_crumble==null:fault="Gold-room middle crossing supports missing"
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(6,0.449707,24),3450,18)
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,gold_crumble,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=gold_crumble.source_pool_id or (int(world.source_player_actor.secondary_flags)&2)==0):fault="Gold middle crumble not supported"
  print("STAGE18_GOLD_CRUMBLE: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"next_spins":world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [11,12]).map(func(a):return {"position":str(a.position),"angle":a.source_angles.y})}))
 if fault.is_empty() and "--verify-stage18-gold-second-spinner" in OS.get_cmdline_user_args():
  var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [11,12])
  var stone: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index==10:stone=actor;break
  if spins.size()!=2 or stone==null:fault="Gold-room second spinner supports missing"
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(1.8,0.449707,22.6),300,25)
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,stone,right_delta,30,0,18)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=stone.source_pool_id or (int(world.source_player_actor.secondary_flags)&2)==0):fault="Gold second stone not supported"
  print("STAGE18_GOLD_SECOND_SPINNER: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-gold-north-box" in OS.get_cmdline_user_args():
  var north_crumble: Node3D=null
  var box: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformCrumble" and actor.source_map_entity_index==15:north_crumble=actor
   if actor.source_name=="SmashBlock" and actor.source_map_entity_index==16:box=actor
  if north_crumble==null or box==null:fault="Gold-room northern supports missing"
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,north_crumble,right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,box,right_delta,60,0)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():fault=await stomp_reward_box(world,box)
  print("STAGE18_GOLD_NORTH_BOX: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage18-gold-key" in OS.get_cmdline_user_args():
  var supports: Dictionary={}
  var key_position := Vector3.ZERO
  for actor in world.source_actors:
   if actor.source_name in ["PlatformSpin","PlatformStepStone"] and actor.source_map_entity_index in [0,1,2]:supports[actor.source_map_entity_index]=actor
   if actor.source_name=="KeyForLockedDoor":key_position=actor.position
  if supports.size()!=3 or key_position==Vector3.ZERO:fault="Gold-key final supports or key missing"
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(1.5,0,13.2),right_delta)
   fault=reached.get("fault","");release_controls()
  for index in [2,1,0]:
   if not fault.is_empty():break
   var reached: Dictionary=await jump_to_actor(world,supports[index],right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(1.5,0,4.5),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,key_position,right_delta,false,null,1.8,"",40,func():return world.source_key_collected==1)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and world.source_key_collected!=1:fault="Authored gold key not collected"
  print("STAGE18_GOLD_KEY: ",JSON.stringify({"fault":fault,"key_latch":world.source_key_collected,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"player":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage18-gold-return-front" in OS.get_cmdline_user_args():
  var supports: Dictionary={}
  for actor in world.source_actors:
   if actor.source_name in ["PlatformSpin","PlatformStepStone"] and actor.source_map_entity_index in [0,1,2]:supports[actor.source_map_entity_index]=actor
  if world.source_key_collected!=1 or supports.size()!=3:fault="Gold return requires collected key and supports"
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(1.5,0,4.5),right_delta)
   fault=reached.get("fault","");release_controls()
  for index in [0,1,2]:
   if not fault.is_empty():break
   var reached: Dictionary=await jump_to_actor(world,supports[index],right_delta,30,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(1.5,0,13.2),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty() and world.source_key_collected!=1:fault="Gold return lost key latch"
  print("STAGE18_GOLD_RETURN_FRONT: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"key_latch":world.source_key_collected,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage18-gold-return-crumble" in OS.get_cmdline_user_args():
  var north_crumble: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformCrumble" and actor.source_map_entity_index==15:north_crumble=actor;break
  if north_crumble==null:fault="Gold return northern crumble missing"
  if fault.is_empty() and "--sync-stage18-gold-return" in OS.get_cmdline_user_args():
   var wait_lives: int=world.source_pickup_counts[3]
   for tick in range(250):
    release_controls();world.sample_source_player_controls();world.tick_source_actors()
    if world.source_pickup_counts[3]<wait_lives:fault="Safe gold return wait lost a life";break
   print("STAGE18_GOLD_RETURN_SYNC: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"spins":world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [11,12]).map(func(a):return {"angle":a.source_angles.y,"position":str(a.position)})}))
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(1.5,0,14.9),right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var landed := func():return int(world.source_player_actor.source_ground.get("actor",-1))==north_crumble.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
   var reached: Dictionary=await jump_to_actor(world,north_crumble,right_delta,30,0,35,landed,landed)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and not landed.call():fault="Gold return northern crumble not supported"
  print("STAGE18_GOLD_RETURN_CRUMBLE: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"key_latch":world.source_key_collected,"inventory":world.source_pickup_counts,"next_spins":world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [11,12]).map(func(a):return {"position":str(a.position),"angle":a.source_angles.y})}))
 if fault.is_empty() and "--verify-stage18-gold-return-second-stone" in OS.get_cmdline_user_args():
  var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [11,12])
  var supports: Dictionary={}
  for actor in world.source_actors:
   if actor.source_map_entity_index in [10,13] and actor.source_name in ["PlatformStepStone","PlatformCrumble"]:supports[actor.source_map_entity_index]=actor
  if supports.size()!=2 or spins.size()!=2:fault="Gold middle return supports missing"
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(1.8,0.449707,19.8),2350,18,95)
  for index in [10,13]:
   if not fault.is_empty():break
   var target: Node3D=supports[index]
   var landed := func():return int(world.source_player_actor.source_ground.get("actor",-1))==target.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0
   var reached: Dictionary=await jump_to_actor(world,target,right_delta,30,0,18 if index==10 else 35,landed,landed)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and not landed.call():fault="Gold middle return support missing: "+str(index)
   if fault.is_empty() and index==10 and "--sync-stage18-gold-first-return" in OS.get_cmdline_user_args():
    var wait_lives: int=world.source_pickup_counts[3]
    var ready := false
    for tick in range(300):
     release_controls()
     for actor in world.source_actors:
      if actor.source_name=="PlatformSpin" and actor.source_map_entity_index in [7,8] and (int(actor.source_angles.y)&4095)>=500 and (int(actor.source_angles.y)&4095)<=545:ready=true;break
     if ready:break
     world.sample_source_player_controls();world.tick_source_actors()
     if world.source_pickup_counts[3]<wait_lives:fault="First return synchronization lost a life";break
    if fault.is_empty() and not ready:fault="First return synchronization window missing"
    print("STAGE18_GOLD_FIRST_RETURN_SYNC: ",JSON.stringify({"fault":fault,"ready":ready,"player":str(world.source_player_actor.position),"spins":world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [7,8]).map(func(a):return {"angle":a.source_angles.y,"position":str(a.position)})}))
  if fault.is_empty() and world.source_key_collected!=1:fault="Middle return lost gold key"
  print("STAGE18_GOLD_RETURN_SECOND_STONE: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"key_latch":world.source_key_collected,"inventory":world.source_pickup_counts,"next_spins":world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [7,8]).map(func(a):return {"angle":a.source_angles.y,"position":str(a.position)})}))
 if fault.is_empty() and "--verify-stage18-gold-return-door" in OS.get_cmdline_user_args():
  var spins: Array=world.source_actors.filter(func(a):return a.source_name=="PlatformSpin" and a.source_map_entity_index in [7,8])
  var stone: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index==9:stone=actor;break
  if spins.size()!=2 or stone==null:fault="Gold first return supports missing"
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(6,0.449707,24),3330,25,180)
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,stone,right_delta,30,0,18)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():fault=await board_stage18_spinner(world,spins,right_delta,Vector3(9,0.449707,24),1400,18)
  if fault.is_empty():
   var reached: Dictionary=await jump_to_actor(world,Vector3(10.8,0,24),right_delta,60,0)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(18,0,24),right_delta,false,null,1.8,"MP018_05.MAP")
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and world.source_key_collected!=1:fault="Normal room5 return lost gold key"
  print("STAGE18_GOLD_RETURN_DOOR: ",JSON.stringify({"fault":fault,"room":world.map_name,"key_latch":world.source_key_collected,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage18-jigsaw-junction" in OS.get_cmdline_user_args():
  if world.map_name!="MP018_05.MAP" or world.source_key_collected!=1:fault="Jigsaw approach requires normal gold-key return"
  for point in [Vector3(9,0,18),Vector3(12,0,16.5)]:
   if not fault.is_empty():break
   var hit: Dictionary=world.source_raw_floor_query(point)
   if hit.has("height_units"):point.y=int(hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   var destination := Vector3(12,0,13.5)
   var hit: Dictionary=world.source_raw_floor_query(destination)
   if hit.has("height_units"):destination.y=int(hit.height_units)*world.CELL_METERS/4096.0
   var reached: Dictionary=await jump_to_actor(world,destination,right_delta,60,0,35)
   fault=reached.get("fault","");release_controls()
  var stones: Dictionary={}
  for actor in world.source_actors:
   if actor.source_name=="PlatformStepStone" and actor.source_map_entity_index in [11,8]:stones[actor.source_map_entity_index]=actor
  if stones.size()!=2:fault="Jigsaw junction stones missing"
  for index in [11,8]:
   if not fault.is_empty():break
   var target: Node3D=stones[index]
   var reached: Dictionary=await jump_to_actor(world,target,right_delta,30,0,35)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and (int(world.source_player_actor.source_ground.get("actor",-1))!=target.source_pool_id or int(world.source_player_actor.source_ground.get("mode",0))!=2 or (int(world.source_player_actor.secondary_flags)&2)==0):fault="Jigsaw junction stone not supported: "+str(index)
  print("STAGE18_JIGSAW_JUNCTION: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts,"key_latch":world.source_key_collected,"platforms":world.source_actors.filter(func(a):return a.source_name in ["PlatformRotate","PlatformCrumble","PlatformStepStone"] and a.source_map_entity_index>=13).map(func(a):return {"index":a.source_map_entity_index,"name":a.source_name,"position":str(a.position),"angles":str(a.source_angles),"pc":a.vm.pc})}))
 if fault.is_empty() and "--verify-stage18-first-wheel" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_wheel.gd").board(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-wheel-middle" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_wheel.gd").middle(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-second-wheel" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_wheel.gd").second(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-wheel-exit" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_wheel.gd").leave(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-locked-room" in OS.get_cmdline_user_args():
  var reached: Dictionary=await walk_to(world,Vector3(30,3.6,6),right_delta,false,null,1.8,"MP018_03.MAP")
  fault=reached.get("fault","");release_controls()
  if fault.is_empty() and world.source_key_collected!=0:fault="Original locked door did not consume gold key"
  print("STAGE18_LOCKED_ROOM: ",JSON.stringify({"fault":fault,"room":world.map_name,"key_latch":world.source_key_collected,"inventory":world.source_pickup_counts,"player":str(world.source_player_actor.position)}))
  if fault.is_empty():print("STAGE18_ROOM3_LAYOUT: ",JSON.stringify(world.source_actors.filter(func(a):return a.source_name in ["PlatformSpin","PlatformDead","Crystal","SeedRed","NormalDoor"]).map(func(a):return {"index":a.source_map_entity_index,"name":a.source_name,"position":str(a.position),"pc":a.vm.pc,"parameters":a.vm.parameters})))
 if fault.is_empty() and "--verify-stage18-room3-left-crystals" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").left_shore(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-room3-right-crystals" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").right_shore(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-room3-first-spin" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").first_spin(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-room3-second-spin" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").second_spin(self,world,right_delta)
 if fault.is_empty() and ("--verify-stage18-room3-third-spin" in OS.get_cmdline_user_args() or "--verify-stage18-room3-top-spin" in OS.get_cmdline_user_args()):fault=await preload("res://probe_stage18_room3_loot.gd").second_spin(self,world,right_delta,1,2)
 if fault.is_empty() and "--verify-stage18-room3-top-spin" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").climb_top(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-room3-high-life" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").high_life(self,world,right_delta,27,28)
 if fault.is_empty() and "--verify-stage18-room3-both-high-lives" in OS.get_cmdline_user_args():
  fault=await preload("res://probe_stage18_room3_loot.gd").return_top(self,world,right_delta)
  if fault.is_empty():fault=await preload("res://probe_stage18_room3_loot.gd").high_life(self,world,right_delta,25,26)
 if fault.is_empty() and "--verify-stage18-room3-high-exit" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").leave_high_lives(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-room3-return-door" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").return_room5(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-jigsaw-contact" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").collect_jigsaw(self,world,right_delta)
 if fault.is_empty() and "--verify-stage18-jigsaw-return" in OS.get_cmdline_user_args():fault=await preload("res://probe_stage18_room3_loot.gd").finish_jigsaw(self,world)
 if world.source_pickup_counts[3]<lives:fault="Secret entrance route lost a life"
 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 print("STAGE18_ENTRANCE_CHECK: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"scope":"Direct initial entry; sampled authored routes selected by flags. Earned full-stage/Jigsaw/save/render/headset proof unverified"}))
 return fault

func fight_stage18_fire(world: Node,right_delta: int,entity_index: int=23,staging: Vector3=Vector3(7.5,0,3.6)) -> String:
 var enemy: Node3D=null
 for actor in world.source_actors:
  if actor.source_name=="FireJumper" and actor.source_map_entity_index==entity_index:enemy=actor;break
 if enemy==null:return "Entrance FireJumper missing"
 var initial_y: float=enemy.position.y
 var lives: int=world.source_pickup_counts[3]
 var floor_hit: Dictionary=world.source_raw_floor_query(staging)
 if floor_hit.has("height_units"):staging.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
 var reached: Dictionary=await walk_to(world,staging,right_delta)
 if not reached.get("fault","").is_empty():return reached.fault
 for tick in range(240):
  release_controls()
  if not is_instance_valid(enemy) or not world.source_actors.has(enemy):return ""
  if enemy.vm.pc==65 and int(enemy.vm.parameters[6])==0 and not enemy.visible and enemy.position.y<initial_y-29:
   print("STAGE18_FIRE_DEFEATED: ",JSON.stringify({"pc":enemy.vm.pc,"wait":enemy.vm.wait_counter,"hidden":not enemy.visible,"position":str(enemy.position),"lives":world.source_pickup_counts[3],"scope":"Original defeat/respawn wait, not permanent removal"}))
   return ""
  var delta: Vector3=enemy.position-world.source_player_actor.position
  var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
  var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
  if abs(difference)>40:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
  if abs(difference)<80 and delta.length()>(1.1 if entity_index==11 else 1.7):Input.action_press("move_forward")
  if abs(difference)<80 and delta.length()<(1.3 if entity_index==11 else 2.0) and tick%12<3:Input.action_press("attack")
  world.sample_source_player_controls();world.tick_source_actors()
  if tick%5==0 and is_instance_valid(enemy):print("STAGE18_FIRE_FIGHT: ",JSON.stringify({"tick":tick,"player":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name,"enemy":str(enemy.position),"pc":enemy.vm.pc,"parameters":enemy.vm.parameters,"lives":world.source_pickup_counts[3]}))
  if world.source_pickup_counts[3]<lives:return "Directed FireJumper combat lost a life"
 release_controls()
 return "Directed FireJumper combat did not defeat enemy"

func board_stage18_spinner(world: Node,spins: Array,right_delta: int,landing: Vector3=Vector3(6.3,4.047363,10.5),angle_min: int=1400,forward_ticks: int=25,window_width: int=45) -> String:
 var lives: int=world.source_pickup_counts[3]
 for tick in range(120):
  release_controls()
  var delta: Vector3=landing-world.source_player_actor.position
  var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
  var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
  if abs(difference)<40:break
  Input.action_press("move_right" if difference*right_delta>0 else "move_left")
  world.sample_source_player_controls();world.tick_source_actors()
  if "--trace-stage18-boarding" in OS.get_cmdline_user_args() and tick%5==0:trace_stage18_boarding(world,tick,"align")
  if world.source_pickup_counts[3]<lives:release_controls();return "Spinner alignment lost a life"
 var selected: Node3D=null
 for tick in range(500):
  for spin in spins:
   var angle: int=int(spin.source_angles.y)&4095
   if angle>=angle_min and angle<=angle_min+window_width:selected=spin;break
  if selected!=null:break
  release_controls();world.sample_source_player_controls();world.tick_source_actors()
  if "--trace-stage18-boarding" in OS.get_cmdline_user_args() and tick%5==0:trace_stage18_boarding(world,tick,"wait")
  if world.source_pickup_counts[3]<lives:return "Spinner boarding wait lost a life"
 if selected==null:return "No approaching spinner boarding window"
 print("STAGE18_TIMED_SPINNER_START: ",JSON.stringify({"player":str(world.source_player_actor.position),"platform":str(selected.position),"angle":selected.source_angles.y}))
 var supported := false
 for tick in range(50):
  release_controls()
  if tick<16:Input.action_press("jump")
  var delta: Vector3=landing-world.source_player_actor.position
  if tick<forward_ticks and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
  world.sample_source_player_controls();world.tick_source_actors()
  if tick%5==0:print("STAGE18_TIMED_SPINNER_TRACE: ",JSON.stringify({"tick":tick,"player":str(world.source_player_actor.position),"platform":str(selected.position),"clip":world.source_player_actor.clip_name,"ground":world.source_player_actor.source_ground}))
  if tick>15 and int(world.source_player_actor.source_ground.get("actor",-1))==selected.source_pool_id and int(world.source_player_actor.source_ground.get("mode",0))==2 and (int(world.source_player_actor.secondary_flags)&2)!=0:supported=true;break
  if world.source_pickup_counts[3]<lives:return "Timed spinner jump lost a life"
 release_controls()
 print("STAGE18_TIMED_SPINNER_END: ",JSON.stringify({"supported":supported,"player":str(world.source_player_actor.position),"ground":world.source_player_actor.source_ground}))
 return "" if supported else "Timed spinner jump did not establish support"

func trace_stage18_boarding(world: Node,tick: int,phase: String) -> void:
 var player: Node3D=world.source_player_actor
 var owner_id: int=int(player.source_ground.get("actor",-1))
 print("STAGE18_BOARDING_STATE: ",JSON.stringify({"phase":phase,"tick":tick,"player":str(player.position),"yaw":player.source_angles.y,"clip":player.clip_name,"state":int(world.source_extended_globals.get(0,0))>>16,"primary":player.primary_flags,"secondary":player.secondary_flags,"ground":player.source_ground,"lives":world.source_pickup_counts[3],"owner":world.source_actors.filter(func(a):return a.source_pool_id==owner_id).map(func(a):return {"pc":a.vm.pc,"position":str(a.position),"primary":a.primary_flags,"secondary":a.secondary_flags,"visible":a.visible,"parameters":a.vm.parameters})}))
