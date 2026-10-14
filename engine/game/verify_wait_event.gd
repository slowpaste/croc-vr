extends SceneTree
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	for mode in range(4):
		var actor = Actor.new()
		actor.primary_flags = 9 if mode == 0 else 1
		actor.vm.configure({"instructions":[{"pc":8,"op":104,"name":"WaitEvent","args":[mode],"next":10},{"pc":10,"op":66,"name":"Hold","args":[],"next":11}]},8,actor)
		if actor.vm.run() != "yielded" or actor.vm.pc != 8 or (actor.primary_flags & 2) == 0:
			actor.free()
			quit(1)
			return
		match mode:
			0: actor.primary_flags &= ~8
			1: actor.primary_flags |= 0x400000
			2: actor.primary_flags |= 0x20000000
			3: actor.secondary_flags |= 0x200
		if actor.vm.run() != "yielded" or actor.vm.pc != 10:
			actor.free()
			quit(1)
			return
		actor.free()
	print("PASS: all source WaitEvent conditions hold their pointer then resume on matching flags")
	quit(0)
