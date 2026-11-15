"""Optional CC0 audio authoring; selected recordings only, no runtime dependency."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
encoder = shutil.which('ffmpeg')
if not encoder:
    sys.path.insert(0, str(root / 'test-results/movie-tools'))
    import imageio_ffmpeg
    encoder = imageio_ffmpeg.get_ffmpeg_exe()
prep = root / 'test-results/v012-prep'
tiny = prep / 'tinysized/sfx-cc0'
impact = root / 'test-results/v011-prep/impact/Audio'
output = root / 'assets/v012/audio'
output.mkdir(parents=True, exist_ok=True)
vehicle = ('Vehicle / Jan Schupke', 'https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx')
kenney = ('Kenney', 'https://kenney.nl/assets/impact-sounds')
ice = ('bart; original recordings Stephan / pdsounds', 'https://opengameart.org/content/ice-spells')
items = [
    ('ranger_draw', tiny/'arrow-grab-from-quiver-01.wav', .24, 1, vehicle),
    ('ranger_release', tiny/'arrow-feathers-01.wav', .24, 1.15, vehicle),
    ('ranger_hit', tiny/'wood-twigs-break-01.wav', .22, 1, vehicle),
    ('ranger_roll', tiny/'cloth-pouch-shake-01.wav', .30, .85, vehicle),
    ('ranger_rain', tiny/'wood-twigs-break-02.wav', .28, 1.15, vehicle),
    ('mage_gather', impact/'impactBell_heavy_000.ogg', .28, .75, kenney),
    ('mage_cast', impact/'impactGlass_light_000.ogg', .25, 1.15, kenney),
    ('mage_hit', impact/'impactGlass_light_001.ogg', .26, 1, kenney),
    ('mage_frost', prep/'icespells/coldsnap.wav', .65, 1, ice),
    ('mage_meteor_charge', prep/'icespells/ice.wav', .85, .7, ice),
    ('mage_meteor_hit', impact/'impactGlass_heavy_000.ogg', .55, .7, kenney),
]
records = []
for cue, source, duration, pitch, provenance in items:
    target = output / (cue+'.ogg')
    filters = f'silenceremove=start_periods=1:start_threshold=-48dB,aresample=44100,asetrate=44100*{pitch},aresample=44100,atrim=duration={duration},afade=t=out:st={duration-.055}:d=0.055,loudnorm=I=-20:TP=-3:LRA=7'
    subprocess.run([encoder, '-y', '-loglevel', 'error', '-i', str(source), '-ar', '44100', '-ac', '1', '-af', filters, '-c:a', 'libvorbis', '-q:a', '4', str(target)], check=True)
    records.append({'cue':cue, 'file':target.relative_to(root).as_posix(), 'source_file':source.name,
                    'author':provenance[0], 'source':provenance[1], 'license':'CC0-1.0',
                    'processing':filters, 'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
license_dir = root / 'third_party/hero_audio_v012'
license_dir.mkdir(parents=True, exist_ok=True)
shutil.copyfile(prep/'tinysized/readme.txt', license_dir/'Vehicle-CC0.txt')
(license_dir/'SOURCES.txt').write_text('Selected recordings only. All CC0-1.0.\n'+'\n'.join(f'{a}: {u}' for a,u in [vehicle,kenney,ice])+'\nhttps://creativecommons.org/publicdomain/zero/1.0/\nKenney license also retained in ../kenney_audio.\nFoley is adapted for bow/cloth/star/ice cues; no claim of original bow-string recording.\n', encoding='utf-8')
(root/'docs/AUDIO_V012.json').write_text(json.dumps({'format':'mono Vorbis, 44.1kHz', 'assets':records}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'{len(records)} CC0 sampled cues: {sum(p.stat().st_size for p in output.glob("*.ogg"))} bytes')
