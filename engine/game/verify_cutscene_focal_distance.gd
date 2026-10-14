extends SceneTree
func _initialize() -> void:
	var frame = preload("res://source_cutscene_frame.gd")
	# Independently observed original intro CP2 registers at three captures.
	var result: Dictionary = frame.projection(320)
	assert(result.h == 480 and result.offset == Vector2i(16777216,12582912))
	assert(frame.projection(256).h == 384)
	assert(frame.projection(65536+320).h == 480)
	assert(frame.display_y(192) == 120 and frame.display_y(384) == 240)
	assert(frame.display_y(7) == 3 and frame.display_y(-1) == -2)
	assert(frame.display_y(65535) == -2)
	print("PASS: original geometry-height projection matches captured intro H/OFX/OFY and camera-halfword conversion")
	quit(0)
