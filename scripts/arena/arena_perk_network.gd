class_name ArenaPerkNetwork
extends RefCounted
# Generated from docs/passives-network.html; design preview data, not gameplay.

const AREA := Vector2(1600, 1100)

const CARDS := [
 {
  "id": "power",
  "name": "锋芒",
  "axis": "blade",
  "rarity": "common",
  "max": 3,
  "cluster": "blade",
  "x": 430,
  "y": 175,
  "r": 22,
  "color": "#e2a34f",
  "ranks": [
   "普攻伤害 +12%",
   "+1 固定伤害",
   "对满血目标 +15%"
  ]
 },
 {
  "id": "rapid",
  "name": "疾攻",
  "axis": "blade",
  "rarity": "common",
  "max": 3,
  "cluster": "blade",
  "x": 547,
  "y": 223,
  "r": 22,
  "color": "#e2a34f",
  "ranks": [
   "攻速 +10%",
   "每第 5 次攻击 +30%",
   "改为每第 4 次"
  ]
 },
 {
  "id": "lifesteal",
  "name": "嗜血",
  "axis": "blade",
  "rarity": "common",
  "max": 3,
  "cluster": "blade",
  "x": 595,
  "y": 340,
  "r": 22,
  "color": "#e2a34f",
  "ranks": [
   "击杀回复 4 生命",
   "过量治疗转护盾（上限 30）",
   "护盾期间 +8% 伤害"
  ]
 },
 {
  "id": "execute",
  "name": "处决",
  "axis": "blade",
  "rarity": "rare",
  "max": 2,
  "cluster": "blade",
  "x": 547,
  "y": 457,
  "r": 26,
  "color": "#e2a34f",
  "ranks": [
   "对 <25% 生命目标 +30% 伤害",
   "击杀刷新 Q 冷却 50%"
  ]
 },
 {
  "id": "combo",
  "name": "连击",
  "axis": "blade",
  "rarity": "epic",
  "max": 1,
  "cluster": "blade",
  "x": 430,
  "y": 505,
  "r": 30,
  "color": "#e2a34f",
  "ranks": [
   "每第 3 次攻击追加 80% 伤害；切换目标保留 1 层"
  ]
 },
 {
  "id": "shadowstep",
  "name": "疾影",
  "axis": "ranger",
  "rarity": "rare",
  "max": 2,
  "cluster": "blade",
  "x": 313,
  "y": 457,
  "r": 26,
  "color": "#8fbf6a",
  "ranks": [
   "翻滚后 2 秒攻速 +25%",
   "翻滚后第一击 +100% 伤害"
  ]
 },
 {
  "id": "piercearrow",
  "name": "穿杨",
  "axis": "ranger",
  "rarity": "epic",
  "max": 1,
  "cluster": "blade",
  "x": 265,
  "y": 340,
  "r": 30,
  "color": "#8fbf6a",
  "ranks": [
   "普攻 +1 穿透；每第三箭再 +1；穿透目标 +10% 伤害"
  ]
 },
 {
  "id": "sworddance",
  "name": "剑舞",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "cluster": "blade",
  "x": 313,
  "y": 223,
  "r": 32,
  "color": "#f2d27a",
  "ranks": [
   "20% 概率立即再攻击；每次触发 +5% 攻速（5 层）"
  ]
 },
 {
  "id": "pierce",
  "name": "破防",
  "axis": "blade",
  "rarity": "rare",
  "max": 2,
  "cluster": "expose",
  "x": 800,
  "y": 50,
  "r": 26,
  "color": "#e2a34f",
  "ranks": [
   "无视 15% 对应抗性",
   "对 >30% 抗性目标 +10% 伤害"
  ]
 },
 {
  "id": "enchant",
  "name": "附魔",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "cluster": "expose",
  "x": 887,
  "y": 200,
  "r": 30,
  "color": "#9aa08e",
  "ranks": [
   "技能命中后 3 秒内普攻附加 40% 技能伤害"
  ]
 },
 {
  "id": "executioner",
  "name": "处刑者",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "cluster": "expose",
  "x": 713,
  "y": 200,
  "r": 32,
  "color": "#f2d27a",
  "ranks": [
   "对精英/首领 +25%；击杀精英 +30 金币"
  ]
 },
 {
  "id": "focus",
  "name": "专注",
  "axis": "star",
  "rarity": "common",
  "max": 3,
  "cluster": "star",
  "x": 1170,
  "y": 175,
  "r": 22,
  "color": "#a78bfa",
  "ranks": [
   "技能冷却 −10%",
   "技能命中 −0.3 秒全冷却",
   "击杀 −0.2 秒全冷却"
  ]
 },
 {
  "id": "starlight",
  "name": "星辉",
  "axis": "star",
  "rarity": "common",
  "max": 3,
  "cluster": "star",
  "x": 1276,
  "y": 214,
  "r": 22,
  "color": "#a78bfa",
  "ranks": [
   "技能伤害 +20%",
   "命中施加 10% 易伤 3 秒",
   "易伤可叠 2 层"
  ]
 },
 {
  "id": "burn",
  "name": "灼烧",
  "axis": "star",
  "rarity": "common",
  "max": 3,
  "cluster": "star",
  "x": 1332,
  "y": 311,
  "r": 22,
  "color": "#a78bfa",
  "ranks": [
   "攻击附加 3 秒灼烧（3/5/7 每秒）",
   "灼烧目标死亡爆炸（30/60）",
   "爆炸半径 90"
  ]
 },
 {
  "id": "echo",
  "name": "回响",
  "axis": "star",
  "rarity": "rare",
  "max": 2,
  "cluster": "star",
  "x": 1313,
  "y": 423,
  "r": 26,
  "color": "#a78bfa",
  "ranks": [
   "技能后 3 秒普攻 +20%",
   "期间攻速 +10%"
  ]
 },
 {
  "id": "chain",
  "name": "连锁",
  "axis": "star",
  "rarity": "rare",
  "max": 2,
  "cluster": "star",
  "x": 1226,
  "y": 495,
  "r": 26,
  "color": "#a78bfa",
  "ranks": [
   "技能弹射 1 个目标（50% 伤害）",
   "弹射目标减速 20%"
  ]
 },
 {
  "id": "overload",
  "name": "超载",
  "axis": "star",
  "rarity": "epic",
  "max": 1,
  "cluster": "star",
  "x": 1114,
  "y": 495,
  "r": 30,
  "color": "#a78bfa",
  "ranks": [
   "大招期间攻速 +40%、技能 +20%；大招后 3 秒冷却回复 +50%"
  ]
 },
 {
  "id": "frostheart",
  "name": "霜心",
  "axis": "mage",
  "rarity": "rare",
  "max": 2,
  "cluster": "star",
  "x": 1027,
  "y": 423,
  "r": 26,
  "color": "#9d86d8",
  "ranks": [
   "霜环半径 +20%、减速 +10%",
   "命中 3+ 敌人时冷却 −1 秒"
  ]
 },
 {
  "id": "starcore",
  "name": "星核",
  "axis": "mage",
  "rarity": "epic",
  "max": 1,
  "cluster": "star",
  "x": 1008,
  "y": 311,
  "r": 30,
  "color": "#9d86d8",
  "ranks": [
   "星陨 +40%、冷却 −4 秒；落点燃烧 3 秒"
  ]
 },
 {
  "id": "frostfire",
  "name": "焚霜",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "cluster": "star",
  "x": 1064,
  "y": 214,
  "r": 32,
  "color": "#f2d27a",
  "ranks": [
   "灼烧目标死亡时爆炸并传播灼烧"
  ]
 },
 {
  "id": "tough",
  "name": "坚韧",
  "axis": "bulwark",
  "rarity": "common",
  "max": 3,
  "cluster": "bulwark",
  "x": 430,
  "y": 615,
  "r": 22,
  "color": "#4fb3a1",
  "ranks": [
   "最大生命 +12%",
   "脱战回血 +50%",
   "每秒回复 0.5% 生命"
  ]
 },
 {
  "id": "ironwall",
  "name": "铁壁",
  "axis": "bulwark",
  "rarity": "common",
  "max": 3,
  "cluster": "bulwark",
  "x": 536,
  "y": 654,
  "r": 22,
  "color": "#4fb3a1",
  "ranks": [
   "拦截时近战 −8%",
   "10% 概率完全格挡",
   "20% 概率完全格挡"
  ]
 },
 {
  "id": "battlewill",
  "name": "战意",
  "axis": "bulwark",
  "rarity": "common",
  "max": 3,
  "cluster": "bulwark",
  "x": 592,
  "y": 751,
  "r": 22,
  "color": "#4fb3a1",
  "ranks": [
   "生命 <50% 时伤害 +10%",
   "<30% 时再 +10%",
   "低血击杀回复 5% 生命"
  ]
 },
 {
  "id": "reflect",
  "name": "反震",
  "axis": "bulwark",
  "rarity": "rare",
  "max": 2,
  "cluster": "bulwark",
  "x": 573,
  "y": 863,
  "r": 26,
  "color": "#4fb3a1",
  "ranks": [
   "被近战击中反弹 20% 伤害",
   "反弹变为 80 半径 AoE"
  ]
 },
 {
  "id": "revive",
  "name": "复苏",
  "axis": "bulwark",
  "rarity": "rare",
  "max": 2,
  "cluster": "bulwark",
  "x": 486,
  "y": 935,
  "r": 26,
  "color": "#4fb3a1",
  "ranks": [
   "复活时间 −4 秒",
   "复活时全塔 +20% 攻速 3 秒"
  ]
 },
 {
  "id": "unyield",
  "name": "不屈",
  "axis": "bulwark",
  "rarity": "epic",
  "max": 1,
  "cluster": "bulwark",
  "x": 374,
  "y": 935,
  "r": 30,
  "color": "#4fb3a1",
  "ranks": [
   "每局一次免死；触发后 5 秒 +30% 伤害"
  ]
 },
 {
  "id": "bloodrage",
  "name": "血怒",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "cluster": "bulwark",
  "x": 287,
  "y": 863,
  "r": 30,
  "color": "#9aa08e",
  "ranks": [
   "每损失 10% 生命 +3% 伤害（最多 30%）"
  ]
 },
 {
  "id": "shieldback",
  "name": "盾反",
  "axis": "knight",
  "rarity": "rare",
  "max": 2,
  "cluster": "bulwark",
  "x": 268,
  "y": 751,
  "r": 26,
  "color": "#c96b5f",
  "ranks": [
   "拦截时反弹 15% 近战伤害",
   "触发时获得 2 秒 20% 减伤"
  ]
 },
 {
  "id": "fortress",
  "name": "堡垒",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "cluster": "bulwark",
  "x": 324,
  "y": 654,
  "r": 32,
  "color": "#f2d27a",
  "ranks": [
   "拦截时每秒回复 2% 生命；格挡容量 +1"
  ]
 },
 {
  "id": "command",
  "name": "共战",
  "axis": "command",
  "rarity": "common",
  "max": 3,
  "cluster": "tower",
  "x": 1180,
  "y": 605,
  "r": 22,
  "color": "#c9a15a",
  "ranks": [
   "附近塔 +12% 伤害",
   "半径 240 → 320",
   "士兵也 +12% 伤害"
  ]
 },
 {
  "id": "armament",
  "name": "军械",
  "axis": "command",
  "rarity": "common",
  "max": 3,
  "cluster": "tower",
  "x": 1309,
  "y": 667,
  "r": 22,
  "color": "#c9a15a",
  "ranks": [
   "塔攻速 +10%",
   "每第 5 发 +50% 伤害",
   "改为每第 4 发"
  ]
 },
 {
  "id": "farsight",
  "name": "远见",
  "axis": "command",
  "rarity": "rare",
  "max": 2,
  "cluster": "tower",
  "x": 1341,
  "y": 807,
  "r": 26,
  "color": "#c9a15a",
  "ranks": [
   "塔射程 +8%",
   "对 >250px 目标 +10% 伤害"
  ]
 },
 {
  "id": "warcredit",
  "name": "战功",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "cluster": "tower",
  "x": 1252,
  "y": 919,
  "r": 30,
  "color": "#9aa08e",
  "ranks": [
   "英雄每击杀 10 个敌人，全塔 +5% 伤害（最多 5 层）"
  ]
 },
 {
  "id": "citywall",
  "name": "城防",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "cluster": "tower",
  "x": 1108,
  "y": 919,
  "r": 30,
  "color": "#9aa08e",
  "ranks": [
   "每座塔给英雄 +2% 减伤（最多 8%）"
  ]
 },
 {
  "id": "oath",
  "name": "守誓",
  "axis": "knight",
  "rarity": "epic",
  "max": 1,
  "cluster": "tower",
  "x": 1019,
  "y": 807,
  "r": 30,
  "color": "#c96b5f",
  "ranks": [
   "战吼 +3 秒、范围 +80；期间全塔 +15% 伤害"
  ]
 },
 {
  "id": "warmachine",
  "name": "战争机器",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "cluster": "tower",
  "x": 1051,
  "y": 667,
  "r": 32,
  "color": "#f2d27a",
  "ranks": [
   "塔连续 3 次攻击同目标后 +20% 伤害（2 层）"
  ]
 },
 {
  "id": "spoils",
  "name": "战利",
  "axis": "command",
  "rarity": "common",
  "max": 3,
  "cluster": "economy",
  "x": 800,
  "y": 810,
  "r": 22,
  "color": "#c9a15a",
  "ranks": [
   "击杀 +1 金币",
   "每波开始 +10 金币",
   "出售返还 +10%"
  ]
 },
 {
  "id": "works",
  "name": "工事",
  "axis": "command",
  "rarity": "rare",
  "max": 2,
  "cluster": "economy",
  "x": 900,
  "y": 910,
  "r": 26,
  "color": "#c9a15a",
  "ranks": [
   "建造费用 −10%",
   "升级费用 −20%"
  ]
 },
 {
  "id": "horn",
  "name": "号角",
  "axis": "command",
  "rarity": "epic",
  "max": 1,
  "cluster": "economy",
  "x": 800,
  "y": 1010,
  "r": 30,
  "color": "#c9a15a",
  "ranks": [
   "提前开波奖励 ×2；每提前 5 秒 +3 金币；休息 −3 秒"
  ]
 },
 {
  "id": "goldenage",
  "name": "黄金时代",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "cluster": "economy",
  "x": 700,
  "y": 910,
  "r": 32,
  "color": "#f2d27a",
  "ranks": [
   "每波 +25 金币；出售返还 80%"
  ]
 }
]

const EDGES := [
 {
  "from": "rapid",
  "to": "power",
  "type": "amplify",
  "text": "拥有【锋芒】时，疾攻第 5 次攻击改为第 4 次",
  "req": 0
 },
 {
  "from": "power",
  "to": "execute",
  "type": "amplify",
  "text": "拥有【处决】时，锋芒“满血 +15%”扩展为“>70% 生命 +15%”",
  "req": 0
 },
 {
  "from": "combo",
  "to": "rapid",
  "type": "trigger",
  "text": "连击触发时，疾攻计数 +1",
  "req": 0
 },
 {
  "from": "execute",
  "to": "combo",
  "type": "trigger",
  "text": "处决击杀使连击计数 +1",
  "req": 0
 },
 {
  "from": "lifesteal",
  "to": "combo",
  "type": "convert",
  "text": "护盾存在时，连击伤害 +15%",
  "req": 0
 },
 {
  "from": "burn",
  "to": "chain",
  "type": "trigger",
  "text": "连锁弹射的目标附加灼烧",
  "req": 0
 },
 {
  "from": "chain",
  "to": "burn",
  "type": "amplify",
  "text": "灼烧目标死亡爆炸半径 +30%",
  "req": 0
 },
 {
  "from": "starlight",
  "to": "burn",
  "type": "amplify",
  "text": "易伤目标受到的灼烧伤害 +20%",
  "req": 0
 },
 {
  "from": "focus",
  "to": "starlight",
  "type": "convert",
  "text": "每 10% 冷却缩减使技能伤害 +3%",
  "req": 0
 },
 {
  "from": "echo",
  "to": "overload",
  "type": "amplify",
  "text": "超载期间回响的普攻加成翻倍",
  "req": 0
 },
 {
  "from": "overload",
  "to": "focus",
  "type": "amplify",
  "text": "大招后的冷却回复 +1 秒（有专注再 +1 秒）",
  "req": 0
 },
 {
  "from": "starlight",
  "to": "pierce",
  "type": "amplify",
  "text": "对易伤目标，破防额外无视 10% 抗性",
  "req": 0
 },
 {
  "from": "pierce",
  "to": "execute",
  "type": "amplify",
  "text": "处决阈值从 25% 提高到 30%",
  "req": 0
 },
 {
  "from": "enchant",
  "to": "starlight",
  "type": "amplify",
  "text": "附魔附加的技能伤害吃易伤加成",
  "req": 0
 },
 {
  "from": "execute",
  "to": "enchant",
  "type": "trigger",
  "text": "处决击杀刷新附魔的持续时间",
  "req": 0
 },
 {
  "from": "lifesteal",
  "to": "tough",
  "type": "amplify",
  "text": "护盾上限 +50%",
  "req": 0
 },
 {
  "from": "tough",
  "to": "ironwall",
  "type": "amplify",
  "text": "格挡减伤 +3%",
  "req": 0
 },
 {
  "from": "ironwall",
  "to": "reflect",
  "type": "amplify",
  "text": "反弹伤害 +50%",
  "req": 0
 },
 {
  "from": "unyield",
  "to": "revive",
  "type": "trigger",
  "text": "不屈触发后，复活时间减半",
  "req": 0
 },
 {
  "from": "revive",
  "to": "ironwall",
  "type": "trigger",
  "text": "复活后 3 秒内格挡概率 +30%",
  "req": 0
 },
 {
  "from": "bloodrage",
  "to": "battlewill",
  "type": "amplify",
  "text": "拥有【血怒】时，战意低血阈值 50%→60%",
  "req": 0
 },
 {
  "from": "battlewill",
  "to": "bloodrage",
  "type": "amplify",
  "text": "战意激活时，血怒层数上限 +2",
  "req": 0
 },
 {
  "from": "command",
  "to": "armament",
  "type": "amplify",
  "text": "拥有共战时，军械第 5 发改第 4 发",
  "req": 0
 },
 {
  "from": "armament",
  "to": "command",
  "type": "amplify",
  "text": "共战光环内塔攻速 +5%",
  "req": 0
 },
 {
  "from": "warcredit",
  "to": "command",
  "type": "convert",
  "text": "每层战功使共战加成 +2%",
  "req": 0
 },
 {
  "from": "citywall",
  "to": "command",
  "type": "convert",
  "text": "每座受光环影响的塔，给英雄 +1% 减伤",
  "req": 0
 },
 {
  "from": "farsight",
  "to": "command",
  "type": "amplify",
  "text": "共战光环半径 +40",
  "req": 0
 },
 {
  "from": "works",
  "to": "spoils",
  "type": "convert",
  "text": "每波开始 +5 金（拥有工事时）",
  "req": 0
 },
 {
  "from": "spoils",
  "to": "works",
  "type": "amplify",
  "text": "工事的费用减免 +5%",
  "req": 0
 },
 {
  "from": "horn",
  "to": "spoils",
  "type": "amplify",
  "text": "提前开波每提前 5 秒额外 +3 金",
  "req": 0
 },
 {
  "from": "spoils",
  "to": "horn",
  "type": "amplify",
  "text": "拥有战利时，提前开波奖励 +50%",
  "req": 0
 },
 {
  "from": "shieldback",
  "to": "ironwall",
  "type": "amplify",
  "text": "盾反触发时，格挡概率 +10%",
  "req": 0
 },
 {
  "from": "oath",
  "to": "command",
  "type": "amplify",
  "text": "战吼期间共战光环翻倍",
  "req": 0
 },
 {
  "from": "shadowstep",
  "to": "rapid",
  "type": "amplify",
  "text": "翻滚后攻速与疾攻叠加，且疾攻计数 +1",
  "req": 0
 },
 {
  "from": "piercearrow",
  "to": "combo",
  "type": "trigger",
  "text": "穿透命中使连击计数 +1",
  "req": 0
 },
 {
  "from": "frostheart",
  "to": "focus",
  "type": "amplify",
  "text": "命中 3+ 敌人时冷却 −1 秒；有专精再 −1 秒",
  "req": 0
 },
 {
  "from": "starcore",
  "to": "starlight",
  "type": "amplify",
  "text": "星陨对易伤目标 +20%",
  "req": 0
 },
 {
  "from": "power",
  "to": "sworddance",
  "type": "require",
  "text": "锋芒 3 级",
  "req": 3
 },
 {
  "from": "rapid",
  "to": "sworddance",
  "type": "require",
  "text": "疾攻 3 级",
  "req": 3
 },
 {
  "from": "pierce",
  "to": "executioner",
  "type": "require",
  "text": "破防 2 级",
  "req": 2
 },
 {
  "from": "execute",
  "to": "executioner",
  "type": "require",
  "text": "处决 2 级",
  "req": 2
 },
 {
  "from": "burn",
  "to": "frostfire",
  "type": "require",
  "text": "灼烧 3 级",
  "req": 3
 },
 {
  "from": "chain",
  "to": "frostfire",
  "type": "require",
  "text": "连锁 2 级",
  "req": 2
 },
 {
  "from": "tough",
  "to": "fortress",
  "type": "require",
  "text": "坚韧 3 级",
  "req": 3
 },
 {
  "from": "ironwall",
  "to": "fortress",
  "type": "require",
  "text": "铁壁 3 级",
  "req": 3
 },
 {
  "from": "command",
  "to": "warmachine",
  "type": "require",
  "text": "共战 3 级",
  "req": 3
 },
 {
  "from": "armament",
  "to": "warmachine",
  "type": "require",
  "text": "军械 3 级",
  "req": 3
 },
 {
  "from": "spoils",
  "to": "goldenage",
  "type": "require",
  "text": "战利 3 级",
  "req": 3
 },
 {
  "from": "works",
  "to": "goldenage",
  "type": "require",
  "text": "工事 2 级",
  "req": 2
 }
]

const SETS := [
 {
  "name": "锋刃 · 三",
  "desc": "任意 3 张锋刃卡",
  "effect": "攻速 +6%",
  "axis": "blade"
 },
 {
  "name": "星火 · 三",
  "desc": "任意 3 张星火卡",
  "effect": "冷却 −5%",
  "axis": "star"
 },
 {
  "name": "壁垒 · 三",
  "desc": "任意 3 张壁垒卡",
  "effect": "生命 +8%",
  "axis": "bulwark"
 },
 {
  "name": "号令 · 三",
  "desc": "任意 3 张号令卡",
  "effect": "塔攻速 +6%",
  "axis": "command"
 },
 {
  "name": "灼烧 · 三",
  "desc": "灼烧、连锁、焚霜中 3 张",
  "effect": "灼烧伤害 +50%",
  "members": [
   "burn",
   "chain",
   "frostfire"
  ]
 },
 {
  "name": "易伤 · 三",
  "desc": "星辉、破防、附魔中 3 张",
  "effect": "易伤效果 +5%",
  "members": [
   "starlight",
   "pierce",
   "enchant"
  ]
 },
 {
  "name": "护盾 · 三",
  "desc": "嗜血、坚韧、不屈中 3 张",
  "effect": "护盾上限 +30%",
  "members": [
   "lifesteal",
   "tough",
   "unyield"
  ]
 },
 {
  "name": "跨轴 · 二二",
  "desc": "任意两轴各 2 张",
  "effect": "混合效果（如锋刃+壁垒：拦截时 +8% 伤害）",
  "cross": true
 }
]

const CLUSTERS := [
 {
  "key": "blade",
  "label": "连击 · 锋刃",
  "x": 430,
  "y": 340,
  "r": 210,
  "color": "#e2a34f"
 },
 {
  "key": "expose",
  "label": "易伤 · 锋刃×星火",
  "x": 800,
  "y": 150,
  "r": 145,
  "color": "#d8a7c9"
 },
 {
  "key": "star",
  "label": "灼烧 · 星火",
  "x": 1170,
  "y": 340,
  "r": 210,
  "color": "#a78bfa"
 },
 {
  "key": "bulwark",
  "label": "护盾 · 壁垒",
  "x": 430,
  "y": 780,
  "r": 210,
  "color": "#4fb3a1"
 },
 {
  "key": "tower",
  "label": "塔链 · 号令",
  "x": 1180,
  "y": 770,
  "r": 210,
  "color": "#c9a15a"
 },
 {
  "key": "economy",
  "label": "经济 · 号令",
  "x": 800,
  "y": 910,
  "r": 145,
  "color": "#c9a15a"
 }
]

static func card(id: String) -> Dictionary:
	for item in CARDS:
		if item.id == id:
			return item
	return {}

static func links_to(id: String) -> Array:
	var result: Array = []
	for edge in EDGES:
		if edge.from == id or edge.to == id:
			result.append(edge)
	return result
