extends RefCounted
const Menu=preload("res://source_main_menu.gd")
static func initialize(slots: Array, new_path: String) -> Dictionary:
	if slots.size()>15 or (slots.size()==15 and not new_path.is_empty()):return {"fault":"Invalid original Save card capacity"}
	return {"kind":"save","slots":slots.duplicate(true),"new_path":new_path,"slot":0,"navigation":Menu.initialize(0,1),"overwrite":false,"exit_requested":false,"pending_path":"","sounds":[]}
static func advance(state: Dictionary, held: int, pressed: int) -> Dictionary:
	if not state.has_all(["slots","new_path","slot","navigation","overwrite","exit_requested","pending_path"]):return {"fault":"Missing Save session state"}
	if bool(state.exit_requested) or not str(state.pending_path).is_empty():return state.duplicate(true)
	var next := state.duplicate(true);next.sounds=[]
	next.navigation=Menu.advance(next.navigation,held,pressed)
	if (pressed&0x100000)!=0:
		next.sounds.append("START")
		if next.overwrite:next.overwrite=false;next.navigation=Menu.initialize(0,1)
		else:next.exit_requested=true
		return next
	var moved := preload("res://source_save_slot_navigation.gd").advance(int(next.slot),next.slots.size(),1,0 if str(next.new_path).is_empty() else 1,0,pressed)
	if moved.has("fault"):return moved
	next.slot=int(moved.selected);next.sounds.append_array(moved.sounds)
	if (pressed&0x800000)==0:return next
	next.sounds.append("START")
	if int(next.navigation.selected)!=0:
		if next.overwrite:next.overwrite=false;next.navigation=Menu.initialize(0,1)
		else:next.exit_requested=true
		return next
	if int(next.slot)>=next.slots.size():
		if str(next.new_path).is_empty():next.sounds.append("BON_BEEP")
		else:next.pending_path=str(next.new_path)
		return next
	if not next.slots[next.slot].has("path"):return {"fault":"Missing selected Save path"}
	if not bool(next.overwrite):next.overwrite=true;next.navigation=Menu.initialize(1,1);return next
	next.pending_path=str(next.slots[next.slot].path)
	return next
