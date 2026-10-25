# 旧模式内容迁入竞技场（2026-10-24）

本分支把旧 core-slice 的内容迁入环形竞技场，并**把主场景切到 `scenes/arena.tscn`**。旧 `scenes/main.tscn` 保留，现有旧模式测试仍显式加载它，所以没有被删除或改写。

## 迁移映射

| 旧模式内容 | 竞技场实现 |
| --- | --- |
| 三英雄 | 开局英雄选择；骑士/游侠/秘术师使用 `Rules.HEROES` 数值与主动 |
| 骑士主动「火力双生」 | 5 秒双持：一次开火两发，12 秒冷却 |
| 游侠主动「掠影翻滚」 | 0.18 秒翻滚 + 短暂无敌，1.8 秒冷却 |
| 秘术师主动「星纹结界」 | 3.5 秒清弹结界，14 秒冷却 |
| 起手武器 | 骑士铜雀手枪 / 游侠疾风连弓 / 秘术师群星法杖 |
| 三个宝匣 | 三座营地宝匣改为三选一**强力被动**（76 种，含武器专属、职业专属、元素、塔防、协同；营地只出 rare+） |
| 三营地 | 休息期在远端刷一个以 `Rules.CAMP_NAMES` 命名的营地宝匣；拾取给金币并打开强力被动三选一 |
| 三组互斥路线 | 旧路线定义仍保留在 `Rules.RELICS`，但当前宝匣池只给强力被动；路线面板暂不触发 |
| 击杀经验升级 | 升级不再自动加生命；每级弹出三选一强力被动，可叠加 |
| 六波 + Boss | 保留竞技场的 6 轮压力/休息 + Boss，刷怪改为 8 区域环形；Boss 有 66%/33% 召唤阶段 |
| 双车道/固定塔位 | 不迁移；竞技场保留自由建塔、挡路、流场和路径验证 |

## 旧模式中仍保留但不迁移的内容

- 双车道、固定塔位、营地作为地图遭遇、NPC 伙伴、仓库/工匠强化店、Threat 成长、旧标题界面；
- 旧 `Rules` 的 11 武器定义仍保留为素材库；当前可获取的是三英雄起手武器，宝匣不再给武器。
- 旧 `main.tscn` 仍可直接运行：`godot --path . res://scenes/main.tscn`。

## 入口与测试

```powershell
# 当前主场景（竞技场）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_arena.ps1

# 竞技场测试
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_arena.ps1

# 旧模式回归（显式加载 main.tscn）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify.ps1
```

当前竞技场复测：三英雄在自然经济 + 修理下都能通关；英雄血量在 46～230 之间，压力已明显高于迁移前；4 塔边界仍需下一轮复测。

## 风险

- 营地在竞技场里是“远端宝匣”，不是完整遭遇；如果要完整迁移营地战斗，需要另加短遭遇。
- 宝匣现在是强力被动三选一，旧路线面板暂不触发；旧 `Rules.RELICS` 定义保留。
- 旧主线的教程、README 和历史文档仍以旧模式为主，需要下一轮统一。
- 主场景切换后，`tools/export.ps1` / `verify_export.ps1` 需要重新跑；导出 PCK 应加载 arena 主场景，不能再用旧 main 的 PCK 证据。
