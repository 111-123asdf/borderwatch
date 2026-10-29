# 工程架构与修改入口

scenes/main.tscn只有挂game.gd的根Node2D。运行时创建世界、Y排序角色、英雄、弹道、相机、声音、营地和HUD；无后端、.NET或运行下载依赖。

| 模块 | 职责 |
| --- | --- |
| rules.gd | 地图/英雄/武器/塔/路线定义，伤害抗性表 |
| progression.gd | 关卡外英雄等级、经验、升级点、永久属性与本地存档 |
| camp.gd | 营地解锁、遭遇、进度、宝匣与伙伴状态聚合，NODES=1 |
| threat.gd | 随波次/营地变动的压力纯函数，统一敌人血量倍率 |
| game.gd | 组合根、输入、经济、波次、探索、奖励、导航和胜负 |
| hero.gd | CharacterBody2D移动、指令行军、索敌、武器与职业主动 |
| enemy.gd / projectile.gd / tower.gd | 敌人行为、弹道扫掠、自动塔和升级 |
| world.gd / cover.gd | 地形、碰撞、掩体、LOS和AStar阻挡 |
| actor_visual.gd / weapon_rig.gd / turret_visual.gd | 身体逐帧、独立持械、塔表现 |
| hud.gd / minimap.gd | 按需界面、教程、成长路线、地图、设置和结算 |
| effects.gd / sound.gd / art.gd | 绘制反馈、合成短音效、素材缓存 |

营地通过Camp推进，不恢复平行状态数组；压力只从Threat取值。路线走tower_damage_scale、hero_damage_scale、prep_seconds、kill_gold_scale、tower_limit统一入口，pending_group保证互斥。

game.gd仍职责较多、动态属性多；增加英雄/营地/塔会遇固定数量假设，不只扩数组就声称支持。掩体同时影响物理、LOS、扫掠和导航。新增内容沿Rules→行为→表现→获得途径→UI→测试验证。

不在接收任务全盘重构。weapon_drop已移除，不能单独恢复而调用已删除的仓库API。保留定义和当前开放流程不同，恢复系统需负责人确认。
