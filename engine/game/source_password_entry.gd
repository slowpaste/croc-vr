extends RefCounted
# Input52568..5277c and trailing5316c:15 symbols, validation on the next tick.
static func initialize() -> Dictionary:
	var symbols: Array = []; symbols.resize(16); symbols.fill(0)
	return {"symbols":symbols,"count":0,"return_requested":false,"return_flag":0,"events":[],"needs_validation":false}
static func advance(state: Dictionary, pressed: int) -> Dictionary:
	if not state.has_all(["symbols","count"]) or state.symbols.size() != 16:
		return {"fault":"Invalid original password-entry buffer"}
	var result := state.duplicate(true)
	result.events = []
	var count := int(result.count)
	if count < 0 or count > 16: return {"fault":"Invalid original password-entry count"}
	if count < 16 and pressed != 0:
		if pressed & 0x100200:
			result.return_requested = true
			result.return_flag = 1
			result.events.append({"sound_handle":20264,"volume":80,"pitch":24})
		elif pressed & 0x800000:
			if count > 0:
				count -= 1
				result.symbols[count] = 0
				result.events.append({"sound_handle":20436,"volume":80,"pitch":24})
			else: result.events.append({"sound_handle":20432,"volume":15,"pitch":0})
		else:
			var symbol := 1 if pressed & 0x10000 else 2 if pressed & 0x80000 else 3 if pressed & 0x40000 else 4 if pressed & 0x20000 else 0
			if symbol != 0:
				result.symbols[count] = symbol
				count += 1
				result.events.append({"sound_handle":20436,"volume":80,"pitch":24})
	result.needs_validation = count == 16 and not bool(result.return_requested)
	result.count = 16 if count == 15 else count
	return result
