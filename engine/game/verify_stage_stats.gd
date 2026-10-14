extends SceneTree
const Stats = preload("res://source_stage_stats.gd")
func _initialize() -> void:
	var dimmed := Stats.initialize(0,0,0,0,3,[0,0,0,0,0,0,0,0])
	dimmed.phase = 255
	if Stats.backdrop_level(dimmed) != 255: quit(1); return
	dimmed.phase = 31
	dimmed = Stats.advance(dimmed,0,0)
	if dimmed.phase != 32 or Stats.backdrop_level(dimmed) != 31: push_error("Results backdrop used updated phase instead of source draw phase"); quit(1); return
	dimmed.secret = 1
	if Stats.backdrop_level(dimmed) != 0: quit(1); return
	if Stats.shared_texture_name(1) != "TK01_ENM.BIN" or Stats.shared_texture_name(13) != "TK13_ENM.BIN" or Stats.shared_texture_name(65537) != "TK01_ENM.BIN": quit(1); return
	var normal_icons := Stats.icon_layout({"kind":0})
	var boss_icons := Stats.icon_layout({"kind":1})
	var secret_icons := Stats.icon_layout({"kind":2})
	if normal_icons.track.labels[0].glyphs.size() != 3 or normal_icons.track.labels[0].glyphs[0].sprite != 11 or normal_icons.track.labels[0].glyphs[0].size != Vector2(61,24): quit(1); return
	if boss_icons.shared.labels[0].glyphs[0].sprite != 26 or boss_icons.shared.labels[0].glyphs[0].position != Vector2(60,120) or boss_icons.shared.labels[0].glyphs[0].size != Vector2(50,24): quit(1); return
	if secret_icons.track.labels[0].glyphs.size() != 2 or not secret_icons.shared.labels[0].glyphs.is_empty(): quit(1); return
	if normal_icons.track.labels[0].glyphs[1].sprite != 12 or normal_icons.track.labels[0].glyphs[1].position != Vector2(200,117) or normal_icons.track.labels[0].glyphs[2].sprite != 10 or normal_icons.track.labels[0].glyphs[2].position != Vector2(350,115): quit(1); return
	for fixture in [[0,[0],[235]],[9,[9],[235]],[10,[1,0],[235,253]],[99,[9,9],[235,253]],[100,[1,0,0],[235,253,271]]]:
		var quads := Stats.number_quads({"kind":2,"shown_bank":fixture[0],"shown_lives":10})
		for digit in range(fixture[1].size()):
			if quads[digit].digit != fixture[1][digit] or quads[digit].x != fixture[2][digit] or quads[digit].y != 136:
				push_error("Original results bank digit placement differs")
				quit(1)
				return
		if quads[-2].digit != 1 or quads[-2].x != 332 or quads[-1].digit != 0 or quads[-1].x != 350: quit(1); return
	var normal := Stats.number_quads({"kind":0,"shown_rescues":6,"shown_bank":0,"shown_lives":9})
	var boss := Stats.number_quads({"kind":1,"pickup_count":8,"shown_bank":0,"shown_lives":9})
	if normal[0].digit != 6 or normal[0].x != 100 or boss[0].digit != 8 or normal[-1].digit != 9 or normal[-1].x != 350: quit(1); return
	var state := Stats.initialize(0,75,6,40,3,[0,1,0,-1,0,0,0,1])
	if state.bank != 15 or state.lives != 4 or state.shown_bank != 40 or state.shown_crystals != 75 or state.shown_rescues != 6 or state.shown_lives != 2 or state.delay != 30 or state.pickup_count != 3 or state.kind != 0:
		quit(1)
		return
	if Stats.initialize(3,250,0,99,98,[0,0,0,0,0,0,0,0]).lives != 99 or Stats.initialize(4,0,0,0,0,[0,0,0,0,0,0,0,0]).kind != 1 or Stats.initialize(8,0,0,0,0,[0,0,0,0,0,0,0,0]).kind != 2 or Stats.initialize(40,0,0,0,0,[0,0,0,0,0,0,0,0]).kind != 3:
		quit(1)
		return
	if not Stats.initialize(0,0,0,0,3,[]).has("fault"):
		quit(1)
		return
	state = Stats.initialize(0,2,6,99,3,[0,0,0,0,0,0,0,0])
	for tick in range(30):
		state = Stats.advance(state,0,2)
	if state.shown_crystals != 2 or state.delay != 0:
		quit(1)
		return
	state = Stats.advance(state,0,2)
	if state.shown_crystals != 1 or state.shown_bank != 0 or state.shown_lives != 3 or state.current_crystals != 1 or state.events != ["life","crystal"]:
		push_error("Source stat transfer/award timing differs")
		quit(1)
		return
	state = Stats.advance(state,0x200,1)
	if state.busy != 1 or state.shown_crystals != 0 or state.current_crystals != 0 or state.shown_bank != 1 or state.events != ["confirm"]:
		quit(1)
		return
	state = Stats.advance(state,0x200,0)
	if not state.events.is_empty():
		quit(1)
		return
	print("PASS: source stats capture, count-up delay, crystal transfers, life awards and confirmation")
	quit(0)
