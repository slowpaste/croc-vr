extends RefCounted
const VM = preload("res://asl_vm.gd")
var cursor := 0
var mode := 200 # Play510c4 -> Setmode50bbc: byte0xc8.
var reading := false
var remainder := 0
func begin(position: int, read_mode: int) -> void:
	cursor = VM.signed32(position)
	mode = read_mode&255
	remainder = 0
	reading = true
func advance(microseconds: int) -> Dictionary:
	if microseconds < 0: return {"fault":"Negative CD clock interval"}
	if not reading: return {"cursor":cursor,"sectors":0}
	# CD nominal raw-sector rates. Seek latency/IRQ phase are supplied separately.
	var total := microseconds*(150 if (mode&128) != 0 else 75)+remainder
	var sectors := int(total/1000000)
	remainder = total%1000000
	cursor = VM.signed32(cursor+sectors)
	return {"cursor":cursor,"sectors":sectors}
