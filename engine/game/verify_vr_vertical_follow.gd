extends SceneTree
const Follow=preload("res://vr_vertical_follow.gd")
func _initialize() -> void:
	var state := Follow.initialize(3.0)
	# Repeated jumps and brief contacts must not pull the camera through an arc.
	for jump in range(12):
		for frame in range(60):
			state=Follow.step(state,3.0+1.4*sin(PI*float(frame)/60.0),false,1.0/60.0)
			assert(is_equal_approx(state.height,3.0))
		for frame in range(4):state=Follow.step(state,3.0,true,1.0/60.0)
		assert(is_equal_approx(state.height,3.0))
	# A platform landing starts catching up immediately with bounded acceleration.
	state=Follow.initialize(3.0)
	for frame in range(360):
		var previous:=state.duplicate()
		state=Follow.step(state,4.0,true,1.0/60.0)
		assert(absf(state.velocity)<=Follow.MAX_SPEED+0.000001)
		assert(absf(state.velocity-previous.velocity)<=Follow.MAX_ACCELERATION/60.0+0.000001)
	assert(absf(state.height-4.0)<0.16)
	# Higher-platform landing should settle promptly, including at VR refresh rates.
	for rate in [60,72,90,120,144]:
		state=Follow.initialize(3.0)
		for frame in range(roundi(rate*0.6)):
			state=Follow.step(state,4.5,true,1.0/rate)
		assert(absf(state.height-4.5)<0.08,"Higher-platform landing took too long to catch up")
		# Terminal source fall speed is about12.7m/s; exercise a20m continuous drop.
		state=Follow.initialize(20.0)
		var lowest_error := 0.0
		for frame in range(roundi(rate*1.6)):
			var player_height:=maxf(0.0,20.0-(frame+1)*12.7/rate)
			state=Follow.step(state,player_height,false,1.0/rate)
			lowest_error=maxf(lowest_error,absf(state.height-player_height))
		assert(lowest_error<2.7,"Long drop left the player far below the camera")
		for frame in range(roundi(rate*0.6)):state=Follow.step(state,0.0,true,1.0/rate)
		assert(absf(state.height)<0.08,"Camera did not settle promptly after a long drop")
		state=Follow.initialize(20.0)
		lowest_error=0.0
		for frame in range(roundi(rate*1.6)):
			var source_tick:=floorf(float(frame+1)*30.0/rate)
			var player_height:=maxf(0.0,20.0-source_tick*12.7/30.0)
			state=Follow.step(state,player_height,false,1.0/rate)
			lowest_error=maxf(lowest_error,absf(state.height-player_height))
		assert(lowest_error<2.7,"30Hz source positions made high-refresh drop tracking lag")
	# Eight rapid box jumps, with only one frame of contact on each landing.
	state=Follow.initialize(3.0)
	for stair in range(1,9):
		var support:=3.0+stair*0.6
		state=Follow.step(state,support,true,1.0/60.0)
		for frame in range(30):
			state=Follow.step(state,support+1.4*sin(PI*frame/30.0),false,1.0/60.0)
		assert(support-state.height<0.65,"Rapid staircase left the camera behind")
	# Large drops still follow, but cannot introduce a single-frame camera lurch.
	var before:float=state.height
	state=Follow.step(state,-5.0,false,5.0)
	assert(absf(state.height-before)<=Follow.MAX_SPEED*0.05)
	for frame in range(180):state=Follow.step(state,-5.0,false,1.0/60.0)
	assert(state.height<before-0.5)
	print("PASS: level jumps remain steady; higher landings settle within0.6s;20m falls stay within2.7m and settle promptly at60..144Hz; rapid stairs and bounded drop recovery")
	quit(0)
