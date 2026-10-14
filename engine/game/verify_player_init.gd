extends SceneTree
const World = preload("res://imported_main.gd")
const Actor = preload("res://asl_actor.gd")
class ArrivalActor extends Actor:
	var collision_calls := 0
	var height_before_collision := 0
	func run_source_collision_response(_buffers: Dictionary = {}) -> bool:
		collision_calls += 1
		height_before_collision = int(source_ground.height_units)
		source_ground.height_units = 700
		return true
func _initialize() -> void:
	var world = World.new()
	if world.source_extended_globals.size() != 256 or world.source_extended_globals[31] != 0 or world.source_extended_globals[255] != 0 or world.source_extended_globals.has(256):
		world.free()
		quit(1)
		return
	var actor = ArrivalActor.new()
	world.add_child(actor)
	actor.world = world
	actor.vm.host = actor
	if actor.asl_command({"op":94,"args":[57,[{"op":4,"value":-2147483648},{"op":18}]]},actor.vm) != "continue":
		world.free()
		quit(1)
		return
	var observer = Actor.new()
	world.add_child(observer)
	observer.world = world
	observer.vm.host = observer
	if observer.vm.evaluate([{"op":28,"index":57},{"op":18}]) != -2147483648 or not observer.vm.globals.is_empty():
		world.free()
		quit(1)
		return
	world.room_data = {"flags":0}
	actor.vm.program = {"references":[{"kind":8,"name":"optional-sound","condition":[{"op":4,"value":8},{"op":35},{"op":18}]}]}
	if actor.asl_asset({"kind":80,"name":"optional-sound"},actor.vm) != 0 or actor.vm.status == "unsupported":
		world.free()
		quit(1)
		return
	world.room_data.flags = 8
	actor.asl_asset({"kind":80,"name":"optional-sound"},actor.vm)
	if actor.vm.status != "unsupported":
		world.free()
		quit(1)
		return
	actor.vm.status = "ready"
	actor.vm.fault = ""
	world.room_data.waitAnimation = 0
	if actor.asl_asset({"kind":142},actor.vm) != 0 or actor.asl_asset({"kind":81},actor.vm) != 0:
		world.free()
		quit(1)
		return
	world.room_data.waitAnimation = 3
	actor.bindings = [{"kind":4,"name":"CROCWA3.ANI","file":"idle-animation"},{"kind":3,"name":"CROCWA3","file":"idle-sound"}]
	if actor.asl_asset({"kind":142},actor.vm) != 1 or actor.asl_asset({"kind":81},actor.vm) != 131072 or actor.asl_asset({"kind":142},actor.vm) != 1:
		world.free()
		quit(1)
		return
	actor.primary_flags = 1
	if actor.vm.evaluate([{"op":4,"value":123},{"op":4,"value":8},{"op":35},{"op":18}]) != 123:
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x08000001
	if actor.vm.evaluate([{"op":4,"value":123},{"op":4,"value":8},{"op":35},{"op":18}]) != 8:
		world.free()
		quit(1)
		return
	actor.source_pool_id = 127
	world.map_name = "MP010_02.MAP"
	world.source_player_entry_state = {"present":false}
	var exit_context: Dictionary = world.source_exit_context(7,123)
	if exit_context != {"id":7,"level":10,"room":2,"yaw":123,"previous_entry":{"present":false}}:
		world.free()
		quit(1)
		return
	world.runtime_tables = {"mapYScale":{"values":[512]}}
	var data := {"style":0,"startRotation":0.25,"doors":[{"position":[3,0,4],"flags":12}],"tracks":[]}
	var entry: Dictionary = world.initial_source_player_entry(data)
	if entry.position != Vector3i(12288,3584,16384) or entry.yaw != 1024 or entry.flags != 12:
		world.free()
		quit(1)
		return
	data.tracks = [{"position":[3,1,4]}]
	if world.initial_source_player_entry(data).position != Vector3i(12288,512,16384):
		world.free()
		quit(1)
		return
	data.doors = [{"position":[3,0,4],"flags":0,"id":7,"level":10,"room":2},{"position":[9,0,9],"flags":1,"id":7,"level":10,"room":3}]
	data.tracks[0].rotation = 0.5
	var incoming := {"id":7,"level":10,"room":2,"yaw":77,"previous_entry":{"present":false}}
	entry = world.initial_source_player_entry(data,incoming)
	if not entry.present or entry.position != Vector3i(12288,512,16384) or entry.yaw != 2048:
		world.free()
		quit(1)
		return
	data.doors[0].flags = 4
	if world.initial_source_player_entry(data,incoming).yaw != 1024:
		world.free()
		quit(1)
		return
	incoming.previous_entry = entry
	incoming.room = 99
	var retained: Dictionary = world.initial_source_player_entry(data,incoming)
	if retained.position != entry.position or retained.restore_yaw or retained.yaw != entry.yaw:
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x41
	actor.secondary_flags = 0x82
	actor.position = Vector3(1,2,3)
	world.source_player_entry_state = {"present":false}
	if not actor.initialize_source_player() or actor.collision_calls != 0 or actor.position != Vector3(1,2,3) or actor.primary_flags != 0x02000841 or actor.secondary_flags != 0x80 or actor.source_ground.height_units != 0 or world.source_player_actor != actor or world.source_player_id != 127:
		world.free()
		quit(1)
		return
	world.source_player_entry_state = {"present":true,"position":Vector3i(100,200,300),"restore_yaw":true,"yaw":5000,"flags":0}
	world.room_data = {"style":0}
	actor.source_angles = Vector3i(12,34,56)
	if not actor.initialize_source_player() or actor.source_angles != Vector3i(12,904,56) or actor.position != Vector3(100,700,300)*3.0/4096.0 or (actor.secondary_flags & 2) == 0:
		world.free()
		quit(1)
		return
	world.source_player_entry_state.flags = 4
	world.source_player_entry_state.restore_yaw = false
	if not actor.initialize_source_player() or actor.position != Vector3(100,200,300)*3.0/4096.0 or (actor.secondary_flags & 2) != 0:
		world.free()
		quit(1)
		return
	world.room_data.style = 1
	world.source_player_entry_state.flags = 0
	if not actor.initialize_source_player() or actor.position != Vector3(100,2800,300)*3.0/4096.0 or actor.collision_calls != 3:
		world.free()
		quit(1)
		return
	var quarter: Array = []
	quarter.resize(1025)
	quarter.fill(0)
	quarter[1024] = 4096
	world.runtime_tables.trigonometry = {"quarterSine":quarter}
	actor.position = Vector3.ZERO
	actor.source_angles.y = 0
	world.room_data.style = 0
	if not world.reset_source_camera(actor) or world.source_camera_state.position != Vector3i(0,1536,-256) or world.source_camera_state.yaw != 0 or world.source_camera_target != actor:
		world.free()
		quit(1)
		return
	world.room_data.style = 1
	if not world.reset_source_camera(actor) or world.source_camera_state.position != Vector3i(0,1536,6144) or world.source_camera_state.yaw != 2048:
		world.free()
		quit(1)
		return
	if actor.asl_command({"op":95,"args":[[{"op":4,"value":-1},{"op":18}]]},actor.vm) != "continue" or world.source_camera_height_units != -1:
		world.free()
		quit(1)
		return
	if actor.asl_command({"op":102,"args":[[{"op":4,"value":26214},{"op":18}]]},actor.vm) != "continue" or world.source_camera_distance_units != 1638 or world.source_camera_distance_copy_units != 1638:
		world.free()
		quit(1)
		return
	world.reset_source_camera(actor)
	# CamTarget72 calls412e4:412f4/f8/fc clear height and both distances.
	if world.source_camera_height_units != 0 or world.source_camera_distance_units != 0 or world.source_camera_distance_copy_units != 0:
		push_error("Camera initialization retained original height/distance words")
		world.free()
		quit(1)
		return
	world.room_data.style = 65535
	world.map_name = "MP010_02.MAP"
	if actor.vm.evaluate([{"op":3,"index":40},{"op":18}]) != -65536 or actor.vm.evaluate([{"op":3,"index":69},{"op":18}]) != 655360 or actor.vm.evaluate([{"op":3,"index":70},{"op":18}]) != 131072:
		world.free()
		quit(1)
		return
	if actor.asl_command({"op":56,"args":[37,[{"op":4,"value":-123},{"op":18}]]},actor.vm) != "continue" or observer.vm.evaluate([{"op":3,"index":37},{"op":18}]) != -123 or world.source_camera_state.offset != Vector3i(-123,1280,0):
		world.free()
		quit(1)
		return
	world.source_player_entry_state.flags = 12
	if actor.vm.evaluate([{"op":3,"index":58},{"op":18}]) != 12:
		world.free()
		quit(1)
		return
	actor.source_ground.surface_type = 1
	if observer.vm.evaluate([{"op":3,"index":84},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	actor.source_ground.surface_type = 0x80
	world.source_ground_mode_80_value = -17
	world.source_pickup_counts[1] = 7
	if observer.vm.evaluate([{"op":3,"index":41},{"op":18}]) != 458752:
		world.free()
		quit(1)
		return
	if observer.vm.evaluate([{"op":3,"index":84},{"op":18}]) != -17:
		world.free()
		quit(1)
		return
	world.update_source_input(0x205,4)
	if world.source_input_held_mask != 0x205 or world.source_input_pressed_mask != 0x201 or world.source_input_released_mask != 0:
		world.free()
		quit(1)
		return
	if actor.vm.evaluate([{"op":3,"index":13},{"op":18}]) != 0x201 or actor.vm.evaluate([{"op":28,"index":13},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	world.source_input_suppression_count = -1
	world.update_source_input(0x205,0x205)
	if world.source_input_pressed_mask != 0 or world.source_input_released_mask != 0:
		world.free()
		quit(1)
		return
	world.update_source_input(4,0x205)
	if world.source_input_pressed_mask != 0 or world.source_input_released_mask != 0x201 or world.source_input_held_mask != 4:
		world.free()
		quit(1)
		return
	world.source_input_pressed_mask = null
	if actor.vm.evaluate([{"op":3,"index":13},{"op":18}]) != 0 or actor.vm.status == "unsupported":
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x601
	if actor.vm.evaluate([{"op":3,"index":24},{"op":18}]) != 512 or actor.vm.evaluate([{"op":3,"index":25},{"op":18}]) != 1024:
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x81
	if actor.vm.evaluate([{"op":3,"index":24},{"op":18}]) != 0 or actor.vm.evaluate([{"op":3,"index":25},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	var words: Array = []
	words.resize(22)
	words.fill(0)
	words[18] = 100
	words[19] = -200
	observer.model_data = {"models":[{"collision":{"groups":[[{"halfwords":words}]]}}]}
	observer.primary_flags = 1
	observer.secondary_flags = 0x20
	observer.source_angles.y = 512
	world.source_pool.slots[17] = {"node":observer}
	actor.source_ground = {"mode":2,"surface_type":0,"actor":17,"record":0}
	actor.secondary_flags = 2
	if world.source_player_gradient(actor) != {"x":100,"z":-200,"yaw":512}:
		world.free()
		quit(1)
		return
	observer.secondary_flags = 0
	if world.source_player_gradient(actor) != {"x":0,"z":0,"yaw":0}:
		world.free()
		quit(1)
		return
	world.room_data.tracks = [{"index":0,"position":[0,0,0],"rotation":0.25}]
	world.terrain_models = observer.model_data.models
	actor.source_ground = {"mode":1,"surface_type":0,"tile":0,"record":0}
	if world.source_player_gradient(actor) != {"x":100,"z":-200,"yaw":1024}:
		world.free()
		quit(1)
		return
	var roots: Array = []
	roots.resize(192)
	roots.fill(4096)
	world.runtime_tables.distanceRoot = {"values":roots}
	world.source_player_entry_state.flags = 0
	world.source_input_suppression_count = 0
	world.source_player_input_state = {"pad_mode":1}
	world.update_source_input(1,0)
	actor.position = Vector3.ZERO
	actor.primary_flags = 1
	actor.secondary_flags = 0
	actor.source_angles = Vector3i(12,0,56)
	actor.source_ground = {"mode":0,"surface_type":0,"height_units":0}
	if actor.asl_command({"op":191,"args":[]},actor.vm) != "continue" or actor.position != Vector3(0,0,35)*3.0/4096.0 or actor.source_angles != Vector3i(12,0,56) or world.source_player_movement_state.counter != 1:
		world.free()
		quit(1)
		return
	world.update_source_input(0,1)
	if observer.vm.evaluate([{"op":3,"index":72},{"op":18}]) != 1:
		world.free()
		quit(1)
		return
	if actor.asl_command({"op":191,"args":[]},actor.vm) != "continue" or actor.position != Vector3(0,0,61)*3.0/4096.0 or world.source_player_movement_state.mode != 0:
		world.free()
		quit(1)
		return
	actor.secondary_flags = 2
	world.update_source_input(4,0)
	if actor.asl_command({"op":192,"args":[]},actor.vm) != "continue" or actor.source_angles.y != 0 or world.source_player_movement_state.turn_history != 196608:
		world.free()
		quit(1)
		return
	if actor.asl_command({"op":192,"args":[]},actor.vm) != "continue" or actor.source_angles != Vector3i(12,3,56) or world.source_player_movement_state.turn_history != 491520:
		world.free()
		quit(1)
		return
	if actor.vm.evaluate([{"op":3,"index":65},{"op":18}]) != 2:
		world.free()
		quit(1)
		return
	if observer.vm.evaluate([{"op":3,"index":73},{"op":18}]) != 491520:
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x40000001
	actor.clip_speed_offset = 99
	actor.asl_command({"op":106,"args":[]},actor.vm)
	if actor.primary_flags != 0x40200001 or actor.clip_speed_offset != 99:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":107,"args":[]},actor.vm)
	if actor.primary_flags != 0x40000001 or actor.clip_speed_offset != 99:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":69,"args":[]},actor.vm)
	if actor.primary_flags != 0x50000001:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":70,"args":[]},actor.vm)
	if actor.primary_flags != 0x40000001:
		world.free()
		quit(1)
		return
	var identity := [4096,0,0,0,4096,0,0,0,4096]
	actor.model_data = {"models":[{"radius":1,"bounds":[[0,0,0]]}]}
	actor.clip = {}
	actor.source_render_matrix = identity
	actor.source_render_position = Vector3i.ZERO
	actor.primary_flags = 0x10000801
	observer.model_data = actor.model_data
	observer.clip = {}
	observer.source_render_matrix = identity
	observer.source_render_position = Vector3i.ZERO
	observer.primary_flags = 0x10001
	observer.secondary_flags = 0
	observer.source_player_distance_valid = true
	observer.source_player_distance = 0
	world.source_actors.assign([observer,actor])
	if not world.run_source_player_contacts() or observer.primary_flags != 0x110001 or world.source_player_contact_fault != "":
		world.free()
		quit(1)
		return
	world.source_pickup_counts[1] = 98
	world.add_source_pickup(1)
	world.add_source_pickup(1)
	world.source_pickup_counts[2] = 2147483647
	world.add_source_pickup(2)
	world.add_source_pickup(3)
	if world.source_pickup_counts != {1:99,2:-2147483648,3:4} or world.source_pickup_display_timer != 60:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":181,"args":[31]},actor.vm)
	actor.asl_command({"op":181,"args":[32]},actor.vm)
	if world.source_bonus_mask != -2147483647:
		world.free()
		quit(1)
		return
	world.source_bonus_mask = 31
	if observer.vm.evaluate([{"op":3,"index":67},{"op":18}]) != 1 or observer.vm.evaluate([{"op":3,"index":46},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	world.source_bonus_mask = 63
	if observer.vm.evaluate([{"op":3,"index":67},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	actor.position = Vector3(100,-200,300)*3.0/4096.0
	if observer.vm.evaluate([{"op":3,"index":15},{"op":18}]) != 100 or observer.vm.evaluate([{"op":3,"index":16},{"op":18}]) != -200 or observer.vm.evaluate([{"op":3,"index":17},{"op":18}]) != 300:
		world.free()
		quit(1)
		return
	for fixture in [[189,60],[200,-1],[201,0]]:
		if actor.asl_command({"op":fixture[0],"args":[]},actor.vm) != "continue" or world.source_bonus_display_timer != fixture[1]:
			world.free()
			quit(1)
			return
	actor.vm.parameters = [0,0]
	for tick in range(8):
		actor.vm.pc = 10
		if actor.asl_command({"op":167,"pc":9,"args":[]},actor.vm) != "yield" or actor.source_scale != Vector3i.ONE*(4096-512*(tick+1)) or actor.vm.pc != (9 if tick < 7 else 10):
			world.free()
			quit(1)
			return
	world.source_camera_state.yaw = 5000
	if observer.vm.evaluate([{"op":3,"index":45},{"op":18}]) != 59244544:
		world.free()
		quit(1)
		return
	actor.source_angles = Vector3i(4090,7,4090)
	for command in [45,46]:
		actor.asl_command({"op":command,"args":[[{"op":4,"value":655360},{"op":18}]]},actor.vm)
	actor.asl_command({"op":47,"args":[[{"op":4,"value":393216},{"op":18}]]},actor.vm)
	actor.asl_command({"op":44,"args":[[{"op":4,"value":-131072},{"op":18}]]},actor.vm)
	if actor.source_angles != Vector3i(6,7,4094):
		world.free()
		quit(1)
		return
	actor.source_waypoints = [{},{},{}]
	actor.source_waypoint_index = 0
	actor.asl_command({"op":136,"args":[]},actor.vm)
	if actor.source_waypoint_index != 2:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":136,"args":[]},actor.vm)
	actor.asl_command({"op":135,"args":[]},actor.vm)
	if actor.source_waypoint_index != 2:
		world.free()
		quit(1)
		return
	world.room_data.style = 0
	actor.source_waypoints = [{"runtime_position":Vector3i(1,2,3),"value":4}]
	actor.source_waypoint_index = 0
	observer.source_waypoints = actor.source_waypoints
	observer.source_waypoint_index = 0
	if actor.asl_command({"op":56,"args":[31,[{"op":4,"value":-99},{"op":18}]]},actor.vm) != "continue" or observer.vm.evaluate([{"op":3,"index":31},{"op":18}]) != -99 or actor.source_waypoints[0].runtime_position != Vector3i(1,-99,3):
		world.free()
		quit(1)
		return
	actor.asl_command({"op":56,"args":[33,[{"op":4,"value":-1},{"op":18}]]},actor.vm)
	if observer.vm.evaluate([{"op":3,"index":33},{"op":18}]) != -1:
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x400001
	if actor.vm.evaluate([{"op":3,"index":36},{"op":18}]) != 4194304:
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x2001
	if actor.vm.evaluate([{"op":3,"index":36},{"op":18}]) != 0:
		world.free()
		quit(1)
		return
	if actor.vm.evaluate([{"op":4,"value":67113524},{"op":20},{"op":18}]) != 65536 or actor.vm.evaluate([{"op":4,"value":0},{"op":21},{"op":18}]) != 65536 or actor.vm.evaluate([{"op":4,"value":-67108864},{"op":20},{"op":18}]) != -65536:
		world.free()
		quit(1)
		return
	world.map_name = "MP010_02.MAP"
	world.source_checkpoint_entry = {"present":true,"flags":9,"position":Vector3i(1,2,3)}
	world.source_pickup_counts = {1:7,2:1,3:3}
	world.source_map_entity_flags = {"MP010_02.MAP":{0:5,1:4},"MP011_00.MAP":{0:4}}
	if actor.asl_command({"op":170,"args":[]},actor.vm) != "continue" or world.source_transition_state != 1 or world.source_pickup_counts != {1:0,2:1,3:2} or world.source_map_entity_flags["MP010_02.MAP"] != {0:1,1:0} or world.source_map_entity_flags["MP011_00.MAP"][0] != 4 or world.source_pickup_display_timer != 240 or world.source_bonus_display_timer != 30:
		world.free()
		quit(1)
		return
	actor.asl_command({"op":170,"args":[]},actor.vm)
	world.source_player_entry_state.flags = 2
	if world.source_pickup_counts[3] != 2 or world.source_checkpoint_entry.flags != 9:
		world.free()
		quit(1)
		return
	world.source_player_actor = actor
	actor.source_angles = Vector3i(-1,5000,8193)
	observer.source_angles = Vector3i.ZERO
	for index in [18,19,20]:
		var expected: int = [268369920,59244544,65536][index-18]
		if observer.vm.evaluate([{"op":3,"index":index},{"op":18}]) != expected:
			push_error("Registered player angle getter failed")
			world.free()
			quit(1)
			return
	actor.previous_source_position = Vector3i.ZERO
	actor.position = Vector3(0,100,0)
	if actor.vm.evaluate([{"op":3,"index":11},{"op":18}]) != 0:
		push_error("Horizontal motion distance included vertical movement")
		world.free()
		quit(1)
		return
	actor.position.x = world.CELL_METERS
	if actor.vm.evaluate([{"op":3,"index":11},{"op":18}]) != 65536:
		push_error("Horizontal motion distance scaling failed")
		world.free()
		quit(1)
		return
	actor.previous_source_position.x = 4096
	if actor.vm.evaluate([{"op":3,"index":11},{"op":18}]) != 0:
		push_error("Horizontal motion distance ignored previous pose")
		world.free()
		quit(1)
		return
	actor.primary_flags = 0x41
	actor.secondary_flags = 0x82
	actor.source_ground.height_units = 123
	var previous_calls: int = actor.collision_calls
	var previous_position: Vector3 = actor.position
	if actor.asl_command({"op":203,"args":[]},actor.vm) != "continue" or actor.collision_calls != previous_calls+1 or actor.height_before_collision != 0 or actor.primary_flags != 0x841 or actor.secondary_flags != 0x80 or actor.position != previous_position or world.source_player_actor != actor or world.source_player_id != actor.source_pool_id:
		push_error("QuickPlayer performed incorrect state/arrival initialization")
		world.free()
		quit(1)
		return
	world.free()
	print("PASS: native state, QuickPlayer, registered player angles, horizontal motion distance and death requests")
	quit(0)
