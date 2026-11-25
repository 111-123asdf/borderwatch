import math
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

PROJECT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT.parent / "美术参考" / "v027_ui_raw"
OUT_DIR = PROJECT / "assets" / "ui_v027"
TOWERS_DIR = PROJECT / "assets" / "towers_v024"


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


def _erode(mask: np.ndarray, iters: int = 1) -> np.ndarray:
    return ~_dilate(~mask, iters)


def _lerp_color(c0: tuple[int, int, int], c1: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(round(c0[0] + (c1[0] - c0[0]) * t)),
        int(round(c0[1] + (c1[1] - c0[1]) * t)),
        int(round(c0[2] + (c1[2] - c0[2]) * t)),
    )


def build_title_bg() -> None:
    im = Image.open(RAW_DIR / "01_title_bg.jpg").convert("RGBA")
    im = im.resize((1600, 900), Image.Resampling.LANCZOS)
    im = ImageEnhance.Sharpness(im).enhance(1.12)
    arr = np.array(im, dtype=np.float32)

    # Top-center subtle twilight darkening so the Logo pops effortlessly without muting side mountains
    y = np.linspace(0.0, 1.0, 900)[:, None]
    x = np.linspace(-1.0, 1.0, 1600)[None, :]
    top_weight = np.clip((0.26 - y) / 0.26, 0.0, 1.0) ** 1.35 * np.clip(1.0 - 0.45 * x * x, 0.45, 1.0)
    bot_weight = np.clip((y - 0.78) / 0.22, 0.0, 1.0) ** 1.25

    vignette = np.clip(top_weight * 0.24 + bot_weight * 0.46, 0.0, 0.55)
    target = np.array([7.0, 14.0, 22.0, 255.0], dtype=np.float32)
    arr[:, :, :3] = arr[:, :, :3] * (1.0 - vignette[:, :, None]) + target[:3] * vignette[:, :, None]
    arr[:, :, 3] = 255.0
    Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(OUT_DIR / "title_bg.png")


def build_title_logo() -> None:
    im = Image.open(RAW_DIR / "02_title_logo.jpg").convert("RGBA")
    arr = np.array(im)
    h, w, _ = arr.shape
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)

    # Strict neon chroma-green mask: NEVER touches the dark olive-pine emblem banner (where G-maxRB <= 40)
    cand = (g > 142) & ((g - np.maximum(r, b)) > 52)
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

    # Clear genuine interior neon-green cutouts (inside character enclosed loops / sword cross gaps)
    # Using strict neon thresholds verified against center pine banner (0 neon pixels inside banner)
    strict_holes = (g > 175) & ((g - np.maximum(r, b)) > 88) & (~bg)
    visited = np.zeros((h, w), dtype=bool)
    ys, xs = np.where(strict_holes)
    for sy, sx in zip(ys, xs):
        if visited[sy, sx]:
            continue
        comp = []
        cq = deque([(int(sy), int(sx))])
        visited[sy, sx] = True
        while cq:
            cy, cx = cq.popleft()
            comp.append((cy, cx))
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and strict_holes[ny, nx]:
                    visited[ny, nx] = True
                    cq.append((ny, nx))
        if len(comp) >= 8:
            for cy, cx in comp:
                bg[cy, cx] = True

    # Expand 1px into bright-green anti-aliased fringe adjacent to removed bg
    edge1 = _dilate(bg, 1) & (~bg)
    fringe = edge1 & (g > 112) & ((g - np.maximum(r, b)) > 40)
    bg |= fringe

    arr[bg, 3] = 0

    # Taper alpha smoothly on immediate bright-green edge pixels and run despill ONLY on edge2
    edge_soft = _dilate(bg, 1) & (~bg)
    soft_green = edge_soft & (g > np.maximum(r, b) + 18) & (g > 72)
    arr[soft_green, 3] = 165

    edge2 = _dilate(bg, 2) & (~bg)
    sp = edge2 & (g > np.maximum(r, b) + 6)
    max_rb = np.maximum(r[sp], b[sp])
    arr[sp, 1] = np.minimum(arr[sp, 1], np.clip(max_rb + 4, 0, 255)).astype(np.uint8)

    # Tight crop with clean 10px margin
    oys, oxs = np.where(arr[:, :, 3] > 20)
    x0 = max(0, int(oxs.min()) - 10)
    y0 = max(0, int(oys.min()) - 10)
    x1 = min(w, int(oxs.max()) + 11)
    y1 = min(h, int(oys.max()) + 11)
    cropped = Image.fromarray(arr[y0:y1, x0:x1], "RGBA")
    # Crisp 0.92 Lanczos scale to target display clarity ~840px wide
    tw = 820
    th = max(1, int(round(cropped.height * tw / cropped.width)))
    out = cropped.resize((tw, th), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "title_logo.png")


def build_world_map() -> None:
    im = Image.open(RAW_DIR / "03_world_map.jpg").convert("RGBA")
    im = im.resize((1600, 900), Image.Resampling.LANCZOS)
    im = ImageEnhance.Sharpness(im).enhance(1.10)
    arr = np.array(im, dtype=np.float32)

    yy, xx = np.mgrid[0:900, 0:1600].astype(np.float32)
    # Subtle localized vignette only at UI corners (top-left wallet/back, top-right settings, bottom rim)
    tl = np.exp(-((xx / 360.0) ** 2 + (yy / 105.0) ** 2)) * 0.30
    tr = np.exp(-(((1600.0 - xx) / 180.0) ** 2 + (yy / 105.0) ** 2)) * 0.28
    bot = np.clip((yy - 770.0) / 130.0, 0.0, 1.0) ** 1.35 * 0.36
    vignette = np.clip(tl + tr + bot, 0.0, 0.42)

    target = np.array([8.0, 16.0, 26.0], dtype=np.float32)
    arr[:, :, :3] = arr[:, :, :3] * (1.0 - vignette[:, :, None]) + target[None, None, :] * vignette[:, :, None]
    arr[:, :, 3] = 255.0
    Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(OUT_DIR / "world_map.png")


def build_hero_cards() -> None:
    heroes = {
        "lord": "04_hero_lord.jpg",
        "druid": "05_hero_druid.jpg",
        "healer": "06_hero_healer.jpg",
        "werewolf": "07_hero_werewolf.jpg",
        "gunner": "08_hero_gunner.jpg",
    }
    w, h = 360, 540
    y = np.linspace(0.0, 1.0, h)[:, None]
    bot_fade = np.clip((y - 0.81) / 0.19, 0.0, 1.0) ** 1.2 * 0.56
    target = np.array([8.0, 17.0, 26.0], dtype=np.float32)

    for hid, fname in heroes.items():
        im = Image.open(RAW_DIR / fname).convert("RGBA")
        # Exact center crop to 2:3 if 682x1024 -> 682x1023
        cw, ch = im.size
        target_h = int(round(cw * 1.5))
        if target_h < ch:
            top = (ch - target_h) // 2
            im = im.crop((0, top, cw, top + target_h))
        im = im.resize((w, h), Image.Resampling.LANCZOS)
        im = ImageEnhance.Sharpness(im).enhance(1.08)
        arr = np.array(im, dtype=np.float32)
        arr[:, :, :3] = arr[:, :, :3] * (1.0 - bot_fade[:, :, None]) + target[None, None, :] * bot_fade[:, :, None]
        arr[:, :, 3] = 255.0
        Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(OUT_DIR / f"hero_card_{hid}.png")


def build_hall_bg() -> None:
    # Draw on 800x450 pixel canvas and upscale 2x NEAREST -> authentic crisp pixel-art atmosphere (KR5 calm slate-blue)
    w, h = 800, 450
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    t = yy / float(h - 1)
    top_c = np.array([34.0, 78.0, 106.0])
    mid_c = np.array([21.0, 52.0, 74.0])
    bot_c = np.array([11.0, 25.0, 38.0])

    grad = np.where(
        t[:, :, None] < 0.52,
        top_c * (1.0 - (t[:, :, None] / 0.52)) + mid_c * (t[:, :, None] / 0.52),
        mid_c * (1.0 - ((t[:, :, None] - 0.52) / 0.48)) + bot_c * ((t[:, :, None] - 0.52) / 0.48),
    )

    # Subtle spotlight halo around center hero/tower showcase x=285, y=205
    spot = np.exp(-(((xx - 290.0) / 210.0) ** 2 + ((yy - 195.0) / 145.0) ** 2)) * 22.0
    grad[:, :, 0] += spot * 0.55
    grad[:, :, 1] += spot * 0.90
    grad[:, :, 2] += spot * 1.10

    # Gentle outer framing vignette
    nx = (xx / w - 0.5) * 2.0
    ny = (yy / h - 0.5) * 2.0
    vig = np.clip((nx * nx * 0.55 + ny * ny * 0.65 - 0.25) * 0.48, 0.0, 0.52)
    grad *= (1.0 - vig[:, :, None])

    # Crisp 4x4 ordered Bayer pixel dither to keep genuine indie pixel craft without smooth banding
    bayer = (np.array([
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5],
    ], dtype=np.float32) / 16.0 - 0.5) * 4.5
    grad += np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w, None]

    # Quantize slightly to calm pixel steps before drawing foreground silhouettes
    arr = np.round(grad.clip(6, 255) / 2.0) * 2.0
    img = Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")
    draw = ImageDraw.Draw(img)

    # Far layered mountain silhouette (#102838)
    m_pts = [(0, h), (0, 322), (48, 294), (108, 315), (174, 272), (242, 306), (318, 286),
             (390, 318), (470, 278), (546, 312), (620, 274), (692, 304), (754, 284), (800, 314), (800, h)]
    draw.polygon(m_pts, fill=_hex("0e2334"))

    # Closer pine/hill ridge silhouette (#0a1a27)
    r_pts = [(0, h), (0, 358), (64, 342), (132, 355), (210, 336), (310, 360), (418, 344),
             (510, 364), (602, 338), (698, 356), (768, 340), (800, 352), (800, h)]
    draw.polygon(r_pts, fill=_hex("0a1a27"))

    # Distant quiet frontier battlements & war-banner poles along horizon (#06101a)
    battlement = _hex("06101a")
    draw.rectangle((0, 384, w, h), fill=battlement)
    # Crenelated stone parapet teeth across left and right wings (center kept lower so card shines)
    for bx in list(range(14, 190, 22)) + list(range(585, 790, 22)):
        draw.rectangle((bx, 372, bx + 13, 386), fill=battlement)
    # Left watchtower silhouette
    draw.rectangle((18, 318, 62, 386), fill=battlement)
    draw.polygon([(12, 318), (40, 286), (68, 318)], fill=battlement)
    draw.line([(40, 286), (40, 260)], fill=battlement, width=2)
    draw.polygon([(40, 262), (64, 267), (56, 276), (40, 274)], fill=battlement)
    # Right citadel turret & spear banners
    draw.rectangle((724, 310, 774, 386), fill=battlement)
    for tx in range(720, 778, 12):
        draw.rectangle((tx, 300, tx + 7, 312), fill=battlement)
    for px, ph in [(104, 62), (128, 48), (668, 56), (694, 44)]:
        draw.line([(px, 384), (px, 384 - ph)], fill=battlement, width=2)
        draw.polygon([(px, 384 - ph + 2), (px + 18, 384 - ph + 7), (px + 11, 384 - ph + 15), (px, 384 - ph + 13)], fill=battlement)

    # Subtle drifting atmospheric mist flecks in pixel grid
    rng = np.random.default_rng(27)
    for _ in range(38):
        fx = int(rng.integers(24, w - 24))
        fy = int(rng.integers(48, 355))
        fa = int(rng.integers(22, 54))
        col = (145, 205, 232, fa) if rng.random() > 0.25 else (235, 198, 118, fa)
        img.putpixel((fx, fy), col)

    img.resize((1600, 900), Image.Resampling.NEAREST).save(OUT_DIR / "hall_bg.png")


def _draw_chamfer_rect(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, c: int, fill, outline=None) -> None:
    pts = [
        (x0 + c, y0), (x1 - c, y0),
        (x1, y0 + c), (x1, y1 - c),
        (x1 - c, y1), (x0 + c, y1),
        (x0, y1 - c), (x0, y0 + c),
    ]
    draw.polygon(pts, fill=fill, outline=outline)


def _put_rivet(img: Image.Image, x: int, y: int, hi=_hex("a6c3d6"), lo=_hex("243745")) -> None:
    for dy in range(4):
        for dx in range(4):
            if (dx in (0, 3) and dy in (0, 3)):
                continue
            col = hi if (dx <= 1 and dy <= 1) else (_hex("648399") if (dx + dy) <= 3 else lo)
            img.putpixel((x + dx, y + dy), col)


def build_panels_and_frames() -> None:
    # 1. panel_obsidian.png (128x128 9-slice)
    s = 128
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Dark outer outline + steel body + top specular bevel + dark obsidian inner cavity
    _draw_chamfer_rect(d, 0, 0, s - 1, s - 1, 7, _hex("050b10", 248))
    _draw_chamfer_rect(d, 2, 2, s - 3, s - 3, 6, _hex("4f6c80", 252))
    # Top bright bevel highlight & bottom steel shadow rim
    d.line([(9, 2), (s - 10, 2)], fill=_hex("8fb0c7"))
    d.line([(8, 3), (s - 9, 3)], fill=_hex("7191a8"))
    d.line([(9, s - 3), (s - 10, s - 3)], fill=_hex("243644"))
    d.line([(8, s - 4), (s - 9, s - 4)], fill=_hex("324859"))
    # Obsidian interior fill with subtle vertical shading
    _draw_chamfer_rect(d, 7, 7, s - 8, s - 8, 4, _hex("0c1924", 240))
    _draw_chamfer_rect(d, 8, 8, s - 9, s - 9, 3, None, outline=_hex("1d3242", 210))
    # Corner rivets cleanly inside 18px 9-slice corner budget
    for rx, ry in [(10, 10), (s - 14, 10), (10, s - 14), (s - 14, s - 14)]:
        _put_rivet(im, rx, ry)
    im.save(OUT_DIR / "panel_obsidian.png")

    # 2. panel_inset_dark.png (96x96 9-slice)
    s = 96
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    _draw_chamfer_rect(d, 0, 0, s - 1, s - 1, 4, _hex("1d3242", 240))
    _draw_chamfer_rect(d, 2, 2, s - 3, s - 3, 3, _hex("060e15", 238))
    d.line([(6, 2), (s - 7, 2)], fill=_hex("03080d"))
    d.line([(6, s - 3), (s - 7, s - 3)], fill=_hex("294559"))
    im.save(OUT_DIR / "panel_inset_dark.png")

    # 3. rail_steel.png (128x96 9-slice top bar cradle)
    w, h = 128, 96
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    _draw_chamfer_rect(d, 0, 0, w - 1, h - 1, 7, _hex("050b10", 248))
    _draw_chamfer_rect(d, 2, 2, w - 3, h - 3, 6, _hex("486377", 250))
    d.line([(9, 2), (w - 10, 2)], fill=_hex("87a8be"))
    d.line([(9, h - 3), (w - 10, h - 3)], fill=_hex("233442"))
    _draw_chamfer_rect(d, 6, 6, w - 7, h - 7, 4, _hex("08131c", 236))
    for rx, ry in [(10, 10), (w - 14, 10), (10, h - 14), (w - 14, h - 14)]:
        _put_rivet(im, rx, ry)
    im.save(OUT_DIR / "rail_steel.png")

    # 4. card_frame_steel.png & card_frame_gold.png (160x220 transparent center!)
    for name, c_outer, c_hi, c_mid, c_lo in [
        ("card_frame_steel.png", "050b10", "9ab9cf", "557286", "283d4c"),
        ("card_frame_gold.png", "140d04", "ffe394", "cf9736", "6b4813"),
    ]:
        w, h = 160, 220
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        _draw_chamfer_rect(d, 0, 0, w - 1, h - 1, 9, _hex(c_outer, 255))
        _draw_chamfer_rect(d, 2, 2, w - 3, h - 3, 8, _hex(c_mid, 255))
        d.line([(10, 2), (w - 11, 2)], fill=_hex(c_hi))
        d.line([(10, 3), (w - 11, 3)], fill=_hex(c_hi))
        d.line([(10, h - 3), (w - 11, h - 3)], fill=_hex(c_lo))
        d.line([(10, h - 4), (w - 11, h - 4)], fill=_hex(c_lo))
        # Inner cutout window
        _draw_chamfer_rect(d, 10, 10, w - 11, h - 11, 4, _hex(c_outer, 255))
        _draw_chamfer_rect(d, 12, 12, w - 13, h - 13, 3, (0, 0, 0, 0))
        # Crisp rivet accents in the 4 chamfered metallic corners
        for rx, ry in [(15, 5), (w - 19, 5), (15, h - 9), (w - 19, h - 9)]:
            _put_rivet(im, rx, ry, hi=_hex(c_hi), lo=_hex(c_lo))
        im.save(OUT_DIR / name)


def build_tower_pedestal_bg() -> None:
    # Authored on 180x270 canvas -> 2x NEAREST upscale to 360x540
    w, h = 180, 270
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    cx, cy = 90.0, 118.0
    dist = np.sqrt(((xx - cx) / 95.0) ** 2 + ((yy - cy) / 115.0) ** 2)
    radial = np.clip(1.0 - dist, 0.0, 1.0) ** 1.45

    bg_lo = np.array([7.0, 15.0, 24.0])
    bg_hi = np.array([34.0, 74.0, 102.0])
    rgb = bg_lo * (1.0 - radial[:, :, None]) + bg_hi * radial[:, :, None]

    # Bayer pixel dithering for rich 16-bit texture
    bayer = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5) * 6.0
    rgb += np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w, None]
    rgb = np.round(rgb.clip(5, 255) / 2.0) * 2.0

    img = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)

    # Distant arched stone archway & subtle fluted bastion columns pushed deep into shadow
    for px0, px1, inner_x in [(6, 22, 21), (w - 23, w - 7, w - 23)]:
        d.rectangle((px0, 0, px1, 204), fill=_hex("0a1722", 220))
        d.line([(inner_x, 0), (inner_x, 204)], fill=_hex("183042", 200))
        for sy in range(16, 200, 24):
            d.line([(px0 + 1, sy), (px1 - 1, sy)], fill=_hex("060d14", 190))
        d.rectangle((px0 - 2, 196, px1 + 2, 205), fill=_hex("122433"))

    # Grounded dark stone floor horizon below pedestal
    d.rectangle((0, 204, w, h), fill=_hex("08121c", 220))
    d.line([(0, 204), (w, 204)], fill=_hex("172c3d"))

    # Isometric granite/steel pedestal centered at (90, 202) matching card tower foot position!
    # Contact ground shadow under plinth
    d.ellipse((24, 198, 156, 232), fill=_hex("03080e", 215))
    # Pedestal lower bevel stone block (octagonal skirt)
    skirt = [(32, 196), (48, 214), (132, 214), (148, 196), (144, 186), (36, 186)]
    d.polygon(skirt, fill=_hex("243747"), outline=_hex("070f17"))
    d.polygon([(48, 214), (132, 214), (138, 204), (42, 204)], fill=_hex("172531"))
    # Vertical masonry joints on pedestal front
    for jx in (66, 90, 114):
        d.line([(jx, 198), (jx, 213)], fill=_hex("111d28"))
    # Top stone platform ellipse (bright slate bevel + antique brass outer ring)
    d.ellipse((32, 174, 148, 202), fill=_hex("8c6f38"), outline=_hex("070f17"))
    d.ellipse((36, 176, 144, 199), fill=_hex("385266"), outline=_hex("56778f"))
    d.ellipse((50, 181, 130, 194), fill=_hex("2a4052"), outline=_hex("4d6b80"))
    # Contact shadow right where the tower base sits
    d.ellipse((46, 180, 134, 195), fill=_hex("0b1520", 165))

    # Subtle ambient sparks
    rng = np.random.default_rng(107)
    for _ in range(18):
        sx = int(rng.integers(28, w - 28))
        sy = int(rng.integers(32, 168))
        col = _hex("7bd8ff", int(rng.integers(45, 95))) if rng.random() > 0.4 else _hex("f2c66d", int(rng.integers(45, 90)))
        img.putpixel((sx, sy), col)

    img.resize((360, 540), Image.Resampling.NEAREST).save(OUT_DIR / "tower_pedestal_bg.png")


def build_buttons() -> None:
    specs = {
        "btn_cyan": ("06141e", "7be0ff", "299edb", "135f8c", "1b7ab0"),
        "btn_gold": ("180e04", "ffe89c", "d49932", "7d5011", "a8721d"),
        "btn_steel": ("060d14", "8fb0c7", "466175", "223340", "324959"),
        "btn_muted": ("060c12", "495f70", "253440", "131c24", "1d2933"),
    }
    w, h = 128, 64
    for name, (c_out, c_hi, c_body, c_lip, c_bot) in specs.items():
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        _draw_chamfer_rect(d, 0, 0, w - 1, h - 1, 6, _hex(c_out))
        _draw_chamfer_rect(d, 2, 2, w - 3, h - 3, 5, _hex(c_body))
        # Subtle lower gradient half
        _draw_chamfer_rect(d, 2, h // 2, w - 3, h - 7, 3, _hex(c_bot))
        # Bottom recessed beveled lip (4px)
        d.polygon([(7, h - 7), (w - 8, h - 7), (w - 6, h - 3), (5, h - 3)], fill=_hex(c_lip))
        # Top crisp pixel specular bevel (2px)
        d.line([(7, 2), (w - 8, 2)], fill=_hex(c_hi))
        d.line([(6, 3), (w - 7, 3)], fill=_hex(c_hi, 190))
        # Corner rivets placed cleanly inside 14px non-stretching 9-slice corners
        for rx, ry in [(7, 7), (w - 11, 7), (7, h - 13), (w - 11, h - 13)]:
            _put_rivet(im, rx, ry, hi=_hex(c_hi), lo=_hex(c_lip))
        im.save(OUT_DIR / f"{name}.png")


def build_stage_shields() -> None:
    for cleared in (False, True):
        # 42x48 pixel canvas -> 2x NEAREST = 84x96
        w, h = 42, 48
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)

        # Grounded contact shadow ellipse + planted iron post
        d.ellipse((9, 41, 33, 47), fill=_hex("03080e", 170))
        d.rectangle((19, 34, 23, 44), fill=_hex("384d5e"), outline=_hex("070e15"))

        # Heraldic shield silhouette
        outer_pts = [(6, 10), (21, 6), (36, 10), (35, 26), (21, 38), (7, 26)]
        rim_pts = [(8, 12), (21, 8), (34, 12), (33, 25), (21, 35), (9, 25)]
        inner_pts = [(10, 14), (21, 11), (32, 14), (31, 24), (21, 32), (11, 24)]

        d.polygon(outer_pts, fill=_hex("070f17"))
        d.polygon(rim_pts, fill=_hex("e8be5e" if cleared else "b89242"))
        d.polygon(inner_pts, fill=_hex("16354d" if cleared else "142a3d"))
        # Top inner gloss
        d.line([(12, 13), (21, 11), (30, 13)], fill=_hex("336687"))

        if cleared:
            # Crown laurel wings on top left/right corners + crisp emerald-gold check pip bottom-right
            d.polygon([(3, 12), (9, 7), (12, 11), (6, 15)], fill=_hex("f2c963"), outline=_hex("0b1218"))
            d.polygon([(39, 12), (33, 7), (30, 11), (36, 15)], fill=_hex("f2c963"), outline=_hex("0b1218"))
            d.ellipse((26, 27, 38, 39), fill=_hex("1b8c5a"), outline=_hex("08140f"))
            d.line([(29, 33), (31, 35), (35, 30)], fill=_hex("fff2be"), width=2)

        fname = "stage_shield_cleared.png" if cleared else "stage_shield_open.png"
        im.resize((84, 96), Image.Resampling.NEAREST).save(OUT_DIR / fname)

    # stage_lock_seal.png (28x28 -> 56x56)
    im = Image.new("RGBA", (28, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 21, 24, 26), fill=_hex("04090f", 160))
    # Octagonal dark steel plate + padlock shackle
    d.polygon([(8, 6), (20, 6), (24, 10), (24, 20), (20, 24), (8, 24), (4, 20), (4, 10)],
              fill=_hex("3c5161"), outline=_hex("081018"))
    d.polygon([(9, 8), (19, 8), (22, 11), (22, 19), (19, 22), (9, 22), (6, 19), (6, 11)],
              fill=_hex("1a2a36"))
    d.arc((10, 8, 18, 16), 180, 360, fill=_hex("9ab5c9"), width=2)
    d.rectangle((9, 13, 19, 20), fill=_hex("637e94"), outline=_hex("0c151e"))
    d.rectangle((13, 15, 15, 18), fill=_hex("0b141c"))
    im.resize((56, 56), Image.Resampling.NEAREST).save(OUT_DIR / "stage_lock_seal.png")


def _medallion_shell(inner_bg: Image.Image) -> Image.Image:
    # 112x112 circular cold-steel medallion framing any centered square 82x82 pixel emblem
    s = 112
    c = s / 2.0
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32) + 0.5
    dist = np.sqrt((xx - c) ** 2 + (yy - c) ** 2)

    out = np.zeros((s, s, 4), dtype=np.uint8)
    inner_arr = np.array(inner_bg.convert("RGBA"))
    inside = dist <= 41.0
    out[inside] = inner_arr[inside]

    # Subtle inner dark rim shadow around inner well
    in_shadow = (dist > 37.5) & (dist <= 41.0)
    out[in_shadow, :3] = (out[in_shadow, :3].astype(np.float32) * 0.58).astype(np.uint8)

    # Brushed gunmetal steel outer ring (41..52) + dark ink outline (52..54.5)
    ring_inner_ink = (dist > 40.5) & (dist <= 42.5)
    ring_metal = (dist > 42.5) & (dist <= 51.8)
    ring_outer_ink = (dist > 51.8) & (dist <= 54.5)

    angle_top = ((yy - c) / np.maximum(dist, 1.0))  # -1 top, +1 bottom
    out[ring_inner_ink] = _hex("070f17")
    out[ring_outer_ink] = _hex("050b10")

    metal_rgba = np.zeros((s, s, 4), dtype=np.uint8)
    for iy, ix in zip(*np.where(ring_metal)):
        t = (angle_top[iy, ix] + 1.0) * 0.5
        if dist[iy, ix] < 44.5:
            col = _lerp_color((152, 184, 207), (52, 74, 92), t)
        elif dist[iy, ix] > 49.5:
            col = _lerp_color((42, 60, 74), (105, 134, 156), t)
        else:
            col = _lerp_color((114, 144, 166), (48, 69, 86), t)
        metal_rgba[iy, ix] = (col[0], col[1], col[2], 255)
    out[ring_metal] = metal_rgba[ring_metal]

    res = Image.fromarray(out, "RGBA")
    # 4 cardinal brass-gold rivets around the circular steel bezel
    for rx, ry in [(54, 6), (54, 102), (6, 54), (102, 54)]:
        _put_rivet(res, rx, ry, hi=_hex("ffe085"), lo=_hex("6e4a14"))
    return res


def build_dock_medallions() -> None:
    s = 112
    # 1. dock_hero.png: Extract inner pixel portrait of Wolf King (werewolf) or Lord cleanly into circular well
    hero_src = Image.open(RAW_DIR / "04_hero_lord.jpg").convert("RGBA")
    # Tight upper-body crop centering Lord's head/crown/eye-pauldron
    hw, hh = hero_src.size
    crop_box = (int(hw * 0.08), int(hh * 0.03), int(hw * 0.92), int(hh * 0.59))
    hero_well = Image.new("RGBA", (s, s), _hex("0d1c29"))
    bust = hero_src.crop(crop_box).resize((86, 86), Image.Resampling.LANCZOS)
    hero_well.paste(bust, (13, 13))
    _medallion_shell(hero_well).save(OUT_DIR / "dock_hero.png")

    # 2. dock_tower.png: Real refactored Tower Archer Lv2 (frame 0) centered cleanly inside twilight blue well!
    tower_sheet = Image.open(TOWERS_DIR / "tower_archer_lv2.png").convert("RGBA")
    f0 = tower_sheet.crop((0, 0, 256, 256))
    arr = np.array(f0)
    ys, xs = np.where(arr[:, :, 3] > 20)
    tx0, ty0, tx1, ty1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    cropped_t = f0.crop((tx0, ty0, tx1, ty1))
    tw_box = 74
    scale = min(tw_box / cropped_t.width, tw_box / cropped_t.height)
    nt_w, nt_h = max(1, int(round(cropped_t.width * scale))), max(1, int(round(cropped_t.height * scale)))
    t_resized = cropped_t.resize((nt_w, nt_h), Image.Resampling.NEAREST)

    tower_well = Image.new("RGBA", (s, s), (0, 0, 0, 255))
    td = ImageDraw.Draw(tower_well)
    for y in range(s):
        col = _lerp_color((32, 74, 102), (10, 24, 36), y / float(s - 1))
        td.line([(0, y), (s - 1, y)], fill=col + (255,))
    td.ellipse((24, 78, 88, 92), fill=_hex("061018", 210))
    tower_well.alpha_composite(t_resized, ((s - nt_w) // 2, (s - nt_h) // 2 + 4))
    _medallion_shell(tower_well).save(OUT_DIR / "dock_tower.png")

    # 3. dock_codex.png: Rich pixel-art bronze-and-sapphire tome with faceted star clasp
    codex_well = Image.new("RGBA", (56, 56), _hex("102638"))
    cd = ImageDraw.Draw(codex_well)
    for y in range(56):
        col = _lerp_color((38, 66, 98), (12, 24, 38), y / 55.0)
        cd.line([(0, y), (55, y)], fill=col + (255,))
    # Book angled shadow, gold-bound pages, dark sapphire leather cover, corner clasps
    cd.ellipse((12, 39, 44, 47), fill=_hex("060d15", 190))
    cd.polygon([(14, 15), (39, 10), (43, 38), (18, 43)], fill=_hex("244166"), outline=_hex("070f18"))
    cd.polygon([(15, 16), (38, 11), (39, 14), (16, 19)], fill=_hex("3c689c"))
    cd.polygon([(14, 15), (18, 43), (14, 41), (11, 17)], fill=_hex("e5d2a7"), outline=_hex("070f18"))
    cd.line([(13, 18), (16, 40)], fill=_hex("b89c6a"))
    # Brass spine & corner clasps
    for cx, cy in [(36, 12), (40, 36), (19, 40)]:
        cd.rectangle((cx - 1, cy - 1, cx + 1, cy + 1), fill=_hex("e6ba5c"))
    # Glowing cyan star rune on book cover
    cd.polygon([(28, 20), (30, 26), (36, 27), (30, 29), (28, 35), (26, 29), (20, 27), (26, 26)], fill=_hex("56ccf2"))
    cd.polygon([(28, 22), (29, 26), (33, 27), (29, 28), (28, 32), (27, 28), (23, 27), (27, 26)], fill=_hex("b5f2ff"))
    cd.point((28, 27), fill=_hex("ffffff"))
    codex_big = codex_well.resize((s, s), Image.Resampling.NEAREST)
    _medallion_shell(codex_big).save(OUT_DIR / "dock_codex.png")


def build_mini_icons() -> None:
    def save16(name: str, draw_fn) -> None:
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        draw_fn(im, ImageDraw.Draw(im))
        im.resize((32, 32), Image.Resampling.NEAREST).save(OUT_DIR / f"{name}.png")

    def draw_hp(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.polygon([(3, 4), (6, 2), (8, 5), (10, 2), (13, 4), (14, 8), (8, 14), (2, 8)],
                  fill=_hex("d94854"), outline=_hex("170709"))
        d.rectangle((4, 4, 6, 6), fill=_hex("ffa3ad"))

    def draw_atk(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.line([(2, 13), (13, 2)], fill=_hex("0b1117"), width=4)
        d.line([(4, 11), (13, 2)], fill=_hex("cfdce6"), width=2)
        d.line([(5, 10), (12, 3)], fill=_hex("ffffff"), width=1)
        d.line([(3, 8), (8, 13)], fill=_hex("e0ae4e"), width=2)
        d.point((2, 13), fill=_hex("e0ae4e"))

    def draw_spd(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.polygon([(2, 12), (5, 5), (14, 2), (11, 9), (6, 12)], fill=_hex("6fd7f0"), outline=_hex("0a1721"))
        d.line([(3, 13), (9, 7)], fill=_hex("e0f8ff"), width=1)

    def draw_rng(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.ellipse((2, 2, 13, 13), outline=_hex("e8be63"), width=2)
        d.ellipse((6, 6, 9, 9), fill=_hex("ffffff"))
        for p0, p1 in [((8, 0), (8, 4)), ((8, 11), (8, 15)), ((0, 8), (4, 8)), ((11, 8), (15, 8))]:
            d.line([p0, p1], fill=_hex("e8be63"), width=1)

    def draw_shield(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.polygon([(3, 2), (8, 1), (13, 2), (12, 10), (8, 14), (4, 10)], fill=_hex("7f9eb5"), outline=_hex("081017"))
        d.polygon([(4, 3), (8, 2), (12, 3), (11, 9), (8, 12), (5, 9)], fill=_hex("4c687d"))
        d.line([(8, 2), (8, 12)], fill=_hex("b8d3e6"))

    def star_poly() -> list[tuple[int, int]]:
        pts = []
        for i in range(10):
            ang = math.radians(-90 + i * 36)
            rad = 6.5 if i % 2 == 0 else 2.9
            pts.append((int(round(7.5 + rad * math.cos(ang))), int(round(8.0 + rad * math.sin(ang)))))
        return pts

    def draw_star_on(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.polygon(star_poly(), fill=_hex("f2c14e"), outline=_hex("241505"))
        d.rectangle((7, 5, 8, 8), fill=_hex("fff1a8"))

    def draw_star_off(im: Image.Image, d: ImageDraw.ImageDraw) -> None:
        d.polygon(star_poly(), fill=_hex("213240"), outline=_hex("0c151c"))

    save16("stat_hp", draw_hp)
    save16("stat_atk", draw_atk)
    save16("stat_spd", draw_spd)
    save16("stat_rng", draw_rng)
    save16("stat_shield", draw_shield)
    save16("star_on", draw_star_on)
    save16("star_off", draw_star_off)

    # lock_badge.png (14x14 -> 28x28)
    lk = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lk)
    ld.ellipse((0, 0, 13, 13), fill=_hex("09131c", 230), outline=_hex("4d687d"))
    ld.arc((4, 2, 10, 8), 180, 360, fill=_hex("c5d9e8"), width=1)
    ld.rectangle((3, 6, 10, 11), fill=_hex("8aa8bd"), outline=_hex("0c161f"))
    ld.rectangle((6, 7, 7, 9), fill=_hex("0d1822"))
    lk.resize((28, 28), Image.Resampling.NEAREST).save(OUT_DIR / "lock_badge.png")

    # equipped_pip.png (12x12 -> 24x24)
    ep = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    ed = ImageDraw.Draw(ep)
    ed.ellipse((0, 0, 11, 11), fill=_hex("1888ba"), outline=_hex("06141c"))
    ed.line([(3, 6), (5, 8), (8, 4)], fill=_hex("ffffff"), width=1)
    ep.resize((24, 24), Image.Resampling.NEAREST).save(OUT_DIR / "equipped_pip.png")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_title_bg()
    build_title_logo()
    build_world_map()
    build_hero_cards()
    build_hall_bg()
    build_panels_and_frames()
    build_tower_pedestal_bg()
    build_buttons()
    build_stage_shields()
    build_dock_medallions()
    build_mini_icons()
    generated = sorted(p.name for p in OUT_DIR.glob("*.png"))
    print(f"Generated {len(generated)} v0.27 UI assets in {OUT_DIR}:")
    for name in generated:
        im = Image.open(OUT_DIR / name)
        print(f"  {name:28s} {im.size}")


if __name__ == "__main__":
    main()
