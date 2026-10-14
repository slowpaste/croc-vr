extends RefCounted
# Normalized session order: L->L, R->R, L->R, R->L.
# CD gains are unsigned bytes /128; each product is shifted before summing.
# Reference: DuckStation CDROM::GetAudioFrame/ApplyVolume/SaturateVolume.
static func frame(left: int, right: int, mix: Array) -> Vector2:
	var output_left := clampi(((left*int(mix[0]))>>7)+((right*int(mix[3]))>>7),-32768,32767)
	var output_right := clampi(((right*int(mix[1]))>>7)+((left*int(mix[2]))>>7),-32768,32767)
	return Vector2(output_left,output_right)/32768.0
