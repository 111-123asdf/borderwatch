# 当前验收入口 · v0.19

- tools/verify.ps1：冷导入，以及24套规则、布局、战斗、成长、养成、加载与第三关机制检查。沿用的v06/v015等文件名是测试历史，不代表旧玩法。
- tools/verify_window.ps1：1600×900及1024×576各九套真实窗口事件检查；明确注入资源的展示是视觉夹具。
- tests/v019_inspect_states.gd：三关与塔位五态/图标菜单截图，输出user://v019-inspect；夹具不替代正常流程。
- tests/v019_sample_capture.gd：稀疏/密集战斗表现夹具，注入资源、敌人和进度，不能用作正常资源试玩证据。
- tools/verify_export.ps1 -FullPlaythrough：隔离EXE内嵌PCK运行25套检查，以及永久1/5级×三英雄×三关18条自动通关。LV.5为既有档夹具；局内生命、金币、伤害、死亡和波次时钟不注入。
- tests/v017_stress.gd：18秒压力夹具，预热3秒、12座三级塔、约105活怪；注入资源和HP，仅用于同机帧耗时，不等于真人或所有机器的帧率。
- tools/record_closeout.ps1：隔离PCK录制两关三英雄正常局内资源自动操作；LV.5预设档、45秒剪辑，不是完整通关或真人实录。

实际结果、失败复测和未测项只写STAGE_CLOSEOUT.md；历史记录在RELEASE_NOTES.md。所有测试隔离APPDATA/LOCALAPPDATA，不改写正常存档。错误、失败断言、音频对象泄漏均判失败；仅忽略已知OS证书存储警告。

源码ZIP解压检查CRC、完整.git、git fsck --full、HEAD/工作区清单和所有源码SHA256；--audit进一步在解压副本暂存并核对完整清单。HEAD可能仍是旧提交，未提交成果必须纳入工作区核对。
