extends SceneTree
func _initialize() -> void:call_deferred("verify")
func verify() -> void:
 var world=load("res://imported.tscn").instantiate();root.add_child(world);await process_frame;world.set_process(false);world.set_physics_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-compose-shake.json"))
 for index in range(0,fixture.observations.size(),7):
  var actor:Dictionary=fixture.observations[index];var cache:Dictionary=fixture.observations[index+1];var look:Dictionary=fixture.observations[index+2];var b:Dictionary=fixture.observations[index+3];var a:Dictionary=fixture.observations[index+5];var out:Dictionary=fixture.observations[index+6]
  var points:Array=[]
  for p in range(6):points.append({"lower":{"tile":int(cache.get("lt%d"%p)),"record":int(cache.get("lr%d"%p))},"upper":{"tile":-1,"record":0}})
  var state={"position":Vector3i(int(b.x),int(b.y),int(b.z)),"yaw":int(b.yaw),"yaw_velocity":int(b.yaw_velocity),"distance_velocity":int(b.distance_velocity),"height_velocity":int(b.height_velocity),"query_counter":int(b.query_counter),"orbit_offset":int(b.orbit),"primary_flags":int(b.primary),"secondary_flags":int(actor.secondary),"last_ground_y":int(actor.last_ground_y),"lower_tile_actor":int(actor.lower_tile),"upper_height_actor":int(actor.upper_height),"height_copy":int(actor.height_copy),"collision_status":int(actor.collision_status),"point_caches":points,"center_cache":{"lower":{"tile":int(cache.clt),"record":int(cache.clr)},"upper":{"tile":int(cache.cut),"record":int(cache.cur)}},"manual_yaw":int(look.manual_yaw),"look_offset_y":int(look.offset_y),"look_offset":Vector2i(int(look.current_x),int(look.current_z)),"look_offset_velocity":Vector2i(int(look.velocity_x),int(look.velocity_z)),"look_position":Vector3i(0,int(look.look_y),0),"look_velocity_y":int(look.look_velocity_y),"shake_index":int(look.shake_index),"shake_strength":int(look.shake_strength)}
  var result:Dictionary=preload("res://source_camera_update_pipeline.gd").step(world,state,Vector3i(int(b.target_x),int(b.target_y),int(b.target_z)),int(b.target_yaw),int(b.distance_copy),int(b.height),int(b.padkind),JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-shake-waveform.json")).values)
  if result.has("fault"):push_error(str(result.fault));quit(1);return
  var n:Dictionary=result.camera_state
  assert(n.position==Vector3i(int(a.x),int(a.y),int(a.z)) and n.look_position==Vector3i(int(out.look_x),int(out.look_y),int(out.look_z)))
  assert(n.distance_velocity==int(a.distance_velocity) and n.height_velocity==int(a.height_velocity) and n.look_velocity_y==int(out.look_velocity_y))
  assert(n.shake_index==int(out.shake_index))
  assert(n.yaw==int(a.yaw) and n.yaw_velocity==int(a.yaw_velocity))
  assert(n.query_counter==int(a.query_counter) and n.orbit_offset==int(a.orbit))
  assert(n.look_offset_velocity==Vector2i(int(out.velocity_x),int(out.velocity_z)))
  assert(n.look_offset==Vector2i(int(out.offset_x),int(out.offset_z)) and n.collision_status==int(out.collision_status))
 world.queue_free();await process_frame;print("PASS: all eight original combined movement/look/shake outputs match");quit(0)

