extends RefCounted
const Record=preload("res://source_save_record.gd")
# Source3a900..3aadc. Field16 is current room (gp1732/80074fa4),
# also assigned from the high half of ForceDoor's packed destination.
static func encode(prior: PackedByteArray, settings: Dictionary, state: Dictionary) -> Dictionary:
	if prior.size()!=256 or not state.has_all(["level","selection","room","lives","flags","pickups","announcement_history"]):return {"fault":"Missing original campaign save fields"}
	if state.flags.size()!=46 or state.pickups.size()!=8 or state.announcement_history.size()!=8:return {"fault":"Invalid original campaign array lengths"}
	var next := prior.duplicate()
	for index in range(46):
		if not state.flags[index] is int or int(state.flags[index])<0 or int(state.flags[index])>65535:return {"fault":"Invalid campaign flag halfword"}
		next.encode_u16(32+index*2,int(state.flags[index]))
	for key in ["level","selection","room","lives"]:
		if not state[key] is int:return {"fault":"Invalid campaign scalar"}
	next.encode_u32(12,int(state.level)&0xffffffff);next.encode_u32(16,int(state.room)&0xffffffff)
	next.encode_u32(28,int(state.lives)&0xffffffff);next.encode_u32(196,int(state.selection)&0xffffffff)
	var count := 0;var pickup_mask := 0
	for index in range(44):
		if int(state.flags[index])&0x8000:count+=2
	for index in range(8):
		if not state.pickups[index] is int or not state.announcement_history[index] is int or int(state.announcement_history[index])<0 or int(state.announcement_history[index])>255:return {"fault":"Invalid persistent campaign byte"}
		pickup_mask<<=1
		if int(state.pickups[index])!=0:pickup_mask|=1;count+=1
		next[232+index]=int(state.announcement_history[index])
	if int(state.flags[45])&0x8000:count+=4
	next.encode_u32(20,pickup_mask);next.encode_u32(24,count)
	return Record.patch_options(next,settings)

static func decode(record: PackedByteArray) -> Dictionary:
	if not Record.valid(record):return {"fault":"Invalid campaign checksum"}
	var flags := [];var pickups := [];var history := []
	for index in range(46):flags.append(record.decode_u16(32+index*2))
	var mask := record.decode_u32(20)
	# Native3ad3c..3ad78 restores original bit values, not normalized booleans.
	for index in range(8):pickups.append(mask&(0x80>>index));history.append(int(record[232+index]))
	return {"level":record.decode_s32(12),"room":record.decode_s32(16),"selection":record.decode_s32(196),"lives":record.decode_s32(28),"percentage":record.decode_s32(24),"flags":flags,"pickups":pickups,"announcement_history":history,"settings":Record.options(record)}
