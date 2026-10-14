extends RefCounted
const PATTERNS := {
	"menu":{"amplitude":0.12,"duration":0.025,"both":false},
	"confirm":{"amplitude":0.25,"duration":0.055,"both":false},
	"jump":{"amplitude":0.2,"duration":0.045,"both":false},
	"attack":{"amplitude":0.38,"duration":0.08,"both":false},
	"pickup":{"amplitude":0.16,"duration":0.035,"both":false},
	"rescue":{"amplitude":0.35,"duration":0.12,"both":true},
	"damage":{"amplitude":0.6,"duration":0.16,"both":true},
	"complete":{"amplitude":0.4,"duration":0.2,"both":true}
}
var hand_until := {}
var hand_amplitude := {}
func request(event: String, now: float, enabled: bool) -> Array:
	if not enabled or not PATTERNS.has(event):return []
	var pattern:Dictionary=PATTERNS[event]
	var pulses:Array=[]
	for hand in ["left","right"] if pattern.both else ["right"]:
		# A quieter event must never truncate a stronger pulse already in flight.
		if now<float(hand_until.get(hand,0.0)) and float(pattern.amplitude)<=float(hand_amplitude.get(hand,0.0)):continue
		hand_until[hand]=now+float(pattern.duration)+0.025
		hand_amplitude[hand]=pattern.amplitude
		pulses.append({"hand":hand,"amplitude":pattern.amplitude,"duration":pattern.duration})
	return pulses
