# 《边境守望》系统架构总览（v0.32 程序化地牢与割草重构版）

> **工程版本**：`0.32.0`（Godot 4.7.2 · GL Compatibility）  
> **核心定位**：左侧战略塔防主域（Defense）与右侧程序化多层级暗影裂隙（Rift）实时并行的双域耦合防御游戏，以英雄为核心机动/清场主力，通过经验驱动肉鸽被动与跨界圣物反向赋能防线。

---

## 1. 模块分层与核心脚本职责

| 层级 | 核心脚本 / 着色器 | 职责与 v0.32 关键特性 |
| :--- | :--- | :--- |
| **战役与状态中枢** | `scripts/arena/arena_game.gd` | 双域协同主控（`siege_alert_at = 85.0`、`siege_start_at = 95.0`）；永久随时召波 `request_next_wave_anytime()`（`[F]` / 按钮支持休整开波、前哨快进至总攻赏金、堆波 `+45g`）；局内/轮次确定性前哨扰动；`72` 掉落物智能合并与 `110` 特效上限保护；裂隙奇遇事件仲裁（`open_rift_event()` / `choose_rift_event()`）。 |
| **程序化地牢生成** | `scripts/arena/arena_rift_pcg.gd` | `ArenaRiftPCG` 确定性随机种子生成引擎：`5×5` 网格（`GRID_COLS = 5`, `GRID_ROWS = 5`, `TILE_SIZE = 64.0`），按关卡生成 `9..12` 间不规则足迹房间（`hub` / `standard` / `wide_hall` / `tall_arena` / `vault` / `boss_sanctum`），严格连通邻接开门（零假门）、`6` 种房间词缀（`MUTATORS`）、`6` 套柱体/晶桶/加速带/陷阱模板（`TEMPLATES`）与动态 `world_rect` / `grid_bounds`。 |
| **裂隙域与多层下潜** | `scripts/arena/arena_rift_domain.gd`<br>`scripts/shaders/rift_tile_floor.gdshader`<br>`scripts/arena/arena_battle_camera.gd` | `_RiftFloorCanvas` 模块化 `64×64` 砖墙/地砖/走廊平铺与 2D 哈希值噪声着色器；AABB 柱体碰撞；可引爆连锁晶桶（`prop_barrel_crystal`）与 `damage_barrels_in_radius()`；血祭/锻造/星辉三类交互事件祭坛；首领清空后开启深渊下潜传送门 `descend_next_floor()`（2 层起双首领并倍率增益）；`26..48` 怪/房割草波次与动态 `rift_world_rect()` 摄像机钳制。 |
| **跨界圣物与被动引擎** | `scripts/arena/arena_relic_engine.gd`<br>`scripts/arena/arena_passive_engine.gd` | **圣物引擎**（`MAX_RELICS = 6`）：`8` 件跨界圣物（`ember_ordnance`、`chrono_prism`、`orbital_beacon`、`aegis_reactor`、`chain_detonator`、`titan_breaker`、`vampiric_chalice`、`gilded_compass`）与 EventBus 跨界响应。<br>**被动引擎**：`14` 项高表现主动特效被动，`MAX_TOTAL_PICKS = 10` / `MAX_RUN_LEVEL = 11` 纯经验解耦（`xp_needed(lv) = 72 + 52*(lv-1) + 18*(lv-1)^1.45`），满级后经验溢流自动转化为金币与基地圣盾。 |
| **实体与主域塔防** | `scripts/arena/arena_hero.gd`<br>`scripts/arena/arena_tower.gd`<br>`scripts/arena/arena_enemy.gd`<br>`scripts/arena/arena_projectile.gd` | 5 位可控英雄的差异化普攻/技能与裂隙清场机制；塔防主域防御向/联动向自动塔群；杂兵差异化血量系数（主域 `is_swarm_fodder = 0.72x`、裂隙 `0.52x` + 层数缩放）兼顾割草爽感与数值防线压力。 |
| **关卡目录与长波调优** | `scripts/arena/arena_level_catalog.gd`<br>`scripts/arena/arena_saltport.gd` | 全部 6 关（`forest`、`creek`、`saltport`、`lighthouse`、`ruins`、`sanctum`）统一为 `95s` 总攻开启、`95..128s` 轮次长度（`28..36s` 总攻波长）、`55..135` 只/轮高密度兽潮与多首领波次表。 |
| **平视显示与防误触 UI** | `scripts/arena/arena_hud.gd`<br>`scripts/arena/arena_menu_art.gd` | 动态 `5×5` 投影 `_RiftMinimap`（`1370, 72` / `218×204`，整合轮次显示并彻底消除裂隙右上角与 `护盾(B)` / `CallNextWave` 重叠）；永久 `[F] CallNextWave` 按钮、`OwnedRelicsStrip`（`1010, 782`）、`DescentReadyBadge`；奇遇事件与被动三选一 `0.45s`/`0.55s` 防误触保护。 |

---

## 2. 美术资产与构建工具流

- `tools/build_v032_tiles.py` -> 生成 `assets/rift_v032/` 下 `25` 组 `64×64` 生态地砖/墙体/走廊/柱体图集与 `5` 组共享交互道具（`prop_barrel_crystal`、`prop_altar_blood`、`prop_anvil_forge`、`prop_pedestal_choice`、`prop_descent_gate`），以及 `assets/ui_v032/` 下 `8` 枚八角金边圣物图标。
- `tools/verify.ps1`：全量无头回归验证脚本（涵盖规则、布局、经济、波次、物理手感、英雄/怪物/防御塔、章节军团、裂隙 PCG、三策略平衡性证明）。
- `tools/verify_window.ps1`：双分辨率（`1600×900` 与 `1024×576`）实机窗口交互回归。
