extends RefCounted
# SPDX-License-Identifier: GPL-2.0-only
const VM = preload("res://asl_vm.gd")

static func fall(y: int, speed: int, ground: int, primary: int, secondary: int, map_type: int) -> Dictionary:
	# Retail 0x8002d774..0x8002d834.
	y = VM.signed32(y - (speed >> 4 if map_type == 1 else speed))
	secondary &= ~2
	speed = VM.signed32(VM.signed32(speed + 8) + (speed >> 2))
	if speed > 576:
		speed = 576
	if y <= ground:
		y = ground
		primary = VM.signed32((primary & ~0x400) | 0x1000)
		secondary |= 2
		speed = 0
	return {"y":y,"speed":speed,"primary":primary,"secondary":secondary}

static func rise(y: int, speed: int, remaining: int, primary: int, jump_held: bool) -> Dictionary:
	# Retail 0x8002d838..0x8002d920. Flags transition to falling at the apex.
	y = VM.signed32(y + speed)
	remaining = VM.signed32(remaining - speed)
	if remaining < 700:
		speed = VM.signed32(VM.signed32(speed - 8) - (speed >> 2))
	if remaining < 1400 and (primary & 0x2000000) != 0 and not jump_held:
		speed = VM.signed32(speed - (speed >> 1))
	if remaining < 4 or speed < 4:
		remaining = 0
		speed = 0
		primary = VM.signed32((primary & ~0x200) | 0x2400)
	return {"y":y,"speed":speed,"remaining":remaining,"primary":primary}
