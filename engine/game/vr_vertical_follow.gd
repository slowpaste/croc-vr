extends RefCounted
const GROUND_DEADBAND := 0.08
const AIRBORNE_MARGIN := 2.0
const DROP_MARGIN := 0.75
const LANDING_SPEED := 8.0
const LANDING_ACCELERATION := 32.0
const MAX_SPEED := 24.0
const MAX_ACCELERATION := 80.0
static func initialize(height: float) -> Dictionary:
	return {"height":height,"velocity":0.0,"support_height":height,"player_height":height,"player_velocity":0.0,"sample_elapsed":0.0}
static func step(state: Dictionary, player_height: float, grounded: bool, delta: float) -> Dictionary:
	var next := state.duplicate()
	var dt := clampf(delta,0.0,0.05)
	if dt <= 0.0: return next
	var height := float(state.height)
	# Gameplay positions update at30Hz; headset frames can run much faster.
	# Measure across source samples and retain their velocity between frames.
	var elapsed := float(state.get("sample_elapsed",0.0))+dt
	var player_velocity := float(state.get("player_velocity",0.0))
	var change := player_height-float(state.get("player_height",player_height))
	if absf(change)>0.000001:
		player_velocity=clampf(change/elapsed,-MAX_SPEED,MAX_SPEED)
		elapsed=0.0
	elif grounded:
		player_velocity=0.0
	next.player_velocity=player_velocity
	next.sample_elapsed=minf(elapsed,0.25)
	next.player_height = player_height
	# Keep the latest landing as the target through the following jump.
	# Brief contacts on a staircase count; airborne jump arcs do not.
	if grounded and absf(player_height-float(next.support_height))>GROUND_DEADBAND:next.support_height=player_height
	var desired := float(next.support_height)
	var chasing := false
	if not grounded and player_height-desired>AIRBORNE_MARGIN:
		desired=player_height-AIRBORNE_MARGIN;chasing=true
	elif not grounded and desired-player_height>DROP_MARGIN:
		desired=player_height+DROP_MARGIN;chasing=true
	var error:=desired-height
	var rapid := chasing or absf(error)>2.0
	var speed := MAX_SPEED if rapid else LANDING_SPEED
	var acceleration := MAX_ACCELERATION if rapid else LANDING_ACCELERATION
	var requested := signf(error)*minf(speed,minf(absf(error)*10.0,sqrt(acceleration*absf(error))))
	if chasing: requested=clampf(requested+player_velocity,-speed,speed)
	next.velocity=move_toward(float(state.velocity),requested,acceleration*dt)
	next.height=height+float(next.velocity)*dt
	if (desired-height)*(desired-float(next.height))<=0.0:
		next.height=desired;next.velocity=0.0
	return next
