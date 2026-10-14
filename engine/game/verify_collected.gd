extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var world = World.new()
	world.room_data = {"entities":[{}]}
	world.map_name = "MP015_00.MAP"
	world.source_map_entity_flags = {"MP015_00.MAP":{0:2}}
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	actor.source_map_entity_index = 0
	actor.primary_flags = 123
	actor.secondary_flags = 456
	if actor.asl_command({"op":175,"args":[]},actor.vm) != "continue" or world.source_map_entity_flags[world.map_name][0] != 6 or actor.primary_flags != 123 or actor.secondary_flags != 456 or actor.get_parent() != world:
		push_error("Collected changed actor state instead of only the map-entity flag")
		quit(1)
		return
	actor.source_map_entity_index = -1
	if actor.asl_command({"op":175,"args":[]},actor.vm) != "continue" or world.source_map_entity_flags[world.map_name][0] != 6:
		quit(1)
		return
	world.free()
	print("PASS: source Collected map mask4, existing flags, null entity no-op and actor retention")
	quit(0)
