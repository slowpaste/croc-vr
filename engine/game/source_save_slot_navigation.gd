extends RefCounted
# Original4f3e8..4f548: edge-triggered left then right, clamped list.
# Mode0 Load,1 Save,2 Delete. Save may append one new-file entry.
static func advance(selected: int, count: int, mode: int, new_entry: int, card_state: int, pressed: int) -> Dictionary:
	if count<0 or count>15 or mode not in [0,1,2] or new_entry not in [0,1] or selected<0:
		return {"fault":"Invalid original save-slot navigation state"}
	var last := count+new_entry-1 if mode==1 else count-1
	if selected>maxi(last,0):return {"fault":"Save-slot selection outside directory"}
	var sounds := []
	if mode==2 and card_state==2:return {"selected":selected,"sounds":sounds}
	if (pressed&0x20000)!=0:
		if selected!=0:selected-=1;sounds.append("SELECT")
		else:sounds.append("BON_BEEP")
	if (pressed&0x80000)!=0:
		if (mode==1 and selected!=last) or (mode!=1 and count!=0 and selected!=last):
			selected+=1;sounds.append("SELECT")
		else:sounds.append("BON_BEEP")
	return {"selected":selected,"sounds":sounds}
