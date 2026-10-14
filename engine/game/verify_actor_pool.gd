extends SceneTree
const Pool = preload("res://source_actor_pool.gd")

func _initialize() -> void:
	var pool = Pool.new()
	pool.reset(128)
	if pool.allocate({"name":"Croc"}) != 127 or pool.allocate({"name":"FirstMapActor"}) != 126:
		quit(1)
		return
	for i in range(126):
		if pool.allocate({"name":"Reserved"}) != 125 - i:
			quit(1)
			return
	if pool.allocate({}) != -1 or pool.slots.size() != 128:
		quit(1)
		return
	if not pool.release(42) or not pool.release(90) or pool.release(90) or pool.allocate({}) != 90 or pool.allocate({}) != 42:
		quit(1)
		return
	pool.reset(128)
	if pool.allocate({}) != 127:
		quit(1)
		return
	print("PASS: source descending actor allocation, capacity exhaustion and room reset")
	quit(0)
