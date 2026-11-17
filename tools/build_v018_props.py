"""Generate painterly 2.5D sculpted stone tower plinths and ruins mechanisms for v0.18.

Matches the exact stone/moss/gold/lavender palette of assets/v09/map_forest.png and
assets/v017/map_ruins.png using 2x supersampled procedural stone relief + painterly grain.
"""
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "v018"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def _noise_field(w: int, h: int, seed: int = 42) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.normal(0.0, 1.0, (h // 4 + 2, w // 4 + 2)).astype(np.float32)
    img = Image.fromarray(((base * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8))
    img = img.resize((w, h), Image.Resampling.BICUBIC)
    fine = rng.normal(0.0, 0.35, (h, w)).astype(np.float32)
    return (np.array(img, dtype=np.float32) / 255.0 - 0.5) * 2.0 + fine


def _apply_stone_grain(canvas: Image.Image, seed: int, strength: float = 11.0) -> Image.Image:
    arr = np.array(canvas, dtype=np.float32)
    n = _noise_field(canvas.width, canvas.height, seed)
    alpha_mask = (arr[:, :, 3] > 12).astype(np.float32)
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c] + n * strength * alpha_mask, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def _draw_beveled_ellipse(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float,
                          thickness: float, top_col, side_col, rim_col, shadow_col=None):
    if shadow_col is not None:
        draw.ellipse([cx - rx * 1.08, cy - ry * 0.95 + thickness * 0.85,
                      cx + rx * 1.08, cy + ry * 1.15 + thickness * 1.25], fill=shadow_col)
    # 3D extruded side wall
    for step in range(int(thickness), 0, -1):
        t = step / max(1.0, thickness)
        col = tuple(int(side_col[i] * (0.72 + 0.28 * (1.0 - t))) for i in range(3)) + (255,)
        draw.ellipse([cx - rx, cy - ry + step, cx + rx, cy + ry + step], fill=col)
    # Top face
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=top_col, outline=rim_col, width=4)


def _draw_stone_blocks_ring(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float,
                            count: int, col_a, col_b, seam_col, seed: int = 0):
    for i in range(count):
        a0 = (i / count) * math.tau + 0.12
        a1 = ((i + 0.88) / count) * math.tau + 0.12
        am = 0.5 * (a0 + a1)
        col = col_a if (i + seed) % 2 == 0 else col_b
        pts = []
        for a in np.linspace(a0, a1, 5):
            pts.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry))
        for a in np.linspace(a1, a0, 5):
            pts.append((cx + math.cos(a) * (rx * 0.72), cy + math.sin(a) * (ry * 0.72)))
        draw.polygon(pts, fill=col, outline=seam_col)
        # Subtle highlight on sun-facing upper-left arc
        if math.cos(am - 2.2) > 0.15:
            hx0, hy0 = cx + math.cos(a0) * (rx * 0.94), cy + math.sin(a0) * (ry * 0.94)
            hx1, hy1 = cx + math.cos(a1) * (rx * 0.94), cy + math.sin(a1) * (ry * 0.94)
            draw.line([hx0, hy0, hx1, hy1], fill=(248, 240, 222, 165), width=2)


def _draw_hammer_emblem(draw: ImageDraw.ImageDraw, cx: float, cy: float, col_main, col_hi, col_dark):
    # Subtle carved relief of a builder's warhammer / anvil icon in the stone center
    draw.polygon([(cx - 5, cy + 16), (cx + 5, cy + 16), (cx + 4, cy - 6), (cx - 4, cy - 6)],
                 fill=col_dark, outline=col_hi)
    draw.polygon([(cx - 22, cy - 14), (cx + 22, cy - 14), (cx + 26, cy - 3), (cx - 26, cy - 3)],
                 fill=col_main, outline=col_hi)
    draw.line([(cx - 20, cy - 11), (cx + 20, cy - 11)], fill=col_hi, width=2)


def build_site_plinths():
    cell = 512  # 2x SSAA -> downsampled to 256x256
    sheet = Image.new("RGBA", (256 * 5, 256), (0, 0, 0, 0))

    for idx in range(5):
        tile = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        d = ImageDraw.Draw(tile)
        cx, cy = cell * 0.5, cell * 0.54
        rx, ry = 188.0, 96.0

        if idx == 0:
            # [0] Woodland / Creek Mossy Warm Sandstone Plinth
            _draw_beveled_ellipse(d, cx, cy, rx, ry, 24,
                                  top_col=(186, 164, 126, 255),
                                  side_col=(118, 98, 70, 255),
                                  rim_col=(224, 202, 158, 255),
                                  shadow_col=(18, 28, 14, 115))
            _draw_stone_blocks_ring(d, cx, cy, rx * 0.94, ry * 0.92, 12,
                                    (176, 154, 116, 255), (162, 140, 104, 255), (96, 78, 54, 220), seed=1)
            d.ellipse([cx - rx * 0.64, cy - ry * 0.62, cx + rx * 0.64, cy + ry * 0.62],
                      fill=(146, 126, 92, 255), outline=(216, 194, 146, 255), width=3)
            # Moss tufts on rim
            for ma, mr in [(0.6, 0.92), (2.4, 0.95), (3.8, 0.90), (5.3, 0.93)]:
                mx, my = cx + math.cos(ma) * rx * mr, cy + math.sin(ma) * ry * mr
                d.ellipse([mx - 22, my - 11, mx + 22, my + 11], fill=(106, 144, 68, 230))
                d.ellipse([mx - 14, my - 7, mx + 16, my + 7], fill=(138, 174, 86, 235))
            _draw_hammer_emblem(d, cx, cy - 2, (218, 182, 108, 255), (250, 226, 162, 255), (108, 84, 48, 255))

        elif idx == 1:
            # [1] Ruins Highground — Pale Ruin Marble + Golden Crenellations & Winged Chevron
            _draw_beveled_ellipse(d, cx, cy, rx, ry, 28,
                                  top_col=(172, 166, 178, 255),
                                  side_col=(104, 98, 116, 255),
                                  rim_col=(228, 212, 176, 255),
                                  shadow_col=(20, 18, 30, 128))
            _draw_stone_blocks_ring(d, cx, cy, rx * 0.94, ry * 0.92, 12,
                                    (168, 162, 176, 255), (154, 148, 164, 255), (88, 82, 102, 225), seed=2)
            d.ellipse([cx - rx * 0.65, cy - ry * 0.63, cx + rx * 0.65, cy + ry * 0.63],
                      fill=(136, 130, 148, 255), outline=(232, 198, 118, 255), width=4)
            # 4 Golden Battlement Turrets on diagonal corners
            for ang in [0.65, 2.49, 3.79, 5.63]:
                bx, by = cx + math.cos(ang) * rx * 0.88, cy + math.sin(ang) * ry * 0.88
                d.polygon([(bx - 20, by + 6), (bx - 16, by - 14), (bx + 16, by - 14), (bx + 20, by + 6)],
                          fill=(218, 178, 92, 255), outline=(92, 68, 32, 255))
                d.line([(bx - 13, by - 10), (bx + 13, cy if False else by - 10)], fill=(255, 236, 172, 255), width=3)
            # Winged Highground Sightline Emblem in center
            d.polygon([(cx, cy - 26), (cx + 38, cy + 4), (cx + 22, cy + 12), (cx, cy - 8),
                       (cx - 22, cy + 12), (cx - 38, cy + 4)],
                      fill=(236, 196, 102, 255), outline=(255, 240, 188, 255))
            d.polygon([(cx, cy - 8), (cx + 18, cy + 16), (cx, cy + 26), (cx - 18, cy + 16)],
                      fill=(204, 158, 74, 255), outline=(255, 236, 176, 255))

        elif idx == 2:
            # [2] Ruins Choke — Heavy Forged Iron & Warm Amber-Bronze Bastion Plinth
            _draw_beveled_ellipse(d, cx, cy, rx, ry, 26,
                                  top_col=(158, 150, 162, 255),
                                  side_col=(92, 86, 102, 255),
                                  rim_col=(214, 154, 112, 255),
                                  shadow_col=(20, 18, 30, 128))
            _draw_stone_blocks_ring(d, cx, cy, rx * 0.94, ry * 0.92, 10,
                                    (152, 144, 158, 255), (138, 130, 146, 255), (76, 70, 86, 230), seed=3)
            d.ellipse([cx - rx * 0.65, cy - ry * 0.63, cx + rx * 0.65, cy + ry * 0.63],
                      fill=(118, 110, 126, 255), outline=(228, 142, 96, 255), width=4)
            # 6 Heavy Iron & Copper Rivet Shields around rim
            for i in range(6):
                ang = i * math.tau / 6.0
                bx, by = cx + math.cos(ang) * rx * 0.86, cy + math.sin(ang) * ry * 0.86
                d.polygon([(bx, by - 14), (bx + 15, by), (bx, by + 14), (bx - 15, by)],
                          fill=(216, 128, 86, 255), outline=(64, 46, 44, 255))
                d.ellipse([bx - 5, by - 5, bx + 5, by + 5], fill=(252, 210, 168, 255))
            # Center Bastion Shield Crest
            d.polygon([(cx, cy - 26), (cx + 28, cy - 14), (cx + 22, cy + 16), (cx, cy + 28),
                       (cx - 22, cy + 16), (cx - 28, cy - 14)],
                      fill=(212, 124, 84, 255), outline=(252, 212, 174, 255))
            d.line([(cx - 14, cy - 4), (cx + 14, cy - 4)], fill=(255, 232, 198, 255), width=4)
            d.line([(cx, cy - 16), (cx, cy + 16)], fill=(255, 232, 198, 255), width=4)

        elif idx == 3:
            # [3] Ruins Conduit — Arcane Leyline Astrolabe Plinth (Cyan-Violet Inlaid Rings)
            _draw_beveled_ellipse(d, cx, cy, rx, ry, 26,
                                  top_col=(160, 158, 178, 255),
                                  side_col=(96, 92, 118, 255),
                                  rim_col=(142, 224, 250, 255),
                                  shadow_col=(18, 20, 36, 128))
            _draw_stone_blocks_ring(d, cx, cy, rx * 0.94, ry * 0.92, 12,
                                    (154, 152, 174, 255), (140, 138, 162, 255), (78, 76, 104, 225), seed=4)
            # Glowing recessed astrolabe channels
            d.ellipse([cx - rx * 0.72, cy - ry * 0.70, cx + rx * 0.72, cy + ry * 0.70],
                      fill=(88, 92, 126, 255), outline=(120, 232, 255, 255), width=5)
            d.ellipse([cx - rx * 0.48, cy - ry * 0.46, cx + rx * 0.48, cy + ry * 0.46],
                      fill=(112, 108, 146, 255), outline=(196, 156, 255, 255), width=4)
            for i in range(4):
                ang = i * math.pi * 0.5 + math.pi * 0.25
                gx, gy = cx + math.cos(ang) * rx * 0.72, cy + math.sin(ang) * ry * 0.70
                d.polygon([(gx, gy - 12), (gx + 12, gy), (gx, gy + 12), (gx - 12, gy)],
                          fill=(124, 238, 255, 255), outline=(255, 255, 255, 255))
            # Center 8-point astral star
            d.polygon([(cx, cy - 24), (cx + 9, cy - 7), (cx + 28, cy), (cx + 9, cy + 7),
                       (cx, cy + 24), (cx - 9, cy + 7), (cx - 28, cy), (cx - 9, cy - 7)],
                      fill=(136, 236, 255, 255), outline=(240, 252, 255, 255))

        else:
            # [4] Locked Seal Overlay — Heavy Chains & Ornate Bronze Padlock
            d.ellipse([cx - rx * 0.78, cy - ry * 0.76, cx + rx * 0.78, cy + ry * 0.76],
                      fill=(28, 24, 38, 168), outline=(188, 162, 108, 235), width=5)
            # Crossed heavy iron-gold chains
            for sx in [-1.0, 1.0]:
                for t in np.linspace(-0.68, 0.68, 9):
                    lx = cx + t * rx * 0.85
                    ly = cy + sx * t * ry * 0.78
                    d.rounded_rectangle([lx - 14, ly - 8, lx + 14, ly + 8], radius=5,
                                        fill=(112, 106, 118, 255), outline=(212, 188, 134, 255), width=3)
            # Ornate Padlock body
            d.arc([cx - 24, cy - 42, cx + 24, cy + 2], start=180, end=360, fill=(228, 198, 128, 255), width=9)
            d.rounded_rectangle([cx - 32, cy - 14, cx + 32, cy + 34], radius=8,
                                fill=(196, 158, 86, 255), outline=(252, 232, 174, 255), width=4)
            d.ellipse([cx - 7, cy + 2, cx + 7, cy + 16], fill=(54, 42, 28, 255))
            d.polygon([(cx - 4, cy + 12), (cx + 4, cy + 12), (cx + 6, cy + 26), (cx - 6, cy + 26)],
                      fill=(54, 42, 28, 255))

        tile = _apply_stone_grain(tile, seed=100 + idx, strength=9.5)
        tile = tile.resize((256, 256), Image.Resampling.LANCZOS)
        sheet.paste(tile, (idx * 256, 0))

    sheet.save(OUT_DIR / "site_plinths.png")
    print("Saved:", OUT_DIR / "site_plinths.png", sheet.size)


def build_ruins_mechanisms():
    cell = 512  # 2x SSAA -> downsampled to 256x256
    sheet = Image.new("RGBA", (256 * 3, 256), (0, 0, 0, 0))

    # [0] Breach Barricade: Collapsed Ruin Stone Archway, Fallen Fluted Column & Glowing Fracture Rubble
    t0 = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(t0)
    cx, cy = 256, 280
    d0.ellipse([cx - 210, cy - 68, cx + 210, cy + 88], fill=(22, 18, 32, 138))
    # Glowing amber/violet leyline cracks underneath rubble
    for pts in [[(110, 290), (195, 260), (260, 282), (345, 252), (400, 285)],
                [(155, 315), (245, 292), (330, 318)]]:
        d0.line(pts, fill=(246, 182, 92, 220), width=10)
        d0.line(pts, fill=(255, 240, 188, 255), width=4)
    # irregular carved ancient limestone boulders & broken column drums (NO grid rectangles!)
    boulders = [
        ([(86, 296), (118, 228), (192, 218), (222, 276), (188, 316), (104, 318)], (156, 150, 164, 255), (206, 198, 208, 255)),
        ([(286, 304), (312, 222), (398, 232), (426, 292), (388, 326), (302, 322)], (148, 142, 158, 255), (198, 190, 202, 255)),
        ([(172, 268), (214, 186), (304, 192), (332, 264), (288, 302), (196, 298)], (172, 166, 180, 255), (222, 214, 220, 255)),
        ([(128, 332), (162, 278), (248, 274), (274, 328), (222, 354), (144, 350)], (142, 136, 152, 255), (192, 184, 196, 255)),
        ([(246, 336), (278, 282), (362, 286), (382, 338), (332, 360), (260, 356)], (162, 156, 170, 255), (212, 204, 214, 255)),
    ]
    for poly, body_col, top_col in boulders:
        # Shadow base
        s_poly = [(x + 4, y + 12) for x, y in poly]
        d0.polygon(s_poly, fill=(44, 40, 56, 195))
        d0.polygon(poly, fill=body_col, outline=(72, 66, 86, 255))
        # Upper-left sunlit facet
        facet = [(x, y) for x, y in poly[:4]] + [(
            sum(x for x, _ in poly) / len(poly),
            sum(y for _, y in poly) / len(poly)
        )]
        d0.polygon(facet, fill=top_col)
    # Engraved golden astrolabe ring fragment embedded in center stone
    d0.arc([196, 212, 316, 312], start=200, end=350, fill=(224, 184, 102, 255), width=7)
    # Lavender moss tufts matching map_ruins flora
    for mx, my in [(116, 312), (382, 316), (208, 344), (312, 216)]:
        d0.ellipse([mx - 18, my - 9, mx + 18, my + 9], fill=(156, 122, 184, 225))
        d0.ellipse([mx - 10, my - 6, mx + 12, my + 6], fill=(192, 158, 218, 235))
    t0 = _apply_stone_grain(t0, seed=201, strength=10.5).resize((256, 256), Image.Resampling.LANCZOS)
    sheet.paste(t0, (0, 0))

    # [1] Drawbridge Lowered & [2] Drawbridge Raised
    for state_idx in [1, 2]:
        raised = (state_idx == 2)
        t1 = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        d1 = ImageDraw.Draw(t1)
        # Water channel shadow under bridge
        d1.rounded_rectangle([112, 148, 400, 368], radius=28, fill=(28, 58, 82, 190))
        for wy in range(168, 352, 28):
            d1.arc([132, wy - 10, 380, wy + 18], start=10, end=170, fill=(138, 212, 238, 130), width=4)

        if not raised:
            # Carved stone-and-bronze bridge deck flush with road
            d1.rounded_rectangle([96, 166, 416, 346], radius=16,
                                 fill=(178, 168, 156, 255), outline=(82, 76, 92, 255), width=5)
            # Arched stone slabs across deck
            for i in range(6):
                x0 = 114 + i * 48
                col = (192, 182, 168, 255) if i % 2 == 0 else (174, 164, 152, 255)
                d1.rectangle([x0, 178, x0 + 44, 334], fill=col, outline=(108, 100, 112, 230), width=2)
                d1.line([(x0 + 4, 182), (x0 + 40, 182)], fill=(232, 224, 210, 220), width=3)
            # Bronze astrolabe trim rails top & bottom
            for ry_bar in [168, 332]:
                d1.rectangle([92, ry_bar, 420, ry_bar + 14], fill=(196, 158, 92, 255), outline=(88, 66, 38, 255), width=2)
        else:
            # Raised leaf decks on left & right + glowing cyan rune barrier across chasm
            for side in [-1, 1]:
                bx0 = 92 if side < 0 else 336
                d1.rounded_rectangle([bx0, 142, bx0 + 84, 344], radius=10,
                                     fill=(152, 144, 156, 255), outline=(74, 68, 86, 255), width=4)
                d1.rectangle([bx0 + 10, 154, bx0 + 74, 330], fill=(186, 150, 88, 255), outline=(92, 70, 40, 255), width=2)
            # Glowing Arcane Forcefield Barrier across open water gap
            for gx in range(192, 328, 26):
                d1.line([(gx, 162), (gx, 348)], fill=(112, 232, 255, 225), width=8)
                d1.line([(gx, 162), (gx, 348)], fill=(232, 252, 255, 255), width=3)
            for gy in [196, 256, 316]:
                d1.line([(176, gy), (336, gy)], fill=(138, 238, 255, 215), width=6)

        # Heavy Carved Stone Bridge Abutment Pillars (4 corners)
        for px in [86, 402]:
            for py in [156, 336]:
                d1.ellipse([px - 28, py - 22, px + 28, py + 26], fill=(32, 28, 44, 160))
                d1.rounded_rectangle([px - 24, py - 24, px + 24, py + 20], radius=8,
                                     fill=(166, 160, 174, 255), outline=(76, 70, 88, 255), width=3)
                d1.ellipse([px - 10, py - 12, px + 10, py + 8],
                           fill=(124, 234, 255, 255) if raised else (218, 178, 96, 255))

        t1 = _apply_stone_grain(t1, seed=210 + state_idx, strength=9.0).resize((256, 256), Image.Resampling.LANCZOS)
        sheet.paste(t1, (state_idx * 256, 0))

    sheet.save(OUT_DIR / "ruins_mechanisms.png")
    print("Saved:", OUT_DIR / "ruins_mechanisms.png", sheet.size)


if __name__ == "__main__":
    build_site_plinths()
    build_ruins_mechanisms()
