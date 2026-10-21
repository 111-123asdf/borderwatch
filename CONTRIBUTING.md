# 四人如何一起开发

公开仓库可读，但直接写入需组长邀请协作者、对方接受；无写权限可先fork并提PR。各用自己的账号和提交邮箱，不共享密码或令牌。

## 第一次接入

1. 注册/登录GitHub，把用户名发给组长。组长在Settings的Collaborators处邀请，接受后才能直接推送。
2. 安装Git、Godot4.7.2 Standard。仓库Code复制HTTPS地址，执行 `git clone 复制的仓库地址`，进入目录。
3. 在本仓库配置自己的身份，推荐GitHub设置的隐私noreply邮箱；不能照抄别人。

```powershell
git config user.name "你自己的用户名"
git config user.email "你自己的GitHub提交邮箱"
git config --get user.name
git config --get user.email
```

4. 冷导入project.godot，F5试玩，按DEVELOPMENT跑测试。不再用旧ZIP覆盖Git目录。

## 每次任务

先用Issue写目标、范围和验收。分工可协商，不把人锁死在一层，不要四人同时改game.gd。

```powershell
git switch main
git pull --ff-only
git switch -c feature/short-task-name
# 完成真实修改并验证
git diff
git add 你实际修改且准备提交的文件
git diff --cached
git commit -m "说明完成了什么"
git push -u origin HEAD
```

到GitHub开PR，写测试、截图和风险；至少另一人看过再由组长合并。这个约定不等于已设置服务端强制保护。不要force-push main，不用reset --hard或clean -fdx清别人的未提交工作。

首次有意义贡献可以是修复可复现问题、添加具体测试、获组长批准的需求/用例文档或有真实记录的试玩报告；不只改空格凑次数。队友ZIP的来源在接入记录注明，不伪造其过去Git提交。

## 课程节奏

每周至少一次全员碰头，建议周三20:00，须四人确认。会后写当周周志：进展、障碍、决策与理由、AI建议采纳/拒绝依据、下周计划。时间、参与者和贡献必须真实。

课程文档经组长审阅再入docs/course；未审草稿不进首个代码提交。每人尽早完成一次真实成果提交，不攒到期末、不倒签。PR区分已执行、计划执行、未验证；特定种子/构筑全通不是所有玩法都平衡。

参考：[GitHub创建仓库](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)、[协作者访问](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/managing-access-to-your-repository/inviting-collaborators-to-a-personal-repository)。
