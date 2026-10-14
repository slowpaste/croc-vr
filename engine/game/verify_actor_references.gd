extends SceneTree
func _initialize() -> void:
	var queue := preload("res://source_actor_references.gd").new()
	var owner = preload("res://asl_actor.gd").new()
	owner.vm.program = {"references":[{"kind":0,"name":"Target"},{"kind":0,"name":"Missing"}]}
	owner.source_reference_slots[1] = 77
	var newer = preload("res://asl_actor.gd").new();newer.source_name = "Target";newer.source_pool_id = 3
	var older = preload("res://asl_actor.gd").new();older.source_name = "Target";older.source_pool_id = 9
	queue.register(owner);assert(queue.pending.size() == 2)
	queue.refresh([newer,older])
	assert(owner.source_reference_slots == {0:9,1:77} and queue.pending.is_empty())
	queue.refresh([newer]);assert(owner.source_reference_slots[0] == 9)
	owner.vm.program.references = []
	for index in range(40): owner.vm.program.references.append({"kind":0,"name":"Target"})
	queue.register(owner);assert(queue.pending.size() == 32)
	queue.reset();assert(queue.pending.is_empty())
	owner.free();newer.free();older.free()
	print("PASS: pending actor references use last exact-name match, preserve unmatched/resolved slots, consume once and retain native32-record bound")
	quit(0)
