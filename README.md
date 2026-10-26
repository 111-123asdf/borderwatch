# 边境守望 核心切片

第四组软件工程实践项目。Godot 4.7.2 Standard / GDScript / 2D俯视角。

玩家控制英雄在**回防与继续探索**之间取舍：塔自动守两条道路，英雄处理威胁和弹幕；出门清营地带回武器、路线选择、金币与防线强化，再迎战六波敌人和最终Boss。

> **2026-10-24 迁移分支**：主场景已切到 `scenes/arena.tscn`（环形围守 + 三英雄 + 宝匣武器 + 营地路线）。旧 `scenes/main.tscn` 保留，旧模式测试仍显式加载它。迁移映射和未迁内容见[竞技场迁移记录](docs/ARENA_MIGRATION.md)。

## 当前主场景：竞技场

- 三英雄开局选择；骑士双持、游侠翻滚、秘术师清弹结界。
- 8 区域远处刷怪、热点预警、30 秒压力/16 秒休息、Boss。
- 自由网格建塔、塔挡路、不能 8 邻接、流场寻路和路径验证。
- 经验和金币掉落、磁铁拾取、休息结束普通掉落消失。
- 三座营地宝匣给三选一的强力被动（旧路线也并入宝匣池）；起手武器按英雄固定。89 张带武器/职业/元素/塔防/协同的被动、武器三级进化、七塔体系、跨塔群增益、元素交互、稀有度、3 次刷新与 1 次放逐见 [PASSIVE_SYSTEM.md](docs/PASSIVE_SYSTEM.md)；构筑层级见 [PASSIVE_DEPTH.md](docs/PASSIVE_DEPTH.md)；塔设计见 [TOWER_REDESIGN.md](docs/TOWER_REDESIGN.md)；怪物与出怪见 [ENEMY_REDESIGN.md](docs/ENEMY_REDESIGN.md)；打击感见 [COMBAT_FEEL.md](docs/COMBAT_FEEL.md)；第一关 A 方向见 [LEVEL1_A_DIRECTION.md](docs/LEVEL1_A_DIRECTION.md)。
- 操作：WASD 移动，左键自动攻击，**B 建造 / 1-7 或滚轮选塔 / 左键放置**，**右键点塔管理**，**T 全塔目标**，**Space 职业技能**；E 修理，R 重开。
- 入口：`试玩竞技场.bat` 或 `tools/run_arena.ps1`；测试：`tools/verify_arena.ps1`。

## 旧 core-slice 基线（保留）

采用队友2026-10-21交回的core-slice-preview，不是此前完整0.3玩法。内部版本字段仍为0.3.0，以Git提交和[接入记录](docs/INTEGRATION.md)区分版本。

- 三英雄，每人一个主动：骑士临时复制当前武器、游侠翻滚、秘术师清弹结界。
- 三个营地各一个遭遇；宝匣武器直接替换，无掉落仓库和工匠/导师强化店。
- 三组互斥路线各二选一：孤塔/群塔、亲征/指挥、急袭/深耕。击杀升级只加生命，不再升级抽卡。
- 六波、两路防线；弩塔起步，首营地解锁重炮。核心不自修复，攻击塔不吃敌弹，英雄不能入驻。
- 首波90秒自动开始，可F提前确认；波间基础55秒，节奏路线会改变它。

[当前切片](docs/CURRENT_SLICE.md)区分开放内容与保留定义，不能把代码库全部武器宣传为当前可获得。

[竞技场迁移记录](docs/ARENA_MIGRATION.md) · [竞技场测试结论](docs/ARENA_PLAYTEST_FINDINGS.md) · [竞技场计划](docs/PLAN_ARENA_SURVIVAL.md)

## 打开与验证

```powershell
git clone https://github.com/111-123asdf/borderwatch.git
cd borderwatch
```

仓库为私有，需先接受仓库所有者的协作者邀请；克隆时用被邀请的那个账号登录。

1. 从[官方发行页](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)安装 **Godot 4.7.2 Standard**，导入根目录project.godot，等首次导入完成后F5。
2. 主场景只有挂脚本的根节点，世界与UI运行时创建；编辑器空白不是缺地图。
3. Windows可双击开发编辑器.bat；仓库不含编辑器/模板，需设置GODOT_BIN或把Godot加入PATH。本机的便携工具链不进Git。

```powershell
$env:GODOT_BIN = '你的Godot4.7.2可执行文件完整路径'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\doctor.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_arena.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify.ps1
```

Windows导出用tools/export.ps1，实际PCK复验用tools/verify_export.ps1；需匹配的Windows x64导出模板。输出在builds/windows-core-slice，不把旧0.3 EXE冒充当前版本。

## 操作

竞技场主场景：WASD/方向键移动；按住左键自动攻击最近有效敌人；**B 进入/退出建造，1-7 或滚轮选择塔型，左键确认放置，右键取消**；**右键点塔打开塔旁面板**，点塔外/左键攻击/右键空白处关闭；**T 全塔目标**；**Space 职业技能**；E 修理；R 重开。右上角有小地图。旧模式（`scenes/main.tscn`）仍使用原来的右键行军/E 宝匣/F 开波/Tab 成长操作。

竞技场开局 260 金，弩塔 70；正常击杀 + 远端营地宝匣能建到 6 塔左右。旧模式（`scenes/main.tscn`）仍是 180 金 / 弩塔 100，两者不要混用。

## 开发导航

[环境](docs/DEVELOPMENT.md) · [架构](docs/ARCHITECTURE.md) · [当前玩法](docs/CURRENT_SLICE.md) · [竞技场迁移](docs/ARENA_MIGRATION.md) · [测试](docs/TESTING.md) · [四人协作](CONTRIBUTING.md) · [素材来源](docs/ASSET_SOURCES.md)

AI先读AGENTS.md。课程报告由组长审阅后另行入库；不公开个人对话、未审草稿、商业研究截图和用户配置。源码尚未指定开放源码许可证；公开可读不等于授权任意再分发，第三方素材按各自许可。
