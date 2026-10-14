extends RefCounted
const Tables = preload("res://source_xa_zigzag_tables.gd")
var left_ring := PackedInt32Array()
var right_ring := PackedInt32Array()
var position := 0
var sixstep := 6 # Diagnostic initial phase; hardware power-up phase is unqualified.
var phases: Array[PackedInt32Array] = []
var phase_offsets: Array[PackedInt32Array] = []
func _init() -> void:
	for phase in Tables.PHASES:
		var coefficients := PackedInt32Array()
		var offsets := PackedInt32Array()
		for tap in range(29):
			if int(phase[tap]) != 0:
				coefficients.append(int(phase[tap]))
				offsets.append(tap)
		phases.append(coefficients)
		phase_offsets.append(offsets)
	reset(6)
func snapshot() -> Dictionary:
	return {"left":Array(left_ring),"right":Array(right_ring),"position":position,"sixstep":sixstep}
static func valid_snapshot(state: Dictionary) -> bool:
	for key in ["position","sixstep"]:
		if not state.get(key) is int: return false
	if state.position < 0 or state.position > 31 or state.sixstep < 1 or state.sixstep > 6: return false
	for key in ["left","right"]:
		if not state.get(key) is Array or state[key].size() != 32: return false
		for sample in state[key]:
			if not sample is int or sample < -32768 or sample > 32767: return false
	return true
func restore(state: Dictionary) -> bool:
	if not valid_snapshot(state): return false
	left_ring = PackedInt32Array(state.left)
	right_ring = PackedInt32Array(state.right)
	position = state.position
	sixstep = state.sixstep
	return true
func reset(initial_sixstep: int) -> bool:
	if initial_sixstep < 1 or initial_sixstep > 6: return false
	left_ring.resize(32)
	right_ring.resize(32)
	left_ring.fill(0)
	right_ring.fill(0)
	position = 0
	sixstep = initial_sixstep
	return true
func process_pcm(pcm: PackedByteArray, rate: int) -> Dictionary:
	if rate != 37800 or pcm.size()%4 != 0:
		return {"fault":"Zigzag interpolation requires stereo signed16 37800Hz PCM"}
	var frames := pcm.size()/4
	var output := PackedByteArray()
	output.resize(int((frames+6-sixstep)/6)*7*4)
	var out := 0
	for frame in range(frames):
		left_ring[position] = pcm.decode_s16(frame*4)
		right_ring[position] = pcm.decode_s16(frame*4+2)
		position = (position+1)&31
		sixstep -= 1
		if sixstep == 0:
			sixstep = 6
			for phase_index in range(7):
				var phase: PackedInt32Array = phases[phase_index]
				var offsets: PackedInt32Array = phase_offsets[phase_index]
				var left := 0
				var right := 0
				for tap in range(phase.size()):
					var coefficient := phase[tap]
					var index := (position-offsets[tap])&31
					left += (left_ring[index]*coefficient)>>15
					right += (right_ring[index]*coefficient)>>15
				output.encode_s16(out,clampi(left,-32768,32767))
				output.encode_s16(out+2,clampi(right,-32768,32767))
				out += 4
	return {"pcm":output,"frames":out/4,"rate":44100}
