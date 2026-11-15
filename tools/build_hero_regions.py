"""Inspect original RGBA atlases; write frame/ground/socket metadata, never edit images.

Optional authoring dependencies: Pillow, numpy, OpenCV. Runtime needs only the JSON.
Unlike the old knight-only tool, small disconnected equipment parts can join their pose.
"""
from pathlib import Path
import argparse
import json
import cv2
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
states = ['idle', 'walk', 'attack', 'small', 'ultimate', 'hurt', 'down']
parser = argparse.ArgumentParser()
parser.add_argument('--hero', choices=['ranger', 'mage', 'all'], default='all')
args = parser.parse_args()

def bands_for(mask):
    active = mask.sum(axis=1) > 5
    spans, start = [], None
    for y, visible in enumerate(active):
        if visible and start is None: start = y
        if not visible and start is not None: spans.append([start, y]); start = None
    if start is not None: spans.append([start, len(active)])
    merged = []
    for start, end in spans:
        if merged and start - merged[-1][1] < 6: merged[-1][1] = end
        elif end - start > 3: merged.append([start, end])
    return merged

for hero in (['ranger', 'mage'] if args.hero == 'all' else [args.hero]):
    result = {'canvas': 256, 'foot_y': 240, 'hero': hero, 'views': {}}
    for view in ['side', 'down', 'up']:
        rgba = np.array(Image.open(root / f'assets/v012/{hero}_{view}.png').convert('RGBA'))
        mask = (rgba[:, :, 3] > 100).astype('uint8')
        bands = bands_for(mask)
        if len(bands) != 7: raise ValueError(f'{hero}/{view}: expected seven complete state rows, got {len(bands)}')
        rows, heights = {}, []
        for state, (top_band, bottom_band) in zip(states, bands):
            area_mask = mask[top_band:bottom_band]
            count, labels, stats, centers = cv2.connectedComponentsWithStats(area_mask)
            indexed = sorted([(i, list(map(int, s))) for i, s in enumerate(stats) if i and s[4] > 800], key=lambda item: -item[1][4])
            if len(indexed) < 8: raise ValueError(f'{hero}/{view}/{state}: incomplete figures')
            mains = sorted(indexed[:8], key=lambda item: item[1][0])
            if len(indexed) > 8 and indexed[8][1][4] > min(s[4] for _, s in mains) * 0.6:
                raise ValueError(f'{hero}/{view}/{state}: ambiguous pose grouping; author explicit boxes instead')
            assigned = [[i] for i, _ in mains]
            main_ids = {i for i, _ in mains}
            for index in range(1, count):
                if index in main_ids or stats[index, 4] < 15: continue
                x, y, w, h, _ = stats[index]
                distances = []
                for _, (mx, my, mw, mh, _) in mains:
                    dx = max(mx - (x + w), x - (mx + mw), 0)
                    dy = max(my - (y + h), y - (my + mh), 0)
                    distances.append(dx * dx + dy * dy)
                owner = int(np.argmin(distances))
                if distances[owner] <= 35 * 35: assigned[owner].append(index)
            frames = []
            for (_, main), members in zip(mains, assigned):
                pose = np.isin(labels, members)
                yy, xx = np.where(pose)
                x0, x1, y0, y1 = int(xx.min()), int(xx.max()) + 1, int(yy.min()), int(yy.max()) + 1
                colors = rgba[top_band:bottom_band, :, :3].astype('float32')
                boots = pose & (colors[:, :, 0] > colors[:, :, 1] * 1.08) & (colors[:, :, 0] > colors[:, :, 2] * 1.1) & (colors[:, :, 0] < 210)
                boots[:y0 + int((y1-y0)*0.7)] = False
                boot_rows = np.where(boots.sum(axis=1) >= 5)[0]
                foot_y = int(boot_rows[-1]) + 1 if len(boot_rows) else y1
                bottom = boots[max(0, foot_y-9):foot_y]
                if not bottom.any(): bottom = pose[max(0, foot_y-9):foot_y]
                weights = bottom.sum(axis=0)
                foot_x = float(np.average(np.arange(pose.shape[1]), weights=weights))
                left, top = max(0, x0-2), max(top_band, top_band+y0-2)
                right, lower = min(rgba.shape[1], x1+2), min(bottom_band, top_band+y1+2)
                # Explicit directional hand/core estimates, snapped onto this pose's opaque art.
                sx = {'side':0.82,'down':0.66,'up':0.55}[view]
                sy = {'side':0.46,'down':0.48,'up':0.35}[view]
                estimate = np.array([x0+(x1-x0)*sx, y0+(y1-y0)*sy])
                if hero == 'mage':
                    crystal = pose & (colors[:, :, 2] > 140) & (colors[:, :, 2] > colors[:, :, 1]*1.25) & (colors[:, :, 0] < colors[:, :, 2]*1.15)
                    nc, lc, sc, cc = cv2.connectedComponentsWithStats(crystal.astype('uint8'))
                    eligible = [(int(s[4]), cc[i]) for i, s in enumerate(sc) if i and s[4] >= 12]
                    if eligible: estimate = max(eligible, key=lambda entry:entry[0])[1]
                nearest = int(np.argmin((xx-estimate[0])**2+(yy-estimate[1])**2))
                frames.append({'rect':[left,top,right-left,lower-top],
                               'anchor':[round(foot_x-left,2),top_band+foot_y-top],
                               'socket':[int(xx[nearest])-left,top_band+int(yy[nearest])-top]})
                if state == 'idle': heights.append(top_band+foot_y-(top_band+y0))
            rows[state] = frames
        result['views'][view] = {'height':float(np.median(heights)), 'states':rows}
    target = root / f'assets/v012/{hero}_frames.json'
    target.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(f'{hero}: 168 inspected poses; foot and emission anchors; raster files unchanged')
