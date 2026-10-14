extends SceneTree
const Actor = preload("res://asl_actor.gd")
func _initialize() -> void:
	var actor = Actor.new()
	actor.primary_flags = -2147483644
	actor.secondary_flags = 123
	if actor.asl_command({"op":130,"args":[]},actor.vm) != "continue" or actor.primary_flags != -2130706428 or actor.secondary_flags != 123:
		quit(1)
		return
	if actor.asl_command({"op":131,"args":[]},actor.vm) != "continue" or actor.primary_flags != -2147483644 or actor.secondary_flags != 123:
		quit(1)
		return
	actor.free()
	print("PASS: source PushableOn/Off primary bit24 and unrelated flag preservation")
	quit(0)
