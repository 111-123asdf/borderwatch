class_name ArenaMotion
extends RefCounted
# Relative holds sum to the actual frame count, keeping animation and damage in sync.
const COUNTS:={"idle":6,"walk":8,"attack":10,"small":10,"ultimate":12,"hurt":4,"down":6}
static func frame_count(state: String) -> int:return int(COUNTS.get(state,6))
static func holds(identity: String,state: String,polished:=true) -> Array:
	var count:=frame_count(state);var result: Array=[];var total:=0.0
	if polished and identity=="knight" and state in ["attack","small","ultimate"]:
		var keys: Array=[1.0,1.1,1.5,1.4,0.7,0.35,0.35,1.0,1.2,1.4] if state!="ultimate" else [1.0,1.1,1.3,1.3,1.0,0.6,0.5,0.7,0.9,1.0,1.1,1.2]
		for weight in keys:total+=float(weight)
		for weight in keys:result.append(float(weight)*count/total)
		return result
	if polished and identity in ["ranger","mage"] and state in ["attack","small","ultimate"]:
		var keys: Array=[]
		if state=="ultimate":keys=[1.0,1.2,1.3,1.4,1.1,0.7,0.45,0.55,0.75,0.9,1.1,1.2]
		elif identity=="ranger" and state=="attack":keys=[0.7,0.9,1.1,1.3,1.5,1.4,0.3,0.45,0.9,1.15]
		elif identity=="ranger":keys=[0.6,0.65,0.8,1.0,1.15,1.2,1.1,0.9,0.8,0.8]
		else:keys=[0.8,1.0,1.35,1.45,1.2,0.35,0.5,0.8,1.0,1.2]
		for weight in keys:total+=float(weight)
		for weight in keys:result.append(float(weight)*count/total)
		return result
	for index in range(count):
		var progress:=float(index)/maxi(1,count-1);var weight:=1.0
		if state in ["attack","small","ultimate"]:
			weight=1.20 if progress<0.4 else (0.55 if progress<0.65 else 1.20)
			if identity=="ranger" and state=="attack" and progress>0.25 and progress<0.45:weight=1.45
		elif state=="hurt":weight=0.55 if index==0 else 1.15
		result.append(weight);total+=weight
	for index in range(count):result[index]=float(result[index])*count/total
	return result
static func release_frame(state: String,identity: String="knight") -> int:
	return 6 if state=="ultimate" or (state=="attack" and identity=="ranger") else 5
static func release_fraction(identity: String,state: String,polished:=true) -> float:
	var weights:=holds(identity,state,polished)
	var elapsed:=0.0
	for index in range(release_frame(state,identity)):elapsed+=float(weights[index])
	return elapsed/float(weights.size())
static func stride_scale(speed: float,height: float) -> float:
	return clampf(speed*0.6/(height*1.2),0.3,1.7)
