extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
const VM = preload("res://asl_vm.gd")
var bios_seed := 0
var accumulator := 0
var draws := 0
func bios_rand() -> int:
	bios_seed = (bios_seed*0x41c64e6d+12345) & 0xffffffff
	draws += 1
	return (bios_seed >> 16) & 32767
func sound_variation(volume: int, pitch: int, mask: int) -> Dictionary:
	# PlaySound mode4 at0x80027b40..0x80027b60; BIOS stream only, not accumulator.
	if mask != 0:
		pitch = VM.signed32(pitch-(bios_rand() & mask))
		volume = VM.signed32(volume-(bios_rand() & mask))
	return {"volume":volume,"pitch":pitch}

func bounded(bound: int) -> Dictionary:
	# Retail expression25 at0x8003001c..0x80030074 updates state before DIVU.
	var first := bios_rand()
	var second := bios_rand()
	accumulator = (accumulator+first+(second << 17)) & 0xffffffff
	var divisor := bound & 0xffffffff
	if divisor == 0:
		return {"fault":"Source random expression division by zero"}
	return {"value":VM.signed32(accumulator % divisor)}
