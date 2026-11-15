"""List real author-dated commits reachable from the integration's two parents."""
from datetime import datetime
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
revisions = ['HEAD', 'origin/main']
merge = root / '.git/MERGE_HEAD'
if merge.exists():
    revisions += merge.read_text().splitlines()
records = subprocess.check_output(['git', 'log', *revisions, '--format=%H%x09%aI%x09%an%x09%s'], cwd=root, text=True, encoding='utf-8')
start = datetime.fromisoformat('2026-11-09T00:00:00+08:00')
end = datetime.fromisoformat('2026-11-16T00:00:00+08:00')
members = {'黄子衿': {'disguisedbe'}, '田家豪': {'111-123asdf'}, '陈睿智': {'pH0-c'}, '任羽翔': {'U-Siong Dzing', 'lovesherryforever'}}
week = [line.split('\t', 3) for line in records.splitlines() if start <= datetime.fromisoformat(line.split('\t')[1]) < end]
print('第3周：2026-11-09至11-15，按真实作者日期；合并中的另一父历史单独纳入，不伪称均已进入main。')
for name, aliases in members.items():
    found = [record for record in week if record[2] in aliases]
    print(f'{name}: {len(found)} 项真实提交' if found else f'{name}: 本周尚未发现已提交记录（本地开发不等于Git提交）')
    for sha, when, author, subject in found:
        print(f'  {sha[:8]} | {when} | {author} | {subject}')
