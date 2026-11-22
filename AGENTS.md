# 《边境守望》v0.23 接手说明

唯一正式工程为 D:/godot/边境守望。使用 Godot 4.7.2 Standard 与 GL Compatibility，主场景 scenes/arena.tscn。开工前读本文件及 [README](README.md)、[架构](docs/ARCHITECTURE.md)、[测试](docs/TESTING.md) 和 [贡献约定](CONTRIBUTING.md)。

## 合并来源与确认的玩法

- 本地共同基线为 3e666b6，保留本地未提交的领主、德鲁伊、爱神、狼王、星衡及操作时序、四关地形、盐港和 v023 怪物。溪谷按本地十波编排，森林、遗迹、盐港八波。遗迹第五波随已开路线均摊，第八波巨像在 20 秒入场。
- 守线系统来自 [PR #14](https://github.com/111-123asdf/borderwatch/pull/14) 的 46fa2c2。正式战役在开局和非末波清场选祝福及代价，按 B 下令。七塔统一接入四关。保留 assets/towers_v024 的现行塔外观，缺少对应贴图时沿用既有资源。移除精英营地与改造券。课程文档来自 e27465e。
- 保留 v0.22 的永久等级、技能解锁及存档兼容。旧 ID knight、mage、longbow、ranger 对应 lord、healer、werewolf、gunner。迁移读取旧键及已保存的塔阵容。正式用户档 campaign_v3.cfg、独立试玩 playtest_v013.cfg、条件和塔实验各用独立档。--feel-lab 是非持久化的 5 级英雄夹具。

## 代码和美术入口

- scripts/arena 内 arena_game.gd 串联关卡和战斗，arena_rule_deck.gd、arena_defense_orders.gd 管正式选牌和指令，arena_conditions.gd 管条件被动实验。读取波表和地图时从 arena_level_catalog.gd 和 arena_saltport.gd 开始。
- arena_hero.gd、arena_actor.gd 与 arena_companion.gd 管英雄与双狼。arena_tower.gd、arena_tower_trial.gd、arena_attack_timing.gd 管塔。五英雄素材在 assets/heroes_v022，新怪在 assets/monsters_v023，相关复建工具位于 tools。
- 合并前工作区的完整回退包位于 D:/godot/稳定交付包/合并PR14前-正式工程.zip。PR 自带的旧版实测保留在 [分支验收](docs/STAGE_CLOSEOUT.md)，整合版验证看 [测试](docs/TESTING.md)。

## 当前交付

源码、双尺寸窗口和隔离 Windows 成品功能检查全部通过。40 局固定策略自动对局均进入结算，27 胜、13 负。四关战果和复跑命令见 [验证](docs/TESTING.md)。旧版成绩单独保留。真人手感及难度仍待试玩。

第 4 周发布分支为 work/week04-integration-20261122，基于远端 main 的 b2bc5a8。首页接入 PR #15 的布局、进度、出战英雄和键盘焦点，保持四关及五英雄档案。负责人手动提交时将 46fa2c2 记录为第二父提交。周志和日志记录在 docs/course/week-04。助教包用课程材料目录中的 04组-第4周-代码仓库.zip。回退包和原始测试日志在 D:/godot/稳定交付包/第4周交付。

保留实际存档、Git 历史、素材原件、许可和课程材料。Git 暂存、提交、推送及 PR 由负责人手动处理。
