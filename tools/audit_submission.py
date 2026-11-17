"""Read-only audit of the complete worktree against origin/main.

The external JSON snapshot is also a staging completeness gate. Does not stage,
commit, rewrite history, or upload. Requires only Python's standard library.
"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_DIRS = {'.git', '.godot', 'test-results', 'builds', '_local', 'toolchain', '__pycache__', '.idea', '.vscode'}
FORBIDDEN_SUFFIXES = {'.exe', '.pck', '.zip', '.tpz', '.pyc', '.log', '.tmp', '.avi', '.mp4', '.mov', '.pem', '.key', '.pfx'}


def git(*args):
    return subprocess.check_output(['git', '-c', 'core.quotepath=false', *args], cwd=ROOT)


def paths(*args):
    return {p.decode('utf-8') for p in git(*args).split(b'\0') if p}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot():
    tracked = paths('ls-files', '-z')
    unknown = paths('ls-files', '--others', '--exclude-standard', '-z')
    existing = sorted(p for p in tracked | unknown if (ROOT / p).is_file())
    for name in existing:
        p = Path(name)
        if set(p.parts) & FORBIDDEN_DIRS or p.suffix.lower() in FORBIDDEN_SUFFIXES or p.name.startswith('.env') or p.name in {'export_credentials.cfg', '.git-credentials'}:
            raise RuntimeError('Unexpected upload candidate: ' + name)
        if (ROOT / p).stat().st_size >= 100 * 1024 * 1024:
            raise RuntimeError('GitHub individual-file limit: ' + name)
    deleted = sorted(tracked - set(existing))
    changed = paths('diff', '--name-only', '-z', 'origin/main') | unknown
    if paths('diff', '--name-only', '--diff-filter=U', '-z'):
        raise RuntimeError('Unresolved merge conflicts')
    main = git('rev-parse', 'origin/main').decode().strip()
    head = git('rev-parse', 'HEAD').decode().strip()
    ancestor = subprocess.run(['git', 'merge-base', '--is-ancestor', main, head], cwd=ROOT).returncode == 0
    same_tree = git('rev-parse', main + '^{tree}') == git('rev-parse', head + '^{tree}')
    if not ancestor and not same_tree:
        raise RuntimeError('Upstream has different source changes; review integration before submitting')
    merge_file = ROOT / '.git/MERGE_HEAD'
    return {
        'format': 1, 'base_main': main, 'head_at_review': head,
        'upstream_is_ancestor': ancestor, 'upstream_tree_equals_head': same_tree,
        'branch': git('branch', '--show-current').decode().strip(),
        'merge_heads': merge_file.read_text().splitlines() if merge_file.exists() else [],
        'files': {p: {'bytes': (ROOT / p).stat().st_size, 'sha256': digest(ROOT / p)} for p in existing},
        'deleted': deleted, 'changed_vs_main': sorted(changed),
        'untracked_required': sorted(unknown),
        'staged_before_review': sorted(paths('diff', '--cached', '--name-only', '-z')),
    }


def verify(expected, staged=False):
    current = snapshot()
    for key in ['base_main', 'files']:
        if current[key] != expected[key]:
            raise RuntimeError('Snapshot mismatch (' + key + '); re-audit before submitting')
    # A real commit removes deleted files from the index, so validate deletions
    # against disk and the eventual stage rather than requiring stale status.
    if any((ROOT / p).exists() for p in expected['deleted']):
        raise RuntimeError('A reviewed deletion reappeared')
    if staged:
        if current['untracked_required'] or git('diff', '--name-only', '-z'):
            raise RuntimeError('Files remain unstaged or untracked')
        if paths('ls-files', '-z') != set(expected['files']):
            raise RuntimeError('Staged tree does not equal the complete reviewed source tree')
        # Preserve the two upstream CC0 license files byte-for-byte, including
        # their original whitespace-only first lines. Check all authored files.
        subprocess.run(['git', 'diff', '--cached', '--check', '--', '.',
                        ':(exclude)third_party/kenney_audio/impact-License.txt',
                        ':(exclude)third_party/kenney_audio/rpg-License.txt'], cwd=ROOT, check=True)
    print('COMPLETE SOURCE SNAPSHOT VERIFIED' + ('; INDEX MATCHES WORKTREE' if staged else ''))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', type=Path)
    parser.add_argument('--verify', type=Path)
    parser.add_argument('--staged', action='store_true')
    args = parser.parse_args()
    if args.verify:
        verify(json.loads(args.verify.read_text(encoding='utf-8')), args.staged)
        return
    report = snapshot()
    if args.record:
        args.record.parent.mkdir(parents=True, exist_ok=True)
        args.record.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    groups = collections.Counter(p.split('/')[0] for p in report['changed_vs_main'])
    print(json.dumps({'main': report['base_main'], 'head': report['head_at_review'],
                      'merge_heads': report['merge_heads'], 'source_files': len(report['files']),
                      'changed': len(report['changed_vs_main']), 'new_untracked': len(report['untracked_required']),
                      'deleted': report['deleted'], 'groups': groups}, ensure_ascii=True, indent=2))


if __name__ == '__main__':
    main()
