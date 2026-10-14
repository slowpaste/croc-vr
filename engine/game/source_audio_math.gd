extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
const VM = preload("res://asl_vm.gd")
const Collision = preload("res://source_collision.gd")
static func panning(volume: int, angle: int, mode: int) -> Dictionary:
	# Native2e5a4..2e818. Rear surround produces opposite signed channels;
	# retain low-halfword results rather than imposing normalized gains.
	var value := ((volume&65535)^32768)-32768
	var bearing := angle&65535
	if bearing == 0:
		var centered := value>>1 if mode == 2 else value
		return {"left":centered,"right":centered,"flags":1}
	if bearing > 4096: return {"ignored":true}
	var distance := absi(1024-bearing) if bearing <= 2048 else absi(bearing-3072)
	var near := ((distance*value)>>10)
	var far := (((2048-distance)*value)>>10)
	var left := far if bearing <= 2048 else near
	var right := near if bearing <= 2048 else far
	if mode == 2 and bearing > 1024 and bearing <= 3072:
		var rear := ((far&65535)^32768)-32768
		left = rear>>2 if bearing <= 2048 else (-rear)>>2
		right = (-rear)>>2 if bearing <= 2048 else rear>>2
		return {"left":left,"right":right,"flags":2}
	return {"left":((left&65535)^32768)-32768,"right":((right&65535)^32768)-32768,"flags":1}
static func one_shot_volume(base: int, effects: int, distance: int, quiet: bool) -> Dictionary:
	# Native2e878..2e928: low32 multiply, optional logical half, distance
	# subtraction, then a signed low-halfword gate. Held-sample allocation is
	# handled later by the caller, so inaudible doesn't always mean rejected.
	var option := ((effects&65535)^32768)-32768
	var product := VM.signed32(base*option)
	if product == 0: return {"blocked":true,"volume":0,"audible":false}
	if quiet: product = (product&0xffffffff)>>1
	var volume := VM.signed32(product-(VM.signed32(distance-4096)>>2))
	var word := ((volume&65535)^32768)-32768
	return {"blocked":false,"volume":word,"audible":word>0}
static func fade_step(master: int) -> int:
	var signed := ((master&65535)^32768)-32768
	return (signed+7 if signed < 0 else signed)>>3
static func fade_half_up(current: int, step: int, maximum: int) -> int:
	# Source0x8002dfa8..0x8002dff4: signed half input, unsigned limit comparison.
	var signed := ((current&65535)^32768)-32768
	if (VM.signed32(signed+step)&0xffffffff) >= (maximum&0xffffffff):
		return maximum&65535
	return ((current&65535)+(step&65535))&65535
static func fade_half_down(current: int, step: int) -> int:
	# Source0x8002e080..0x8002e0c8 zeros candidate values below2.
	var signed := ((current&65535)^32768)-32768
	return 0 if VM.signed32(signed-step) < 2 else ((current&65535)-(step&65535))&65535
static func should_fade_out(transition_state: int, lives: int, game_mode: int, mode8_gate: int) -> bool:
	# Source0x8002e018: surviving respawn and the gated mode8 path retain audio.
	return not ((transition_state == 1 and lives != 0) or (game_mode == 8 and mode8_gate == 0))
static func listener_metrics(emitter: Vector3i, listener: Vector3i, roots: Array) -> Dictionary:
	if roots.size() != 192:
		return {"fault":"Missing source audio distance table"}
	var delta := Vector3i(VM.signed32(emitter.x-listener.x) >> 1,VM.signed32(emitter.y-listener.y),VM.signed32(emitter.z-listener.z) >> 1)
	return {"distance":VM.signed32(Collision.player_distance(delta,roots) << 1)}
static func listener_bearing(emitter: Vector3i, listener: Vector3i, yaw: int, angles: Array) -> Dictionary:
	# Native38c3c/38c68 halves X/Z deltas before5558c;38cbc subtracts
	# the view yaw and retains12 bits. Height doesn't affect bearing.
	var delta := Vector2i(VM.signed32(emitter.x-listener.x)>>1,VM.signed32(emitter.z-listener.z)>>1)
	var bearing := Collision.wall_normal_angle(delta,angles)
	if bearing.has("fault"): return bearing
	return {"angle":(int(bearing.angle)-(yaw&65535))&4095}
static func loop_volume(base: int, master: int, distance: int, muted: bool) -> int:
	# 0x8002ebf4..0x8002ec60; low signed halfword is tested before SPU output.
	var gain := master & 65535
	if gain >= 32768:
		gain -= 65536
	var volume := VM.signed32(VM.signed32(base*gain)-(VM.signed32(distance-4096) >> 2))
	var word := volume & 65535
	return 0 if muted or word == 0 or word >= 32768 else word
