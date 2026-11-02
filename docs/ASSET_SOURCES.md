# 素材来源与公开范围

使用Pixel Frog Tiny Swords Update 010**旧CC0包**，不是新版Free Pack或付费Enemy Pack。来源、原包SHA256、CC0文本见third_party；原ZIP本机归档，不进Git。运行PNG、Aseprite、导入描述和UID保留可编辑。

英雄立绘/跑步、被动、掩体PNG由前期OpenAI图像生成制作，未直接用商业角色/图标；只有PNG，不虚构分层源文件。持械、预警和部分建筑代码绘制，音效程序合成，系统字体不再分发。见credits.txt和godot-copyright.txt。

`assets/original/` 由本轮 OpenAI 内置图像生成工具制作：`frontier_beacon_title.png` 是森林边哨开场背景，`frontier_menu_button.png` 是透明背景的铜框木牌，`frontier_beacon_core.png` 是青色信标核心，`beacon_clearing.png` 为信标附近的石质空地；`ranger_walk_preview.png` 是圆润风格游侠正面六帧行走样板。提示词要求原创奇幻像素风、不使用现有游戏角色或标志。游侠的攻击和受击尚无专门帧，现用站姿与程序反馈暂代。

`frontier_battlefield_concept.png` 是本轮使用 OpenAI 内置图像生成工具制作的原创森林战场构图样板，包含林缘、废弃营地和旧路痕；当前整体作为地表试用，图中的树石与实际碰撞及建塔规则尚未逐一对应，不能当作最终可交互地图。

`tower_crossbow_preview.png` 是本轮 OpenAI 内置图像生成的原创弩塔样板，使用森林木材、石料与青色旗帜的视觉主题；当前只有单张静态图，尚不是完整攻击动画。

`tower_cannon_preview.png`、`tower_frost_preview.png`、`tower_arc_preview.png` 是本轮参考弩塔的同一主题生成的炮塔、寒霜塔和雷塔样板；当前为静态图。

`tower_venom_preview.png`、`tower_laser_preview.png`、`tower_banner_preview.png` 为参考原创雷塔、使用 OpenAI 内置图像生成工具制作的毒塔、棱塔和战地号令样板；静态图上的毒雾属于美术表现，攻击仍由原有逻辑控制。三张图的塔身和菜单缩略图仍需在对局中确认视觉效果。

`knight_portrait_preview.png` 与 `mage_portrait_preview.png` 为本轮参考原创圆润游侠动作样板、使用 OpenAI 内置图像生成工具制作的骑士和秘术师立绘；骑士手持武器经图像编辑调整为手枪。

`knight_walk_preview.png` 与 `mage_walk_preview.png` 为本轮以各自原创立绘为参考生成的六帧正面行走样板。英雄的攻击和受击仍缺专门帧。

`ranger_bow_preview.png` 为本轮 OpenAI 内置图像生成工具制作的透明背景原创弓箭样板；游戏中按攻击方向旋转显示，握持和拉弓动作仍需后续完善。

`weapon_pistol.png`、`weapon_scatter.png`、`weapon_sniper.png` 为本轮参考原创弓箭的视觉风格、使用 OpenAI 内置图像生成工具批量制作的独立武器图。武器资源独立于英雄身体，可由不同英雄装备；持握与后坐表现仍需试玩调整。

武器掉落及本局武器栏使用 `assets/original/` 中与手持武器一致的原创图：`weapon_pistol.png`、`ranger_bow_preview.png`、`weapon_scatter.png` 和 `weapon_sniper.png`。

`ranger_walk_side.png` 和 `ranger_walk_back.png` 是以游侠正面行走样板为参考生成的侧面、背面六帧行走图；左侧通过侧面镜像显示。其动作连贯性及持弓遮挡仍需真人试玩评估。

`mage_walk_side.png`、`mage_walk_back_v2.png`、`knight_walk_side.png` 与 `knight_walk_back_v2.png` 是以各自正面样板为参考、用 OpenAI 内置图像生成工具制作的六帧方向动作图；人物手部与武器仍分层。方向切换和步幅仍需完整对局的真人体验确认。

`enemy_moth_boss_walk_v2.png` 是以原创森林画面为风格参考、用 OpenAI 内置图像生成工具制作的飞蛾首领四帧振翅图，取代旧版占位外观；仍沿用原 Boss 的战斗逻辑，不代表新增了完整攻击动画。

`enemy_bark_brute_walk.png` 和 `enemy_bark_brute_attack_3.png` 是本轮生成的原创苔石树甲怪行走与攻击帧；`enemy_cinder_fox_walk.png` 和 `enemy_cinder_fox_attack.png` 是原创炭狐行走与攻击帧。炭狐攻击图的前两格互相跨界，因此只使用后两格；受击仍使用闪白反馈。这些都是本轮图像生成工具制作的样板，仍需在完整对局中评估动作观感。

`enemy_forest_wisp_walk.png` 是本轮图像生成工具制作的原创林间幽灵四帧漂浮图，供萨满敌人使用；支援动作暂无独立动画，受击沿用闪白反馈。

源码尚未由负责人指定开放源码许可证，不擅自为团队作品选MIT/CC0。公开用于课程查看和团队协作，不声称任意商业再分发授权；商业发布前继续审阅素材和生成资产权利状态。

公开：源码、运行原素材、测试、开发脚本、必要技术说明和许可。排除：引擎/模板、缓存、发行/ZIP、商业研究图、聊天链接/记忆、密钥、个人配置和未审课程稿。提交前审暂存清单，不只依赖.gitignore。

[Pixel Frog](https://pixelfrog-assets.itch.io/tiny-swords)、[CC0文本](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)、[Godot许可](https://godotengine.org/license/)。
