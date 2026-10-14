extends RefCounted
static func fixed_level(attribute: int) -> int:
	# Native672a8..672f8/67378 masks fixed-volume attributes to15 bits.
	# Bit14 is the sign; bit15 is not a fixed-volume sweep request here.
	return ((attribute&0x7fff)^0x4000)-0x4000
static func frame(sample: int, left: int, right: int) -> Vector2i:
	var value := ((sample&65535)^32768)-32768
	return Vector2i(clampi((value*fixed_level(left))>>14,-32768,32767),clampi((value*fixed_level(right))>>14,-32768,32767))
static func mono16_block(pcm: PackedByteArray, start: int, count: int, left: int, right: int) -> Dictionary:
	if pcm.size()%2 != 0 or start < 0 or count < 0 or start+count > int(pcm.size()/2):
		return {"fault":"Invalid decoded mono16 sample range"}
	var output := PackedVector2Array()
	output.resize(count)
	var left_level:=fixed_level(left);var right_level:=fixed_level(right)
	for index in range(count):
		var value:=pcm.decode_s16((start+index)*2)
		output[index] = Vector2(clampi((value*left_level)>>14,-32768,32767),clampi((value*right_level)>>14,-32768,32767))/32768.0
	return {"frames":output}
