extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var world = World.new()
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	actor.vm.host = actor
	actor.source_map_entity_index = 3
	world.map_name = "MP018_05.MAP"
	world.source_map_entity_flags = {"MP018_05.MAP":{3:7}}
	if actor.vm.evaluate([{"op":3,"index":48},{"op":18}]) != 2 or actor.asl_command({"op":168,"args":[]},actor.vm) != "continue" or world.source_input_suppression_count != 1 or actor.vm.evaluate([{"op":3,"index":12},{"op":18}]) != 0 or actor.asl_command({"op":169,"args":[]},actor.vm) != "continue" or world.source_input_suppression_count != 0:
		quit(1)
		return
	actor.asl_command({"op":180,"args":[[{"op":4,"value":458752},{"op":18}]]},actor.vm)
	if actor.vm.evaluate([{"op":4,"value":7},{"op":46},{"op":18}]) != 1 or world.source_stage_pickup_slots[7] != 1:
		quit(1)
		return
	actor.asl_command({"op":180,"args":[[{"op":4,"value":-65536},{"op":18}]]},actor.vm)
	if world.source_stage_pickup_slots != [0,0,0,0,0,0,0,1]:
		quit(1)
		return
	world.source_pickup_counts[1] = 0
	if actor.asl_command({"op":179,"args":[]},actor.vm) != "continue" or world.source_pickup_counts[1] != -1:
		quit(1)
		return
	world.source_pickup_counts[1] = 75
	world.source_stage_crystal_bank = 40
	var stats := preload("res://source_stage_stats.gd").initialize(int(world.source_menu_state.selected_index),int(world.source_pickup_counts[1]),int(world.source_pickup_counts[2]),world.source_stage_crystal_bank,int(world.source_pickup_counts[3]),world.source_stage_pickup_slots)
	if stats.pickup_count != 1 or stats.bank != 15 or stats.lives != 4:
		push_error("Source pickup-slot table did not feed stats initialization")
		quit(1)
		return
	world.free()
	print("PASS: source persistent pickup set/read, invalid writer no-op, crystal decrement and stats table integration")
	quit(0)
