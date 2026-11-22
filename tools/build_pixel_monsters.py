import argparse
import os
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]

STD_CELL = 192
BOSS_CELL = 256
COLS = 6
FOOT_FRAC = 0.875  # 168/192 and 224/256 -> exact offset_y = -0.375 * cell_h in Godot

_IMAGE_CACHE = {}


def load_raw(raw_dir: Path, name: str) -> np.ndarray:
    if name not in _IMAGE_CACHE:
        path = raw_dir / name
        _IMAGE_CACHE[name] = np.array(Image.open(path).convert("RGBA"))
    return _IMAGE_CACHE[name]


def is_bg_mask(arr: np.ndarray, protect_green: bool = False) -> np.ndarray:
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)
    if protect_green:
        # Strict neon chroma green / lime glow so darker sage/emerald creature pixels stay intact
        return (g > 165) & (r < 95) & (b < 95) & ((g - r) > 78) & ((g - b) > 78)
    return (g > 115) & ((g - r) > 48) & ((g - b) > 52)


def dilate_mask(mask: np.ndarray, iters: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(iters):
        d = out.copy()
        d[1:, :] |= out[:-1, :]
        d[:-1, :] |= out[1:, :]
        d[:, 1:] |= out[:, :-1]
        d[:, :-1] |= out[:, 1:]
        out = d
    return out


def key_crop(raw_arr: np.ndarray, box: tuple, protect_green: bool = False,
             erase_rects: list = None) -> np.ndarray:
    x0, y0, x1, y1 = box
    crop = raw_arr[y0:y1, x0:x1].copy()
    if erase_rects:
        for ex0, ey0, ex1, ey1 in erase_rects:
            lx0, ly0 = max(0, ex0 - x0), max(0, ey0 - y0)
            lx1, ly1 = min(crop.shape[1], ex1 - x0), min(crop.shape[0], ey1 - y0)
            if lx1 > lx0 and ly1 > ly0:
                crop[ly0:ly1, lx0:lx1, :3] = [0, 255, 0]
                crop[ly0:ly1, lx0:lx1, 3] = 255

    h, w, _ = crop.shape
    bg_cand = is_bg_mask(crop, protect_green=protect_green)

    # 1. Edge flood-fill (4-connected) from border pixels matching bg_cand
    bg = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if bg_cand[0, x] and not bg[0, x]:
            bg[0, x] = True; q.append((0, x))
        if bg_cand[h - 1, x] and not bg[h - 1, x]:
            bg[h - 1, x] = True; q.append((h - 1, x))
    for y in range(h):
        if bg_cand[y, 0] and not bg[y, 0]:
            bg[y, 0] = True; q.append((y, 0))
        if bg_cand[y, w - 1] and not bg[y, w - 1]:
            bg[y, w - 1] = True; q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and bg_cand[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    # 2. Clear enclosed interior holes (under arms, between legs, weapon/aura loops)
    r = crop[:, :, 0].astype(np.int32)
    g = crop[:, :, 1].astype(np.int32)
    b = crop[:, :, 2].astype(np.int32)
    if protect_green:
        strict_bg = (g > 175) & ((g - r) > 95) & ((g - b) > 95) & (r < 85) & (b < 85)
    else:
        strict_bg = (g > 120) & ((g - r) > 45) & ((g - b) > 50)

    rem = strict_bg & (~bg)
    visited = np.zeros((h, w), dtype=bool)
    ys, xs = np.where(rem)
    for sy, sx in zip(ys, xs):
        if visited[sy, sx]:
            continue
        comp = []
        cq = deque([(sy, sx)])
        visited[sy, sx] = True
        while cq:
            cy, cx = cq.popleft()
            comp.append((cy, cx))
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and rem[ny, nx]:
                    visited[ny, nx] = True
                    cq.append((ny, nx))
        min_hole = 2 if not protect_green else 4
        if len(comp) >= min_hole:
            for cy, cx in comp:
                bg[cy, cx] = True

    crop[bg, 3] = 0

    # 3. Clean 1px WebP chroma halo & despill green tint on ALL silhouette boundaries (outer + interior holes)
    edge1 = dilate_mask(bg, 1) & (~bg)
    if protect_green:
        fringe = edge1 & (g > 155) & (r < 95) & (b < 95) & ((g - r) > 65) & ((g - b) > 65)
        crop[fringe, 3] = 0
        sp = edge1 & (~fringe) & (g > np.maximum(r, b) + 45) & (g > 145) & (r < 105) & (b < 105)
        crop[sp, 1] = np.maximum(crop[sp, 0], crop[sp, 2])
    else:
        fringe = edge1 & (g > 110) & ((g - r) > 36) & ((g - b) > 36)
        crop[fringe, 3] = 0
        sp = edge1 & (~fringe) & (g > np.maximum(r, b) + 18)
        crop[sp, 1] = np.maximum(crop[sp, 0], crop[sp, 2])

    return crop


def extract_frames(raw_dir: Path, sheet_name: str, y0: int, y1: int, x_splits: list,
                   protect_green: bool = False, erase_rects: list = None) -> list:
    raw = load_raw(raw_dir, sheet_name)
    frames = []
    for xa, xb in x_splits:
        frames.append(key_crop(raw, (xa, y0, xb, y1), protect_green=protect_green, erase_rects=erase_rects))
    return frames


def resample_to_6(frames: list) -> list:
    if not frames:
        return [np.zeros((16, 16, 4), dtype=np.uint8)] * COLS
    n = len(frames)
    if n == COLS:
        return frames
    out = []
    for i in range(COLS):
        idx = int(round(i * (n - 1) / float(COLS - 1))) if COLS > 1 and n > 1 else 0
        out.append(frames[min(n - 1, max(0, idx))])
    return out


def frame_metrics(arr: np.ndarray):
    ys, xs = np.where(arr[:, :, 3] > 25)
    if len(ys) == 0:
        return None
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    foot_cut = y1 - max(4, int((y1 - y0) * 0.22))
    foot_xs = xs[ys >= foot_cut]
    foot_cx = float(np.median(foot_xs)) if len(foot_xs) > 0 else (x0 + x1) * 0.5
    return (x0, y0, x1 + 1, y1 + 1, foot_cx)


def place_frame(arr: np.ndarray, scale: float, cell_size: int,
                anchor_mode: str = "foot", foot_bias: int = 0) -> Image.Image:
    m = frame_metrics(arr)
    cell = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
    if m is None:
        return cell
    x0, y0, x1, y1, foot_cx = m
    trimmed = Image.fromarray(arr[y0:y1, x0:x1])
    tw, th = trimmed.size
    nw = max(1, int(round(tw * scale)))
    nh = max(1, int(round(th * scale)))
    fit = min(1.0, (cell_size - 8) / float(nw), (cell_size - 8) / float(nh))
    if fit < 1.0:
        nw = max(1, int(round(nw * fit)))
        nh = max(1, int(round(nh * fit)))
        eff_scale = scale * fit
    else:
        eff_scale = scale

    resized = trimmed.resize((nw, nh), Image.Resampling.NEAREST)
    center_x = cell_size // 2
    foot_y = int(round(cell_size * FOOT_FRAC)) + foot_bias
    if anchor_mode == "center":
        px = int(round(center_x - nw * 0.5))
    else:
        local_foot_x = (foot_cx - x0) * eff_scale
        px = int(round(center_x - local_foot_x))
    px = max(2, min(cell_size - nw - 2, px))
    py = max(2, min(cell_size - nh - 2, foot_y - nh))
    cell.paste(resized, (px, py), resized)
    return cell


def build_monster_sheet(out_path: Path, rows_dict: dict, state_order: list,
                        cell_size: int, target_h: float):
    walk_frames = rows_dict.get("walk", [])
    heights = []
    for f in walk_frames:
        m = frame_metrics(f)
        if m:
            heights.append(m[3] - m[1])
    ref_h = float(np.median(heights)) if heights else 100.0
    scale = target_h / max(20.0, ref_h)

    sheet = Image.new("RGBA", (cell_size * COLS, cell_size * len(state_order)), (0, 0, 0, 0))
    for r_idx, state in enumerate(state_order):
        frames = resample_to_6(rows_dict.get(state, walk_frames))
        is_ko = (state == "down")
        for c_idx, f in enumerate(frames):
            cell = place_frame(
                f,
                scale=scale,
                cell_size=cell_size,
                anchor_mode=("center" if is_ko else "foot"),
                foot_bias=(4 if is_ko else 0),
            )
            sheet.paste(cell, (c_idx * cell_size, r_idx * cell_size), cell)
    sheet.save(out_path)
    return sheet


def build_portraits(raw_dir: Path, out_dir: Path):
    p_raw = Image.open(raw_dir / "portraits_v023.webp").convert("RGBA")
    y_runs = [(18, 234), (272, 488), (526, 739)]
    x_runs = [(18, 238), (274, 494), (530, 750), (786, 1006)]
    grid_ids = [
        ["pigsoldier", "rottooth_hyena", "tusk_fighter", "dreadeye_viper"],
        ["turtle_shaman", "bear_vanguard", "throat_cutter", "scout_vulture"],
        ["skunk_bombardier", "bear_woodsman", "darksteel_guard", "two_headed_troll"],
    ]
    for r, y_box in enumerate(y_runs):
        for c, x_box in enumerate(x_runs):
            mid = grid_ids[r][c]
            crop = p_raw.crop((x_box[0], y_box[0], x_box[1], y_box[1]))
            crop.resize((128, 128), Image.Resampling.NEAREST).save(out_dir / f"portrait_{mid}.png")


def build_all(raw_dir: Path, out_dir: Path, audit_path: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    audit_path.parent.mkdir(parents=True, exist_ok=True)

    build_portraits(raw_dir, out_dir)

    monsters = {
        "pigsoldier": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 112.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet1.webp", 36, 148, [(22, 108), (120, 204), (220, 316), (328, 444)]),
                "attack": extract_frames(raw_dir, "sheet1.webp", 36, 148, [(449, 550), (553, 656)]),
                "down": extract_frames(raw_dir, "sheet1.webp", 36, 148, [(660, 804), (812, 958)]),
            },
        },
        "tusk_fighter": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 124.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet1.webp", 184, 306, [(14, 158), (160, 279), (350, 469)]),
                "attack": extract_frames(raw_dir, "sheet1.webp", 184, 306, [(471, 562), (569, 650), (656, 762)]),
                "down": extract_frames(raw_dir, "sheet1.webp", 184, 306, [(764, 872), (874, 1008)]),
            },
        },
        "throat_cutter": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 106.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet1.webp", 346, 436, [(18, 128), (136, 232), (242, 344), (346, 490)]),
                "attack": extract_frames(raw_dir, "sheet1.webp", 346, 436, [(494, 712), (728, 855)]),
                "down": extract_frames(raw_dir, "sheet1.webp", 346, 436, [(866, 985)]),
            },
        },
        "bear_vanguard": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 134.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet1.webp", 464, 610, [(18, 158), (159, 254), (256, 346), (347, 474)]),
                "attack": extract_frames(raw_dir, "sheet1.webp", 464, 610, [(347, 474), (476, 714)]),
                "down": extract_frames(raw_dir, "sheet1.webp", 464, 610, [(724, 1004)]),
            },
        },
        "turtle_shaman": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 116.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet1.webp", 637, 761, [(30, 153), (245, 368)], protect_green=True),
                "attack": extract_frames(raw_dir, "sheet1.webp", 637, 761, [(478, 600), (610, 734)], protect_green=True),
                "down": extract_frames(raw_dir, "sheet1.webp", 686, 761, [(748, 852), (866, 970)], protect_green=True),
            },
        },
        "scout_vulture": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 118.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet2.webp", 33, 154, [(10, 214), (225, 384), (398, 544)]),
                "attack": extract_frames(raw_dir, "sheet2.webp", 33, 154, [(398, 544), (552, 698)]),
                "down": extract_frames(raw_dir, "sheet2.webp", 33, 154, [(806, 956)]),
            },
        },
        "bear_woodsman": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 130.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet2.webp", 183, 310, [(18, 138), (154, 280), (292, 416)]),
                "attack": extract_frames(raw_dir, "sheet2.webp", 183, 310, [(460, 572), (572, 724)]),
                "down": extract_frames(raw_dir, "sheet2.webp", 183, 310, [(764, 982)]),
            },
        },
        "dreadeye_viper": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 120.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet2.webp", 342, 462, [(29, 155), (156, 296)], protect_green=True),
                "attack": extract_frames(raw_dir, "sheet2.webp", 342, 462, [(156, 296), (304, 450)], protect_green=True),
                "down": extract_frames(raw_dir, "sheet2.webp", 342, 462, [(802, 994)], protect_green=True),
            },
        },
        "skunk_bombardier": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 114.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet2.webp", 492, 612, [(10, 134), (152, 292), (302, 450)]),
                "attack": extract_frames(raw_dir, "sheet2.webp", 492, 612, [(302, 450), (480, 766)]),
                "down": extract_frames(raw_dir, "sheet2.webp", 492, 612, [(784, 990)]),
            },
        },
        "rottooth_hyena": {
            "states": ["walk", "attack", "down"],
            "cell": STD_CELL,
            "target_h": 102.0,
            "rows": {
                "walk": extract_frames(raw_dir, "sheet3.webp", 52, 165, [(26, 170), (190, 338), (355, 510)], protect_green=False),
                "attack": extract_frames(raw_dir, "sheet3.webp", 52, 165, [(355, 510), (539, 694)], protect_green=False),
                "down": extract_frames(raw_dir, "sheet3.webp", 52, 165, [(712, 844), (860, 1004)], protect_green=False),
            },
        },
        "darksteel_guard": {
            "states": ["walk", "attack", "skill", "down"],
            "cell": BOSS_CELL,
            "target_h": 168.0,
            "rows": {
                "walk": extract_frames(raw_dir, "miniboss_darksteel_guard.webp", 38, 185, [(6, 258), (260, 512), (514, 764), (766, 1016)]),
                "attack": extract_frames(raw_dir, "miniboss_darksteel_guard.webp", 412, 574, [(20, 236), (258, 500), (504, 770), (772, 1018)]),
                "skill": extract_frames(raw_dir, "miniboss_darksteel_guard.webp", 226, 374, [(6, 254), (258, 505), (514, 759), (759, 1018)]),
                "down": extract_frames(raw_dir, "miniboss_darksteel_guard.webp", 614, 761, [(10, 260), (272, 535), (538, 832)]),
            },
        },
        "two_headed_troll": {
            "states": ["walk", "attack", "skill", "down"],
            "cell": BOSS_CELL,
            "target_h": 182.0,
            "rows": {
                "walk": extract_frames(raw_dir, "boss_two_headed_troll.webp", 44, 192, [(22, 219), (233, 426), (428, 622), (628, 818), (828, 1016)]),
                "attack": extract_frames(raw_dir, "boss_two_headed_troll.webp", 232, 384, [(8, 202), (310, 512), (536, 738), (770, 976)]),
                "skill": extract_frames(
                    raw_dir, "boss_two_headed_troll.webp", 414, 580,
                    [(8, 250), (252, 480), (520, 758), (792, 994)],
                    erase_rects=[(0, 390, 450, 422)]
                ),
                "down": extract_frames(
                    raw_dir, "boss_two_headed_troll.webp", 615, 763,
                    [(401, 637), (638, 786), (788, 1016)],
                    erase_rects=[(860, 628, 940, 682)]
                ),
            },
        },
    }

    for mid, cfg in monsters.items():
        build_monster_sheet(
            out_dir / f"creature_{mid}.png",
            cfg["rows"],
            cfg["states"],
            cfg["cell"],
            cfg["target_h"],
        )

    # Visual Audit Contact Sheet
    order = [
        "pigsoldier", "rottooth_hyena", "tusk_fighter", "dreadeye_viper",
        "turtle_shaman", "bear_vanguard", "throat_cutter", "scout_vulture",
        "skunk_bombardier", "bear_woodsman", "darksteel_guard", "two_headed_troll",
    ]
    thumb = 112
    audit = Image.new("RGBA", (thumb * 6, thumb * len(order)), (38, 42, 52, 255))
    draw = ImageDraw.Draw(audit)
    for y in range(0, audit.height, 16):
        for x in range(0, audit.width, 16):
            if ((x // 16) + (y // 16)) % 2 == 0:
                draw.rectangle([x, y, x + 15, y + 15], fill=(48, 52, 64, 255))

    for r_i, mid in enumerate(order):
        p_path = out_dir / f"portrait_{mid}.png"
        if p_path.exists():
            pi = Image.open(p_path).resize((thumb - 8, thumb - 8), Image.Resampling.NEAREST)
            audit.paste(pi, (4, r_i * thumb + 4), pi)
        s_img = Image.open(out_dir / f"creature_{mid}.png")
        c_sz = monsters[mid]["cell"]
        states = monsters[mid]["states"]
        picks = [
            (0, 0),  # walk 0
            (0, 3),  # walk 3
            (1, 3),  # attack 3
            (2 if "skill" in states else 1, 5),  # skill/attack end
            (len(states) - 1, 5),  # down end
        ]
        for c_i, (row_s, col_s) in enumerate(picks):
            cell = s_img.crop((col_s * c_sz, row_s * c_sz, (col_s + 1) * c_sz, (row_s + 1) * c_sz))
            t = cell.resize((thumb, thumb), Image.Resampling.NEAREST)
            audit.paste(t, ((c_i + 1) * thumb, r_i * thumb), t)
        draw.text((6, r_i * thumb + 4), mid, fill=(255, 240, 130, 255))

    audit.save(audit_path)
    print(f"Built {len(monsters)} monster sheets + portraits; audit at {audit_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build v0.23 Beast Legion monster sprite sheets.")
    parser.add_argument("--raw-dir", type=Path, default=PROJECT.parent / "美术参考/monsters_v023_raw")
    parser.add_argument("--out-dir", type=Path, default=PROJECT / "assets/monsters_v023")
    parser.add_argument("--audit", type=Path, default=PROJECT / "test-results/v023-art/monster_slice_audit.png")
    args = parser.parse_args()
    build_all(args.raw_dir.resolve(strict=True), args.out_dir.resolve(), args.audit.resolve())
