#!/usr/bin/env python3
"""Prepare v0.29 Phase 1 art reference assets:
- 4 exact 1600x900 tactical map blueprints (matching Godot's ArenaLevelCatalog.curve 1:1)
- 1 2x2 geometry QA sheet showing HUD safe zones, blocked rects, and numbered sites
- 2 4x3 monster reference collages (Coast Legion from new4 + Storm Wyrm, Ruins Legion from new3)
- v029_maps_layout.json single source of truth for Phase 2 alignment audit
- Drop directory d:/godot/美术参考/v029_raw/ with README.txt
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

WORKSPACE_ROOT = Path(r"d:\godot")
PREP_DIR = WORKSPACE_ROOT / "美术参考" / "v029_prep"
RAW_DROP_DIR = WORKSPACE_ROOT / "美术参考" / "v029_raw"
NEW3_DIR = WORKSPACE_ROOT / "美术参考" / "new3"
NEW4_DIR = WORKSPACE_ROOT / "美术参考" / "new4"
SHOT1_PATH = Path(
    r"C:\Users\黄子衿\.gemini\antigravity\brain\576a2758-9e88-4f27-8e7a-860481c4c0c1\.user_uploaded\media_1795444977902_72880633.jpg"
)
# Verified exact square box for Row 3 (天雷雏龙 Storm Wyrm) inside shot1
STORM_WYRM_BOX = (24, 152, 91, 219)

MAP_W, MAP_H = 1600, 900
HUD_TOP_Y = 86
HUD_BOTTOM_LEFT = (0, 805, 350, 95)
HUD_BOTTOM_RIGHT = (1095, 820, 505, 80)

MAPS: Dict[str, dict] = {
    "saltport": {
        "order": 3,
        "filename": "blueprint_03_saltport.png",
        "title": "Stage 3: 白帆盐港 (saltport)",
        "exits": [(1520, 445)],
        "hero_spawn": (1385, 455),
        "routes": [
            [(-30, 215), (235, 215), (370, 355), (605, 355), (720, 195), (990, 195), (1110, 375), (1330, 445), (1520, 445)],
            [(430, 930), (430, 745), (610, 625), (895, 625), (1045, 710), (1235, 565), (1365, 445), (1520, 445)],
        ],
        "detour_routes": [],
        "sites": [
            (175, 325), (440, 240), (585, 480), (845, 315), (1165, 250),
            (285, 705), (560, 750), (825, 745), (1010, 520), (1250, 705), (1390, 325),
        ],
        "site_traits": [""] * 11,
        "locked_sites": [10],
        "blocked": [
            (0, 0, 280, 115),
            (450, 0, 175, 110),
            (1290, 0, 310, 160),
            (0, 415, 175, 195),
            (0, 790, 310, 110),
            (1370, 760, 230, 140),
        ],
        "palette": {
            "ground": (205, 191, 162),
            "meadow": (182, 173, 138),
            "road_border": (122, 108, 88),
            "road_fill": (222, 206, 174),
            "blocked_outer": (48, 114, 136),
            "blocked_inner": (34, 86, 112),
            "clearing": (214, 201, 172),
            "exit_pillar": (96, 175, 204),
        },
        "specials": {"coastal_coves": True},
    },
    "lighthouse": {
        "order": 4,
        "filename": "blueprint_04_lighthouse.png",
        "title": "Stage 4: 汐涌灯塔 (lighthouse)",
        "exits": [(1520, 495)],
        "hero_spawn": (1385, 495),
        "lighthouse_landmark": (1470, 125),
        "routes": [
            [(-30, 175), (280, 175), (455, 295), (765, 295), (925, 195), (1145, 290), (1285, 495), (1520, 495)],
            [(-30, 540), (245, 540), (405, 455), (680, 485), (900, 465), (1120, 515), (1285, 495), (1520, 495)],
            [(575, 930), (575, 765), (755, 670), (990, 705), (1185, 600), (1335, 495), (1520, 495)],
        ],
        "detour_routes": [],
        "sites": [
            (190, 290), (545, 185), (610, 385), (845, 380), (1065, 385), (195, 655),
            (425, 605), (735, 575), (880, 780), (1085, 776), (1295, 345), (1395, 610),
        ],
        "site_traits": [""] * 12,
        "locked_sites": [9, 10],
        "blocked": [
            (0, 0, 420, 90),
            (1340, 0, 260, 250),
            (0, 750, 450, 150),
            (1320, 765, 280, 135),
        ],
        "palette": {
            "ground": (152, 158, 146),
            "meadow": (134, 145, 126),
            "road_border": (92, 95, 94),
            "road_fill": (182, 179, 162),
            "shoal_fill": (118, 176, 178),
            "blocked_outer": (42, 98, 126),
            "blocked_inner": (28, 70, 98),
            "clearing": (166, 170, 156),
            "exit_pillar": (96, 198, 224),
        },
        "specials": {"shoal_route": 2, "lighthouse": (1470, 125)},
    },
    "ruins": {
        "order": 5,
        "filename": "blueprint_05_ruins.png",
        "title": "Stage 5: 紫雾遗迹 (ruins)",
        "exits": [(1520, 470)],
        "hero_spawn": (1380, 470),
        "routes": [
            [(-30, 190), (240, 190), (395, 325), (675, 325), (805, 195), (1040, 240), (1185, 440), (1355, 470), (1520, 470)],
            [(-30, 725), (260, 725), (385, 675), (495, 675), (655, 675), (855, 745), (1065, 630), (1240, 520), (1355, 470), (1520, 470)],
            [(1210, -30), (1160, 155), (1185, 330), (1255, 445), (1355, 470), (1520, 470)],
        ],
        "detour_routes": [
            [(-30, 725), (260, 725), (385, 675), (345, 515), (545, 465), (760, 510), (790, 675), (855, 745), (1065, 630), (1240, 520), (1355, 470), (1520, 470)],
        ],
        "sites": [
            (190, 315), (480, 215), (560, 400), (895, 310), (1035, 365), (215, 595),
            (490, 575), (640, 775), (945, 550), (1095, 745), (1295, 255), (1395, 595),
        ],
        "site_traits": [
            "highground", "choke", "conduit", "highground", "conduit", "choke",
            "choke", "highground", "conduit", "choke", "highground", "choke",
        ],
        "locked_sites": [9, 10],
        "blocked": [
            (0, 0, 280, 100),
            (540, 0, 180, 115),
            (1380, 0, 220, 165),
            (0, 805, 340, 95),
            (462, 725, 68, 175),
            (1290, 775, 310, 125),
        ],
        "palette": {
            "ground": (92, 90, 114),
            "meadow": (78, 76, 102),
            "road_border": (60, 58, 78),
            "road_fill": (136, 134, 152),
            "detour_fill": (114, 110, 136),
            "blocked_outer": (54, 42, 78),
            "blocked_inner": (34, 24, 54),
            "clearing": (104, 102, 126),
            "exit_pillar": (134, 212, 245),
        },
        "specials": {
            "drawbridge": (495, 675),
            "chasm_trench": (460, 620, 532, 900),
            "breach": (1160, 155),
        },
    },
    "sanctum": {
        "order": 6,
        "filename": "blueprint_06_sanctum.png",
        "title": "Stage 6: 星陨高坛 (sanctum)",
        "exits": [(1520, 290), (1520, 620)],
        "hero_spawn": (1345, 455),
        "routes": [
            [(-30, 175), (265, 175), (425, 275), (720, 245), (965, 185), (1185, 290), (1520, 290)],
            [(-30, 455), (260, 455), (455, 455), (695, 455), (935, 455), (1155, 575), (1355, 620), (1520, 620)],
            [(-30, 745), (295, 745), (505, 650), (795, 725), (1045, 695), (1245, 620), (1520, 620)],
            [(695, 455), (895, 365), (1135, 320), (1335, 290), (1520, 290)],
        ],
        "detour_routes": [],
        "sites": [
            (190, 295), (545, 165), (545, 355), (855, 275), (1120, 175), (1330, 185), (195, 600),
            (420, 565), (710, 585), (965, 575), (1075, 435), (1250, 740), (1375, 460),
        ],
        "site_traits": [
            "highground", "choke", "conduit", "conduit", "highground", "choke", "choke",
            "highground", "conduit", "highground", "conduit", "choke", "choke",
        ],
        "locked_sites": [5, 11],
        "blocked": [
            (0, 0, 260, 95),
            (1420, 0, 180, 150),
            (0, 815, 340, 85),
            (1380, 770, 220, 130),
        ],
        "palette": {
            "ground": (76, 72, 104),
            "meadow": (62, 58, 90),
            "road_border": (48, 44, 72),
            "road_fill": (122, 118, 146),
            "rift_fill": (132, 92, 168),
            "blocked_outer": (46, 30, 68),
            "blocked_inner": (22, 14, 38),
            "clearing": (90, 86, 118),
            "exit_pillar": (150, 220, 255),
        },
        "specials": {
            "void_rift": (695, 455),
            "rift_route": 3,
        },
    },
}

COAST_MONSTERS: List[Tuple[str, str, Path | None]] = [
    ("1. 鱼人猎手", "Murloc Hunter", NEW4_DIR / "鱼人猎手（前线敌人_大）.webp"),
    ("2. 海潮骑手", "Tide Rider (Shark mount)", NEW4_DIR / "海潮骑手（前线敌人_小）.png"),
    ("3. 水灵精", "Water Sprite (Elemental)", NEW4_DIR / "水灵精（联盟敌人_大）.webp"),
    ("4. 天雷雏龙", "Storm Wyrm (Flying)", None),  # Cropped from shot1
    ("5. 海潮战士", "Tide Warrior (Harpoon)", NEW4_DIR / "海潮战士（前线敌人_大）.webp"),
    ("6. 风校尉", "Wind Captain (Full-body)", NEW4_DIR / "风校尉（联盟敌人_小）.png"),
    ("7. 海螺法师", "Conch Mage (Shell wizard)", NEW4_DIR / "海螺法师（前线敌人_大）.webp"),
    ("8. 水长老", "Water Elder (Blue wizard)", NEW4_DIR / "水长老（联盟敌人_大）.webp"),
    ("9. 怒风怪", "Tempest Elemental", NEW4_DIR / "怒风怪（联盟敌人_大）.webp"),
    ("10. 蓝色风暴", "Bluegale (Storm shaman)", NEW4_DIR / "蓝色风暴（前线敌人_大）.webp"),
    ("11. 狂暴螃蟹", "Bloodshell Crab (Tank)", NEW4_DIR / "狂暴螃蟹（前线敌人_大）.webp"),
    ("12. 利维坦", "Leviathan (Kraken Boss)", NEW4_DIR / "利维坦（前线敌人_大）.webp"),
]

RUINS_MONSTERS: List[Tuple[str, str, Path]] = [
    ("1. 眼精", "Void Eyeling (Eye orb)", NEW3_DIR / "眼精（联盟敌人_大）.webp"),
    ("2. 虚空瞥视者", "Void Gazer (Flying bat)", NEW3_DIR / "虚空瞥视者（联盟敌人_大）.webp"),
    ("3. 暮光骚扰者", "Twilight Harasser", NEW3_DIR / "438px-暮光骚扰者（起源敌人_大）.webp"),
    ("4. 回魂割喉者", "Spectral Cutter (Rogue)", NEW3_DIR / "回魂割喉者（复仇敌人_大）.webp"),
    ("5. 暮光复仇者", "Twilight Avenger", NEW3_DIR / "438px-暮光复仇者（起源敌人_大）.webp"),
    ("6. 复仇骑兵", "Avenger Rider (Beetle)", NEW3_DIR / "复仇骑兵（起源敌人_大）.webp"),
    ("7. 剧毒喷吐者", "Venom Spitter (Toad)", NEW3_DIR / "438px-剧毒喷吐者（联盟敌人_大）.webp"),
    ("8. 还魂师", "Soul Reaver (Necromancer)", NEW3_DIR / "还魂师（复仇敌人_大）.webp"),
    ("9. 暮光傀儡", "Twilight Golem (Stone)", NEW3_DIR / "暮光傀儡（起源敌人_大）.webp"),
    ("10. 恶毒眼巢", "Vile Eyenest (Brood sac)", NEW3_DIR / "恶毒眼巢（联盟敌人_大）.webp"),
    ("11. 血壤巨兽", "Bloodsoil Behemoth", NEW3_DIR / "438px-血壤巨兽（联盟敌人_大）.webp"),
    ("12. 憎恶者巴杰尼蒙", "Baj'Nimen (Centipede Boss)", NEW3_DIR / "438px-憎恶者巴杰尼蒙（起源敌人_大）.webp"),
]


def _dist(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def sample_godot_curve(waypoints: List[Tuple[float, float]], steps_per_seg: int = 32) -> List[Tuple[float, float]]:
    """Replicate ArenaLevelCatalog.curve() 1:1 in Python."""
    n = len(waypoints)
    ins: List[Tuple[float, float]] = []
    outs: List[Tuple[float, float]] = []
    for idx in range(n):
        prev_p = waypoints[max(0, idx - 1)]
        next_p = waypoints[min(n - 1, idx + 1)]
        dx, dy = next_p[0] - prev_p[0], next_p[1] - prev_p[1]
        length = math.hypot(dx, dy)
        nx, ny = (dx / length, dy / length) if length > 1e-6 else (0.0, 0.0)
        mag = min(_dist(prev_p, waypoints[idx]), _dist(waypoints[idx], next_p)) * 0.23
        tx, ty = nx * mag, ny * mag
        ins.append((waypoints[idx][0] - tx, waypoints[idx][1] - ty))
        outs.append((waypoints[idx][0] + tx, waypoints[idx][1] + ty))

    pts: List[Tuple[float, float]] = []
    for i in range(n - 1):
        p0, c0, c1, p1 = waypoints[i], outs[i], ins[i + 1], waypoints[i + 1]
        end = steps_per_seg + (1 if i == n - 2 else 0)
        for s in range(end):
            t = s / steps_per_seg
            mt = 1.0 - t
            x = (mt ** 3) * p0[0] + 3 * (mt ** 2) * t * c0[0] + 3 * mt * (t ** 2) * c1[0] + (t ** 3) * p1[0]
            y = (mt ** 3) * p0[1] + 3 * (mt ** 2) * t * c0[1] + 3 * mt * (t ** 2) * c1[1] + (t ** 3) * p1[1]
            pts.append((x, y))
    return pts


def _pt_in_rect(pt: Tuple[float, float], rect: Tuple[int, int, int, int]) -> bool:
    rx, ry, rw, rh = rect
    return rx <= pt[0] <= rx + rw and ry <= pt[1] <= ry + rh


def validate_all_geometry() -> None:
    """Assert every site & road passes clearance, blocked, and HUD safe-zone constraints."""
    for name, cfg in MAPS.items():
        curves = [sample_godot_curve(r) for r in cfg["routes"] + cfg["detour_routes"]]
        all_road_pts = [p for c in curves for p in c]
        sites = cfg["sites"]
        blocked = cfg["blocked"]

        for idx, s in enumerate(sites):
            min_r = min(_dist(s, p) for p in all_road_pts)
            min_s = min(_dist(s, s2) for j, s2 in enumerate(sites) if j != idx)
            assert min_r >= 56.0, f"{name} site {idx} {s} too close to road: {min_r:.1f}px"
            assert min_s >= 110.0, f"{name} site {idx} {s} too close to sibling site: {min_s:.1f}px"
            assert s[1] >= 110, f"{name} site {idx} {s} overlaps top HUD"
            assert not _pt_in_rect(s, HUD_BOTTOM_LEFT), f"{name} site {idx} {s} overlaps bottom-left HUD"
            assert not _pt_in_rect(s, HUD_BOTTOM_RIGHT), f"{name} site {idx} {s} overlaps bottom-right HUD"
            for b in blocked:
                assert not _pt_in_rect(s, b), f"{name} site {idx} {s} inside blocked rect {b}"

        for ridx, r in enumerate(cfg["routes"]):
            for rp in sample_godot_curve(r):
                if 0 <= rp[0] <= MAP_W and 0 <= rp[1] <= MAP_H:
                    for b in blocked:
                        assert not _pt_in_rect(rp, b), f"{name} route {ridx} pt {rp} enters blocked {b}"


def _draw_thick_curve(draw: ImageDraw.ImageDraw, pts: List[Tuple[float, float]], width: int, fill: Tuple[int, int, int]) -> None:
    if len(pts) < 2:
        return
    draw.line(pts, fill=fill, width=width, joint="curve")
    r = width * 0.5
    for x, y in (pts[0], pts[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)
    for x, y in pts[1:-1:3]:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def _draw_organic_blocked(draw: ImageDraw.ImageDraw, rect: Tuple[int, int, int, int], outer: Tuple[int, int, int], inner: Tuple[int, int, int]) -> None:
    rx, ry, rw, rh = rect
    pad_x, pad_y = rw * 0.08, rh * 0.12
    draw.rounded_rectangle(
        (rx - pad_x * 0.4, ry - pad_y * 0.4, rx + rw + pad_x * 0.4, ry + rh + pad_y * 0.4),
        radius=int(min(rw, rh) * 0.42),
        fill=outer,
    )
    in_pad = min(rw, rh) * 0.14
    draw.rounded_rectangle(
        (rx + in_pad, ry + in_pad, rx + rw - in_pad, ry + rh - in_pad),
        radius=int(min(rw, rh) * 0.35),
        fill=inner,
    )


def _draw_entry_chevron(draw: ImageDraw.ImageDraw, p0: Tuple[float, float], p1: Tuple[float, float]) -> None:
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = max(1e-6, math.hypot(dx, dy))
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    cx = max(24.0, min(MAP_W - 24.0, p0[0] + ux * 46.0))
    cy = max(24.0, min(MAP_H - 24.0, p0[1] + uy * 46.0))
    tip = (cx + ux * 16.0, cy + uy * 16.0)
    left = (cx - ux * 10.0 + px * 11.0, cy - uy * 10.0 + py * 11.0)
    right = (cx - ux * 10.0 - px * 11.0, cy - uy * 10.0 - py * 11.0)
    draw.polygon([tip, left, right], fill=(242, 118, 86))


def render_blueprint(cfg: dict) -> Image.Image:
    pal = cfg["palette"]
    img = Image.new("RGB", (MAP_W, MAP_H), pal["ground"])
    draw = ImageDraw.Draw(img)

    # Organic low-contrast multi-lobe terrain contours (never rigid UI shapes)
    meadow_blobs = [
        (250, 230, 170, 95), (410, 290, 150, 80),
        (920, 440, 220, 125), (1080, 520, 190, 110),
        (590, 710, 180, 90), (740, 740, 150, 80),
    ]
    for gx, gy, grx, gry in meadow_blobs:
        draw.ellipse((gx - grx, gy - gry, gx + grx, gy + gry), fill=pal["meadow"])

    # Blocked water / cliff / chasm masses (organic shapes covering collision bounds)
    for b in cfg["blocked"]:
        _draw_organic_blocked(draw, b, pal["blocked_outer"], pal["blocked_inner"])

    specials = cfg.get("specials", {})

    # Optional Stage 5 chasm fissure tapering cleanly north and running off-screen south
    if "chasm_trench" in specials:
        tx0, ty0, tx1, ty1 = specials["chasm_trench"]
        draw.polygon(
            [(tx0 + 18, ty0), (tx1 - 18, ty0), (tx1 + 6, ty0 + 48), (tx1 + 8, ty1), (tx0 - 8, ty1), (tx0 - 6, ty0 + 48)],
            fill=pal["blocked_outer"],
        )
        draw.polygon(
            [(tx0 + 24, ty0 + 14), (tx1 - 24, ty0 + 14), (tx1 - 6, ty0 + 54), (tx1 - 4, ty1), (tx0 + 4, ty1), (tx0 + 6, ty0 + 54)],
            fill=pal["blocked_inner"],
        )

    # Draw detour routes first (so main road draws cleanly over junctions)
    for dr in cfg["detour_routes"]:
        pts = sample_godot_curve(dr)
        _draw_thick_curve(draw, pts, 66, pal["road_border"])
        _draw_thick_curve(draw, pts, 56, pal.get("detour_fill", pal["road_fill"]))

    # Draw primary roads (continuing cleanly off right-edge exits to x=1610, NO UI arrows inside clean blueprint)
    for idx, r in enumerate(cfg["routes"]):
        extended = list(r)
        if abs(extended[-1][0] - 1520) < 2:
            extended.append((1610, extended[-1][1]))
        pts = sample_godot_curve(extended)
        is_shoal = idx == specials.get("shoal_route", -1)
        is_rift = idx == specials.get("rift_route", -1)
        border_col = pal["road_border"]
        fill_col = pal["shoal_fill"] if is_shoal else (pal["rift_fill"] if is_rift else pal["road_fill"])
        _draw_thick_curve(draw, pts, 84, border_col)
        _draw_thick_curve(draw, pts, 72, fill_col)

    # Subtle flat clearing patches at buildable tower sites (no harsh borders or text)
    for sx, sy in cfg["sites"]:
        draw.ellipse((sx - 46, sy - 28, sx + 46, sy + 28), fill=pal["clearing"])

    # Stage 5 Drawbridge & Breach markers (non-textual natural environmental cues)
    if "drawbridge" in specials:
        bx, by = specials["drawbridge"]
        draw.rectangle((bx - 36, by - 36, bx + 36, by + 36), fill=(158, 122, 82), outline=(88, 62, 42), width=4)
        for plank_x in range(bx - 28, bx + 32, 14):
            draw.line((plank_x, by - 34, plank_x, by + 34), fill=(98, 70, 48), width=2)

    if "breach" in specials:
        rx, ry = specials["breach"]
        draw.rounded_rectangle((rx - 44, ry - 18, rx + 44, ry + 18), radius=8, fill=(116, 86, 118), outline=(74, 58, 86), width=4)

    # Stage 6 Mid-map Void Rift portal ring
    if "void_rift" in specials:
        vx, vy = specials["void_rift"]
        draw.ellipse((vx - 46, vy - 30, vx + 46, vy + 30), fill=(92, 42, 138), outline=(196, 128, 255), width=5)
        draw.ellipse((vx - 24, vy - 15, vx + 24, vy + 15), fill=(214, 152, 255))

    # Stage 4 Decorative Lighthouse silhouette on top-right headland
    if "lighthouse" in specials:
        lx, ly = specials["lighthouse"]
        draw.ellipse((lx - 42, ly + 8, lx + 42, ly + 42), fill=(84, 92, 88))
        draw.polygon([(lx - 18, ly + 26), (lx - 11, ly - 32), (lx + 11, ly - 32), (lx + 18, ly + 26)], fill=(218, 214, 202), outline=(56, 62, 72))
        draw.rectangle((lx - 13, ly - 48, lx + 13, ly - 30), fill=(246, 218, 122), outline=(56, 62, 72), width=3)

    # Subtle weathered stone side-threshold piers OUTSIDE the road curb (no painted UI circles)
    for ex, ey in cfg["exits"]:
        for py in (ey - 52, ey + 52):
            draw.rounded_rectangle((ex - 36, py - 10, ex - 14, py + 10), radius=4, fill=pal["road_border"])

    return img


def render_qa_sheet(blueprints: Dict[str, Image.Image], font: ImageFont.FreeTypeFont) -> Image.Image:
    quad_w, quad_h = 800, 450
    sheet = Image.new("RGB", (quad_w * 2, quad_h * 2), (18, 22, 30))
    order = ["saltport", "lighthouse", "ruins", "sanctum"]

    for q_idx, key in enumerate(order):
        cfg = MAPS[key]
        overlay = blueprints[key].copy().convert("RGBA")
        ov_draw = ImageDraw.Draw(overlay)

        # HUD safe zones (translucent cyan/red warning)
        ov_draw.rectangle((0, 0, MAP_W, HUD_TOP_Y), fill=(220, 60, 60, 55), outline=(255, 110, 110, 210), width=3)
        for hx, hy, hw, hh in (HUD_BOTTOM_LEFT, HUD_BOTTOM_RIGHT):
            ov_draw.rectangle((hx, hy, hx + hw, hy + hh), fill=(220, 60, 60, 55), outline=(255, 110, 110, 210), width=3)

        # Blocked rect bounds
        for bx, by, bw, bh in cfg["blocked"]:
            ov_draw.rectangle((bx, by, bx + bw, by + bh), outline=(90, 200, 255, 220), width=3)

        # Exact Curve2D centerlines + entry chevrons
        for dr in cfg["detour_routes"]:
            ov_draw.line(sample_godot_curve(dr), fill=(255, 196, 84, 210), width=3)
        for r in cfg["routes"]:
            ov_draw.line(sample_godot_curve(r), fill=(255, 255, 255, 220), width=3)
            if r[0][0] < 0 or r[0][1] < 0 or r[0][1] > MAP_H:
                _draw_entry_chevron(ov_draw, r[0], r[1])

        # Exit gate pillar indicators
        for ex, ey in cfg["exits"]:
            for py in (ey - 44, ey + 44):
                ov_draw.ellipse((ex - 36, py - 14, ex - 10, py + 12), fill=(96, 214, 255, 230), outline=(255, 255, 255, 255), width=2)

        # Site footprints + indices + locked markers
        locked_set = set(cfg["locked_sites"])
        for s_idx, (sx, sy) in enumerate(cfg["sites"]):
            trait = cfg["site_traits"][s_idx]
            col = (246, 200, 98) if trait == "highground" else ((238, 123, 86) if trait == "choke" else ((108, 232, 255) if trait == "conduit" else (240, 240, 210)))
            if s_idx in locked_set:
                col = (255, 90, 140)
            ov_draw.rectangle((sx - 48, sy - 24, sx + 48, sy + 24), outline=col + (245,), width=4)
            label = f"{s_idx}{'*' if s_idx in locked_set else ''}"
            ov_draw.text((sx - 10, sy - 12), label, fill=(10, 12, 18, 255), font=font)

        # Title badge
        ov_draw.rectangle((14, 14, 440, 56), fill=(12, 18, 28, 220), outline=(90, 180, 225, 255), width=2)
        ov_draw.text((24, 21), cfg["title"], fill=(240, 248, 255, 255), font=font)

        resized = overlay.convert("RGB").resize((quad_w, quad_h), Image.Resampling.LANCZOS)
        qx = (q_idx % 2) * quad_w
        qy = (q_idx // 2) * quad_h
        sheet.paste(resized, (qx, qy))

    return sheet


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in [
        r"C:\Windows\Fonts\msyhbd.ttc",
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
    ]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default()


def build_monster_collage(
    entries: List[Tuple[str, str, Path]],
    title: str,
    accent: Tuple[int, int, int],
    out_path: Path,
    font_title: ImageFont.FreeTypeFont,
    font_cn: ImageFont.FreeTypeFont,
    font_en: ImageFont.FreeTypeFont,
) -> None:
    cols, rows = 4, 3
    pad_x, pad_y = 22, 20
    header_h = 68
    card_w, card_h = 290, 296
    w = pad_x * 2 + cols * card_w + (cols - 1) * 18
    h = header_h + rows * card_h + (rows - 1) * 18 + pad_y

    canvas = Image.new("RGB", (w, h), (20, 27, 38))
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((0, 0, w, header_h - 8), fill=(13, 19, 28))
    draw.line((0, header_h - 8, w, header_h - 8), fill=accent, width=3)
    draw.text((pad_x, 14), title, fill=(238, 246, 255), font=font_title)

    img_box = 216
    for idx, (cn_name, en_name, img_path) in enumerate(entries):
        r, c = idx // cols, idx % cols
        x0 = pad_x + c * (card_w + 18)
        y0 = header_h + r * (card_h + 18)
        draw.rounded_rectangle((x0, y0, x0 + card_w, y0 + card_h), radius=10, fill=(30, 39, 54), outline=(72, 92, 118), width=2)

        src = Image.open(img_path).convert("RGBA")
        fitted = ImageOps.contain(src, (img_box, img_box), Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (img_box, img_box), (18, 24, 34, 255))
        fx = (img_box - fitted.width) // 2
        fy = (img_box - fitted.height) // 2
        frame.paste(fitted, (fx, fy), fitted)

        ix = x0 + (card_w - img_box) // 2
        iy = y0 + 12
        canvas.paste(frame.convert("RGB"), (ix, iy))
        draw.rectangle((ix - 1, iy - 1, ix + img_box, iy + img_box), outline=accent, width=2)

        draw.text((x0 + 16, iy + img_box + 8), cn_name, fill=(246, 232, 174), font=font_cn)
        draw.text((x0 + 16, iy + img_box + 38), en_name, fill=(168, 196, 222), font=font_en)

    canvas.save(out_path)


def crop_storm_wyrm(out_path: Path) -> Path:
    shot = Image.open(SHOT1_PATH).convert("RGB")
    cropped = shot.crop(STORM_WYRM_BOX)
    # Upscale 3x crisp so it reads cleanly alongside the 344px coastal refs in ref_coast_12
    up = cropped.resize((201, 201), Image.Resampling.NEAREST)
    up.save(out_path)
    return out_path


def write_drop_readme() -> None:
    RAW_DROP_DIR.mkdir(parents=True, exist_ok=True)
    text = (
        "v0.29 云端生图回收目录 (请保持以下精确文件名)\n"
        "==================================================\n\n"
        "[Batch A — 第一批共 9 张]\n"
        "1) 4 张 16:9 像素战斗地图:\n"
        "   - map_03_saltport.png\n"
        "   - map_04_lighthouse.png\n"
        "   - map_05_ruins.png\n"
        "   - map_06_sanctum.png\n\n"
        "2) 5 张 4:3 海岸深潮军团绿幕帧表与头像表:\n"
        "   - coast_sheet1.png\n"
        "   - coast_sheet2.png\n"
        "   - coast_miniboss_crab.png\n"
        "   - coast_boss_leviathan.png\n"
        "   - coast_portraits.png\n\n"
        "[Batch B — 第二批共 5 张]\n"
        "3) 5 张 4:3 紫雾星陨军团绿幕帧表与头像表:\n"
        "   - ruins_sheet1.png\n"
        "   - ruins_sheet2.png\n"
        "   - ruins_miniboss_behemoth.png\n"
        "   - ruins_boss_bajnimen.png\n"
        "   - ruins_portraits.png\n"
    )
    (RAW_DROP_DIR / "README.txt").write_text(text, encoding="utf-8")


def main() -> None:
    PREP_DIR.mkdir(parents=True, exist_ok=True)
    validate_all_geometry()

    font_qa = load_font(22)
    font_title = load_font(28)
    font_cn = load_font(21)
    font_en = load_font(14)

    blueprints: Dict[str, Image.Image] = {}
    for key, cfg in MAPS.items():
        bp = render_blueprint(cfg)
        bp.save(PREP_DIR / cfg["filename"])
        blueprints[key] = bp

    qa_sheet = render_qa_sheet(blueprints, font_qa)
    qa_sheet.save(PREP_DIR / "blueprint_QA_all4.png")

    wyrm_ref = crop_storm_wyrm(PREP_DIR / "storm_wyrm_ref.png")
    coast_entries = [
        (cn, en, wyrm_ref if p is None else p)
        for (cn, en, p) in COAST_MONSTERS
    ]
    build_monster_collage(
        coast_entries,
        "第二章 · 盐港深潮军团 (12 Monsters · Ref Board)",
        (86, 202, 238),
        PREP_DIR / "ref_coast_12.png",
        font_title,
        font_cn,
        font_en,
    )
    build_monster_collage(
        RUINS_MONSTERS,
        "第三章 · 紫雾星陨军团 (12 Monsters · Ref Board)",
        (188, 128, 255),
        PREP_DIR / "ref_ruins_12.png",
        font_title,
        font_cn,
        font_en,
    )

    layout_export = {
        k: {
            "order": v["order"],
            "exits": v["exits"],
            "hero_spawn": v["hero_spawn"],
            "routes": v["routes"],
            "detour_routes": v["detour_routes"],
            "sites": v["sites"],
            "site_traits": v["site_traits"],
            "locked_sites": v["locked_sites"],
            "blocked": v["blocked"],
            "specials": v["specials"],
        }
        for k, v in MAPS.items()
    }
    (PREP_DIR / "v029_maps_layout.json").write_text(
        json.dumps(layout_export, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_drop_readme()
    print(f"v0.29 Phase 1 prep complete: {PREP_DIR}")


if __name__ == "__main__":
    main()
