extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
class SchedulerWorld extends World:
	var contact_log: Array = []
	func run_source_player_contacts() -> bool:
		contact_log.append("contacts")
		return true

class Probe extends Node3D:
	var log: Array
	var tag: String
	var secondary_flags := 0
	var primary_flags := 1
	var on_script: Callable
	func begin_source_tick() -> void:
		log.append("begin:" + tag)
	func run_source_scripts(_vertical_context: Dictionary = {}) -> void:
		log.append("script:" + tag)
		if on_script.is_valid(): on_script.call()
	func refresh_source_render_pose() -> bool:
		log.append("render:" + tag)
		return true

func _initialize() -> void:
	var world = SchedulerWorld.new()
	var log: Array = []
	world.contact_log = log
	var probes: Array[Node3D] = []
	for tag in ["a","b","c"]:
		var probe := Probe.new()
		probe.tag = tag
		probe.log = log
		probe.secondary_flags = 0 if tag == "a" else 0x10
		world.add_child(probe)
		probes.append(probe)
	world.source_actors.assign(probes)
	world.tick_source_actors()
	if log != ["contacts","begin:a","begin:b","begin:c","script:b","script:c","script:a","render:b","render:c","render:a"]:
		world.free()
		quit(1)
		return
	var actor = Actor.new()
	world.source_camera_hold_counter = 5
	probes[0].on_script = func():
		assert(world.source_camera_hold_counter == 5)
		world.source_camera_hold_counter = 3
	world.tick_source_actors()
	assert(world.source_camera_hold_counter == 2)
	probes[0].on_script = Callable()
	world.add_child(actor)
	actor.world = world
	actor.position = Vector3(3,6,9)
	actor.source_rotation_y = 1024
	actor.vm.configure({"instructions":[{"pc":8,"op":41,"name":"MoveUp","args":[[{"op":4,"value":4096},{"op":18}]],"next":16},{"pc":16,"op":30,"name":"Goto","args":[8],"next":19}]},8,actor)
	actor.vm.status = "yielded"
	world.source_actors.assign([actor])
	world.tick_source_actors()
	if actor.previous_source_position != Vector3i(4096,8192,12288) or actor.source_render_position != Vector3i(4096,8448,12288) or actor.previous_source_yaw != 1024 or not is_equal_approx(actor.position.y,6.1875):
		world.free()
		quit(1)
		return
	actor.vm.configure({"instructions":[{"pc":0,"op":67,"name":"Hold","args":[],"next":1}]},0,actor)
	actor.primary_flags = 0x401
	actor.position.y = 3.0
	actor.source_ground = {"height_units":0}
	actor.source_vertical_speed = 100
	world.room_data = {"style":0}
	world.tick_source_actors()
	if actor.previous_source_position.y != 4096 or actor.source_render_position.y != 3996 or actor.source_vertical_speed != 133:
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: actor snapshot/script order and live vertical motion before scripts")
	quit(0)
