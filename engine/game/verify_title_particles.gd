extends SceneTree
const Particles = preload("res://source_title_particles.gd")
class FixedRandom:
	extends RefCounted
	var draws := 0
	func bios_rand() -> int:
		draws += 1
		return 0
func _initialize() -> void:
	var random_source := FixedRandom.new()
	var original := Particles.initialize()
	var state := Particles.advance(original,1288,random_source)
	if state.phase != 0 or random_source.draws != 0:
		quit(1)
		return
	state = Particles.advance(state,1289,random_source)
	if state.phase != 2 or state.allocated != 1 or random_source.draws != 3 or state.slots[0].x != 226 or state.slots[0].y != 132 or state.slots[0].sprite != 0 or original.phase != 0:
		quit(1)
		return
	if state.render_phase != 1 or state.central.size() != 1 or state.central[0].size != Vector2i(8,16) or state.central[0].source_u_span != 8:
		quit(1)
		return
	for tick in range(30):
		state = Particles.advance(state,1800,random_source)
	if state.phase != 32 or state.allocated != 30 or random_source.draws != 91:
		push_error("Source title particle capacity/phase/random consumption differs")
		quit(1)
		return
	state = Particles.advance(state,1800,random_source)
	if state.central.size() != 2 or state.central[0].size != Vector2i(128,16) or state.central[1].size != Vector2i(128,16) or state.central[1].position != Vector2i(338,130):
		push_error("Source title banner did not reach its original reveal extent")
		quit(1)
		return
	for tick in range(30):
		state = Particles.advance(state,1800,random_source)
	if state.slots.any(func(slot): return int(slot.active) != 0) or random_source.draws != 91:
		quit(1)
		return
	print("PASS: source title effect activation, phase limit, particle capacity, lifetime and random-call count")
	quit(0)
