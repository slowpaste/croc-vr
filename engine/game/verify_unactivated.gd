extends SceneTree
func _initialize() -> void:
	var world = preload("res://imported_main.gd").new()
	world.map_name = "MP024_05.MAP"
	world.room_data = {"entities":[{},{}]}
	var actor = preload("res://asl_actor.gd").new()
	actor.world = world
	actor.source_map_entity_index = 1
	world.source_map_entity_flags = {world.map_name:{0:7,1:7},"other":{1:7}}
	assert(actor.asl_command({"op":206,"args":[]},actor.vm) == "continue")
	assert(world.source_map_entity_flags[world.map_name][1] == 5)
	assert(world.source_map_entity_flags[world.map_name][0] == 7)
	assert(world.source_map_entity_flags.other[1] == 7)
	assert(actor.asl_command({"op":162,"args":[]},actor.vm) == "continue")
	assert(world.source_map_entity_flags[world.map_name][1] == 7)
	actor.source_map_entity_index = -1
	assert(actor.asl_command({"op":206,"args":[]},actor.vm) == "continue")
	assert(world.source_map_entity_flags[world.map_name][1] == 7)
	actor.source_map_entity_index = 2
	assert(actor.asl_command({"op":206,"args":[]},actor.vm) == "unsupported")
	actor.free();world.free()
	print("PASS: UnActivated clears only the authored activation bit, preserves other entities and accepts a null entity")
	quit(0)
