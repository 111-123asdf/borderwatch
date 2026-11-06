# 开发与导出
Godot4.7.2 Standard / Compatibility。GODOT_BIN可指定引擎，否则查PATH或上一级toolchain/godot。Windows导出模板须同版本；portable模板在editor_data/export_templates/4.7.2.stable。

导入project.godot后F5。tools/run.ps1运行当前工程，-Editor打开编辑器；tools/doctor.ps1检查环境。两关均可直接进入。

tools/verify.ps1冷导入并验证当前规则、道路布局、技能、存档、素材和失败重开。tests/v06_playthrough.gd可加--hero=knight/ranger/mage及--level=forest/creek，在正常资源下走完整流程。tools/export.ps1生成独立Windows包；tools/verify_export.ps1使用隔离目录的成品PCK复检，不回退源码资源。

更改道路先用v06_layout检查离路距离、建筑间距、射界及碰撞，再按布局作图。更改英雄或怪物须检查连续动作，不能只看立绘。替换PNG后运行tools/build_art_anchors.py更新脚底元数据；这一步需要Python和Pillow，运行游戏不依赖Python。动作策划见MOTION_ART_DIRECTION.md。

课程材料位于docs/course，私人草稿留在外层。测试产物test-results和发行builds不入Git。正常用户存档不清理。手动提交前查看git status与git diff，最终提交、推送和PR由负责人操作。
