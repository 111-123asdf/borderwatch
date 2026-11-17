# 边境守望 v0.19 · 阶段交付

三英雄、四类三级塔、三关八波。英雄拦怪、躲弹和救场，固定塔位组织防线，营地与局内成长补充构筑。美术、打击感和真人体验仍有提升空间，自动通关不等于体验验收。

## 运行与操作

Windows试玩包解压双击Play.bat，无需Godot。源码用Godot4.7.2 Standard / Compatibility导入project.godot后F5；入口scenes/arena.tscn。外层试玩.bat进入完整流程，试玩-直达第3关.bat进入遗迹。

WASD/方向键移动，右键点地移动，键盘立即覆盖。按住左键普攻并自动锁敌；Q小技能、E大招（永久2/4级解锁）。点塔位建造，点塔升级、出售、选目标或设兵营集结点。英雄倒下15秒复活，基地归零才失败。Esc暂停/取消选点，H手册。怪物按钮点击预览、再次点击提前开波，最多奖励12金。

前两关森林/溪谷全图。第三关遗迹2000×1125、18塔位，第四波破障新增支路；中键/边缘移镜头，M全图、C英雄、G桥、R共鸣。桥等待既有单位通过，分岔后不切换敌人曲线。

--playtest独立playtest_v013.cfg，初始LV.1、9999钻石，重进补足；局内资源正常。正常档campaign_v3.cfg与旧训练档不受影响。--feel-lab是不持久化5级夹具。

## 开发与交付

PowerShell依次执行tools/verify.ps1、tools/verify_window.ps1、tools/export.ps1、tools/verify_export.ps1 -FullPlaythrough；详见docs/TESTING.md。

python tools/package_source.py包含当前工作区和完整.git，排除引擎、缓存、发行程序、录像和测试输出，解压校验CRC、Git和源码哈希。包内未提交成果需结合清单核对，不能只看HEAD。

实际结果和清理边界见docs/STAGE_CLOSEOUT.md，后续方向见docs/NEXT_STAGE.md，来源见docs/ASSET_SOURCES.md。提交快照在工程外交付核对.json；负责人手动运行tools/submit_closeout.ps1，详见外层提交说明。
