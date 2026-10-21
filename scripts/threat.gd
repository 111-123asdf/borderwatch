class_name Threat
extends RefCounted

## 防线承受的压力：只回答一个问题——第 N 波有多硬。
## 纯函数式，不持有节点引用，可以直接单测。
##
## 压力的两个来源：
##   - 时间：每推进一波自动加压，回不回家都要面对；
##   - 探索：每清一个营地，压力略微上升（带回来的东西也会引来更多）。
## 对抗压力的手段全部来自探索：塔位、重炮、营地武器。

const PER_WAVE := 0.15
const PER_CAMP := 0.05

var exploration := 0.0

func level_for(wave_number: int) -> float:
	return maxf(0.0, float(maxi(0, wave_number - 1)) * PER_WAVE + exploration)

func scale_for(wave_number: int) -> float:
	return 1.0 + level_for(wave_number)

func enemy_health(wave_number: int, base: float) -> float:
	return base * scale_for(wave_number)

func note_camp_cleared() -> void:
	exploration += PER_CAMP

func reset() -> void:
	exploration = 0.0
