# 开发与交付 · v0.19

唯一工程为本目录。Godot4.7.2 Standard / Compatibility，模板匹配4.7.2.stable。引擎由GODOT_BIN、外层toolchain/godot或PATH解析。

## 入口与验证

导入project.godot后F5。tools/run.ps1正常档；-Editor开发；-Playtest独立试玩；-Playtest -Stage ruins直达第三关。Q/E技能，第三关M/C镜头、G桥、R共鸣。

依次运行tools/verify.ps1、tools/verify_window.ps1、tools/export.ps1、tools/verify_export.ps1 -FullPlaythrough。输出builds/windows及Borderwatch-v0.19-Windows.zip。隔离成品从内嵌PCK读资源，不回退源码。

python tools/package_source.py打包工作区和完整.git；--output指定工程外ZIP，--audit验证审核快照并在解压副本验证完整暂存。不代提交/推送。python tools/audit_submission.py --record <工程外JSON>生成快照。

## 素材与录制

道路/塔位先由ArenaLevelCatalog确定，再修改美术和运行布局检查。v017地图/塔/构装部件，v018机关/粒子，v016共享特效，v011/v012英雄，v013局外。v016不是可整删目录。开发生成工具使用可选Python/Node依赖，游戏无需这些运行时。

ArenaAttackTiming管理塔/士兵准备、释放、回落，ArenaMotion管理英雄。构装为2D部件动画；脚底与出手点使用元数据。所有效果需在实际窗口目检。

FFmpeg在PATH或外层toolchain/ffmpeg/ffmpeg.exe。tests/closeout_demo.gd继承正常资源自动策略，使用标注的既有LV.5档。短视频为三段剪辑，不是完整通关或真人录屏。工具tools/record_closeout.ps1从隔离PCK录制并自动裁剪。

## 提交与清理

负责人手动运行tools/submit_closeout.ps1（本地提交）或加-Push（同时推送）；网页创建PR。脚本校验完整快照和远端基线，不强推、不改作者或日期。

不提交引擎、缓存、测试输出、录像、发行包、参考图和课程草稿。正常存档与历史保留。清理后冷导入；最终成品/源码检查通过才更新外层入口。自动删除被安全检查拒绝的项目集中在外层待清理目录，需负责人最终删除。
