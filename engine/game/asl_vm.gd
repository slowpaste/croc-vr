extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
# New script-machine implementation. Programs come from the user's local import.
# No PS-X machine code is embedded or executed by this runtime.
var program: Dictionary
var instructions: Dictionary = {}
var pc := 8
var globals: Dictionary = {}
var parameters: Array = []
var frames: Array[Dictionary] = []
var wait_counter := 0
var status := "ready"
var fault := ""
var host: Object

static func signed32(value: int) -> int:
	var bits := value & 0xffffffff
	return bits - 0x100000000 if bits >= 0x80000000 else bits

static func native_divide(numerator: int, denominator: int) -> int:
	# Preserve the retail evaluator's two-stage integer/fraction division.
	var quotient: int
	var remainder: int
	if denominator == 0:
		quotient = -1 if numerator >= 0 else 1
		remainder = numerator
	elif numerator == -2147483648 and denominator == -1:
		quotient = -2147483648
		remainder = 0
	else:
		quotient = int(float(numerator) / float(denominator))
		remainder = numerator - quotient * denominator
	var integer_denominator := (denominator & 0xffffffff) >> 16
	var fraction := (-1 if remainder >= 0 else 1) if integer_denominator == 0 else int(float(remainder) / float(integer_denominator))
	return signed32(((quotient & 65535) << 16) | (fraction & 65535))

func configure(data: Dictionary, entry: int, owner: Object, params: Array = []) -> void:
	program = data.duplicate()
	instructions.clear()
	for instruction in data.instructions:
		instructions[int(instruction.pc)] = instruction
	pc = entry
	host = owner
	parameters = params.duplicate()
	frames.clear()
	wait_counter = 0
	globals.clear()
	status = "ready"
	fault = ""

func fail(message: String) -> void:
	status = "unsupported"
	fault = message

func evaluate(terms: Array) -> int:
	var stack: Array[int] = []
	for term in terms:
		var op := int(term.op)
		if op == 4:
			stack.append(signed32(int(term.value)))
		elif op == 2:
			stack.append(int(globals.get(int(term.index),0)))
		elif op == 29:
			var index := int(term.index)
			if index < 0 or index >= 8:
				fail("Parameter read out of bounds")
				return 0
			stack.append(signed32(int(parameters[index])) if index < parameters.size() else 0)
		elif op == 19:
			if host == null or not host.has_method("asl_asset"):
				fail("Missing resource resolver")
				return 0
			stack.append(int(host.asl_asset(term,self)))
		elif op == 18:
			if stack.is_empty():
				fail("Expression stack underflow")
				return 0
			return stack.back()
		elif op == 38:
			return 0
		elif op in [30,31,24,26]:
			if stack.is_empty():
				fail("Unary expression stack underflow")
				return 0
			var value: int = stack.pop_back()
			stack.append(signed32(-value) if op == 30 else int(value == 0) if op == 31 else signed32(absi(value)) if op == 24 else signed32(value & 0xffff0000))
		elif op in [6,7,8,9,10,11,12,13,14,15,16,17,32,36,37]:
			if stack.size() < 2:
				fail("Binary expression stack underflow")
				return 0
			var top: int = stack.pop_back()
			var previous: int = stack.pop_back()
			var result := 0
			match op:
				6: result = previous + top
				7: result = previous - top
				8: result = native_divide(previous,top)
				9: result = (previous * top) >> 16
				10: result = previous & top
				11: result = previous | top
				12: result = int(previous == top)
				13: result = int(previous != top)
				14: result = int(top < previous)
				15: result = int(previous < top)
				16: result = int(previous >= top)
				17: result = int(top >= previous)
				32: result = int(previous != 0 and top != 0)
				36: result = previous >> ((top >> 16) & 31)
				37: result = previous << ((top >> 16) & 31)
			stack.append(signed32(result))
		else:
			if host == null or not host.has_method("asl_expression"):
				fail("Unimplemented expression opcode %d" % op)
				return 0
			if not host.asl_expression(term,stack,self):
				fail("Unimplemented expression opcode %d" % op)
				return 0
		if status == "unsupported":
			return 0
	fail("Expression has no return")
	return 0

func run(instruction_budget: int = 10000) -> String:
	if status == "unsupported" or status == "finished":
		return status
	status = "running"
	for count in range(instruction_budget):
		if not instructions.has(pc):
			fail("Execution address is not an instruction: %d" % pc)
			return status
		var instruction: Dictionary = instructions[pc]
		var previous_pc := pc
		pc = int(instruction.next)
		var args: Array = instruction.args
		match int(instruction.op):
			26:
				var selector := evaluate(args[0])
				pc = int(args[2])
				for i in range(int(args[1])):
					var branch: Dictionary = args[i + 3]
					if evaluate(branch.condition) == selector:
						pc = int(branch.target)
						break
			68,176:
				var domain := int(args[0])
				var index := int(args[1])
				var increment := 65536 if int(instruction.op) == 68 else -65536
				if domain == 2:
					globals[index] = signed32(int(globals.get(index,0)) + increment)
				elif domain == 28 and host != null and host.has_method("asl_increment_extended_global"):
					if not host.asl_increment_extended_global(index,increment):
						fail("Unresolved extended global increment/decrement")
				elif domain == 29 and index >= 0 and index < 8:
					while parameters.size() <= index:
						parameters.append(0)
					parameters[index] = signed32(int(parameters[index]) + increment)
				elif domain == 45 and int(instruction.op) == 68 and host != null and host.has_method("asl_increment_parent_parameter"):
					if not host.asl_increment_parent_parameter(index,increment):
						fail("Unresolved parent parameter increment")
				else:
					fail("Unsupported increment/decrement variable domain")
			16:
				var duration := evaluate(args[0]) >> 16
				if status == "unsupported":
					pc = previous_pc
					return status
				if wait_counter == 0:
					wait_counter = duration + 1
				wait_counter -= 1
				if wait_counter != 0:
					pc = previous_pc
					status = "yielded"
					return status
			17:
				frames.append({"kind":"repeat","pc":previous_pc})
			18,174:
				var condition := evaluate(args[0])
				if frames.is_empty() or frames.back().kind != "repeat":
					fail("Until has no matching Repeat")
				else:
					var loop: Dictionary = frames.pop_back()
					if condition == 0:
						pc = loop.pc
					if int(instruction.op) == 18 and status != "unsupported":
						status = "yielded"
						return status
			19:
				if evaluate(args[0]) != 0:
					frames.append({"kind":"while","pc":previous_pc})
				else:
					pc = int(args[1])
			20,134:
				if frames.is_empty() or frames.back().kind != "while":
					fail("EndWhile has no matching While")
				else:
					pc = int(frames.pop_back().pc)
					if int(instruction.op) == 20:
						status = "yielded"
						return status
			24:
				var kind := int(args[0])
				var index := int(args[1])
				var initial := evaluate(args[2])
				var limit := evaluate(args[3])
				if kind == 2:
					globals[index] = initial
				elif kind == 29 and index >= 0 and index < 8:
					while parameters.size() <= index:
						parameters.append(0)
					parameters[index] = initial
				else:
					fail("Unimplemented For variable domain")
				frames.append({"kind":"for","pc":pc,"domain":kind,"index":index,"limit":limit})
			25,121:
				if frames.is_empty() or frames.back().kind != "for":
					fail("Next has no matching For")
				else:
					var loop: Dictionary = frames.pop_back()
					var value := signed32(int(globals.get(loop.index,0)) + 65536) if int(loop.domain) == 2 else signed32(int(parameters[loop.index]) + 65536)
					if int(loop.domain) == 2:
						globals[loop.index] = value
					else:
						parameters[loop.index] = value
					if (value & 0xffffffff) < (int(loop.limit) & 0xffffffff):
						frames.append(loop)
						pc = int(loop.pc)
					if int(instruction.op) == 25:
						status = "yielded"
						return status
			28:
				frames.append({"kind":"procedure","pc":pc})
				pc = int(args[0])
			30:
				pc = int(args[0])
				status = "yielded"
				return status
			22,27:
				pc = int(args[0])
			57:
				if frames.is_empty():
					status = "finished"
					return status
				if frames.back().kind != "procedure":
					fail("EndProc encountered an unbalanced source stack")
				else:
					pc = int(frames.pop_back().pc)
			59:
				pc = previous_pc
				if host != null and host.has_method("asl_file_end"):
					host.asl_file_end(self)
				status = "finished"
				return status
			21:
				if evaluate(args[0]) == 0:
					pc = int(args[1])
			54:
				var value := evaluate(args[1])
				if status != "unsupported":
					globals[int(args[0])] = value
			108:
				var value := evaluate(args[1])
				var index := int(args[0])
				if index < 0 or index >= 8:
					fail("Parameter index out of bounds")
				else:
					while parameters.size() <= index:
						parameters.append(0)
					parameters[index] = value
			_:
				if host == null or not host.has_method("asl_command"):
					fail("Unimplemented engine command: " + instruction.name)
				else:
					var outcome: String = host.asl_command(instruction,self)
					if outcome == "yield":
						status = "yielded"
						return status
					elif outcome == "finish":
						status = "finished"
						return status
					elif outcome != "continue":
						if status != "unsupported":
							fail("Unimplemented engine command: " + instruction.name)
		if status == "unsupported":
			pc = previous_pc
			return status
	fail("Instruction budget exhausted")
	return status
