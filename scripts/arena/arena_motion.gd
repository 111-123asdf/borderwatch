class_name ArenaMotion
extends RefCounted
# Six relative frame holds sum to 6: same total action time, distinct phase rhythm.
static func holds(identity: String,state: String) -> Array:
	if state=="attack":
		return {"knight":[1.25,1.4,0.6,0.3,0.9,1.55],"ranger":[1.0,1.6,1.5,0.25,0.5,1.15],"mage":[1.1,1.25,1.25,0.4,0.8,1.2]}[identity]
	if state=="small":return [1.0,1.4,0.7,0.35,1.0,1.55] if identity!="ranger" else [0.6,0.7,1.0,1.2,1.3,1.2]
	if state=="ultimate":return [0.8,1.4,1.6,0.5,0.65,1.05]
	if state=="hurt":return [0.25,1.2,1.8,1.0,0.75,1.0]
	return [1.0,1.0,1.0,1.0,1.0,1.0]
static func release_fraction(identity: String,state: String) -> float:
	var weights:=holds(identity,state)
	return (weights[0]+weights[1]+weights[2])/6.0
static func stride_scale(speed: float,height: float) -> float:
	return clampf(speed*0.6/(height*1.2),0.3,1.7)
