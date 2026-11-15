"""Inspect alpha components and author runtime atlas regions; never modifies raster art.

Optional art-maintenance dependencies: Pillow, numpy, OpenCV. Not a game dependency.
Reject overlapping/incomplete sheets rather than hiding bad frames in the build.
"""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
states = ['idle', 'walk', 'attack', 'small', 'ultimate', 'hurt', 'down']
result = {'canvas': 256, 'foot_y': 240, 'views': {}}
for view in ['side', 'down', 'up']:
    image = np.array(Image.open(root / f'assets/v011/knight_{view}.png').convert('RGBA'))
    mask = (image[:, :, 3] > 100).astype('uint8')
    count, labels, stats, centers = cv2.connectedComponentsWithStats(mask)
    components = sorted([list(map(int, s)) for s in stats[1:] if s[4] > 1800], key=lambda s: s[1])
    if len(components) != 56:
        raise ValueError(f'{view}: expected 56 separate intact figures, got {len(components)}')
    rows = {}
    idle_heights = []
    for row, state in enumerate(states):
        group = sorted(components[row * 8:(row + 1) * 8], key=lambda s: s[0])
        frames = []
        for x, y, width, height, area in group:
            # Lowest visible boot/ground pixels anchor the figure, not transparent cell edges.
            floor = mask[y + max(0, height - 9):y + height, x:x + width]
            weights = floor.sum(axis=0)
            foot_x = float(np.average(np.arange(width), weights=weights)) if weights.sum() else width / 2
            left, top = max(0, x - 2), max(0, y - 2)
            right, bottom = min(image.shape[1], x + width + 2), min(image.shape[0], y + height + 2)
            frames.append({'rect': [left, top, right - left, bottom - top],
                           'anchor': [round(x + foot_x - left, 2), y + height - top]})
            if state == 'idle': idle_heights.append(height)
        rows[state] = frames
    result['views'][view] = {'height': float(np.median(idle_heights)), 'states': rows}
target = root / 'assets/v011/knight_frames.json'
target.write_text(json.dumps(result, indent=2), encoding='utf-8')
print('ATLAS REGIONS: 168 inspected poses; original images unchanged')
