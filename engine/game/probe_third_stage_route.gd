extends "res://probe_stage12_opening_pickups.gd"
var stage12_starting_lives: int=3
func probe() -> void:
 if "--from-earned-stage10" in OS.get_cmdline_user_args():
  await super.probe();return
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 var fault: String=await run_stage12(world)
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)

func continue_earned_stage(world: Node) -> String:
 var fault: String=await super.continue_earned_stage(world)
 if not fault.is_empty():return fault
 world.set_process(true);world.set_physics_process(true)
 for frame in range(60):await physics_frame
 Input.action_press("jump")
 for frame in range(4):await physics_frame
 Input.action_release("jump")
 for frame in range(180):
  await physics_frame
  if world.map_name=="MP012_00.MAP" and world.source_fade_phase=="":break
 if world.map_name!="MP012_00.MAP" or world.source_menu_state.selected_index!=2:
  print("STAGE12_EARNED_ENTRY_FAULT: ",JSON.stringify({"room":world.map_name,"selection":world.source_menu_state.selected_index}))
  return "Earned stage11 save/selector route did not enter stage12"
 print("STAGE12_EARNED_ENTRY: ",JSON.stringify({"progress":world.source_menu_progress_flags,"lives":world.source_pickup_counts[3],"selection":world.source_menu_state.selected_index}))
 return await run_stage12(world)

func run_stage12(world: Node) -> String:
 if "--verify-stage12-extras" in OS.get_cmdline_user_args():
  var extras_fault: String=await run_stage12_extras(world)
  if not extras_fault.is_empty():return extras_fault
 stage12_starting_lives=int(world.source_pickup_counts[3])
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 var prior: int=world.source_player_actor.source_angles.y
 for tick in range(12):
  Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
 release_controls()
 var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
 print("STAGE12_TURN_CALIBRATION: ",right_delta)
 var fault := ""
 if right_delta==0:fault="Stage12 turn calibration produced no movement"
 if "--verify-stage12-extras" in OS.get_cmdline_user_args():
  var obstacle: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SmashBlockGobbo":obstacle=actor;break
  if obstacle==null:fault="Opening Gobbo box missing after extras"
  else:
   var approach: Dictionary=await jump_to_actor(world,obstacle,right_delta)
   fault=approach.get("fault","");release_controls()
   if fault.is_empty():
    var point := Vector3(6,0,8.4)
    approach=await jump_to_actor(world,point,right_delta)
    fault=approach.get("fault","");release_controls()
 var expected_entrance_color: int=1 if "--verify-entrance-color" in OS.get_cmdline_user_args() else 0
 if fault.is_empty() and ("--verify-entrance-platform" in OS.get_cmdline_user_args() or "--verify-entrance-color" in OS.get_cmdline_user_args()):
  var runner: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="RunningPlatform":runner=actor;break
  if runner==null:fault="Missing entrance directional platform"
  else:
   var takeoff := Vector3(6,0,8.4) if "--verify-stage12-extras" in OS.get_cmdline_user_args() else Vector3(6,0,4.2)
   var reached: Dictionary=await walk_to(world,takeoff,right_delta,true)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty() and "--verify-stage12-extras" in OS.get_cmdline_user_args():
    var log_point := Vector3(6,0,6)
    var floor_hit: Dictionary=world.source_raw_floor_query(log_point)
    if floor_hit.has("height_units"):log_point.y=int(floor_hit.height_units)*world.CELL_METERS/4096.0
    reached=await jump_to_actor(world,log_point,right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,runner,right_delta)
    fault=reached.get("fault","");release_controls()
   print("STAGE12_ENTRANCE_PLATFORM: ",JSON.stringify({"fault":fault,"platform":str(runner.position),"player":str(world.source_player_actor.position)}))
   if fault.is_empty() and "--verify-entrance-color" in OS.get_cmdline_user_args():
    for returning in [false,true]:
     var red_jump := -1
     if returning:
      for tick in range(60):
       release_controls();world.sample_source_player_controls();world.tick_source_actors()
      if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Red pickup jump lost a life before return";break
     for tick in range(120):
      release_controls()
      var desired := 1024 if returning else 3072
      var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
      if abs(difference)<80:break
      Input.action_press("move_right" if difference*right_delta>0 else "move_left")
      world.sample_source_player_controls();world.tick_source_actors()
     for tick in range(600):
      release_controls()
      var offset: float=world.source_player_actor.position.x-runner.position.x
      if (returning and offset<0.35) or (not returning and offset> -0.35):Input.action_press("move_forward")
      if not returning and runner.position.x<0.6 and red_jump<0:red_jump=tick
      if red_jump>=0 and tick-red_jump<16:Input.action_press("jump")
      world.sample_source_player_controls();world.tick_source_actors()
      if tick%30==0:print("STAGE12_ARROW_RIDE: ",JSON.stringify({"returning":returning,"tick":tick,"platform":str(runner.position),"player":str(world.source_player_actor.position),"colors":world.source_bonus_mask}))
      if not returning and (world.source_bonus_mask&1)!=0:break
      if returning and runner.position.x>3.9:break
     release_controls()
     if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Entrance arrow ride lost a life";break
    if fault.is_empty() and (world.source_bonus_mask&1)==0:fault="Entrance red crystal was not collected"
    if fault.is_empty():
     reached=await jump_to_actor(world,Vector3(6,0,8.4),right_delta)
     fault=reached.get("fault","");release_controls()
    print("STAGE12_ENTRANCE_COLOR: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts,"platform":str(runner.position)}))
 var box: Node3D=null
 for actor in world.source_actors:
  if actor.source_name=="SmashBlockGobbo":box=actor;break
 print("STAGE12_START: ",JSON.stringify({"position":str(world.source_player_actor.position),"box":str(box.position) if box!=null else "missing"}))
 if box==null:fault="Missing stage12 opening Gobbo box"
 elif fault.is_empty():
  var reached: Dictionary
  if "--verify-entrance-color" in OS.get_cmdline_user_args():reached=await jump_to_actor(world,box,right_delta)
  else:reached=await walk_to(world,box.position,right_delta,true,box)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   for tick in range(240):
    release_controls()
    if tick in [12,13,14,15] or (tick>=22 and tick<100):Input.action_press("jump")
    world.sample_source_player_controls();world.tick_source_actors()
   release_controls()
   if world.source_pickup_counts[2]!=1:fault="Opening box did not rescue first Gobbo"

 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Stage12 opening route lost a life"
 print("STAGE12_FIRST_GOBBO: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position),"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage12-well" in OS.get_cmdline_user_args():
  var button: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="SwitchPlatforms":button=actor;break
  if button==null:fault="Missing opening platform switch"
  else:
   var reached: Dictionary=await walk_to(world,button.position,right_delta,true,button,1.8,"",40,func():return int(world.source_extended_globals.get(32,0))!=0)
   fault=reached.get("fault","");release_controls()
   for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
   print("STAGE12_SWITCH: ",JSON.stringify({"fault":fault,"parameters":button.vm.parameters,"activation":world.source_extended_globals.get(32,0),"platforms":world.source_actors.filter(func(a):return a.source_name.contains("Plat")).map(func(a):return {"name":a.source_name,"position":str(a.position)})}))
  if fault.is_empty():
   var platforms: Array=world.source_actors.filter(func(a):return a.source_name=="SwitchTriggerPlats")
   platforms.sort_custom(func(a,b):return a.position.z<b.position.z)
   for platform in platforms:
    for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
    for tick in range(120):
     release_controls()
     var delta: Vector3=platform.position-world.source_player_actor.position
     var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
     var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
     if abs(difference)<80:break
     Input.action_press("move_right" if difference*right_delta>0 else "move_left")
     world.sample_source_player_controls();world.tick_source_actors()
    for tick in range(60):
     release_controls()
     if tick<16:Input.action_press("jump")
     var delta: Vector3=platform.position-world.source_player_actor.position
     if tick<25 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
     world.sample_source_player_controls();world.tick_source_actors()
    release_controls()
    var crossed: Dictionary=await walk_to(world,platform.position,right_delta,true,platform)
    fault=crossed.get("fault","");release_controls()
    if not fault.is_empty():break
  if fault.is_empty():
   var lid: Node3D=null
   for actor in world.source_actors:
    if actor.source_name=="SmashLid":lid=actor;break
   if lid==null:fault="Missing stage12 well lid"
   else:
    var reached: Dictionary=await jump_to_actor(world,lid,right_delta)
    fault=reached.get("fault","");release_controls()
    if fault.is_empty():
     for tick in range(360):
      release_controls()
      if tick in [12,13,14,15] or (tick>=22 and tick<100):Input.action_press("jump")
      world.sample_source_player_controls();world.tick_source_actors()
      if not world.process_source_exit():fault=world.source_transition_fault;break
      if world.map_name=="MP012_04.MAP" and world.source_fade_phase=="":break
     release_controls()
     if world.map_name!="MP012_04.MAP":fault="Stage12 well did not enter room4"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Stage12 switch/well route lost a life"
  print("STAGE12_WELL_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
  if not fault.is_empty():
   for actor in world.source_actors:
    if actor.source_name in ["SwitchPlatforms","SwitchTrigger2"]:print("STAGE12_SOUND_BINDING: ",JSON.stringify({"name":actor.source_name,"parent":actor.source_parent_id,"globals":actor.vm.globals,"handles":actor.handles}))
 if fault.is_empty() and ("--inspect-shell-room" in OS.get_cmdline_user_args() or "--verify-shell-game" in OS.get_cmdline_user_args()):
  for tick in range(180):world.sample_source_player_controls();world.tick_source_actors()
  print("STAGE12_SHELL_ROOM: ",JSON.stringify(world.source_actors.map(func(a):return {"name":a.source_name,"position":str(a.position),"pc":a.vm.pc,"parameters":a.vm.parameters})))
 if fault.is_empty() and "--verify-shell-game" in OS.get_cmdline_user_args():
  var shell: Node3D=null
  for tick in range(1200):
   release_controls();world.sample_source_player_controls();world.tick_source_actors()
   for actor in world.source_actors:
    if actor.source_name=="ShellSmashBlock_Red":shell=actor;break
   if shell!=null:break
  if shell==null:fault="Missing tracked shell-game box"
  else:
   var reached: Dictionary=await walk_to(world,shell.position,right_delta,false,shell)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    for tick in range(600):
     release_controls()
     if tick in [12,13,14,15] or (tick>=22 and tick<100):Input.action_press("jump")
     world.sample_source_player_controls();world.tick_source_actors()
    release_controls()
    if world.source_pickup_counts[2]!=2:fault="Tracked shell box did not rescue second Gobbo"
  print("STAGE12_SHELL_RESULT: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-shell-return" in OS.get_cmdline_user_args():
  var reached: Dictionary=await walk_to(world,Vector3(6,0,0.7),right_delta,false,null,1.8,"MP012_00.MAP")
  fault=reached.get("fault","");release_controls()
  if fault.is_empty() and (world.source_pickup_counts[2]!=2 or world.source_pickup_counts[3]!=stage12_starting_lives):fault="Shell return lost earned inventory"
  print("STAGE12_SHELL_RETURN: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage12-next-room" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  for tick in range(120):
   release_controls()
   var difference := wrapi(1024-int(world.source_player_actor.source_angles.y),-2048,2048)
   if abs(difference)<80:break
   Input.action_press("move_right" if difference*right_delta>0 else "move_left")
   world.sample_source_player_controls();world.tick_source_actors()
  for tick in range(60):
   release_controls()
   if tick<16:Input.action_press("jump")
   if tick<25:Input.action_press("move_forward")
   world.sample_source_player_controls();world.tick_source_actors()
  release_controls()
  var reached: Dictionary=await walk_to(world,Vector3(15,0,21),right_delta)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await walk_to(world,Vector3(19.5,0,21),right_delta,false,null,1.8,"MP012_01.MAP")
   fault=reached.get("fault","");release_controls()
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Stage12 doorway route lost a life"
  print("STAGE12_ROOM1_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-third-gobbo-route" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var block: Node3D=null
  var platform: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PushBlock":block=actor
   if actor.source_name=="PlatformDead" and actor.position.z>12:platform=actor
  if block==null or platform==null:fault="Missing third-rescue push block/platform"
  else:
   var before: Vector3=block.position
   var reached: Dictionary=await walk_to(world,Vector3(3,0,11.2),right_delta)
   fault=reached.get("fault","");release_controls()
   print("STAGE12_PUSH_BLOCK: ",JSON.stringify({"fault":fault,"before":str(before),"after":str(block.position),"player":str(world.source_player_actor.position)}))
   if fault.is_empty() and block.position.distance_to(before)<0.5:fault="Push route did not move block"
   if fault.is_empty():
    reached=await walk_to(world,block.position,right_delta,false,block)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    for tick in range(20):world.sample_source_player_controls();world.tick_source_actors()
    for tick in range(120):
     release_controls()
     var delta: Vector3=platform.position-world.source_player_actor.position
     var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
     var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
     if abs(difference)<80:break
     Input.action_press("move_right" if difference*right_delta>0 else "move_left")
     world.sample_source_player_controls();world.tick_source_actors()
    for tick in range(60):
     release_controls()
     if tick<16:Input.action_press("jump")
     var delta: Vector3=platform.position-world.source_player_actor.position
     if tick<25 and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
     world.sample_source_player_controls();world.tick_source_actors()
    release_controls()
    reached=await walk_to(world,platform.position,right_delta,true,platform,3.0)
    fault=reached.get("fault","");release_controls()
    for tick in range(180):world.sample_source_player_controls();world.tick_source_actors()
    if fault.is_empty() and world.source_pickup_counts[2]!=3:fault="Raised platform did not rescue third Gobbo"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Third rescue route lost a life"
  print("STAGE12_THIRD_GOBBO: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage12-key" in OS.get_cmdline_user_args():
  var block: Node3D=null
  var platform: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PushBlock":block=actor
   if actor.source_name=="PlatformDead" and actor.position.z<12:platform=actor
  if block==null or platform==null:fault="Missing key-route support"
  else:
   var reached: Dictionary=await jump_to_actor(world,block,right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,platform,right_delta)
    fault=reached.get("fault","");release_controls()
    for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
    if fault.is_empty() and (int(world.source_map_entity_flags.get("MP012_01.MAP",{}).get(9,0))&5)==0:fault="Locked-door key was not collected"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Key route lost a life"
  print("STAGE12_KEY: ",JSON.stringify({"fault":fault,"state":world.source_level_script_state,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage12-lift-color" in OS.get_cmdline_user_args():
  var block: Node3D=null
  var lift: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PushBlock":block=actor
   if actor.source_name=="PlatformNormal":lift=actor
  if block==null or lift==null:fault="Missing block/lift color route"
  else:
   var reached: Dictionary=await jump_to_actor(world,block,right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await walk_to(world,Vector3(3,0,13.1),right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await walk_to(world,Vector3(3,0,9.3),right_delta)
    fault=reached.get("fault","");release_controls()
    print("STAGE12_PUSH_BACK: ",JSON.stringify({"fault":fault,"block":str(block.position),"player":str(world.source_player_actor.position)}))
   if fault.is_empty():
    reached=await jump_to_actor(world,block,right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,lift,right_delta)
    fault=reached.get("fault","");release_controls()
    for tick in range(300):world.sample_source_player_controls();world.tick_source_actors()
    if fault.is_empty() and (int(world.source_map_entity_flags.get("MP012_01.MAP",{}).get(11,0))&5)==0:fault="Lift color was not collected"
    if fault.is_empty() and world.source_player_actor.position.y<5:fault="Color lift did not raise player to upper landing"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Lift color route lost a life"
  print("STAGE12_LIFT_COLOR: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage12-locked-door" in OS.get_cmdline_user_args():
  for waypoint in [Vector3(6.75,5.25,7.65),Vector3(9,5.25,9)]:
   var reached: Dictionary=await jump_to_actor(world,waypoint,right_delta) if waypoint.x==6.75 else await walk_to(world,waypoint,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty() and "--verify-stage12-upper-boxes" in OS.get_cmdline_user_args():
   var boxes: Array=world.source_actors.filter(func(a):return a.source_name=="SmashBlock")
   boxes.sort_custom(func(a,b):return a.position.z<b.position.z)
   if boxes.size()!=2:fault="Upper room does not contain two reward boxes"
   for reward_box in boxes:
    if not fault.is_empty():break
    var reached: Dictionary=await jump_to_actor(world,reward_box,right_delta)
    fault=reached.get("fault","");release_controls()
    if fault.is_empty():fault=await stomp_reward_box(world,reward_box)
   if fault.is_empty():
    var reached: Dictionary=await jump_to_actor(world,Vector3(9,5.25,9),right_delta)
    fault=reached.get("fault","");release_controls()
   print("STAGE12_UPPER_BOXES: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags.get("MP012_01.MAP",{})}))
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(13.5,5.25,9),right_delta,false,null,1.8,"MP012_05.MAP")
   fault=reached.get("fault","");release_controls()
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Locked doorway route lost a life"
  if fault.is_empty() and world.source_key_collected!=0:fault="Locked door did not consume collected key"
  print("STAGE12_LOCKED_DOOR: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"key_latch":world.source_key_collected}))
 if fault.is_empty() and "--verify-crate-stairs" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var boxes: Array=world.source_actors.filter(func(a):return a.source_name in ["SmashBlock","SmashBlockFloat"])
  boxes.sort_custom(func(a,b):return a.position.z<b.position.z)
  if boxes.size()!=4:fault="Crate staircase does not contain four source boxes"
  if fault.is_empty():
   var approach: Dictionary=await walk_to(world,Vector3(6,0,3.5),right_delta)
   fault=approach.get("fault","");release_controls()
  for crate in boxes:
   if not fault.is_empty():break
   var reached: Dictionary
   reached=await jump_to_actor(world,crate,right_delta)
   fault=reached.get("fault","");release_controls()
   print("STAGE12_CRATE_STEP: ",JSON.stringify({"fault":fault,"crate":str(crate.position),"player":str(world.source_player_actor.position)}))
  if fault.is_empty() and world.source_player_actor.position.y<5:fault="Crate staircase did not reach upper height"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Crate staircase lost a life"
  print("STAGE12_CRATE_STAIRS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-upper-well-pickups" in OS.get_cmdline_user_args():
  var ledge: Dictionary=await jump_to_actor(world,Vector3(3.75,5.25,10.5),right_delta)
  fault=ledge.get("fault","");release_controls()
  for waypoint in [Vector3(3.75,5.25,10.5),Vector3(3.75,5.25,15),Vector3(8.1,5.25,14.4),Vector3(8.1,5.25,12.2),Vector3(8.1,0,9.0)]:
   if not fault.is_empty():break
   var reached: Dictionary
   if waypoint==Vector3(8.1,5.25,12.2):reached=await jump_to_actor(world,waypoint,right_delta,30)
   elif waypoint==Vector3(3.75,5.25,15):reached=await walk_to(world,waypoint,right_delta,false,null,1.8,"",80)
   elif waypoint==Vector3(8.1,0,9.0):reached=await jump_to_actor(world,waypoint,right_delta,30,0)
   else:reached=await walk_to(world,waypoint,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
   if fault.is_empty() and waypoint==Vector3(8.1,5.25,14.4):
    var worm: Node3D=null
    for actor in world.source_actors:
     if actor.source_name=="BigWorm":worm=actor;break
    if worm==null:fault="Upper worm missing"
    else:
     for tick in range(600):
      if worm.vm.pc==411 and (int(worm.primary_flags)&0x10000)==0:break
      release_controls();world.sample_source_player_controls();world.tick_source_actors()
      if tick%60==0:await process_frame
     if worm.vm.pc!=411 or (int(worm.primary_flags)&0x10000)!=0:fault="Upper worm did not reach authored recovery wait"
     print("STAGE12_WORM_RECOVERY: ",JSON.stringify({"fault":fault,"pc":worm.vm.pc,"position":str(world.source_player_actor.position),"lives":world.source_pickup_counts[3]}))
  for tick in range(1):world.sample_source_player_controls();world.tick_source_actors()
  if fault.is_empty() and world.source_pickup_counts[2]!=4:fault="Upper well did not yield fourth Gobbo"
  if fault.is_empty() and (int(world.source_map_entity_flags.get("MP012_05.MAP",{}).get(4,0))&5)==0:fault="Upper-well color was not collected"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Upper-well pickup route lost a life"
  print("STAGE12_UPPER_WELL_PICKUPS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage12-upper-return" in OS.get_cmdline_user_args():
  if "--verify-stage12-stair-rewards" in OS.get_cmdline_user_args():fault=await collect_stage12_stair_rewards(world,right_delta)
  for waypoint in [Vector3(8.1,0,3.6),Vector3(6,0,3.6)]:
   if not fault.is_empty():break
   var reached: Dictionary=await walk_to(world,waypoint,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(6,0,0),right_delta,false,null,1.8,"MP012_01.MAP")
   fault=reached.get("fault","");release_controls()
  if fault.is_empty() and (world.source_pickup_counts[2]!=4 or world.source_bonus_mask!=(6|expected_entrance_color) or world.source_pickup_counts[3]!=stage12_starting_lives):fault="Upper-room return lost earned inventory"
  print("STAGE12_UPPER_RETURN: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-room1-balloon-return" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var reached: Dictionary=await walk_to(world,Vector3(7.4,5.25,9),right_delta)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   for tick in range(120):
    release_controls()
    var difference := wrapi(3072-int(world.source_player_actor.source_angles.y),-2048,2048)
    if abs(difference)<80:break
    Input.action_press("move_right" if difference*right_delta>0 else "move_left")
    world.sample_source_player_controls();world.tick_source_actors()
   var attached := false
   var landed := false
   for tick in range(600):
    release_controls()
    if tick<16:Input.action_press("jump")
    if tick<10:Input.action_press("move_forward")
    world.sample_source_player_controls();world.tick_source_actors()
    if (int(world.source_extended_globals.get(0,0))>>16)==7:attached=true
    if tick%30==0:print("STAGE12_BALLOON_TRACE: ",JSON.stringify({"tick":tick,"attached":attached,"position":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name}))
    if world.source_player_actor.position.y<1 and (int(world.source_player_actor.secondary_flags)&2)!=0:landed=true;break
   release_controls()
   if not attached or not landed:fault="Room1 balloon did not attach and land"
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Balloon return lost a life"
  print("STAGE12_BALLOON_RETURN: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"position":str(world.source_player_actor.position)}))
 if fault.is_empty() and "--verify-stage12-cage-room" in OS.get_cmdline_user_args():
  for waypoint in [Vector3(3,0,12),Vector3(3,0,15)]:
   var reached: Dictionary=await walk_to(world,waypoint,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,Vector3(3,0,19.5),right_delta,false,null,1.8,"MP012_02.MAP")
   fault=reached.get("fault","");release_controls()
  if fault.is_empty() and (world.source_pickup_counts[2]!=4 or world.source_bonus_mask!=(6|expected_entrance_color) or world.source_pickup_counts[3]!=stage12_starting_lives):fault="Cage-room route lost earned inventory"
  print("STAGE12_CAGE_ROOM_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask}))
 if fault.is_empty() and "--verify-stage12-timer" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var button: Node3D=null
  var lift: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformSwch":button=actor
   if actor.source_name=="PlatformTimer":lift=actor
  if button==null or lift==null:fault="Missing timer switch/platform"
  else:
   var before: Vector3=lift.position
   var reached: Dictionary=await walk_to(world,button.position,right_delta,false,button)
   fault=reached.get("fault","");release_controls()
   for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
   if fault.is_empty() and button.source_scale.y!=2048:fault="Timed button did not enter its pressed half-height state"
   if fault.is_empty() and lift.position.y>=before.y-0.5:fault="Timed button did not lower platform"
   print("STAGE12_TIMER: ",JSON.stringify({"fault":fault,"before":str(before),"after":str(lift.position),"button":str(button.position),"button_scale_y":button.source_scale.y,"button_pc":button.vm.pc,"parameters":lift.vm.parameters,"inventory":world.source_pickup_counts}))
   if fault.is_empty() and "--verify-stage12-timer-ride" in OS.get_cmdline_user_args():
    reached=await walk_to(world,Vector3(7.5,0,9.5),right_delta)
    fault=reached.get("fault","");release_controls()
    if fault.is_empty():
     reached=await jump_to_actor(world,lift,right_delta)
     fault=reached.get("fault","");release_controls()
    var rode := false
    var upper: Dictionary=world.source_map_position(lift.source_waypoints[1].position)
    var upper_y: float=int(upper.position.y)*world.CELL_METERS/4096.0
    if fault.is_empty():
     for tick in range(600):
      world.sample_source_player_controls();world.tick_source_actors()
      if tick%30==0:print("STAGE12_TIMER_RIDE_TRACE: ",JSON.stringify({"tick":tick,"platform":str(lift.position),"player":str(world.source_player_actor.position),"clip":world.source_player_actor.clip_name}))
      if lift.position.y>upper_y-0.4 and int(world.source_player_actor.source_ground.get("actor",-1))==lift.source_pool_id and (int(world.source_player_actor.secondary_flags)&2)!=0:rode=true;break
     if not rode:fault="Timed platform did not carry player to upper height"
    print("STAGE12_TIMER_RIDE: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"platform":str(lift.position),"player":str(world.source_player_actor.position)}))
    if fault.is_empty() and "--verify-stage12-upper-colors" in OS.get_cmdline_user_args():
     reached=await jump_to_actor(world,Vector3(7.5,3.6,14.2),right_delta)
     fault=reached.get("fault","");release_controls()
     var boxes: Array=world.source_actors.filter(func(a):return a.source_name=="SmashBlock")
     boxes.sort_custom(func(a,b):return a.position.x<b.position.x)
     for crate in boxes:
      if not fault.is_empty():break
      reached=await jump_to_actor(world,crate,right_delta)
      fault=reached.get("fault","");release_controls()
      for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
      if fault.is_empty() and "--verify-stage12-cage-boxes" in OS.get_cmdline_user_args():fault=await stomp_reward_box(world,crate)
     if fault.is_empty():
      for index in [7,8]:
       if (int(world.source_map_entity_flags.get("MP012_02.MAP",{}).get(index,0))&5)==0:fault="Upper color remains at index "+str(index);break
     print("STAGE12_UPPER_COLORS: ",JSON.stringify({"fault":fault,"colors":world.source_bonus_mask,"inventory":world.source_pickup_counts,"position":str(world.source_player_actor.position)}))
     if "--verify-stage12-cage-boxes" in OS.get_cmdline_user_args():print("STAGE12_CAGE_BOXES: ",JSON.stringify({"fault":fault,"flags":world.source_map_entity_flags.get("MP012_02.MAP",{}),"inventory":world.source_pickup_counts}))
     if fault.is_empty() and "--verify-stage12-fifth-gobbo" in OS.get_cmdline_user_args():
      for waypoint in [Vector3(7.5,3.6,17.4),Vector3(9,3.6,18),Vector3(9,3.6,20.7),Vector3(7.5,3.6,20.7)]:
       reached=await walk_to(world,waypoint,right_delta)
       fault=reached.get("fault","");release_controls()
       if not fault.is_empty():break
      for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
      if fault.is_empty() and (int(world.source_map_entity_flags.get("MP012_02.MAP",{}).get(10,0))&5)==0:fault="Cage key was not collected"
      if fault.is_empty():
       for waypoint in [Vector3(9,3.6,20.7),Vector3(9,3.6,18),Vector3(7.5,3.6,14.2)]:
        reached=await walk_to(world,waypoint,right_delta)
        fault=reached.get("fault","");release_controls()
        if not fault.is_empty():break
      if fault.is_empty():
       reached=await jump_to_actor(world,lift,right_delta)
       fault=reached.get("fault","");release_controls()
      if fault.is_empty():
       reached=await jump_to_actor(world,Vector3(8.4,0,8),right_delta)
       fault=reached.get("fault","");release_controls()
       for tick in range(180):world.sample_source_player_controls();world.tick_source_actors()
       if fault.is_empty() and world.source_pickup_counts[2]!=5:fault="Cage did not yield fifth Gobbo"
      print("STAGE12_FIFTH_GOBBO: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"key_state":world.source_level_script_state,"position":str(world.source_player_actor.position)}))
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Timed-platform approach lost a life"
 if fault.is_empty() and "--verify-stage12-bonus-door" in OS.get_cmdline_user_args():
  if world.source_bonus_mask!=31 or world.source_pickup_counts[2]!=5:fault="Bonus entry requires earned five colors/five Gobbos"
  var lift: Node3D=null
  var button: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="PlatformTimer":lift=actor
   if actor.source_name=="PlatformSwch":button=actor
  if lift==null or button==null:fault="Missing return timed lift"
  if fault.is_empty():print("STAGE12_RETURN_TIMER_STATE: ",JSON.stringify({"phase":"before_button","lift":str(lift.position),"lift_pc":lift.vm.pc,"globals":lift.vm.globals,"button_pc":button.vm.pc,"scale":button.source_scale.y}))
  if fault.is_empty():
   var reached: Dictionary=await walk_to(world,button.position,right_delta,false,button)
   fault=reached.get("fault","");release_controls()
   for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
   print("STAGE12_RETURN_TIMER_STATE: ",JSON.stringify({"phase":"after_button","lift":str(lift.position),"lift_pc":lift.vm.pc,"globals":lift.vm.globals,"button_pc":button.vm.pc,"scale":button.source_scale.y}))
   if fault.is_empty():
    reached=await walk_to(world,Vector3(7.5,0,9.5),right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    reached=await jump_to_actor(world,lift,right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    for tick in range(600):
     world.sample_source_player_controls();world.tick_source_actors()
     if lift.position.y>2.84 and int(world.source_player_actor.source_ground.get("actor",-1))==lift.source_pool_id and (int(world.source_player_actor.secondary_flags)&2)!=0:break
    reached=await jump_to_actor(world,Vector3(7.5,3.6,14.2),right_delta)
    fault=reached.get("fault","");release_controls()
   if fault.is_empty():
    for waypoint in [Vector3(7.5,3.6,16.5),Vector3(3,3.6,18)]:
     reached=await walk_to(world,waypoint,right_delta)
     fault=reached.get("fault","");release_controls()
     if not fault.is_empty():break
   if fault.is_empty():
    reached=await walk_to(world,Vector3(-1.5,3.6,18),right_delta,false,null,1.8,"MP012_03.MAP")
    fault=reached.get("fault","");release_controls()
  if world.source_pickup_counts[3]!=stage12_starting_lives:fault="Bonus-door approach lost a life"
  print("STAGE12_BONUS_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask}))
 if fault.is_empty() and "--inspect-popping-game" in OS.get_cmdline_user_args():
  for tick in range(120):world.sample_source_player_controls();world.tick_source_actors()
  print("STAGE12_POPPING_ACTORS: ",JSON.stringify(world.source_actors.map(func(a):return {"name":a.source_name,"position":str(a.position),"pc":a.vm.pc,"parameters":a.vm.parameters,"globals":a.vm.globals})))
 if fault.is_empty() and "--verify-popping-start" in OS.get_cmdline_user_args():
  for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
  var starter: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="WackStartSwitch":starter=actor;break
  if starter==null:fault="Missing popping-game start switch"
  else:
   var reached: Dictionary=await walk_to(world,starter.position,right_delta,false,starter)
   fault=reached.get("fault","");release_controls()
   for tick in range(180):
    world.sample_source_player_controls();world.tick_source_actors()
    if "--verify-popping-win" in OS.get_cmdline_user_args() and world.source_actors.any(func(a):return a.source_name=="WackSwitch1"):break
   if fault.is_empty() and not world.source_actors.any(func(a):return a.source_name=="WackSwitch1"):fault="Popping game did not create scoring switches"
  print("STAGE12_POPPING_START: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"actors":world.source_actors.filter(func(a):return a.source_name.begins_with("Wack")).map(func(a):return {"name":a.source_name,"position":str(a.position),"pc":a.vm.pc,"parameters":a.vm.parameters})}))
 if fault.is_empty() and "--verify-popping-score" in OS.get_cmdline_user_args():
  var middle: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="WackSwitch2":middle=actor;break
  if middle==null:fault="Missing middle scoring switch"
  else:
   var reached: Dictionary=await walk_to(world,middle.position,right_delta,false,middle)
   fault=reached.get("fault","");release_controls()
   var before: int=world.source_extended_globals.get(42,0)
   if fault.is_empty():
    for tick in range(1200):
     release_controls()
     if tick%60<8:Input.action_press("jump")
     world.sample_source_player_controls();world.tick_source_actors()
     if tick%60==0:print("POPPING_SCORE_TRACE: ",JSON.stringify({"tick":tick,"score":world.source_extended_globals.get(42,0),"channel":world.source_extended_globals.get(32,0),"player":str(world.source_player_actor.position)}))
     if int(world.source_extended_globals.get(42,0))>before:break
    release_controls()
    if int(world.source_extended_globals.get(42,0))<=before:fault="Middle-switch jumping did not score a capture"
   print("STAGE12_POPPING_SCORE: ",JSON.stringify({"fault":fault,"before":before,"after":world.source_extended_globals.get(42,0),"inventory":world.source_pickup_counts}))
 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 if fault.is_empty() and "--verify-popping-win" in OS.get_cmdline_user_args():
  for tick in range(2):world.sample_source_player_controls();world.tick_source_actors()
  var middle: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="WackSwitch2":middle=actor;break
  var reached: Dictionary={"fault":"Missing win-route middle switch"}
  if middle!=null:reached=await jump_to_actor(world,middle,right_delta)
  fault=reached.get("fault","");release_controls()
  var jump_age := -100
  var reaction_turn_delta: int=right_delta
  if fault.is_empty() and not "--popping-ground" in OS.get_cmdline_user_args():
   var yaw_before: int=world.source_player_actor.source_angles.y
   for tick in range(12):
    release_controls();Input.action_press("move_right")
    world.sample_source_player_controls();world.tick_source_actors()
   release_controls()
   reaction_turn_delta=wrapi(int(world.source_player_actor.source_angles.y)-yaw_before,-2048,2048)
   if reaction_turn_delta==0:fault="Popping reaction turn calibration remained zero"
   print("POPPING_TURN_CALIBRATION: ",reaction_turn_delta)
   for tick in range(120):
    release_controls();Input.action_release("precision_move")
    var difference := wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048)
    if abs(difference)<80:break
    Input.action_press("move_right" if difference*reaction_turn_delta>0 else "move_left")
    world.sample_source_player_controls();world.tick_source_actors()
  if fault.is_empty():
   for tick in range(8000):
    release_controls();Input.action_release("precision_move")
    var sheep: Array=world.source_actors.filter(func(a):return a.source_name=="WackJumpy" and a.model_name=="SHEP.MOD")
    sheep.sort_custom(func(a,b):return a.get_instance_id()>b.get_instance_id())
    var target_x := 9.0
    if not sheep.is_empty():target_x=8.25 if sheep[0].position.x<7 else 9.75 if sheep[0].position.x>11 else 9.0
    var dx: float=target_x-world.source_player_actor.position.x
    var pressed := false
    if "--popping-edge" in OS.get_cmdline_user_args():
     var switch_name := "WackSwitch3" if target_x<8.5 else "WackSwitch1" if target_x>9.5 else "WackSwitch2"
     for actor in world.source_actors:
      if actor.source_name==switch_name and actor.source_scale.y<4096:pressed=true;break
    var grounded: bool=(int(world.source_player_actor.secondary_flags)&2)!=0
    var turn := wrapi(-int(world.source_player_actor.source_angles.y),-2048,2048)
    if not "--popping-ground" in OS.get_cmdline_user_args() and grounded and abs(dx)>0.12 and tick-jump_age>30:jump_age=tick
    if tick-jump_age<8:Input.action_press("jump")
    if abs(dx)>0.12 and not pressed:
     Input.action_press("precision_move")
     Input.action_press("move_left" if dx>0 else "move_right")
    world.sample_source_player_controls();world.tick_source_actors()
    if tick%60==0:print("POPPING_REACTION_TRACE: ",JSON.stringify({"tick":tick,"score":world.source_extended_globals.get(42,0),"target_x":target_x,"player":str(world.source_player_actor.position),"yaw":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name,"held":world.source_input_held_mask}))
    if int(world.source_extended_globals.get(40,0))!=0:break
   release_controls();Input.action_release("precision_move")
   var score: int=int(world.source_extended_globals.get(42,0))>>16
   if score<25:fault="Popping-game score below original Gobbo threshold: "+str(score)
   if fault.is_empty():
    var prize: Node3D=null
    for actor in world.source_actors:
     if actor.source_name=="WackJumpyGame":prize=actor;break
    if prize==null:fault="Winning popping prize is missing"
    else:
     reached=await walk_to(world,prize.position,right_delta)
     fault=reached.get("fault","");release_controls()
     for tick in range(180):world.sample_source_player_controls();world.tick_source_actors()
     if fault.is_empty() and world.source_pickup_counts[2]!=6:fault="Popping prize did not yield sixth Gobbo"
   print("STAGE12_POPPING_WIN: ",JSON.stringify({"fault":fault,"score":score,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask}))
 var expected_final_gobbos: int=6 if "--verify-popping-win" in OS.get_cmdline_user_args() else 5
 if fault.is_empty() and "--verify-five-colors" in OS.get_cmdline_user_args() and (world.source_bonus_mask!=31 or world.source_pickup_counts[2]!=expected_final_gobbos):fault="Continuous route did not retain earned colors/Gobbos"
 if fault.is_empty() and "--audit-stage12-pickups" in OS.get_cmdline_user_args():print("STAGE_ENTITY_FLAGS: ",JSON.stringify(world.source_map_entity_flags))
 if fault.is_empty() and "--verify-stage12-gong" in OS.get_cmdline_user_args():
  var gong: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="FinalExit":gong=actor;break
  if gong==null:fault="Missing stage12 bonus-room gong"
  else:
   var gong_position: Vector3=gong.position
   for point in [Vector3(10.5,3.6,7.3),Vector3(10.5,3.6,11.1),gong_position-Vector3(0,0,1.2)]:
    var reached: Dictionary=await walk_to(world,point,right_delta)
    fault=reached.get("fault","");release_controls()
    if not fault.is_empty():break
   if fault.is_empty():
    for tick in range(1200):
     release_controls()
     if world.source_main_mode==4 and world.source_transition_state==0:
      var delta: Vector3=gong_position-world.source_player_actor.position
      var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
      var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
      if abs(difference)>60:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
      if abs(difference)<160 and Vector2(delta.x,delta.z).length()>1.0:Input.action_press("move_forward")
     if tick%40<4:Input.action_press("attack")
     if "--stage12-gong-jump" in OS.get_cmdline_user_args() and world.source_main_mode==4 and world.source_transition_state==0 and tick%80<16:Input.action_press("jump")
     if world.source_transition_state==3 and tick%40<4:Input.action_press("jump")
     world.sample_source_player_controls();world.tick_source_actors()
     if not world.process_source_exit():fault=world.source_transition_fault;break
     if world.source_main_mode==5 and world.source_fade_phase=="":break
     if tick%60==0:
      print("STAGE12_GONG_TRACE: ",JSON.stringify({"tick":tick,"mode":world.source_main_mode,"transition":world.source_transition_state,"player":str(world.source_player_actor.position),"yaw":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name,"actors":world.source_actors.filter(func(a):return a.source_name.begins_with("FinalExit")).map(func(a):return {"name":a.source_name,"pc":a.vm.pc,"position":str(a.position),"globals":a.vm.globals,"parameters":a.vm.parameters})}))
      await process_frame
    release_controls()
    if world.source_main_mode!=5 or world.map_name!="MP100_01.MAP":fault="Stage12 gong did not return to selector"
   print("STAGE12_GONG_RESULT: ",JSON.stringify({"fault":fault,"room":world.map_name,"progress":world.source_menu_progress_flags,"selection":world.source_menu_state.selected_index,"scope":"Direct-entry exit diagnostic; campaign attribution requires earned entry"}))
   if fault.is_empty() and "--from-earned-stage10" in OS.get_cmdline_user_args():
    for index in range(3):
     if int(world.source_menu_progress_flags.get(index,0))!=0x8006:fault="Earned campaign completion missing at index "+str(index);break
    if fault.is_empty() and "--verify-stage12-save" in OS.get_cmdline_user_args():fault=await verify_earned_campaign_roundtrip(world,"MP013_00.MAP")
 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 print("STAGE12_FINAL_CHECK: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"colors":world.source_bonus_mask,"room":world.map_name}))
 return fault

func collect_stage12_stair_rewards(world: Node,right_delta: int) -> String:
 var boxes: Array=world.source_actors.filter(func(a):return a.source_name in ["SmashBlock","SmashBlockFloat"])
 boxes.sort_custom(func(a,b):return a.position.z<b.position.z)
 if boxes.size()!=4:return "Stair reward route requires four intact boxes"
 var fault := ""
 for top_index in range(3,-1,-1):
  for point in [Vector3(8.1,0,3.6),Vector3(6,0,3.5)]:
   var reached: Dictionary=await walk_to(world,point,right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if not fault.is_empty():break
  for index in range(top_index+1):
   var reached: Dictionary=await jump_to_actor(world,boxes[index],right_delta)
   fault=reached.get("fault","");release_controls()
   if not fault.is_empty():break
  if fault.is_empty():fault=await stomp_reward_box(world,boxes[top_index])
  if not fault.is_empty():break
 print("STAGE12_STAIR_REWARDS: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags.get("MP012_05.MAP",{})}))
 return fault

func jump_to_actor(world: Node,target: Variant,right_delta: int,jump_ticks: int=60,settle_ticks: int=20,forward_ticks: int=25,arrival: Callable=Callable(),event_during_jump: Callable=Callable(),aim_override: Variant=null) -> Dictionary:
 var lives_before: int=world.source_pickup_counts[3]
 release_controls()
 for tick in range(settle_ticks):world.sample_source_player_controls();world.tick_source_actors()
 for tick in range(120):
  release_controls()
  var target_position: Vector3=aim_override if aim_override is Vector3 else (target if target is Vector3 else target.position)
  var delta: Vector3=target_position-world.source_player_actor.position
  var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
  var difference := wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048)
  if abs(difference)<80:break
  Input.action_press("move_right" if difference*right_delta>0 else "move_left")
  world.sample_source_player_controls();world.tick_source_actors()
 for tick in range(jump_ticks):
  if "--trace-stage12-jumps" in OS.get_cmdline_user_args() and tick%5==0:
   print("STAGE12_JUMP_TRACE: ",JSON.stringify({"tick":tick,"target":str(target) if target is Vector3 else target.source_name,"target_position":str(target) if target is Vector3 else str(target.position),"target_pc":-1 if target is Vector3 else target.vm.pc,"player":str(world.source_player_actor.position),"yaw":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name,"lives":world.source_pickup_counts[3],"ground":world.source_player_actor.source_ground}))
  if "--trace-well-jumps" in OS.get_cmdline_user_args() and world.map_name=="MP012_05.MAP" and tick%5==0:
   print("WELL_JUMP_TRACE: ",JSON.stringify({"tick":tick,"target":str(target) if target is Vector3 else target.source_name,"position":str(world.source_player_actor.position),"angle":world.source_player_actor.source_angles.y,"clip":world.source_player_actor.clip_name,"lives":world.source_pickup_counts[3],"worms":world.source_actors.filter(func(a):return a.source_name=="BigWorm").map(func(a):return {"pc":a.vm.pc,"position":str(a.position)})}))
  release_controls()
  if tick<16:Input.action_press("jump")
  if "--attack-rats" in OS.get_cmdline_user_args() and (int(world.source_map_entity_flags.get("MP012_01.MAP",{}).get(9,0))&5)!=0 and tick%12<3:
   for actor in world.source_actors:
    if actor.source_name=="BigRat" and actor.position.distance_to(world.source_player_actor.position)<2.2:Input.action_press("attack");break
  var target_position: Vector3=target if target is Vector3 else target.position
  var delta: Vector3=target_position-world.source_player_actor.position
  if tick<forward_ticks and Vector2(delta.x,delta.z).length()>0.4:Input.action_press("move_forward")
  world.sample_source_player_controls();world.tick_source_actors()
  if event_during_jump.is_valid() and event_during_jump.call():
   release_controls()
   return {"reached":true,"event":true} if world.source_pickup_counts[3]>=lives_before else {"fault":"Sampled jump lost a life"}
 release_controls()
 if world.source_pickup_counts[3]<lives_before:return {"fault":"Sampled jump lost a life"}
 if arrival.is_valid() and arrival.call():return {"reached":true}
 var destination: Vector3=target if target is Vector3 else target.position
 var target_actor: Node3D=target if target is Node3D else null
 return await walk_to(world,destination,right_delta,true,target_actor,3.0)
