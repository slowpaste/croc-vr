extends SceneTree
const Zigzag = preload("res://source_xa_zigzag.gd")
func _initialize() -> void:
	var impulse := PackedByteArray()
	impulse.resize(24)
	impulse.encode_s16(0,32767)
	impulse.encode_s16(2,-32768)
	var filter := Zigzag.new()
	var result := filter.process_pcm(impulse,37800)
	var expected_left := [9,-19,30,-27,106,-235,346]
	var expected_right := [-10,19,-31,27,-107,235,-347]
	if result.frames != 7 or result.rate != 44100: quit(1); return
	for frame in range(7):
		if result.pcm.decode_s16(frame*4) != expected_left[frame] or result.pcm.decode_s16(frame*4+2) != expected_right[frame]:
			push_error("Original zigzag impulse phase/routing/rounding differs")
			quit(1)
			return
	var input := PackedByteArray()
	input.resize(2016*4)
	for frame in range(2016):
		input.encode_s16(frame*4,((frame*7919)%65536)-32768)
		input.encode_s16(frame*4+2,((frame*3571)%65536)-32768)
	filter.reset(6)
	var entire := filter.process_pcm(input,37800)
	var chunked := Zigzag.new()
	var joined := PackedByteArray()
	for start in range(0,input.size(),20):
		joined.append_array(chunked.process_pcm(input.slice(start,mini(start+20,input.size())),37800).pcm)
	if entire.frames != 2352 or entire.pcm != joined or filter.left_ring != chunked.left_ring or filter.right_ring != chunked.right_ring or filter.sixstep != chunked.sixstep:
		push_error("XA interpolation changed at streaming chunk boundaries")
		quit(1)
		return
	var before := filter.left_ring.duplicate()
	var checkpoint := filter.snapshot()
	var resumed := Zigzag.new()
	if not resumed.restore(checkpoint) or resumed.process_pcm(impulse,37800).pcm != filter.process_pcm(impulse,37800).pcm:
		push_error("Explicit interpolation snapshot did not preserve continuation PCM")
		quit(1)
		return
	before = filter.left_ring.duplicate()
	checkpoint = filter.snapshot()
	var invalid := checkpoint.duplicate(true)
	invalid.position = 32
	if filter.restore(invalid) or filter.snapshot() != checkpoint:
		push_error("Invalid interpolation snapshot changed active state")
		quit(1)
		return
	if not filter.process_pcm(input,18900).has("fault") or filter.reset(0) or filter.left_ring != before:
		push_error("Unsupported interpolation input changed filter history")
		quit(1)
		return
	print("PASS: XA zigzag stereo impulse, 6:7 sample rate, streaming ring/phase continuity and rejected input")
	quit(0)
