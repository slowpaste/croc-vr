extends RefCounted
const Save=preload("res://source_save_session.gd")
const Menu=preload("res://source_main_menu.gd")
static func initialize(slots: Array) -> Dictionary:
	var state := Save.initialize(slots,"")
	if state.has("fault"):return state
	state.kind="delete";state.navigation=Menu.initialize(0 if slots.is_empty() else 1,0 if slots.is_empty() else 1)
	return state
static func advance(state: Dictionary, held: int, pressed: int) -> Dictionary:
	if state.slots.is_empty() and (pressed&0x900000)!=0:
		var next := state.duplicate(true);next.exit_requested=true;next.sounds=["START"];return next
	# Native Delete confirmation locks left/right slot movement.
	var next := Save.advance(state,held,pressed&(~0xa0000) if bool(state.overwrite) else pressed)
	if next.has("fault"):return next
	if bool(state.overwrite) and not bool(next.overwrite) and str(next.pending_path).is_empty():next.navigation=Menu.initialize(1,1)
	return next
