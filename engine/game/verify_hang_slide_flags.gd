extends SceneTree
func _initialize() -> void:
	var actor = preload("res://asl_actor.gd").new()
	actor.primary_flags = 0x01234567
	actor.secondary_flags = 0x0820
	for step in [[163,0x1820],[171,0x1821],[164,0x0821],[172,0x0820],[172,0x0820],[164,0x0820]]:
		assert(actor.asl_command({"op":step[0],"args":[]},actor.vm) == "continue")
		assert(actor.secondary_flags == step[1])
		assert(actor.primary_flags == 0x01234567)
	actor.free()
	print("PASS: authored hang/slide commands independently toggle source secondary masks without altering other flags")
	quit(0)
