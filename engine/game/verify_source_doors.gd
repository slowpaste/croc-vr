extends SceneTree
const Doors = preload("res://source_doors.gd")
func _initialize() -> void:
	var door := {"level":10,"room":1,"id":7,"flags":2}
	var counter := 0
	for tick in range(10):
		var delayed := Doors.transition_request(door,10,5,1,false,counter)
		if delayed.transition or delayed.counter != counter+1:
			quit(1)
			return
		counter = delayed.counter
	if Doors.transition_request(door,10,5,1,false,counter) != {"transition":true,"state":5,"counter":10,"capture_origin":true} or Doors.transition_request(door,10,1,11,false,0).state != 2 or Doors.transition_request(door,9,5,5,false,null).state != 3 or Doors.transition_request(door,10,5,5,true,8).transition:
		quit(1)
		return
	door.flags = 16
	if Doors.transition_request(door,10,5,5,true,null) != {"transition":true,"state":3,"counter":0,"capture_origin":false}:
		quit(1)
		return
	var entries := [{"position":[1,0,2],"flags":8},{"position":[1,0,2],"flags":2},{"position":[1,0,2],"flags":1}]
	var hit := Doors.matching_exit(Vector3i(4096,-600,8192),512,0,entries)
	if hit != {"matched":false,"blocked":true,"index":1}:
		quit(1)
		return
	hit = Doors.matching_exit(Vector3i(2048,0,8192),512,2,entries)
	if not hit.matched or hit.index != 1 or Doors.matching_exit(Vector3i(2047,0,8192),512,2,entries).matched:
		quit(1)
		return
	entries[0].flags = 9
	if Doors.matching_exit(Vector3i(4096,0,8192),512,0,entries).index != 0 or not Doors.matching_exit(Vector3i.ZERO,0,0,entries).has("fault"):
		quit(1)
		return
	print("PASS: source door grid rounding, signed Y division, exact flags and ground blocking")
	quit(0)
