# 验证入口

| 检查 | 运行方式与覆盖范围 |
|---|---|
| 源码 | 运行 `./tools/verify.ps1`。导入后执行 `34` 项步骤（`import` + `33` 套无头测试），覆盖规则、布局、经济、长波、物理手感、英雄、怪物、防御塔、前端 UI、章节双军团、程序化裂隙与圣物被动（`v025_combat_and_vfx` 至 `v030_se_balance_proof`）。原条件卡/战令实验脚本（`v017_*`、`v020_battle_orders`、`v020_conditions`、`v020_passives`、`v07_*`）已退役并由双域被动/圣物/PCG 套件替代。 |
| 实际窗口 | `./tools/verify_window.ps1` 在 `1600×900` 与 `1024×576` 运行 `10` 套菜单、键鼠、战场、工坊与结算回归（共 `20` 次实窗运行）。 |
| 资源审计 | `godot --headless --path . --script res://tests/v06_export_audit.gd` 验证现行核心脚本、英雄/怪物/塔/六关地图/模块化裂隙砖块图集打包引用及退役文件清理（`220` 项检查）。 |
| 正式局 | 运行下方命令。`--level` 可用 `forest`、`creek`、`saltport`、`lighthouse`、`ruins`、`sanctum`，`--hero` 可用 `lord`、`druid`、`healer`、`werewolf`、`gunner`。`--towers=storm,lens,snare,barracks` 可复跑塔阵容，默认永久 1 级，`--hero-level=5` 使用既有等级夹具，局内资源按正常流程结算。 |
| 导出 | `./tools/export.ps1` 需要 Godot 4.7.2.stable Windows 导出模板。`./tools/verify_export.ps1 -FullPlaythrough` 从隔离目录读取 EXE 内嵌 PCK。单独导出的 PCK 可用 `--main-pack` 运行同一资源审计。 |

~~~powershell
godot --headless --fixed-fps 60 --path . --script res://tests/v06_playthrough.gd -- --hero=gunner --level=creek
~~~

## 对照与记录

- 五英雄 5 级试招夹具使用 `./tools/run.ps1 -FeelLab`，四塔机制对照使用 `./tools/run.ps1 -TowerLab -Playtest`。
- `tests/v030_rift_and_passives.gd`、`tests/v029_chapters_and_legions.gd`、`tests/v030_se_balance_proof.gd` 分别负责验证 `ArenaRiftPCG` 连通性与双域被动圣物上限、三章六关长波兽潮与双军团、以及三策略自动对局平衡性证明。
- `tools/capture_v026_showcase.gd`、`capture_v027_frontend.gd`、`capture_v028_passive_ui.gd` 用于阶段性实机截图夹具。
- 运行测试时隔离 `APPDATA` 与 `LOCALAPPDATA`。项目脚本错误、失败断言及对象泄漏均须排查。

## 2026-11-25 v0.32.0 双域与程序化地牢验收

- **源码无头回归（`./tools/verify.ps1`）**：`34/34` 步骤全部通过（`SOURCE VERIFICATION PASSED`，`FAILURES: 0`），其中 `v030_rift_and_passives` 通过 `131` 项、`v029_chapters_and_legions` 通过 `132` 项、`v030_se_balance_proof` 通过 `4` 项、`v06_layout` 通过 `23013` 项。
- **导出资源审计（`tests/v06_export_audit.gd`）**：`220/220` 检查全部通过（`FAILURES: 0`）。
- **双尺寸窗口回归（`./tools/verify_window.ps1`）**：`1600×900` 与 `1024×576` 共 `20/20` 次实机窗口测试通过（`FAILURES: 0`）。
- **三策略软件工程平衡性证明（`tests/v030_se_balance_proof.gd`）**：
  - `OnlyRift_NoRecall`（只刷裂隙不回防）：败北（`cycle=3, floors=1, core_hp=0, built=3, rooms=8, kills=353, picks=10, relics=4, run_lv=11, recalls=0`）。
  - `OnlyDefense_NoRift`（只守主域不入裂隙）：败北（`cycle=5, floors=1, core_hp=0, built=6, rooms=0, kills=366, picks=3, relics=0, run_lv=4, recalls=0`）。
  - `DualDomain_Synergy`（双域协同）：胜利（`cycle=5, floors=1, core_hp=750, built=6, rooms=6, kills=755, picks=10, relics=1, run_lv=11, recalls=10`）。

## 2026-11-22 整合验收

通过 31 套源码检查、22 套双尺寸窗口检查和 32 套隔离成品检查。新增选牌、B 键指令和退出选点的窗口回归在 1600×900、1024×576 各通过 99 项。成品资源审计通过 193 项。

用 Windows 成品内嵌资源完成 40 局普通经济、永久 1 或 5 级的自动对局。27 局守住，13 局失守，均进入结算。森林 10/10、溪谷 5/10、遗迹 6/10、盐港 6/10。结果使用固定策略和每轮自动选牌，真人操作、难度和构筑体验仍待试玩。日志位于 D:/godot/稳定交付包/PR14整合，逐局胜负与选牌见验收汇总.json。

## 第 4 周发布复测

首页整合后复跑 31 套源码与 22 套实窗检查。四关均跑完一局并进入结算。键盘首页、四关通关进度及五英雄档案的验证与四局结果见 [第 4 周日志记录](course/week-04/04组-第4周-日志记录.md)。
