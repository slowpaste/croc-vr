extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var room=load("res://imported.tscn").instantiate();root.add_child(room)
 for i in range(30):await process_frame
 room.set_process(false);room.set_physics_process(false)
 room.camera.global_position=Vector3(7,6,15)
 room.camera.look_at(Vector3(14,2,10))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../build/stage11-climb-wall.png")
 quit()
