# 玩法设计参考

## 自选打法 · 官方资料复核

| 资料中能确认的做法 | 本作据此作出的设计选择 |
|---|---|
| 《王国保卫战》官方介绍强调塔的布防、升级和部队指挥。《复仇》的官方更新记录区分波次旗、建塔操作、集结范围和英雄输入。[经典版官方介绍](https://www.ironhidegames.com/Games/kingdom-rush) [《复仇》官方更新](https://www.ironhidegames.com/News/Details/411) | 复用这种操作分工作为本作的参照。玩家负责点塔位、调兵营旗、开波，并用直接输入操作自己的英雄在道路之间接敌。 |
| 《Battle Brothers》的 Ambitions 让玩家在经营佣兵团的过程中选择想追求的方向，候选随队伍和世界状态变化。[Overhype 开发日志](https://battlebrothersgame.com/dev-blog-89-ambitions/) | 让当局的选择体现在玩家接下来会做的事，例如看完来敌后，在整备期重摆塔阵。 |
| 《Orcs Must Die! Deathtrap》把选择放在波间。《Orcs Must Die! 3》Scramble 跨阶段保留所选的双向影响。[波间设计](https://robotentertainment.com/news-archive/2024/8/15/orcs-must-die-deathtrap-our-new-loop-and-progression-systems) [Scramble 设计总监介绍](https://blog.playstation.com/?p=351128) | 首次选择放在开局，之后波间逐次增加。玩家可以在同一局连续使用先前和后来选的打法。 |
| 《杀戮尖塔》通过每局遇到的卡牌和其搭配，让玩家在游玩过程中形成当局构筑。[Mega Crit 官方商店介绍](https://store.steampowered.com/app/646570/Slay_the_Spire/) | 固定地图重复开局时，先换第一张打法，再让后续随机选项改变局中打法。部分规则用不同的代价版本引出不同操作。 |
| 《Into the Breach》在行动前明确预告敌方攻击，让玩家能按预告布置应对。[发行商提供的介绍](https://www.nintendo.com/us/store/products/into-the-breach-switch/) | 来敌预览给玩家布防所需的信息，便于提前判断英雄要亲自去哪一段交战。 |

## 主动操作与回报

| 开发者给出的具体做法 | 在《边境守望》里怎样试 |
|---|---|
| Ubisoft 展示了队友之间怎样打出追击。先让队友准备对移动目标反应射击，再由另一人滑铲把敌人击飞，射程内的队友就会开火。[Ubisoft 战斗实例](https://news.ubisoft.com/en-gb/article/5GejsL2kJa4dT6QEV120qh/how-mario--rabbids-sparks-of-hope-shakes-up-its-formula-and-redefines-tactical-rpgs) | 骑士用一剑把苔甲推回法师塔射界，接下来的一击由塔按自己的装填打出。试玩时看玩家能否认出是哪次推击换来了第二轮塔火。 |
| Robot Entertainment 的设计总监介绍，酸液陷阱给目标施加的状态会提高后续物理伤害，因而摆在它后方的陷阱也会影响它的价值。[《Orcs Must Die! 3》设计总监介绍](https://blog.playstation.com/?p=351128) | 核心的墙能将前队留在炮击范围，再由玩家收墙反推。开墙给已有塔创造了第二次出手机会，是否兑现取决于落点和装填。 |
| Subset Games 在 GDC 复盘中展示了提前揭示敌方攻击，以及让玩家移动敌人来改变战果的设计。[《Into the Breach》设计复盘，第 14、21–22 页](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf) | 回马一击先画能退到哪里。悬赏在押金扣款前亮出三名敌人和过线位置。怎样拦、塔能否及时出手，仍由实时战场决定。 |
| Eremite Games 把限时订单做成玩家可自选的挑战。它可以失败，丰厚回报让玩家愿意临时改变自己的节奏。[《风暴之城》开发日志](https://eremitegames.com/time-is-money-update/) | 前线悬赏用道路半程当期限。提前歼灭三名前锋能多建一座兵营，守后弯的玩家可在本波跳过。60 金押金、80 金奖金按本作塔价起算。 |

搁置的巢穴原型曾参考《Dome Keeper》的外出与回防取舍；该项目的恢复条件见[后续工作](NEXT_STAGE.md)。[开发商介绍](https://store.steampowered.com/app/1637320/Dome_Keeper/)
