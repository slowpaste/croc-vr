extends RefCounted
static func initialize(count: int) -> Dictionary:
	var nodes: Dictionary = {}
	for index in range(count):
		nodes[index] = {"next":index+1 if index+1 < count else -1,"previous":index-1}
	return {"head":0 if count > 0 else -1,"tail":count-1,"nodes":nodes}
static func delete_current(chain: Dictionary, current: int) -> Dictionary:
	# Native2b7b0..2b880 keeps removed records allocated and tail408 unchanged.
	var head := int(chain.head)
	if head < 0 or not chain.nodes.has(head) or int(chain.nodes[head].next) < 0:
		return {"fault":"Source cannot delete the final waypoint"}
	if not chain.nodes.has(current):
		return {"fault":"Missing current source waypoint"}
	var node: Dictionary = chain.nodes[current]
	var next := int(node.next)
	var previous := int(node.previous)
	if previous >= 0:
		chain.nodes[previous].next = next
	if next >= 0:
		chain.nodes[next].previous = previous
	if previous < 0:
		chain.head = next
	return {"current":next if next >= 0 else head}
