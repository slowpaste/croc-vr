extends RefCounted
const COEFFICIENTS := [[0,0],[60,0],[115,-52],[98,-55]]
var history: Array = [[0,0],[0,0]]
func reset() -> void:
	history = [[0,0],[0,0]]
func decode(raw: PackedByteArray) -> Dictionary:
	if raw.size() != 2352 or raw[15] != 2 or raw[0] != 0 or raw[11] != 0:
		return {"fault":"Invalid original XA sector"}
	for index in range(1,11):
		if raw[index] != 255: return {"fault":"Invalid XA sync"}
	if raw.slice(16,20) != raw.slice(20,24) or (raw[18]&0x24) != 0x24:
		return {"fault":"Invalid XA audio subheader"}
	var coding := int(raw[19])
	if (coding&3) != 1 or ((coding>>2)&3) > 1 or ((coding>>4)&3) != 0 or (coding&128) != 0:
		return {"fault":"Unsupported native XA coding mode"}
	var pcm := PackedByteArray()
	pcm.resize(8064)
	for group in range(18):
		var at := 24+group*128
		if raw.slice(at,at+4) != raw.slice(at+4,at+8) or raw.slice(at+8,at+12) != raw.slice(at+12,at+16):
			return {"fault":"Invalid XA sound parameter copies"}
		for unit in range(8):
			var parameter := int(raw[at+4+unit])
			var filter := parameter>>4
			var shift := parameter&15
			if filter >= 4 or shift > 12: return {"fault":"Invalid XA predictor/range"}
			var channel := unit&1
			var previous := int(history[channel][0])
			var older := int(history[channel][1])
			var coefficient_0 := int(COEFFICIENTS[filter][0])
			var coefficient_1 := int(COEFFICIENTS[filter][1])
			var sample_shift := 12-shift
			var nibble_shift := channel*4
			var data_offset := at+16+(unit>>1)
			var output_offset := (group*112+(unit>>1)*28)*4+channel*2
			for sample in range(28):
				var packed := int(raw[data_offset+sample*4])
				var nibble := (packed>>nibble_shift)&15
				if nibble >= 8: nibble -= 16
				var value := clampi((nibble<<sample_shift)+((previous*coefficient_0+older*coefficient_1+32)>>6),-32768,32767)
				older = previous
				previous = value
				pcm.encode_s16(output_offset+sample*4,value)
			history[channel][0] = previous
			history[channel][1] = older
	return {"pcm":pcm,"frames":2016,"rate":18900 if (coding&4) != 0 else 37800,"emphasis":(coding&64) != 0}
