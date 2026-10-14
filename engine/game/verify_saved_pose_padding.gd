extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://imported.tscn").instantiate()
	root.add_child(world);await process_frame
	world.set_process(false);world.set_physics_process(false)
	var player = world.source_player_actor
	var pose_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../reference/original-camera-direct-height.json"))
	for observation in pose_fixture.observations:
		if observation.kind != "CAMERA_TARGET_POSE": continue
		var words: Array = observation.words
		player.source_angles = Vector3i(int(words[0])&65535,(int(words[0])>>16)&65535,int(words[1])&65535)
		player.source_pose_padding = [(int(words[1])>>16)&65535,int(words[5])]
		var vm = preload("res://asl_vm.gd")
		player.position = Vector3(vm.signed32(int(words[2])),vm.signed32(int(words[3])),vm.signed32(int(words[4])))*world.CELL_METERS/4096.0
		var packed: Array = player.source_camera_pose_words()
		for word_index in range(6):
			if int(packed[word_index])!=int(words[word_index]):
				push_error("Actor camera pose differs from original six-word capture: "+str(packed)+" expected="+str(words));quit(1);return
	player.source_pose_padding = [null,null]
	var opaque: Array = player.source_camera_pose_words()
	if opaque[1].known_mask!=65535 or opaque[5]!=null: quit(1);return
	for padding in [[null,null],[0,0],[0xface,0x89abcdef]]:
		player.source_pose_padding = padding.duplicate()
		var old_position: Vector3 = player.position
		var old_angles: Vector3i = player.source_angles
		if player.asl_command({"op":86,"args":[]},player.vm)!="continue": quit(1);return
		player.position += Vector3(1,2,3)
		player.source_angles = Vector3i(100,200,300)
		player.source_pose_padding = [123,456]
		if player.asl_command({"op":29,"args":[]},player.vm)!="continue": quit(1);return
		if player.source_pose_padding!=padding or player.position.distance_to(old_position)>0.0001 or player.source_angles!=old_angles:
			push_error("Source saved pose lost padding or transform");quit(1);return
	var child = world.spawn_source_actor(player,"Gobbo",[])
	if child == null: push_error("Missing reusable actor fixture");quit(1);return
	var reused_slot: int = child.source_pool_id
	child.source_pose_padding = [0x1234,0x89abcdef]
	child.source_saved_pose_padding = [0xabcd,0x76543210]
	if not world.remove_source_actor(child): quit(1);return
	var replacement = world.spawn_source_actor(player,"Gobbo",[])
	if replacement == null or replacement.source_pool_id!=reused_slot or replacement.source_pose_padding!=[0x1234,0x89abcdef] or replacement.source_saved_pose_padding!=[0xabcd,0x76543210]:
		push_error("Actor allocation lost independent current/saved pose padding");quit(1);return
	world.queue_free();await process_frame
	print("PASS: native six-word Save/Restore semantics retain unknown and known pose padding")
	quit(0)
