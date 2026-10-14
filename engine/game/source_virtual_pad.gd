extends RefCounted
# Explicit local adapter; packet decoding remains the original reimplementation.
static func axis_byte(value: float) -> int:
	var axis := clampf(value,-1.0,1.0)
	return clampi(128+roundi(axis*(128.0 if axis<0 else 127.0)),0,255)
static func analog_packet(left: Vector2, right: Vector2, active_low: int = 65535) -> PackedByteArray:
	if not is_finite(left.x) or not is_finite(left.y) or not is_finite(right.x) or not is_finite(right.y):return PackedByteArray()
	return PackedByteArray([0,0x73,active_low&255,(active_low>>8)&255,axis_byte(right.x),axis_byte(right.y),axis_byte(left.x),axis_byte(left.y)])
