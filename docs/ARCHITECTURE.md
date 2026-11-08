# 当前架构
ArenaGame组装唯一战斗场景、地图、固定相机、按脚底排序的Actors、碰撞、导航、波次、成长选择和胜负状态。关卡差异只进入ArenaLevelCatalog；敌人记录route_id与progress，沿同一Curve2D采样。英雄使用CharacterBody2D与静态障碍碰撞；右键路径使用20像素网格，建塔后重建。

ArenaBlocking集中维护敌人与英雄／士兵的拦截关系、容量与释放。塔无生命且不接收敌弹；兵营士兵独立承受近战，阵亡10秒补员。敌人未被拦截就沿道路前进，击退只改变道路进度。营地守卫在home附近行动。

ArenaDefinitions为英雄、敌人、四塔、八类成长的唯一配置。ArenaCombat统一物理／法术与两类抗性；Area、Cone、Projectile、Delayed均显式传伤害类型。魔法易伤只影响法术。漏怪损失由关卡规则计算。

ArenaHero管理职业状态、双技能、经验、被动、脱战回血、倒下复活。ArenaActor使用完整人物与武器动作帧；ArenaMotion配置预备、出手、恢复节奏，动作帧事件与低帧率时钟后备使用同一释放比例。步频随速度变化。ArenaCreature统一敌人与士兵动画；ArenaArtAnchors按图片真实透明范围对齐脚底和建筑接触面。

ArenaHUD负责入口、图卡、图标HUD、固定塔位菜单、开波预览、局内成长与结算。模态和建造屏蔽普攻；右键／Esc优先取消选点。工程没有跨局英雄训练，历史训练存档保持原样且不再读取。ArenaAudio程序生成短音效并显式释放播放器。

所有运行资源在res://，存档在user://。编辑器、测试、导出和外层入口均指向唯一正式工程，不复制第二套玩法脚本。
