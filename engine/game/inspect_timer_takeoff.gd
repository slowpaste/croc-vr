extends SceneTree
func _initialize():call_deferred("inspect")
func inspect():
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame
 world.set_process(false);world.set_physics_process(false)
 for point in [Vector3(6.75,0.75,9),Vector3(6.75,0.75,9.4),Vector3(7.1,0.75,9.4),Vector3(7.5,0.75,9.5)]:
  print("TIMER_TAKEOFF_FLOOR: ",JSON.stringify({"point":str(point),"floor":world.source_raw_floor_query(point)}))
 world.stop_imported_audio();world.queue_free();await process_frame
 await preload("res://source_spu_stream_retirement.gd").drain(self)
 quit()
