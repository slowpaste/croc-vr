extends RefCounted
# Verified stages of PlayerMove; the full command remains incomplete.
const VM = preload("res://asl_vm.gd")
const Collision = preload("res://source_collision.gd")
static func analog_turn(yaw: int, history: int, mode: int, suppression: int, secondary: int, buttons: int, magnitude: int, threshold: int, camera_yaw: int, stick_yaw: int) -> Dictionary:
	if (secondary&2) == 0:
		var direction := digital_turn_direction(0,0,0,buttons,history)
		var result := digital_turn_history(mode,direction,history)
		return {"yaw":(yaw+int(result.yaw_delta))&4095,"history":result.history}
	var rate := halfword(history>>16)
	if (magnitude&0xffffffff) > (threshold&0xffffffff):
		var target := (stick_yaw+4096-camera_yaw)&4095 if mode == 3 else (camera_yaw+stick_yaw)&4095
		if suppression != 0:
			target = yaw&65535
		var delta := ((target-yaw)&4095)
		if delta >= 2048:
			delta -= 4096
		if absi(delta) < 3:
			return {"yaw":target&4095,"history":0}
		rate = VM.signed32(rate+(delta>>5)+(1 if delta > 0 else -1))
		if delta > 0:
			rate = mini(rate,delta>>3)
			rate = mini(rate,delta)
		else:
			rate = maxi(rate,delta>>3)
			rate = maxi(rate,delta)
	else:
		rate >>= 2
		if rate >= -3 and rate <= 3:
			rate = 0
	return {"yaw":(yaw+rate)&4095,"history":VM.signed32(rate<<16)}
static func digital_turn_history(mode: int, direction: int, history: int) -> Dictionary:
	history = VM.signed32(history)
	if direction == 0:
		return {"history":history,"yaw_delta":0}
	var delta := halfword(history>>16)
	var idle := mode in [0,3]
	if direction == 2:
		var minimum := 0x30000 if idle else 0xb0000
		var maximum := 0x3f0000 if idle else 0x340000
		if history < minimum:
			history = minimum
		elif history < maximum:
			history = VM.signed32(VM.signed32(history<<1)+(history>>1)) if idle else VM.signed32(history+(history>>2))
		else:
			history = maximum
	elif direction == -2:
		var minimum := -0x30000 if idle else -0xb0000
		var maximum := -0x3f0000 if idle else -0x340000
		if history > minimum:
			history = minimum
		elif history > maximum:
			history = VM.signed32(VM.signed32(history<<1)+(history>>1)) if idle else VM.signed32(history+(history>>2))
		else:
			history = maximum
	else:
		var retaining := history > 0x30000 if direction > 0 else history < -0x30000
		history = (history>>(2 if idle else 3)) if retaining else 0
	return {"history":history,"yaw_delta":delta}
static func digital_turn_direction(mode: int, suppression: int, secondary: int, buttons: int, history: int) -> int:
	# PlayerTurn0x800443d8..0x800444c4 retains historical turning under suppression.
	var direction := 1 if history >= 26215 else -1 if history < -26214 else 0
	if mode == 5 or suppression != 0:
		return direction
	var grounded := (secondary&2) != 0 and mode != 4
	var positive := 4 if grounded else 0x80
	var negative := 8 if grounded else 0x100
	if (buttons&positive) != 0 and direction != -1:
		direction = 2
	if (buttons&negative) != 0 and direction != 1:
		direction = -2
	return direction
static func step(state: Dictionary, actor: Dictionary, input: Dictionary, gradient: Dictionary, tables: Dictionary) -> Dictionary:
	for key in ["position","yaw","primary","secondary","surface_type","status","entry_flags"]:
		if not actor.has(key):
			return {"fault":"Missing PlayerMove actor field: "+key}
	if not input.has("suppression") or not state.has("motion") or not state.has("magnitude") or not state.has("reset_pending"):
		return {"fault":"Incomplete PlayerMove shared state"}
	var next := state.duplicate(true)
	var suppression := int(input.suppression)
	if bool(next.reset_pending):
		next = reset_entry_state(next,int(actor.entry_flags),suppression)
		suppression = int(next.suppression)
	for key in ["mode","counter","lock","forced"]:
		if not next.has(key):
			return {"fault":"Unknown PlayerMove shared word: "+key}
	var pre := pre_input(int(next.forced),int(next.lock),suppression,int(actor.primary),int(actor.secondary))
	next.forced = pre.forced
	next.lock = pre.lock
	next.suppression = pre.suppression
	var primary := int(pre.primary)
	var secondary := int(pre.secondary)
	if pre.mode != null:
		next.mode = pre.mode
	var quarter: Array = tables.get("trigonometry",{}).get("quarterSine",[])
	var angles: Array = tables.get("wallAngles",{}).get("values",[])
	var roots: Array = tables.get("distanceRoot",{}).get("values",[])
	var selection := {"forward":pre.forward,"side":0,"shift":2,"speed":140}
	if not bool(pre.bypass) or bool(input.get("intent_override",false)):
		if not input.has("pad_mode") or not input.has("buttons"):
			return {"fault":"Unknown PlayerMove pad state"}
		if int(input.pad_mode) == 2:
			var analog := input.duplicate(true)
			analog.merge({"mode":next.mode,"counter":next.counter,"surface_type":actor.surface_type,"secondary":secondary,"actor_yaw":actor.yaw},true)
			selection = modern_input(analog,quarter) if bool(input.get("modern",false)) else analog_input(analog,quarter)
		else:
			selection = digital_input(int(input.buttons),int(next.mode),int(next.counter),int(actor.surface_type),secondary)
		if selection.has("fault"):
			return selection
		next.mode = selection.mode
		next.counter = selection.counter
	var axes := restrict_wall_axes(int(actor.status),int(selection.forward),int(selection.side))
	var grounded := (secondary&2) != 0
	if not grounded and int(actor.surface_type) != 15:
		gradient = {"x":0,"z":0,"yaw":0}
	var clip_offset := 0
	if (primary&0x200000) != 0 and grounded:
		clip_offset = halfword(int(float((VM.signed32(int(next.magnitude)<<8)&0xffffffff))/int(selection.speed))-256)&65535
	if not gradient.has("x") or not gradient.has("z") or not gradient.has("yaw"):
		return {"fault":"Missing PlayerMove selected gradient"}
	if int(next.mode) in [4,5] and not next.has("timer"):
		return {"fault":"Unknown PlayerMove slide timer"}
	var timer := int(next.get("timer",0))
	var begun := begin_slide_state(int(next.mode),timer,grounded)
	next.mode = begun.mode
	if next.has("timer"):
		next.timer = begun.timer
	timer = int(begun.timer)
	var slope := gradient_state(int(actor.surface_type),int(gradient.x),int(gradient.z))
	var target := Vector2i.ZERO
	var constructed: Dictionary = {}
	if int(next.mode) in [4,5]:
		if grounded:
			constructed = slide_target(axes.x,axes.y,int(actor.yaw),gradient,quarter,angles)
	elif axes != Vector2i.ZERO:
		var use_slope := (grounded and int(actor.surface_type) != 14) or int(actor.surface_type) == 15
		var movement_yaw := int(selection.get("movement_yaw",actor.yaw))
		constructed = movement_target(axes.x,axes.y,movement_yaw,quarter,gradient if use_slope else {})
	if constructed.has("fault"):
		return constructed
	if constructed.has("target"):
		target = constructed.target
	var finished := finish_slide_state(int(next.mode),timer,grounded,int(actor.surface_type),axes != Vector2i.ZERO,slope)
	next.mode = finished.mode
	if next.has("timer") or int(next.mode) == 5:
		next.timer = finished.timer
	if bool(finished.reset_yaw_rate):
		next.yaw_rate = 0
	if bool(input.get("modern",false)) and int(selection.shift) == 1 and (not bool(pre.bypass) or bool(input.get("intent_override",false))):
		target *= 2 # Faster convergence while retaining the original top speed.
	next.motion = accumulate_motion(next.motion,target,int(selection.shift))
	if bool(input.get("modern",false)) and input.has("turn_translation_scale"):
		# Cap retained momentum too, so a running reversal cannot launch the player.
		var scale := clampf(float(input.turn_translation_scale),0.0,1.0)
		var limit := float(Vector2(target).length())*pow(2.0,int(selection.shift))*scale
		var motion := Vector2(next.motion).limit_length(limit)
		next.motion = Vector2i(roundi(motion.x),roundi(motion.y))
	var yaw := int(actor.yaw)
	if int(next.mode) in [4,5]:
		if not next.has("yaw_rate"):
			return {"fault":"Unknown PlayerMove yaw history"}
		var heading := Collision.wall_normal_angle(next.motion,angles)
		if heading.has("fault"):
			return heading
		var turn := slide_heading(yaw,int(heading.angle),int(next.yaw_rate))
		yaw = int(turn.yaw)
		next.yaw_rate = turn.rate
	var committed := final_position(actor.position,next.motion,roots)
	if committed.has("fault"):
		return committed
	next.magnitude = committed.magnitude
	if bool(input.get("modern",false)) and (primary&0x200000) != 0 and grounded and int(next.mode) not in [4,5]:
		clip_offset = (clampi(roundi(float(next.magnitude)*256.0/maxi(1,int(selection.speed))),32,512)-256)&65535
	var result := {"state":next,"position":committed.position,"yaw":yaw,"primary":primary,"secondary":secondary,"clip_offset":clip_offset}
	for key in ["rise_remaining","vertical_speed"]:
		if pre.has(key):
			result[key] = pre[key]
	return result
static func modern_input(input: Dictionary, quarter: Array) -> Dictionary:
	if bool(input.get("traversal",false)):
		return {"mode":0,"counter":0,"forward":0,"side":0,"shift":1,"speed":60}
	# Leave scripted movement, slippery slopes and surfing to their source states.
	if int(input.mode) in [4,5]:
		return analog_input(input,quarter)
	if bool(input.get("turn_only",false)):
		return {"mode":0,"counter":0,"forward":0,"side":0,"shift":1,"speed":60}
	var amount := clampf(float(int(input.magnitude)-int(input.idle_threshold))/float(127-int(input.idle_threshold)),0.0,1.0)
	var slow := (int(input.surface_type)&255) == 15 or ((int(input.surface_type)&255) == 1 and (int(input.secondary)&2) != 0)
	if bool(input.get("natural_step",false)):
		var forward_axis := float(input.get("local_forward",0.0))
		var side_axis := float(input.get("local_side",0.0))
		return {"mode":3 if forward_axis < -0.35 and absf(forward_axis)>=absf(side_axis) else 0,"counter":0,"forward":roundi(amount*(4.0 if slow else 35.0)),"side":0,"shift":5 if slow else 1,"speed":64 if slow else 60,"movement_yaw":int(input.stick_yaw)}
	if bool(input.get("precision",false)):
		var result := digital_input(int(input.buttons),1,0,int(input.surface_type),int(input.secondary))
		result.forward = roundi(float(result.forward)*amount)
		result.side = roundi(float(result.side)*amount)
		result.shift = 5 if slow else 1
		return result
	var running := int(input.magnitude) > int(input.run_threshold)-(6 if int(input.mode) == 2 else 0)
	return {"mode":0 if amount == 0.0 or bool(input.get("turn_step",false)) else 2 if running else 1,"counter":5 if running else 0,"forward":roundi(amount*(4.0 if slow else 35.0)),"side":0,"shift":5 if slow else 1,"speed":128 if slow else 140 if running else 60,"movement_yaw":int(input.stick_yaw)}
static func analog_input(input: Dictionary, quarter: Array) -> Dictionary:
	for key in ["magnitude","idle_threshold","run_threshold","camera_yaw","stick_yaw","buttons","mode","counter","surface_type","secondary","actor_yaw"]:
		if not input.has(key):
			return {"fault":"Missing PlayerMove analog field: "+key}
	if quarter.size() != 1025:
		return {"fault":"Missing PlayerMove analog trigonometry"}
	var mode := int(input.mode)
	var counter := int(input.counter)
	var grounded := (int(input.secondary)&2) != 0
	var slow := (int(input.surface_type)&255) == 15 or ((int(input.surface_type)&255) == 1 and grounded)
	var buttons := int(input.buttons)
	var forward := 0
	var side := 0
	var speed := 140
	var heading := 0
	if mode == 4:
		forward = 2 if (buttons&1) != 0 else -4 if (buttons&2) != 0 else 0
		if (buttons&4) != 0:
			side = 4 if slow else 17
		if (buttons&8) != 0:
			side = -4 if slow else -17
	elif mode != 5:
		var magnitude := int(input.magnitude)&0xffffffff
		var running := magnitude > (int(input.run_threshold)&0xffffffff)
		if magnitude <= (int(input.idle_threshold)&0xffffffff):
			mode = 0
			counter = 0
		else:
			heading = (int(input.camera_yaw)+int(input.stick_yaw))&4095
			if running and counter == 5:
				mode = 2
			elif (buttons&3) != 0 or running:
				if (buttons&2) != 0 and grounded:
					mode = 3
				else:
					mode = 1
					if (counter&0xffffffff) < 5:
						counter = VM.signed32(counter+1)
			else:
				mode = 0
				counter = 0
			if mode == 3:
				forward = -2 if slow else -15
			elif running:
				forward = 4 if slow else 35
				speed = 128 if slow else 140
			elif mode != 0:
				forward = 2 if slow else 15
				speed = 64 if slow else 60
			if not grounded:
				heading = (heading-int(input.actor_yaw))&4095
				var product := VM.signed32(Collision.sine(heading,quarter)*forward)
				side = VM.signed32(VM.signed32(product*3)<<1)>>15
				forward = VM.signed32(Collision.sine(heading+1024,quarter)*forward)>>12
	return {"mode":mode,"counter":counter,"forward":forward,"side":side,"shift":5 if slow else 2,"speed":speed,"heading":heading}
static func initial_state() -> Dictionary:
	# Startup call0x80013034 invokes0x80042e34; other words await entry reset.
	return {"motion":Vector2i.ZERO,"magnitude":0,"field456":0,"reset_pending":true,"yaw_rate":0,"timer":0}

static func reset_motion_state(state: Dictionary) -> Dictionary:
	# Respawn0x800157a0 calls0x80042e34; unrelated shared history is retained.
	var result := state.duplicate(true)
	result.motion = Vector2i.ZERO
	result.magnitude = 0
	result.field456 = 0
	result.reset_pending = true
	return result
static func stop_dead(state: Dictionary) -> Dictionary:
	# StopDead160 at0x800430e0 clears gp460/464/468/1684/1896/1688.
	# It does not run entry reset or alter vertical jump/fall state.
	var result := state.duplicate(true)
	result.motion = Vector2i.ZERO
	result.magnitude = 0
	result.mode = 0
	result.counter = 0
	result.turn_history = 0
	return result

static func reset_entry_state(state: Dictionary, entry_flags: int, suppression: int) -> Dictionary:
	# 0x80043110..0x80043174 preserves motion and suppression except bit1 add.
	var result := state.duplicate(true)
	result.mode = 0
	result.counter = 0
	result.turn_history = 0
	result.lock = 30 if (entry_flags&1) != 0 else 0
	result.forced = 1 if (entry_flags&2) != 0 else 0
	result.suppression = VM.signed32(suppression+1) if (entry_flags&1) != 0 else suppression
	result.reset_pending = false
	return result
static func pre_input(forced: int, lock: int, suppression: int, primary: int, secondary: int) -> Dictionary:
	# 0x80043204..0x800432ec precedes pad-mode selection.
	var result := {"forced":forced,"lock":lock,"suppression":suppression,"primary":primary,"secondary":secondary,"mode":null,"forward":0,"bypass":false}
	if forced != 0:
		result.bypass = true
		if forced == 1:
			result.rise_remaining = 3600
			result.vertical_speed = 261
			result.primary = VM.signed32((primary&~0x400)|0x200)
			result.secondary = secondary&~2
		if ((forced-9)&0xffffffff) < 26:
			result.forward = 35
		result.forced = VM.signed32(forced+1)
		if (int(result.secondary)&2) != 0:
			result.forced = 0
	elif lock != 0:
		result.lock = VM.signed32(lock-1)
		result.mode = 1
		result.forward = 35
		result.bypass = true
		if result.lock == 0:
			result.suppression = VM.signed32(suppression-1)
	elif suppression != 0:
		result.mode = 0
		result.bypass = true
	return result
static func slide_heading(yaw: int, target: int, rate: int) -> Dictionary:
	# 0x80044014..0x80044100 uses a signed 12-bit delta and halfword history.
	var delta := ((target-yaw)&4095)
	if delta >= 2048:
		delta -= 4096
	if absi(delta) < 3:
		return {"yaw":target&4095,"rate":0}
	rate = halfword(rate+(delta>>6))
	rate = halfword(rate+(1 if delta > 0 else -1))
	if delta > 0:
		if rate > (delta>>3):
			rate = halfword(delta>>3)
		if rate > delta:
			rate = halfword(delta)
	else:
		if rate < (delta>>3):
			rate = halfword(delta>>3)
		if rate < delta:
			rate = halfword(delta)
	return {"yaw":(yaw+rate)&4095,"rate":rate}

static func halfword(value: int) -> int:
	return ((value&65535)^32768)-32768
static func begin_slide_state(mode: int, timer: int, grounded: bool) -> Dictionary:
	# 0x80043aa0..0x80043ae8 expires airborne slide history one call after zero.
	if not grounded and mode in [4,5]:
		if timer != 0:
			timer = VM.signed32(timer-1)
		else:
			mode = 0
	return {"mode":mode,"timer":timer}

static func finish_slide_state(mode: int, timer: int, grounded: bool, surface_type: int, has_input: bool, slope: Dictionary) -> Dictionary:
	var result := {"mode":mode,"timer":timer,"reset_yaw_rate":false}
	if mode in [4,5]:
		if grounded and not bool(slope.first):
			if timer != 0:
				result.timer = VM.signed32(timer-1)
			else:
				result.mode = 0
	elif grounded and (surface_type&255) != 14 and bool(slope.second if has_input else slope.first):
		result.mode = 5 if (surface_type&255) == 8 else 4
		if result.mode == 5:
			result.timer = 20
		result.reset_yaw_rate = true
	return result
static func slide_target(forward: int, side: int, actor_yaw: int, gradient: Dictionary, quarter: Array, angles: Array) -> Dictionary:
	if quarter.size() != 1025 or not gradient.has("x") or not gradient.has("z") or not gradient.has("yaw"):
		return {"fault":"Missing PlayerMove slide data"}
	var gx := int(gradient.x)
	var gz := int(gradient.z)
	var yaw := int(gradient.yaw)
	var sine := Collision.sine(yaw,quarter)
	var cosine := Collision.sine(yaw+1024,quarter)
	var drift_x := VM.signed32(VM.signed32(gz*sine)+VM.signed32(gx*cosine))
	var drift_z := VM.signed32(VM.signed32(gz*cosine)-VM.signed32(gx*sine))
	drift_x = VM.signed32((drift_x>>4)+(drift_x>>8))
	drift_z = VM.signed32((drift_z>>4)+(drift_z>>8))
	var target := Vector2i.ZERO
	if gx != 0 or gz != 0:
		var heading := Collision.wall_normal_angle(Vector2i(gx,gz),angles)
		if heading.has("fault"):
			return heading
		var slide_yaw := (yaw-int(heading.angle)+2048)&4095
		var scaled := VM.signed32(forward<<12)
		target.x = VM.signed32((VM.signed32(Collision.sine(slide_yaw,quarter)*scaled)>>12)+VM.signed32(Collision.sine(actor_yaw+1024,quarter)*side))
		target.y = VM.signed32((VM.signed32(Collision.sine(slide_yaw+1024,quarter)*scaled)>>12)-VM.signed32(Collision.sine(actor_yaw,quarter)*side))
	target.x = VM.signed32(target.x-drift_x)
	target.y = VM.signed32(target.y-drift_z)
	return {"target":target,"square":VM.signed32(VM.signed32(target.x*target.x)+VM.signed32(target.y*target.y))}
static func digital_input(buttons: int, mode: int, counter: int, ground_mode: int, secondary: int) -> Dictionary:
	# 0x80043618..0x8004384c; buttons are the processed input word, not AVar13.
	var slow := (ground_mode&255) == 15 or ((ground_mode&255) == 1 and (secondary&2) != 0)
	var direction := 0
	if mode != 5:
		if (secondary&2) != 0 and mode != 4:
			if (buttons&0x80) != 0 and mode != 0:
				direction = 3
			if (buttons&0x100) != 0 and mode != 0:
				direction = -3
		else:
			if (buttons&4) != 0:
				direction = 2
			if (buttons&8) != 0:
				direction = -2
	var forward := 0
	var speed := 140
	if mode not in [4,5]:
		if (buttons&1) != 0:
			if counter == 5:
				mode = 2
			else:
				mode = 1
				counter = VM.signed32(counter+1)
			forward = 4 if slow else 35
			speed = 128 if slow else 140
		else:
			counter = 0
			if (buttons&2) != 0:
				mode = 3
				forward = -2 if slow else -15
			else:
				mode = 0
	elif mode == 4:
		forward = 2 if (buttons&1) != 0 else -4 if (buttons&2) != 0 else 0
	var side := (2 if slow else 12) if absi(direction) == 3 else (4 if slow else 17) if absi(direction) == 2 else 0
	if direction < 0:
		side = -side
	return {"mode":mode,"counter":counter,"forward":forward,"side":side,"shift":5 if slow else 2,"speed":speed}
static func movement_target(forward: int, side: int, yaw: int, quarter: Array, gradient: Dictionary = {}) -> Dictionary:
	if quarter.size() != 1025:
		return {"fault":"Missing PlayerMove trigonometry"}
	var sine := Collision.sine(yaw,quarter)
	var cosine := Collision.sine(yaw+1024,quarter)
	var target := Vector2i.ZERO
	var adjustment := 0
	if gradient.is_empty():
		# Flat/airborne branch 0x80043ef4..0x80043f58.
		target.x = VM.signed32(VM.signed32(sine*forward)+VM.signed32(cosine*side))
		target.y = VM.signed32(VM.signed32(cosine*forward)-VM.signed32(sine*side))
	else:
		if not gradient.has("x") or not gradient.has("z") or not gradient.has("yaw"):
			return {"fault":"Incomplete PlayerMove slope gradient"}
		# Slope branch 0x80043df0..0x80043ec0 keeps each low CPU product.
		var delta := int(gradient.yaw)-yaw
		var projection := VM.signed32(VM.signed32(int(gradient.z)*Collision.sine(delta+1024,quarter))-VM.signed32(int(gradient.x)*Collision.sine(delta,quarter)))
		adjustment = VM.signed32((projection>>4)+(projection>>5))
		var scaled_forward := VM.signed32(VM.signed32(forward<<12)-(adjustment>>1 if adjustment < 0 else adjustment))
		target.x = VM.signed32((VM.signed32(sine*scaled_forward)>>12)+VM.signed32(cosine*side))
		target.y = VM.signed32((VM.signed32(cosine*scaled_forward)>>12)-VM.signed32(sine*side))
	return {"target":target,"adjustment":adjustment}
static func final_position(position: Vector3i, motion: Vector2i, roots: Array) -> Dictionary:
	# 0x80044104..0x80044170 measures history then commits X/Z only.
	if roots.size() != 192:
		return {"fault":"Missing PlayerMove root table"}
	var x := VM.signed32(motion.x)>>6
	var z := VM.signed32(motion.y)>>6
	var square := VM.signed32(VM.signed32(x*x)+VM.signed32(z*z))
	if square < 0:
		return {"fault":"Unresolved negative PlayerMove root input"}
	var magnitude := Collision.distance_root(square,roots)>>12
	return {"position":Vector3i(VM.signed32(position.x+(VM.signed32(motion.x)>>12)),position.y,VM.signed32(position.z+(VM.signed32(motion.y)>>12))),"magnitude":magnitude}
static func restrict_wall_axes(status: int, forward: int, side: int) -> Vector2i:
	# 0x80043854..0x800438d8 uses the low contact halfword and signed axes.
	forward = VM.signed32(forward)
	side = VM.signed32(side)
	if (status&1) != 0 and forward > 0:
		forward = 0
	if (status&2) != 0 and forward < 0:
		forward = 0
	if (status&4) != 0 and side > 0:
		side = 0
	if (status&8) != 0 and side < 0:
		side = 0
	return Vector2i(forward,side)

static func accumulate_motion(previous: Vector2i, target: Vector2i, shift: int) -> Vector2i:
	# 0x80043fb8..0x80043fe8: target - arithmetic-shifted history + history.
	var result := Vector2i.ZERO
	for axis in range(2):
		var old := VM.signed32(previous[axis])
		result[axis] = VM.signed32(VM.signed32(target[axis]-(old>>(shift&31)))+old)
	return result
static func gradient_state(ground_mode: int, x: int, z: int) -> Dictionary:
	# CPU products/sum 0x80043aec..0x80043b14 wrap before signed comparisons.
	var square := VM.signed32(VM.signed32(x*x)+VM.signed32(z*z))
	var mode := ground_mode & 255
	var first := ((mode in [1,15] and square > 4096) or (mode == 8 and square > 16384) or square > 65536)
	var second := first and ((mode == 1 and square > 16384) or (mode == 15 and square > 4096) or (mode == 8 and square > 32768) or square > 131072)
	return {"square":square,"first":first,"second":second}
