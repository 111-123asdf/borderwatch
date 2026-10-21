class_name Camp
extends RefCounted

## 一个探索营地的完整状态：解锁 / 节点进度 / 当前遭遇 / 宝箱 / 救援伙伴。
## 取代原先五个按下标同步的平行数组，营地自己保证状态一致。

const NODES := 1
const FULL_STAGE := 2

var index := 0
var unlocked := false
var cleared := false
var stage := 0
var progress := 0
var encounter_active := false
var chest_claimed := false
var npc_rescued := false
var npc_arrived := false

func _init(camp_index := 0) -> void:
	index = camp_index

## 三个节点清完之前，靠近当前节点就触发遭遇；已肃清或正在战斗则不触发。
func can_start_encounter() -> bool:
	return unlocked and not cleared and not encounter_active

## 返回本次遭遇的节点序号（0..2），供刷怪取点使用。
func begin_encounter() -> int:
	encounter_active = true
	stage = mini(FULL_STAGE, progress + 1)
	return mini(NODES - 1, progress)

## 返回 true 表示这一战清完之后整个营地肃清。
func end_encounter() -> bool:
	encounter_active = false
	progress = mini(NODES, progress + 1)
	if progress >= NODES:
		cleared = true
		stage = FULL_STAGE
		return true
	return false

func can_claim_chest() -> bool:
	return cleared and not chest_claimed

## 返回 true 表示这是第一次开箱。
func claim_chest() -> bool:
	if not can_claim_chest(): return false
	chest_claimed = true
	return true
