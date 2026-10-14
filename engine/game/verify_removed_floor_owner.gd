extends SceneTree
func _initialize() -> void:
	var world = preload("res://imported_main.gd").new()
	world.source_pool.reset(4)
	var owner = preload("res://asl_actor.gd").new();world.add_child(owner)
	var rider = preload("res://asl_actor.gd").new();world.add_child(rider)
	owner.source_pool_id = world.source_pool.allocate({"node":owner})
	owner.primary_flags = 1;owner.secondary_flags = 0x20;owner.source_angles.y = 123
	var words := []
	words.resize(22);words.fill(0);words[18] = 100;words[19] = -200
	owner.model_data = {"models":[{"collision":{"groups":[[{"halfwords":words}]]}}]}
	rider.secondary_flags = 2
	rider.source_ground = {"mode":2,"actor":owner.source_pool_id,"record":0,"surface_type":0}
	world.source_actors.assign([owner,rider])
	assert(world.source_player_gradient(rider) == {"x":100,"z":-200,"yaw":123})
	assert(world.remove_source_actor(owner))
	var removed_gradient: Dictionary = world.source_player_gradient(rider)
	if removed_gradient != {"x":0,"z":0,"yaw":0}:
		push_error("Freed native slot must be inactive for cached gradient: "+JSON.stringify(removed_gradient))
		world.free();quit(1);return
	rider.source_ground.actor = 99
	assert(world.source_player_gradient(rider).has("fault"))
	rider.source_ground.erase("actor")
	assert(world.source_player_gradient(rider).has("fault"))
	world.free()
	print("PASS: cached removed floor owner is inactive; invalid or absent owner identity still fails")
	quit(0)
