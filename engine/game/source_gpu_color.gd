extends RefCounted
# Numeric PS1 color stage. Work in encoded channel values; no gamma conversion.
const DITHER := [-4,0,-3,1,2,-2,3,-1,-3,1,-4,0,3,-1,2,-2]
static func dither_at(x: int, y: int) -> int:
	return int(DITHER[(y&3)*4+(x&3)])
static func channel(texture5: int, color8: int, textured: bool, modulate: bool, dither: int) -> int:
	var value := clampi(color8,0,255)
	if textured:
		var texture := clampi(texture5,0,31)
		if not modulate: return texture
		value = (texture*value)>>4
	return clampi((value+dither)>>3,0,31)

static func blend(background5: int, foreground5: int, mode: int) -> int:
	var background := clampi(background5,0,31)
	var foreground := clampi(foreground5,0,31)
	match mode:
		0: return (background+foreground)>>1
		1: return mini(31,background+foreground)
		2: return maxi(0,background-foreground)
		3: return mini(31,background+(foreground>>2))
	return -1
