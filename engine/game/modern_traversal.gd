extends RefCounted
# Source states:7 ceiling traversal,8 ledge hang,9 pull-up,11 wall climb.
const DEADZONE := 16.0/127.0
static func axes(stick: Vector2) -> Vector2:
	var length := minf(stick.length(),1.0)
	return Vector2.ZERO if length <= DEADZONE else stick.normalized()*(length-DEADZONE)/(1.0-DEADZONE)

static func animation_button(mode: int, axis: Vector2) -> int:
	if axis.is_zero_approx(): return 0
	if mode == 7: return 1 # Hand-over-hand clip; continuous travel owns its heading.
	if mode == 8: return 1 if axis.y < -0.025 else 2 if axis.y > 0.025 else 0
	return (1 if axis.y < 0 else 2) if absf(axis.y)>=absf(axis.x) else (8 if axis.x>0 else 4)

static func locomotion(mode: int, clip: String) -> bool:
	if mode == 11:
		return clip in ["CROC_CLU.ANI","CROC_CRU.ANI","CROC_CLD.ANI","CROC_CRD.ANI","CROC_CLL.ANI","CROC_CLR.ANI","CROC_CRL.ANI","CROC_CRR.ANI","CROC_CWL.ANI","CROC_CWR.ANI"]
	return mode == 7 and clip in ["CROC_HLR.ANI","CROC_HRL.ANI","CROC_HLB.ANI","CROC_HRB.ANI","CROC_HSL.ANI","CROC_HSR.ANI","CROC_HWL.ANI","CROC_HWR.ANI"]

static func clip_button(mode: int, clip: String) -> int:
	if mode == 7: return 0 if clip in ["CROC_HWL.ANI","CROC_HWR.ANI"] else 1
	if clip in ["CROC_CLU.ANI","CROC_CRU.ANI"]: return 1
	if clip in ["CROC_CLD.ANI","CROC_CRD.ANI"]: return 2
	if clip in ["CROC_CLL.ANI","CROC_CLR.ANI"]: return 4
	if clip in ["CROC_CRL.ANI","CROC_CRR.ANI"]: return 8
	return 0

static func displacement(mode: int, axis: Vector2, yaw: int, heading: int) -> Vector3:
	if mode == 11:
		# Match the authored climb's mean up/down and lateral speeds, in source units.
		return Basis(Vector3.UP,float(yaw)*TAU/4096.0)*Vector3(-axis.x*28.0,-axis.y*46.0,0)
	if mode == 7:
		var angle := float(heading)*TAU/4096.0
		return Vector3(sin(angle),0,cos(angle))*38.0*axis.length()
	return Vector3.ZERO
