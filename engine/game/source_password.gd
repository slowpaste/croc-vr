extends RefCounted
# Native password generation, 0x8005216c..0x800524e4.
const COMPLETION_BITS := [0,1,18,9,11,2]
const SELECTION_BITS := [21,17,4,10,16,20]
const PICKUP_BITS := [19,8,22,13,5,15,12,6]
const SECRET_BITS := [14,7,24,25,26,27,28,29]
const MASKS := [0x45332bfc,0x23454338,0xfeffdb44,0xac432100]

static func encode(progress: Array, selected: int, pickups: Array) -> Dictionary:
	if progress.size() < 45 or pickups.size() != 8:
		return {"fault":"Password requires 45 progress flags and eight persistent pickup slots"}
	var highest := 0
	for index in range(45):
		if int(progress[index]) & 0x8000: highest = index
	var data := 0
	for bit in range(6):
		if highest & (1 << bit): data |= 1 << COMPLETION_BITS[bit]
		if selected & (1 << bit): data |= 1 << SELECTION_BITS[bit]
	for slot in range(8):
		if int(pickups[slot]) != 0: data |= 1 << PICKUP_BITS[slot]
		if int(progress[3+slot*5]) & 0x8000: data |= 1 << SECRET_BITS[slot]
	var count := 0
	for bit in range(30):
		if data & (1 << bit): count += 1
	data |= (count & 1) << 23
	data |= (count & 2) << 2
	var word: int = (data ^ int(MASKS[data & 3])) & 0xffffffff
	var symbols: Array = []
	for index in range(15): symbols.append(((word >> (index*2)) & 3)+1)
	return {"word":word,"data":data,"symbols":symbols,"highest_completed":highest}

static func display(encoded: Dictionary, alphabet: Array) -> Dictionary:
	if encoded.has("fault"): return encoded
	if alphabet.size() != 5: return {"fault":"Missing original password symbol alphabet"}
	var text := ""
	for symbol in encoded.symbols: text += String.chr(int(alphabet[int(symbol)]))
	return {"text":text,"y":140}
