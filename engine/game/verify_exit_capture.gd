extends SceneTree
func _initialize() -> void:
	var world := preload("res://imported_main.gd").new()
	var rider := preload("res://asl_actor.gd").new()
	rider.world = world
	rider.source_ground = {"surface_type":128}
	rider.secondary_flags = 2
	world.map_name = "MP010_00.MAP"
	world.runtime_tables = {"mapYScale":{"values":[2048]}}
	world.manifest = {"maps":[{"name":"MP010_00.MAP","style":0}]}
	world.source_camera_state = {}
	var door := {"position":[0,0,0],"level":20,"room":0,"flags":16,"id":4}
	world.room_data = {"style":0,"doors":[door]}
	var request := world.source_exit_request(rider)
	if request.has("fault") or not request.transition or request.state != 3 or request.capture_origin or request.has("origin"):
		push_error("Source bit16 exit incorrectly required/captured camera arrival context")
		quit(1)
		return
	door.flags = 18
	world.manifest.maps[0].style = 1
	world.source_ground_mode_80_value = 0
	request = world.source_exit_request(rider)
	if request.has("fault") or request.transition or request.counter != 1 or request.has("origin"): quit(1); return
	door.flags = 0
	world.manifest.maps[0].style = 0
	request = world.source_exit_request(rider)
	if not request.has("fault"): push_error("Capturing source exit accepted missing camera context"); quit(1); return
	rider.world = null
	rider.free()
	world.free()
	print("PASS: bit16/delayed source exits bypass arrival capture; normal capturing exit retains camera gate")
	quit(0)
