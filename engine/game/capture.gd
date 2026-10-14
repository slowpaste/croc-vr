extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var room = load("res://imported.tscn").instantiate()
	root.add_child(room)
	for i in range(30):
		await process_frame
	if "--close" in OS.get_cmdline_user_args():
		room.set_physics_process(false)
		room.camera.position = room.actor.position + Vector3(0,0.7,-1.2)
		room.camera.look_at(room.actor.position + Vector3(0,0.3,0))
	await RenderingServer.frame_post_draw
	var status := root.get_texture().get_image().save_png("res://../build/testbed-preview.png")
	quit(status)
