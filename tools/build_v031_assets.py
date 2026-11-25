"""Build v0.31 pixel dungeon, props, badges, and VFX sprite sheets from raw uploads."""

from __future__ import annotations
from collections import deque
import os
import shutil
import numpy as np
from PIL import Image

UPLOAD_DIR = r"C:/Users/黄子衿/.gemini/antigravity/brain/576a2758-9e88-4f27-8e7a-860481c4c0c1/.user_uploaded"
RAW_ARCHIVE_DIR = r"d:/godot/美术参考/v031_raw"
OUT_RIFT = r"d:/godot/边境守望/assets/rift_v031"
OUT_VFX = r"d:/godot/边境守望/assets/vfx_v031"
OUT_UI = r"d:/godot/边境守望/assets/ui_v030"

SOURCES = {
    "01_room_abyss.jpg": "media_1795528301050_18de849c.jpg",
    "02_room_wilds.jpg": "media_1795528306879_0dc64e76.jpg",
    "03_room_void.jpg": "media_1795528400082_dd53d33e.jpg",
    "04_room_hub.jpg": "media_1795529022825_97d58764.jpg",
    "05_room_boss.jpg": "media_1795529126776_c865d098.jpg",
    "06_corridor_and_props.jpg": "media_1795529248936_b1b6684b.jpg",
    "07_three_passive_medals.jpg": "media_1795529327278_3a395ddc.jpg",
    "08_vfx_portal_and_blades.jpg": "media_1795529476235_f853e256.jpg",
    "09_vfx_meteor_and_frost.jpg": "media_1795529662261_2d6f9c32.jpg",
    "10_vfx_blackhole_and_beam.jpg": "media_1795529746632_8b7e7003.jpg",
}


def ensure_dirs() -> None:
    os.makedirs(RAW_ARCHIVE_DIR, exist_ok=True)
    os.makedirs(OUT_RIFT, exist_ok=True)
    os.makedirs(OUT_VFX, exist_ok=True)
    os.makedirs(OUT_UI, exist_ok=True)
    for dst_name, src_name in SOURCES.items():
        src = os.path.join(UPLOAD_DIR, src_name)
        dst = os.path.join(RAW_ARCHIVE_DIR, dst_name)
        if os.path.exists(src):
            shutil.copy2(src, dst)


def is_magenta_bg(arr: np.ndarray, tol: float = 95.0) -> np.ndarray:
    r = arr[..., 0].astype(np.float32)
    g = arr[..., 1].astype(np.float32)
    b = arr[..., 2].astype(np.float32)
    # Bright magenta/pink background detector (high R & B, low G)
    dist = np.sqrt((255.0 - r) ** 2 + g ** 2 + (255.0 - b) ** 2)
    return (dist < tol) | ((r > 175.0) & (b > 175.0) & (g < 95.0) & (np.abs(r - b) < 75.0))


def flood_exterior(mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if mask[0, x]:
            visited[0, x] = True
            q.append((0, x))
        if mask[h - 1, x] and not visited[h - 1, x]:
            visited[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if mask[y, 0] and not visited[y, 0]:
            visited[y, 0] = True
            q.append((y, 0))
        if mask[y, w - 1] and not visited[y, w - 1]:
            visited[y, w - 1] = True
            q.append((y, w - 1))
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and mask[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))
    return visited


def key_magenta_rgba(img: Image.Image, protect_interior: bool = True, clean_pure_holes: bool = False) -> Image.Image:
    arr = np.array(img.convert("RGB"))
    bg_cand = is_magenta_bg(arr, tol=108.0)
    bg = flood_exterior(bg_cand) if protect_interior else bg_cand
    if clean_pure_holes:
        r0 = arr[..., 0].astype(np.float32)
        g0 = arr[..., 1].astype(np.float32)
        b0 = arr[..., 2].astype(np.float32)
        pure_mag = (r0 > 205.0) & (b0 > 195.0) & (g0 < 55.0) & (np.abs(r0 - b0) < 50.0)
        bg = bg | pure_mag
    alpha = np.where(bg, 0, 255).astype(np.uint8)

    # Anti-aliased halo suppression on 1-2px fringe touching exterior bg
    h, w = bg.shape
    fringe = np.zeros((h, w), dtype=bool)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        shifted = np.roll(np.roll(bg, dy, axis=0), dx, axis=1)
        fringe |= (~bg) & shifted

    rgba = np.dstack([arr, alpha]).astype(np.float32)
    r, g, b = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    # Where fringe still carries strong magenta spill, attenuate alpha & despill magenta
    m_strength = np.clip((np.minimum(r, b) - g) / 140.0, 0.0, 1.0)
    fringe_spill = fringe & (m_strength > 0.25)
    rgba[..., 3] = np.where(fringe_spill, np.clip(255.0 * (1.0 - m_strength * 0.72), 40.0, 255.0), rgba[..., 3])
    rgba[..., 0] = np.where(fringe_spill, np.minimum(r, g + 85.0), r)
    rgba[..., 2] = np.where(fringe_spill, np.minimum(b, g + 85.0), b)
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def find_x_spans(alpha_or_luma: np.ndarray, min_val: float = 12.0, min_width: int = 8) -> list[tuple[int, int]]:
    col_max = alpha_or_luma.max(axis=0)
    active = col_max > min_val
    spans = []
    start = None
    for x, flag in enumerate(active):
        if flag and start is None:
            start = x
        elif not flag and start is not None:
            if x - start >= min_width:
                spans.append((start, x))
            start = None
    if start is not None and len(active) - start >= min_width:
        spans.append((start, len(active)))
    # Merge tiny internal gaps <= 14px
    merged: list[tuple[int, int]] = []
    for s, e in spans:
        if merged and s - merged[-1][1] <= 14:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    return merged


def trim_and_place(crop: Image.Image, target_w: int, target_h: int, margin: int = 6, align_bottom: int | None = None) -> Image.Image:
    bbox = crop.getbbox()
    if bbox is None:
        return Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    piece = crop.crop(bbox)
    pw, ph = piece.size
    avail_w = target_w - margin * 2
    avail_h = target_h - margin * 2
    scale = min(avail_w / max(1, pw), avail_h / max(1, ph))
    nw = max(1, int(round(pw * scale)))
    nh = max(1, int(round(ph * scale)))
    resized = piece.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    dx = (target_w - nw) // 2
    dy = (align_bottom - nh) if align_bottom is not None else ((target_h - nh) // 2)
    dy = max(0, min(target_h - nh, dy))
    canvas.paste(resized, (dx, dy), resized)
    return canvas


def process_rooms() -> None:
    room_map = {
        "01_room_abyss.jpg": "room_abyss_arena.png",
        "02_room_wilds.jpg": "room_wilds_arena.png",
        "03_room_void.jpg": "room_void_arena.png",
        "04_room_hub.jpg": "room_hub_sanctuary.png",
        "05_room_boss.jpg": "room_boss_sanctum.png",
    }
    for src_name, dst_name in room_map.items():
        img = Image.open(os.path.join(RAW_ARCHIVE_DIR, src_name)).convert("RGBA")
        out = img.resize((920, 580), Image.Resampling.LANCZOS)
        out.save(os.path.join(OUT_RIFT, dst_name))


def process_corridor_and_props() -> None:
    img = Image.open(os.path.join(RAW_ARCHIVE_DIR, "06_corridor_and_props.jpg")).convert("RGB")
    w, h = img.size
    top_strip = key_magenta_rgba(img.crop((0, 0, w, int(h * 0.44))), protect_interior=True)
    bbox = top_strip.getbbox()
    if bbox:
        corr = top_strip.crop(bbox).resize((512, 168), Image.Resampling.LANCZOS)
        corr.save(os.path.join(OUT_RIFT, "corridor_tiles.png"))

    bot_row = key_magenta_rgba(img.crop((0, int(h * 0.44), w, h)), protect_interior=True, clean_pure_holes=True)
    alpha = np.array(bot_row)[..., 3]
    spans = find_x_spans(alpha, min_val=15.0, min_width=24)
    print("Props x spans:", spans)
    prop_names = ["prop_chest_closed.png", "prop_chest_open.png", "prop_shrine.png", "prop_barrier_pillar.png"]
    for idx, pname in enumerate(prop_names):
        if idx < len(spans):
            x0, x1 = spans[idx]
            sub = bot_row.crop((max(0, x0 - 4), 0, min(w, x1 + 4), bot_row.height))
            placed = trim_and_place(sub, 128, 128, margin=8, align_bottom=116)
            placed.save(os.path.join(OUT_RIFT, pname))


def process_medals() -> None:
    img = Image.open(os.path.join(RAW_ARCHIVE_DIR, "07_three_passive_medals.jpg")).convert("RGB")
    keyed = key_magenta_rgba(img, protect_interior=True)
    alpha = np.array(keyed)[..., 3]
    spans = find_x_spans(alpha, min_val=15.0, min_width=40)
    print("Medals x spans:", spans)
    names = ["passive_gravity_well.png", "passive_orbital_laser.png", "passive_phantom_slash.png"]
    for idx, name in enumerate(names):
        if idx < len(spans):
            x0, x1 = spans[idx]
            sub = keyed.crop((max(0, x0 - 2), 0, min(img.width, x1 + 2), keyed.height))
            placed = trim_and_place(sub, 96, 96, margin=2)
            placed.save(os.path.join(OUT_UI, name))


def black_to_glow_rgba(img: Image.Image, preserve_enclosed_dark: bool = False) -> Image.Image:
    arr = np.array(img.convert("RGB")).astype(np.float32)
    lum = arr.max(axis=2)
    if preserve_enclosed_dark:
        # Anything connected to the border with lum < 36 is exterior black background;
        # interior dark core (blackhole event horizon) stays deep opaque dark purple-black!
        ext_bg = flood_exterior(lum < 36.0)
        core_mask = ~ext_bg
        # Enclosed hole check: fill enclosed voids whose border flood couldn't reach
        enclosed = core_mask & (lum < 32.0)
        a = np.where(ext_bg, 0.0, np.where(enclosed, 0.94, np.clip((lum - 16.0) / 56.0, 0.0, 1.0)))
        rgb = arr.copy()
        denom = np.maximum(a, 0.16)[..., None]
        bright_rgb = np.clip(arr / denom, 0.0, 255.0)
        rgb = np.where(enclosed[..., None], np.array([12.0, 6.0, 26.0]), bright_rgb)
        rgba = np.dstack([rgb, a * 255.0])
    else:
        a = np.clip((lum - 14.0) / 56.0, 0.0, 1.0)
        denom = np.maximum(a, 0.16)[..., None]
        rgb = np.clip(arr / denom, 0.0, 255.0)
        rgb = rgb * np.clip(a / 0.28, 0.0, 1.0)[..., None]
        rgba = np.dstack([rgb, a * 255.0])
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


def _find_valley_cuts(lum: np.ndarray, expected_count: int) -> list[tuple[int, int]]:
    w = lum.shape[1]
    # Vertical projection energy (mean lum) + brightest pixels density
    col_energy = (lum > 30.0).sum(axis=0).astype(np.float32) * 4.0 + lum.mean(axis=0)
    # Trim leading/trailing empty space
    nonzero = np.where(col_energy > 2.0)[0]
    x_min = int(nonzero[0]) if len(nonzero) else 0
    x_max = int(nonzero[-1]) + 1 if len(nonzero) else w
    span_w = max(1, x_max - x_min)

    cuts = [max(0, x_min - 6)]
    for i in range(1, expected_count):
        approx = x_min + int(round(span_w * float(i) / float(expected_count)))
        lo = max(cuts[-1] + 24, approx - int(span_w / (expected_count * 2.2)))
        hi = min(x_max - 24, approx + int(span_w / (expected_count * 2.2)))
        if hi <= lo:
            cuts.append(approx)
        else:
            best_x = lo + int(np.argmin(col_energy[lo:hi + 1]))
            cuts.append(best_x)
    cuts.append(min(w, x_max + 6))
    return [(cuts[i], cuts[i + 1]) for i in range(expected_count)]


def split_row_frames(row_img: Image.Image, expected_count: int, preserve_enclosed_dark: bool = False) -> list[Image.Image]:
    arr = np.array(row_img.convert("RGB")).astype(np.float32)
    lum = arr.max(axis=2)
    w, h = row_img.size
    spans = find_x_spans(lum, min_val=34.0, min_width=10)
    if len(spans) == expected_count:
        use_spans = [(max(0, s - 4), min(w, e + 4)) for s, e in spans]
    else:
        use_spans = _find_valley_cuts(lum, expected_count)
    print(f"Final frame cuts (expected {expected_count}):", use_spans)
    return [black_to_glow_rgba(row_img.crop((x0, 0, x1, h)), preserve_enclosed_dark=preserve_enclosed_dark) for x0, x1 in use_spans]


def pack_sheet(frames: list[Image.Image], cell_w: int, cell_h: int, margin: int = 6, align_bottom: int | None = None, uniform_scale: bool = False) -> Image.Image:
    sheet = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    if uniform_scale:
        max_w = 1
        max_h = 1
        trimmed = []
        for fr in frames:
            bb = fr.getbbox()
            if bb:
                p = fr.crop(bb)
                max_w = max(max_w, p.width)
                max_h = max(max_h, p.height)
                trimmed.append(p)
            else:
                trimmed.append(None)
        scale = min((cell_w - margin * 2) / max_w, (cell_h - margin * 2) / max_h)
        for i, p in enumerate(trimmed):
            if p is None:
                continue
            nw = max(1, int(round(p.width * scale)))
            nh = max(1, int(round(p.height * scale)))
            rs = p.resize((nw, nh), Image.Resampling.LANCZOS)
            dx = i * cell_w + (cell_w - nw) // 2
            dy = (align_bottom - nh) if align_bottom is not None else ((cell_h - nh) // 2)
            sheet.paste(rs, (dx, max(0, min(cell_h - nh, dy))), rs)
        return sheet

    for i, fr in enumerate(frames):
        placed = trim_and_place(fr, cell_w, cell_h, margin=margin, align_bottom=align_bottom)
        sheet.paste(placed, (i * cell_w, 0), placed)
    return sheet


def process_vfx() -> None:
    # 08: Portal (8 frames top) + 2 Blades (bottom)
    img08 = Image.open(os.path.join(RAW_ARCHIVE_DIR, "08_vfx_portal_and_blades.jpg")).convert("RGB")
    h8 = img08.height
    row8_top = img08.crop((0, 0, img08.width, int(h8 * 0.44)))
    row8_bot = img08.crop((0, int(h8 * 0.48), img08.width, h8))
    portal_frames = split_row_frames(row8_top, 8, preserve_enclosed_dark=True)
    pack_sheet(portal_frames, 128, 128, margin=4, uniform_scale=True).save(os.path.join(OUT_VFX, "vfx_portal_warp.png"))
    blade_frames = split_row_frames(row8_bot, 2, preserve_enclosed_dark=False)
    trim_and_place(blade_frames[0], 128, 128, margin=6).save(os.path.join(OUT_VFX, "vfx_blade_cyan.png"))
    trim_and_place(blade_frames[1], 128, 128, margin=6).save(os.path.join(OUT_VFX, "vfx_blade_gold.png"))

    # 09: Meteor (6 frames top) + Frost spikes (6 frames bottom)
    img09 = Image.open(os.path.join(RAW_ARCHIVE_DIR, "09_vfx_meteor_and_frost.jpg")).convert("RGB")
    h9 = img09.height
    row9_top = img09.crop((0, 0, img09.width, int(h9 * 0.46)))
    row9_bot = img09.crop((0, int(h9 * 0.46), img09.width, h9))
    meteor_frames = split_row_frames(row9_top, 6, preserve_enclosed_dark=False)
    pack_sheet(meteor_frames, 128, 128, margin=4, uniform_scale=True).save(os.path.join(OUT_VFX, "vfx_meteor_comet.png"))
    frost_frames = split_row_frames(row9_bot, 6, preserve_enclosed_dark=False)
    pack_sheet(frost_frames, 128, 128, margin=4, align_bottom=118, uniform_scale=True).save(os.path.join(OUT_VFX, "vfx_frost_spikes.png"))

    # 10: Blackhole (6 frames top) + Orbital beam (4 frames bottom)
    img10 = Image.open(os.path.join(RAW_ARCHIVE_DIR, "10_vfx_blackhole_and_beam.jpg")).convert("RGB")
    h10 = img10.height
    row10_top = img10.crop((0, 0, img10.width, int(h10 * 0.45)))
    row10_bot = img10.crop((0, int(h10 * 0.47), img10.width, h10))
    bh_frames = split_row_frames(row10_top, 6, preserve_enclosed_dark=True)
    pack_sheet(bh_frames, 128, 128, margin=4, uniform_scale=True).save(os.path.join(OUT_VFX, "vfx_blackhole_void.png"))
    beam_frames = split_row_frames(row10_bot, 4, preserve_enclosed_dark=False)
    pack_sheet(beam_frames, 128, 192, margin=4, align_bottom=184, uniform_scale=True).save(os.path.join(OUT_VFX, "vfx_orbital_beam.png"))


if __name__ == "__main__":
    ensure_dirs()
    process_rooms()
    process_corridor_and_props()
    process_medals()
    process_vfx()
    print("Built all v0.31 assets cleanly.")
