extends SceneTree
const Chain = preload("res://source_waypoint_chain.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var actor = Actor.new()
	actor.source_waypoints = [{"id":0},{"id":1},{"id":2}]
	actor.ensure_source_waypoint_chain()
	var child: Dictionary = actor.source_waypoint_chain.duplicate(false)
	if actor.asl_command({"op":141,"args":[]},actor.vm) != "continue" or actor.source_waypoint_index != 1 or actor.source_waypoint_chain.head != 1 or child.head != 0 or child.nodes[1].previous != -1 or actor.source_waypoints.size() != 3:
		push_error("Deleting source head changed saved child root or lost the removed record")
		quit(1)
		return
	if actor.asl_command({"op":173,"args":[]},actor.vm) != "continue" or actor.source_waypoint_index != 1:
		quit(1)
		return
	var middle := Chain.initialize(3)
	var result := Chain.delete_current(middle,1)
	if result.current != 2 or middle.nodes[0].next != 2 or middle.nodes[2].previous != 0 or middle.nodes[1].next != 2:
		quit(1)
		return
	var tail := Chain.initialize(3)
	result = Chain.delete_current(tail,2)
	if result.current != 0 or tail.tail != 2 or tail.nodes[1].next != -1:
		quit(1)
		return
	if not Chain.delete_current(Chain.initialize(1),0).has("fault"):
		quit(1)
		return
	actor.free()
	print("PASS: source waypoint unlink, stable records/shared links, head/current updates and final-point guard")
	quit(0)
