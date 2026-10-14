extends RefCounted
static func plan(request: Dictionary, previous: Dictionary, rooms: Dictionary, pairs: Array, end_offsets: Array, streams: Array, mode8_channels: Array = []) -> Dictionary:
	# Play51090..51218 plus seek-mode branches50f08..51078.
	var cue := int(request.cue)
	var mode := int(request.mode)
	var room := int(request.room)
	var variant := 0
	var seek_mode := int(request.get("seek_mode",0))
	var bookmark_room := room
	var looping := bool(request.get("loop",false))
	if mode == 4:
		variant = int(rooms.get(room,{}).get("variant",0))
		if int(previous.get("cue",-1)) == cue and int(previous.get("room",-1)) != room:
			bookmark_room = int(previous.room)
			variant = int(rooms.get(bookmark_room,{}).get("variant",0))
			seek_mode = 2
		if ((int(request.style)-7)&0xffffffff) < 9 and cue != 64:
			looping = true
	if variant not in [0,1]:
		return {"fault":"Unqualified original music variant table index"}
	var selected := select(cue,variant != 0,pairs,end_offsets)
	if selected.has("fault"):
		return selected
	if mode == 8 and int(request.get("mode8_flag",0)) != 0:
		if mode8_channels.size() != 65:
			return {"fault":"Missing original mode8 music channel table"}
		var logical := int(mode8_channels[cue])
		if logical < 1 or logical > 70:
			return {"fault":"Invalid original mode8 music channel"}
		selected = {"logical":logical,"pack":int((logical-1)/7)+1,"channel":(logical-1)%7+1,"end_sector_offset":int(end_offsets[logical-1])}
		seek_mode = 0 # Native511f4 calls50f08 with mode0 outside gameplay.
	elif mode != 4:
		seek_mode = 0
	var stream: Dictionary = {}
	for candidate in streams:
		if int(candidate.logical) == int(selected.logical):
			stream = candidate
	if stream.is_empty():
		return {"fault":"Missing original selected XA channel"}
	var start := int(stream.sourceLba)
	if seek_mode == 2:
		var saved := int(rooms.get(bookmark_room,{}).get("start",0))
		if saved != 0:
			start = saved
	elif seek_mode == 128:
		var saved := int(rooms.get(room,{}).get("start",0))
		if saved != 0:
			start = saved
	# A cue can finish before the selected XA lane's physical file ends.
	# Keep the catalog bound with the stream passed to both decoding paths.
	stream = stream.duplicate(true)
	stream.end_sector_limit = int(stream.sourceLba)+int(selected.end_sector_offset)
	selected.merge({"cue":cue,"variant":variant,"loop":looping,"seek_mode":seek_mode,"room":room,"start_sector":start,"pack_start":int(stream.sourceLba),"end_sector":int(stream.sourceLba)+int(selected.end_sector_offset),"fade_sector":int(stream.sourceLba)+int(selected.end_sector_offset)-300,"stream":stream})
	return selected
static func select(cue: int, alternate: bool, pairs: Array, end_offsets: Array) -> Dictionary:
	if pairs.size() != 65 or end_offsets.size() != 70 or cue < 1 or cue >= 65:
		return {"fault":"Missing original music cue/bounds data or invalid cue"}
	var logical := int(pairs[cue][1 if alternate else 0])
	if logical < 1 or logical > 70:
		return {"fault":"Invalid original XA channel number"}
	return {"logical":logical,"pack":int((logical-1)/7)+1,"channel":(logical-1)%7+1,"end_sector_offset":int(end_offsets[logical-1])}
