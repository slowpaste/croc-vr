extends SceneTree
const Move = preload("res://source_player_movement.gd")
const Pad = preload("res://source_input.gd")
func _initialize() -> void:
	if Move.analog_turn(0,0,1,0,2,0,100,63,64,0) != {"yaw":3,"history":196608} or Move.analog_turn(0,0,3,0,2,0,100,63,64,0) != {"yaw":4093,"history":-196608} or Move.analog_turn(0,655360,1,0,2,0,0,63,0,0) != {"yaw":0,"history":0} or Move.analog_turn(10,655360,1,1,2,0,100,63,64,0) != {"yaw":10,"history":0}:
		quit(1)
		return
	if Move.digital_turn_history(0,2,0) != {"history":196608,"yaw_delta":0} or Move.digital_turn_history(0,2,196608) != {"history":491520,"yaw_delta":3} or Move.digital_turn_history(1,2,0) != {"history":720896,"yaw_delta":0} or Move.digital_turn_history(1,-2,-720896) != {"history":-901120,"yaw_delta":-11} or Move.digital_turn_history(0,1,196608) != {"history":0,"yaw_delta":3} or Move.digital_turn_history(1,1,524288) != {"history":65536,"yaw_delta":8} or Move.digital_turn_history(0,0,524288) != {"history":524288,"yaw_delta":0}:
		quit(1)
		return
	if Move.digital_turn_direction(0,0,2,4,0) != 2 or Move.digital_turn_direction(0,0,2,12,0) != -2 or Move.digital_turn_direction(0,0,2,4,-26215) != -1 or Move.digital_turn_direction(5,0,2,8,26215) != 1 or Move.digital_turn_direction(0,1,2,4,-26214) != 0 or Move.digital_turn_direction(4,0,2,0x100,0) != -2:
		quit(1)
		return
	if Pad.analog_thresholds(Vector2i(128,128),Vector2i.ZERO,Vector2i(255,255)) != {"idle_threshold":63,"run_threshold":123} or Pad.analog_thresholds(Vector2i(120,130),Vector2i.ZERO,Vector2i(255,255)) != {"idle_threshold":60,"run_threshold":116}:
		quit(1)
		return
	var initial := Move.initial_state()
	var motion_reset := Move.reset_motion_state({"motion":Vector2i(10,20),"magnitude":30,"field456":9,"reset_pending":false,"yaw_rate":123,"timer":456,"mode":5})
	if motion_reset.motion != Vector2i.ZERO or motion_reset.magnitude != 0 or motion_reset.field456 != 0 or not motion_reset.reset_pending or motion_reset.yaw_rate != 123 or motion_reset.timer != 456 or motion_reset.mode != 5:
		quit(1)
		return
	var reset := Move.reset_entry_state(initial,3,0)
	if not initial.reset_pending or initial.has("forced") or initial.motion != Vector2i.ZERO or reset.reset_pending or reset.forced != 1 or reset.lock != 30 or reset.suppression != 1 or reset.mode != 0 or reset.counter != 0:
		quit(1)
		return
	reset.motion = Vector2i(123,-456)
	reset = Move.reset_entry_state(reset,0,7)
	if reset.motion != Vector2i(123,-456) or reset.lock != 0 or reset.forced != 0 or reset.suppression != 7:
		quit(1)
		return
	var pre := Move.pre_input(1,7,1,0x401,2)
	if pre.forced != 2 or pre.lock != 7 or pre.primary != 0x201 or pre.secondary != 0 or pre.rise_remaining != 3600 or pre.vertical_speed != 261 or not pre.bypass:
		quit(1)
		return
	if Move.pre_input(9,0,0,1,0).forward != 35 or Move.pre_input(34,0,0,1,0).forward != 35 or Move.pre_input(35,0,0,1,0).forward != 0 or Move.pre_input(9,0,0,1,2).forced != 0:
		quit(1)
		return
	pre = Move.pre_input(0,1,1,1,2)
	if pre.lock != 0 or pre.suppression != 0 or pre.mode != 1 or pre.forward != 35 or not pre.bypass or Move.pre_input(0,0,1,1,2).mode != 0 or Move.pre_input(0,0,0,1,2).bypass:
		quit(1)
		return
	if Move.slide_heading(0,64,0) != {"yaw":2,"rate":2} or Move.slide_heading(0,4032,0) != {"yaw":4094,"rate":-2} or Move.slide_heading(0,3,0) != {"yaw":0,"rate":0} or Move.slide_heading(0,4093,0) != {"yaw":4095,"rate":-1} or Move.slide_heading(4095,1,99) != {"yaw":1,"rate":0} or Move.slide_heading(0,2048,0) != {"yaw":4063,"rate":-33}:
		quit(1)
		return
	if Move.begin_slide_state(5,1,false) != {"mode":5,"timer":0} or Move.begin_slide_state(5,0,false) != {"mode":0,"timer":0} or Move.begin_slide_state(5,1,true) != {"mode":5,"timer":1}:
		quit(1)
		return
	if Move.finish_slide_state(0,0,true,8,false,{"first":true,"second":false}) != {"mode":5,"timer":20,"reset_yaw_rate":true} or Move.finish_slide_state(1,0,true,1,true,{"first":true,"second":false}) != {"mode":1,"timer":0,"reset_yaw_rate":false} or Move.finish_slide_state(5,1,true,8,false,{"first":false,"second":false}) != {"mode":5,"timer":0,"reset_yaw_rate":false} or Move.finish_slide_state(0,0,true,14,false,{"first":true,"second":true}).mode != 0:
		quit(1)
		return
	if Pad.digital_pad(65535,0,4) != 0 or Pad.digital_pad(65535^0x10,0,4) != 0x10001 or Pad.digital_pad(65535^0x4000,1,4) != 0x800001 or Pad.digital_pad(65535^0x4000,2,4) != 0x801000 or Pad.digital_pad(65535^0x1010,0,4) != 0x40110000 or Pad.digital_pad(65535^0x1000,0,0) != 0x100000:
		quit(1)
		return
	if Move.digital_input(0x181,1,5,0,2) != {"mode":2,"counter":5,"forward":35,"side":-12,"shift":2,"speed":140} or Move.digital_input(3,0,0,1,2) != {"mode":1,"counter":1,"forward":4,"side":0,"shift":5,"speed":128} or Move.digital_input(0xb,4,8,0,2) != {"mode":4,"counter":8,"forward":2,"side":-17,"shift":2,"speed":140} or Move.digital_input(0x1ff,5,8,0,2) != {"mode":5,"counter":8,"forward":0,"side":0,"shift":2,"speed":140}:
		quit(1)
		return
	var quarter: Array = []
	quarter.resize(1025)
	quarter.fill(0)
	quarter[1024] = 4096
	var analog := {"magnitude":100,"idle_threshold":10,"run_threshold":50,"camera_yaw":1024,"stick_yaw":0,"buttons":0,"mode":1,"counter":5,"surface_type":0,"secondary":2,"actor_yaw":0}
	if Move.analog_input(analog,quarter) != {"mode":2,"counter":5,"forward":35,"side":0,"shift":2,"speed":140,"heading":1024}:
		quit(1)
		return
	analog.secondary = 0
	if Move.analog_input(analog,quarter).side != 26 or Move.analog_input(analog,quarter).forward != 0:
		quit(1)
		return
	analog.secondary = 2
	analog.magnitude = 40
	analog.counter = 0
	analog.buttons = 3
	if Move.analog_input(analog,quarter).mode != 3 or Move.analog_input(analog,quarter).forward != -15:
		quit(1)
		return
	analog.buttons = 0
	analog.magnitude = 50
	if Move.analog_input(analog,quarter).mode != 0 or Move.analog_input(analog,quarter).forward != 0:
		quit(1)
		return
	var angles: Array = []
	angles.resize(1025)
	angles.fill(0)
	if Move.slide_target(35,0,0,{"x":0,"z":64,"yaw":0},quarter,angles) != {"target":Vector2i(0,-160768),"square":76546048} or Move.slide_target(35,17,0,{"x":0,"z":0,"yaw":0},quarter,angles) != {"target":Vector2i.ZERO,"square":0}:
		quit(1)
		return
	if Move.movement_target(140,35,0,quarter).target != Vector2i(143360,573440) or Move.movement_target(140,35,1024,quarter).target != Vector2i(573440,-143360):
		quit(1)
		return
	if Move.movement_target(35,35,0,quarter,{"x":0,"z":64,"yaw":0}) != {"target":Vector2i(143360,118784),"adjustment":24576} or Move.movement_target(35,35,0,quarter,{"x":0,"z":-64,"yaw":0}) != {"target":Vector2i(143360,155648),"adjustment":-24576}:
		quit(1)
		return
	var roots: Array = []
	if Move.movement_target(140,35,0,quarter,{"x":0,"z":64,"yaw":0}).target != Vector2i(143360,-499712):
		quit(1)
		return
	roots.resize(192)
	roots.fill(4096)
	var packet := {"pad_mode":1,"buttons":1,"suppression":0}
	var actor_state := {"position":Vector3i.ZERO,"yaw":0,"primary":1,"secondary":2,"surface_type":0,"status":0,"entry_flags":0}
	var tables := {"trigonometry":{"quarterSine":quarter},"wallAngles":{"values":angles},"distanceRoot":{"values":roots}}
	var combined := Move.step(Move.initial_state(),actor_state,packet,{"x":0,"z":0,"yaw":0},tables)
	if combined.has("fault") or combined.position != Vector3i(0,0,35) or combined.state.motion != Vector2i(0,143360) or combined.state.counter != 1 or combined.state.mode != 1:
		push_error("PlayerMove composition failed: "+str(combined))
		quit(1)
		return
	actor_state.position = combined.position
	combined = Move.step(combined.state,actor_state,packet,{"x":0,"z":0,"yaw":0},tables)
	if combined.has("fault") or combined.position != Vector3i(0,0,96) or combined.state.motion != Vector2i(0,250880):
		quit(1)
		return
	if Move.final_position(Vector3i(2147483647,17,0),Vector2i(4096,-1),roots) != {"position":Vector3i(-2147483648,17,-1),"magnitude":1} or Move.final_position(Vector3i(1,2,3),Vector2i.ZERO,roots) != {"position":Vector3i(1,2,3),"magnitude":0} or not Move.final_position(Vector3i.ZERO,Vector2i(2147483647,2147483647),roots).has("fault"):
		quit(1)
		return
	for mask in range(16):
		for forward in [-140,0,140]:
			for side in [-35,0,35]:
				var expected := Vector2i(0 if (forward > 0 and (mask&1) != 0) or (forward < 0 and (mask&2) != 0) else forward,0 if (side > 0 and (mask&4) != 0) or (side < 0 and (mask&8) != 0) else side)
				if Move.restrict_wall_axes(mask|0x800,forward,side) != expected:
					quit(1)
					return
	if Move.accumulate_motion(Vector2i(7,-7),Vector2i(100,-100),2) != Vector2i(106,-105) or Move.accumulate_motion(Vector2i(32,-32),Vector2i.ZERO,5) != Vector2i(31,-31) or Move.accumulate_motion(Vector2i(2147483647,0),Vector2i(2147483647,0),0) != Vector2i(2147483647,0):
		quit(1)
		return
	for fixture in [[1,64,0,4096,false,false],[1,64,1,4097,true,false],[1,128,0,16384,true,false],[1,128,1,16385,true,true],[15,64,1,4097,true,true],[8,128,0,16384,false,false],[8,128,1,16385,true,false],[8,128,128,32768,true,false],[8,181,15,32986,true,true],[0,256,0,65536,false,false],[0,256,1,65537,true,false],[0,256,256,131072,true,false],[0,256,257,131585,true,true],[1,46341,0,-2147479015,false,false]]:
		var result := Move.gradient_state(fixture[0],fixture[1],fixture[2])
		if result != {"square":fixture[3],"first":fixture[4],"second":fixture[5]}:
			push_error("PlayerMove gradient mismatch: "+str(fixture)+" -> "+str(result))
			quit(1)
			return
	if Move.accumulate_motion(Vector2i(2147483647,0),Vector2i(2147483647,0),2) != Vector2i(-536870913,0):
		quit(1)
		return
	print("PASS: PlayerMove wall-axis restrictions, motion accumulation and signed slope thresholds")
	quit(0)
