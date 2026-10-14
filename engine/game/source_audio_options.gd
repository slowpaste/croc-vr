extends RefCounted
# Original4c7fc..4ca0c processes left before right. Volume helpers515b4
# and2ef38 clamp to0..127; the left branch also rounds119 to120 and
# snaps values below7 to zero. Audio modes cycle through0,1,2.
static func advance(state: Dictionary, selected: int, pressed: int) -> Dictionary:
	if not state.has_all(["music","effects","mode"]): return {"fault":"Missing original audio options"}
	if selected < 0 or selected > 4: return {"fault":"Invalid original audio option selection"}
	var next := state.duplicate(true)
	if int(next.music) < 0 or int(next.music) > 127 or int(next.effects) < 0 or int(next.effects) > 127 or int(next.mode) not in [0,1,2]:
		return {"fault":"Invalid original audio option value"}
	next.changed = false
	next.volume_updates = []
	if selected >= 3: return next
	for direction in [-1,1]:
		var mask := 0x20000 if direction < 0 else 0x80000
		if (pressed&mask) == 0: continue
		next.changed = true
		if selected == 2:
			next.mode = (int(next.mode)+direction+3)%3
			next.volume_updates.append({"kind":"mode","mode":int(next.mode)})
		else:
			var key := "music" if selected == 0 else "effects"
			var volume := clampi(int(next[key])+direction*8,0,127)
			# Record helper output before menu-only snapping. Native helper
			# publishes mix/fade values before119 is rounded to120 in the UI.
			next.volume_updates.append({"kind":key,"volume":volume})
			if direction < 0:
				if volume == 119: volume = 120
				if volume < 7: volume = 0
			next[key] = volume
			next.volume_updates[-1].option_volume = volume
		next.volume_updates[-1].preview_effects = int(next.effects)
		next.volume_updates[-1].preview_mode = int(next.mode)
	return next

static func page_action(selected: int, music_player_available: bool, pressed: int, last_index: int = -1) -> Dictionary:
	# Native4c79c..4c7f8: Select reveals the music-player row; an existing
	# Back selection moves down so it continues to mean Back.
	var last := (4 if music_player_available else 3) if last_index < 0 else last_index
	if selected < 0 or selected > last or last not in [3,4]:
		return {"fault":"Invalid original audio page selection"}
	var next_selected := selected
	var available := music_player_available
	if (pressed&0x400) != 0 and not available:
		if next_selected == 3: next_selected = 4
		available = true
		last = 4
	var action := "none"
	# Native4ca0c: Triangle returns to parent Options selection1, page1.
	if (pressed&0x100000) != 0:
		action = "back"
	elif (pressed&0x800000) != 0 and next_selected >= 3:
		action = "music_player" if next_selected == 3 and available else "back"
	return {"selected":next_selected,"music_player_available":available,"last_index":last,"action":action,"parent_page":1,"parent_selection":1,"parent_last_index":3}
