extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
# Retail 0x800267f8 prepends ascending slots; 0x80026a18 pops the head.
var free_slots: Array[int] = []
var slots: Dictionary = {}

func reset(capacity: int) -> void:
	free_slots.clear()
	slots.clear()
	for index in range(capacity):
		free_slots.append(index)

func allocate(value: Dictionary) -> int:
	if free_slots.is_empty():
		return -1
	var index: int = free_slots.pop_back()
	slots[index] = value
	return index

func release(index: int) -> bool:
	if not slots.has(index):
		return false
	slots.erase(index)
	free_slots.append(index)
	return true
