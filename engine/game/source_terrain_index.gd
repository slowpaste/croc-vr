extends RefCounted
var tracks:Array=[]
var buckets:Dictionary={}
var full_scan:=false
func build(source_tracks:Array) -> void:
	tracks=source_tracks;buckets.clear();full_scan=false
	for index in range(tracks.size()):
		var position:Array=tracks[index].position
		var x:=int(position[0])*4096;var z:=int(position[2])*4096
		if abs(x)>536870912 or abs(z)>536870912:full_scan=true;continue
		# Native tile radius rejects equality at 2176 source units.
		for bx in range(floori(float(x-2175)/4096.0),floori(float(x+2175)/4096.0)+1):
			for bz in range(floori(float(z-2175)/4096.0),floori(float(z+2175)/4096.0)+1):
				var key:=Vector2i(bx,bz)
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append(index)
func candidates(source_tracks:Array, point:Vector3i) -> Array:
	# Preserve native signed-overflow behavior and caller-supplied geometry.
	if full_scan or not is_same(tracks,source_tracks) or abs(point.x)>536870912 or abs(point.z)>536870912:return range(source_tracks.size())
	return buckets.get(Vector2i(floori(float(point.x)/4096.0),floori(float(point.z)/4096.0)),[])
