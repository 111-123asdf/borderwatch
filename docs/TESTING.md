# 验证入口

| 检查 | 运行方式与覆盖范围 |
|---|---|
| 源码 | 运行 ./tools/verify.ps1。导入后检查关卡、战斗、经济、存档及历史对照模式。正式用例 v020_defense 检查选牌、施工退款、出兵与胜负，v020_battle_orders 检查打法联动和候选过滤，v021_tower_roster 检查工坊替换、旧档与七种塔。 |
| 实际窗口 | ./tools/verify_window.ps1 在 1600×900 与 1024×576 运行菜单、键鼠、战场和结算回归。七塔工坊用例走正式流程，历史界面用例显式传入 --legacy-rules。 |
| 八波正式局 | 运行下方命令。--level 可用 forest、creek、ruins，--hero 可用 knight、ranger、mage。--rule=draw 每轮选一张，省略时走基础守线。--towers=storm,lens,snare,barracks 可复跑新塔阵容。默认永久 1 级，--hero-level=5 使用既有等级夹具，局内资源按正常流程结算。 |
| 导出 | ./tools/export.ps1 需要 Godot 4.7.2.stable Windows 导出模板。./tools/verify_export.ps1 -FullPlaythrough 从隔离目录读取 EXE 内嵌 PCK，覆盖资源、玩法与三英雄 × 三关 × 两档等级。单独导出的 PCK 可用 --main-pack 运行同一资源审计。 |

~~~powershell
godot --headless --fixed-fps 60 --path . --script res://tests/v06_playthrough.gd -- --hero=ranger --level=creek --rule=draw
~~~

## 对照与记录

- 条件卡实验用 ./tools/run.ps1 -ConditionLab -Playtest，使用 condition_lab_v020.cfg。三英雄共用 20 张两阶卡，2–11 级各选一次，每局可重抽一次。更早的 12 卡原型以 --passive-lab 运行。
- 四塔机制对照用 ./tools/run.ps1 -TowerLab -Playtest，使用 tower_lab_v020.cfg。机制检查可注入金币、等级或站位；正常经济回放单独记录。
- tests/v019_inspect_states.gd、v019_sample_capture.gd 用于截图夹具。v017_stress.gd 用 12 座三级塔、约 105 个敌人量帧耗时。tools/record_closeout.ps1 从隔离资源包录制既有 5 级英雄的自动剪辑。
- 运行测试时隔离 APPDATA 与 LOCALAPPDATA。项目脚本错误、失败断言及对象泄漏均须排查。源码包验证包括 CRC、Git 历史完整性、工作区清单、逐文件 SHA256 与解压副本核对。[本轮结果](STAGE_CLOSEOUT.md)
