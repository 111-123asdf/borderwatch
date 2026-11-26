# 开发与交付

使用 Godot 4.7.2 Standard、Compatibility 渲染器。启动脚本从 GODOT_BIN、项目或上一级的 toolchain/godot、系统 PATH 找引擎。用 ./tools/run.ps1 -Editor 开编辑器，或用 -Playtest 启动独立试玩。-Playtest -Stage ruins 可直达遗迹。 默认存档目录不可写时，源码试玩改用项目的 _local/playtest 目录。[运行与操作](../README.md)

地图调整先更新 ArenaLevelCatalog 的道路和塔位，再改美术、跑布局回归。heroes_v022 为五英雄及双狼，monsters_v023 为森林和溪谷的新怪，v013 为局外界面，v016 有现用特效，v017 为遗迹与构装，v018 为机关和粒子，v021 为新增三塔。生成工具可用 Python/Node，运行游戏只需 Godot。录制工具可从 PATH 或 toolchain/ffmpeg 找 FFmpeg。[资源来源](ASSET_SOURCES.md)

按源码、窗口、导出和隔离成品的顺序验收。[验证命令](TESTING.md) Windows 产物在 builds/windows。源码交付可用 python tools/package_source.py --output 指定工程外 ZIP，包含当前工作区和完整 .git。tools/audit_submission.py --record 可生成清单，打包时用 --audit 核对清单与解压副本。

负责人在已检查的任务分支手动提交、推送并向 main 开 PR。tools/submit_closeout.ps1 固定指向历史 v0.19 收尾分支和提交说明。引擎、测试输出、缓存、录像、发行包和本地原型备份都在提交范围外。[协作约定](../CONTRIBUTING.md)
