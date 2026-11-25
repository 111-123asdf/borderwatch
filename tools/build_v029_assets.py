#!/usr/bin/env python3
"""Build all v0.29 production assets from d:/godot/美术参考/v029_raw:
1. Four 1600x900 pixel battle maps -> assets/maps_v029/map_{saltport,lighthouse,ruins,sanctum}.png
2. 12 Coast Legion sheets + portraits -> assets/monsters_v029_coast/
3. 12 Ruins Legion sheets + portraits -> assets/monsters_v029_ruins/
4. Visual audit contact sheets -> test-results/v029-art/{audit_maps_alignment,audit_coast,audit_ruins}.png
"""

from __future__ import annotations

import json
import math
import sys
from collections import deque
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw

TOOLS_DIR = Path(__file__).resolve().parent
PROJECT = TOOLS_DIR.parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import build_pixel_monsters as bpm  # noqa: E402

RAW_DIR = PROJECT.parent / "美术参考" / "v029_raw"
PREP_LAYOUT_PATH = PROJECT.parent / "美术参考" / "v029_prep" / "v029_maps_layout.json"
MAPS_OUT = PROJECT / "assets" / "maps_v029"
COAST_OUT = PROJECT / "assets" / "monsters_v029_coast"
RUINS_OUT = PROJECT / "assets" / "monsters_v029_ruins"
AUDIT_DIR = PROJECT / "test-results" / "v029-art"

RAW_FILES = {
    "map_saltport": "download.png",
    "map_lighthouse": "156320238a4e5991c07ef12395f5d147.png",
    "map_ruins": "b92e7ca5f7108f803678ac6f1a739c90.png",
    "map_sanctum": "71d7229e4d9d099c2f09b33ce9dd8eb2.png",
    "coast_sheet1": "8bfb7cedc77e074d0263656a029a7f8e.png",
    "coast_sheet2": "bb931da95679dd34fabed09180d11e35.png",
    "coast_crab": "6bb2afcff69a8b6df781aa0882a2be31.png",
    "coast_leviathan": "51a7717df94674b6266234330ef9525f.png",
    "coast_portraits": "79b20452e19c3aa973062b712bfd9577.png",
    "ruins_sheet1": "8d29c75b2fb4b84752ec1cbc6e57ca44.png",
    "ruins_sheet2": "f5004eb5a02bf8151f7bc8f851ddd475.png",
    "ruins_behemoth": "d2d280669bbab6a607231647d9abe157.png",
    "ruins_bajnimen": "059aa09a9c1eae4daa81ae9d0d04656a.png",
    "ruins_portraits": "7f7fb5b521cd2a093d02014150509ae0.png",
}

# Verified flat-ground tower site coordinates matched to generated 1600x900 pixel maps
VERIFIED_SITES: Dict[str, List[Tuple[int, int]]] = {
    "saltport": [
        (175, 325), (440, 240), (585, 480), (845, 315), (1165, 250),
        (285, 705), (560, 750), (825, 745), (1010, 520), (1250, 705), (1390, 325),
    ],
    "lighthouse": [
        (190, 290), (545, 185), (610, 385), (845, 380), (1065, 385), (250, 610),
        (425, 605), (735, 575), (880, 780), (1085, 776), (1295, 345), (1395, 610),
    ],
    "ruins": [
        (190, 315), (471, 244), (560, 400), (895, 310), (1035, 365), (215, 595),
        (581, 598), (640, 775), (945, 550), (1095, 745), (1295, 255), (1395, 595),
    ],
    "sanctum": [
        (190, 295), (545, 165), (545, 355), (855, 275), (740, 155), (1404, 200),
        (195, 600), (454, 546), (697, 562), (965, 575), (1075, 435), (1250, 740), (1400, 489),
    ],
}

COAST_PORTRAIT_ORDER = [
    "murloc_hunter", "tide_rider", "water_sprite", "storm_wyrm",
    "tide_warrior", "wind_captain", "conch_mage", "water_elder",
    "tempest_elemental", "bluegale", "bloodshell_crab", "leviathan",
]

RUINS_PORTRAIT_ORDER = [
    "void_eyeling", "void_gazer", "twilight_harasser", "spectral_cutter",
    "twilight_avenger", "avenger_rider", "venom_spitter", "soul_reaver",
    "twilight_golem", "vile_eyenest", "bloodsoil_behemoth", "baj_nimen",
]


def _strict_fg_mask(arr: np.ndarray) -> np.ndarray:
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)
    return ~((g > 155) & (r < 110) & (b < 110) & ((g - r) > 55) & ((g - b) > 55))


def detect_row_bands(raw_arr: np.ndarray, expected_rows: int) -> List[Tuple[int, int]]:
    fg = _strict_fg_mask(raw_arr)
    row_cov = fg.sum(axis=1)
    bands: List[Tuple[int, int]] = []
    in_b = False
    r0 = 0
    for y in range(len(row_cov)):
        if row_cov[y] > 12 and not in_b:
            in_b = True
            r0 = y
        elif row_cov[y] <= 12 and in_b:
            in_b = False
            if y - r0 > 20:
                bands.append((r0, y))
    if in_b and len(row_cov) - r0 > 20:
        bands.append((r0, len(row_cov)))
    assert len(bands) == expected_rows, f"Expected {expected_rows} rows, got {len(bands)}: {bands}"
    return bands


def slice_row_frames(raw_arr: np.ndarray, y0: int, y1: int, num_frames: int, protect_green: bool = True) -> List[np.ndarray]:
    """Find cleanest vertical valley splits across a row band and return RGBA keyed frames."""
    h, w, _ = raw_arr.shape
    py0 = max(0, y0 - 8)
    py1 = min(h, y1 + 8)
    fg = _strict_fg_mask(raw_arr[py0:py1, :, :])
    cov = fg.sum(axis=0)

    cuts = [0]
    half_win = max(60, int(w / (num_frames * 1.45)))
    for k in range(1, num_frames):
        est = int(round(k * w / float(num_frames)))
        lo = max(cuts[-1] + 55, est - half_win)
        hi = min(w - 55, est + half_win)
        sub = cov[lo : hi + 1]
        mval = int(sub.min())
        # Prefer wider contiguous runs of minimum value near estimate
        cand = np.where(sub == mval)[0] + lo
        # Pick index closest to middle of longest run if mval==0, else closest to est
        cut = int(round(float(cand.mean())))
        if mval == 0 and len(cand) > 1:
            # Find zero-run closest to est (avoids averaging two disconnected zero gaps)
            runs = []
            rs = cand[0]
            prev = cand[0]
            for c in cand[1:]:
                if c - prev > 2:
                    runs.append((rs, prev))
                    rs = c
                prev = c
            runs.append((rs, prev))
            best_run = min(runs, key=lambda ab: abs(((ab[0] + ab[1]) * 0.5) - est))
            cut = int(round((best_run[0] + best_run[1]) * 0.5))
        cuts.append(cut)
    cuts.append(w)

    frames: List[np.ndarray] = []
    for i in range(num_frames):
        xa, xb = cuts[i], cuts[i + 1]
        keyed = bpm.key_crop(raw_arr, (xa, py0, xb, py1), protect_green=protect_green)
        frames.append(keyed)
    return frames


def slice_row_explicit(raw_arr: np.ndarray, y0: int, y1: int, boxes: List[Tuple[int, int]], protect_green: bool = True) -> List[np.ndarray]:
    h = raw_arr.shape[0]
    py0 = max(0, y0 - 8)
    py1 = min(h, y1 + 8)
    return [bpm.key_crop(raw_arr, (xa, py0, xb, py1), protect_green=protect_green) for (xa, xb) in boxes]


def extract_portraits(sheet_path: Path, out_dir: Path, order: List[str]) -> None:
    arr = np.array(Image.open(sheet_path).convert("RGB"))
    bg = (arr[:, :, 0] < 35) & (arr[:, :, 1] < 50) & (arr[:, :, 2] < 65)
    fg = ~bg

    def _bands(cov: np.ndarray) -> List[Tuple[int, int]]:
        out: List[Tuple[int, int]] = []
        in_b = False
        b0 = 0
        for idx, val in enumerate(cov):
            if val > 40 and not in_b:
                in_b = True
                b0 = idx
            elif val <= 40 and in_b:
                in_b = False
                if idx - b0 > 120:
                    out.append((b0, idx))
        if in_b and len(cov) - b0 > 120:
            out.append((b0, len(cov)))
        return out

    rb = _bands(fg.sum(axis=1))
    cb = _bands(fg.sum(axis=0))
    assert len(rb) == 3 and len(cb) == 4, f"Expected 3x4 portraits in {sheet_path}, got {len(rb)}x{len(cb)}"

    raw_img = Image.open(sheet_path).convert("RGBA")
    for r, (ya, yb) in enumerate(rb):
        for c, (xa, xb) in enumerate(cb):
            mid = order[r * 4 + c]
            crop = raw_img.crop((xa, ya, xb, yb)).resize((128, 128), Image.Resampling.NEAREST)
            crop.save(out_dir / f"portrait_{mid}.png")


def build_legion_assets(
    out_dir: Path,
    sheet1_key: str,
    sheet2_key: str,
    miniboss_key: str,
    boss_key: str,
    portraits_key: str,
    portrait_order: List[str],
    specs: dict,
    miniboss_spec: dict,
    boss_spec: dict,
    audit_path: Path,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    extract_portraits(RAW_DIR / RAW_FILES[portraits_key], out_dir, portrait_order)

    built_meta: List[Tuple[str, int, List[str]]] = []

    for skey, row_list in ((sheet1_key, specs["sheet1"]), (sheet2_key, specs["sheet2"])):
        raw_arr = np.array(Image.open(RAW_DIR / RAW_FILES[skey]).convert("RGBA"))
        row_bands = detect_row_bands(raw_arr, len(row_list))
        for (ya, yb), rspec in zip(row_bands, row_list):
            mid = rspec["id"]
            if "x_boxes" in rspec:
                frames = slice_row_explicit(raw_arr, ya, yb, rspec["x_boxes"], protect_green=True)
            else:
                frames = slice_row_frames(raw_arr, ya, yb, rspec["nf"], protect_green=True)
            rows_dict = {
                "walk": [frames[i] for i in rspec["walk"]],
                "attack": [frames[i] for i in rspec["attack"]],
                "down": [frames[i] for i in rspec["down"]],
            }
            states = ["walk", "attack", "down"]
            bpm.build_monster_sheet(out_dir / f"creature_{mid}.png", rows_dict, states, bpm.STD_CELL, rspec["target_h"])
            built_meta.append((mid, bpm.STD_CELL, states))

    for mkey, mspec in ((miniboss_key, miniboss_spec), (boss_key, boss_spec)):
        raw_arr = np.array(Image.open(RAW_DIR / RAW_FILES[mkey]).convert("RGBA"))
        row_bands = detect_row_bands(raw_arr, 4)
        states = ["walk", "attack", "skill", "down"]
        rows_dict = {}
        for (ya, yb), st in zip(row_bands, states):
            rows_dict[st] = slice_row_frames(raw_arr, ya, yb, 4, protect_green=True)
        mid = mspec["id"]
        bpm.build_monster_sheet(out_dir / f"creature_{mid}.png", rows_dict, states, bpm.BOSS_CELL, mspec["target_h"])
        built_meta.append((mid, bpm.BOSS_CELL, states))

    # Build visual audit contact sheet
    thumb = 112
    audit = Image.new("RGBA", (thumb * 6, thumb * len(portrait_order)), (32, 38, 48, 255))
    draw = ImageDraw.Draw(audit)
    for y in range(0, audit.height, 16):
        for x in range(0, audit.width, 16):
            if ((x // 16) + (y // 16)) % 2 == 0:
                draw.rectangle([x, y, x + 15, y + 15], fill=(42, 48, 60, 255))

    meta_map = {m[0]: (m[1], m[2]) for m in built_meta}
    for r_i, mid in enumerate(portrait_order):
        p_path = out_dir / f"portrait_{mid}.png"
        if p_path.exists():
            pi = Image.open(p_path).resize((thumb - 8, thumb - 8), Image.Resampling.NEAREST)
            audit.paste(pi, (4, r_i * thumb + 4), pi)
        c_sz, states = meta_map[mid]
        s_img = Image.open(out_dir / f"creature_{mid}.png")
        picks = [
            (0, 0),
            (0, 3),
            (1, 3),
            (2 if "skill" in states else 1, 5),
            (len(states) - 1, 5),
        ]
        for c_i, (row_s, col_s) in enumerate(picks):
            cell = s_img.crop((col_s * c_sz, row_s * c_sz, (col_s + 1) * c_sz, (row_s + 1) * c_sz))
            t = cell.resize((thumb, thumb), Image.Resampling.NEAREST)
            audit.paste(t, ((c_i + 1) * thumb, r_i * thumb), t)
        draw.text((6, r_i * thumb + 4), mid, fill=(255, 240, 140, 255))

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit.save(audit_path)


def _sample_curve(wps: List[List[float]]) -> List[Tuple[float, float]]:
    n = len(wps)
    ins, outs = [], []
    for i in range(n):
        p0, p1 = wps[max(0, i - 1)], wps[min(n - 1, i + 1)]
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        ln = math.hypot(dx, dy)
        nx, ny = (dx / ln, dy / ln) if ln > 1e-6 else (0.0, 0.0)
        mag = min(math.hypot(p0[0] - wps[i][0], p0[1] - wps[i][1]), math.hypot(p1[0] - wps[i][0], p1[1] - wps[i][1])) * 0.23
        ins.append((wps[i][0] - nx * mag, wps[i][1] - ny * mag))
        outs.append((wps[i][0] + nx * mag, wps[i][1] + ny * mag))
    pts: List[Tuple[float, float]] = []
    for i in range(n - 1):
        a, b, c, d = wps[i], outs[i], ins[i + 1], wps[i + 1]
        for s in range(28):
            t = s / 28.0
            mt = 1.0 - t
            pts.append((
                (mt ** 3) * a[0] + 3 * (mt ** 2) * t * b[0] + 3 * mt * (t ** 2) * c[0] + (t ** 3) * d[0],
                (mt ** 3) * a[1] + 3 * (mt ** 2) * t * b[1] + 3 * mt * (t ** 2) * c[1] + (t ** 3) * d[1],
            ))
    pts.append((wps[-1][0], wps[-1][1]))
    return pts


def build_maps_and_alignment_audit(audit_path: Path) -> None:
    MAPS_OUT.mkdir(parents=True, exist_ok=True)
    layout = json.loads(PREP_LAYOUT_PATH.read_text(encoding="utf-8"))

    order = ["saltport", "lighthouse", "ruins", "sanctum"]
    quad_w, quad_h = 800, 450
    audit = Image.new("RGB", (quad_w * 2, quad_h * 2), (16, 20, 28))

    for q_idx, key in enumerate(order):
        src = Image.open(RAW_DIR / RAW_FILES[f"map_{key}"]).convert("RGB")
        resized = src.resize((1600, 900), Image.Resampling.LANCZOS)
        resized.save(MAPS_OUT / f"map_{key}.png")

        ov = resized.copy().convert("RGBA")
        draw = ImageDraw.Draw(ov)

        cfg = layout[key]
        sites = VERIFIED_SITES[key]
        road_pts = [p for r in cfg["routes"] + cfg.get("detour_routes", []) for p in _sample_curve(r)]
        for i, s in enumerate(sites):
            mr = min(math.hypot(s[0] - p[0], s[1] - p[1]) for p in road_pts)
            ms = min(math.hypot(s[0] - s2[0], s[1] - s2[1]) for j, s2 in enumerate(sites) if j != i)
            assert mr >= 54.0, f"{key} site {i} {s} too close to road: {mr:.1f}"
            assert ms >= 110.0, f"{key} site {i} {s} too close to site: {ms:.1f}"
            assert s[1] >= 110 and not (s[0] < 355 and s[1] > 795) and not (s[0] > 1090 and s[1] > 810), f"{key} site {i} {s} in HUD zone"

        for dr in cfg.get("detour_routes", []):
            draw.line(_sample_curve(dr), fill=(255, 198, 92, 220), width=3)
        for r in cfg["routes"]:
            draw.line(_sample_curve(r), fill=(255, 255, 255, 220), width=3)
        for idx, (sx, sy) in enumerate(sites):
            locked = idx in cfg["locked_sites"]
            col = (255, 100, 160, 245) if locked else (120, 245, 255, 245)
            draw.rectangle((sx - 46, sy - 23, sx + 46, sy + 23), outline=col, width=4)
            draw.text((sx - 8, sy - 6), f"{idx}{'*' if locked else ''}", fill=(255, 250, 210, 255))
        for ex, ey in cfg["exits"]:
            for py in (ey - 44, ey + 44):
                draw.ellipse((ex - 10, py - 10, ex + 10, py + 10), fill=(96, 236, 255, 235), outline=(255, 255, 255, 255), width=2)

        thumb = ov.convert("RGB").resize((quad_w, quad_h), Image.Resampling.LANCZOS)
        audit.paste(thumb, ((q_idx % 2) * quad_w, (q_idx // 2) * quad_h))

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit.save(audit_path)


def write_manifest_note() -> None:
    note = "\n".join(f"{v} -> {k}" for k, v in RAW_FILES.items()) + "\n"
    (RAW_DIR / "MANIFEST.txt").write_text(note, encoding="utf-8")


def main() -> None:
    write_manifest_note()
    build_maps_and_alignment_audit(AUDIT_DIR / "audit_maps_alignment.png")

    coast_specs = {
        "sheet1": [
            {"id": "murloc_hunter", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 108.0},
            {"id": "tide_rider", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 116.0},
            {"id": "water_sprite", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 112.0},
            {"id": "storm_wyrm", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 118.0},
            {"id": "tide_warrior", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 126.0,
             "x_boxes": [(25, 214), (220, 400), (410, 588), (592, 772), (773, 950), (950, 1198), (1198, 1445)]},
        ],
        "sheet2": [
            {"id": "wind_captain", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 120.0,
             "x_boxes": [(22, 232), (232, 444), (444, 637), (637, 818), (818, 1004), (1004, 1216), (1216, 1440)]},
            {"id": "conch_mage", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 120.0},
            {"id": "water_elder", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 120.0,
             "x_boxes": [(25, 208), (208, 397), (397, 580), (580, 769), (769, 976), (976, 1205), (1205, 1440)]},
            {"id": "tempest_elemental", "nf": 7, "walk": [0, 1, 2, 3], "attack": [3, 4], "down": [6], "target_h": 132.0},
            {"id": "bluegale", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4, 5], "down": [6], "target_h": 128.0,
             "x_boxes": [(15, 196), (196, 386), (386, 588), (588, 770), (770, 972), (972, 1206), (1206, 1435)]},
        ],
    }
    build_legion_assets(
        COAST_OUT,
        "coast_sheet1",
        "coast_sheet2",
        "coast_crab",
        "coast_leviathan",
        "coast_portraits",
        COAST_PORTRAIT_ORDER,
        coast_specs,
        {"id": "bloodshell_crab", "target_h": 168.0},
        {"id": "leviathan", "target_h": 186.0},
        AUDIT_DIR / "audit_coast.png",
    )

    ruins_specs = {
        "sheet1": [
            {"id": "void_eyeling", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [5, 6], "target_h": 96.0},
            {"id": "void_gazer", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [5, 6], "target_h": 116.0},
            {"id": "twilight_harasser", "nf": 6, "walk": [0, 1, 2], "attack": [3, 4], "down": [5], "target_h": 118.0},
            {"id": "spectral_cutter", "nf": 6, "walk": [0, 1, 2], "attack": [3, 4], "down": [5], "target_h": 112.0},
            {"id": "twilight_avenger", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [5, 6], "target_h": 128.0},
        ],
        "sheet2": [
            {"id": "avenger_rider", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [5, 6], "target_h": 128.0},
            {"id": "venom_spitter", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [5, 6], "target_h": 112.0},
            {"id": "soul_reaver", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [6], "target_h": 120.0},
            {"id": "twilight_golem", "nf": 7, "walk": [0, 1, 2], "attack": [3, 4], "down": [5, 6], "target_h": 136.0},
            {"id": "vile_eyenest", "nf": 7, "walk": [0, 1, 2, 3], "attack": [4], "down": [5, 6], "target_h": 134.0},
        ],
    }
    build_legion_assets(
        RUINS_OUT,
        "ruins_sheet1",
        "ruins_sheet2",
        "ruins_behemoth",
        "ruins_bajnimen",
        "ruins_portraits",
        RUINS_PORTRAIT_ORDER,
        ruins_specs,
        {"id": "bloodsoil_behemoth", "target_h": 172.0},
        {"id": "baj_nimen", "target_h": 188.0},
        AUDIT_DIR / "audit_ruins.png",
    )

    print("v0.29 asset build & audits complete!")


if __name__ == "__main__":
    main()
