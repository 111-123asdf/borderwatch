# 游戏素材与来源

新增三塔的三级外观来自项目生成的九宫格图集 assets/v021/towers.png，三列对应跃电塔、聚光塔、绊索工坊。制作方式和随包授权见 [credits.txt](credits.txt)。

- **v0.18 新增引擎混合层（`assets/v018/`）**：
  - `assets/v018/particles/`：选自 [`Calinou/kenney-particle-pack`](https://github.com/Calinou/kenney-particle-pack)（作者 Kenney，CC0 1.0 公共领域许可，保留于 `third_party/kenney_particles/LICENSE.txt`），用于火盆火舌、余烬、步尘、法术光环与命中火花。
  - `assets/v018/site_plinths.png` 与 `assets/v018/ruins_mechanisms.png`：由 `tools/build_v018_props.py`（2x SSAA 程序石雕纹理）生成，提供全三关 2.5D 雕石塔基座（含高台/隘口/脉座/锁位）及第 3 关破障碎石封门、石墩符文吊桥。
  - `scripts/shaders/water_ribbon.gdshader` 与 `painted_ruins.gdshader`：驱动第 2–3 关溪流海岸实时波光与火盆呼吸。

assets/v017：OpenAI内置imagegen为本项目生成四类塔三级形态、六种构装敌人、遗迹地表与核心。塔分别独立设计轮廓，不用同一图反复换色。来源文件和SHA256见ART_GENERATION_V017.json；原始图在工程外美术参考/v017原始生成。已获负责人授权进行裁切、局部遮罩、切片和游戏引擎渲染。

运行是2D混合方案：地表与外观为生成位图，机关／肢体局部动作、阴影、环境色、桥墙细节、水面、光与粒子由代码驱动。构装兼容精灵表重复同一底图以维持状态时钟，实际动作由ArenaConstructRig刚性部件完成，不声称逐帧手绘或真实3D。此段记录 v0.19 的表现方式。当前可玩英雄、狼王形态和冰炎双狼使用 assets/heroes_v022，原张在外层美术参考/heroes_v022_raw，切图脚本为 tools/build_pixel_heroes.py。

参考[Ironhide官方关卡资料](https://play.kingdomrush.com/kingdom-rush-strategy-guide)研究可读道路与火力覆盖；[Godot Cutout](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html)研究部件动画；[CanvasItem shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)确认COLOR语义。商业截图／用户提供参考图不进入运行包。

## 当前仍使用的共享素材

assets/v016/fx_*.png与fx_manifest.json由tools/compile_pixelfx.mjs基于patch-gg/pixelfx生成，原始MIT声明保留在tools/vendor/pixelfx/LICENSE和NOTICE.md。只移出展示站点与演示GIF，生成模块仍保留。v016祭坛等资源仍有运行引用；旧TileMap与像素构装体属于历史实验，不代表当前地图画法。

v011骑士、v012游侠/法师、v013局外界面、v09森林/溪谷地表、v06森林怪物与士兵为此前项目生成美术。当前直接运行的PNG与元数据保留；历史生成清单可从Git历史或收尾前源码归档恢复，不伪称手绘分层源文件。

v011/audio：Kenney RPG Audio与Impact Sounds，CC0-1.0，许可在third_party/kenney_audio。v012/audio：Kenney Impact Sounds、Jan Schupke的Tinysized SFX与bart/Stephan的Ice Spells，许可在third_party/hero_audio_v012。third_party其他历史许可继续保留。

商业角色立绘、用户视频和公开截图仅为构图/动作研究，保存在工程外，不进入运行包。Godot版权见godot-copyright.txt；不分发Windows字体。不擅自为团队源码指定开放源码许可。

v0.19 的运行时表现还包括地面降噪、无字塔位图形、攻击时序、步态、世界步尘、局部反馈和音频并发；均为2D混合实现。素材画法与实际体验仍待负责人反馈，不能由来源声明或自动测试证明好看。

## v0.25–v0.32 新增视觉资源与着色器

- **界面、被动图标与圣物徽章（`assets/ui_v027/`、`assets/ui_v028/`、`assets/ui_v030/`、`assets/ui_v032/`）**：包含主菜单/英雄界面切图、14 项主动特效被动徽章、双域裂隙 HUD 控件与 8 枚八角金边跨界圣物图标，由 `tools/build_frontend_ui_v027.py`、`tools/build_passive_ui_v028.py`、`tools/build_v030_assets.py`、`tools/build_v032_tiles.py` 生成或裁切。
- **三章六关地图与双军团（`assets/maps_v029/`、`assets/monsters_v029_coast/`、`assets/monsters_v029_ruins/`）**：新增盐港/灯塔/遗迹/圣所战场底图与海岸、遗迹两套 12 种敌军精灵表及头像，由 `tools/build_v029_prep.py`、`tools/build_v029_assets.py` 切图打包。
- **裂隙地牢、模块化砖块与粒子特效（`assets/rift_v030/`、`assets/rift_v031/`、`assets/vfx_v031/`、`assets/rift_v032/`、`assets/towers_v024/prop_exit_pillar.png`）**：包含裂隙房间基础素材、传送门/技能序列帧、25 组 `64×64` 模块化生态地砖/墙体/走廊/柱体与 5 组共享交互道具（可引爆晶桶、血祭祭坛、锻造铁砧、星辉底座、深渊下潜传送门），由 `tools/build_v030_assets.py`、`tools/build_v031_assets.py`、`tools/build_v032_tiles.py`、`tools/build_pixel_towers.py` 构建；负责人提供的生成原图在工程外 `美术参考/` 保留并经授权裁切进入工程，不伪称手绘分层源文件。
- **GL Compatibility 着色器（`scripts/shaders/`）**：新增 `magma_zone.gdshader`、`portal_iris.gdshader`、`rift_fog.gdshader` 与 `rift_tile_floor.gdshader`（2D 哈希值噪声房间底纹）。
