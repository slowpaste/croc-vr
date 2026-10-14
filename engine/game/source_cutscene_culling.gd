extends RefCounted
const VM = preload("res://asl_vm.gd")
# GTE NCLIP MAC0 consumes the already projected signed screen coordinates.
static func nclip(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return VM.signed32(a.x*b.y+b.x*c.y+c.x*a.y-a.x*c.y-b.x*a.y-c.x*b.y)

# Native199c8..199e0 and1910c..19148. Zero-area source faces are accepted.
static func triangle(flags: int, area: int) -> bool:
	return VM.signed32(area) >= 0 or (flags&4) != 0

# Second area uses native SXY register order[vertex3,vertex1,vertex2].
static func quad(flags: int, first_area: int, second_area: int) -> bool:
	if VM.signed32(first_area) >= 0 or (flags&4) != 0: return true
	if (flags&0x80) != 0: return false
	return VM.signed32(second_area) <= 0
