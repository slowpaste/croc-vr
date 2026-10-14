extends SceneTree
const Actor = preload("res://asl_actor.gd")
const List = preload("res://source_actor_list.gd")

func _initialize() -> void:
	var actors: Array = []
	for y in [1,-1,1,2]:
		var actor = Actor.new()
		root.add_child(actor)
		actor.position.y = y * 3.0
		actor.source_spawn_y_units = y * 4096
		actors.push_front(actor)
	var result := List.order(actors,3.0)
	if not result.ok or result.actors != [actors[2],actors[1],actors[3],actors[0]]:
		quit(1)
		return
	actors[0].primary_flags |= 0x800
	result = List.order(actors,3.0)
	if not result.ok or result.actors != [actors[0],actors[2],actors[1],actors[3]]:
		quit(1)
		return
	actors[2].primary_flags |= 0x800
	if List.order(actors,3.0).ok:
		quit(1)
		return
	# Script movement after creation must not change map-load insertion/sort state.
	actors[2].position.y = 300.0
	result = List.order(actors,3.0,true)
	if not result.ok or result.actors != [actors[2],actors[1],actors[3],actors[0]]:
		quit(1)
		return
	print("PASS: source prepend order, stable equal heights, signed height sorting and priority-node guard")
	quit(0)
