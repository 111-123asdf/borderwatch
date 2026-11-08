class_name ArenaPerks
extends RefCounted
# v0.7 全量卡池：34 张池内卡 + 6 张进化，37 条联动，8 个套装。

const CARDS := [
 {
  "id": "power",
  "name": "锋芒",
  "axis": "blade",
  "rarity": "common",
  "max": 3,
  "icon": "physical",
  "color": "#e2a34f",
  "ranks": [
   "普攻伤害 +12%",
   "普攻伤害 +24%",
   "普攻伤害 +36%；对满血目标 +15%"
  ],
  "effects": [
   {
    "damage": 0.12
   },
   {
    "damage": 0.12,
    "flat": 1
   },
   {
    "damage": 0.12,
    "full_hp_bonus": 0.15
   }
  ]
 },
 {
  "id": "rapid",
  "name": "疾攻",
  "axis": "blade",
  "rarity": "common",
  "max": 3,
  "icon": "physical",
  "color": "#e2a34f",
  "ranks": [
   "攻速 +10%；每第 5 次攻击 +30%",
   "攻速 +20%；每第 5 次攻击 +30%",
   "攻速 +30%；每第 5 次攻击 +30%"
  ],
  "effects": [
   {
    "attack_speed": 0.1
   },
   {
    "attack_speed": 0.1
   },
   {
    "attack_speed": 0.1
   }
  ]
 },
 {
  "id": "lifesteal",
  "name": "嗜血",
  "axis": "blade",
  "rarity": "common",
  "max": 3,
  "icon": "heart",
  "color": "#e2a34f",
  "ranks": [
   "击杀回复 +4",
   "击杀回复 +8；过量转护盾（上限 30）",
   "击杀回复 +12；护盾上限 30"
  ],
  "effects": [
   {
    "lifesteal": 4
   },
   {
    "lifesteal": 4,
    "shield_cap": 30
   },
   {
    "lifesteal": 4
   }
  ]
 },
 {
  "id": "pierce",
  "name": "破防",
  "axis": "blade",
  "rarity": "rare",
  "max": 2,
  "icon": "physical",
  "color": "#e2a34f",
  "ranks": [
   "无视抗性 +15%",
   "无视抗性 +25%"
  ],
  "effects": [
   {
    "armor_pen": 0.15
   },
   {
    "armor_pen": 0.1
   }
  ]
 },
 {
  "id": "execute",
  "name": "处决",
  "axis": "blade",
  "rarity": "rare",
  "max": 2,
  "icon": "physical",
  "color": "#e2a34f",
  "ranks": [
   "处决阈值 25%，处决伤害 +30%",
   "处决阈值 25%，处决伤害 +45%"
  ],
  "effects": [
   {
    "execute_threshold": 0.25,
    "execute_bonus": 0.3
   },
   {
    "execute_bonus": 0.15
   }
  ]
 },
 {
  "id": "combo",
  "name": "连击",
  "axis": "blade",
  "rarity": "epic",
  "max": 1,
  "icon": "physical",
  "color": "#e2a34f",
  "ranks": [
   "每第 3 次攻击 +80% 伤害"
  ],
  "effects": [
   {
    "combo_every": 3,
    "combo_bonus": 0.8
   }
  ]
 },
 {
  "id": "focus",
  "name": "专注",
  "axis": "star",
  "rarity": "common",
  "max": 3,
  "icon": "skill",
  "color": "#a78bfa",
  "ranks": [
   "技能冷却 −10%",
   "技能冷却 −20%",
   "技能冷却 −30%"
  ],
  "effects": [
   {
    "cooldown": 0.1
   },
   {
    "cooldown": 0.1
   },
   {
    "cooldown": 0.1
   }
  ]
 },
 {
  "id": "starlight",
  "name": "星辉",
  "axis": "star",
  "rarity": "common",
  "max": 3,
  "icon": "magic",
  "color": "#a78bfa",
  "ranks": [
   "技能伤害 +20%；命中施加易伤 3 秒",
   "技能伤害 +40%；命中施加易伤 3 秒",
   "技能伤害 +60%；命中施加易伤 3 秒"
  ],
  "effects": [
   {
    "skill": 0.2
   },
   {
    "skill": 0.2
   },
   {
    "skill": 0.2
   }
  ]
 },
 {
  "id": "burn",
  "name": "灼烧",
  "axis": "star",
  "rarity": "common",
  "max": 3,
  "icon": "magic",
  "color": "#a78bfa",
  "ranks": [
   "灼烧/秒 +3",
   "灼烧/秒 +5",
   "灼烧/秒 +7"
  ],
  "effects": [
   {
    "burn": 3
   },
   {
    "burn": 2
   },
   {
    "burn": 2
   }
  ]
 },
 {
  "id": "echo",
  "name": "回响",
  "axis": "star",
  "rarity": "rare",
  "max": 2,
  "icon": "skill",
  "color": "#a78bfa",
  "ranks": [
   "回响 +20%",
   "回响 +35%"
  ],
  "effects": [
   {
    "echo": 0.2
   },
   {
    "echo": 0.15
   }
  ]
 },
 {
  "id": "chain",
  "name": "连锁",
  "axis": "star",
  "rarity": "rare",
  "max": 2,
  "icon": "magic",
  "color": "#a78bfa",
  "ranks": [
   "技能命中弹射一次（50% 伤害）",
   "弹射两次（75% 伤害）"
  ],
  "effects": [
   {
    "skill": 0.1
   },
   {
    "skill": 0.1
   }
  ]
 },
 {
  "id": "overload",
  "name": "超载",
  "axis": "star",
  "rarity": "epic",
  "max": 1,
  "icon": "skill",
  "color": "#a78bfa",
  "ranks": [
   "大招后 6 秒：攻速 +40%、技能 +20%"
  ],
  "effects": [
   {
    "overload": 1
   }
  ]
 },
 {
  "id": "tough",
  "name": "坚韧",
  "axis": "bulwark",
  "rarity": "common",
  "max": 3,
  "icon": "heart",
  "color": "#4fb3a1",
  "ranks": [
   "最大生命 +12%",
   "最大生命 +24%",
   "最大生命 +36%"
  ],
  "effects": [
   {
    "max_hp": 0.12
   },
   {
    "max_hp": 0.12
   },
   {
    "max_hp": 0.12
   }
  ]
 },
 {
  "id": "ironwall",
  "name": "铁壁",
  "axis": "bulwark",
  "rarity": "common",
  "max": 3,
  "icon": "physical",
  "color": "#4fb3a1",
  "ranks": [
   "拦截减伤 +8%",
   "拦截减伤 +16%",
   "拦截减伤 +24%"
  ],
  "effects": [
   {
    "block_reduction": 0.08
   },
   {
    "block_reduction": 0.08
   },
   {
    "block_reduction": 0.08
   }
  ]
 },
 {
  "id": "battlewill",
  "name": "战意",
  "axis": "bulwark",
  "rarity": "common",
  "max": 3,
  "icon": "physical",
  "color": "#4fb3a1",
  "ranks": [
   "低血伤害 +10%",
   "低血伤害 +20%",
   "低血伤害 +30%"
  ],
  "effects": [
   {
    "low_hp_damage": 0.1
   },
   {
    "low_hp_damage": 0.1
   },
   {
    "low_hp_damage": 0.1
   }
  ]
 },
 {
  "id": "reflect",
  "name": "反震",
  "axis": "bulwark",
  "rarity": "rare",
  "max": 2,
  "icon": "physical",
  "color": "#4fb3a1",
  "ranks": [
   "反弹 +20%",
   "反弹 +35%"
  ],
  "effects": [
   {
    "reflect": 0.2
   },
   {
    "reflect": 0.15
   }
  ]
 },
 {
  "id": "revive",
  "name": "复苏",
  "axis": "bulwark",
  "rarity": "rare",
  "max": 2,
  "icon": "heart",
  "color": "#4fb3a1",
  "ranks": [
   "复活时间 −4",
   "复活时间 −8"
  ],
  "effects": [
   {
    "revive_reduce": 4
   },
   {
    "revive_reduce": 4
   }
  ]
 },
 {
  "id": "unyield",
  "name": "不屈",
  "axis": "bulwark",
  "rarity": "epic",
  "max": 1,
  "icon": "heart",
  "color": "#4fb3a1",
  "ranks": [
   "每局一次免死"
  ],
  "effects": [
   {
    "death_save": 1
   }
  ]
 },
 {
  "id": "command",
  "name": "共战",
  "axis": "command",
  "rarity": "common",
  "max": 3,
  "icon": "flag",
  "color": "#c9a15a",
  "ranks": [
   "光环内塔伤害 +12%",
   "光环内塔伤害 +24%",
   "光环内塔伤害 +36%"
  ],
  "effects": [
   {
    "command_aura": 0.12
   },
   {
    "command_aura": 0.12
   },
   {
    "command_aura": 0.12
   }
  ]
 },
 {
  "id": "armament",
  "name": "军械",
  "axis": "command",
  "rarity": "common",
  "max": 3,
  "icon": "skill",
  "color": "#c9a15a",
  "ranks": [
   "塔攻速 +10%；每第 5 发 +50%",
   "塔攻速 +20%；每第 5 发 +50%",
   "塔攻速 +30%；每第 5 发 +50%"
  ],
  "effects": [
   {
    "tower_speed": 0.1
   },
   {
    "tower_speed": 0.1
   },
   {
    "tower_speed": 0.1
   }
  ]
 },
 {
  "id": "spoils",
  "name": "战利",
  "axis": "command",
  "rarity": "common",
  "max": 3,
  "icon": "coin",
  "color": "#c9a15a",
  "ranks": [
   "击杀金币 +1",
   "击杀金币 +2",
   "击杀金币 +3"
  ],
  "effects": [
   {
    "gold_kill": 1
   },
   {
    "gold_kill": 1
   },
   {
    "gold_kill": 1
   }
  ]
 },
 {
  "id": "farsight",
  "name": "远见",
  "axis": "command",
  "rarity": "rare",
  "max": 2,
  "icon": "target",
  "color": "#c9a15a",
  "ranks": [
   "塔射程 +8%",
   "塔射程 +16%"
  ],
  "effects": [
   {
    "tower_range": 0.08
   },
   {
    "tower_range": 0.08
   }
  ]
 },
 {
  "id": "works",
  "name": "工事",
  "axis": "command",
  "rarity": "rare",
  "max": 2,
  "icon": "build",
  "color": "#c9a15a",
  "ranks": [
   "建造费用 −10%",
   "建造费用 −10%，升级费用 −20%"
  ],
  "effects": [
   {
    "tower_cost": 0.1
   },
   {
    "tower_upgrade": 0.2
   }
  ]
 },
 {
  "id": "horn",
  "name": "号角",
  "axis": "command",
  "rarity": "epic",
  "max": 1,
  "icon": "flag",
  "color": "#c9a15a",
  "ranks": [
   "提前开波奖励 ×2；休息 −3 秒"
  ],
  "effects": [
   {
    "rest_bonus": 1,
    "rest_reduce": 3
   }
  ]
 },
 {
  "id": "warcredit",
  "name": "战功",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "icon": "flag",
  "color": "#9aa08e",
  "ranks": [
   "每 10 杀：全塔伤害 +5%（最多 5 层）"
  ],
  "effects": [
   {
    "warcredit": 1
   }
  ]
 },
 {
  "id": "citywall",
  "name": "城防",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "icon": "heart",
  "color": "#9aa08e",
  "ranks": [
   "每座塔给英雄 +2% 减伤（最多 8%）"
  ],
  "effects": [
   {
    "citywall": 1
   }
  ]
 },
 {
  "id": "enchant",
  "name": "附魔",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "icon": "magic",
  "color": "#9aa08e",
  "ranks": [
   "技能后 3 秒普攻 +40% 伤害"
  ],
  "effects": [
   {
    "enchant": 0.4
   }
  ]
 },
 {
  "id": "bloodrage",
  "name": "血怒",
  "axis": "bridge",
  "rarity": "epic",
  "max": 1,
  "icon": "physical",
  "color": "#9aa08e",
  "ranks": [
   "每损失 10% 生命 +3% 伤害（最多 30%）"
  ],
  "effects": [
   {
    "bloodrage": 0.3
   }
  ]
 },
 {
  "id": "shieldback",
  "name": "盾反",
  "axis": "knight",
  "rarity": "rare",
  "max": 2,
  "icon": "physical",
  "color": "#c96b5f",
  "ranks": [
   "拦截反弹 15%",
   "再 +10%"
  ],
  "effects": [
   {
    "reflect": 0.15
   },
   {
    "reflect": 0.1
   }
  ],
  "hero": "knight"
 },
 {
  "id": "oath",
  "name": "守誓",
  "axis": "knight",
  "rarity": "epic",
  "max": 1,
  "icon": "flag",
  "color": "#c96b5f",
  "ranks": [
   "战吼 +3 秒；期间全塔 +15%"
  ],
  "effects": [
   {
    "war_cry_bonus": 3
   }
  ],
  "hero": "knight"
 },
 {
  "id": "shadowstep",
  "name": "疾影",
  "axis": "ranger",
  "rarity": "rare",
  "max": 2,
  "icon": "move",
  "color": "#8fbf6a",
  "ranks": [
   "翻滚后 2 秒攻速 +25%",
   "再 +15%"
  ],
  "effects": [
   {
    "roll_boost": 0.25
   },
   {
    "roll_boost": 0.15
   }
  ],
  "hero": "ranger"
 },
 {
  "id": "piercearrow",
  "name": "穿杨",
  "axis": "ranger",
  "rarity": "epic",
  "max": 1,
  "icon": "physical",
  "color": "#8fbf6a",
  "ranks": [
   "普攻 +1 穿透；每第三箭再 +1"
  ],
  "effects": [
   {
    "pierce_bonus": 1
   }
  ],
  "hero": "ranger"
 },
 {
  "id": "frostheart",
  "name": "霜心",
  "axis": "mage",
  "rarity": "rare",
  "max": 2,
  "icon": "frost",
  "color": "#9d86d8",
  "ranks": [
   "霜环半径 +20%",
   "再 +35%"
  ],
  "effects": [
   {
    "frost_bonus": 0.2
   },
   {
    "frost_bonus": 0.35
   }
  ],
  "hero": "mage"
 },
 {
  "id": "starcore",
  "name": "星核",
  "axis": "mage",
  "rarity": "epic",
  "max": 1,
  "icon": "meteor",
  "color": "#9d86d8",
  "ranks": [
   "星陨 +40%、冷却 −4 秒"
  ],
  "effects": [
   {
    "meteor_bonus": 0.4
   }
  ],
  "hero": "mage"
 },
 {
  "id": "sworddance",
  "name": "剑舞",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "icon": "physical",
  "color": "#f2d27a",
  "ranks": [
   "20% 概率追加一次 60% 普攻"
  ],
  "effects": [
   {
    "sworddance": 1
   }
  ],
  "evolution": true,
  "requires": {
   "power": 3,
   "rapid": 3
  }
 },
 {
  "id": "executioner",
  "name": "处刑者",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "icon": "physical",
  "color": "#f2d27a",
  "ranks": [
   "对精英/首领 +25% 伤害"
  ],
  "effects": [
   {
    "elite_bonus": 0.25
   }
  ],
  "evolution": true,
  "requires": {
   "pierce": 2,
   "execute": 2
  }
 },
 {
  "id": "frostfire",
  "name": "焚霜",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "icon": "frost",
  "color": "#f2d27a",
  "ranks": [
   "灼烧目标死亡时爆炸（60 半径）"
  ],
  "effects": [
   {
    "frostfire": 1
   }
  ],
  "evolution": true,
  "requires": {
   "burn": 3,
   "chain": 2
  }
 },
 {
  "id": "fortress",
  "name": "堡垒",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "icon": "heart",
  "color": "#f2d27a",
  "ranks": [
   "拦截时每秒回 2% 生命；格挡 +1"
  ],
  "effects": [
   {
    "fortress": 1
   }
  ],
  "evolution": true,
  "requires": {
   "tough": 3,
   "ironwall": 3
  }
 },
 {
  "id": "warmachine",
  "name": "战争机器",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "icon": "skill",
  "color": "#f2d27a",
  "ranks": [
   "同目标连续 3 次攻击后 +20% 伤害（2 层）"
  ],
  "effects": [
   {
    "warmachine": 1
   }
  ],
  "evolution": true,
  "requires": {
   "command": 3,
   "armament": 3
  }
 },
 {
  "id": "goldenage",
  "name": "黄金时代",
  "axis": "evo",
  "rarity": "evo",
  "max": 1,
  "icon": "coin",
  "color": "#f2d27a",
  "ranks": [
   "每波 +25 金币；出售返还 80%"
  ],
  "effects": [
   {
    "wave_gold": 25,
    "sell_bonus": 0.2
   }
  ],
  "evolution": true,
  "requires": {
   "spoils": 3,
   "works": 2
  }
 }
]

const LINKS := [
 {
  "from": "rapid",
  "to": "power",
  "bonus": {
   "damage": 0.04
  }
 },
 {
  "from": "power",
  "to": "execute",
  "bonus": {
   "execute_threshold": 0.05
  }
 },
 {
  "from": "combo",
  "to": "rapid",
  "bonus": {
   "attack_speed": 0.05
  }
 },
 {
  "from": "execute",
  "to": "combo",
  "bonus": {
   "combo_bonus": 0.15
  }
 },
 {
  "from": "lifesteal",
  "to": "combo",
  "bonus": {
   "lifesteal": 2
  }
 },
 {
  "from": "burn",
  "to": "chain",
  "bonus": {
   "burn": 1
  }
 },
 {
  "from": "chain",
  "to": "burn",
  "bonus": {
   "skill": 0.05
  }
 },
 {
  "from": "starlight",
  "to": "burn",
  "bonus": {
   "burn": 1
  }
 },
 {
  "from": "focus",
  "to": "starlight",
  "bonus": {
   "skill": 0.05
  }
 },
 {
  "from": "echo",
  "to": "overload",
  "bonus": {
   "echo": 0.1
  }
 },
 {
  "from": "overload",
  "to": "focus",
  "bonus": {
   "cooldown": 0.03
  }
 },
 {
  "from": "starlight",
  "to": "pierce",
  "bonus": {
   "armor_pen": 0.05
  }
 },
 {
  "from": "pierce",
  "to": "execute",
  "bonus": {
   "execute_bonus": 0.1
  }
 },
 {
  "from": "enchant",
  "to": "starlight",
  "bonus": {
   "enchant": 0.1
  }
 },
 {
  "from": "execute",
  "to": "enchant",
  "bonus": {
   "skill": 0.05
  }
 },
 {
  "from": "lifesteal",
  "to": "tough",
  "bonus": {
   "max_hp": 0.05
  }
 },
 {
  "from": "tough",
  "to": "ironwall",
  "bonus": {
   "block_reduction": 0.03
  }
 },
 {
  "from": "ironwall",
  "to": "reflect",
  "bonus": {
   "reflect": 0.1
  }
 },
 {
  "from": "unyield",
  "to": "revive",
  "bonus": {
   "revive_reduce": 2
  }
 },
 {
  "from": "revive",
  "to": "ironwall",
  "bonus": {
   "block_reduction": 0.03
  }
 },
 {
  "from": "bloodrage",
  "to": "battlewill",
  "bonus": {
   "low_hp_damage": 0.05
  }
 },
 {
  "from": "battlewill",
  "to": "bloodrage",
  "bonus": {
   "bloodrage": 0.05
  }
 },
 {
  "from": "command",
  "to": "armament",
  "bonus": {
   "tower_damage": 0.05
  }
 },
 {
  "from": "armament",
  "to": "command",
  "bonus": {
   "tower_speed": 0.05
  }
 },
 {
  "from": "warcredit",
  "to": "command",
  "bonus": {
   "tower_damage": 0.05
  }
 },
 {
  "from": "citywall",
  "to": "command",
  "bonus": {
   "block_reduction": 0.03
  }
 },
 {
  "from": "farsight",
  "to": "command",
  "bonus": {
   "tower_range": 0.04
  }
 },
 {
  "from": "works",
  "to": "spoils",
  "bonus": {
   "gold_kill": 1
  }
 },
 {
  "from": "spoils",
  "to": "works",
  "bonus": {
   "tower_cost": 0.03
  }
 },
 {
  "from": "horn",
  "to": "spoils",
  "bonus": {
   "gold_kill": 1
  }
 },
 {
  "from": "spoils",
  "to": "horn",
  "bonus": {
   "wave_gold": 5
  }
 },
 {
  "from": "shieldback",
  "to": "ironwall",
  "bonus": {
   "block_reduction": 0.03
  }
 },
 {
  "from": "oath",
  "to": "command",
  "bonus": {
   "tower_damage": 0.05
  }
 },
 {
  "from": "shadowstep",
  "to": "rapid",
  "bonus": {
   "attack_speed": 0.05
  }
 },
 {
  "from": "piercearrow",
  "to": "combo",
  "bonus": {
   "combo_bonus": 0.1
  }
 },
 {
  "from": "frostheart",
  "to": "focus",
  "bonus": {
   "cooldown": 0.03
  }
 },
 {
  "from": "starcore",
  "to": "starlight",
  "bonus": {
   "skill": 0.05
  }
 }
]

const SETS := [
 {
  "id": "blade3",
  "name": "锋刃 · 三",
  "desc": "任意 3 张锋刃卡",
  "effect": "攻速 +6%",
  "axis": "blade",
  "need": 3,
  "bonus": {
   "attack_speed": 0.06
  }
 },
 {
  "id": "star3",
  "name": "星火 · 三",
  "desc": "任意 3 张星火卡",
  "effect": "冷却 −5%",
  "axis": "star",
  "need": 3,
  "bonus": {
   "cooldown": 0.05
  }
 },
 {
  "id": "bulwark3",
  "name": "壁垒 · 三",
  "desc": "任意 3 张壁垒卡",
  "effect": "生命 +8%",
  "axis": "bulwark",
  "need": 3,
  "bonus": {
   "max_hp": 0.08
  }
 },
 {
  "id": "command3",
  "name": "号令 · 三",
  "desc": "任意 3 张号令卡",
  "effect": "塔攻速 +6%",
  "axis": "command",
  "need": 3,
  "bonus": {
   "tower_speed": 0.06
  }
 },
 {
  "id": "burn3",
  "name": "灼烧 · 三",
  "desc": "灼烧、连锁、焚霜",
  "effect": "灼烧 +2/秒",
  "members": [
   "burn",
   "chain",
   "frostfire"
  ],
  "bonus": {
   "burn": 2
  }
 },
 {
  "id": "expose3",
  "name": "易伤 · 三",
  "desc": "星辉、破防、附魔",
  "effect": "技能伤害 +8%",
  "members": [
   "starlight",
   "pierce",
   "enchant"
  ],
  "bonus": {
   "skill": 0.08
  }
 },
 {
  "id": "shield3",
  "name": "护盾 · 三",
  "desc": "嗜血、坚韧、不屈",
  "effect": "生命 +5%",
  "members": [
   "lifesteal",
   "tough",
   "unyield"
  ],
  "bonus": {
   "max_hp": 0.05
  }
 },
 {
  "id": "cross22",
  "name": "跨轴 · 二二",
  "desc": "任意两轴各 2 张",
  "effect": "伤害 +5%",
  "cross": true,
  "bonus": {
   "damage": 0.05
  }
 }
]

static func card(id: String) -> Dictionary:
	for item in CARDS:
		if item.id == id:
			return item
	return {}

const REAL_LINKS := ["rapid>power","combo>rapid","execute>combo","lifesteal>combo","lifesteal>tough","starlight>burn","burn>chain","chain>burn","starlight>pierce","pierce>execute","execute>enchant","echo>overload","overload>focus","starcore>starlight","command>armament","armament>command","warcredit>command","citywall>command","farsight>command","works>spoils","spoils>works","horn>spoils","spoils>horn"]

static func is_real_link(from: String, to: String) -> bool:
	return has_card(from) and has_card(to)

static func has_card(id: String) -> bool:
	return not card(id).is_empty()
