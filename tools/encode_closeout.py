"""Produce a 45-second group preview from real, isolated-PCK action recordings."""
from pathlib import Path
import array
import json
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
work = root / 'test-results/closeout-movie'
encoder = shutil.which('ffmpeg') or str(root.parent / 'toolchain/ffmpeg/ffmpeg.exe')
segments = [('ranger-creek', 72), ('knight-ruins', 74), ('mage-ruins', 60)]
for name, start in segments:
    subprocess.run([encoder, '-v', 'error', '-y', '-ss', str(start), '-i', str(work / (name + '.avi')),
                    '-t', '15', '-vf', 'scale=1280:720,setsar=1,fps=30', '-c:v', 'libx264',
                    '-preset', 'medium', '-crf', '23', '-maxrate', '3000k', '-bufsize', '6000k',
                    '-pix_fmt', 'yuv420p', '-af', 'afade=t=in:d=0.12,afade=t=out:st=14.8:d=0.2',
                    '-c:a', 'aac', '-b:a', '128k', '-ar', '48000', '-ac', '2',
                    str(work / (name + '.mp4'))], check=True)
concat = work / 'concat.txt'
concat.write_text(''.join("file '" + name + ".mp4'\n" for name, _ in segments), encoding='utf-8')
target = root.parent / '阶段演示-两关三英雄.mp4'
subprocess.run([encoder, '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(concat),
                '-c', 'copy', '-movflags', '+faststart', str(target)], check=True)
decoded = subprocess.run([encoder, '-v', 'error', '-i', str(target), '-vn', '-ac', '1', '-ar', '22050',
                          '-f', 'f32le', 'pipe:1'], capture_output=True, check=True)
samples = array.array('f', decoded.stdout)
duration = len(samples) / 22050
peak = max(abs(x) for x in samples)
clipped = sum(abs(x) >= .999 for x in samples) / len(samples)
assert 44 <= duration <= 46 and peak > .001 and clipped < .001
subprocess.run([encoder, '-v', 'error', '-i', str(target), '-f', 'null', '-'], check=True)
report = {'seconds': round(duration, 2), 'bytes': target.stat().st_size, 'audio_peak': peak,
          'clipped_fraction': clipped, 'resolution': '1280x720', 'fps': 30,
          'segments': segments, 'profile': 'pre-existing LV5, normal in-run resources, automatic actions',
          'source': 'isolated exported PCK; edited excerpts, not a full clear'}
(work / 'video-check.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
