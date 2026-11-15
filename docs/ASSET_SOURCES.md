# 当前素材与来源
v0.13局外资产使用assets/v013：新三英雄同框标题、暗调军械厅、多地貌卡通世界、UI皮肤、16个徽章/技能图标、16个通用控件图标、40个成长图标，以及从同一皮肤派生的五张轻量控件纹理。均由内置imagegen为本项目原创生成；原始输出、提示、处理和SHA256见ART_GENERATION_V013.json。负责人明确授权脚本做透明底清理和控件裁切/归一化。概念参考图只研究布局；商业游戏截图和视频不进入游戏/源码包。旧v010局外图片已移出正式工程，保存在外层清理保留目录及v012源码基线；生成记录保留，发行不包含。

v0.12游侠/法师使用assets/v012：六张三方向七状态表、两张透明立绘、两张4×4特效和逐帧区域/脚底/出手点JSON。内置imagegen重新生成，未分发商业参考图。原始生成、编辑提示、SHA256及18项参考取舍见ART_GENERATION_V012.json；骑士保持assets/v011。

新增11个CC0采样约81KB：Kenney Impact Sounds、Vehicle/Jan Schupke的Tinysized SFX、bart（原Stephan/pdsounds）的Ice Spells。逐文件来源和处理见AUDIO_V012.json，声明见third_party/hero_audio_v012。

v0.11骑士使用assets/v011/knight_side/down/up.png与透明portrait_knight.png；形象根据负责人反馈改为露面、蓝黑短发带银色前发、银甲红披风的青年卡通剑士。每方向56个关键姿势，按原始PNG实际透明轮廓切片；未用Python修改图片。physical_fx.png为四行四列的刀光、命中、震地和战吼特效。原始输出与完整提示见ART_GENERATION_V011.json。三视设定稿放在工程外的美术参考，不作为运行背景。

assets/v011/audio的16个OGG选自Kenney RPG Audio与Impact Sounds，逐文件来源、SHA256和CC0-1.0许可见AUDIO_V011.json，两包原始许可保存在third_party/kenney_audio。只带使用的文件，未携带整个下载包。来源：https://kenney.nl/assets/rpg-audio 与 https://kenney.nl/assets/impact-sounds 。商业参考角色只研究青年气质、轮廓和色块，不打包其图片或录音。
历史v0.10曾使用assets/v010（现已移出工程）：同场景守线封面、标题图、多地貌大陆地图、中性前哨庭院、八个功能图标和四格材质。全部为内置imagegen生成的PNG；原始输出保持，透明范围以AtlasTexture使用，界面材质用九宫格拉伸。选定输出、完整提示及校验见ART_GENERATION_V010.json。早期全绿地图、森林营地和四屏视觉稿只作为迭代参考，未加入运行工程。

负责人提供的视频仅研究标题/世界/英雄/图鉴的层级与操作；不打入源码或成品。配色和地貌按最新需求设计成多地区世界，当前两个真实关卡仍在森林区域。局外界面不使用商业游戏的截图、图标、录音或代码。

旧英雄对照、当前地表、塔与空地基使用assets/v09/*.png；生成的森林生物、士兵与场景道具沿用assets/v06/creature_*.png及props.png；旧菜单木牌已退出运行并移出工程。所有当前图片使用OpenAI内置imagegen为本项目生成；仅有PNG输出，不声称具备手绘逐层源文件或实际3D模型。

三张portrait为英雄养成和出战立绘。九张knight/ranger/mage的side/down/up表，每张十二列七行，顺序为待机、移动、普攻、小技能、大招、受击、倒下，专属武器画入完整人物。运行按状态采用6／8／10／10／12／4／6帧。v09改为年轻、柔和体积光与精致塑形的原创职业形象，衣着色彩与武器标志延续本项目设计。

七张creature表为炭狐、苔甲、幽光、投矛手、孢囊兽、飞蛾及士兵，六列三行，分别走动／攻击／倒下。保留项目前期生成的森林生物种类，重新生成完整序列，不恢复最初的占位怪。透明底提取也通过imagegen完成。

towers.png为四列三行，四列依次弓箭塔、法师塔、火炮塔、兵营，三行依次一级至三级，共十二套建筑形态；v09统一地基接触面，强化俯视体积。site_pad为空塔位石土环，透明边距由AtlasTexture裁切，不改写源图。props.png为四列两行的树、岩、遗址、营地与信标。v09的map_forest与map_creek基于已验收地表去除旧烘焙塔环，道路、营地、地标和不对称双桥保持；塔位单独绘制。实际通路、碰撞、射界以ArenaLevelCatalog与检查为准。

旧v06生成记录见ART_GENERATION.json，v09选定输出、提示与文件校验见ART_GENERATION_V09.json。记录不包含失败稿或私人聊天。旧v06人物、地图与塔图不再运行，已移至外层清理保留目录，逐文件SHA256验证原件保持；不再进入源码包。七种森林生物和props仍在工程。先前删除审批被阻止，本次未重试删除旧图，采用原件保留的可逆归档。负责人提供的17张商业游戏立绘参考保存在工程外的美术参考，公开实机与攻略只供构图、比例、动作研究，不直接打进成品。研究链接见MOTION_ART_DIRECTION.md。

骑士挥剑、命中、重击、击杀、震地、战吼和草地脚步使用上述真实采样；其余未覆盖类别保留ArenaAudio合成音，实验场原版切换回合成音。运行字体由系统／Godot提供，不分发Windows字体文件。Godot与第三方引擎声明见godot-copyright.txt。

历史版本曾使用Tiny Swords旧CC0包及CC0武器图，v0.6已不再引用；其来源与许可仍保留在third_party和Git历史。项目源码尚未由团队指定开放源码许可证，不擅自选MIT或CC0授权团队作品。
