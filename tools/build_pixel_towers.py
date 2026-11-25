import argparse
import json
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]

TOWER_CELL = 256
TOWER_COLS = 4
TOWER_FOOT_Y = 236  # 236 / 256 = 0.921875

SOLDIER_CELL = 192
SOLDIER_COLS = 6
SOLDIER_FOOT_FRAC = 0.875  # Matches v023 monster spec (168 / 192)


def load_rgb(raw_dir: Path, name: str) -> np.ndarray:
    return np.array(Image.open(raw_dir / name).convert("RGBA"))


def find_header_bars(arr: np.ndarray, expected_rows: int) -> list:
    h, w, _ = arr.shape
    rgb = arr[:, :, :3].astype(np.int32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    is_green = (g > 150) & (g - r > 60) & (g - b > 60)
    is_mag = (r > 150) & (b > 150) & (r - g > 60) & (b - g > 60)
    bg_frac = np.maximum(is_green.mean(axis=1), is_mag.mean(axis=1))
    is_dark = (rgb.max(axis=2) < 62).mean(axis=1)
    is_bar = (bg_frac < 0.15) & (is_dark > 0.45)

    bars = []
    y = 0
    while y < h:
        if is_bar[y]:
            s = y
            while y < h and (is_bar[y] or (y + 1 < h and is_bar[y:min(h, y + 7)].any())):
                y += 1
            if y - s >= 12:
                bars.append((s, y))
        else:
            y += 1
    if len(bars) != expected_rows:
        raise RuntimeError(f"Expected {expected_rows} header bars, detected {len(bars)}: {bars}")
    return bars


def bg_candidate_mask(arr: np.ndarray, mode: str) -> np.ndarray:
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)
    if mode == "green":
        # Protect sky blue / cyan electricity (B >= G - 22) and desaturated stone/metal
        return (g > 118) & ((g - r) > 46) & ((g - b) > 38)
    elif mode == "magenta":
        return (r > 128) & (b > 128) & ((r - g) > 42) & ((b - g) > 42) & (np.abs(r - b) < 88)
    else:
        raise ValueError(f"Unknown chroma mode: {mode}")


def dilate(mask: np.ndarray, iters: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(iters):
        d = out.copy()
        d[1:, :] |= out[:-1, :]
        d[:-1, :] |= out[1:, :]
        d[:, 1:] |= out[:, :-1]
        d[:, :-1] |= out[:, 1:]
        out = d
    return out


def chroma_key(crop_rgba: np.ndarray, mode: str) -> np.ndarray:
    crop = crop_rgba.copy()
    h, w, _ = crop.shape
    cand = bg_candidate_mask(crop, mode)

    # 1. Border flood-fill (4-connected)
    bg = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if cand[0, x] and not bg[0, x]:
            bg[0, x] = True; q.append((0, x))
        if cand[h - 1, x] and not bg[h - 1, x]:
            bg[h - 1, x] = True; q.append((h - 1, x))
    for y in range(h):
        if cand[y, 0] and not bg[y, 0]:
            bg[y, 0] = True; q.append((y, 0))
        if cand[y, w - 1] and not bg[y, w - 1]:
            bg[y, w - 1] = True; q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and cand[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    # 2. Clear enclosed interior holes (arches, bows, struts, rope mesh, between legs)
    r = crop[:, :, 0].astype(np.int32)
    g = crop[:, :, 1].astype(np.int32)
    b = crop[:, :, 2].astype(np.int32)
    if mode == "green":
        strict = (g > 135) & ((g - r) > 52) & ((g - b) > 45) & (r < 125) & (b < 125)
    else:
        strict = (r > 118) & (b > 118) & ((r - g) > 38) & ((b - g) > 38) & (np.abs(r - b) < 88) & (g < 130)

    rem = strict & (~bg)
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
        if len(comp) >= 1:
            for cy, cx in comp:
                bg[cy, cx] = True

    crop[bg, 3] = 0

    # 3. 1px Halo Fringe Removal + 2px Chroma Despill (including bright comic magenta outlines)
    r = crop[:, :, 0].astype(np.int32)
    g = crop[:, :, 1].astype(np.int32)
    b = crop[:, :, 2].astype(np.int32)
    edge1 = dilate(bg, 1) & (~bg)
    edge2 = dilate(bg, 2) & (~bg)

    if mode == "green":
        fringe = edge1 & (g > 100) & ((g - r) > 24) & ((g - b) > 18)
        crop[fringe, 3] = 0
        bg |= fringe
        edge2 = dilate(bg, 2) & (~bg)
        sp = edge2 & (g > np.maximum(r, b) + 10)
        crop[sp, 1] = np.minimum(crop[sp, 1], np.maximum(crop[sp, 0], crop[sp, 2]))
    else:
        fringe = edge1 & (r > 102) & (b > 102) & ((r - g) > 22) & ((b - g) > 22) & (np.abs(r - b) < 92)
        crop[fringe, 3] = 0
        bg |= fringe
        edge2 = dilate(bg, 2) & (~bg)
        sp = edge2 & (r > g + 10) & (b > g + 10) & (np.abs(r - b) < 88)
        avg = ((r[sp] + b[sp]) // 2).clip(0, 255)
        cap = np.minimum(g[sp] + 6, avg)
        crop[sp, 0] = cap
        crop[sp, 2] = cap

    return crop


def split_columns(row_rgba: np.ndarray, cols: int, mode: str) -> list:
    h, w, _ = row_rgba.shape
    cand = bg_candidate_mask(row_rgba, mode)
    # Trim top/bottom dark header bleed before measuring density
    fg_col = (~cand[4:max(5, h - 4), :]).sum(axis=0)
    cuts = [0]
    margin = max(18, int(w / cols * 0.16))
    for k in range(1, cols):
        nom = int(round(w * k / cols))
        lo = max(cuts[-1] + 20, nom - margin)
        hi = min(w - 20, nom + margin)
        win = fg_col[lo:hi + 1]
        min_v = int(win.min())
        best_indices = np.where(win == min_v)[0]
        # Prefer center of widest clear gap
        split_x = lo + int(round(float(np.median(best_indices))))
        cuts.append(split_x)
    cuts.append(w)
    return [(cuts[i], cuts[i + 1]) for i in range(cols)]


def connected_components_8(mask: np.ndarray) -> list:
    h, w = mask.shape
    visited = np.zeros((h, w), dtype=bool)
    comps = []
    ys, xs = np.where(mask)
    for sy, sx in zip(ys, xs):
        if visited[sy, sx]:
            continue
        q = deque([(sy, sx)])
        visited[sy, sx] = True
        pts = []
        x0 = x1 = sx
        y0 = y1 = sy
        while q:
            cy, cx = q.popleft()
            pts.append((cy, cx))
            if cx < x0: x0 = cx
            if cx > x1: x1 = cx
            if cy < y0: y0 = cy
            if cy > y1: y1 = cy
            for dy in (-1, 0, 1):
                ny = cy + dy
                if ny < 0 or ny >= h:
                    continue
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    nx = cx + dx
                    if 0 <= nx < w and not visited[ny, nx] and mask[ny, nx]:
                        visited[ny, nx] = True
                        q.append((ny, nx))
        comps.append({"pts": pts, "area": len(pts), "bbox": (x0, y0, x1 + 1, y1 + 1)})
    comps.sort(key=lambda c: c["area"], reverse=True)
    return comps


def clean_floating_artifacts(cell: np.ndarray, rule: str = "", ref_bbox: tuple = None) -> np.ndarray:
    """Remove disconnected comic-book marks / arrows / stray specks without touching the tower/soldier."""
    out = cell.copy()
    alpha = out[:, :, 3] > 20
    comps = connected_components_8(alpha)
    if not comps:
        return out
    main = comps[0]
    mx0, my0, mx1, my1 = ref_bbox if ref_bbox is not None else main["bbox"]
    mw = max(1, mx1 - mx0)
    mh = max(1, my1 - my0)
    main_area = main["area"]

    # Bottom-half solid structure X bounds (invariant across cell split offsets)
    ys_a, xs_a = np.where(alpha)
    if len(ys_a) > 20:
        half_y = int(np.percentile(ys_a, 45))
        low_xs = xs_a[ys_a >= half_y]
        base_x0 = int(np.percentile(low_xs, 1)) if len(low_xs) > 10 else mx0
        base_x1 = int(np.percentile(low_xs, 99)) if len(low_xs) > 10 else mx1
        top_y = int(np.percentile(ys_a, 2))
    else:
        base_x0, base_x1, top_y = mx0, mx1, my0

    for c in comps[1:]:
        cx0, cy0, cx1, cy1 = c["bbox"]
        cw = cx1 - cx0
        ch = cy1 - cy0
        area = c["area"]
        cy_mid = 0.5 * (cy0 + cy1)
        h_cell, w_cell = out.shape[:2]

        erase = False
        if area <= 14:
            erase = True
        elif "no_floating_above" in rule and cy_mid <= top_y + int(mh * 0.16) and area < main_area * 0.06:
            erase = True
        elif rule == "snare_above_all":
            if cy1 <= my0 + int(mh * 0.30) and area < main_area * 0.06:
                erase = True
        elif rule == "snare_rearm_arrow":
            if cy1 <= my0 + int(mh * 0.42) and cx0 >= base_x0 + int((base_x1 - base_x0) * 0.55) and area < main_area * 0.09:
                erase = True
        elif rule == "archer_l3_fire":
            # Any small/detached object floating to the right (flying bolts: wide & flat) or comic brackets/pebbles
            is_flying_bolt = (cx0 >= w_cell * 0.62) and (cw > ch * 1.8) and (area < main_area * 0.06)
            is_detached_right = cx0 >= w_cell * 0.72 and area < main_area * 0.08
            is_bracket_or_dot = area < main_area * 0.022 and (cx1 < w_cell * 0.26 or cx0 > w_cell * 0.74)
            if is_flying_bolt or is_detached_right or is_bracket_or_dot:
                erase = True
        elif rule == "archer_l3_recover":
            if area < main_area * 0.03 and cx0 >= base_x1 - 12 and cw < 32:
                erase = True
        elif rule == "snare_net_clean":
            # Stray marks above net or vertical line outside left edge
            if (cy_mid < my0 + int(mh * 0.34) or cx1 < base_x0 - 4) and area < main_area * 0.05:
                erase = True
        elif rule == "soldier_hurt":
            if cy1 <= top_y + int(mh * 0.24) and area < main_area * 0.06:
                erase = True
        elif rule == "prop_above_clean":
            if cy1 <= my0 + int(mh * 0.28) and area < main_area * 0.08:
                erase = True

        if erase:
            for py, px in c["pts"]:
                out[py, px, 3] = 0
    return out


def frame_bbox(arr: np.ndarray, alpha_thresh: int = 25):
    ys, xs = np.where(arr[:, :, 3] > alpha_thresh)
    if len(ys) == 0:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def find_stable_base_anchor(arr: np.ndarray):
    """Anchor on bottom 35% solid silhouette to ignore muzzle flashes, lightning, or dust wings."""
    m = frame_bbox(arr)
    if m is None:
        return None
    x0, y0, x1, y1 = m
    h = y1 - y0
    base_y0 = y0 + int(h * 0.58)
    base_mask = arr[base_y0:y1, :, 3] > 80
    ys, xs = np.where(base_mask)
    if len(xs) < 20:
        return (x0, y0, x1, y1, 0.5 * (x0 + x1), float(y1))
    # Robust horizontal bounds of base via 5th-95th percentile, avoiding single stray flame sparks
    bx0 = float(np.percentile(xs, 3))
    bx1 = float(np.percentile(xs, 97))
    cx = 0.5 * (bx0 + bx1)
    by = float(base_y0 + np.max(ys) + 1)
    return (x0, y0, x1, y1, cx, by)


def compute_base_deltas(frames: list) -> list:
    """Align frames 1..N-1 to frame 0 (IDLE) using bottom-38% grayscale L1 template matching."""
    base_a0 = find_stable_base_anchor(frames[0])
    if base_a0 is None:
        return [(0, 0) for _ in frames]
    ref_x0, ref_y0, ref_x1, ref_y1, ref_cx, ref_by = base_a0
    ref_h = ref_y1 - ref_y0
    # Crop template from bottom 36% of IDLE tower
    ty0 = max(ref_y0, int(ref_by - ref_h * 0.36))
    ty1 = min(frames[0].shape[0], int(ref_by))
    tx0 = max(0, int(ref_cx - (ref_x1 - ref_x0) * 0.38))
    tx1 = min(frames[0].shape[1], int(ref_cx + (ref_x1 - ref_x0) * 0.38))

    def lum_and_alpha(im):
        rgb = im[:, :, :3].astype(np.float32)
        l = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
        a = (im[:, :, 3] > 60)
        return l, a

    l0, a0 = lum_and_alpha(frames[0])
    tmpl_l = l0[ty0:ty1, tx0:tx1]
    tmpl_a = a0[ty0:ty1, tx0:tx1]

    deltas = [(0, 0)]
    for fi in range(1, len(frames)):
        fa = find_stable_base_anchor(frames[fi])
        if fa is None:
            deltas.append((0, 0))
            continue
        _, _, _, _, f_cx, f_by = fa
        init_dx = int(round(f_cx - ref_cx))
        init_dy = int(round(f_by - ref_by))
        lf, af = lum_and_alpha(frames[fi])
        fh, fw = lf.shape
        th, tw = tmpl_l.shape

        best_score = 1e18
        best_d = (init_dx, init_dy)
        for ddy in range(init_dy - 10, init_dy + 11):
            sy0 = ty0 + ddy
            sy1 = sy0 + th
            if sy0 < 0 or sy1 > fh:
                continue
            for ddx in range(init_dx - 16, init_dx + 17):
                sx0 = tx0 + ddx
                sx1 = sx0 + tw
                if sx0 < 0 or sx1 > fw:
                    continue
                valid = tmpl_a & af[sy0:sy1, sx0:sx1]
                overlap = int(valid.sum())
                if overlap < int(tmpl_a.sum() * 0.55):
                    continue
                diff = np.abs(tmpl_l[valid] - lf[sy0:sy1, sx0:sx1][valid]).mean()
                # Also reward mask match
                xor_pen = float((tmpl_a ^ af[sy0:sy1, sx0:sx1]).mean()) * 140.0
                score = float(diff) + xor_pen
                if score < best_score:
                    best_score = score
                    best_d = (ddx, ddy)
        deltas.append(best_d)
    return deltas


def build_tower_strip(out_path: Path, frames: list, target_idle_h: float) -> dict:
    """Scale all 4 frames identically with nearest-neighbor / crisp pixel resampling, aligned to IDLE stone base."""
    deltas = compute_base_deltas(frames)
    a0 = find_stable_base_anchor(frames[0])
    assert a0 is not None
    ix0, iy0, ix1, iy1, ref_cx, ref_by = a0
    h_idle = max(20.0, ref_by - iy0)

    # Check bounding extents across all 4 frames in reference frame coordinates to ensure zero clipping at 256x256
    min_rx, max_rx = 1e9, -1e9
    min_ry = 1e9
    for fi, (f, (dx, dy)) in enumerate(zip(frames, deltas)):
        bb = frame_bbox(f, 20)
        if bb is None:
            continue
        fx0, fy0, fx1, fy1 = bb
        rx0 = (fx0 - dx) - ref_cx
        rx1 = (fx1 - dx) - ref_cx
        ry0 = (fy0 - dy) - ref_by
        min_rx = min(min_rx, rx0)
        max_rx = max(max_rx, rx1)
        min_ry = min(min_ry, ry0)

    scale = target_idle_h / h_idle
    # Clamp scale only if an attack explosion exceeds 256x256 safe margins
    half_x_avail = 122.0
    top_y_avail = float(TOWER_FOOT_Y - 6)
    if -min_rx > 1 and -min_rx * scale > half_x_avail:
        scale = min(scale, half_x_avail / (-min_rx))
    if max_rx > 1 and max_rx * scale > half_x_avail:
        scale = min(scale, half_x_avail / max_rx)
    if -min_ry > 1 and -min_ry * scale > top_y_avail:
        scale = min(scale, top_y_avail / (-min_ry))

    strip = Image.new("RGBA", (TOWER_CELL * TOWER_COLS, TOWER_CELL), (0, 0, 0, 0))
    frame_boxes = []
    for fi, (f, (dx, dy)) in enumerate(zip(frames, deltas)):
        bb = frame_bbox(f, 15)
        if bb is None:
            continue
        fx0, fy0, fx1, fy1 = bb
        trimmed = Image.fromarray(f[fy0:fy1, fx0:fx1])
        tw, th = trimmed.size
        nw = max(1, int(round(tw * scale)))
        nh = max(1, int(round(th * scale)))
        # Crisp box/nearest mix: for integer or ~0.65x pixel-art downscale, LANCZOS/BOX creates ugly blur, while NEAREST keeps crisp dark outlines.
        # However slightly cleaner results happen with Image.Resampling.NEAREST on dark pixel art sprites.
        resized = trimmed.resize((nw, nh), Image.Resampling.NEAREST)
        dst_x = int(round(TOWER_CELL * 0.5 + ((fx0 - dx) - ref_cx) * scale))
        dst_y = int(round(TOWER_FOOT_Y + ((fy0 - dy) - ref_by) * scale))
        dst_x = max(2, min(TOWER_CELL - nw - 2, dst_x))
        dst_y = max(2, min(TOWER_CELL - nh - 2, dst_y))
        strip.paste(resized, (fi * TOWER_CELL + dst_x, dst_y), resized)
        frame_boxes.append((dst_x, dst_y, dst_x + nw, dst_y + nh))

    strip.save(out_path)
    # Estimate bright burst center on Frame 2 (FIRE/CAST/ZAP/BEAM/DEPLOY) as default muzzle UV
    f2 = np.array(strip.crop((2 * TOWER_CELL, 0, 3 * TOWER_CELL, TOWER_CELL)))
    a2 = f2[:, :, 3] > 60
    lum2 = 0.299 * f2[:, :, 0].astype(np.float32) + 0.587 * f2[:, :, 1].astype(np.float32) + 0.114 * f2[:, :, 2].astype(np.float32)
    bright = a2 & (lum2 > 225.0)
    # Prefer upper 72% so threshold dust doesn't pull muzzle down
    bright_up = bright.copy()
    bright_up[int(TOWER_FOOT_Y * 0.72):, :] = False
    ys_b, xs_b = np.where(bright_up)
    if len(xs_b) >= 6:
        mx = float(np.median(xs_b)) / float(TOWER_CELL)
        my = float(np.median(ys_b)) / float(TOWER_CELL)
    else:
        mx = 0.5
        my = 0.42
    return {
        "file": out_path.name,
        "idle_h_px": round(h_idle * scale, 1),
        "base_width_px": round((a0[2] - a0[0]) * scale, 1),
        "muzzle_uv": [round(mx, 4), round(my, 4)],
    }


def extract_sheet_rows(raw_dir: Path, filename: str, num_rows: int, num_cols: int, mode: str,
                       row_clean_rules: dict = None) -> list:
    arr = load_rgb(raw_dir, filename)
    h, w, _ = arr.shape
    bars = find_header_bars(arr, num_rows)
    row_clean_rules = row_clean_rules or {}
    all_rows = []
    for ri in range(num_rows):
        y0 = min(h - 1, bars[ri][1] + 2)
        y1 = max(y0 + 10, (bars[ri + 1][0] - 1) if (ri + 1 < num_rows) else h)
        row_band = arr[y0:y1, :, :]
        col_spans = split_columns(row_band, num_cols, mode)
        row_frames = []
        idle_ref_bb = None
        for ci, (cx0, cx1) in enumerate(col_spans):
            cell_raw = row_band[:, cx0:cx1, :]
            keyed = chroma_key(cell_raw, mode)
            if ci == 0:
                idle_ref_bb = frame_bbox(keyed, 20)
            rule = row_clean_rules.get((ri, ci), row_clean_rules.get((-1, ci), ""))
            keyed = clean_floating_artifacts(keyed, rule, idle_ref_bb)
            row_frames.append(keyed)
        all_rows.append(row_frames)
    return all_rows


def build_soldier_sheet(out_path: Path, frames_6: list, target_h: float = 112.0):
    """Build 6x3 soldier sprite sheet matching ArenaCreature 6x3 v023 spec (walk, attack, down)."""
    # frames_6: [walkA, walkB, windup, strike, hurt, defeated]
    # Use walk frames for ref scale
    heights = []
    for f in frames_6[:2]:
        bb = frame_bbox(f)
        if bb:
            heights.append(bb[3] - bb[1])
    ref_h = float(np.median(heights)) if heights else 120.0
    scale = target_h / max(20.0, ref_h)

    # Check attack frames width/height so strike slash fits cleanly inside 192x192
    for f in frames_6[2:4]:
        bb = frame_bbox(f)
        if bb:
            tw, th = bb[2] - bb[0], bb[3] - bb[1]
            scale = min(scale, 180.0 / max(1, tw), 178.0 / max(1, th))

    def place(arr, anchor_mode="foot", dx_bias=0, dy_bias=0):
        cell = Image.new("RGBA", (SOLDIER_CELL, SOLDIER_CELL), (0, 0, 0, 0))
        bb = frame_bbox(arr, 20)
        if bb is None:
            return cell
        x0, y0, x1, y1 = bb
        ys, xs = np.where(arr[:, :, 3] > 40)
        foot_cut = y1 - max(4, int((y1 - y0) * 0.20))
        foot_xs = xs[ys >= foot_cut]
        foot_cx = float(np.median(foot_xs)) if len(foot_xs) > 0 else 0.5 * (x0 + x1)

        trimmed = Image.fromarray(arr[y0:y1, x0:x1])
        nw = max(1, int(round((x1 - x0) * scale)))
        nh = max(1, int(round((y1 - y0) * scale)))
        resized = trimmed.resize((nw, nh), Image.Resampling.NEAREST)

        foot_y = int(round(SOLDIER_CELL * SOLDIER_FOOT_FRAC)) + dy_bias
        if anchor_mode == "center":
            px = int(round(SOLDIER_CELL * 0.5 - nw * 0.5)) + dx_bias
        else:
            px = int(round(SOLDIER_CELL * 0.5 - (foot_cx - x0) * scale)) + dx_bias
        px = max(2, min(SOLDIER_CELL - nw - 2, px))
        py = max(2, min(SOLDIER_CELL - nh - 2, foot_y - nh))
        cell.paste(resized, (px, py), resized)
        return cell

    rows = [
        # Row 0: walk (6 frames: crisp 2-stride bounce cycle)
        [
            place(frames_6[0], "foot", 0, 0),
            place(frames_6[0], "foot", 0, -3),
            place(frames_6[0], "foot", 0, -1),
            place(frames_6[1], "foot", 0, 0),
            place(frames_6[1], "foot", 0, -3),
            place(frames_6[1], "foot", 0, -1),
        ],
        # Row 1: attack (6 frames: guard -> windup -> windup -> strike -> strike follow -> recover)
        [
            place(frames_6[0], "foot", 0, 0),
            place(frames_6[2], "foot", -4, 0),
            place(frames_6[2], "foot", -2, 0),
            place(frames_6[3], "foot", 6, 0),
            place(frames_6[3], "foot", 4, 0),
            place(frames_6[0], "foot", 0, 0),
        ],
        # Row 2: down (6 frames: hurt stagger -> defeated ground)
        [
            place(frames_6[4], "foot", -4, 0),
            place(frames_6[4], "foot", -2, 2),
            place(frames_6[5], "center", 0, 4),
            place(frames_6[5], "center", 0, 4),
            place(frames_6[5], "center", 0, 4),
            place(frames_6[5], "center", 0, 4),
        ],
    ]
    sheet = Image.new("RGBA", (SOLDIER_CELL * SOLDIER_COLS, SOLDIER_CELL * 3), (0, 0, 0, 0))
    for r_i, row_cells in enumerate(rows):
        for c_i, cell in enumerate(row_cells):
            sheet.paste(cell, (c_i * SOLDIER_CELL, r_i * SOLDIER_CELL), cell)
    sheet.save(out_path)


def build_prop_strip(out_path: Path, frames: list, cell_w: int, cell_h: int,
                     anchor: str = "center", align_to_first: bool = False):
    """Build single-row prop sprite sheet with consistent scale."""
    deltas = compute_base_deltas(frames) if align_to_first else [(0, 0)] * len(frames)
    bb0 = frame_bbox(frames[0], 20)
    assert bb0 is not None
    if align_to_first:
        ba0 = find_stable_base_anchor(frames[0])
        ref_cx, ref_by = ba0[4], ba0[5]
    else:
        max_w = max(frame_bbox(f, 20)[2] - frame_bbox(f, 20)[0] for f in frames)
        max_h = max(frame_bbox(f, 20)[3] - frame_bbox(f, 20)[1] for f in frames)
        ref_cx = 0.5 * (bb0[0] + bb0[2])
        ref_by = float(bb0[3])

    max_rel_w = max(frame_bbox(f, 20)[2] - frame_bbox(f, 20)[0] for f in frames)
    max_rel_h = max(frame_bbox(f, 20)[3] - frame_bbox(f, 20)[1] for f in frames)
    scale = min((cell_w - 10) / float(max_rel_w), (cell_h - 10) / float(max_rel_h))

    strip = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    foot_y = cell_h - max(6, int(round(cell_h * 0.08)))
    for fi, (f, (dx, dy)) in enumerate(zip(frames, deltas)):
        bb = frame_bbox(f, 15)
        if bb is None:
            continue
        fx0, fy0, fx1, fy1 = bb
        trimmed = Image.fromarray(f[fy0:fy1, fx0:fx1])
        nw = max(1, int(round((fx1 - fx0) * scale)))
        nh = max(1, int(round((fy1 - fy0) * scale)))
        resized = trimmed.resize((nw, nh), Image.Resampling.NEAREST)
        if align_to_first:
            px = int(round(cell_w * 0.5 + ((fx0 - dx) - ref_cx) * scale))
            py = int(round(foot_y + ((fy0 - dy) - ref_by) * scale))
        elif anchor == "bottom":
            px = int(round(cell_w * 0.5 - nw * 0.5))
            py = int(round(foot_y - nh))
        else:
            px = int(round(cell_w * 0.5 - nw * 0.5))
            py = int(round(cell_h * 0.5 - nh * 0.5))
        px = max(2, min(cell_w - nw - 2, px))
        py = max(2, min(cell_h - nh - 2, py))
        strip.paste(resized, (fi * cell_w + px, py), resized)
    strip.save(out_path)


def build_portraits(raw_dir: Path, out_dir: Path):
    arr = load_rgb(raw_dir, "17_tower_portraits.png")
    keyed = chroma_key(arr, "green")
    # Merge small spark gaps near portrait frames by dilating alpha slightly before CC
    comps = connected_components_8(dilate(keyed[:, :, 3] > 30, 2))
    big = [c for c in comps if c["area"] > 8000]
    assert len(big) == 8, f"Expected 8 portrait boxes, got {len(big)}"
    # Sort top 4 then bottom 4, each sorted left-to-right
    big.sort(key=lambda c: c["bbox"][1])
    top4 = sorted(big[:4], key=lambda c: c["bbox"][0])
    bot4 = sorted(big[4:], key=lambda c: c["bbox"][0])
    ordered = top4 + bot4
    names = ["archer", "mage", "cannon", "barracks", "storm", "lens", "snare", "build"]
    for name, c in zip(names, ordered):
        x0, y0, x1, y1 = c["bbox"]
        sub = keyed[y0:y1, x0:x1]
        bb = frame_bbox(sub, 30)
        assert bb is not None
        crop = Image.fromarray(sub[bb[1]:bb[3], bb[0]:bb[2]])
        crop.resize((128, 128), Image.Resampling.NEAREST).save(out_dir / f"portrait_{name}.png")


def build_plinths(raw_dir: Path, out_dir: Path):
    arr = load_rgb(raw_dir, "18_site_plinths.png")
    keyed = chroma_key(arr, "magenta")
    comps = connected_components_8(dilate(keyed[:, :, 3] > 25, 3))
    big = sorted([c for c in comps if c["area"] > 5000], key=lambda c: c["bbox"][0])
    assert len(big) == 5, f"Expected 5 plinths, got {len(big)}"
    names = ["normal", "highground", "choke", "conduit", "locked"]

    # Unified height scaling so all 5 plinths occupy consistent ground footprint (approx 168x104 inside 192x128)
    widths = [c["bbox"][2] - c["bbox"][0] for c in big]
    heights = [c["bbox"][3] - c["bbox"][1] for c in big]
    scale = min(176.0 / max(widths), 116.0 / max(heights))
    for name, c in zip(names, big):
        x0, y0, x1, y1 = c["bbox"]
        sub = keyed[y0:y1, x0:x1]
        bb = frame_bbox(sub, 20)
        crop = Image.fromarray(sub[bb[1]:bb[3], bb[0]:bb[2]])
        nw = max(1, int(round(crop.width * scale)))
        nh = max(1, int(round(crop.height * scale)))
        resized = crop.resize((nw, nh), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
        canvas.paste(resized, ((192 - nw) // 2, (128 - nh) // 2), resized)
        canvas.save(out_dir / f"plinth_{name}.png")


def make_checker_bg(w: int, h: int) -> Image.Image:
    bg = Image.new("RGBA", (w, h), (38, 42, 52, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, h, 16):
        for x in range(0, w, 16):
            if ((x // 16) + (y // 16)) % 2 == 0:
                d.rectangle([x, y, x + 15, y + 15], fill=(50, 55, 68, 255))
    return bg


def _build_portrait_bezel_template(out_dir: Path):
    """Extract the clean 128x128 octagonal gold riveted bezel & interior mask from portrait_cannon.png."""
    donor = Image.open(out_dir / "portrait_cannon.png").convert("RGBA")
    arr = np.array(donor)
    yy, xx = np.mgrid[0:128, 0:128]
    d_diag = np.minimum(
        np.minimum(xx + yy, (127 - xx) + yy),
        np.minimum(xx + (127 - yy), (127 - xx) + (127 - yy)),
    )
    bezel = (xx <= 8) | (xx >= 119) | (yy <= 8) | (yy >= 119) | (d_diag < 28)
    inner = ~bezel
    template = np.zeros_like(arr)
    template[bezel] = arr[bezel]
    seam = (
        (((xx == 8) | (xx == 119)) & (yy >= 8) & (yy <= 119) & (d_diag >= 28))
        | (((yy == 8) | (yy == 119)) & (xx >= 8) & (xx <= 119) & (d_diag >= 28))
        | ((d_diag == 28) & (xx >= 8) & (xx <= 119) & (yy >= 8) & (yy <= 119))
    )
    template[seam] = [12, 10, 12, 255]
    return Image.fromarray(template), inner


def build_v026_tower_portraits(out_dir: Path):
    """Regenerate portrait_storm/lens/snare from their new Lv2 idle sprites inside the gold bezel."""
    bezel_img, inner_mask = _build_portrait_bezel_template(out_dir)
    specs = {
        "storm": {
            "top": (20, 34, 58),
            "bot": (10, 18, 32),
            "glow": (62, 195, 255),
            "pad_w": 96,
            "pad_h": 98,
            "y_bias": 2,
        },
        "lens": {
            "top": (42, 34, 24),
            "bot": (18, 15, 13),
            "glow": (255, 205, 92),
            "pad_w": 96,
            "pad_h": 98,
            "y_bias": 1,
        },
        "snare": {
            "top": (26, 38, 25),
            "bot": (13, 20, 14),
            "glow": (235, 178, 86),
            "pad_w": 100,
            "pad_h": 94,
            "y_bias": 4,
        },
    }
    yy, xx = np.mgrid[0:128, 0:128]
    u = np.clip((yy - 9.0) / 109.0, 0.0, 1.0)
    dist = np.sqrt(((xx - 63.5) / 48.0) ** 2 + ((yy - 58.0) / 48.0) ** 2)
    radial = np.clip(1.0 - dist, 0.0, 1.0) ** 1.7

    for kind, cfg in specs.items():
        sheet = Image.open(out_dir / f"tower_{kind}_lv2.png").convert("RGBA")
        idle = sheet.crop((0, 0, TOWER_CELL, TOWER_CELL))
        idle_arr = np.array(idle)
        bb = frame_bbox(idle_arr, 20)
        assert bb is not None, f"Empty Lv2 idle frame for {kind}"
        cropped = idle.crop(bb)
        scale = min(cfg["pad_w"] / float(cropped.width), cfg["pad_h"] / float(cropped.height))
        nw = max(1, int(round(cropped.width * scale)))
        nh = max(1, int(round(cropped.height * scale)))
        sprite = cropped.resize((nw, nh), Image.Resampling.NEAREST)

        top_c = np.array(cfg["top"], dtype=np.float32)
        bot_c = np.array(cfg["bot"], dtype=np.float32)
        glow_c = np.array(cfg["glow"], dtype=np.float32)
        bg = top_c[None, None, :] * (1.0 - u[:, :, None]) + bot_c[None, None, :] * u[:, :, None]
        bg += glow_c[None, None, :] * (radial[:, :, None] * 0.36)
        canvas = np.zeros((128, 128, 4), dtype=np.uint8)
        canvas[:, :, :3] = np.clip(np.round(bg), 0, 255).astype(np.uint8)
        canvas[:, :, 3] = np.where(inner_mask, 255, 0).astype(np.uint8)

        card = Image.fromarray(canvas)
        px = (128 - nw) // 2
        py = 117 - nh + cfg["y_bias"]
        py = max(11, min(118 - nh, py))
        card.paste(sprite, (px, py), sprite)
        card.paste(bezel_img, (0, 0), bezel_img)
        card.save(out_dir / f"portrait_{kind}.png")


def build_exit_pillar_strip(out_dir: Path):
    """Paint a crisp 16-bit 3-frame pixel strip (288x144) for the endpoint Twin Watch Rune Pillars."""
    gw, gh = 48, 72
    frames = []
    outline = (20, 17, 27, 255)
    stone_d = (50, 54, 68, 255)
    stone_m = (86, 92, 110, 255)
    stone_l = (138, 145, 166, 255)
    stone_h = (176, 184, 202, 255)
    moss_d = (62, 102, 50, 255)
    moss_l = (112, 164, 72, 255)
    bronze_d = (108, 70, 34, 255)
    bronze_m = (182, 124, 52, 255)
    bronze_h = (242, 198, 102, 255)

    for state in range(3):
        # state 0=ready (cyan-gold rune glow), 1=teleport burst (bright surge), 2=cooldown dormant (slate)
        img = Image.new("RGBA", (gw, gh), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        def p(x: int, y: int, c):
            if 0 <= x < gw and 0 <= y < gh:
                img.putpixel((x, y), c)

        def hline(x0: int, x1: int, y: int, c):
            for xi in range(x0, x1 + 1):
                p(xi, y, c)

        # 1. Stepped mossy stone plinth (y = 56..68)
        d.rectangle([10, 62, 37, 68], fill=stone_m)
        hline(10, 37, 62, stone_l)
        hline(11, 22, 62, stone_h)
        d.rectangle([10, 66, 37, 68], fill=stone_d)
        for sx in (15, 22, 30):
            for sy in range(63, 68):
                p(sx, sy, stone_d)
        # Upper step plinth
        d.rectangle([13, 56, 34, 62], fill=stone_m)
        hline(13, 34, 56, stone_l)
        hline(14, 23, 56, stone_h)
        d.rectangle([28, 57, 34, 62], fill=stone_d)
        # Moss clusters tucked into left & right step corners
        for mx, my in [(11, 61), (12, 61), (11, 62), (12, 62), (13, 61), (34, 62), (35, 62), (35, 63), (12, 67), (13, 67)]:
            p(mx, my, moss_d)
        for mx, my in [(11, 60), (12, 60), (14, 60), (35, 61)]:
            p(mx, my, moss_l)

        # 2. Tapered sculpted obelisk column shaft (y = 26..56)
        for y in range(26, 56):
            inset = 0 if y >= 46 else (1 if y >= 35 else 2)
            x0 = 16 + inset
            x1 = 31 - inset
            hline(x0, x1, y, stone_m)
            p(x0, y, stone_l)
            p(x0 + 1, y, stone_h if y % 6 < 4 else stone_l)
            p(x1, y, stone_d)
            p(x1 - 1, y, stone_d)
            if y in (36, 46):
                hline(x0 + 1, x1 - 1, y, stone_d)
                hline(x0 + 1, x1 - 1, y + 1, stone_l)

        # 3. Riveted bronze structural collars (y=53..55 and y=29..31 and crown y=23..26)
        for cy in (29, 53):
            inset = 1 if cy == 29 else 0
            x0, x1 = 15 + inset, 32 - inset
            hline(x0, x1, cy, bronze_h)
            hline(x0, x1, cy + 1, bronze_m)
            hline(x0, x1, cy + 2, bronze_d)
            for rx in (x0 + 2, 23, x1 - 2):
                p(rx, cy + 1, outline)

        # Crown pedestal + left/right claw prongs cradling crystal
        d.rectangle([16, 23, 31, 26], fill=bronze_m)
        hline(16, 31, 23, bronze_h)
        hline(17, 30, 26, bronze_d)
        for side_x in (15, 32):
            for py in range(15, 24):
                p(side_x, py, bronze_h if side_x < 24 else bronze_m)
                p(side_x + (1 if side_x < 24 else -1), py, bronze_d)
        p(16, 14, bronze_h); p(31, 14, bronze_m)

        # 4. Recessed vertical rune conduit groove & rune glyphs on shaft (x = 22..25, y = 27..52)
        if state == 2:
            rune_dark = (34, 38, 50, 255)
            rune_lit = (72, 82, 102, 255)
            gem_c1, gem_c2, gem_hi = (66, 74, 92, 255), (96, 108, 128, 255), (144, 158, 178, 255)
        elif state == 1:
            rune_dark = (40, 156, 210, 255)
            rune_lit = (220, 255, 255, 255)
            gem_c1, gem_c2, gem_hi = (78, 224, 255, 255), (195, 255, 255, 255), (255, 252, 214, 255)
        else:
            rune_dark = (32, 92, 128, 255)
            rune_lit = (106, 242, 255, 255)
            gem_c1, gem_c2, gem_hi = (42, 168, 214, 255), (120, 244, 255, 255), (255, 244, 184, 255)

        for y in range(27, 52):
            p(22, y, stone_d)
            p(25, y, stone_d)
            is_node = y in (33, 34, 39, 40, 44, 45, 49, 50)
            c = rune_lit if is_node else rune_dark
            p(23, y, c)
            p(24, y, c)
            if state == 1 and y in (33, 40, 49):
                p(21, y, rune_lit); p(26, y, rune_lit)

        # 5. Faceted diamond crystal hovering between prongs (center x=23.5, y=6..20)
        for y in range(6, 21):
            half_w = (y - 6) * 0.68 if y <= 13 else (20 - y) * 0.68
            hw = int(round(half_w))
            for x in range(23 - hw, 25 + hw):
                if x < 23:
                    col = gem_hi if (state != 2 and y in range(9, 14) and x >= 21) else gem_c2
                else:
                    col = gem_c1
                p(x, y, col)
        p(23, 11, gem_hi); p(24, 12, gem_hi); p(22, 11, gem_hi)

        # Apply crisp 1px dark contour outline around all solid pixels before energy sparks
        src = np.array(img)
        opaque = src[:, :, 3] > 200
        ring = dilate(opaque, 1) & (~opaque)
        src[ring] = outline
        img = Image.fromarray(src)

        # Add exterior pixel sparks outside outline for Ready (state 0) & Burst (state 1)
        if state == 0:
            for sx, sy, sc in [(18, 9, (140, 248, 255, 220)), (29, 8, (255, 244, 184, 220)), (23, 3, (120, 240, 255, 210))]:
                img.putpixel((sx, sy), sc)
        elif state == 1:
            surge_c = (150, 248, 255, 240)
            core_w = (255, 255, 232, 255)
            for ray_pt in [(14, 11), (13, 10), (33, 11), (34, 10), (17, 5), (30, 5), (23, 2), (24, 2), (23, 1), (11, 59), (36, 59)]:
                img.putpixel(ray_pt, surge_c)
            for c_pt in [(23, 12), (24, 12), (23, 13), (24, 13), (23, 3), (24, 3)]:
                img.putpixel(c_pt, core_w)

        upscaled = img.resize((gw * 2, gh * 2), Image.Resampling.NEAREST)
        frames.append(upscaled)

    strip = Image.new("RGBA", (gw * 2 * 3, gh * 2), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * gw * 2, 0), fr)
    strip.save(out_dir / "prop_exit_pillar.png")


def build_all(raw_dir: Path, out_dir: Path, qa_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    qa_dir.mkdir(parents=True, exist_ok=True)

    # Target IDLE heights inside 256x256 sheet (balanced around ~192..216px)
    # Godot battle world heights are scaled independently via manifest / contact()
    tower_specs = [
        ("01_archer_base.jpg", "magenta", [("archer", "lv1", 198), ("archer", "lv2", 210)],
         {}),
        ("02_archer_l3.png", "magenta", [("archer", "sentinel", 216), ("archer", "repeater", 198), ("archer", "piercer", 204)],
         {(-1, 2): "archer_l3_fire", (-1, 3): "archer_l3_recover"}),
        ("03_mage_base.png", "green", [("mage", "lv1", 196), ("mage", "lv2", 210)],
         {}),
        ("04_mage_l3.png", "green", [("mage", "frost", 208), ("mage", "arcfire", 208), ("mage", "breaker", 208)],
         {}),
        ("05_cannon_base.png", "green", [("cannon", "lv1", 184), ("cannon", "lv2", 198)],
         {}),
        ("06_cannon_l3.png", "green", [("cannon", "siege", 206), ("cannon", "burning", 202), ("cannon", "frag", 202)],
         {}),
        ("07_barracks_base.jpg", "green", [("barracks", "lv1", 186), ("barracks", "lv2", 202)],
         {}),
        ("08_barracks_l3.png", "green", [("barracks", "shield", 208), ("barracks", "hunter", 200), ("barracks", "charge", 204)],
         {(-1, 1): "no_floating_above"}),
        ("09_storm_base.jpg", "green", [("storm", "lv1", 198), ("storm", "lv2", 206)],
         {}),
        ("10_storm_l3.jpg", "green", [("storm", "fork", 202), ("storm", "relay", 214), ("storm", "surge", 196)],
         {}),
        ("11_lens_base.jpg", "green", [("lens", "lv1", 198), ("lens", "lv2", 210)],
         {}),
        ("12_lens_l3.jpg", "green", [("lens", "focus", 210), ("lens", "sweep", 210), ("lens", "far_lens", 204)],
         {}),
        ("13_snare_base.jpg", "magenta", [("snare", "lv1", 184), ("snare", "lv2", 198)],
         {}),
        ("14_snare_l3.jpg", "magenta", [("snare", "net", 194), ("snare", "barb", 190), ("snare", "ratchet", 198)],
         {}),
    ]

    # World display heights in Godot arena px (tuned cleanly to sit snugly inside 108x72 plinths & harmonize with 65px heroes)
    WORLD_HEIGHTS = {
        "archer_lv1": 100.0, "archer_lv2": 114.0, "archer_sentinel": 126.0, "archer_repeater": 108.0, "archer_piercer": 112.0,
        "mage_lv1": 96.0, "mage_lv2": 108.0, "mage_frost": 118.0, "mage_arcfire": 116.0, "mage_breaker": 118.0,
        "cannon_lv1": 88.0, "cannon_lv2": 98.0, "cannon_siege": 108.0, "cannon_burning": 106.0, "cannon_frag": 106.0,
        "barracks_lv1": 92.0, "barracks_lv2": 104.0, "barracks_shield": 112.0, "barracks_hunter": 104.0, "barracks_charge": 108.0,
        "storm_lv1": 104.0, "storm_lv2": 96.0, "storm_fork": 98.0, "storm_relay": 122.0, "storm_surge": 88.0,
        "lens_lv1": 102.0, "lens_lv2": 106.0, "lens_focus": 108.0, "lens_sweep": 114.0, "lens_far_lens": 96.0,
        "snare_lv1": 76.0, "snare_lv2": 86.0, "snare_net": 82.0, "snare_barb": 80.0, "snare_ratchet": 88.0,
    }
    FLIPPABLE_KINDS = {"archer", "cannon", "lens"}

    manifest = {"cell_size": TOWER_CELL, "foot_frac": TOWER_FOOT_Y / float(TOWER_CELL), "towers": {}}
    qa_entries = []

    for fname, mode, row_defs, rules in tower_specs:
        rows = extract_sheet_rows(raw_dir, fname, len(row_defs), TOWER_COLS, mode, rules)
        for ri, (kind, form, target_idle) in enumerate(row_defs):
            key = f"{kind}_{form}"
            out_file = out_dir / f"tower_{key}.png"
            info = build_tower_strip(out_file, rows[ri], float(target_idle))
            # World display scale factor for Godot contact() = world_height / idle_h_px
            info["world_height"] = WORLD_HEIGHTS[key]
            info["flippable"] = (kind in FLIPPABLE_KINDS)
            if kind == "archer":
                info["muzzle_uv"] = [0.64, 0.38 if form in ("lv1", "lv2", "sentinel") else 0.42]
            elif kind == "cannon":
                info["muzzle_uv"] = [0.68, 0.30]
            elif kind == "barracks":
                info["muzzle_uv"] = [0.50, 0.74]
            elif kind == "snare":
                info["muzzle_uv"] = [0.54, 0.56]
            elif kind == "storm":
                storm_uvs = {
                    "lv1": [0.50, 0.22],
                    "lv2": [0.50, 0.22],
                    "fork": [0.50, 0.24],
                    "relay": [0.50, 0.16],
                    "surge": [0.50, 0.44],
                }
                info["muzzle_uv"] = storm_uvs.get(form, [0.50, 0.24])
            elif kind == "mage":
                info["muzzle_uv"] = [0.50, 0.28]
            elif kind == "lens":
                lens_uvs = {
                    "lv1": [0.60, 0.28],
                    "lv2": [0.63, 0.30],
                    "focus": [0.62, 0.30],
                    "sweep": [0.52, 0.34],
                    "far_lens": [0.76, 0.28],
                }
                info["muzzle_uv"] = lens_uvs.get(form, [0.62, 0.30])
            manifest["towers"][key] = info
            qa_entries.append((key, out_file))
            print(f"Built {out_file.name}: world_h={info['world_height']} muzzle={info['muzzle_uv']}")

    # Soldiers (Sheet 15)
    soldier_rows = extract_sheet_rows(
        raw_dir, "15_barracks_soldiers.png", 4, SOLDIER_COLS, "green",
        {(-1, 4): "soldier_hurt"}
    )
    soldier_ids = ["base", "shield", "hunter", "charge"]
    for ri, sid in enumerate(soldier_ids):
        out_s = out_dir / f"creature_soldier_{sid}.png"
        build_soldier_sheet(out_s, soldier_rows[ri], target_h=120.0 if sid == "shield" else 112.0)
        print(f"Built {out_s.name}")

    # Props (Sheet 16)
    prop_rows = extract_sheet_rows(
        raw_dir, "16_tower_props.png", 4, 4, "magenta",
        {(0, 1): "prop_above_clean", (0, 2): "prop_above_clean", (3, 1): "prop_above_clean"}
    )
    build_prop_strip(out_dir / "prop_snare_net.png", prop_rows[0], 128, 96, anchor="center", align_to_first=False)
    build_prop_strip(out_dir / "prop_snare_barb.png", prop_rows[1][:2], 128, 96, anchor="center", align_to_first=False)
    build_prop_strip(out_dir / "prop_snare_ratchet.png", prop_rows[1][2:], 128, 96, anchor="center", align_to_first=False)
    build_prop_strip(out_dir / "prop_flag_std.png", prop_rows[2][:2], 96, 96, anchor="bottom", align_to_first=True)
    build_prop_strip(out_dir / "prop_flag_elite.png", prop_rows[2][2:], 96, 96, anchor="bottom", align_to_first=True)
    build_prop_strip(out_dir / "prop_scaffold.png", prop_rows[3][:2], 192, 160, anchor="bottom", align_to_first=True)
    # Use only sharp frame 3 of reticle (frame 4 had magenta feathering)
    build_prop_strip(out_dir / "prop_reticle.png", [prop_rows[3][2]], 128, 96, anchor="center", align_to_first=False)
    print("Built all 7 tower prop strips")

    build_portraits(raw_dir, out_dir)
    build_v026_tower_portraits(out_dir)
    build_exit_pillar_strip(out_dir)
    print("Built all 8 gold-framed portraits + v0.26 portraits & exit pillar strip")

    build_plinths(raw_dir, out_dir)
    print("Built all 5 pixel plinths")

    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    # Visual QA Contact Sheet 1: all 35 towers (IDLE vs FIRE side-by-side in 7 columns x 5 rows)
    cell_q = 128
    # 5 forms per tower x 7 towers => arrange as 7 towers x (5 rows) with [IDLE, FIRE] side-by-side per form
    # Better: 7 blocks stacked vertically? Wait: 35 forms, 4 frames each = 35 rows of 4 frames is very tall (4480px).
    # Instead make 7 rows (one per tower kind), columns = 5 forms x 2 frames (IDLE+FIRE) -> wait 10*112 = 1120px wide, 7*112 = 784px tall!
    # Also draw red dot at muzzle_uv on FIRE frame and faint cyan baseline at FOOT_FRAC!
    th_w, th_h = 112, 112
    qa1 = make_checker_bg(10 * th_w, 7 * th_h)
    d1 = ImageDraw.Draw(qa1)
    kinds_order = ["archer", "mage", "cannon", "barracks", "storm", "lens", "snare"]
    by_kind = {k: [] for k in kinds_order}
    for key, p in qa_entries:
        k = key.split("_")[0]
        by_kind[k].append((key, p))

    for rk, k in enumerate(kinds_order):
        for fi, (key, p) in enumerate(by_kind[k]):
            sheet = Image.open(p)
            muv = manifest["towers"][key]["muzzle_uv"]
            for idx_pair, src_col in enumerate([0, 2]):  # IDLE and FIRE
                sub = sheet.crop((src_col * TOWER_CELL, 0, (src_col + 1) * TOWER_CELL, TOWER_CELL))
                thumb = sub.resize((th_w, th_h), Image.Resampling.NEAREST)
                gx = (fi * 2 + idx_pair) * th_w
                gy = rk * th_h
                qa1.paste(thumb, (gx, gy), thumb)
                foot_py = gy + int(round(th_h * TOWER_FOOT_Y / float(TOWER_CELL)))
                d1.line([gx, foot_py, gx + th_w - 1, foot_py], fill=(0, 220, 255, 160), width=1)
                if idx_pair == 1:
                    mx = gx + int(round(muv[0] * th_w))
                    my = gy + int(round(muv[1] * th_h))
                    d1.ellipse([mx - 3, my - 3, mx + 3, my + 3], fill=(255, 60, 60, 255))
            d1.text((fi * 2 * th_w + 3, rk * th_h + 2), key, fill=(255, 235, 120, 255))
    qa1.save(qa_dir / "v024_slice_qa_towers.png")

    # Visual QA Contact Sheet 2: soldiers + props + portraits + plinths
    qa2 = make_checker_bg(960, 760)
    d2 = ImageDraw.Draw(qa2)
    # 4 soldiers (each 6 cols across row: walk0, walk1, windup, strike, hurt, down)
    for ri, sid in enumerate(soldier_ids):
        sim = Image.open(out_dir / f"creature_soldier_{sid}.png")
        picks = [(0, 0), (0, 3), (1, 1), (1, 3), (2, 0), (2, 3)]
        for ci, (sr, sc) in enumerate(picks):
            sub = sim.crop((sc * SOLDIER_CELL, sr * SOLDIER_CELL, (sc + 1) * SOLDIER_CELL, (sr + 1) * SOLDIER_CELL))
            qa2.paste(sub.resize((96, 96), Image.Resampling.NEAREST), (ci * 96, ri * 96), sub.resize((96, 96), Image.Resampling.NEAREST))
        d2.text((4, ri * 96 + 2), f"soldier_{sid}", fill=(255, 240, 120, 255))

    # Right column on top: 8 portraits (2 cols x 4 rows)
    p_names = ["archer", "mage", "cannon", "barracks", "storm", "lens", "snare", "build"]
    for pi, pn in enumerate(p_names):
        pim = Image.open(out_dir / f"portrait_{pn}.png").resize((92, 92), Image.Resampling.NEAREST)
        px = 600 + (pi % 4) * 90
        py = (pi // 4) * 94 + 4
        qa2.paste(pim, (px, py), pim)

    # Middle right: props
    y_prop = 210
    for pname, cols in [("snare_net", 4), ("snare_barb", 2), ("snare_ratchet", 2), ("flag_std", 2), ("flag_elite", 2), ("scaffold", 2), ("reticle", 1)]:
        pim = Image.open(out_dir / f"prop_{pname}.png")
        scale_p = min(1.0, 180.0 / pim.height if pim.height > 80 else 1.0)
        # crop/scale nicely to fit width 340
        pw = min(340, pim.width // 2 if pim.width > 400 else pim.width)
        ph = int(round(pim.height * (pw / float(pim.width))))
        if y_prop + ph < 540:
            res = pim.resize((pw, ph), Image.Resampling.NEAREST)
            qa2.paste(res, (595, y_prop), res)
            d2.text((595, y_prop), pname, fill=(255, 230, 140, 255))
            y_prop += ph + 6

    # Bottom: 5 plinths + full net + scaffold
    for pli, pln in enumerate(["normal", "highground", "choke", "conduit", "locked"]):
        plim = Image.open(out_dir / f"plinth_{pln}.png").resize((160, 106), Image.Resampling.NEAREST)
        qa2.paste(plim, (16 + pli * 188, 560), plim)
        d2.text((20 + pli * 188, 550), pln, fill=(255, 235, 130, 255))

    scaf = Image.open(out_dir / "prop_scaffold.png")
    qa2.paste(scaf.resize((220, 92), Image.Resampling.NEAREST), (16, 668), scaf.resize((220, 92), Image.Resampling.NEAREST))
    net = Image.open(out_dir / "prop_snare_net.png")
    qa2.paste(net.resize((320, 60), Image.Resampling.NEAREST), (260, 682), net.resize((320, 60), Image.Resampling.NEAREST))
    fstd = Image.open(out_dir / "prop_flag_std.png")
    qa2.paste(fstd.resize((160, 80), Image.Resampling.NEAREST), (600, 672), fstd.resize((160, 80), Image.Resampling.NEAREST))
    felt = Image.open(out_dir / "prop_flag_elite.png")
    qa2.paste(felt.resize((160, 80), Image.Resampling.NEAREST), (770, 672), felt.resize((160, 80), Image.Resampling.NEAREST))
    ret = Image.open(out_dir / "prop_reticle.png")
    qa2.paste(ret.resize((88, 66), Image.Resampling.NEAREST), (850, 480), ret.resize((88, 66), Image.Resampling.NEAREST))

    qa2.save(qa_dir / "v024_slice_qa_extras.png")
    print(f"QA sheets saved under {qa_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build v0.24 pixel art tower sheets, soldiers, props, portraits and plinths.")
    parser.add_argument("--raw-dir", type=Path, default=PROJECT.parent / "美术参考/v024_final_raw")
    parser.add_argument("--out-dir", type=Path, default=PROJECT / "assets/towers_v024")
    parser.add_argument("--qa-dir", type=Path, default=PROJECT / "test-results")
    parser.add_argument("--v026-only", action="store_true", help="Only regenerate v0.26 portraits and endpoint exit pillar strip.")
    args = parser.parse_args()
    if args.v026_only:
        out_resolved = args.out_dir.resolve()
        build_v026_tower_portraits(out_resolved)
        build_exit_pillar_strip(out_resolved)
        print("Built v0.26 portraits (storm/lens/snare) & prop_exit_pillar.png")
    else:
        build_all(args.raw_dir.resolve(strict=True), args.out_dir.resolve(), args.qa_dir.resolve())
