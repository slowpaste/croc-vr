extends RefCounted
# Original 3b358..3b45c patches settings in a 256-byte campaign record.
# The last word is the modulo-2^32 sum of the preceding 63 words.
const SETTINGS_WORDS := [0,1,2,48,50,51,52,53,54,55,56,57]
const SETTINGS_KEYS := ["scheme","effects","music","mode","center_x","center_y","minimum_x","minimum_y","maximum_x","maximum_y","screen_x","screen_y"]

static func checksum(record: PackedByteArray) -> int:
	if record.size()!=256:return -1
	var sum := 0
	for word in range(63):sum=(sum+record.decode_u32(word*4))&0xffffffff
	return sum

static func valid(record: PackedByteArray) -> bool:
	return record.size()==256 and checksum(record)==record.decode_u32(252)

static func select_copy(copies: PackedByteArray) -> Dictionary:
	if copies.size()!=512:return {"fault":"Save requires two original 256-byte records"}
	for index in range(2):
		var record := copies.slice(index*256,(index+1)*256)
		if valid(record):return {"record":record,"copy":index}
	return {"fault":"Both save record checksums failed"}

static func patch_options(record: PackedByteArray, settings: Dictionary) -> Dictionary:
	if record.size()!=256:return {"fault":"Invalid original save record size"}
	for key in SETTINGS_KEYS:
		if not settings.has(key) or not settings[key] is int:return {"fault":"Missing integer save setting: "+key}
	var next := record.duplicate()
	for index in range(SETTINGS_WORDS.size()):
		var value := int(settings[SETTINGS_KEYS[index]])
		# Source music/effects globals are read with signed halfword loads.
		if index in [1,2]:value=((value&0xffff)^0x8000)-0x8000
		next.encode_u32(SETTINGS_WORDS[index]*4,value&0xffffffff)
	next.encode_u32(252,checksum(next))
	return {"record":next,"copies":next+next}

static func new_record() -> PackedByteArray:
	var record := PackedByteArray();record.resize(256)
	# Original new-file branch 3b258..3b290: stage10 and three lives.
	record.encode_u32(12,10);record.encode_u32(28,3)
	record.encode_u32(252,checksum(record))
	return record

static func options(record: PackedByteArray) -> Dictionary:
	if not valid(record):return {"fault":"Invalid settings record checksum"}
	var settings := {}
	for index in range(SETTINGS_WORDS.size()):
		var offset: int = SETTINGS_WORDS[index]*4
		# Native3acd0..3ade4 loads full words except two unsigned halfwords.
		settings[SETTINGS_KEYS[index]]=record.decode_u16(offset) if index in [1,2] else record.decode_s32(offset)
	return settings
