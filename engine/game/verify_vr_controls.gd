extends SceneTree
const Controls = preload("res://vr_controls.gd")
func _initialize() -> void:
	var c = Controls.new()
	if c.layout != "modern" or c.turn_mode != "snap":
		quit(1)
		return
	var facing := Vector3(1,0,0)
	if c.analog_input(Vector2(0,-1),facing).stick_yaw != 1024 or c.analog_input(Vector2(1,0),facing).stick_yaw != 0:
		push_error("Modern view-relative heading differs")
		quit(1)
		return
	if c.reversal(Vector2.RIGHT,0.0) or not c.reversal(Vector2.LEFT,0.1) or c.reversal(Vector2.LEFT,0.2):
		quit(1)
		return
	c.reset_gestures()
	c.reversal(Vector2.RIGHT,1.0)
	if c.reversal(Vector2.UP,1.1) or c.reversal(Vector2.DOWN,1.6):
		push_error("Quick-turn gesture accepted a quarter turn or expired gesture")
		quit(1)
		return
	c.turn_delta(0.0,0.1)
	c.snap_armed = true
	if not is_equal_approx(c.turn_delta(1.0,0.1),-PI/6.0) or c.turn_delta(1.0,0.1) != 0:
		quit(1)
		return
	c.turn_delta(0,0.1)
	c.snap_degrees = 45
	if not is_equal_approx(c.turn_delta(-1,0.1),PI/4.0):
		quit(1)
		return
	c.turn_mode = "smooth"
	if not is_equal_approx(c.turn_delta(1,0.1),-PI/20.0):
		quit(1)
		return
	c.reset_gestures()
	if c.turn_delta(1,0.1) != 0.0:
		push_error("Held smooth-turn input moved the camera after baseline reset")
		quit(1)
		return
	c.turn_delta(0,0.1)
	if not is_equal_approx(c.turn_delta(1,0.1),-PI/20.0):
		quit(1)
		return
	print("PASS: modern view-relative direction, quick-turn cone/window and snap/smooth turn")
	quit(0)
