import argparse
import os
from pathlib import Path
from collections import deque
import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]

CELL = 224
COLS = 8
STATES = ["idle", "walk", "attack", "small", "ultimate", "hurt", "down"]
FOOT_Y = 196
CENTER_X = 112

_IMAGE_CACHE = {}


def load_raw(name: str) -> np.ndarray:
    if name not in _IMAGE_CACHE:
        path = os.path.join(RAW_DIR, name)
        _IMAGE_CACHE[name] = np.array(Image.open(path).convert("RGBA"))
    return _IMAGE_CACHE[name]


def is_bg_mask(arr: np.ndarray, mode: str, protect_green: bool = False) -> np.ndarray:
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)
    if mode == "green":
        if protect_green:
            # Strict neon screen green (#00FF00) so druid's darker forest-green cloak & vines are protected
            return (g > 205) & (r < 68) & (b < 68) & ((g - r) > 135) & ((g - b) > 135)
        # Covers bright #00FF00, werewolf chroma green (4,167,17), and divider dark green (1,132,13)
        return (g > 110) & ((g - r) > 54) & ((g - b) > 54)
    else:
        # Pure magenta #FF00FF + WebP-compressed magenta edge pixels
        return (r > 150) & (b > 150) & (g < 115) & ((r - g) > 55) & ((b - g) > 55) & (np.abs(r - b) < 75)


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


def key_crop(raw_arr: np.ndarray, box: tuple, mode: str = "green", protect_green: bool = False) -> np.ndarray:
    x0, y0, x1, y1 = box
    crop = raw_arr[y0:y1, x0:x1].copy()
    h, w, _ = crop.shape
    bg_cand = is_bg_mask(crop, mode, protect_green=protect_green)

    # 1. Edge flood-fill (4-connected) from all border pixels matching bg_cand
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

    # 2. Clear enclosed interior background holes (between legs, under arms) using ultra-strict pure chroma key
    r = crop[:, :, 0].astype(np.int32)
    g = crop[:, :, 1].astype(np.int32)
    b = crop[:, :, 2].astype(np.int32)
    if mode == "green":
        if protect_green:
            # Ultra-strict neon green only (G > 232, R < 32, B < 32) so green cloaks are 100% immune!
            strict_bg = (g > 232) & (r < 32) & (b < 32)
        else:
            strict_bg = (g > 130) & ((g - r) > 85) & ((g - b) > 85) & (r < 55) & (b < 55)
    else:
        strict_bg = (r > 165) & (b > 165) & (g < 115) & (np.abs(r - b) < 55)

    rem = strict_bg & (~bg)
    visited = np.zeros((h, w), dtype=bool)
    ys, xs = np.where(rem)
    min_hole = 1 if mode == "magenta" else 4
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
        if len(comp) >= min_hole:
            for cy, cx in comp:
                bg[cy, cx] = True

    crop[bg, 3] = 0

    # 3. Clean 2px WebP compression halo strictly on boundary pixels touching transparent background
    edge1 = dilate_mask(bg, 1) & (~bg)
    edge2 = dilate_mask(bg, 2) & (~bg)

    if mode == "green":
        fringe = edge1 & (g > 115) & ((g - r) > 38) & ((g - b) > 38)
        if protect_green:
            fringe &= (g > 180) & (r < 95) & (b < 95)
        crop[fringe, 3] = 0
        sp = edge1 & (~fringe) & (g > np.maximum(r, b) + (38 if protect_green else 18))
        crop[sp, 1] = np.maximum(crop[sp, 0], crop[sp, 2])
    else:
        # Strip WebP-blurred magenta fringe pixels up to 2px from background border
        fringe1 = edge1 & (r > g + 18) & (b > g + 18) & (np.abs(r - b) < 85)
        fringe2 = edge2 & (r > 125) & (b > 125) & (g < 130) & (r > g + 30) & (b > g + 30) & (np.abs(r - b) < 65)
        fringe = fringe1 | fringe2
        crop[fringe, 3] = 0
        # Despill any remaining magenta-tinted pixels (Druid & Ember Wolf palettes have zero magenta)
        new_bg = bg | fringe
        sp = (~new_bg) & (r > g + 18) & (b > g + 18) & (np.abs(r - b) < 65)
        cap = np.minimum(255, crop[sp, 1].astype(np.int32) + 10).astype(np.uint8)
        crop[sp, 0] = np.minimum(crop[sp, 0], cap)
        crop[sp, 2] = np.minimum(crop[sp, 2], cap)

    return crop


def extract_row_frames(sheet_name: str, y0: int, y1: int, mode: str = "green",
                       x_splits: list = None, x_range: tuple = (0, 1024),
                       min_width: int = 24, protect_green: bool = False) -> list:
    raw = load_raw(sheet_name)
    frames = []
    if x_splits is not None:
        for xa, xb in x_splits:
            frames.append(key_crop(raw, (xa, y0, xb, y1), mode, protect_green=protect_green))
        return frames

    rx0, rx1 = x_range
    band = key_crop(raw, (rx0, y0, rx1, y1), mode, protect_green=protect_green)
    col_fg = (band[:, :, 3] > 20).sum(axis=0) > 1
    segs = []
    in_s = False
    sx = 0
    for x in range(len(col_fg)):
        if col_fg[x] and not in_s:
            in_s = True; sx = x
        elif not col_fg[x] and in_s:
            in_s = False
            if x - sx >= min_width:
                segs.append((sx, x))
    if in_s and len(col_fg) - sx >= min_width:
        segs.append((sx, len(col_fg)))

    for xa, xb in segs:
        pad_a = max(0, xa - 2)
        pad_b = min(band.shape[1], xb + 2)
        frames.append(band[:, pad_a:pad_b].copy())
    return frames


def resample_to_8(frames: list) -> list:
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
    foot_cut = y1 - max(4, int((y1 - y0) * 0.20))
    foot_xs = xs[ys >= foot_cut]
    foot_cx = float(np.median(foot_xs)) if len(foot_xs) > 0 else (x0 + x1) * 0.5
    return (x0, y0, x1 + 1, y1 + 1, foot_cx)


def place_frame(arr: np.ndarray, scale: float, foot_y: int = FOOT_Y, anchor_mode: str = "foot") -> Image.Image:
    m = frame_metrics(arr)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    if m is None:
        return cell
    x0, y0, x1, y1, foot_cx = m
    trimmed = Image.fromarray(arr[y0:y1, x0:x1])
    tw, th = trimmed.size
    nw = max(1, int(round(tw * scale)))
    nh = max(1, int(round(th * scale)))
    fit = min(1.0, (CELL - 6) / float(nw), (CELL - 6) / float(nh))
    if fit < 1.0:
        nw = max(1, int(round(nw * fit)))
        nh = max(1, int(round(nh * fit)))
        eff_scale = scale * fit
    else:
        eff_scale = scale

    resized = trimmed.resize((nw, nh), Image.Resampling.NEAREST)
    if anchor_mode == "center":
        px = int(round(CENTER_X - nw * 0.5))
    else:
        local_foot_x = (foot_cx - x0) * eff_scale
        px = int(round(CENTER_X - local_foot_x))
    px = max(2, min(CELL - nw - 2, px))
    py = max(2, min(CELL - nh - 2, foot_y - nh))
    cell.paste(resized, (px, py), resized)
    return cell


def build_view_sheet(out_path: str, rows_dict: dict, target_h: float = 132.0):
    idle_frames = rows_dict.get("idle", [])
    heights = []
    for f in idle_frames:
        m = frame_metrics(f)
        if m:
            heights.append(m[3] - m[1])
    ref_h = float(np.median(heights)) if heights else 120.0
    scale = target_h / max(20.0, ref_h)

    sheet = Image.new("RGBA", (CELL * COLS, CELL * len(STATES)), (0, 0, 0, 0))
    for r_idx, state in enumerate(STATES):
        frames = resample_to_8(rows_dict.get(state, idle_frames))
        is_ko = (state == "down")
        for c_idx, f in enumerate(frames):
            cell = place_frame(
                f,
                scale=scale,
                foot_y=(FOOT_Y + 6 if is_ko else FOOT_Y),
                anchor_mode=("center" if is_ko else "foot"),
            )
            sheet.paste(cell, (c_idx * CELL, r_idx * CELL), cell)
    sheet.save(out_path)
    return sheet


def build_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(AUDIT_PATH), exist_ok=True)

    # 0. PORTRAITS
    p_raw = Image.open(os.path.join(RAW_DIR, "portraits.webp")).convert("RGBA")
    portrait_boxes_large = {
        "lord":     (18, 56, 200, 238),
        "werewolf": (222, 58, 402, 238),
        "druid":    (422, 56, 604, 238),
        "healer":   (624, 58, 804, 238),
        "gunner":   (825, 56, 1007, 238),
    }
    portrait_boxes_small = {
        "lord":     (53, 368, 169, 484),
        "werewolf": (254, 368, 370, 484),
        "druid":    (455, 368, 571, 484),
        "healer":   (656, 368, 772, 484),
        "gunner":   (858, 368, 974, 484),
    }
    for hid, box in portrait_boxes_large.items():
        p_raw.crop(box).resize((160, 160), Image.Resampling.NEAREST).save(os.path.join(OUT_DIR, f"portrait_{hid}.png"))
    for hid, box in portrait_boxes_small.items():
        p_raw.crop(box).resize((96, 96), Image.Resampling.NEAREST).save(os.path.join(OUT_DIR, f"portrait_{hid}_small.png"))

    # DEFEATED (DOWN) FRAMES
    ko_lord = extract_row_frames("defeated_all.webp", 36, 186, "green", x_splits=[(38, 315), (355, 670), (700, 1008)])
    ko_werewolf = extract_row_frames("defeated_all.webp", 226, 374, "green", x_splits=[(60, 215), (382, 642), (712, 980)])
    ko_druid = extract_row_frames("defeated_all.webp", 412, 564, "green", x_splits=[(42, 186), (392, 645), (722, 980)], protect_green=True)
    ko_healer = extract_row_frames("defeated_all.webp", 582, 672, "green", x_splits=[(390, 668), (710, 976)])
    ko_gunner = [
        key_crop(load_raw("defeated_all.webp"), (42, 602, 212, 756), "green"),
        key_crop(load_raw("defeated_all.webp"), (235, 602, 380, 756), "green"),
        key_crop(load_raw("defeated_all.webp"), (432, 668, 660, 756), "green"),
        key_crop(load_raw("defeated_all.webp"), (695, 672, 978, 756), "green"),
    ]

    # 1. LORD (领主 冥翎 / DOLORION)
    lord_s_idle = extract_row_frames("lord_side.webp", 38, 186, "green")
    lord_s_walk = extract_row_frames("lord_side.webp", 226, 374, "green")
    lord_s_atk  = extract_row_frames("lord_side.webp", 414, 566, "green", x_splits=[(6, 200), (214, 360), (362, 666), (666, 856), (860, 1006)])
    lord_s_hd   = extract_row_frames("lord_side.webp", 604, 756, "green", x_splits=[(32, 238), (238, 378), (380, 542), (550, 704), (705, 862), (864, 1010)])
    lord_s_ult  = lord_s_hd[0:3]
    lord_s_hurt = lord_s_hd[3:6]

    lord_f_idle = extract_row_frames("lord_fb.webp", 36, 186, "green", x_splits=[(55, 200), (220, 368), (390, 508)])
    lord_f_walk = extract_row_frames("lord_fb.webp", 36, 186, "green", x_splits=[(618, 822), (828, 982)])
    lord_f_ah   = extract_row_frames("lord_fb.webp", 222, 374, "green", x_splits=[(28, 178), (198, 355), (358, 558), (556, 738), (740, 874), (880, 1008)])
    lord_b_idle = extract_row_frames("lord_fb.webp", 414, 566, "green", x_splits=[(10, 176), (214, 358), (362, 508)])
    lord_b_walk = extract_row_frames("lord_fb.webp", 414, 566, "green", x_splits=[(534, 682), (690, 836), (842, 994)])
    lord_b_ah   = extract_row_frames("lord_fb.webp", 602, 756, "green", x_splits=[(42, 235), (236, 374), (378, 534), (538, 698), (698, 845), (848, 992)])

    build_view_sheet(os.path.join(OUT_DIR, "lord_side.png"), {
        "idle": lord_s_idle, "walk": lord_s_walk, "attack": lord_s_atk,
        "small": lord_s_atk, "ultimate": lord_s_ult, "hurt": lord_s_hurt, "down": ko_lord
    }, target_h=142.0)
    build_view_sheet(os.path.join(OUT_DIR, "lord_down.png"), {
        "idle": lord_f_idle, "walk": lord_f_walk, "attack": lord_f_ah[0:5],
        "small": lord_f_ah[0:5], "ultimate": lord_s_ult, "hurt": lord_f_ah[4:6], "down": ko_lord
    }, target_h=142.0)
    build_view_sheet(os.path.join(OUT_DIR, "lord_up.png"), {
        "idle": lord_b_idle, "walk": lord_b_walk, "attack": lord_b_ah[0:4],
        "small": lord_b_ah[0:4], "ultimate": lord_b_ah[2:4], "hurt": lord_b_ah[4:6], "down": ko_lord
    }, target_h=142.0)

    # 2. DRUID (德鲁伊) — protect_green=True on all green-screen frames + cleaned 2px magenta despill on magenta frames!
    dr_s_idle = extract_row_frames("druid_side.webp", 38, 184, "green", protect_green=True)
    dr_s_walk = extract_row_frames("druid_side.webp", 222, 362, "green", protect_green=True)
    dr_s_hd   = extract_row_frames("druid_side.webp", 602, 754, "green", protect_green=True)
    dr_m_f_ir  = extract_row_frames("druid_healer_redwolf_magenta.webp", 42, 186, "magenta", x_splits=[(26, 128), (148, 250), (268, 370), (398, 505)])
    dr_m_f_atk = extract_row_frames("druid_healer_redwolf_magenta.webp", 220, 360, "magenta", x_splits=[(24, 138), (138, 255), (254, 378), (378, 518)])
    dr_m_b_atk = extract_row_frames("druid_healer_redwolf_magenta.webp", 220, 360, "magenta", x_splits=[(524, 646), (646, 766), (766, 888), (888, 1012)])
    dr_fb_f_run = extract_row_frames("druid_wolves_fb.webp", 36, 180, "green", x_splits=[(268, 386), (404, 516)], protect_green=True)
    dr_fb_b_ir  = extract_row_frames("druid_wolves_fb.webp", 222, 360, "green", x_splits=[(12, 128), (134, 248), (250, 376), (378, 508)], protect_green=True)

    build_view_sheet(os.path.join(OUT_DIR, "druid_side.png"), {
        "idle": dr_s_idle, "walk": dr_s_walk, "attack": dr_m_f_atk,
        "small": dr_m_f_atk, "ultimate": [dr_m_f_atk[0], dr_m_f_atk[2], dr_m_f_atk[3], dr_m_f_atk[3]],
        "hurt": dr_s_hd[4:8], "down": ko_druid
    }, target_h=130.0)
    build_view_sheet(os.path.join(OUT_DIR, "druid_down.png"), {
        "idle": dr_m_f_ir[0:3], "walk": [dr_m_f_ir[3]] + dr_fb_f_run, "attack": dr_m_f_atk,
        "small": dr_m_f_atk, "ultimate": [dr_m_f_atk[0], dr_m_f_atk[2], dr_m_f_atk[3], dr_m_f_atk[3]],
        "hurt": dr_s_hd[4:8], "down": ko_druid
    }, target_h=130.0)
    build_view_sheet(os.path.join(OUT_DIR, "druid_up.png"), {
        "idle": dr_fb_b_ir[0:2], "walk": dr_fb_b_ir[2:4], "attack": dr_m_b_atk,
        "small": dr_m_b_atk, "ultimate": dr_m_b_atk, "hurt": dr_s_hd[4:8], "down": ko_druid
    }, target_h=130.0)

    # 2a. FROST WOLF (冰蓝狼)
    fw_s_idle = extract_row_frames("frost_wolf_side.webp", 38, 184, "green")
    fw_s_walk = extract_row_frames("frost_wolf_side.webp", 224, 368, "green", x_splits=[(4, 132), (132, 256), (256, 386), (386, 518), (518, 646), (646, 766), (766, 888), (888, 1018)])
    fw_s_atk  = extract_row_frames("frost_wolf_side.webp", 414, 560, "green", x_splits=[(4, 166), (166, 326), (324, 502), (500, 676), (674, 836), (842, 1012)])
    fw_s_hurt = extract_row_frames("frost_wolf_side.webp", 604, 756, "green")
    fw_fb     = extract_row_frames("druid_wolves_fb.webp", 414, 554, "green", x_splits=[(12, 122), (124, 214), (214, 444), (446, 678), (682, 762), (762, 834), (836, 1020)])

    build_view_sheet(os.path.join(OUT_DIR, "frost_wolf_side.png"), {
        "idle": fw_s_idle, "walk": fw_s_walk, "attack": fw_s_atk,
        "small": fw_s_atk, "ultimate": fw_s_atk, "hurt": fw_s_hurt, "down": [fw_s_hurt[-1]]
    }, target_h=96.0)
    build_view_sheet(os.path.join(OUT_DIR, "frost_wolf_down.png"), {
        "idle": fw_fb[0:2], "walk": fw_fb[0:2], "attack": fw_fb[2:4],
        "small": fw_fb[2:4], "ultimate": fw_fb[2:4], "hurt": fw_s_hurt, "down": [fw_s_hurt[-1]]
    }, target_h=96.0)
    build_view_sheet(os.path.join(OUT_DIR, "frost_wolf_up.png"), {
        "idle": [fw_fb[4]], "walk": fw_fb[4:6], "attack": [fw_fb[4], fw_fb[6], fw_fb[6]],
        "small": [fw_fb[4], fw_fb[6]], "ultimate": [fw_fb[4], fw_fb[6]], "hurt": fw_s_hurt, "down": [fw_s_hurt[-1]]
    }, target_h=96.0)

    # 2b. EMBER WOLF (赤红狼) — side from ember_wolf_side.webp (zero magenta!), front from magenta with clean top trim y0=596!
    ew_s_idle = extract_row_frames("ember_wolf_side.webp", 38, 184, "green")
    ew_s_walk = extract_row_frames("ember_wolf_side.webp", 224, 368, "green", x_splits=[(6, 130), (130, 256), (256, 382), (382, 512), (512, 642), (642, 766), (766, 892), (892, 1018)])
    ew_s_atk  = extract_row_frames("ember_wolf_side.webp", 414, 560, "green", x_splits=[(18, 188), (215, 408), (442, 678), (838, 1012)])
    ew_s_hurt = extract_row_frames("ember_wolf_side.webp", 604, 756, "green")
    ew_m_front = extract_row_frames("druid_healer_redwolf_magenta.webp", 596, 672, "magenta", x_splits=[(8, 120), (132, 244), (258, 376), (398, 502), (518, 622), (654, 750), (784, 876), (912, 1002)])
    ew_fb     = extract_row_frames("druid_wolves_fb.webp", 604, 756, "green", x_splits=[(26, 206), (270, 518), (562, 662), (674, 800), (812, 1016)])

    build_view_sheet(os.path.join(OUT_DIR, "ember_wolf_side.png"), {
        "idle": ew_s_idle, "walk": ew_s_walk, "attack": ew_s_atk,
        "small": ew_s_atk, "ultimate": ew_s_atk, "hurt": ew_s_hurt, "down": [ew_s_hurt[-1]]
    }, target_h=96.0)
    build_view_sheet(os.path.join(OUT_DIR, "ember_wolf_down.png"), {
        "idle": ew_m_front[0:4], "walk": ew_m_front[4:8], "attack": [ew_fb[0], ew_fb[1], ew_fb[1]],
        "small": [ew_fb[0], ew_fb[1]], "ultimate": [ew_fb[0], ew_fb[1]], "hurt": ew_s_hurt, "down": [ew_s_hurt[-1]]
    }, target_h=96.0)
    build_view_sheet(os.path.join(OUT_DIR, "ember_wolf_up.png"), {
        "idle": [ew_fb[2]], "walk": ew_fb[2:4], "attack": [ew_fb[2], ew_fb[4], ew_fb[4]],
        "small": [ew_fb[2], ew_fb[4]], "ultimate": [ew_fb[2], ew_fb[4]], "hurt": ew_s_hurt, "down": [ew_s_hurt[-1]]
    }, target_h=96.0)

    # 3. HEALER (爱神 / APHRODITE) — use tall consistent elegant Aphrodite from healer_side & healer_fb with protect_green=True on HEAL rows!
    hl_s_idle = extract_row_frames("healer_side.webp", 36, 186, "green")
    hl_s_walk = extract_row_frames("healer_side.webp", 224, 374, "green")
    hl_s_heal = extract_row_frames("healer_side.webp", 412, 564, "green", x_splits=[(26, 126), (154, 256), (278, 398), (412, 578), (628, 742), (764, 880), (900, 1008)], protect_green=True)
    hl_s_ah   = extract_row_frames("healer_side.webp", 604, 756, "green", x_splits=[(14, 128), (132, 236), (244, 348), (356, 495), (534, 638), (656, 758), (776, 878), (898, 998)])
    hl_f_idle = extract_row_frames("healer_fb.webp", 36, 186, "green", x_splits=[(18, 114), (128, 236), (246, 340), (358, 450)])
    hl_f_walk = extract_row_frames("healer_fb.webp", 36, 186, "green", x_splits=[(456, 564), (570, 676), (678, 785), (786, 894), (895, 994)])
    hl_f_heal = extract_row_frames("healer_fb.webp", 222, 374, "green", x_splits=[(18, 142), (158, 258), (282, 396), (408, 566)], protect_green=True)
    hl_b_idle = extract_row_frames("healer_fb.webp", 412, 566, "green", x_splits=[(26, 130), (158, 252), (282, 378), (392, 500)])
    hl_b_walk = extract_row_frames("healer_fb.webp", 412, 566, "green", x_splits=[(514, 616), (620, 746), (766, 876), (892, 994)])
    hl_b_heal = extract_row_frames("healer_fb.webp", 602, 756, "green", x_splits=[(16, 112), (128, 252), (264, 366), (390, 492)], protect_green=True)
    hl_b_atk  = extract_row_frames("healer_fb.webp", 602, 756, "green", x_splits=[(536, 654), (656, 746), (758, 874), (898, 994)])

    build_view_sheet(os.path.join(OUT_DIR, "healer_side.png"), {
        "idle": hl_s_idle, "walk": hl_s_walk, "attack": hl_s_ah[0:4],
        "small": hl_s_heal[0:4], "ultimate": hl_s_heal, "hurt": hl_s_ah[4:8], "down": ko_healer
    }, target_h=130.0)
    build_view_sheet(os.path.join(OUT_DIR, "healer_down.png"), {
        "idle": hl_f_idle, "walk": hl_f_walk, "attack": hl_s_ah[0:4],
        "small": hl_f_heal, "ultimate": hl_f_heal, "hurt": hl_s_ah[4:8], "down": ko_healer
    }, target_h=130.0)
    build_view_sheet(os.path.join(OUT_DIR, "healer_up.png"), {
        "idle": hl_b_idle, "walk": hl_b_walk, "attack": hl_b_atk[0:3],
        "small": hl_b_heal, "ultimate": hl_b_heal, "hurt": [hl_b_atk[3]], "down": ko_healer
    }, target_h=130.0)

    # 4a. WEREWOLF HUMAN FORM
    ww_s_idle = extract_row_frames("werewolf_side.webp", 36, 186, "green", x_splits=[(30, 126), (146, 242), (262, 358), (378, 474), (498, 604), (612, 724)])
    ww_s_walk = extract_row_frames("werewolf_side.webp", 228, 370, "green", x_splits=[(14, 130), (140, 260), (266, 376), (382, 502)])
    ww_s_hatk = extract_row_frames("werewolf_extra.webp", 36, 186, "green", x_splits=[(30, 128), (160, 320), (346, 480), (614, 858), (880, 986)])
    ww_s_ult  = extract_row_frames("werewolf_side.webp", 408, 566, "green", x_splits=[(12, 200), (212, 384), (396, 720)])
    ww_s_hd   = extract_row_frames("werewolf_side.webp", 612, 756, "green", x_splits=[(12, 234), (242, 512), (522, 666), (672, 876), (884, 1014)])
    ww_f_idle = extract_row_frames("werewolf_fb.webp", 36, 186, "green", x_splits=[(32, 128), (150, 248), (268, 364), (386, 474)])
    ww_f_walk = extract_row_frames("werewolf_fb.webp", 36, 186, "green", x_splits=[(506, 628), (630, 746), (752, 868), (870, 1002)])
    ww_b_idle = extract_row_frames("werewolf_fb.webp", 408, 566, "green", x_splits=[(34, 138), (154, 258), (274, 378), (394, 498)])
    ww_b_walk = extract_row_frames("werewolf_fb.webp", 408, 566, "green", x_splits=[(558, 704), (712, 868), (874, 1004)])

    build_view_sheet(os.path.join(OUT_DIR, "werewolf_side.png"), {
        "idle": ww_s_idle[0:4], "walk": ww_s_walk, "attack": ww_s_hatk,
        "small": [ww_s_idle[4], ww_s_idle[5], ww_s_hatk[1], ww_s_hatk[3]], "ultimate": ww_s_ult,
        "hurt": [ww_s_hd[2], ww_s_hd[4]], "down": ko_werewolf
    }, target_h=134.0)
    build_view_sheet(os.path.join(OUT_DIR, "werewolf_down.png"), {
        "idle": ww_f_idle, "walk": ww_f_walk, "attack": ww_s_hatk,
        "small": ww_s_hatk, "ultimate": ww_s_ult,
        "hurt": [ww_s_hd[2], ww_s_hd[4]], "down": ko_werewolf
    }, target_h=134.0)
    build_view_sheet(os.path.join(OUT_DIR, "werewolf_up.png"), {
        "idle": ww_b_idle, "walk": ww_b_walk, "attack": ww_s_hatk,
        "small": ww_s_hatk, "ultimate": ww_s_ult,
        "hurt": [ww_s_hd[2], ww_s_hd[4]], "down": ko_werewolf
    }, target_h=134.0)

    # 4b. WEREWOLF BEAST FORM
    wb_s_idle = extract_row_frames("werewolf_extra.webp", 228, 372, "green", x_splits=[(14, 256), (304, 568)])
    wb_s_walk = extract_row_frames("werewolf_extra.webp", 228, 372, "green", x_splits=[(614, 782), (800, 992)]) + \
                extract_row_frames("werewolf_side.webp", 228, 370, "green", x_splits=[(816, 1002)])
    wb_s_atk  = extract_row_frames("werewolf_side.webp", 408, 566, "green", x_splits=[(212, 384), (396, 720), (732, 880)])
    wb_f_idle = extract_row_frames("werewolf_extra.webp", 412, 566, "green", x_splits=[(10, 146), (150, 260), (262, 392), (404, 536)])
    wb_f_walk = extract_row_frames("werewolf_extra.webp", 412, 566, "green", x_splits=[(596, 796), (798, 1008)])
    wb_f_atk  = extract_row_frames("werewolf_fb.webp", 226, 374, "green", x_splits=[(274, 392), (394, 520), (522, 704), (704, 840), (840, 1018)])
    wb_b_idle = extract_row_frames("werewolf_extra.webp", 608, 756, "green", x_splits=[(26, 138), (162, 258), (280, 386), (400, 512)])
    wb_b_walk = extract_row_frames("werewolf_extra.webp", 608, 756, "green", x_splits=[(552, 662), (662, 764), (764, 882), (882, 1008)])
    wb_b_atk  = extract_row_frames("werewolf_fb.webp", 608, 756, "green", x_splits=[(20, 236), (242, 512), (518, 722), (724, 882)])

    build_view_sheet(os.path.join(OUT_DIR, "werewolf_beast_side.png"), {
        "idle": wb_s_idle, "walk": wb_s_walk, "attack": wb_s_atk,
        "small": wb_s_atk, "ultimate": wb_s_atk, "hurt": [wb_s_atk[2]], "down": ko_werewolf
    }, target_h=140.0)
    build_view_sheet(os.path.join(OUT_DIR, "werewolf_beast_down.png"), {
        "idle": wb_f_idle, "walk": wb_f_walk, "attack": wb_f_atk,
        "small": wb_f_atk, "ultimate": wb_f_atk, "hurt": [wb_f_atk[0]], "down": ko_werewolf
    }, target_h=140.0)
    build_view_sheet(os.path.join(OUT_DIR, "werewolf_beast_up.png"), {
        "idle": wb_b_idle, "walk": wb_b_walk, "attack": wb_b_atk,
        "small": wb_b_atk, "ultimate": wb_b_atk, "hurt": [wb_b_atk[3]], "down": ko_werewolf
    }, target_h=140.0)

    # 5. GUNNER (星衡 / SYRUS)
    gn_s_idle = extract_row_frames("gunner_side.webp", 36, 186, "green")
    gn_s_walk = extract_row_frames("gunner_side.webp", 224, 374, "green")
    gn_s_atk  = extract_row_frames("gunner_side.webp", 412, 566, "green", x_splits=[(32, 152), (156, 280), (288, 434), (414, 622), (632, 752), (756, 874), (882, 998)])
    gn_s_roll = extract_row_frames("gunner_side.webp", 604, 756, "green", x_splits=[(32, 150), (146, 274), (272, 408), (416, 512)])
    gn_s_hurt = extract_row_frames("gunner_side.webp", 604, 756, "green", x_splits=[(548, 650), (654, 760), (772, 872), (886, 1000)])

    gn_f_idle = extract_row_frames("gunner_fb.webp", 36, 186, "green", x_splits=[(42, 136), (162, 258), (282, 378), (404, 498)])
    gn_f_walk = extract_row_frames("gunner_fb.webp", 36, 186, "green", x_splits=[(530, 630), (642, 750), (760, 872), (894, 994)])
    gn_f_atk  = extract_row_frames("gunner_fb.webp", 224, 374, "green", x_splits=[(42, 136), (162, 282), (286, 410), (410, 532)])
    gn_f_roll = extract_row_frames("gunner_fb.webp", 224, 374, "green", x_splits=[(528, 632), (626, 752), (750, 874), (892, 994)])

    gn_b_idle = extract_row_frames("gunner_fb.webp", 412, 566, "green", x_splits=[(26, 114), (150, 240), (278, 366), (402, 490)])
    gn_b_walk = extract_row_frames("gunner_fb.webp", 412, 566, "green", x_splits=[(526, 612), (642, 730), (740, 850), (880, 972)])
    gn_b_atk  = extract_row_frames("gunner_fb.webp", 604, 756, "green", x_splits=[(38, 164), (165, 288), (290, 416), (418, 502)])
    gn_b_roll = extract_row_frames("gunner_fb.webp", 604, 756, "green", x_splits=[(522, 636), (648, 760), (784, 874), (886, 992)])

    build_view_sheet(os.path.join(OUT_DIR, "gunner_side.png"), {
        "idle": gn_s_idle, "walk": gn_s_walk, "attack": gn_s_atk,
        "small": gn_s_roll, "ultimate": gn_s_atk[1:5], "hurt": gn_s_hurt, "down": ko_gunner
    }, target_h=126.0)
    build_view_sheet(os.path.join(OUT_DIR, "gunner_down.png"), {
        "idle": gn_f_idle, "walk": gn_f_walk, "attack": gn_f_atk,
        "small": gn_f_roll, "ultimate": gn_f_atk, "hurt": gn_s_hurt, "down": ko_gunner
    }, target_h=126.0)
    build_view_sheet(os.path.join(OUT_DIR, "gunner_up.png"), {
        "idle": gn_b_idle, "walk": gn_b_walk, "attack": gn_b_atk,
        "small": gn_b_roll, "ultimate": gn_b_atk, "hurt": gn_s_hurt, "down": ko_gunner
    }, target_h=126.0)

    # VISUAL AUDIT CONTACT SHEET
    actors = ["lord", "druid", "healer", "werewolf", "werewolf_beast", "gunner", "frost_wolf", "ember_wolf"]
    thumb = 128
    audit = Image.new("RGBA", (thumb * 8, thumb * len(actors)), (38, 42, 52, 255))
    draw = ImageDraw.Draw(audit)
    for y in range(0, audit.height, 16):
        for x in range(0, audit.width, 16):
            if ((x // 16) + (y // 16)) % 2 == 0:
                draw.rectangle([x, y, x + 15, y + 15], fill=(48, 52, 64, 255))

    for r_i, key in enumerate(actors):
        p_path = os.path.join(OUT_DIR, f"portrait_{key}.png")
        if os.path.exists(p_path):
            pi = Image.open(p_path).resize((thumb - 8, thumb - 8), Image.Resampling.NEAREST)
            audit.paste(pi, (4, r_i * thumb + 4), pi)
        s_img = Image.open(os.path.join(OUT_DIR, f"{key}_side.png"))
        d_img = Image.open(os.path.join(OUT_DIR, f"{key}_down.png"))
        u_img = Image.open(os.path.join(OUT_DIR, f"{key}_up.png"))
        picks = [
            (s_img, 0, 1),
            (s_img, 1, 2),
            (s_img, 2, 4),
            (s_img, 4, 4),
            (d_img, 0, 1),
            (u_img, 0, 1),
            (s_img, 6, 7),
        ]
        for c_i, (img, row_s, col_s) in enumerate(picks):
            cell = img.crop((col_s * CELL, row_s * CELL, (col_s + 1) * CELL, (row_s + 1) * CELL))
            t = cell.resize((thumb, thumb), Image.Resampling.NEAREST)
            audit.paste(t, ((c_i + 1) * thumb, r_i * thumb), t)
        draw.text((6, r_i * thumb + 4), key, fill=(255, 240, 130, 255))

    audit.save(AUDIT_PATH)
    print(f"Rebuilt all 24 sheets + 10 portraits cleanly.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build v0.22 hero sprite sheets from the original artwork.")
    parser.add_argument("--raw-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, default=PROJECT / "assets/heroes_v022")
    parser.add_argument("--audit", type=Path, default=PROJECT / "test-results/v022-art/hero_slice_audit.png")
    args = parser.parse_args()
    RAW_DIR = args.raw_dir.resolve(strict=True)
    OUT_DIR = args.out_dir.resolve()
    AUDIT_PATH = args.audit.resolve()
    build_all()
