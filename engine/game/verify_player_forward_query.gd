extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false)
 var player=world.source_player_actor
 var owner=world.source_actors.filter(func(a):return a!=player)[0]
 var fault := ""
 var cases=0
 for origin in [Vector3(9,0,6),Vector3(-3,0,-6)]:
  owner.position=origin
  for data in [[0,Vector3(0,0,3),4096],[2048,Vector3(0,0,3),-4096],[1024,Vector3(3,0,0),4096],[3072,Vector3(3,0,0),-4096],[0,Vector3(3,0,0),0],[1024,Vector3(0,0,3),0]]:
   owner.source_angles.y=data[0];player.position=origin+data[1]
   var machine=preload("res://asl_vm.gd").new()
   var stack: Array=[]
   owner.asl_expression({"op":3,"index":61},stack,machine)
   if not machine.fault.is_empty() or stack!=[data[2]]:fault="Forward coordinate differs "+str(data)+" -> "+str(stack)
   cases+=1
 print("PLAYER_FORWARD_QUERY: ",JSON.stringify({"fault":fault,"cases":cases}))
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0 if fault.is_empty() else 1)
