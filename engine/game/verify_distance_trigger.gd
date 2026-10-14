extends SceneTree
func _initialize() -> void:
	var world := preload("res://imported_main.gd").new()
	var player := Node3D.new()
	world.source_player_actor = player
	var actor := preload("res://asl_actor.gd").new()
	actor.world = world
	root.add_child(actor)
	var program := {"instructions":[{"pc":8,"op":49,"args":[6,[{"op":4,"value":65536},{"op":18}],30],"next":18},{"pc":18,"op":66,"args":[],"next":19},{"pc":30,"op":68,"args":[29,0],"next":34},{"pc":34,"op":52,"args":[],"next":35}]}
	actor.vm.configure(program,8,actor,[0])
	actor.vm.run()
	actor.source_player_distance_valid = true
	actor.source_player_distance = 4096
	actor.run_source_scripts()
	if actor.event_triggers[0].threshold != 65536 or actor.vm.parameters[0] != 0: quit(1); return
	actor.source_player_distance = 4095
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 65536: push_error("Strict native near-distance trigger boundary differs"); quit(1); return
	world.source_player_actor = null
	actor.source_player_distance = 0
	actor.run_source_scripts()
	if actor.vm.parameters[0] != 65536: push_error("Distance trigger fired without registered player"); quit(1); return
	actor.world = null
	actor.free()
	player.free()
	world.free()
	print("PASS: trigger6 full fixed-point threshold, strict distance boundary and missing-player gate")
	quit(0)
