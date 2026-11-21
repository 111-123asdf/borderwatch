# 战斗与存档

| 入口 | 职责 |
|---|---|
| ArenaGame、ArenaLevelCatalog | 组装同一战斗场景，按关卡生成道路、塔位和波次队列。待出队列与在场主队清空且该关首领已击杀，才结算末波。 |
| ArenaRuleDeck、ArenaDefenseOrders | 保存本局所选完整配对。按地图、可用兵力、金币和实际波次过滤候选。预览和开波复用队列，击杀、漏怪、清波按事件顺序结算指令。 |
| ArenaCampaign、ArenaFrontEnd | 保存英雄、钻石、阵容、设置及已结算的 run_id。世界地图选塔，部署快照锁定阵容，同局重试沿用。旧 v3 档补默认，异常档保护原件。 |
| ArenaTower、ArenaTowerTrial、ArenaDoctrines | 塔负责施工、目标、攻击与退款。参数区分正式守线和四塔实验，三级改造及双分支使用同一配置入口。 |
| ArenaHero、ArenaSoldier、ArenaBlocking | 英雄直接移动或在 20 像素网格寻路，建塔后更新导航。按单位容量分配拦截；驻军换岗时解除拦截，回到旗位再接敌。 |
| ArenaEnemy、ArenaCombat | 敌人沿 Curve2D 采样并记录道路与进度。击退、分岔与目标预判复用所属道路，伤害显式区分物理和法术。投射物每物理帧共享敌人快照，增删即失效。 |
| ArenaRuinsSiege、ArenaBattleCamera | 管理遗迹破障、封路和一次性援兵。大图镜头支持平移、全图与聚焦，界面坐标通过画布变换投影。 |
| ArenaHUD、ArenaMenuArt | 选牌、预览、指令、塔位菜单与结算。弹窗持有暂停状态，取消选点先于移动或攻击。 |

英雄动作与释放点由 ArenaHeroArt、ArenaMotion 提供，塔和士兵使用 ArenaAttackTiming。ArenaBattleArt 管地表、稳定塔身和局部机关，ArenaConstructRig 按位移驱动二维部件。ArenaAudio 限制同族音效并发。运行资源来自 res://，存档位于 user://。[素材记录](ASSET_SOURCES.md)
