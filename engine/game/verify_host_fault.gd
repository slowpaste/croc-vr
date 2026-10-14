extends SceneTree
class Host:
	extends RefCounted
	var specific := true
	func asl_command(_instruction: Dictionary, machine: RefCounted) -> String:
		if specific: machine.fail("Missing PlayerMove gradient owner")
		return "unsupported"
func _initialize() -> void:
	var host := Host.new()
	var machine := preload("res://asl_vm.gd").new()
	var program := {"instructions":[{"pc":8,"next":9,"op":191,"name":"PlayerMove","args":[]}]}
	machine.configure(program,8,host)
	assert(machine.run() == "unsupported" and machine.pc == 8)
	assert(machine.fault == "Missing PlayerMove gradient owner")
	host.specific = false;machine.configure(program,8,host)
	assert(machine.run() == "unsupported" and machine.pc == 8)
	assert(machine.fault == "Unimplemented engine command: PlayerMove")
	print("PASS: VM preserves specific host fault and original failing PC, while retaining generic fallback for missing handlers")
	quit(0)
