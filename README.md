# 边境守望 v0.32

五名英雄、七类三级塔、三章六张关卡地图（林地 `forest`、溪谷 `creek`、盐港 `saltport`、灯塔 `lighthouse`、遗迹 `ruins`、圣所 `sanctum`）。采用**左侧战略塔防主域（Defense）+ 右侧程序化多层暗影裂隙（Rift，`ArenaRiftPCG`）**实时并行的双域耦合结构。

主域统一于 `95s` 开启总攻、单轮总攻波长 `28..36s`（`55..135` 只/轮高密度兽潮）；裂隙内以纯经验驱动 `14` 项高表现主动特效被动（`MAX_TOTAL_PICKS = 10` / `MAX_RUN_LEVEL = 11`，满级后经验溢流自动折算金币与基地圣盾），并通过 `3` 类奇遇祭坛收集至多 `6` 件跨界圣物（共 `8` 件）反向赋能防线。

## 运行与操作

Windows 试玩包解压后双击 `Play.bat`。`Play-HeroLab.bat` 进入五英雄的 5 级试招场。源码根目录外层 `试玩.bat` 启动独立试玩档，`开发编辑器.bat` 打开正式工程。工程使用 Godot 4.7.2 Standard（GL Compatibility），主入口 `scenes/arena.tscn`。

- **移动与战斗**：`WASD` 或方向键移动，左键可按住普攻，右键点地，`Q` 小技能，`E` 大招。
- **双域穿梭与随时召波**：`T` / `R` 召唤双域传送门往返主域与裂隙；`F`（或右上角按钮）随时召波（支持休整立刻开波、前哨快进至总攻并领赏金、波次叠加 `+45g`）。
- **构筑与防御指令**：`Tab` 随时打开待选的经验被动三选一（带防误触保护，战斗升级不强制弹窗）；`B` 释放防线圣盾。
- **塔位建造与镜头**：点塔位建造，点塔升阶、出售或换旗，震地炮可指定落点，绊索工坊可换设索路口。`Esc` 暂停或取消选点，`H` 打开手册，`M` 全图、`C` 英雄、`G` 吊桥。

## 开发与验证

正常档使用 `campaign_v3.cfg`，独立试玩使用 `playtest_v013.cfg`，五英雄试招夹具使用 `--feel-lab`。提交前运行 `./tools/verify.ps1` 与 `./tools/verify_window.ps1`。

[工程接手](AGENTS.md) · [系统架构](docs/ARCHITECTURE.md) · [验证入口](docs/TESTING.md) · [素材来源](docs/ASSET_SOURCES.md) · [团队协作](CONTRIBUTING.md)
