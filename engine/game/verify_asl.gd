extends SceneTree
const VM = preload("res://asl_vm.gd")

var failures := 0

func check(condition: bool) -> void:
	if not condition:
		failures += 1
		push_error("ASL runtime check failed")

func _initialize() -> void:
	var vm = VM.new()
	check(vm.evaluate([{"op":4,"value":65536},{"op":4,"value":131072},{"op":9},{"op":18}]) == 131072)
	check(VM.signed32(2147483648) == -2147483648)
	check(VM.native_divide(196608,131072) == 98304)
	check(VM.native_divide(65536,65536) == 65536)
	# These intentionally preserve retail divide quirks, not ideal fixed-point division.
	check(VM.native_divide(65536,32768) == 196607)
	check(vm.evaluate([{"op":4,"value":1},{"op":4,"value":65536},{"op":37},{"op":18}]) == 2)
	check(vm.evaluate([{"op":4,"value":2147483647},{"op":4,"value":1},{"op":6},{"op":18}]) == -2147483648)
	check(vm.evaluate([{"op":4,"value":10},{"op":4,"value":20},{"op":16},{"op":18}]) == 0)
	check(vm.evaluate([{"op":4,"value":10},{"op":4,"value":20},{"op":17},{"op":18}]) == 1)
	var data := {"instructions":[{"pc":8,"op":28,"name":"ProcCall","args":[20],"next":11},{"pc":11,"op":59,"name":"FileEnd","args":[],"next":12},{"pc":20,"op":54,"name":"LetGVar","args":[0,[{"op":4,"value":42},{"op":18}]],"next":28},{"pc":28,"op":57,"name":"EndProc","args":[],"next":29}]}
	vm.configure(data,8,null)
	check(vm.run() == "finished")
	check(vm.globals[0] == 42)
	var goto_program := {"instructions":[{"pc":8,"op":30,"name":"Goto","args":[20],"next":11},{"pc":20,"op":68,"name":"Inc","args":[2,0],"next":24},{"pc":24,"op":30,"name":"Goto","args":[20],"next":27}]}
	vm.configure(goto_program,8,null)
	check(vm.run() == "yielded" and vm.pc == 20 and vm.globals.is_empty())
	check(vm.run() == "yielded" and vm.pc == 20 and vm.globals[0] == 65536)
	check(vm.run() == "yielded" and vm.globals[0] == 131072)
	var switch_program := {"instructions":[{"pc":8,"op":26,"name":"Switch","args":[[{"op":4,"value":1},{"op":18}],2,30,{"target":20,"condition":[{"op":4,"value":1},{"op":18}]},{"target":30,"condition":[{"op":1,"index":999},{"op":18}]}],"next":20},{"pc":20,"op":68,"name":"Inc","args":[29,0],"next":24},{"pc":24,"op":176,"name":"Dec","args":[29,0],"next":28},{"pc":28,"op":59,"name":"FileEnd","args":[],"next":29},{"pc":30,"op":0,"name":"CommandError","args":[],"next":31}]}
	vm.configure(switch_program,8,null,[0])
	check(vm.run() == "finished" and vm.parameters[0] == 0)
	var wait_program := {"instructions":[{"pc":8,"op":16,"name":"Wait","args":[[{"op":4,"value":131072},{"op":18}]],"next":15},{"pc":15,"op":59,"name":"FileEnd","args":[],"next":16}]}
	vm.configure(wait_program,8,null)
	check(vm.run() == "yielded" and vm.pc == 8)
	check(vm.run() == "yielded" and vm.pc == 8)
	check(vm.run() == "finished")
	var repeat_program := {"instructions":[{"pc":8,"op":17,"name":"Repeat","args":[],"next":9},{"pc":9,"op":18,"name":"Until","args":[[{"op":4,"value":1},{"op":18}]],"next":16},{"pc":16,"op":59,"name":"FileEnd","args":[],"next":17}]}
	vm.configure(repeat_program,8,null)
	check(vm.run() == "yielded" and vm.pc == 16)
	check(vm.run() == "finished")
	repeat_program.instructions[1].op = 174
	vm.configure(repeat_program,8,null)
	check(vm.run() == "finished")
	var for_program := {"instructions":[{"pc":8,"op":24,"name":"For","args":[29,0,[{"op":38}],[{"op":4,"value":131072},{"op":18}]],"next":20},{"pc":20,"op":121,"name":"NextImm","args":[],"next":21},{"pc":21,"op":59,"name":"FileEnd","args":[],"next":22}]}
	vm.configure(for_program,8,null)
	check(vm.run() == "finished" and vm.parameters[0] == 131072)
	for_program.instructions[1].op = 25
	vm.configure(for_program,8,null)
	check(vm.run() == "yielded" and vm.parameters[0] == 65536)
	check(vm.run() == "yielded" and vm.parameters[0] == 131072)
	check(vm.run() == "finished")
	vm.configure({"instructions":[{"pc":8,"op":157,"name":"InitCrystal","args":[],"next":9}]},8,null)
	check(vm.run() == "unsupported")
	check(vm.pc == 8)
	if failures == 0:
		print("PASS: ASL fixed arithmetic, source divide quirks, calls, globals, explicit unsupported commands")
	quit(1 if failures else 0)
