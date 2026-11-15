# 开发与导出
下一阶段按[NEXT_PHASE_PLAN.md](NEXT_PHASE_PLAN.md)推进：Codex主实现，冻结新玩法，当前推进v0.13局外界面。视觉规范草案见[ART_BIBLE.md](ART_BIBLE.md)，表现层改动的回归与录屏要求见[FEEL_REGRESSION.md](FEEL_REGRESSION.md)。尚未完成的小样不能写成已验收成果。

Godot4.7.2 Standard / Compatibility。GODOT_BIN可指定引擎，否则查PATH或上一级toolchain/godot。Windows导出模板须同版本；portable模板在editor_data/export_templates/4.7.2.stable。

导入project.godot后F5。tools/run.ps1运行当前工程，-Editor打开编辑器；tools/doctor.ps1检查环境。两关均可直接进入。

tools/verify.ps1冷导入并验证当前规则、道路布局、技能、存档、素材和失败重开；每项检查使用独立的新测试档，持久化测试不会污染基础数值测试。tests/v06_playthrough.gd可加--hero=knight/ranger/mage及--level=forest/creek；默认永久1级新档，不注入局内资源。--hero-level=5为明确标注的既有满级档夹具。tools/export.ps1生成builds/Borderwatch-v0.13-Windows.zip；tools/verify_export.ps1 -FullPlaythrough使用隔离目录的成品PCK复检，覆盖1、5级各三英雄两关，不回退源码资源。

v0.12三英雄表现与实验场见HERO_FEEL_V012.md。tools/record_feel.ps1 -Packed -Hero ranger（或mage/knight）录制有声对照，加-Battle录制前三波正常局内资源自动操作并输出30秒连续摘录。实验场启动加-- --feel-lab，不持久化。切片维护工具只分析PNG并生成元数据，不将Pillow/numpy/OpenCV打入游戏。

局外流程由ArenaFrontEnd维护，材质和图标由ArenaMenuArt维护。新增地区在ArenaLevelCatalog登记ID、世界坐标、区域、故事、map_art/preview_art及战斗规则，不复制界面或假设全部是森林。tests/v010_loadouts验证配置与旧档兼容；v010_window验证世界地图、英雄/塔页、图鉴、设置与直接出战。旧v010演示脚本和录制入口已退出当前工程；现行复现使用tools/record_ui.ps1 -Packed及v013_demo。

更改道路先用v06_layout检查离路距离、建筑间距、射界及碰撞，再按布局作图。更改英雄或怪物须检查连续动作，不能只看立绘。v09建筑接触参数在ArenaBattleArt，人物七状态帧数和释放点在ArenaMotion；v06怪物/道具透明范围元数据由tools/build_art_anchors.py维护。不要将v09重新套用旧六帧锚点。动作策划见MOTION_ART_DIRECTION.md，生成记录见ART_GENERATION_V09.json。

课程材料位于docs/course，私人草稿留在外层。测试产物test-results和发行builds不入Git。正常用户存档不清理。手动提交前查看git status与git diff，最终提交、推送和PR由负责人操作。

python tools/package_source.py把当前工作区与完整.git归档到外层“边境守望-最新源码.zip”，排除引擎、缓存、测试输出和发行程序；随后解压检查CRC、git fsck、HEAD及暂存/工作区文件清单一致，不代提交或改变历史。

局外重构见UI_OVERHAUL_V013.md；tools/run.ps1 -Playtest使用独立资金充足试玩档，正常F5不启用。tools/record_ui.ps1 -Packed录制实际试玩流程与高清截图。tools/prepare_ui_art.py需要可选Pillow/numpy/OpenCV，仅用于授权的透明边缘/裁切处理；运行无该依赖。
