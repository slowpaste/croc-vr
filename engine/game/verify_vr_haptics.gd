extends SceneTree
func _initialize() -> void:
	var service=preload("res://vr_haptics.gd").new()
	assert(service.request("pickup",1.0,false).is_empty())
	var pulses:Array=service.request("pickup",1.0,true)
	assert(pulses.size()==1 and pulses[0].hand=="right")
	assert(service.request("pickup",1.01,true).is_empty())
	pulses=service.request("damage",1.02,true)
	assert(pulses.size()==2 and pulses[0].amplitude==0.6)
	assert(service.request("menu",1.03,true).is_empty())
	assert(service.request("jump",1.3,true).size()==1)
	assert(service.request("complete",1.5,true).size()==2)
	print("PASS: haptic events, hand routing, disable setting and pulse priority")
	quit(0)
