extends RefCounted
static func lookup(manifest:Dictionary,name:String) -> Dictionary:
	for entry in manifest.get("backgroundColors",[]):
		if str(entry.name)==name:return entry
	return {"clear":[0,0,0],"dome":[0,0,0]}
static func quantized(values:Array) -> Vector3:
	return Vector3(int(values[0])>>3,int(values[1])>>3,int(values[2])>>3)/31.0
