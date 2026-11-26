# 验证入口

| 检查 | 运行方式与覆盖范围 |
|---|---|
| 源码 | 运行 `./tools/verify.ps1`。导入后执行 `34` 项步骤（`import` + `33` 套无头测试），覆盖规则、布局、经济、长波、物理手感、英雄、怪物、防御塔、前端 UI、章节双军团、程序化裂隙与圣物被动（`v025_combat_and_vfx` 至 `v030_se_balance_proof`）。原条件卡/战令实验脚本（`v017_rules`、`v020_battle_orders`、`v020_conditions`、`v020_passives`、`v07_*`）已退役并由双域被动/圣物/PCG 套件替代。 |
| 实际窗口 | `./tools/verify_window.ps1` 在 `1600×900` 与 `1024×576` 运行 `10` 套菜单、键鼠、战场、工坊与结算回归（共 `20` 次实窗运行）。 |
| 资源审计 | `godot --headless --path . --script res://tests/v06_export_audit.gd` 验证现行核心脚本、英雄/怪物/塔/六关地图/模块化裂隙砖块图集打包引用及退役文件清理（`220` 项检查）。 |
| 正式局 | 运行下方命令。`--level` 可用 `forest`、`creek`、`saltport`、`lighthouse`、`ruins`、`sanctum`，`--hero` 可用 `lord`、`druid`、`healer`、`werewolf`、`gunner`。`--towers=storm,lens,snare,barracks` 可复跑塔阵容，默认永久 1 级，`--hero-level=5` 使用既有等级夹具，局内资源按正常流程结算。自动对局要求进入有效胜负结算，固定种子的胜负预期由三策略验证覆盖。加入 --benchmark --seed=42 可按路段覆盖选塔位、使用关卡机关，并优先集火末波首领。用 --strategy=defense 或 --strategy=rift 对照单域打法，默认执行双域策略。 |
| 导出 | `./tools/export.ps1` 需要 Godot 4.7.2.stable Windows 导出模板。`./tools/verify_export.ps1 -FullPlaythrough` 从隔离目录读取 EXE 内嵌 PCK。单独导出的 PCK 可用 `--main-pack` 运行同一资源审计。 |

~~~powershell
godot --headless --fixed-fps 60 --path . --script res://tests/v06_playthrough.gd -- --hero=lord --level=forest
~~~

## 对照与记录

- 五英雄 5 级试招夹具使用 `./tools/run.ps1 -FeelLab`，四塔机制对照使用 `./tools/run.ps1 -TowerLab -Playtest`。
- `tests/v030_rift_and_passives.gd`、`tests/v029_chapters_and_legions.gd`、`tests/v030_se_balance_proof.gd` 分别负责验证 `ArenaRiftPCG` 连通性与双域被动圣物上限、三章六关长波兽潮与双军团、以及三策略自动对局平衡性证明。
- `tools/capture_v026_showcase.gd`、`capture_v027_frontend.gd` 用于阶段性实机截图夹具。
- 运行测试时隔离 `APPDATA` 与 `LOCALAPPDATA`。项目脚本错误、失败断言及对象泄漏均须排查。

## 金币收支复测

森林用永久 1 级领主、默认塔组，按同一双域打法对比种子 42 和 137。开局都是 300 金。

| 种子 | 调前结算金币 | 调整后结算金币 | 前两波建塔 | 调整后战果 |
|---|---:|---:|---:|---|
| 42 | 12,916 | 638 | 7 座 | 胜利，核心 750 |
| 137 | 6,052 | 31 | 7 座 | 胜利，核心 390 |

调前种子 42 共获得 14,656 金，防御域击杀占 12,323 金。自动对局记录各来源的金币和前两波建塔数。经济回归检查击杀赏金梯度、金币升阶和强化，以及出售时按实付金额退款。改为金币升阶前复跑六关时，17 局均进入结算。双域打法在每关至少通关一次，12 局的余额为 2 至 974 金。

## 现有机制调整的平衡对照

双域用种子 42 和 137 跑六关。森林用 1 级领主、盐港用 4 级爱神，均使用默认塔组。溪谷用 3 级星衡与弓箭、法师、聚光、兵营。灯塔用 4 级狼王与弓箭、法师、跃电、兵营。遗迹用 5 级德鲁伊与弓箭、法师、聚光、兵营。圣所用 5 级领主与跃电、聚光、绊索、兵营。

NORMAL 日志记录胜负、末波首领、漏怪按波次和种类计数、首张被动与首次超武时间、金币收入支出和局外结算。森林、溪谷两关用相同配置复跑纯守线。另以森林种子 42 对照纯裂隙不回防。测试使用正常局内资源。

| 关卡 | 调前通关 / 2 | 调整后通关 / 2 |
|---|---:|---:|
| 森林 | 1 | 2 |
| 溪谷 | 0 | 2 |
| 盐港 | 1 | 2 |
| 灯塔 | 2 | 1 |
| 遗迹 | 0 | 1 |
| 圣所 | 0 | 1 |

调前的盐港种子 42 达到对局步数上限，未进入结算。调整后的 17 局均正常结算。森林和溪谷的四局纯守线都推进到第五波后失守，森林的纯裂隙对照在第三波失守。溪谷复测根据巨魔漏怪记录调整了它的基础生命和移速，两个种子分别以 732 和 598 核心耐久通关。

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
