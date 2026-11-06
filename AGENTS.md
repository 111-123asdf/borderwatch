# 边境守望开发约定
唯一运行工程为本目录，Godot4.7.2 Standard / Compatibility，入口scenes/arena.tscn。先读README、docs/CURRENT_SLICE.md、ARCHITECTURE.md、DEVELOPMENT.md、TESTING.md及CONTRIBUTING.md。最新负责人需求优先。

当前v0.6：固定道路和塔位、两关各八轮、三职业固定攻击与双技能、四塔三级、兵营士兵和真实拦截、营地与三选一。旧独立武器、背包、能量、护盾与自由建塔退出运行。塔无血量，只有基地失守才整局失败；英雄15秒复活。所有攻击明确物理或法术，不混用抗性。

人物武器画在完整动作帧中，伤害按实际出手帧触发；节奏配置在ArenaMotion。运行美术在assets/v06，怪物全部为生成的森林生物，不能恢复最初Tiny Swords占位怪。参考图留在工程外。

保留Git历史、素材来源与课程资料。正常用户存档不清理；旧v1档不改写，v2验证后迁移。测试隔离APPDATA；夹具不冒充正常资源通关或真人体验；失败先查原因，不删断言求绿。

不自动登录、提交、推送或创建PR。引擎、缓存、测试输出、发行包、ZIP、密钥及未审课程草稿不入Git。
