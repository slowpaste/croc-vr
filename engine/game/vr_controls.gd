extends RefCounted
# VR adaptation around the original movement/animation controller.
var layout := "modern"
var haptics_enabled := true
var turn_mode := "snap"
var snap_degrees := 30
var smooth_degrees_per_second := 90.0
var foveation_level := 0
var foveation_debug := false
var jump_camera := "steady"
var camera_tilt := 0.0
var opposite_cone_degrees := 30.0
var reversal_window_seconds := 0.3
var last_direction := Vector2.ZERO
var last_direction_time := -1.0
var last_reversal_time := -1.0
var snap_armed := true
var turn_requires_neutral := false
var natural_step := false

static func collision_fade(level: float, overlapping: bool, delta: float) -> float:
	return 255.0 if overlapping else maxf(0.0,level-1020.0*delta) # 250ms recovery.

func reset_gestures() -> void:
	natural_step = false
	last_direction = Vector2.ZERO
	last_direction_time = -1.0
	last_reversal_time = -1.0
	snap_armed = false
	turn_requires_neutral = true

func reversal(stick: Vector2, now: float) -> bool:
	if stick.length() < 0.75:
		return false
	var direction := stick.normalized()
	var reverse := last_direction_time >= 0.0 and now-last_direction_time <= reversal_window_seconds and direction.dot(last_direction) <= -cos(deg_to_rad(opposite_cone_degrees)) and (last_reversal_time < 0.0 or now-last_reversal_time > reversal_window_seconds)
	last_direction = direction
	last_direction_time = now
	if reverse:
		last_reversal_time = now
	return reverse

func turn_delta(axis: float, delta: float) -> float:
	if absf(axis) < 0.25:
		snap_armed = true
		turn_requires_neutral = false
	if turn_requires_neutral:
		return 0.0
	if turn_mode == "smooth":
		return -axis*deg_to_rad(smooth_degrees_per_second)*delta if absf(axis) > 0.25 else 0.0
	if absf(axis) > 0.7 and snap_armed:
		snap_armed = false
		return -signf(axis)*deg_to_rad(snap_degrees)
	return 0.0

func analog_input(stick: Vector2, view_forward: Vector3) -> Dictionary:
	var forward := Vector3(view_forward.x,0,view_forward.z).normalized()
	if forward.length_squared() < 0.5:
		forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var desired := right*stick.x-forward*stick.y
	var heading := posmod(roundi(atan2(desired.x,desired.z)*4096.0/TAU),4096)
	# Native analog controller thresholds/magnitude scale; absolute heading uses camera0.
	return {"modern":true,"pad_mode":2,"magnitude":roundi(minf(stick.length(),1.0)*127.0),"idle_threshold":16,"run_threshold":90,"camera_yaw":0,"stick_yaw":heading}

func resolve_motion(input: Dictionary, facing: int, grounded: bool) -> Dictionary:
	var result := input.duplicate(true)
	var angle := float(((int(input.stick_yaw)-facing+2048)&4095)-2048)*TAU/4096.0
	var forward := cos(angle)
	var side := sin(angle)
	var magnitude := int(input.magnitude)
	# A gentle request keeps facing for small, deliberate footwork. A stronger
	# request commits the body to travel; separate enter/exit bands prevent chatter.
	if not grounded or magnitude <= int(input.idle_threshold) or bool(input.get("traversal",false)) or bool(input.get("turn_only",false)):
		natural_step = false
	elif bool(input.get("precision",false)):
		natural_step = false # Explicit override retains its facing-relative axes.
	else:
		var threshold := 62 if natural_step else 50
		natural_step = magnitude < threshold and (forward < -0.35 or absf(side)>0.65)
	result.natural_step = natural_step
	result.local_forward = forward
	result.local_side = side
	result.turn_step = grounded and not natural_step and magnitude >= 50 and magnitude < 90 and absf(angle)>PI/3.0 and not bool(input.get("precision",false)) and not bool(input.get("turn_only",false)) and not bool(input.get("traversal",false))
	return result

static func responsive_turn(yaw: int, input: Dictionary, suppression: int, mode: int) -> Dictionary:
	if bool(input.get("traversal",false)):
		return {"yaw":yaw,"history":0}
	if suppression == 0 and mode not in [4,5] and bool(input.get("turn_only",false)):
		var rate := roundi(-float(input.get("turn_axis",0.0))*128.0)
		return {"yaw":(yaw+rate)&4095,"history":rate<<16}
	if suppression != 0 or mode in [4,5] or bool(input.get("natural_step",false)) or bool(input.get("precision",false)) or int(input.get("magnitude",0)) <= int(input.get("idle_threshold",16)):
		return {"yaw":yaw,"history":0}
	var difference := ((int(input.stick_yaw)-yaw+2048)&4095)-2048
	var commitment := smoothstep(50.0,100.0,float(input.magnitude))
	var limit := roundi(lerpf(96.0,384.0,commitment))
	var rate := clampi(difference,-limit,limit)
	return {"yaw":(yaw+rate)&4095,"history":rate<<16}

func animation_buttons(buttons: int, pad_mode: int, movement_mode: int, secondary: int, turn_history: int, traversal_mode: int = 0, surface_axes: Vector2 = Vector2.ZERO) -> int:
	if layout == "modern" and pad_mode == 2 and traversal_mode in [7,11]:
		return (buttons & ~15)|preload("res://modern_traversal.gd").animation_button(traversal_mode,surface_axes)
	# The original idle-animation branch tests digital left/right, even when
	# PlayerTurn is driven by analog heading. Supply only the animation query;
	# locomotion and pressed/released button edges keep their original masks.
	if layout != "modern" or pad_mode != 2 or movement_mode != 0 or (secondary & 2) == 0:
		return buttons
	var rate := (turn_history >> 16) & 65535
	if rate >= 32768:
		rate -= 65536
	return buttons | (4 if rate > 0 else 8 if rate < 0 else 0)

func save_settings(path: String = "user://vr-controls.cfg") -> Error:
	var file := ConfigFile.new()
	file.set_value("controls","layout",layout)
	file.set_value("controls","haptics_enabled",haptics_enabled)
	file.set_value("comfort","turn_mode",turn_mode)
	file.set_value("comfort","snap_degrees",snap_degrees)
	file.set_value("comfort","smooth_speed",smooth_degrees_per_second)
	file.set_value("comfort","jump_camera",jump_camera)
	file.set_value("comfort","camera_tilt",camera_tilt)
	file.set_value("rendering","foveation_level",foveation_level)
	file.set_value("rendering","foveation_debug",foveation_debug)
	return file.save(path)

func load_settings(path: String = "user://vr-controls.cfg") -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	layout = "classic" if file.get_value("controls","layout","modern") == "classic" else "modern"
	haptics_enabled=bool(file.get_value("controls","haptics_enabled",true))
	turn_mode = "smooth" if file.get_value("comfort","turn_mode","snap") == "smooth" else "snap"
	var angle := int(file.get_value("comfort","snap_degrees",30))
	snap_degrees = angle if angle in [15,30,45,90] else 30
	smooth_degrees_per_second = clampf(float(file.get_value("comfort","smooth_speed",90.0)),30.0,180.0)
	jump_camera="follow" if file.get_value("comfort","jump_camera","steady")=="follow" else "steady"
	camera_tilt=clampf(float(file.get_value("comfort","camera_tilt",0.0)),-0.35,0.55)
	foveation_level = clampi(int(file.get_value("rendering","foveation_level",0)),0,3)
	foveation_debug = bool(file.get_value("rendering","foveation_debug",false))
