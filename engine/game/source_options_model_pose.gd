extends RefCounted
static func music_selection(state: Dictionary, selected: int, playback: int) -> Dictionary:
	if selected<0 or selected>4:return {"fault":"Invalid Music Player model selection"}
	var next := state.duplicate(true)
	next.slot=(1260 if playback==1 else 1264) if selected==0 else [1268,1304,1308,1296][selected-1]
	var position: Vector3i=next.position;position.z=3000 if selected==4 else 2000;next.position=position
	return next
static func audio_selection(state: Dictionary, selected: int, mode: int, player_available: bool) -> Dictionary:
	if selected<0 or selected>(4 if player_available else 3) or not state.has_all(["position","angles"]):return {"fault":"Invalid Audio preview selection"}
	if selected==2:return audio_mode_selection(state,mode)
	var result := state.duplicate(true)
	var position: Vector3i=result.position
	if selected in [0,1]:
		result.slot=1256 if selected==0 else 1276;position.z=3000
	elif selected==3 and player_available:
		result.slot=1272;position.y=200;position.z=1800
	else:
		result.slot=1296;position.z=3000
		if player_available:
			position.y=0
			var angles: Vector3i=result.angles;angles.x=0;result.angles=angles
	result.position=position
	return result
static func audio_mode_selection(state: Dictionary, mode: int) -> Dictionary:
	if mode not in [0,1,2] or not state.has_all(["position","angles"]):return {"fault":"Invalid Audio mode preview state"}
	var result := state.duplicate(true)
	result.slot=[1288,1292,1300][mode]
	var angles: Vector3i=result.angles;angles.x=0;result.angles=angles
	var position: Vector3i=result.position;position.y=0;position.z=2000;result.position=position
	return result
static func draw_step(state: Dictionary) -> Dictionary:
	if not state.has_all(["slot","position","angles"]) or not state.slot is int or not state.position is Vector3i or not state.angles is Vector3i: return {"fault":"Invalid Options preview draw state"}
	var next := state.duplicate(true)
	if state.slot == 0: return {"draw":{},"next":next}
	# Native4b090..4b104 renders before advancing the unsigned yaw halfword.
	var angles: Vector3i = next.angles
	angles.y = (angles.y+48)&65535
	next.angles = angles
	return {"draw":state.duplicate(true),"next":next}
static func root_selection(state: Dictionary, selected: int, pad_kind: int) -> Dictionary:
	if selected < 0 or selected > 3 or not state.has_all(["position","angles"]) or not state.position is Vector3i or not state.angles is Vector3i: return {"fault":"Invalid Options root model pose"}
	var result := state.duplicate(true)
	# Native4b238..4b2f4 writes X angle and Y/Z position, retaining other words.
	result.slot = (1316 if pad_kind == 2 else 1252) if selected == 0 else [1280,1284,1296][selected-1]
	var angles: Vector3i = result.angles
	angles.x = 512 if selected == 0 else 0
	result.angles = angles
	var position: Vector3i = result.position
	position.y = [50,100,0,0][selected]
	position.z = [2200,2000,1200,3000][selected]
	result.position = position
	return result
