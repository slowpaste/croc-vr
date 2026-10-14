extends SceneTree
func _initialize() -> void:
	var mapper=preload("res://source_input.gd")
	for scheme in range(3):
		for row in [[0x8000,0x400000 if scheme==2 else 0x400800],[0x4000,0x801000 if scheme==2 else 0x800010],[0x2000,0x200010 if scheme==2 else 0x201000],[0x1000,0x100800 if scheme==2 else 0x100000],[0x80,0x20000],[0x40,0x40000],[0x100,0x6000],[0x200,0xa000],[8,0x200],[1,0x400]]:
			if mapper.analog_buttons(65535&~int(row[0]),scheme)!=row[1]:push_error("Original analog button flag mapping differs");quit(1);return
	if mapper.analog_buttons(65535,2)!=0 or mapper.analog_buttons(65535&~0xc000,2)!=0xc01000:quit(1);return
	print("PASS: source-derived analog scheme face/common button flags and combined masks; full native capture pending")
	quit(0)
