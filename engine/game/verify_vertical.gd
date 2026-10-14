extends SceneTree
const Vertical = preload("res://source_vertical.gd")
var failures := 0
func check(value: bool) -> void:
	if not value:
		failures += 1
		push_error("Source vertical controller check failed")
func _initialize() -> void:
	check(Vertical.fall(1000,17,0,0x401,2,0) == {"y":983,"speed":29,"primary":0x401,"secondary":0})
	check(Vertical.fall(1000,17,0,0x401,2,1).y == 999)
	check(Vertical.fall(1000,-17,0,0x401,2,1).y == 1002)
	check(Vertical.fall(10,10,0,0x401,0,0) == {"y":0,"speed":0,"primary":0x1001,"secondary":2})
	check(Vertical.fall(1000,576,-1000,0x401,0,0).speed == 576)
	check(Vertical.rise(100,100,800,0x201,true) == {"y":200,"speed":100,"remaining":700,"primary":0x201})
	check(Vertical.rise(100,100,799,0x201,true).speed == 67)
	check(Vertical.rise(100,100,799,0x2000201,false).speed == 34)
	check(Vertical.rise(100,100,1500,0x2000201,false).speed == 100)
	check(Vertical.rise(100,100,103,0x201,true) == {"y":200,"speed":0,"remaining":0,"primary":0x2401})
	check(Vertical.rise(2147483647,100,800,0x201,true).y == -2147483549)
	if failures == 0:
		print("PASS: original falling acceleration, landing, rise thresholds, release shortening and signed wrapping")
	quit(1 if failures else 0)
