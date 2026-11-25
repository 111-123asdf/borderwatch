# 《边境守望》接手指南（v0.32.0）

Codex 和 Antigravity 在 `D:/godot/边境守望` 工作。先运行 `git status -sb` 和 `git log -3 --oneline`，核对队友的新改动，再按负责人在新窗口给的目标动手。当前版本为 `v0.32.0`（分支 `work/v032-dual-domain-20261125`，基于 `main@b14b959`）。工作区源码优先；暂存、提交、推送和 PR 须经负责人明确授权或由负责人手动操作。

## 运行与存档

Godot 4.7.2 Standard，GL Compatibility，入口 `scenes/arena.tscn`。外层「试玩.bat」进入源码试玩，「开发编辑器.bat」打开正式工程。Windows 包里的 `Play.bat` 进战役，`Play-HeroLab.bat` 进五英雄试招场。正式档 `campaign_v3.cfg`，试玩档 `playtest_v013.cfg`；`--feel-lab` 为非持久化 5 级试招夹具。自动验证隔离 `APPDATA` 和 `LOCALAPPDATA`。真实存档、Git 历史、素材原件、许可和课程材料须保留。

## 当前玩法

- **六关与七塔工坊**：三章六关（`forest`、`creek`、`saltport`、`lighthouse`、`ruins`、`sanctum`）共用七塔工坊，每局装备一至四种塔。主域塔位保持简洁，全图统一于 `95s` 开启总攻，总攻波长 `28..36s`（`55..135` 只/轮），支持 `[F]` / 按钮随时召波（休整开波、前哨快进至总攻赏金、堆波 `+45g`）。
- **双域与程序化多层裂隙**：玩家通过 `[T]` / `[R]` 主动召唤传送门往返主域与右侧裂隙。裂隙由 `ArenaRiftPCG` 按随机种子在 `5×5` 网格生成 `9..12` 间不规则房间、严格连通门洞、`6` 种词缀、`6` 套柱体/可引爆晶桶/加速带/陷阱模板与 `26..48` 怪/房割草兽潮；首领清空后开启深渊下潜传送门（2 层起双首领并倍率增益）。
- **纯经验被动与跨界圣物**：`14` 项高表现主动特效被动与房间数彻底解耦，仅绑定裂隙经验曲线（`MAX_TOTAL_PICKS = 10` / `MAX_RUN_LEVEL = 11`），满级后经验溢流自动折算金币与基地圣盾；升级时通过 `[Tab]` 队列与防误触弹窗三选一，不打断战斗。另有 `3` 类奇遇祭坛与 `8` 件跨界圣物（`MAX_RELICS = 6`）反向赋能塔防。
- **英雄与存档兼容**：领主、德鲁伊、爱神、狼王和星衡保留各自的移动及出手时序。永久等级 2、4 解锁 Q、E。旧档英雄 ID（`knight`、`mage`、`longbow`、`ranger`）迁移见 `arena_campaign.gd` 与 `arena_definitions.gd`。

## 从哪里改

- `scripts/arena/` 下：`arena_game.gd` 串联双域战斗、随时召波与事件仲裁；`arena_rift_pcg.gd` 与 `arena_rift_domain.gd` 管程序化地牢、下潜、晶桶与祭坛；`arena_relic_engine.gd` 与 `arena_passive_engine.gd` 管圣物、经验曲线与主动特效被动；`arena_level_catalog.gd` 和 `arena_saltport.gd` 管六关与长波排布。
- 实体与表现：`arena_hero.gd`、`arena_actor.gd`、`arena_companion.gd` 管五英雄与双狼；`arena_tower.gd`、`arena_projectile.gd`、`arena_enemy.gd` 管塔防与割草血量倍率；`arena_hud.gd` 与 `arena_frontend.gd` 管双域 HUD（动态 `5×5` 小地图、圣物栏、防误触弹窗）与首页；着⾊器在 `scripts/shaders/`（`rift_tile_floor.gdshader`、`rift_fog.gdshader`、`portal_iris.gdshader`、`magma_zone.gdshader`）。
- 现行素材：英雄/怪物/塔基础资源在 `assets/heroes_v022`、`assets/monsters_v023`、`assets/towers_v024`；UI/地图/军团/裂隙/特效新资源在 `assets/ui_v027`–`ui_v032`、`assets/maps_v029`、`assets/monsters_v029_coast`、`assets/monsters_v029_ruins`、`assets/rift_v030`–`rift_v032`、`assets/vfx_v031`。
- 详见 [架构](docs/ARCHITECTURE.md)、[测试入口](docs/TESTING.md)、[素材来源](docs/ASSET_SOURCES.md) 和 [贡献约定](CONTRIBUTING.md)。课程周材料在 `docs/course/`。

## 验证与下一轮试玩

`v0.32.0` 正式源码已通过 `tools/verify.ps1` 全部 `34` 项源码步骤（`import` + `33` 套无头测试，含 `v025_combat_and_vfx` 至 `v030_se_balance_proof`，`FAILURES: 0`）、`tests/v06_export_audit.gd`（`220/220` 资源审计全过）与 `tools/verify_window.ps1`（`10` 套脚本 × `1600×900`/`1024×576` 共 `20` 次实窗回归全过）。三策略软件工程平衡性证明（`v030_se_balance_proof.gd`）验证了纯裂隙不回防败北、纯守线不入裂隙败北、双域协同胜利的设计约束。下一轮真人试玩可重点观察多层下潜后的构筑爽感、随时召波赏金节奏以及六关长波割草手感。
