extends RefCounted
const Menu=preload("res://source_main_menu.gd")
static func initialize(slots: Array) -> Dictionary:
	if slots.size()>15:return {"fault":"Load directory exceeds original card capacity"}
	return {"slots":slots.duplicate(true),"slot":0,"navigation":Menu.initialize(0,1),"exit_requested":false,"pending_path":"","sounds":[]}
static func advance(state: Dictionary, held: int, pressed: int) -> Dictionary:
	if not state.has_all(["slots","slot","navigation","exit_requested","pending_path"]):return {"fault":"Missing Load session state"}
	if bool(state.exit_requested) or not str(state.pending_path).is_empty():return state.duplicate(true)
	var next := state.duplicate(true);next.sounds=[]
	next.navigation=Menu.advance(next.navigation,held,pressed)
	# Triangle cancels the screen before the deferred load can run.
	if (pressed&0x100000)!=0:next.exit_requested=true;next.sounds.append("START");return next
	var moved := preload("res://source_save_slot_navigation.gd").advance(int(next.slot),next.slots.size(),0,0,0,pressed)
	if moved.has("fault"):return moved
	next.slot=int(moved.selected);next.sounds.append_array(moved.sounds)
	if (pressed&0x800000)==0:return next
	if int(next.navigation.selected)!=0:
		next.exit_requested=true;next.sounds.append("START");return next
	if next.slots.is_empty() or next.slots[next.slot].has("fault"):
		next.sounds.append("BON_BEEP");return next
	if not next.slots[next.slot].has("path"):return {"fault":"Missing selected saved-record path"}
	next.pending_path=str(next.slots[next.slot].path);next.sounds.append("START")
	return next
