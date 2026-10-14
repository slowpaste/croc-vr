extends RefCounted
static func action(selected: int, track: int, playback: int, pressed: int) -> Dictionary:
	if selected < 0 or selected > 4 or track < 1 or track > 64:
		return {"fault":"Invalid original music player selection/track"}
	var result := {"page":5,"selected":selected,"last_index":4,"track":track,"commands":[]}
	# Native4d4b0 returns before independently handling Confirm; both buttons
	# therefore apply Previous Track after installing the parent selection3.
	if (pressed&0x100000) != 0:
		result.page = 3;result.selected = 3;result.music_player_available = false
	if (pressed&0x800000) == 0: return result
	match int(result.selected):
		0:
			result.commands = ["pause"] if playback == 1 else (["resume"] if playback == 2 else ["play"])
		1: result.commands = ["stop"]
		2,3:
			var direction := 1 if int(result.selected) == 2 else -1
			result.track = ((track-1+direction+64)%64)+1
			result.commands = ["stop","play","pause"] if playback == 2 else ["stop","play"]
		4:
			result.commands = ["stop","menu_music"]
			result.page = 3;result.selected = 3;result.music_player_available = false
	return result
