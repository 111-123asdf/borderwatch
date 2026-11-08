class_name ArenaCombat
extends RefCounted
enum Type { PHYSICAL, MAGIC }
static func resolve(amount: float, kind: int, armour: float, resistance: float, exposure := 0.0, pen := 0.0) -> float:
	var reduction: float=armour if kind==Type.PHYSICAL else resistance
	reduction=maxf(0.0,reduction-pen)
	return maxf(0,amount)*(1.0-clampf(reduction,0,0.8))*(1.0+(exposure if kind==Type.MAGIC else 0.0))
static func colour(kind: int) -> Color:
	return Color("f2cf96") if kind==Type.PHYSICAL else Color("c5a4ff")
static func label(kind: int) -> String:
	return "物理" if kind==Type.PHYSICAL else "法术"
