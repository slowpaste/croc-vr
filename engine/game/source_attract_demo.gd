extends RefCounted
static func select_destination(frame_seed: int, destinations: Array, random_source: RefCounted) -> Dictionary:
	if destinations.size() != 5 or destinations.any(func(pair): return pair.size() != 2):
		return {"fault":"Missing original attract demo destination table"}
	# Main150dc..1514c: srand(frame), one BIOS draw modulo5, then srand0.
	random_source.bios_seed = frame_seed&0xffffffff
	var index: int = random_source.bios_rand()%5
	var destination: Array = destinations[index]
	random_source.bios_seed = 0
	return {"index":index,"level":int(destination[0]),"room":int(destination[1])}
