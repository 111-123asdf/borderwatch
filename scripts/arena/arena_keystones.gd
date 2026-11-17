class_name ArenaKeystones
extends RefCounted
# Stage 3 ("ruins") Milestone Keystone Relics: awarded exclusively during Rest after waves 2, 4, and 6.
# Designed for high build-defining impact with zero mid-wave combat interruption.

const LIST: Array = [
	{
		"id": "conduit",
		"name": "塔灵共鸣",
		"tag": "技能连携 · 群伤",
		"color": Color("67d4ff"),
		"summary": "每次施放 Q / E，290 范围内防御塔立刻追加协同齐射，并放出弹射 4 敌的 110 伤星弧闪电。",
		"hint": "清群与多塔阵地核心",
	},
	{
		"id": "chrono",
		"name": "时痕回溯",
		"tag": "攻速 · 星陨爆发",
		"color": Color("caa4ff"),
		"summary": "施放 Q 后 4.5 秒内攻速 +55%、移速 +20%；期间每 3 次普攻召唤小星陨震晕，并返还 E 冷却 1.5 秒。",
		"hint": "高频技能与英雄主 C",
	},
	{
		"id": "orbit",
		"name": "御剑晶环",
		"tag": "护身 · 拦截弹幕",
		"color": Color("9ce7be"),
		"summary": "召唤 3 枚绕身星晶旋刃自动斩击近敌（每 0.45 秒 34 伤），每 2.5 秒可击碎 1 发敌方弹幕，击杀加速充能 R。",
		"hint": "近身绞杀与防弹幕",
	},
	{
		"id": "fracture",
		"name": "超载裂痕",
		"tag": "塔英引爆 · 真伤",
		"color": Color("f6c26b"),
		"summary": "防御塔命中敌军时刻下 4 秒「裂痕」；英雄攻击或技能触发裂痕爆破，造成 120% 英雄攻力的真伤冲击波。",
		"hint": "克制重盾傀儡与高抗怪",
	},
	{
		"id": "vanguard",
		"name": "星界禁卫",
		"tag": "兵营质变 · 守线",
		"color": Color("93b9ff"),
		"summary": "全部兵营额外 +1 名士兵，士兵生命 +45%、移速 +25%、脱战回血翻倍，且定期获得吸收护盾与微晕冲锋。",
		"hint": "双路阻截防线铜墙",
	},
	{
		"id": "refract",
		"name": "棱镜折射",
		"tag": "多目标弹射 · 溅射",
		"color": Color("b8f08a"),
		"summary": "英雄、弓箭塔与法师塔飞弹命中后向周围弹射 1 次（65% 伤害，+25% 穿透）；火炮溅射半径 +30%。",
		"hint": "全面放大火力覆盖率",
	},
	{
		"id": "overload_core",
		"name": "共鸣过载",
		"tag": "终极协同 · 刷新",
		"color": Color("7fe8ff"),
		"summary": "共鸣能量获取 +50%；每次释放「星界共鸣斩(R)」立刻刷新 Q 冷却，并永久使英雄伤害 +8%（最多 4 层）。",
		"hint": "大招流高频清场",
	},
	{
		"id": "execute_prism",
		"name": "星陨处决",
		"tag": "斩杀 · 反首领",
		"color": Color("ff937d"),
		"summary": "英雄对精英与首领伤害 +32%；敌军生命低于 22% 时，塔或英雄命中触发处决爆破，额外赏 4 金币与共鸣能量。",
		"hint": "专治高血精英与星界巨像",
	},
	{
		"id": "bastion_ward",
		"name": "圣域护佑",
		"tag": "生存 · 祭坛增幅",
		"color": Color("f3d893"),
		"summary": "英雄阻挡数 +2、所受伤害 -25%、每秒稳定回血 2.5%；在己方祭坛领域内防御塔射程额外 +22%。",
		"hint": "硬扛Boss与祭坛守点",
	},
]

static func by_id(key: String) -> Dictionary:
	for item in LIST:
		if str(item.id) == key:
			return item
	return {}
