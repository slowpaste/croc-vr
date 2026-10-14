extends RefCounted
static func record_completion(selected_index: int, rescues: int, flags: Dictionary) -> Dictionary:
	# Source0x8002b300: unsigned maximum, halfword store and secret-entry redirect.
	var updated := flags.duplicate(true)
	var index := selected_index&0xffffffff
	var score := (rescues&0xffffffff)|(0xc000 if index == 40 else 0x8000)
	if index < 39 and index%10 in [3,8]:
		updated[index+1] = 0x8000
	elif index < 45:
		updated[index] = maxi(score,int(updated.get(index,0))&65535)&65535
	return updated
# Native491f8/49108: current island's two three-stage rescue aggregates.
static func update_unlocks(selected_index: int, flags: Dictionary) -> Dictionary:
	var updated := flags.duplicate(true)
	var first := 0
	var second := 0
	var island := int((selected_index&0xffffffff)/10)
	if island < 4:
		for base in [island*10,island*10+5]:
			if (int(updated.get(base+4,0))&0x8000) == 0:
				continue
			var total := 0
			for index in range(base,base+3):
				total += int(updated.get(index,0))&0x7fff
			updated[base+3] = 0x8000 if total == 18 else 0
			if total == 18:
				if base%10 == 0:
					first += 1
				else:
					second += 1
	return {"flags":updated,"first":first,"second":second,"bits":(1 if first != 0 else 0)|(2 if second != 0 else 0)}

# Selector entry0x80013540..0x8001369c; eight saved announcement bytes.
static func enter_selector(selected_index: int, flags: Dictionary, history: Array) -> Dictionary:
	if history.size() != 8:
		return {"fault":"Missing source secret-stage announcement history"}
	var unlocks := update_unlocks(selected_index,flags)
	var seen := history.duplicate()
	var selected := selected_index&0xffffffff
	var entry := int(selected/5)
	var modes := [0,0]
	for half in range(2):
		if (int(unlocks.bits)&(1<<half)) == 0:
			continue
		var matching_half := selected%10 < 5 if half == 0 else selected%10 >= 5
		if (int(seen[entry])&255) == 0 and matching_half:
			modes[half] = 1
			seen[entry] = (int(seen[entry])+1)&255
			selected = entry*5+4
		else:
			modes[half] = 2
	return {"flags":unlocks.flags,"history":seen,"selected_index":selected,"return_mode":modes[0],"secret_return":modes[1]}
