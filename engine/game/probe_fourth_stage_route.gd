extends "res://probe_third_stage_route.gd"

func probe() -> void:
 if "--from-earned-stage10" in OS.get_cmdline_user_args():
  await super.probe();return
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 var fault: String=await run_stage13(world)
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
  if world.map_name=="MP013_00.MAP" and world.source_fade_phase=="":break
 if world.map_name!="MP013_00.MAP" or world.source_menu_state.selected_index!=3:return "Earned selector did not enter first boss level"
 print("STAGE13_EARNED_ENTRY: ",JSON.stringify({"progress":world.source_menu_progress_flags,"inventory":world.source_pickup_counts}))
 return await run_stage13(world)

func run_stage13(world: Node) -> String:
 world.set_process(false);world.set_physics_process(false);world.vr_controls.layout="classic"
 for tick in range(60):world.sample_source_player_controls();world.tick_source_actors()
 var lives: int=world.source_pickup_counts[3]
 var prior: int=world.source_player_actor.source_angles.y
 for tick in range(12):
  Input.action_press("move_right");world.sample_source_player_controls();world.tick_source_actors()
 release_controls()
 var right_delta := wrapi(int(world.source_player_actor.source_angles.y)-prior,-2048,2048)
 var fault := "" if right_delta!=0 else "Stage13 turn calibration failed"
 var platform: Node3D=null
 for actor in world.source_actors:
  if actor.source_name=="GuidedPlatform":platform=actor;break
 if platform==null:fault="First boss guided platform missing"
 if fault.is_empty():
  print("STAGE13_GUIDED_START: ",JSON.stringify({"player":str(world.source_player_actor.position),"platform":str(platform.position),"pc":platform.vm.pc}))
  var reached: Dictionary=await walk_to(world,Vector3(7.5,0,3.9),right_delta)
  fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   reached=await jump_to_actor(world,platform,right_delta)
   fault=reached.get("fault","");release_controls()
  if fault.is_empty():
   for tick in range(900):
    release_controls();Input.action_press("move_forward")
    if "--guided-center" in OS.get_cmdline_user_args():
     var desired := clampi(roundi((7.5-platform.position.x)*512),-192,192)
     var difference := wrapi(desired-int(platform.source_angles.y),-2048,2048)
     if abs(difference)>32:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
    world.sample_source_player_controls();world.tick_source_actors()
    if tick%30==0:
     print("STAGE13_GUIDED_RIDE: ",JSON.stringify({"tick":tick,"player":str(world.source_player_actor.position),"platform":str(platform.position),"yaw":platform.source_angles.y,"pc":platform.vm.pc,"ground":world.source_player_actor.source_ground,"inventory":world.source_pickup_counts}))
     await process_frame
    if world.source_pickup_counts[3]<lives:fault="Guided ride lost a life";break
    if platform.position.z>17.5:break
   release_controls()
   if fault.is_empty() and platform.position.z<17.5:fault="Forward input did not traverse guided platform"
   if fault.is_empty() and "--guided-center" in OS.get_cmdline_user_args():
    for index in range(4,11):
     if (int(world.source_map_entity_flags.get("MP013_00.MAP",{}).get(index,0))&5)==0:fault="Guided central crystal not collected at "+str(index);break
   if fault.is_empty() and "--verify-stage13-right-box" in OS.get_cmdline_user_args():
    fault=await guide_to_point(world,platform,Vector2(9.3,10.5),right_delta)
    var crate: Node3D=null
    for actor in world.source_actors:
     if actor.source_name=="SmashBlock" and actor.position.x>10:crate=actor;break
    if crate==null:fault="Right guided-room box missing"
    if fault.is_empty():
     reached=await jump_to_actor(world,crate,right_delta)
     fault=reached.get("fault","");release_controls()
    if fault.is_empty():fault=await stomp_reward_box(world,crate)
    print("STAGE13_RIGHT_BOX: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
   if fault.is_empty() and "--verify-stage13-left-box" in OS.get_cmdline_user_args():
    reached=await jump_to_actor(world,platform,right_delta)
    fault=reached.get("fault","");release_controls()
    if fault.is_empty():fault=await guide_to_point(world,platform,Vector2(5.7,13.5),right_delta)
    var crate: Node3D=null
    for actor in world.source_actors:
     if actor.source_name=="SmashBlock" and actor.position.x<4:crate=actor;break
    if crate==null:fault="Left guided-room box missing"
    if fault.is_empty():
     reached=await jump_to_actor(world,crate,right_delta)
     fault=reached.get("fault","");release_controls()
    if fault.is_empty():fault=await stomp_reward_box(world,crate)
    if fault.is_empty() and (int(world.source_map_entity_flags.get("MP013_00.MAP",{}).get(11,0))&5)==0:fault="Left side crystal remains uncollected"
    print("STAGE13_LEFT_BOX: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
   if fault.is_empty() and "--verify-stage13-heart" in OS.get_cmdline_user_args():
    var before_lives: int=world.source_pickup_counts[3]
    reached=await jump_to_actor(world,platform,right_delta)
    fault=reached.get("fault","");release_controls()
    if fault.is_empty():fault=await guide_to_point(world,platform,Vector2(9.3,16.5),right_delta)
    var crumble: Node3D=null
    for actor in world.source_actors:
     if actor.source_name=="PlatformCrumble":crumble=actor;break
    if crumble==null:fault="Guided-room crumble platform missing"
    if fault.is_empty():
     reached=await jump_to_actor(world,crumble,right_delta,30)
     fault=reached.get("fault","");release_controls()
    if fault.is_empty() and world.source_pickup_counts[3]!=before_lives+1:fault="Crumble heart did not yield extra life"
    print("STAGE13_CRUMBLE_HEART: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags,"player":str(world.source_player_actor.position)}))
    if fault.is_empty() and "--verify-stage13-heart-return" in OS.get_cmdline_user_args():
     if "--quick-turn-escape" in OS.get_cmdline_user_args():
      var event := InputEventKey.new()
      event.keycode=KEY_F;event.physical_keycode=KEY_F;event.pressed=true
      Input.parse_input_event(event)
      for tick in range(3):world.sample_source_player_controls();world.tick_source_actors()
      event=InputEventKey.new();event.keycode=KEY_F;event.physical_keycode=KEY_F;event.pressed=false
      Input.parse_input_event(event)
      for tick in range(45):
       release_controls();world.sample_source_player_controls();world.tick_source_actors()
       var delta: Vector3=platform.position-world.source_player_actor.position
       var desired := roundi(atan2(delta.x,delta.z)*4096.0/TAU)&4095
       if abs(wrapi(desired-int(world.source_player_actor.source_angles.y),-2048,2048))<80 and not world.source_player_actor.clip_name.begins_with("CROC180"):break
      reached=await jump_to_actor(world,platform,right_delta,60,0)
      fault=reached.get("fault","");release_controls()
     var remounted := false
     for tick in range(120):
      if "--quick-turn-escape" in OS.get_cmdline_user_args():
       remounted=int(world.source_player_actor.source_ground.get("actor",-1))==platform.source_pool_id and (int(world.source_player_actor.secondary_flags)&2)!=0
       break
      release_controls()
      if tick<16:Input.action_press("jump")
      if tick<40:Input.action_press("move_back")
      world.sample_source_player_controls();world.tick_source_actors()
      if tick>10 and int(world.source_player_actor.source_ground.get("actor",-1))==platform.source_pool_id and (int(world.source_player_actor.secondary_flags)&2)!=0:remounted=true;break
      if world.source_pickup_counts[3]!=before_lives+1:fault="Crumble escape lost a life";break
     release_controls()
     if world.source_pickup_counts[3]!=before_lives+1:fault="Crumble escape did not retain gained life"
     if fault.is_empty() and not remounted:fault="Backward jump did not remount guide"
     print("STAGE13_CRUMBLE_ESCAPE: ",JSON.stringify({"fault":fault,"player":str(world.source_player_actor.position),"inventory":world.source_pickup_counts,"ground":world.source_player_actor.source_ground}))
   if fault.is_empty() and "--verify-stage13-next-room" in OS.get_cmdline_user_args():
    if "--verify-stage13-heart-return" in OS.get_cmdline_user_args():fault=await guide_to_point(world,platform,Vector2(7.5,18.2),right_delta)
    for tick in range(40):
     release_controls();Input.action_press("move_forward")
     world.sample_source_player_controls();world.tick_source_actors()
    release_controls()
    reached=await jump_to_actor(world,Vector3(6,0,20.4),right_delta)
    fault=reached.get("fault","");release_controls()
    if fault.is_empty():
     reached=await walk_to(world,Vector3(6,0,24),right_delta,false,null,1.8,"MP013_01.MAP")
     fault=reached.get("fault","");release_controls()
    print("STAGE13_NEXT_ROOM: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--verify-stage13-second-boxes" in OS.get_cmdline_user_args():
  if "--inspect-stage13-corridor" in OS.get_cmdline_user_args():
   for z in range(12,34):
    print("STAGE13_CORRIDOR_FLOOR: ",JSON.stringify({"z":z,"floor":world.source_raw_floor_query(Vector3(6,0,z))}))
  var boxes: Array=world.source_actors.filter(func(a):return a.source_name=="SmashBlock")
  boxes.sort_custom(func(a,b):return a.position.z<b.position.z)
  if boxes.size()!=4:fault="Second approach room requires four boxes"
  for crate in boxes:
   if not fault.is_empty():break
   if crate.position.z>30 and world.source_player_actor.position.z<14:
    var step_index := 0
    for point in [Vector3(6,0,14),Vector3(6,0,16.6),Vector3(6,0,23),Vector3(6,0,25.6),Vector3(6,0,31.8)]:
     var crossing: Dictionary=await jump_to_point(world,point,right_delta) if step_index in [1,3] else await walk_to(world,point,right_delta)
     step_index+=1
     fault=crossing.get("fault","");release_controls()
     if not fault.is_empty():break
    if not fault.is_empty():break
   var reached: Dictionary=await jump_to_actor(world,crate,right_delta)
   fault=reached.get("fault","");release_controls()
   if fault.is_empty():fault=await stomp_reward_box(world,crate)
  print("STAGE13_SECOND_BOXES: ",JSON.stringify({"fault":fault,"inventory":world.source_pickup_counts,"flags":world.source_map_entity_flags}))
 if fault.is_empty() and "--verify-stage13-arena" in OS.get_cmdline_user_args():
  var reached: Dictionary=await walk_to(world,Vector3(6,0,39),right_delta,true,null,1.8,"MP013_02.MAP")
  fault=reached.get("fault","");release_controls()
  print("STAGE13_ARENA_ENTRY: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts}))
 if fault.is_empty() and "--inspect-stage13-boss" in OS.get_cmdline_user_args():
  var boss: Node3D=null
  for actor in world.source_actors:
   if actor.source_name=="Weeble":boss=actor;break
  if boss==null:fault="Weeble missing after normal arena entry"
  else:
   for tick in range(600):
    release_controls();world.sample_source_player_controls();world.tick_source_actors()
    if not world.process_source_exit():fault=world.source_transition_fault;break
    if tick%30==0:
     print("STAGE13_BOSS_IDLE: ",JSON.stringify({"tick":tick,"pc":boss.vm.pc,"boss":str(boss.position),"player":str(world.source_player_actor.position),"health":boss.vm.globals.get(8,0),"vulnerable":boss.vm.globals.get(5,0),"protection":boss.vm.parameters[4],"mode":world.source_main_mode,"lives":world.source_pickup_counts[3]}))
     await process_frame
    if world.source_pickup_counts[3]<lives:fault="Idle boss diagnostic lost a life";break
 if fault.is_empty() and "--fight-weeble" in OS.get_cmdline_user_args():
  var combat_result: Variant=await fight_weeble_sampled(world,right_delta)
  fault=str(combat_result) if typeof(combat_result)==TYPE_STRING else "Combat probe aborted without a result"
 if world.source_pickup_counts[3]<lives:fault="Stage13 approach lost a life"
 for actor in world.source_actors:
  if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault
 print("STAGE13_APPROACH_CHECK: ",JSON.stringify({"fault":fault,"room":world.map_name,"inventory":world.source_pickup_counts,"scope":"guided-platform sampled mount/ride only; arena, full collectibles and boss completion unverified"}))
 return fault

func guide_to_point(world: Node,platform: Node3D,target: Vector2,right_delta: int) -> String:
 var lives: int=world.source_pickup_counts[3]
 for tick in range(1400):
  release_controls()
  var delta := target-Vector2(platform.position.x,platform.position.z)
  if delta.length()<0.35:return ""
  var desired := roundi(atan2(delta.x,delta.y)*4096.0/TAU)&4095
  var difference := wrapi(desired-int(platform.source_angles.y),-2048,2048)
  Input.action_press("move_forward")
  if abs(difference)>32:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
  world.sample_source_player_controls();world.tick_source_actors()
  if world.source_pickup_counts[3]<lives:return "Guided steering lost a life"
  if tick%60==0:
   print("STAGE13_GUIDED_TARGET: ",JSON.stringify({"tick":tick,"target":str(target),"platform":str(platform.position),"yaw":platform.source_angles.y,"player":str(world.source_player_actor.position)}))
   await process_frame
 release_controls()
 return "Guided steering did not reach target"

func fight_weeble_sampled(world: Node,right_delta: int) -> String:
 var modern := "--modern-boss-movement" in OS.get_cmdline_user_args()
 if modern:
  world.vr_controls.layout="modern"
  world.vr_controls.reset_gestures()
 var boss: Node3D=null
 for actor in world.source_actors:
  if actor.source_name=="Weeble":boss=actor;break
 if boss==null:return "Natural Weeble fight has no boss"
 var lives: int=world.source_pickup_counts[3]
 var last_attack := -100
 var last_evade_jump := -100
 var health_seen: Array=[]
 var previous_health: int=boss.vm.globals.get(8,0)
 var retreat_until := -1
 var retreat_yaw := 0
 var orbit_radius := 6.0
 var radius_option := OS.get_cmdline_user_args().find("--boss-orbit-radius")
 if radius_option>=0 and radius_option+1<OS.get_cmdline_user_args().size():orbit_radius=float(OS.get_cmdline_user_args()[radius_option+1])
 var fault := ""
 var won := false
 for tick in range(4800):
  release_controls()
  var player: Node3D=world.source_player_actor
  var delta: Vector3=boss.position-player.position
  var distance := Vector2(delta.x,delta.z).length()
  var vulnerable := int(boss.vm.globals.get(5,0))!=0 and int(boss.vm.parameters[4])==0
  var direction := Vector2(delta.x,delta.z)
  var moving := vulnerable and distance>1.3
  var orbit := "--orbit-weeble" in OS.get_cmdline_user_args()
  if tick<retreat_until:
   direction=Vector2(sin(float(retreat_yaw)*TAU/4096.0),cos(float(retreat_yaw)*TAU/4096.0))
   moving=true
  elif not vulnerable and orbit:
   var angle := atan2(player.position.x-15,player.position.z-24)-0.6
   var destination := Vector2(15+sin(angle)*orbit_radius,24+cos(angle)*orbit_radius)
   direction=destination-Vector2(player.position.x,player.position.z)
   moving=true
  elif not vulnerable and distance<4.5:
   var away := Vector2(-delta.x,-delta.z).normalized()
   var destination := Vector2(clampf(player.position.x+away.x*4,6,24),clampf(player.position.z+away.y*4,12,33))
   direction=destination-Vector2(player.position.x,player.position.z)
   moving=direction.length()>0.3
  var desired := roundi(atan2(direction.x,direction.y)*4096.0/TAU)&4095
  var difference := wrapi(desired-int(player.source_angles.y),-2048,2048)
  if abs(difference)>60:Input.action_press("move_right" if difference*right_delta>0 else "move_left")
  if moving and abs(difference)<160:Input.action_press("move_forward")
  if not vulnerable and moving and orbit:
   if abs(difference)<900:Input.action_press("move_forward")
   if "--weeble-orbit-evade" in OS.get_cmdline_user_args():
    if distance<3.0 and (int(player.secondary_flags)&2)!=0 and tick-last_evade_jump>45:last_evade_jump=tick
    if tick-last_evade_jump<8:Input.action_press("jump")
  elif not vulnerable and moving:
   if abs(difference)>1024:Input.action_press("move_back")
   elif abs(difference)<768:Input.action_press("move_forward")
   if distance<3.5 and (int(player.secondary_flags)&2)!=0 and tick-last_evade_jump>45:last_evade_jump=tick
   if tick-last_evade_jump<8:Input.action_press("jump")
  if modern:
   release_controls()
   if moving and direction.length()>0.01:
    var movement := Vector3(direction.x,0,direction.y).normalized()
    var view: Camera3D=world.head if world.xr_active else world.camera
    var forward: Vector3=-view.global_basis.z
    forward=Vector3(forward.x,0,forward.z).normalized()
    var right := Vector3(-forward.z,0,forward.x)
    var side := movement.dot(right)
    var ahead := movement.dot(forward)
    if abs(side)>0.01:Input.action_press("move_right" if side>0 else "move_left",abs(side))
    if abs(ahead)>0.01:Input.action_press("move_forward" if ahead>0 else "move_back",abs(ahead))
  if vulnerable and distance<1.8 and tick-last_attack>45:last_attack=tick
  if tick-last_attack<3:Input.action_press("attack")
  world.sample_source_player_controls();world.tick_source_actors()
  var health: int=boss.vm.globals.get(8,0)
  if health<previous_health and health>0 and "--post-hit-run" in OS.get_cmdline_user_args():
   retreat_until=tick+60
   retreat_yaw=int(player.source_angles.y)
  previous_health=health
  if not health_seen.has(health):health_seen.append(health)
  if tick%30==0:
   print("STAGE13_SAMPLED_FIGHT: ",JSON.stringify({"tick":tick,"player":str(player.position),"boss":str(boss.position),"vulnerable":vulnerable,"health":health,"health_seen":health_seen,"clip":player.clip_name,"lives":world.source_pickup_counts[3]}))
   await process_frame
  if world.source_pickup_counts[3]<lives:fault="Natural fight lost a life";break
  for actor in world.source_actors:
   if not actor.vm.fault.is_empty():fault=actor.source_name+": "+actor.vm.fault;break
  if not fault.is_empty():break
  if health==0 and world.source_transition_state==3:won=true;break
 release_controls()
 if fault.is_empty() and not won:fault="Natural sampled fight did not reach victory"
 print("STAGE13_FIGHT_RESULT: ",JSON.stringify({"fault":fault,"won":won,"health_seen":health_seen,"inventory":world.source_pickup_counts,"scope":"normal approach and sampled movement/tail attacks; no pose or health writes"}))
 if fault.is_empty() and won and "--verify-stage13-return" in OS.get_cmdline_user_args():
  var last_scene := -1
  var last_frame := -1
  for tick in range(1800):
   release_controls()
   if is_instance_valid(world.source_cutscene_screen):
    var display: Node3D=world.source_cutscene_screen
    last_scene=int(world.source_cutscene_progress.scene)
    if not world.process_source_sad_cutscene(1.0/30.0):fault=world.source_transition_fault;break
    last_frame=int(display.session.player.last_index)
    await process_frame
   else:
    if tick%60<4:Input.action_press("jump")
    world.sample_source_player_controls();world.tick_source_actors()
    if not world.process_source_exit():fault=world.source_transition_fault;break
    if world.source_main_mode==5 and world.source_fade_phase=="":break
    if tick%30==0:await process_frame
  release_controls()
  if fault.is_empty() and (last_scene!=17 or last_frame!=390 or world.source_main_mode!=5 or world.map_name!="MP100_01.MAP"):fault="Natural boss cinematic/selector return incomplete"
  print("STAGE13_BOSS_RETURN: ",JSON.stringify({"fault":fault,"scene":last_scene,"frame":last_frame,"room":world.map_name,"selection":world.source_menu_state.selected_index,"progress":world.source_menu_progress_flags,"scope":"Direct-entry cinematic/return; earned boss credit separately required"}))
  if fault.is_empty() and "--from-earned-stage10" in OS.get_cmdline_user_args():
   for index in range(3):
    if int(world.source_menu_progress_flags.get(index,0))!=0x8006:fault="Prior earned rescues lost at index "+str(index);break
   if fault.is_empty() and (int(world.source_menu_progress_flags.get(3,0))!=0x8000 or world.source_menu_state.selected_index!=4):fault="Earned boss did not unlock/select first secret stage"
   if fault.is_empty() and "--verify-stage13-save" in OS.get_cmdline_user_args():fault=await verify_earned_campaign_roundtrip(world,"MP018_00.MAP")
 return fault
