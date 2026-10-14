extends RefCounted
static func root_action(selected: int, pressed: int) -> Dictionary:
	if selected < 0 or selected > 3: return {"fault":"Invalid original Options root selection"}
	var result := {"page":1,"selected":selected,"last_index":3,"exit_requested":(pressed&0x100000)!=0,"reset_menu":false,"retain_effects":(pressed&0x100000)!=0}
	# Native4b33c..4b424 independently processes confirmation after cancel.
	if (pressed&0x800000) == 0: return result
	if selected == 3:
		result.exit_requested = true;result.retain_effects = true
		return result
	var page: int = [2,3,4][selected]
	result.page = page
	result.selected = page # Native4b400 selects each submenu's final Back row.
	result.last_index = page
	result.reset_menu = true
	if selected == 1: result.music_player_available = false
	return result

static func misc_action(selected: int, pressed: int) -> Dictionary:
	if selected < 0 or selected > 4: return {"fault":"Invalid original miscellaneous option"}
	var result := {"page":4,"selected":selected,"last_index":4,"action":"none","reset_notice_ticks":0}
	# Native4bdf4 cancels before independently processing confirmation.
	if (pressed&0x100000) != 0:
		result.page = 1;result.selected = 2;result.last_index = 3;result.action = "back"
	if (pressed&0x800000) == 0: return result
	match int(result.selected):
		0: result.action = "delete_saved_game"
		1: result.action = "write_options"
		2: result.action = "reset_defaults";result.reset_notice_ticks = 30
		3: result.action = "center_screen";result.page = 7
		4: result.action = "back";result.page = 1;result.selected = 2;result.last_index = 3
	return result

static func controller_action(selected: int, scheme: int, pad_kind: int, pressed: int) -> Dictionary:
	if selected < 0 or selected > 2 or scheme not in [0,1,2]:
		return {"fault":"Invalid original controller option"}
	var result := {"page":2,"selected":selected,"last_index":2,"scheme":scheme,"action":"none"}
	if (pressed&0x100000) != 0:
		result.page = 1;result.selected = 0;result.last_index = 3;result.action = "back"
	# Native4baf8..4bba0: the scheme row processes right before left.
	if int(result.selected) == 1:
		if (pressed&0x80000) != 0: result.scheme = (int(result.scheme)+1)%3
		if (pressed&0x20000) != 0: result.scheme = (int(result.scheme)+2)%3
	if (pressed&0x800000) == 0 or int(result.selected) == 1: return result
	if int(result.selected) == 0:
		result.action = "calibrate" if pad_kind == 2 else "controller_error_sound"
		if pad_kind == 2: result.page = 6;result.calibration_counter = 0
	else:
		result.action = "back";result.page = 1;result.selected = 0;result.last_index = 3
	return result
