#!/usr/bin/env python3
"""Build all v0.30 production pixel assets:
1. Archive raw generated sheets in d:/godot/美术参考/v030_raw/
2. Three 1600x900 chapter Rift Hunting Ground pixel arenas -> assets/rift_v030/rift_{wilds,abyss,void}.png
3. Portals, Bounty Chest & XP Crystals -> assets/rift_v030/{portal_rift,portal_return,chest_bounty,xp_cyan,xp_violet,xp_magnet}.png
4. 18 Circular Passive Medallions + Golden Capstone Card -> assets/ui_v030/passive_*.png, card_evo_gold.png
5. Visual QA contact sheet -> scratch/v030_assets_check.png
"""

from __future__ import annotations

import shutil
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

PROJECT = Path(__file__).resolve().parents[1]
RAW_ARCHIVE = PROJECT.parent / "美术参考" / "v030_raw"
ARTIFACT_DIR = Path(r"C:\Users\黄子衿\.gemini\antigravity\brain\576a2758-9e88-4f27-8e7a-860481c4c0c1")
SCRATCH_CHECK = ARTIFACT_DIR / "scratch" / "v030_assets_check.png"

RIFT_OUT = PROJECT / "assets" / "rift_v030"
UI_OUT = PROJECT / "assets" / "ui_v030"

SRC_FILES = {
    "rift_wilds": ARTIFACT_DIR / "rift_wilds_raw_v3_1795510014565.jpg",
    "rift_abyss": ARTIFACT_DIR / "rift_abyss_raw_v2_1795509995980.jpg",
    "rift_void": ARTIFACT_DIR / "rift_void_raw_1795509996047.jpg",
    "portal_gems": ARTIFACT_DIR / "portal_and_gems_raw_1795509973528.jpg",
    "medals_1": ARTIFACT_DIR / "medals_part1_raw_1795509987574.jpg",
    "medals_2": ARTIFACT_DIR / "medals_part2_raw_1795509983438.jpg",
}

MEDALS_PART1 = [
    ["chain_bolt", "frost_nova", "blazing_wake"],
    ["star_meteor", "void_bloom", "orbit_blades"],
    ["multishot", "ricochet", "frenzy"],
]

MEDALS_PART2 = [
    ["executioner", "thunder_dash", "arcane_echo"],
    ["blood_aegis", "star_magnet", "tower_storm"],
    ["tower_frost", "tower_aegis", "tower_horn"],
]

PROPS_GRID = [
    [("portal_rift", 128), ("portal_return", 128), ("chest_bounty", 96)],
    [("xp_cyan", 48), ("xp_violet", 56), ("xp_magnet", 64)],
]


def _hex(h: str, a: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def _dilate(mask: np.ndarray, iters: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(iters):
        d = out.copy()
        d[1:, :] |= out[:-1, :]
        d[:-1, :] |= out[1:, :]
        d[:, 1:] |= out[:, :-1]
        d[:, :-1] |= out[:, 1:]
        out = d
    return out


def _chroma_extract_cell(cell_rgba: np.ndarray, out_size: int, pad_ratio: float = 0.06) -> Image.Image:
    h, w, _ = cell_rgba.shape
    arr = cell_rgba.copy()
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)

    cand = (g > 115) & ((g - np.maximum(r, b)) > 36)
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for sx in range(w):
        for sy in (0, h - 1):
            if cand[sy, sx] and not bg[sy, sx]:
                bg[sy, sx] = True
                q.append((sy, sx))
    for sy in range(h):
        for sx in (0, w - 1):
            if cand[sy, sx] and not bg[sy, sx]:
                bg[sy, sx] = True
                q.append((sy, sx))
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and cand[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    # Remove pure neon-green enclosed holes (e.g. inside magnet or ring gaps) while protecting dark emerald details
    strict_holes = (g > 188) & (r < 95) & (b < 95) & ((g - np.maximum(r, b)) > 105) & (~bg)
    bg |= strict_holes

    # Strip 1px bright green AA halo on outer edge
    edge1 = _dilate(bg, 1) & (~bg)
    bg |= edge1 & (g > 104) & ((g - np.maximum(r, b)) > 32)
    arr[bg, 3] = 0

    # Despill 2px boundary
    edge2 = _dilate(bg, 2) & (~bg)
    sp = edge2 & (g > np.maximum(r, b) + 6)
    max_rb = np.maximum(r[sp], b[sp])
    arr[sp, 1] = np.minimum(arr[sp, 1], np.clip(max_rb + 3, 0, 255)).astype(np.uint8)

    oys, oxs = np.where(arr[:, :, 3] > 24)
    if len(oxs) == 0:
        raise RuntimeError("Empty sprite cell after chroma key!")
    x0, x1 = int(oxs.min()), int(oxs.max()) + 1
    y0, y1 = int(oys.min()), int(oys.max()) + 1
    cropped = Image.fromarray(arr[y0:y1, x0:x1])

    side = int(round(max(cropped.width, cropped.height) * (1.0 + pad_ratio)))
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2), cropped)

    # Pixel-crisp downscale: first Lanczos to half-res or target, then quantize alpha cleanly
    out = sq.resize((out_size, out_size), Image.Resampling.LANCZOS)
    out_arr = np.array(out)
    out_arr[out_arr[:, :, 3] < 48, 3] = 0
    out_arr[out_arr[:, :, 3] >= 180, 3] = 255
    return ImageEnhance.Sharpness(Image.fromarray(out_arr)).enhance(1.10)


def _build_rift_maps() -> list[Image.Image]:
    built = []
    for key in ("rift_wilds", "rift_abyss", "rift_void"):
        im = Image.open(SRC_FILES[key]).convert("RGB")
        # Snap to 800x450 crisp pixel grid then 2x NEAREST upscale to 1600x900 for razor-sharp 2px pixel clusters
        half = im.resize((800, 450), Image.Resampling.BOX)
        half = ImageEnhance.Sharpness(half).enhance(1.18)
        crisp = half.resize((1600, 900), Image.Resampling.NEAREST)
        out_path = RIFT_OUT / f"{key}.png"
        crisp.save(out_path)
        built.append(crisp)
        print(f"Saved {out_path} ({crisp.size})")
    return built


def _slice_grid_sheet(src_path: Path, rows: int, cols: int) -> list[list[np.ndarray]]:
    arr = np.array(Image.open(src_path).convert("RGBA"))
    h, w, _ = arr.shape
    ch = h / rows
    cw = w / cols
    grid = []
    for r_i in range(rows):
        row_cells = []
        y0 = int(round(r_i * ch))
        y1 = int(round((r_i + 1) * ch))
        for c_i in range(cols):
            x0 = int(round(c_i * cw))
            x1 = int(round((c_i + 1) * cw))
            row_cells.append(arr[y0:y1, x0:x1])
        grid.append(row_cells)
    return grid


def _build_evo_card_frame() -> Image.Image:
    w, h = 296, 376
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def chamfer(x0, y0, x1, y1, c, fill, outline=None):
        pts = [
            (x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
            (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c),
        ]
        d.polygon(pts, fill=fill, outline=outline)

    chamfer(0, 0, w - 1, h - 1, 12, _hex("0a0d16"))
    chamfer(2, 2, w - 3, h - 3, 11, _hex("a6741e"))
    chamfer(4, 4, w - 5, h - 5, 10, _hex("ffe17d"))
    chamfer(7, 7, w - 8, h - 8, 8, _hex("5e3e12"))
    chamfer(10, 10, w - 11, h - 11, 7, _hex("1b1528"))
    # Subtle royal purple-gold gradient bands inside
    for y in range(12, h - 12, 2):
        u = (y - 12) / max(1, h - 24)
        r_c = int(34 * (1.0 - u) + 18 * u)
        g_c = int(24 * (1.0 - u) + 14 * u)
        b_c = int(48 * (1.0 - u) + 28 * u)
        d.rectangle([12, y, w - 13, y + 1], fill=(r_c, g_c, b_c, 255))
    # Corner golden diamonds
    for cx, cy in ((14, 14), (w - 15, 14), (14, h - 15), (w - 15, h - 15)):
        d.polygon([(cx, cy - 4), (cx + 4, cy), (cx, cy + 4), (cx - 4, cy)], fill=_hex("fff0a6"))
    out_path = UI_OUT / "card_evo_gold.png"
    im.save(out_path)
    print(f"Saved {out_path}")
    return im


def main() -> None:
    RAW_ARCHIVE.mkdir(parents=True, exist_ok=True)
    RIFT_OUT.mkdir(parents=True, exist_ok=True)
    UI_OUT.mkdir(parents=True, exist_ok=True)
    SCRATCH_CHECK.parent.mkdir(parents=True, exist_ok=True)

    for name, src in SRC_FILES.items():
        shutil.copy2(src, RAW_ARCHIVE / f"{name}_raw.jpg")

    maps = _build_rift_maps()

    # Slice props (portals, chest, xp crystals)
    prop_cells = _slice_grid_sheet(SRC_FILES["portal_gems"], 2, 3)
    prop_imgs = []
    for r_i in range(2):
        for c_i in range(3):
            p_name, p_sz = PROPS_GRID[r_i][c_i]
            img = _chroma_extract_cell(prop_cells[r_i][c_i], p_sz, pad_ratio=0.04)
            img.save(RIFT_OUT / f"{p_name}.png")
            prop_imgs.append((p_name, img))
            print(f"Saved {RIFT_OUT / (p_name + '.png')} ({p_sz}x{p_sz})")

    # Slice 18 passive medals
    medal_imgs = []
    for sheet_key, id_grid in (("medals_1", MEDALS_PART1), ("medals_2", MEDALS_PART2)):
        cells = _slice_grid_sheet(SRC_FILES[sheet_key], 3, 3)
        for r_i in range(3):
            for c_i in range(3):
                mid = id_grid[r_i][c_i]
                icon = _chroma_extract_cell(cells[r_i][c_i], 96, pad_ratio=0.05)
                icon.save(UI_OUT / f"passive_{mid}.png")
                medal_imgs.append((mid, icon))
                print(f"Saved passive_{mid}.png")

    _build_evo_card_frame()

    # Build dark checkerboard QA contact sheet
    qa = Image.new("RGBA", (1280, 720), _hex("141b24"))
    qd = ImageDraw.Draw(qa)
    for idx, m_im in enumerate(maps):
        thumb = m_im.resize((400, 225), Image.Resampling.NEAREST)
        qa.paste(thumb, (20 + idx * 415, 16))
    for idx, (_, p_im) in enumerate(prop_imgs):
        disp = p_im.resize((96, 96), Image.Resampling.NEAREST)
        qa.paste(disp, (30 + idx * 140, 265), disp)
    for idx, (_, m_icon) in enumerate(medal_imgs):
        col = idx % 9
        row = idx // 9
        qa.paste(m_icon, (30 + col * 132, 395 + row * 136), m_icon)
    qd.rectangle([0, 0, 1279, 719], outline=_hex("59c9f5"))
    qa.save(SCRATCH_CHECK)
    print(f"QA contact sheet written to {SCRATCH_CHECK}")


if __name__ == "__main__":
    main()
