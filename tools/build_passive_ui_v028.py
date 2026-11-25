from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

PROJECT = Path(__file__).resolve().parents[1]
RAW_PATH = PROJECT.parent / "美术参考" / "v028_passive_raw" / "01_tactical_medallions.jpg"
OUT_DIR = PROJECT / "assets" / "ui_v028"
SCRATCH_CHECK = Path(r"C:\Users\黄子衿\.gemini\antigravity\brain\576a2758-9e88-4f27-8e7a-860481c4c0c1\scratch\v028_medallions_check.png")

MEDAL_IDS = [
    ["relay", "riposte", "wall", "beacon"],
    ["bounty", "chest", "lure", "bridge"],
    ["battery", "muster", "mark", "orders"],
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


def _chroma_key_crop(patch: np.ndarray, comp_keep: np.ndarray) -> Image.Image:
    h, w, _ = patch.shape
    arr = patch.copy()
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)

    # Reject pixels from adjacent grid neighbors outside this component's grown mask
    outside_comp = ~_dilate(comp_keep, 3)

    # Outer chroma green background flood-fill from patch edges
    cand = outside_comp | ((g > 118) & ((g - np.maximum(r, b)) > 36))
    bg = outside_comp.copy()
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

    # Strict neon green interior hole removal (only pure chroma green >= 8px)
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

    # Expand 1px into bright-green AA fringe adjacent to background
    edge1 = _dilate(bg, 1) & (~bg)
    bg |= edge1 & (g > 102) & ((g - np.maximum(r, b)) > 34)
    arr[bg, 3] = 0

    # Taper alpha slightly on immediate green-tinted fringe and despill 2px boundary only
    edge_soft = _dilate(bg, 1) & (~bg)
    soft_green = edge_soft & (g > np.maximum(r, b) + 14) & (g > 64)
    arr[soft_green, 3] = 175

    edge2 = _dilate(bg, 2) & (~bg)
    sp = edge2 & (g > np.maximum(r, b) + 6)
    max_rb = np.maximum(r[sp], b[sp])
    arr[sp, 1] = np.minimum(arr[sp, 1], np.clip(max_rb + 4, 0, 255)).astype(np.uint8)

    # Tight bbox crop, center into square with 3% pad, Lanczos downscale to 96x96
    oys, oxs = np.where(arr[:, :, 3] > 24)
    x0, x1 = int(oxs.min()), int(oxs.max()) + 1
    y0, y1 = int(oys.min()), int(oys.max()) + 1
    cropped = Image.fromarray(arr[y0:y1, x0:x1])
    side = int(round(max(cropped.width, cropped.height) * 1.06))
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2), cropped)
    out = sq.resize((96, 96), Image.Resampling.LANCZOS)
    return ImageEnhance.Sharpness(out).enhance(1.06)


def slice_medallions() -> dict[str, Image.Image]:
    im = Image.open(RAW_PATH).convert("RGBA")
    arr = np.array(im)
    h, w, _ = arr.shape
    r = arr[:, :, 0].astype(np.int32)
    g = arr[:, :, 1].astype(np.int32)
    b = arr[:, :, 2].astype(np.int32)

    fg = ~((g > 128) & ((g - np.maximum(r, b)) > 42))
    fg_grouped = _dilate(fg, 1)

    labels = np.zeros((h, w), dtype=np.int32)
    vis = np.zeros((h, w), dtype=bool)
    blobs = []
    label_id = 0
    for sy in range(0, h, 2):
        for sx in range(0, w, 2):
            if fg_grouped[sy, sx] and not vis[sy, sx]:
                label_id += 1
                q = deque([(sy, sx)])
                vis[sy, sx] = True
                pts = []
                min_y = max_y = sy
                min_x = max_x = sx
                while q:
                    cy, cx = q.popleft()
                    labels[cy, cx] = label_id
                    pts.append((cy, cx))
                    min_y = min(min_y, cy)
                    max_y = max(max_y, cy)
                    min_x = min(min_x, cx)
                    max_x = max(max_x, cx)
                    for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                        if 0 <= ny < h and 0 <= nx < w and fg_grouped[ny, nx] and not vis[ny, nx]:
                            vis[ny, nx] = True
                            q.append((ny, nx))
                if len(pts) >= (h * w) // 80:
                    x0 = max(0, min_x - 4)
                    y0 = max(0, min_y - 4)
                    x1 = min(w, max_x + 5)
                    y1 = min(h, max_y + 5)
                    blobs.append(((x0 + x1) * 0.5, (y0 + y1) * 0.5, x0, y0, x1, y1, label_id))

    if len(blobs) != 12:
        raise RuntimeError(f"Expected 12 medallion blobs, found {len(blobs)}")

    blobs.sort(key=lambda item: item[1])
    rows = [sorted(blobs[i * 4 : (i + 1) * 4], key=lambda item: item[0]) for i in range(3)]

    medals: dict[str, Image.Image] = {}
    for r_idx in range(3):
        for c_idx in range(4):
            mid = MEDAL_IDS[r_idx][c_idx]
            _, _, x0, y0, x1, y1, lid = rows[r_idx][c_idx]
            comp_keep = labels[y0:y1, x0:x1] == lid
            icon = _chroma_key_crop(arr[y0:y1, x0:x1], comp_keep)
            icon.save(OUT_DIR / f"medal_{mid}.png")
            medals[mid] = icon
            print(f"Saved medal_{mid}.png from ({x0},{y0})-({x1},{y1})")
    return medals


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
            if dx in (0, 3) and dy in (0, 3):
                continue
            col = hi if (dx <= 1 and dy <= 1) else (_hex("648399") if (dx + dy) <= 3 else lo)
            img.putpixel((x + dx, y + dy), col)


def _build_rule_card(hover: bool) -> Image.Image:
    w, h = 296, 376
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    outer = _hex("050b10", 252)
    rim_mid = _hex("9c7b38" if hover else "4a677c", 252)
    rim_hi = _hex("ffe18f" if hover else "94b6cc", 255)
    rim_lo = _hex("4f3b18" if hover else "223544", 255)

    _draw_chamfer_rect(d, 0, 0, w - 1, h - 1, 10, outer)
    _draw_chamfer_rect(d, 2, 2, w - 3, h - 3, 9, rim_mid)
    d.line([(12, 2), (w - 13, 2)], fill=rim_hi)
    d.line([(11, 3), (w - 12, 3)], fill=rim_hi)
    d.line([(12, h - 3), (w - 13, h - 3)], fill=rim_lo)
    d.line([(11, h - 4), (w - 12, h - 4)], fill=rim_lo)

    # Frosted dark-obsidian translucent vertical gradient interior
    _draw_chamfer_rect(d, 6, 6, w - 7, h - 7, 6, (0, 0, 0, 0))
    arr = np.array(im)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    # Fill interior mask
    mask_im = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask_im)
    _draw_chamfer_rect(md, 6, 6, w - 7, h - 7, 6, 255)
    inside = np.array(mask_im) > 0

    t = np.clip((yy - 6.0) / float(h - 12), 0.0, 1.0)
    if hover:
        top_rgb = np.array([26.0, 52.0, 74.0])
        bot_rgb = np.array([11.0, 23.0, 35.0])
        alpha_val = 238.0
    else:
        top_rgb = np.array([18.0, 36.0, 53.0])
        bot_rgb = np.array([9.0, 18.0, 28.0])
        alpha_val = 228.0

    rgb = top_rgb * (1.0 - t[:, :, None]) + bot_rgb * t[:, :, None]

    # Subtle radial backlight behind upper medallion cradle (center x=148, y=28)
    glow = np.exp(-(((xx - 148.0) / 86.0) ** 2 + ((yy - 24.0) / 72.0) ** 2))
    if hover:
        rgb[:, :, 0] += glow * 34.0
        rgb[:, :, 1] += glow * 44.0
        rgb[:, :, 2] += glow * 52.0
    else:
        rgb[:, :, 0] += glow * 14.0
        rgb[:, :, 1] += glow * 26.0
        rgb[:, :, 2] += glow * 36.0

    # Bayer pixel dithering inside card body
    bayer = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5) * 3.5
    rgb += np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w, None]

    arr[inside, 0] = np.clip(rgb[inside, 0], 0, 255).astype(np.uint8)
    arr[inside, 1] = np.clip(rgb[inside, 1], 0, 255).astype(np.uint8)
    arr[inside, 2] = np.clip(rgb[inside, 2], 0, 255).astype(np.uint8)
    arr[inside, 3] = int(alpha_val)

    im = Image.fromarray(arr)
    d = ImageDraw.Draw(im)

    # Crisp inner hairline & top gold crest bar
    inner_line = _hex("d8a642" if hover else "274459", 215)
    _draw_chamfer_rect(d, 8, 8, w - 9, h - 9, 5, None, outline=inner_line)

    # Decorative gold filigree shoulder accents on top rim around the protruding medallion
    gold_trim = _hex("f5cf72" if hover else "c8993e", 240)
    d.line([(68, 5), (104, 5)], fill=gold_trim, width=2)
    d.line([(w - 105, 5), (w - 69, 5)], fill=gold_trim, width=2)
    d.polygon([(148, h - 8), (156, h - 4), (148, h - 2), (140, h - 4)], fill=gold_trim)

    # Quiet horizontal divider separating title/tag from main effect tagline
    d.line([(36, 138), (w - 37, 138)], fill=_hex("38566c", 180))
    d.rectangle((146, 137, 150, 140), outline=None, fill=gold_trim)

    # Corner rivets
    for rx, ry in [(11, 11), (w - 15, 11), (11, h - 15), (w - 15, h - 15)]:
        _put_rivet(im, rx, ry, hi=rim_hi, lo=rim_lo)

    out_name = "rule_card_hover.png" if hover else "rule_card_bg.png"
    im.save(OUT_DIR / out_name)
    return im


def build_ui_widgets() -> None:
    card_bg = _build_rule_card(False)
    card_hv = _build_rule_card(True)

    # detail_popover_bg.png (96x96, 16px margin)
    s = 96
    pop = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pop)
    _draw_chamfer_rect(pd, 0, 0, s - 1, s - 1, 7, _hex("050b10", 252))
    _draw_chamfer_rect(pd, 2, 2, s - 3, s - 3, 6, _hex("9b7a3a", 252))
    pd.line([(9, 2), (s - 10, 2)], fill=_hex("f5cf72"))
    pd.line([(9, s - 3), (s - 10, s - 3)], fill=_hex("473415"))
    _draw_chamfer_rect(pd, 6, 6, s - 7, s - 7, 4, _hex("0a1520", 246))
    _draw_chamfer_rect(pd, 7, 7, s - 8, s - 8, 3, None, outline=_hex("294358", 210))
    for rx, ry in [(9, 9), (s - 13, 9), (9, s - 13), (s - 13, s - 13)]:
        _put_rivet(pop, rx, ry, hi=_hex("f5cf72"), lo=_hex("473415"))
    pop.save(OUT_DIR / "detail_popover_bg.png")

    # cost_pill_bg.png (96x32, 10px 9-slice)
    pw, ph = 96, 32
    cp = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cp)
    _draw_chamfer_rect(cd, 0, 0, pw - 1, ph - 1, 5, _hex("0c0910", 230))
    _draw_chamfer_rect(cd, 1, 1, pw - 2, ph - 2, 4, _hex("683842", 220))
    _draw_chamfer_rect(cd, 3, 3, pw - 4, ph - 4, 3, _hex("19111a", 228))
    cd.line([(6, 2), (pw - 7, 2)], fill=_hex("8c4d5a", 180))
    cp.save(OUT_DIR / "cost_pill_bg.png")

    # tag_pill_bg.png (80x26, 8px 9-slice)
    tw, th = 80, 26
    tp = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    td = ImageDraw.Draw(tp)
    _draw_chamfer_rect(td, 0, 0, tw - 1, th - 1, 4, _hex("08111a", 230))
    _draw_chamfer_rect(td, 1, 1, tw - 2, th - 2, 3, _hex("355268", 225))
    _draw_chamfer_rect(td, 2, 2, tw - 3, th - 3, 3, _hex("102232", 225))
    tp.save(OUT_DIR / "tag_pill_bg.png")

    # badge_slot_mini.png (48x48 circular/octagonal socket)
    bs = 48
    slot = Image.new("RGBA", (bs, bs), (0, 0, 0, 0))
    sd = ImageDraw.Draw(slot)
    sd.ellipse((1, 1, bs - 2, bs - 2), fill=_hex("060e16", 240), outline=_hex("4d6a80", 240), width=2)
    sd.ellipse((4, 4, bs - 5, bs - 5), fill=_hex("0d1c29", 235), outline=_hex("c89c42", 180), width=1)
    slot.save(OUT_DIR / "badge_slot_mini.png")

    return card_bg, card_hv, pop


def build_check_sheet(medals: dict[str, Image.Image], card_bg: Image.Image, card_hv: Image.Image) -> None:
    cw, ch = 1040, 820
    canvas = Image.new("RGBA", (cw, ch), _hex("0c1722", 255))
    # Paste 12 medallions on dark navy background at top
    ids = [mid for row in MEDAL_IDS for mid in row]
    for i, mid in enumerate(ids):
        r, c = divmod(i, 6)
        x = 30 + c * 164
        y = 28 + r * 140
        m = medals[mid]
        canvas.paste(m, (x, y), m)
        d = ImageDraw.Draw(canvas)
        d.text((x + 12, y + 102), mid, fill=_hex("e8f0f6"))

    # Paste rule_card_bg & rule_card_hover with sample protruding medallions below
    canvas.paste(card_bg, (80, 380), card_bg)
    m0 = medals["relay"]
    canvas.paste(m0, (80 + 100, 380 - 48), m0)

    canvas.paste(card_hv, (460, 380), card_hv)
    m1 = medals["bounty"]
    canvas.paste(m1, (460 + 100, 380 - 48), m1)

    canvas.save(SCRATCH_CHECK)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    medals = slice_medallions()
    card_bg, card_hv, _ = build_ui_widgets()
    build_check_sheet(medals, card_bg, card_hv)
    print("v0.28 asset build complete:", len(list(OUT_DIR.glob("*.png"))), "PNG files")


if __name__ == "__main__":
    main()
