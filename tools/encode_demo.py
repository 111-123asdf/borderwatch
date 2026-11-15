"""Encode the actual Godot movie; --audio retains and verifies its PCM soundtrack."""
import pathlib
import shutil
import subprocess
import sys

source, target = map(pathlib.Path, sys.argv[1:3])
keep_audio = '--audio' in sys.argv[3:]
duration = next((float(x.split('=', 1)[1]) for x in sys.argv[3:] if x.startswith('--duration=')), None)
encoder = shutil.which('ffmpeg')
if not encoder:
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'test-results' / 'movie-tools'))
    try:
        import imageio_ffmpeg
        encoder = imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError as exc:
        raise RuntimeError('Recording conversion needs FFmpeg, or optional imageio-ffmpeg 0.6.0.') from exc
audio_args = ['-map', '0:v:0', '-map', '0:a:0', '-c:a', 'aac', '-b:a', '160k'] if keep_audio else ['-an']
clip_args = ['-t', str(duration)] if duration else []
result = subprocess.run([
    encoder, '-y', '-loglevel', 'error', '-progress', 'pipe:1', '-nostats',
    '-i', str(source), *clip_args, *audio_args, '-c:v', 'libx264', '-preset', 'medium', '-crf', '22',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(target)
], capture_output=True, text=True, check=True)
fields = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
frames = int(fields.get('frame', '0'))
seconds = int(fields.get('out_time_us', '0')) / 1_000_000
if frames < 450 or seconds < 15:
    raise RuntimeError('Recording is incomplete')
subprocess.run([encoder, '-v', 'error', '-i', str(target), '-f', 'null', '-'], check=True)
if keep_audio:
    import array
    decoded = subprocess.run([encoder, '-v', 'error', '-i', str(target), '-vn', '-ac', '1', '-ar', '22050', '-f', 'f32le', 'pipe:1'], capture_output=True, check=True)
    samples = array.array('f', decoded.stdout)
    if not samples or max(abs(x) for x in samples) < 0.001:
        raise RuntimeError('Recorded audio is missing or silent')
    clipped = sum(abs(x) >= 0.999 for x in samples)
    if clipped / len(samples) > 0.001:
        raise RuntimeError('Recorded audio has sustained clipping')
    print(f'AUDIO: peak={max(abs(x) for x in samples):.3f}; clipped={clipped}/{len(samples)}')
print(f'MP4 H.264: {target}; frames={frames}; seconds={seconds:.2f}; bytes={target.stat().st_size}')
