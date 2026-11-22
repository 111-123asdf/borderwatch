# 验证入口

| 检查 | 运行方式与覆盖范围 |
|---|---|
| 源码 | 运行 ./tools/verify.ps1。导入后检查关卡、战斗、经济、存档及历史对照模式。正式用例 v020_defense 检查选牌、施工退款、出兵与胜负，v020_battle_orders 检查打法联动和候选过滤，v021_tower_roster 检查工坊替换、旧档与七种塔。 |
| 实际窗口 | ./tools/verify_window.ps1 在 1600×900 与 1024×576 运行菜单、键鼠、战场和结算回归。七塔工坊用例走正式流程，历史界面用例显式传入 --legacy-rules。 |
| 正式局 | 运行下方命令。--level 可用 forest、creek、ruins、saltport，--hero 可用 lord、druid、healer、werewolf、gunner。--rule=draw 每轮选一张，省略时走基础守线。--towers=storm,lens,snare,barracks 可复跑新塔阵容。默认永久 1 级，--hero-level=5 使用既有等级夹具，局内资源按正常流程结算。 |
| 导出 | ./tools/export.ps1 需要 Godot 4.7.2.stable Windows 导出模板。./tools/verify_export.ps1 -FullPlaythrough 从隔离目录读取 EXE 内嵌 PCK，覆盖资源、玩法与五英雄 × 四关 × 两档等级。单独导出的 PCK 可用 --main-pack 运行同一资源审计。 |

~~~powershell
godot --headless --fixed-fps 60 --path . --script res://tests/v06_playthrough.gd -- --hero=gunner --level=creek --rule=draw
~~~

## 对照与记录

- 条件卡实验用 ./tools/run.ps1 -ConditionLab -Playtest，使用 condition_lab_v020.cfg。五英雄共用 20 张两阶卡，2–11 级各选一次，每局可重抽一次。更早的 12 卡原型以 --passive-lab 运行。
- 四塔机制对照用 ./tools/run.ps1 -TowerLab -Playtest，使用 tower_lab_v020.cfg。机制检查可注入金币、等级或站位；正常经济回放单独记录。
- tests/v019_inspect_states.gd、v019_sample_capture.gd 用于截图夹具。v017_stress.gd 用 12 座三级塔、约 105 个敌人量帧耗时。v022_heroes、v023_monsters 与 saltport_window 验证英雄、怪物及盐港入口。
- 运行测试时隔离 APPDATA 与 LOCALAPPDATA。项目脚本错误、失败断言及对象泄漏均须排查。源码包验证包括 CRC、Git 历史完整性、工作区清单、逐文件 SHA256 与解压副本核对。[PR #14 原始结果](STAGE_CLOSEOUT.md)

## 2026-11-22 整合验收

通过 31 套源码检查、22 套双尺寸窗口检查和 32 套隔离成品检查。新增选牌、B 键指令和退出选点的窗口回归在 1600×900、1024×576 各通过 99 项。成品资源审计通过 193 项。

用 Windows 成品内嵌资源完成 40 局普通经济、永久 1 或 5 级的自动对局。27 局守住，13 局失守，均进入结算。森林 10/10、溪谷 5/10、遗迹 6/10、盐港 6/10。结果使用固定策略和每轮自动选牌，真人操作、难度和构筑体验仍待试玩。日志位于 D:/godot/稳定交付包/PR14整合，逐局胜负与选牌见验收汇总.json。

## 第 4 周发布复测

首页整合后复跑 31 套源码与 22 套实窗检查。四关均跑完一局并进入结算。键盘首页、四关通关进度及五英雄档案的验证与四局结果见 [第 4 周日志记录](course/week-04/04组-第4周-日志记录.md)。
