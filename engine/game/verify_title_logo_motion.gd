extends SceneTree
const Logo = preload("res://source_title_logo.gd")
func _initialize() -> void:
	var original := Logo.initialize()
	var state := Logo.advance(original)
	if original.positions[0].z != 0 or state.positions != [Vector3i(0,-175,112),Vector3i(0,-175,112)] or state.angles != [Vector3i(0,2048,0),Vector3i(0,2048,0)]:
		quit(1)
		return
	for tick in range(29):
		state = Logo.advance(state)
	if state.positions[0].z != 1533:
		quit(1)
		return
	for tick in range(29):
		state = Logo.advance(state)
	if state.positions[0].z != 1800 or state.positions[1].z != 1800:
		quit(1)
		return
	state.positions[0].z = 1797
	state = Logo.advance(state)
	if state.positions[0].z != 1805:
		quit(1)
		return
	state = Logo.advance(state)
	if state.positions[0].z != 1800:
		quit(1)
		return
	print("PASS: both original logo transforms, eased approach, minimum step, overshoot and next-update clamp")
	quit(0)
