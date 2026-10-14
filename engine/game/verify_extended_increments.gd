extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var world = World.new()
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	world.source_extended_globals[23] = 2147418112
	for opcode in [68,176]:
		actor.vm.configure({"instructions":[{"pc":0,"op":opcode,"args":[28,23],"next":4},{"pc":4,"op":16,"args":[[{"op":4,"value":65536},{"op":18}]],"next":10}]},0,actor,[])
		actor.vm.globals[23] = 123
		var expected := -2147483648 if opcode == 68 else 2147418112
		if actor.vm.run() != "yielded" or world.source_extended_globals[23] != expected or actor.vm.globals[23] != 123 or actor.vm.evaluate([{"op":28,"index":23},{"op":18}]) != expected:
			push_error("Source extended-global increment/decrement wrapping or ownership failed")
			quit(1)
			return
	actor.vm.configure({"instructions":[{"pc":0,"op":68,"args":[28,256],"next":4}]},0,actor,[])
	if actor.vm.run() != "unsupported" or world.source_extended_globals.has(256):
		quit(1)
		return
	world.free()
	print("PASS: source shared extended-global increment/decrement, signed wrap and invalid-bank rejection")
	quit(0)
