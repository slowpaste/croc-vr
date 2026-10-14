extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
# Dynamic voice scan at 0x8002e930..0x8002ea28 reserves channels 0..3.
var cursor := 0
var reserved: Array[bool] = []
var pitch_registers: Dictionary = {}
var volume_registers: Dictionary = {}
func _init() -> void:
	reserved.resize(24)
	reserved.fill(false)
func allocate(held: bool) -> int:
	for attempt in range(20):
		cursor = ((cursor+1) & 255) % 24
		if cursor < 4:
			cursor = 4
		if not reserved[cursor]:
			reserved[cursor] = held
			return cursor
	return -1 # Source spins if every dynamic channel is reserved; report exhaustion.
func set_pitch(index: int, pitch: int) -> bool:
	if index < 0 or index >= 24:
		return false
	pitch_registers[index] = pitch & 65535
	return true
func shift_pitch(index: int, delta: int) -> Dictionary:
	if index < 0:
		return {"ignored":true}
	if index >= 24 or not pitch_registers.has(index):
		return {"fault":"Unknown source voice pitch register"}
	pitch_registers[index] = (int(pitch_registers[index])+delta) & 65535
	return {"raw":pitch_registers[index],"effective":mini(int(pitch_registers[index]),16384)}
func release(index: int) -> bool:
	if index < 0:
		return true
	if index >= 24:
		return false
	reserved[index] = false
	return true
