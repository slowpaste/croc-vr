extends RefCounted
# Numeric GTE perspective stage; matrix MAC/IR calculation is supplied separately.
# Reciprocal table is generated from the documented integer formula.
static func reciprocal_entry(index: int) -> int:
	return clampi(((int(262144.0/float(index+256))+1)>>1)-257,0,255)

static func divide(h: int, depth: int) -> int:
	var lhs := h&65535
	var rhs := depth&65535
	if rhs*2 <= lhs: return 0x1ffff
	var shift := 0
	while (rhs<<shift) < 0x8000: shift += 1
	lhs <<= shift
	rhs <<= shift
	var divisor := rhs|0x8000
	var x := 257+reciprocal_entry(((divisor&0x7fff)+64)>>7)
	var d := (divisor*(-x)+128)>>8
	var reciprocal := (x*(0x20000+d)+128)>>8
	return mini(0x1ffff,(lhs*reciprocal+0x8000)>>16)

static func screen(ir: Vector2i, depth: int, h: int, offset: Vector2i) -> Vector2i:
	var factor := divide(h,clampi(depth,0,65535))
	return Vector2i(clampi((clampi(ir.x,-32768,32767)*factor+offset.x)>>16,-1024,1023),clampi((clampi(ir.y,-32768,32767)*factor+offset.y)>>16,-1024,1023))
