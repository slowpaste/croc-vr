extends SceneTree
func _initialize() -> void:call_deferred("probe")
func probe() -> void:
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false)
 if world.map_name!="MP014_00.MAP":push_error("Expected stage14 original entrance");quit(1);return
 for z in [17,18,19,20,21,22,23,24,25]:
  var samples: Array=[]
  for x in [0,1.5,3,4.5,6,7.5,9,10.5,12,13.5,15,16.5,18]:
   for height in [0,3.6,6.0]:
    var hit: Dictionary=world.source_raw_floor_query(Vector3(x,height,z))
    samples.append({"x":x,"query_y":height,"surface":hit.get("surface_type",-1),"height_units":hit.get("height_units",null)})
  print("STAGE14_GROUND: ",JSON.stringify({"z":z,"samples":samples}))
 print("STAGE14_GROUND_SCOPE: Original geometry only, no route or collectible proof")
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit(0)
