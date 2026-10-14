extends RefCounted
const Rotation = preload("res://source_rotation.gd")
const VM = preload("res://asl_vm.gd")
# Native23ed0..24010: unsigned map coordinates, style-scaled Y, builder552fc.
static func poses(room: Dictionary, tables: Dictionary) -> Dictionary:
	var factors: Array = tables.get("mapYScale",{}).get("values",[])
	var pairs: Array = tables.get("rotation",{}).get("pairs",[])
	var style := int(room.get("style",-1))
	if style < 0 or style >= factors.size() or pairs.size() != 4096: return {"fault":"Missing cutscene tile placement tables"}
	var result: Array = []
	for tile in room.get("tracks",[]):
		if not tile.has_all(["position","rotation","index"]) or tile.position.size() != 3: return {"fault":"Invalid original cutscene tile"}
		var point: Array = tile.position
		var position := [VM.signed32((int(point[0])&65535)<<12),VM.signed32((int(point[1])&65535)*int(factors[style])),VM.signed32((int(point[2])&65535)<<12)]
		var yaw := Rotation.halfword(roundi(float(tile.rotation)*4096.0))
		result.append({"id":int(tile.index),"position":position,"matrix":Rotation.matrix(Vector3i(0,yaw,0),pairs),"scale":4096})
	return {"parts":result}
