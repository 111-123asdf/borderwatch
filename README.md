# 边境守望 核心切片

第四组软件工程实践项目。Godot 4.7.2 Standard / GDScript / 2D俯视角。

玩家控制英雄在**回防与继续探索**之间取舍：塔自动守两条道路，英雄处理威胁和弹幕；出门清营地带回武器、路线选择、金币与防线强化，再迎战六波敌人和最终Boss。

## 当前基线

采用队友2026-10-21交回的core-slice-preview，不是此前完整0.3玩法。内部版本字段仍为0.3.0，以Git提交和[接入记录](docs/INTEGRATION.md)区分版本。

- 三英雄，每人一个主动：骑士临时复制当前武器、游侠翻滚、秘术师清弹结界。
- 三个营地各一个遭遇；宝匣武器直接替换，无掉落仓库和工匠/导师强化店。
- 三组互斥路线各二选一：孤塔/群塔、亲征/指挥、急袭/深耕。击杀升级只加生命，不再升级抽卡。
- 六波、两路防线；弩塔起步，首营地解锁重炮。核心不自修复，攻击塔不吃敌弹，英雄不能入驻。
- 首波90秒自动开始，可F提前确认；波间基础55秒，节奏路线会改变它。

[当前切片](docs/CURRENT_SLICE.md)区分开放内容与保留定义，不能把代码库全部武器宣传为当前可获得。

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify.ps1
```

Windows导出用tools/export.ps1，实际PCK复验用tools/verify_export.ps1；需匹配的Windows x64导出模板。输出在builds/windows-core-slice，不把旧0.3 EXE冒充当前版本。

## 操作

WASD/方向键移动；右键、选中或拖动英雄指定行军；按住左键自动攻击最近有效可见敌人，不向鼠标瞄准、不追怪。Space/C共用一个职业主动。点路边空地建塔，点塔升级/出售。E开宝匣/捷径；R引导回营；F开波；Tab成长；M地图；Esc暂停。详见[试玩说明](docs/playtest.txt)。

开局180金币，弩塔100：不能直接支付两座。可先放一座，利用准备期清首营地取得金币再补防线。

## 开发导航

[环境](docs/DEVELOPMENT.md) · [架构](docs/ARCHITECTURE.md) · [当前玩法](docs/CURRENT_SLICE.md) · [测试](docs/TESTING.md) · [四人协作](CONTRIBUTING.md) · [素材来源](docs/ASSET_SOURCES.md)

AI先读AGENTS.md。课程报告由组长审阅后另行入库；不公开个人对话、未审草稿、商业研究截图和用户配置。源码尚未指定开放源码许可证；公开可读不等于授权任意再分发，第三方素材按各自许可。
