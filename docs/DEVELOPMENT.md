# 开发环境与发布

Godot4.7.2 Standard，Compatibility；Windows脚本兼容PowerShell5.1。Git不包含引擎/模板，第一次克隆后自行安装。Python只为辅助测试，不是游戏运行依赖。

引擎顺序：GODOT_BIN→忽略目录toolchain里的本地便携版→PATH。不要要求队友有相同D盘路径。双击开发编辑器.bat或导入project.godot，首次冷导入后F5运行时生成世界。

```powershell
$env:GODOT_BIN = '你安装的Godot4.7.2控制台程序路径'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\doctor.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run.ps1 -Editor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_export.ps1
python .\tools\native_smoke.py
```

verify冷导入后跑规则、战斗、三英雄完整关卡、支持线夹具和四受限策略。export覆盖builds/windows-core-slice和相应ZIP，需Windows x64模板；verify_export在发行目录显式--path加载EXE内PCK，阻止源码回退。日志在忽略的test-results。native_smoke需要Windows交互桌面，只向自己PID的窗口发输入。

Linux/macOS自行装同版Standard，主要实测Windows。Linux最小检查先 `godot --headless --editor --path . --import --quit`，再 `godot --headless --path . --script res://tests/game_tests.gd` 和combat_tests。本次不额外申请工作流写权限，自动CI配置留本机待审，尚未上传启用；本地测试不等于CI已通过。

提交PNG、Aseprite、.import和.uid，不提交.godot。缺全局类/纹理先查冷导入；console包装器必须与主EXE同目录。仅对本进程使用ExecutionPolicy Bypass，不需永久改系统策略。

设置保存在APPDATA/Borderwatch，未随源码迁移；系统中文字体回退、跨平台画面和低端GPU仍需验证。非headless运行 `--path . --script res://tests/visual_capture.gd` 产生摆位PNG，不能当自然通关。

[Godot数据路径](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)、[GitHub大文件限制](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。源码素材体积小，无需为编辑器/EXE启用LFS；发行二进制另用Release，不塞源码历史。
