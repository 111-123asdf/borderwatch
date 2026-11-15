"""Archive the current working repository and complete .git, then extract and verify it.

No commit, staging, fetch or history rewriting. Uses only Python's standard library.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import zipfile
from audit_submission import snapshot

root = Path(__file__).resolve().parents[1]
if not (root / '.git').is_dir():
    raise RuntimeError('Canonical project must contain a complete .git directory')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, help='Optional course ZIP path; defaults to the latest source handoff')
parser.add_argument('--audit', type=Path, help='Reviewed external snapshot to validate, including a dry-run stage in the extracted copy')
args = parser.parse_args()
target = args.output.resolve() if args.output else root.parent / '边境守望-最新源码.zip'
if target.is_relative_to(root):
    raise RuntimeError('Archive output must stay outside the canonical project')
target.parent.mkdir(parents=True, exist_ok=True)
temporary = target.with_suffix('.zip.tmp')
excluded = {'.godot', 'test-results', 'builds', '_local', 'toolchain', '__pycache__', '.idea', '.vscode'}
extensions = {'.exe', '.pck', '.zip', '.tpz', '.pyc', '.log', '.tmp', '.avi', '.mp4', '.mov'}
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
status = subprocess.check_output(['git', 'status', '--porcelain=v1', '--untracked-files=all'], cwd=root)
count = 0
review = snapshot()
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for folder, directories, files in os.walk(root):
        directories[:] = [name for name in directories if name not in excluded]
        for name in files:
            path = Path(folder) / name
            relative = path.relative_to(root)
            if relative.parts[0] != '.git' and (path.suffix.lower() in extensions or name.startswith('.env')):
                continue
            archive.write(path, relative.as_posix())
            count += 1
with zipfile.ZipFile(temporary) as archive:
    if archive.testzip() is not None:
        raise RuntimeError('Archive CRC failure')
    names = archive.namelist()
    assert '.git/HEAD' in names and 'project.godot' in names
    assert not any(set(Path(name).parts) & excluded for name in names)
    if set(name for name in names if not name.startswith('.git/')) != set(review['files']):
        raise RuntimeError('Archive must contain exactly the audited source tree plus complete .git')
    work = root / 'test-results' / 'source-archive-validation'
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='v011-', dir=work) as directory:
        checkout = Path(directory)
        if not checkout.resolve().is_relative_to(work.resolve()) or not checkout.name.startswith('v011-'):
            raise RuntimeError('Temporary extraction path escaped its intended validation directory')
        archive.extractall(checkout)
        subprocess.run(['git', 'fsck', '--full'], cwd=checkout, check=True, capture_output=True)
        restored = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=checkout, text=True).strip()
        restored_status = subprocess.check_output(['git', 'status', '--porcelain=v1', '--untracked-files=all'], cwd=checkout)
        if restored != head or restored_status != status:
            raise RuntimeError('Restored repository differs from current HEAD or working/staged file inventory')
        for name, entry in review['files'].items():
            if hashlib.sha256((checkout / name).read_bytes()).hexdigest() != entry['sha256']:
                raise RuntimeError('Restored source hash mismatch: ' + name)
        if args.audit:
            subprocess.run(['git', 'add', '--all'], cwd=checkout, check=True, capture_output=True)
            checked = subprocess.run(['python', str(checkout / 'tools/audit_submission.py'), '--verify', str(args.audit.resolve()), '--staged'], cwd=checkout, capture_output=True, text=True, encoding='utf-8')
            if checked.returncode:
                raise RuntimeError('Extracted staging verification failed:\n' + checked.stdout + checked.stderr)
temporary.replace(target)
report = {'archive': str(target), 'files': count, 'bytes': target.stat().st_size, 'head': head,
          'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'crc': True, 'git_fsck_full': True,
          'head_and_working_status_match': True, 'all_source_sha256_match': True,
          'isolated_staging_check': bool(args.audit), 'source_files': len(review['files'])}
(root / 'test-results/source-archive-validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=True))
