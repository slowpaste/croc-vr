extends SceneTree
const Actor = preload("res://asl_actor.gd")
class BlinkWorld extends Node3D:
	const CELL_METERS := 3.0
	var runtime_tables := {"blink":{"yScaleUnits":[4096,2048,1024,2048]}}
func _initialize() -> void:
	var world = BlinkWorld.new()
	var actor = Actor.new()
	world.add_child(actor)
	actor.world = world
	actor.model_data = {"models":[{},{}]}
	for i in range(2):
		var part := MeshInstance3D.new()
		actor.add_child(part)
		actor.mesh_parts.append(part)
	actor.clip = {"vertexCount":0,"boneCount":2,"bones":[[[4096,0,0,0,4096,0,0,0,4096,0,0,0],[4096,0,0,0,4097,0,0,0,4096,123,456,789]]]}
	if actor.asl_command({"op":60,"args":[1,1]},actor.vm) != "continue" or (actor.primary_flags & 0x100) == 0 or actor.source_blink_counter != 0:
		world.free()
		quit(1)
		return
	for scale in [0.5,0.25,0.5,4097.0/4096.0]:
		actor.advance_source_blink()
		actor.apply_pose()
		if not is_equal_approx(actor.mesh_parts[1].basis.y.y,scale) or actor.mesh_parts[0].basis.y.y != 1.0 or actor.mesh_parts[1].position != Vector3(123,456,789)*3.0/4096.0:
			world.free()
			quit(1)
			return
	if (actor.primary_flags & 0x100) != 0 or actor.source_blink_counter != 0:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":112,"args":[1,1]},actor.vm)
	actor.advance_source_blink()
	actor.apply_pose()
	if actor.source_blink_counter != 2 or (actor.primary_flags & 0x100) != 0 or actor.mesh_parts[1].basis.y.y != 0.25:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":111,"args":[]},actor.vm)
	actor.apply_pose()
	if actor.source_blink_counter != 0 or not is_equal_approx(actor.mesh_parts[1].basis.y.y,4097.0/4096.0):
		world.free()
		quit(1)
		return
	actor.primary_flags |= 0x100
	actor.asl_command({"op":112,"args":[1,1]},actor.vm)
	actor.advance_source_blink()
	if actor.source_blink_counter != 3:
		world.free()
		quit(1)
		return
	actor.secondary_flags = 0x2080
	actor.vm.host = actor
	if actor.vm.evaluate([{"op":3,"index":78},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	actor.secondary_flags |= 0x800
	if actor.vm.evaluate([{"op":3,"index":78},{"op":18}]) != 0x800:
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: source blink phases, selected model indices, integer scale rounding, unchanged translation and raw AVar78 mask")
	quit(0)
