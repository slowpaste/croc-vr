extends RefCounted
const ABORT_MASK := 0xf0c780
# Main146a0..14748 and14de0. Buttons come from live pad3930c, not recording.
static func decide(tick: int, transition: int, live_buttons: int, fade_present: bool, fade_ready: bool) -> Dictionary:
	var abort := (live_buttons&ABORT_MASK) != 0
	if transition == 0 and tick < 900 and not abort:
		return {"action":"continue","tick":tick,"sound":false,"mode":3}
	if fade_present:
		return {"action":"return" if fade_ready else "wait","tick":900,"sound":false,"mode":0 if fade_ready else 3}
	return {"action":"fade","tick":900,"sound":abort,"mode":3,"profile":8}
