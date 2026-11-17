"""Generate v0.16 Stage 3 strict 1x-pixel-grid construct spritesheets, emissive masks, and twin-state altar."""
from __future__ import annotations

import math
from pathlib import Path
from statistics import median
from typing import Sequence

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "v016"

# Hue-shifted pixel art color ramps (RGBA, 100% opaque on solid pixels).
PAL = {
    "OUT": (22, 17, 36, 255),
    "IN_OUT": (36, 27, 56, 255),
    # Dark iron / steel (hue-shifted toward indigo-plum in shadow, icy silver in highlight)
    "I0": (206, 218, 242, 255),
    "I1": (146, 158, 196, 255),
    "I2": (102, 106, 148, 255),
    "I3": (72, 66, 110, 255),
    "I4": (48, 40, 76, 255),
    # Obsidian / abyssal dark carapace
    "D0": (132, 134, 174, 255),
    "D1": (92, 88, 128, 255),
    "D2": (64, 56, 94, 255),
    "D3": (44, 35, 68, 255),
    # Gold / brass trim (cream gold -> rich gold -> warm bronze -> umber plum)
    "G0": (255, 242, 174, 255),
    "G1": (236, 188, 82, 255),
    "G2": (176, 116, 54, 255),
    "G3": (110, 68, 48, 255),
    # Void cloth / mantle (plum -> violet)
    "V0": (166, 108, 206, 255),
    "V1": (122, 70, 164, 255),
    "V2": (82, 42, 118, 255),
    "V3": (52, 25, 78, 255),
    # Basalt stone (for altar & debris)
    "S0": (166, 172, 204, 255),
    "S1": (118, 120, 156, 255),
    "S2": (84, 80, 116, 255),
    "S3": (58, 52, 84, 255),
    "S4": (38, 33, 58, 255),
    # Emissive Cyan Astral Rune
    "C0": (236, 255, 255, 255),
    "C1": (112, 242, 255, 255),
    "C2": (44, 172, 224, 255),
    "C3": (28, 92, 152, 255),
    # Emissive Arcane Violet
    "P0": (253, 234, 255, 255),
    "P1": (214, 118, 255, 255),
    "P2": (146, 62, 212, 255),
    "P3": (82, 34, 128, 255),
    # Emissive Rift Molten Ember
    "E0": (255, 246, 186, 255),
    "E1": (255, 168, 58, 255),
    "E2": (224, 72, 68, 255),
    "E3": (126, 36, 60, 255),
}

IRON_RAMP = (PAL["I0"], PAL["I1"], PAL["I2"], PAL["I3"], PAL["I4"])
DARK_RAMP = (PAL["D0"], PAL["D1"], PAL["D2"], PAL["D3"], PAL["I4"])
GOLD_RAMP = (PAL["G0"], PAL["G1"], PAL["G2"], PAL["G3"], PAL["G3"])
CLOTH_RAMP = (PAL["V0"], PAL["V1"], PAL["V2"], PAL["V3"], PAL["V3"])
STONE_RAMP = (PAL["S0"], PAL["S1"], PAL["S2"], PAL["S3"], PAL["S4"])
CYAN_RAMP = (PAL["C0"], PAL["C1"], PAL["C2"], PAL["C3"], PAL["C3"])
VIOLET_RAMP = (PAL["P0"], PAL["P1"], PAL["P2"], PAL["P3"], PAL["P3"])
EMBER_RAMP = (PAL["E0"], PAL["E1"], PAL["E2"], PAL["E3"], PAL["E3"])

EMIT_RGB = {
    "C0": (220, 255, 255, 255),
    "C1": (90, 225, 255, 255),
    "C2": (35, 145, 200, 255),
    "C3": (18, 70, 125, 255),
    "P0": (245, 205, 255, 255),
    "P1": (200, 95, 255, 255),
    "P2": (130, 48, 195, 255),
    "P3": (68, 24, 110, 255),
    "E0": (255, 235, 150, 255),
    "E1": (255, 140, 40, 255),
    "E2": (205, 52, 48, 255),
    "G0": (255, 225, 120, 255),
    "G1": (235, 165, 55, 255),
}


class LayerBuffer:
    """1x pixel mask buffer for one articulated body part before shading & compositing."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.mat = np.zeros((h, w), dtype=np.int16)
        self.direct = np.zeros((h, w, 4), dtype=np.uint8)
        self.emit = np.zeros((h, w, 4), dtype=np.uint8)

    def px(self, x: int, y: int, mat_id: int = 1, color: tuple[int, int, int, int] | None = None,
           emit: tuple[int, int, int, int] | None = None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            if color is not None:
                self.direct[y, x] = color
                self.mat[y, x] = mat_id if mat_id > 0 else 99
            else:
                self.mat[y, x] = mat_id
                self.direct[y, x, 3] = 0
            if emit is not None:
                self.emit[y, x] = emit

    def line(self, x0: int, y0: int, x1: int, y1: int, mat_id: int = 1,
             color: tuple[int, int, int, int] | None = None,
             emit: tuple[int, int, int, int] | None = None, thickness: int = 1) -> None:
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        r0 = -(thickness // 2)
        r1 = r0 + thickness
        while True:
            for oy in range(r0, r1):
                for ox in range(r0, r1):
                    self.px(x0 + ox, y0 + oy, mat_id, color, emit)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def rect(self, x: int, y: int, rw: int, rh: int, mat_id: int = 1,
             color: tuple[int, int, int, int] | None = None,
             emit: tuple[int, int, int, int] | None = None) -> None:
        for py in range(y, y + rh):
            for px_x in range(x, x + rw):
                self.px(px_x, py, mat_id, color, emit)

    def disc(self, cx: int, cy: int, r: float, mat_id: int = 1,
             color: tuple[int, int, int, int] | None = None,
             emit: tuple[int, int, int, int] | None = None, ry: float | None = None) -> None:
        ry_val = r if ry is None else ry
        irx = int(math.ceil(r))
        iry = int(math.ceil(ry_val))
        for py in range(cy - iry, cy + iry + 1):
            for px_x in range(cx - irx, cx + irx + 1):
                nx = (px_x - cx) / max(0.5, r)
                ny = (py - cy) / max(0.5, ry_val)
                if nx * nx + ny * ny <= 1.0:
                    self.px(px_x, py, mat_id, color, emit)

    def poly(self, pts: Sequence[tuple[float, float]], mat_id: int = 1,
             color: tuple[int, int, int, int] | None = None,
             emit: tuple[int, int, int, int] | None = None) -> None:
        if len(pts) < 3:
            return
        ipts = [(int(round(px_x)), int(round(py))) for px_x, py in pts]
        ys = [p[1] for p in ipts]
        min_y = max(0, min(ys))
        max_y = min(self.h - 1, max(ys))
        n = len(ipts)
        for y in range(min_y, max_y + 1):
            nodes: list[int] = []
            j = n - 1
            for i in range(n):
                yi = ipts[i][1]
                yj = ipts[j][1]
                xi = ipts[i][0]
                xj = ipts[j][0]
                if (yi < y <= yj) or (yj < y <= yi):
                    x_hit = int(round(xi + (y - yi) * (xj - xi) / float(yj - yi)))
                    nodes.append(x_hit)
                j = i
            nodes.sort()
            for k in range(0, len(nodes) - 1, 2):
                for x in range(max(0, nodes[k]), min(self.w, nodes[k + 1] + 1)):
                    self.px(x, y, mat_id, color, emit)
        for i in range(n):
            p0 = ipts[i]
            p1 = ipts[(i + 1) % n]
            self.line(p0[0], p0[1], p1[0], p1[1], mat_id, color, emit, 1)

    def stamp(self, x0: int, y0: int, rows: Sequence[str], cmap: dict[str, tuple[int, str | None, str | None]]) -> None:
        for ry, row in enumerate(rows):
            for rx, ch in enumerate(row):
                if ch in cmap:
                    mat_id, pal_key, emit_key = cmap[ch]
                    col = PAL[pal_key] if pal_key else None
                    em = EMIT_RGB[emit_key] if emit_key else None
                    self.px(x0 + rx, y0 + ry, mat_id, col, em)


MAT_RAMPS = {
    1: IRON_RAMP,
    2: DARK_RAMP,
    3: GOLD_RAMP,
    4: CLOTH_RAMP,
    5: STONE_RAMP,
    6: CYAN_RAMP,
    7: VIOLET_RAMP,
    8: EMBER_RAMP,
}


class PixelFrame:
    """Assembles shaded, occluded, dark-iron-outlined 1x pixel art frames."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.rgba = np.zeros((h, w, 4), dtype=np.uint8)
        self.emit = np.zeros((h, w, 4), dtype=np.uint8)
        self.solid_mask = np.zeros((h, w), dtype=bool)

    def layer(self) -> LayerBuffer:
        return LayerBuffer(self.w, self.h)

    def composite(self, buf: LayerBuffer, shade_shift: int = 0, receive_outline: bool = True,
                  cast_shadow_on_prev: bool = False) -> None:
        mat = buf.mat
        h, w = self.h, self.w
        occ = mat > 0

        if cast_shadow_on_prev:
            for y in range(1, h):
                for x in range(1, w):
                    if occ[y - 1, x - 1] and not occ[y, x] and self.rgba[y, x, 3] > 0:
                        self._darken_existing(x, y)

        for y in range(h):
            for x in range(w):
                m = int(mat[y, x])
                if m == 0:
                    continue
                if buf.direct[y, x, 3] > 0:
                    self.rgba[y, x] = buf.direct[y, x]
                else:
                    ramp = MAT_RAMPS.get(m, IRON_RAMP)
                    up_empty = (y == 0) or (mat[y - 1, x] == 0)
                    left_empty = (x == 0) or (mat[y, x - 1] == 0)
                    dn_empty = (y == h - 1) or (mat[y + 1, x] == 0)
                    rt_empty = (x == w - 1) or (mat[y, x + 1] == 0)
                    up2_empty = (y <= 1) or (mat[y - 2, x] == 0)
                    dn2_empty = (y >= h - 2) or (mat[y + 2, x] == 0)
                    up_diff = (y > 0) and (mat[y - 1, x] != m) and (mat[y - 1, x] > 0)
                    dn_diff = (y < h - 1) and (mat[y + 1, x] != m) and (mat[y + 1, x] > 0)

                    idx = 2
                    if up_empty and left_empty:
                        idx = 0
                    elif up_empty or left_empty:
                        idx = 1
                    elif up2_empty and ((x + y) % 3 != 0):
                        idx = 1
                    elif dn_empty or rt_empty:
                        idx = 4 if (dn_empty and rt_empty) else 3
                    elif dn2_empty or dn_diff:
                        idx = 3
                    elif up_diff:
                        idx = 1

                    if idx == 2 and not up_empty and not dn_empty and ((x * 3 + y * 5) % 11 == 0):
                        idx = 3

                    idx = max(0, min(len(ramp) - 1, idx + shade_shift))
                    self.rgba[y, x] = ramp[idx]

                if buf.emit[y, x, 3] > 0:
                    self.emit[y, x] = buf.emit[y, x]
                if receive_outline:
                    self.solid_mask[y, x] = True

    def _darken_existing(self, x: int, y: int) -> None:
        c = self.rgba[y, x]
        if self.emit[y, x, 3] > 0:
            return
        r = max(24, int(c[0] * 0.68))
        g = max(20, int(c[1] * 0.64))
        b = max(44, int(c[2] * 0.78))
        self.rgba[y, x] = (r, g, b, 255)

    def add_vfx(self, buf: LayerBuffer) -> None:
        self.composite(buf, shade_shift=0, receive_outline=False, cast_shadow_on_prev=False)

    def finalize_outline(self, outline_col: tuple[int, int, int, int] = PAL["OUT"]) -> None:
        h, w = self.h, self.w
        solid = self.solid_mask
        to_outline: list[tuple[int, int]] = []
        for y in range(h):
            for x in range(w):
                if self.rgba[y, x, 3] > 0:
                    continue
                if ((x > 0 and solid[y, x - 1]) or
                    (x + 1 < w and solid[y, x + 1]) or
                    (y > 0 and solid[y - 1, x]) or
                    (y + 1 < h and solid[y + 1, x])):
                    to_outline.append((x, y))
        for x, y in to_outline:
            self.rgba[y, x] = outline_col


def rot_pt(cx: float, cy: float, dx: float, dy: float, deg: float) -> tuple[int, int]:
    rad = math.radians(deg)
    c, s = math.cos(rad), math.sin(rad)
    return int(round(cx + dx * c - dy * s)), int(round(cy + dx * s + dy * c))


# ==============================================================================
# 1. CREATURE: CONSTRUCT_HOUND (40x40 native -> 80x80 cell -> 480x240)
# ==============================================================================
def _paint_hound_body(f: PixelFrame, cx: int, cy: int, pitch: float,
                      leg_angles: tuple[int, int, int, int], tail_ang: int,
                      jaw_open: int, cry_boost: bool, clamp_floor: bool,
                      crack_mode: int = 0) -> None:
    def draw_leg(lx: int, ly: int, hip_deg: float, mat_id: int, shade: int) -> None:
        buf = f.layer()
        kx, ky = rot_pt(lx, ly, -1, 6, hip_deg)
        px_x, py = rot_pt(kx, ky, 3, 6, hip_deg * 0.42)
        py = min(35 if clamp_floor else 37, py)
        buf.line(lx, ly, kx, ky, mat_id, thickness=2)
        buf.line(kx, ky, px_x, py, mat_id, thickness=2)
        buf.px(kx, ky, 3)
        buf.px(px_x + 1, py, mat_id)
        buf.px(px_x + 2, py, 1 if shade == 0 else 2)
        f.composite(buf, shade_shift=shade)

    # Back legs
    bh_x, bh_y = rot_pt(cx - 6, cy + 1, 0, 0, pitch)
    bf_x, bf_y = rot_pt(cx + 5, cy + 1, 0, 0, pitch)
    draw_leg(bh_x, bh_y, leg_angles[0], 2, 1)
    draw_leg(bf_x, bf_y, leg_angles[1], 2, 1)

    # Tail
    tail = f.layer()
    tx0, ty0 = rot_pt(cx - 7, cy - 2, 0, 0, pitch)
    tx1, ty1 = rot_pt(tx0, ty0, -4, -3, tail_ang)
    tx2, ty2 = rot_pt(tx1, ty1, -3, -2, tail_ang * 1.15)
    tail.line(tx0, ty0, tx1, ty1, 2, thickness=2)
    tail.line(tx1, ty1, tx2, ty2, 7, PAL["P1"], EMIT_RGB["P1"], thickness=1)
    tail.px(tx2 - 1, ty2 - 1, 7, PAL["P0"], EMIT_RGB["P0"])
    f.composite(tail)

    # Torso + collar
    body = f.layer()
    pts = [
        rot_pt(cx - 8, cy - 3, 0, 0, pitch),
        rot_pt(cx + 1, cy - 4, 0, 0, pitch),
        rot_pt(cx + 7, cy - 4, 0, 0, pitch),
        rot_pt(cx + 8, cy + 2, 0, 0, pitch),
        rot_pt(cx + 1, cy + 3, 0, 0, pitch),
        rot_pt(cx - 7, cy + 2, 0, 0, pitch),
    ]
    body.poly(pts, 1)
    c0 = rot_pt(cx + 5, cy - 4, 0, 0, pitch)
    c1 = rot_pt(cx + 6, cy + 2, 0, 0, pitch)
    body.line(c0[0], c0[1], c1[0], c1[1], 3, thickness=2)
    vx, vy = rot_pt(cx + 1, cy - 1, 0, 0, pitch)
    if crack_mode > 0:
        body.line(vx - 3, vy - 1, vx + 3, vy + 1, 7, PAL["P0"], EMIT_RGB["P0"])
    else:
        body.px(vx, vy, 6, PAL["C1"], EMIT_RGB["C1"])
        body.px(vx - 1, vy, 6, PAL["C2"], EMIT_RGB["C2"])
    f.composite(body, cast_shadow_on_prev=True)

    # 3 Dorsal crystals
    crys = f.layer()
    for ci, (ox, oy, ch) in enumerate([(-5, -5, 5), (-1, -6, 7), (3, -5, 5)]):
        if crack_mode == 2 and ci == 1:
            continue
        bx, by = rot_pt(cx + ox, cy + oy, 0, 0, pitch)
        tip_x, tip_y = rot_pt(bx, by, -2, -ch, pitch * 0.5)
        crys.line(bx, by, tip_x, tip_y, 7, PAL["P2"], EMIT_RGB["P2"], thickness=2)
        crys.line(bx, by - 1, tip_x, tip_y, 7, PAL["P0"] if cry_boost else PAL["P1"],
                  EMIT_RGB["P0"] if cry_boost else EMIT_RGB["P1"], thickness=1)
        crys.px(tip_x, tip_y, 7, PAL["C0"] if cry_boost else PAL["P0"],
                EMIT_RGB["C0"] if cry_boost else EMIT_RGB["P0"])
    f.composite(crys)

    # Angular head + solid triangular swept ear (no checkerboard!) + jaw
    head = f.layer()
    hx, hy = rot_pt(cx + 9, cy - 3, 0, 0, pitch * 0.6)
    head.poly([(hx - 2, hy - 3), (hx + 4, hy - 4), (hx + 8, hy - 1), (hx + 7, hy + 1), (hx - 1, hy + 1)], 2)
    # Solid sculpted swept-back horn-ear triangle
    head.poly([(hx - 2, hy - 3), (hx - 5, hy - 8), (hx + 1, hy - 5)], 1)
    head.line(hx, hy + 1 + jaw_open // 2, hx + 7, hy + 1 + jaw_open, 1, thickness=1)
    if jaw_open > 0:
        head.px(hx + 5, hy + 1, 1, PAL["I0"])
        head.px(hx + 6, hy + jaw_open, 1, PAL["I0"])
        head.px(hx + 2, hy + 1, 7, PAL["P1"], EMIT_RGB["P1"])
    head.px(hx + 3, hy - 2, 6, PAL["C0"], EMIT_RGB["C0"])
    head.px(hx + 2, hy - 2, 7, PAL["P1"], EMIT_RGB["P1"])
    f.composite(head, cast_shadow_on_prev=True)

    # Front legs
    fh_x, fh_y = rot_pt(cx - 5, cy + 2, 0, 0, pitch)
    ff_x, ff_y = rot_pt(cx + 5, cy + 2, 0, 0, pitch)
    draw_leg(fh_x, fh_y, leg_angles[2], 1, 0)
    draw_leg(ff_x, ff_y, leg_angles[3], 1, 0)


def draw_construct_hound(row: int, col: int) -> PixelFrame:
    f = PixelFrame(40, 40)
    if row == 2:
        return _hound_down(f, col)

    if row == 0:
        bobs = [1, 0, -2, -1, 1, 0]
        pitches = [2, -6, -3, 4, 7, 1]
        legs = [
            (32, -28, -28, 34),
            (46, -42, -14, 16),
            (18, -14, 42, -38),
            (-26, 34, 24, -22),
            (-42, 42, 6, -10),
            (-14, 20, -40, 44),
        ]
        jaw_open = 0
        dx_shift = 0
        tail_ang = [-28, -42, -18, 5, -12, -32][col]
        cry_boost = (col % 3 == 1)
        clamp = True
    else:
        bobs = [2, -2, -3, 0, 2, 0]
        pitches = [8, -16, -6, 6, 4, 0]
        legs = [
            (36, 22, 32, 26),
            (50, -48, 45, -44),
            (55, -52, 48, -50),
            (-20, -34, -14, -26),
            (-12, 18, -8, 22),
            (14, -12, 10, -8),
        ]
        jaw_open = [1, 3, 4, 2, 1, 0][col]
        dx_shift = [-1, -1, 0, 0, -1, 0][col]
        tail_ang = [-15, -48, -30, 10, -10, -22][col]
        cry_boost = col in (1, 2, 3)
        clamp = False

    _paint_hound_body(f, 19 + dx_shift, 22 + bobs[col], pitches[col], legs[col],
                      tail_ang, jaw_open, cry_boost, clamp)
    f.finalize_outline()

    if row == 1 and col in (2, 3, 4):
        vfx = f.layer()
        if col == 2:
            vfx.line(29, 13, 35, 19, 6, PAL["C1"], EMIT_RGB["C1"])
            vfx.line(31, 16, 36, 22, 7, PAL["P1"], EMIT_RGB["P1"])
        elif col == 3:
            vfx.line(28, 11, 36, 22, 6, PAL["C0"], EMIT_RGB["C0"], thickness=2)
            vfx.line(33, 15, 37, 27, 7, PAL["P1"], EMIT_RGB["P1"])
            vfx.line(27, 17, 34, 29, 6, PAL["C2"], EMIT_RGB["C2"])
        else:
            vfx.px(35, 21, 6, PAL["C1"], EMIT_RGB["C1"])
            vfx.px(36, 26, 7, PAL["P1"], EMIT_RGB["P1"])
        f.add_vfx(vfx)
    return f


def _hound_down(f: PixelFrame, col: int) -> PixelFrame:
    if col == 0:
        _paint_hound_body(f, 19, 23, -12, (28, -22, 20, -14), -40, 2, True, True, crack_mode=1)
    elif col == 1:
        _paint_hound_body(f, 19, 25, 6, (-35, 38, -28, 32), -12, 1, True, True, crack_mode=2)
        vfx = f.layer()
        for ox, oy in [(-4, -5), (3, -6), (0, -7), (6, -3)]:
            vfx.px(20 + ox, 22 + oy, 7, PAL["P0"], EMIT_RGB["P0"])
        f.add_vfx(vfx)
    elif col in (2, 3):
        drop = 3 if col == 2 else 4
        _paint_hound_body(f, 20, 25 + drop, 4, (-55, 58, -50, 55), 10, 0, False, True, crack_mode=2)
    else:
        b = f.layer()
        b.poly([(7, 32), (14, 30), (16, 35), (8, 35)], 2)
        b.poly([(18, 31), (25, 31), (24, 35), (17, 35)], 1)
        b.poly([(27, 32), (33, 33), (32, 35), (27, 35)], 2)
        b.line(18, 31, 20, 31, 3)  # broken collar rim
        if col == 4:
            b.px(16, 32, 7, PAL["P1"], EMIT_RGB["P1"])
            b.px(21, 33, 7, PAL["P2"], EMIT_RGB["P2"])
        else:
            b.px(19, 34, 7, PAL["P3"], EMIT_RGB["P3"])
            b.px(12, 34, 7, PAL["P3"], EMIT_RGB["P3"])
        f.composite(b)
    f.finalize_outline()
    return f


# ==============================================================================
# 2. CREATURE: RUNE_WARDEN (48x48 native -> 96x96 cell -> 576x288)
# ==============================================================================
WARDEN_SHIELD_STAMP = [
    ".GGGGGGGG.",
    "GIIIIIIIIg",
    "GIIDCCDIIG",
    "GIDCCCCDIG",
    "GIDCC0CDIG",
    "GIDCCCCDIG",
    "GIIDCCDIIG",
    "GIIDCCDIIG",
    "GIIDCCDIIG",
    "GIIIDDIIIG",
    ".GIIIIIIg.",
    "..GIIIIg..",
    "...GGGG...",
]


def _paint_warden_body(f: PixelFrame, cx: int, cy: int, leg_l: int, leg_r: int,
                       lift_l: int, lift_r: int, shield_dx: int, shield_dy: int,
                       maul_deg: float, charge_glow: bool, draw_maul: bool = True,
                       visor_dim: bool = False) -> None:
    if draw_maul:
        arm_r = f.layer()
        sx_arm, sy_arm = cx + 7, cy - 3
        hx, hy = rot_pt(sx_arm, sy_arm, 7, 4, maul_deg)
        arm_r.line(sx_arm, sy_arm, hx, hy, 3, thickness=2)
        m0 = rot_pt(hx, hy, 2, -5, maul_deg)
        m1 = rot_pt(hx, hy, 2, 5, maul_deg)
        m2 = rot_pt(hx, hy, 7, 4, maul_deg)
        m3 = rot_pt(hx, hy, 7, -4, maul_deg)
        arm_r.poly([m0, m1, m2, m3], 1)
        rc_x, rc_y = rot_pt(hx, hy, 4, 0, maul_deg)
        arm_r.px(rc_x, rc_y, 6, PAL["C0"] if charge_glow else PAL["C1"],
                 EMIT_RGB["C0"] if charge_glow else EMIT_RGB["C1"])
        arm_r.px(rc_x, rc_y + 1, 6, PAL["C2"], EMIT_RGB["C2"])
        f.composite(arm_r, shade_shift=1)

    # Distinctly separated armored legs (feet at y=44)
    for is_front, l_off, l_lift in [(False, leg_r, lift_r), (True, leg_l, lift_l)]:
        leg = f.layer()
        hip_x = cx + (-5 if is_front else 4)
        knee_x = hip_x + l_off // 2
        foot_x = hip_x + l_off
        foot_y = min(44, 44 - l_lift)
        hip_y = min(foot_y - 6, cy + 7)
        knee_y = min(foot_y - 3, cy + 12)
        leg.poly([(hip_x - 2, hip_y), (hip_x + 3, hip_y), (knee_x + 3, knee_y + 1), (knee_x - 2, knee_y + 1)], 2 if not is_front else 1)
        leg.poly([(knee_x - 2, knee_y), (knee_x + 3, knee_y), (foot_x + 3, foot_y - 2), (foot_x - 2, foot_y - 2)], 2 if not is_front else 1)
        leg.rect(foot_x - 2, foot_y - 2, 7, 3, 1)
        leg.px(knee_x + 1, knee_y, 3)
        f.composite(leg, shade_shift=1 if not is_front else 0)

    # Broad torso + brass belt + glowing chest core
    torso = f.layer()
    torso.poly([(cx - 8, cy - 7), (cx + 8, cy - 7), (cx + 7, cy + 8), (cx - 7, cy + 8)], 2)
    torso.rect(cx - 7, cy + 5, 14, 3, 3)
    torso.rect(cx - 2, cy - 3, 4, 5, 6, PAL["C3"] if visor_dim else PAL["C2"],
               EMIT_RGB["C3"] if visor_dim else EMIT_RGB["C2"])
    torso.px(cx, cy - 1, 6, PAL["C1"] if visor_dim else PAL["C0"],
             EMIT_RGB["C1"] if visor_dim else EMIT_RGB["C0"])
    f.composite(torso, cast_shadow_on_prev=True)

    # Heavy pauldrons & horned bucket helm
    helm = f.layer()
    helm.poly([(cx - 11, cy - 8), (cx - 4, cy - 10), (cx - 4, cy - 2), (cx - 11, cy - 3)], 1)
    helm.poly([(cx + 4, cy - 10), (cx + 11, cy - 8), (cx + 10, cy - 3), (cx + 4, cy - 2)], 1)
    helm.line(cx - 11, cy - 8, cx - 5, cy - 10, 3)
    helm.line(cx + 5, cy - 10, cx + 11, cy - 8, 3)
    helm.poly([(cx - 5, cy - 16), (cx + 5, cy - 16), (cx + 6, cy - 8), (cx - 6, cy - 8)], 1)
    helm.line(cx - 5, cy - 14, cx - 8, cy - 19, 3)
    helm.line(cx + 5, cy - 14, cx + 8, cy - 19, 3)
    vcol = "C2" if visor_dim else "C1"
    helm.line(cx - 2, cy - 12, cx + 4, cy - 12, 6, PAL[vcol], EMIT_RGB[vcol])
    if not visor_dim:
        helm.px(cx + 2, cy - 12, 6, PAL["C0"], EMIT_RGB["C0"])
    f.composite(helm, cast_shadow_on_prev=True)

    # Front tower shield
    sh = f.layer()
    s_cmap = {
        "G": (3, "G1", None),
        "g": (3, "G2", None),
        "I": (1, None, None),
        "D": (2, None, None),
        "C": (6, "C0" if charge_glow else ("C2" if visor_dim else "C1"),
              "C0" if charge_glow else ("C2" if visor_dim else "C1")),
        "0": (6, "C0" if not visor_dim else "C1", "C0" if not visor_dim else "C1"),
    }
    sh.stamp(cx + 1 + shield_dx, cy - 4 + shield_dy, WARDEN_SHIELD_STAMP, s_cmap)
    f.composite(sh, cast_shadow_on_prev=True)


def draw_rune_warden(row: int, col: int) -> PixelFrame:
    f = PixelFrame(48, 48)
    if row == 2:
        return _warden_down(f, col)

    if row == 0:
        bobs = [1, 0, -1, 1, 0, -1]
        leg_l = [-4, -2, 2, 5, 2, -2]
        leg_r = [5, 2, -2, -4, -2, 2]
        lift_l = [0, 0, 2, 0, 0, 1]
        lift_r = [0, 1, 0, 0, 2, 0]
        shield_dx = [0, 1, 1, 0, -1, 0][col]
        shield_dy = [0, -1, 0, 1, 0, -1][col]
        maul_deg = [-16, -28, -8, 16, 26, 4][col]
        slam_vfx = False
        charge_glow = False
    else:
        bobs = [1, -2, -2, 4, 3, 1]
        leg_l = [-3, -4, -4, 4, 3, 0]
        leg_r = [3, 4, 4, -3, -3, 0]
        lift_l = [0, 0, 0, 0, 0, 0]
        lift_r = [0, 0, 0, 0, 0, 0]
        shield_dx = [-1, 0, 1, 4, 3, 1][col]
        shield_dy = [-3, -7, -8, 5, 4, 0][col]
        maul_deg = [-42, -78, -92, 58, 50, 8][col]
        slam_vfx = col in (3, 4)
        charge_glow = col in (1, 2)

    _paint_warden_body(f, 20, 25 + bobs[col], leg_l[col], leg_r[col], lift_l[col], lift_r[col],
                       shield_dx, shield_dy, maul_deg, charge_glow)
    f.finalize_outline()

    if slam_vfx:
        vfx = f.layer()
        if col == 3:
            vfx.line(23, 43, 44, 43, 6, PAL["C0"], EMIT_RGB["C0"], thickness=2)
            vfx.line(26, 40, 32, 35, 6, PAL["C1"], EMIT_RGB["C1"])
            vfx.line(36, 40, 42, 35, 6, PAL["C1"], EMIT_RGB["C1"])
            vfx.px(45, 41, 6, PAL["C0"], EMIT_RGB["C0"])
        else:
            vfx.line(20, 44, 26, 42, 6, PAL["C2"], EMIT_RGB["C2"])
            vfx.line(39, 42, 45, 44, 6, PAL["C2"], EMIT_RGB["C2"])
            vfx.px(43, 38, 6, PAL["C1"], EMIT_RGB["C1"])
        f.add_vfx(vfx)
    return f


def _warden_down(f: PixelFrame, col: int) -> PixelFrame:
    if col == 0:
        _paint_warden_body(f, 19, 25, -2, 2, 0, 0, -1, -1, 35, False, visor_dim=True)
    elif col == 1:
        _paint_warden_body(f, 18, 27, -3, 3, 0, 0, 0, 1, 55, True, visor_dim=False)
        vfx = f.layer()
        vfx.line(15, 22, 22, 29, 6, PAL["C0"], EMIT_RGB["C0"])
        vfx.px(21, 13, 6, PAL["C1"], EMIT_RGB["C1"])
        f.add_vfx(vfx)
    elif col in (2, 3):
        drop = 4 if col == 2 else 7
        _paint_warden_body(f, 19, 24 + drop, -4, 4, 0, 0, 2, 2, 72, False, draw_maul=False, visor_dim=True)
    else:
        b = f.layer()
        b.poly([(10, 35), (21, 34), (22, 43), (9, 44)], 2)
        b.rect(13, 30, 8, 6, 1)
        b.line(13, 31, 11, 28, 3)  # broken horn
        b.poly([(23, 35), (37, 36), (38, 44), (22, 44)], 1)
        b.line(23, 35, 37, 36, 3)
        if col == 4:
            b.line(27, 40, 33, 40, 6, PAL["C2"], EMIT_RGB["C2"])
            b.px(18, 33, 6, PAL["C3"], EMIT_RGB["C3"])
        else:
            b.px(29, 40, 6, PAL["C3"], EMIT_RGB["C3"])
            b.px(31, 40, 6, PAL["C3"], EMIT_RGB["C3"])
        f.composite(b)
    f.finalize_outline()
    return f


# ==============================================================================
# 3. CREATURE: ASTRAL_PRISM (48x48 native -> 96x96 cell -> 576x288)
# ==============================================================================
def draw_astral_prism(row: int, col: int) -> PixelFrame:
    f = PixelFrame(48, 48)
    if row == 2:
        return _prism_down(f, col)

    cx, cy = 24, 21
    orbit_ang = col * (math.tau / 6.0)
    recoil = -2 if (row == 1 and col == 3) else 0
    cx += recoil

    sats: list[tuple[float, int, int, int]] = []
    for k in range(4):
        ang = orbit_ang + k * (math.tau / 4.0)
        if row == 1 and col in (1, 2, 3):
            # Angled prism focus wings + twin forward emitters!
            offsets = [(8, -11), (13, -4), (13, 4), (8, 11)]
            sats.append((1.0, cx + offsets[k][0], cy + offsets[k][1], 1))
        else:
            sx = int(round(cx + math.cos(ang) * 16.0))
            sy = int(round(cy + math.sin(ang) * 6.5))
            sats.append((math.sin(ang), sx, sy, 0))

    def draw_sat(buf: LayerBuffer, sx: int, sy: int, focused: bool) -> None:
        if focused:
            buf.poly([(sx - 2, sy - 3), (sx + 4, sy), (sx - 2, sy + 3), (sx - 3, sy)], 6, PAL["C1"], EMIT_RGB["C1"])
            buf.px(sx, sy, 6, PAL["C0"], EMIT_RGB["C0"])
        else:
            buf.poly([(sx, sy - 4), (sx + 3, sy), (sx, sy + 4), (sx - 3, sy)], 7)
            buf.px(sx - 1, sy - 1, 6, PAL["C1"], EMIT_RGB["C1"])
            buf.px(sx, sy, 6, PAL["C0"], EMIT_RGB["C0"])

    def ring_pt(deg: int) -> tuple[int, int]:
        rad = math.radians(deg)
        return int(round(cx + math.cos(rad) * 14.0)), int(round(cy + math.sin(rad) * 5.0 - math.cos(rad) * 3.0))

    # 1. Back half of astrolabe ring (continuous 4-deg steps) + back satellites
    back_ring = f.layer()
    for step in range(180, 360, 4):
        rx, ry = ring_pt(step)
        back_ring.px(rx, ry, 3)
        back_ring.px(rx, ry + 1, 3)
    for sz, sx, sy, foc in sats:
        if sz < 0:
            draw_sat(back_ring, sx, sy, foc > 0)
    f.composite(back_ring, shade_shift=1)

    # 2. Central Sculpted Faceted Octahedron Crystal
    prism = f.layer()
    prism.poly([(cx, cy - 14), (cx - 9, cy), (cx, cy + 14), (cx - 1, cy)], 6, PAL["C1"], EMIT_RGB["C2"])
    prism.poly([(cx, cy - 14), (cx + 9, cy), (cx, cy + 14), (cx + 1, cy)], 7, PAL["P2"], None)
    prism.line(cx, cy - 13, cx - 7, cy - 1, 6, PAL["C0"], EMIT_RGB["C1"])
    prism.line(cx, cy - 13, cx, cy + 13, 6, PAL["C0"], EMIT_RGB["C0"])
    prism.line(cx + 1, cy - 11, cx + 8, cy, 7, PAL["P3"], None)
    prism.rect(cx - 2, cy - 15, 5, 3, 3)
    prism.rect(cx - 2, cy + 13, 5, 3, 3)
    flare = (row == 1 and col in (1, 2, 3)) or (row == 0 and col in (0, 3))
    prism.disc(cx, cy, 3.0 if flare else 2.2, 6, PAL["P1"], EMIT_RGB["P1"])
    prism.disc(cx, cy, 1.8 if flare else 1.2, 6, PAL["C0"], EMIT_RGB["C0"])
    f.composite(prism)

    # 3. Front continuous astrolabe ring + front satellites
    front = f.layer()
    for step in range(0, 180, 4):
        rx, ry = ring_pt(step)
        front.px(rx, ry, 3)
        front.px(rx, ry + 1, 3)
    for sz, sx, sy, foc in sats:
        if sz >= 0:
            draw_sat(front, sx, sy, foc > 0)
    f.composite(front, cast_shadow_on_prev=True)

    f.finalize_outline()

    if row == 1 and col in (2, 3, 4):
        vfx = f.layer()
        if col == 2:
            vfx.disc(cx + 16, cy, 2.5, 6, PAL["C0"], EMIT_RGB["C0"])
            vfx.line(cx + 12, cy - 8, cx + 16, cy, 6, PAL["C1"], EMIT_RGB["C1"])
            vfx.line(cx + 12, cy + 8, cx + 16, cy, 6, PAL["C1"], EMIT_RGB["C1"])
        elif col == 3:
            vfx.line(cx + 15, cy, 46, cy, 6, PAL["C0"], EMIT_RGB["C0"], thickness=2)
            vfx.line(cx + 17, cy - 2, 43, cy - 2, 7, PAL["P1"], EMIT_RGB["P1"])
            vfx.line(cx + 17, cy + 2, 43, cy + 2, 7, PAL["P1"], EMIT_RGB["P1"])
            vfx.disc(cx + 16, cy, 3.0, 6, PAL["C0"], EMIT_RGB["C0"])
        else:
            for mx, my in [(38, 19), (42, 21), (46, 22), (40, 24)]:
                vfx.px(mx, my, 6, PAL["C1"], EMIT_RGB["C1"])
        f.add_vfx(vfx)
    return f


def _prism_down(f: PixelFrame, col: int) -> PixelFrame:
    if col in (0, 1):
        jx = -1 if col == 0 else 1
        cx, cy = 24 + jx, 21
        b = f.layer()
        b.poly([(cx, cy - 13), (cx - 8, cy), (cx, cy + 13), (cx - 1, cy)], 6, PAL["C1"], EMIT_RGB["C1"])
        b.poly([(cx, cy - 13), (cx + 8, cy), (cx, cy + 13), (cx + 1, cy)], 7, PAL["P2"], EMIT_RGB["P2"] if col == 1 else None)
        b.rect(cx - 2, cy - 14, 5, 3, 3)
        b.rect(cx - 2, cy + 12, 5, 3, 3)
        b.line(cx - 5, cy - 4, cx + 4, cy + 5, 6, PAL["C0"], EMIT_RGB["C0"])
        b.line(10, 19, 16, 16, 3, thickness=2)
        b.line(32, 25, 38, 22, 3, thickness=2)
        f.composite(b)
    elif col == 2:
        vfx = f.layer()
        for ang in range(0, 360, 45):
            ex, ey = rot_pt(24, 22, 13, 0, ang)
            vfx.line(24, 22, ex, ey, 6, PAL["C0"], EMIT_RGB["C0"])
        vfx.disc(24, 22, 4.5, 7, PAL["P1"], EMIT_RGB["P1"])
        f.add_vfx(vfx)
        return f
    elif col == 3:
        b = f.layer()
        for sx, sy in [(14, 26), (22, 31), (31, 25), (26, 19)]:
            b.poly([(sx, sy - 3), (sx + 3, sy), (sx, sy + 3), (sx - 2, sy)], 6, PAL["C1"], EMIT_RGB["C1"])
        b.line(13, 35, 20, 37, 3, thickness=2)
        b.line(27, 37, 34, 34, 3, thickness=2)
        f.composite(b)
    else:
        b = f.layer()
        b.poly([(13, 36), (17, 34), (19, 39), (14, 40)], 6, PAL["C2"] if col == 4 else PAL["C3"], EMIT_RGB["C2"] if col == 4 else EMIT_RGB["C3"])
        b.poly([(22, 37), (26, 35), (27, 40), (21, 40)], 7, PAL["P2"] if col == 4 else PAL["P3"], EMIT_RGB["P2"] if col == 4 else None)
        b.poly([(30, 36), (34, 37), (33, 40), (29, 39)], 3)
        b.line(18, 39, 25, 40, 3)
        f.composite(b)
    f.finalize_outline()
    return f


# ==============================================================================
# 4. CREATURE: RIFT_BOMBER (40x40 native -> 80x80 cell -> 480x240)
# ==============================================================================
def _paint_bomber_body(f: PixelFrame, cx: int, cy: int, leg_a: int, leg_b: int,
                       split: int, core_hot: bool, exhaust_x: int = 0) -> None:
    for is_front, lx_off in [(False, leg_b), (True, leg_a)]:
        leg = f.layer()
        hip_x = cx + (4 if is_front else -4)
        leg.line(hip_x, cy + 7, hip_x + lx_off, 31, 2 if not is_front else 1, thickness=2)
        leg.line(hip_x + lx_off, 31, hip_x + lx_off + 2, 35, 1, thickness=2)
        leg.px(hip_x + lx_off + 3, 35, 3)
        f.composite(leg, shade_shift=1 if not is_front else 0)

    core = f.layer()
    core.disc(cx, cy, 8 + split, 8, PAL["E2"], EMIT_RGB["E2"])
    core.disc(cx, cy, 6 + split, 8, PAL["E1"], EMIT_RGB["E1"])
    core.disc(cx + 1, cy - 1, 4 if core_hot else 3, 8, PAL["E0"], EMIT_RGB["E0"])
    f.composite(core, receive_outline=True)

    shell = f.layer()
    shell.poly([(cx - 10 - split, cy - 3), (cx - 7 - split // 2, cy - 8), (cx - 2 - split // 2, cy - 9),
                (cx - 1 - split // 2, cy - 2), (cx - 2 - split // 2, cy + 6), (cx - 8 - split, cy + 5)], 2)
    shell.poly([(cx + 2 + split // 2, cy - 9), (cx + 8 + split, cy - 7), (cx + 10 + split, cy - 2),
                (cx + 9 + split, cy + 4), (cx + 3 + split // 2, cy + 7), (cx + 2 + split // 2, cy - 1)], 1)
    shell.px(cx - 7 - split // 2, cy - 4, 3)  # brass rivet
    shell.px(cx + 6 + split // 2, cy + 3, 3)
    shell.rect(cx - 4, cy - 12 - split // 2, 8, 4, 3)
    shell.px(cx - 1, cy - 13 - split // 2, 8, PAL["E1"], EMIT_RGB["E1"])
    shell.px(cx + exhaust_x, cy - 15, 8, PAL["E0"], EMIT_RGB["E0"])
    shell.rect(cx - 6, cy + 5, 12, 3, 3)
    shell.rect(cx + 5 + split // 2, cy - 3, 3, 3, 8, PAL["E0"], EMIT_RGB["E0"])
    shell.px(cx + 7 + split // 2, cy - 2, 7, PAL["P0"], EMIT_RGB["P0"])
    f.composite(shell, cast_shadow_on_prev=True)


def draw_rift_bomber(row: int, col: int) -> PixelFrame:
    f = PixelFrame(40, 40)
    if row == 2:
        return _bomber_down(f, col)

    if row == 0:
        bob = [0, -1, 1, 0, -1, 1][col]
        dx = 0
        split = 1 if (col % 2 == 1) else 0
        leg_a = [3, 1, -2, -3, -1, 2][col]
        leg_b = [-3, -1, 2, 3, 1, -2][col]
        core_hot = (col % 2 == 1)
    else:
        bob = [1, -1, -2, 0, 1, 0][col]
        dx = [0, 0, -1, -2, -1, 0][col]
        split = [1, 2, 3, 2, 1, 0][col]
        leg_a = [-2, -3, 2, 3, 1, 0][col]
        leg_b = [2, 3, -2, -3, -1, 0][col]
        core_hot = col in (1, 2, 3)

    _paint_bomber_body(f, 19 + dx, 20 + bob, leg_a, leg_b, split, core_hot, (col % 3) - 1)
    f.finalize_outline()

    if row == 1 and col in (2, 3, 4):
        vfx = f.layer()
        ox = 19 + dx + 11 + (col - 2) * 3
        oy = 20 + bob - 2 - (col - 2)
        vfx.disc(ox, oy, 2.5 if col == 2 else 2.0, 8, PAL["E1"], EMIT_RGB["E1"])
        vfx.px(ox, oy, 8, PAL["E0"], EMIT_RGB["E0"])
        if col == 3:
            vfx.px(ox - 4, oy + 1, 7, PAL["P1"], EMIT_RGB["P1"])
        f.add_vfx(vfx)
    return f


def _bomber_down(f: PixelFrame, col: int) -> PixelFrame:
    if col in (0, 1):
        jx = -1 if col == 0 else 1
        jy = 0 if col == 0 else -1
        _paint_bomber_body(f, 19 + jx, 21 + jy, -2, 2, 2 + col, True, jx)
        vfx = f.layer()
        for ox, oy in [(-10, -7), (10, -7), (-11, 3), (11, 3), (0, -14)]:
            vfx.px(19 + ox + jx, 21 + oy + jy, 7, PAL["P1"], EMIT_RGB["P1"])
        f.add_vfx(vfx)
    elif col == 2:
        # Sharp outlined flying iron shell shards + jagged pixel explosion
        b = f.layer()
        b.poly([(5, 16), (10, 13), (12, 19), (7, 21)], 2)
        b.poly([(28, 12), (34, 15), (32, 21), (27, 18)], 1)
        b.rect(17, 30, 6, 4, 3)
        f.composite(b)
        vfx = f.layer()
        for ang in range(0, 360, 45):
            r = 12 if (ang % 90 == 0) else 8
            ex, ey = rot_pt(20, 20, r, 0, ang)
            vfx.line(20, 20, ex, ey, 8, PAL["E1"], EMIT_RGB["E1"], thickness=2)
        vfx.disc(20, 20, 6, 8, PAL["E0"], EMIT_RGB["E0"])
        vfx.disc(20, 20, 3, 7, PAL["P0"], EMIT_RGB["P0"])
        f.add_vfx(vfx)
    elif col == 3:
        b = f.layer()
        b.poly([(8, 24), (13, 21), (14, 28), (9, 29)], 2)
        b.poly([(26, 22), (31, 24), (30, 30), (25, 29)], 1)
        b.poly([(16, 30), (23, 30), (24, 35), (15, 35)], 3)
        f.composite(b)
        vfx = f.layer()
        for ang in range(15, 360, 45):
            ex, ey = rot_pt(20, 24, 12, 0, ang)
            vfx.px(ex, ey, 8, PAL["E2"], EMIT_RGB["E2"])
        vfx.disc(20, 26, 3.5, 8, PAL["E1"], EMIT_RGB["E1"])
        f.add_vfx(vfx)
    else:
        b = f.layer()
        b.poly([(9, 31), (15, 30), (16, 35), (8, 35)], 2)
        b.poly([(23, 30), (30, 32), (29, 35), (22, 35)], 1)
        b.rect(17, 32, 5, 3, 3)
        if col == 4:
            b.px(19, 33, 8, PAL["E1"], EMIT_RGB["E1"])
            b.px(13, 33, 8, PAL["E2"], EMIT_RGB["E2"])
        else:
            b.px(19, 34, 8, PAL["E2"], EMIT_RGB["E2"])
        f.composite(b)
    f.finalize_outline()
    return f


# ==============================================================================
# 5. CREATURE: VOID_HARVESTER (56x56 native -> 112x112 cell -> 672x336)
# ==============================================================================
def _paint_harvester_body(f: PixelFrame, cx: int, cy: int, stride: int, cape_wave: int,
                          scythe_deg: float, off_deg: float, drop_knees: int = 0,
                          core_dim: bool = False) -> None:
    def draw_scythe(buf: LayerBuffer, hx: int, hy: int, deg: float, scale_blade: float = 1.0) -> None:
        s0 = rot_pt(hx, hy, -7 * scale_blade, 2, deg)
        s1 = rot_pt(hx, hy, 11 * scale_blade, -3, deg)
        buf.line(s0[0], s0[1], s1[0], s1[1], 3, thickness=1)
        b1 = rot_pt(s1[0], s1[1], 4 * scale_blade, -5 * scale_blade, deg)
        b2 = rot_pt(s1[0], s1[1], 10 * scale_blade, -1 * scale_blade, deg)
        b3 = rot_pt(s1[0], s1[1], 12 * scale_blade, 7 * scale_blade, deg)
        b4 = rot_pt(s1[0], s1[1], 6 * scale_blade, 3 * scale_blade, deg)
        c_main = PAL["C2"] if core_dim else PAL["C1"]
        e_main = EMIT_RGB["C2"] if core_dim else EMIT_RGB["C1"]
        buf.poly([s1, b1, b2, b3, b4], 6, c_main, e_main)
        buf.line(s1[0], s1[1], b2[0], b2[1], 2)
        if not core_dim:
            buf.line(b1[0], b1[1], b3[0], b3[1], 6, PAL["C0"], EMIT_RGB["C0"])
            buf.line(b2[0], b2[1], b3[0], b3[1], 7, PAL["P1"], EMIT_RGB["P1"])

    # 1. Tattered billowing void cloak
    cape = f.layer()
    w1 = int(round(math.sin(cape_wave * math.tau / 6.0) * 2.0))
    w2 = int(round(math.cos(cape_wave * math.tau / 6.0) * 2.0))
    cape_pts = [
        (cx - 2, cy - 8),
        (cx - 12, cy - 2 + w1),
        (cx - 17, cy + 12 + w2),
        (cx - 12, cy + 16 + w1),
        (cx - 9, cy + 12),
        (cx - 6, cy + 17 + w2),
        (cx - 2, cy + 9),
    ]
    cape.poly(cape_pts, 4)
    f.composite(cape, shade_shift=0)

    # 2. Offhand scythe
    off_s = f.layer()
    draw_scythe(off_s, cx + 6, cy + 1, off_deg, 0.85)
    f.composite(off_s, shade_shift=1)

    # 3. Wide predatory legs (feet at y=50)
    for is_front, st in [(False, -stride), (True, stride)]:
        leg = f.layer()
        hip_x = cx + (-3 if is_front else 3)
        kx = hip_x + st // 2 + (2 if is_front else 0)
        fx = hip_x + st
        knee_y = min(46, cy + 17 + drop_knees // 2)
        leg.line(hip_x, cy + 10, kx, knee_y, 2 if not is_front else 1, thickness=2)
        leg.line(kx, knee_y, fx, 49, 2 if not is_front else 1, thickness=2)
        leg.rect(fx - 1, 48, 5, 3, 1)
        leg.px(kx, knee_y, 3)
        f.composite(leg, shade_shift=1 if not is_front else 0)

    # 4. Reaper torso, pauldrons & horned helm
    body = f.layer()
    body.poly([(cx - 5, cy - 8), (cx + 6, cy - 8), (cx + 4, cy + 10), (cx - 4, cy + 10)], 2)
    body.poly([(cx - 3, cy + 9), (cx + 4, cy + 9), (cx + 3, cy + 17), (cx - 2, cy + 16)], 4)
    body.line(cx - 4, cy - 4, cx + 5, cy - 4, 3)
    pcol = "P2" if core_dim else "P1"
    body.rect(cx - 1, cy - 3, 4, 5, 7, PAL[pcol], EMIT_RGB[pcol])
    if not core_dim:
        body.px(cx + 1, cy - 1, 7, PAL["P0"], EMIT_RGB["P0"])
    body.poly([(cx - 9, cy - 10), (cx - 2, cy - 11), (cx - 2, cy - 5), (cx - 8, cy - 5)], 1)
    body.poly([(cx + 2, cy - 11), (cx + 9, cy - 9), (cx + 8, cy - 5), (cx + 2, cy - 5)], 1)
    body.px(cx - 9, cy - 11, 3)
    body.px(cx + 9, cy - 10, 3)
    body.poly([(cx - 3, cy - 18), (cx + 4, cy - 18), (cx + 6, cy - 11), (cx - 4, cy - 10)], 2)
    body.line(cx - 2, cy - 17, cx - 7, cy - 22, 1)
    body.line(cx + 3, cy - 17, cx + 6, cy - 22, 3)
    body.line(cx + 1, cy - 14, cx + 5, cy - 14, 7, PAL["P2"] if core_dim else PAL["P0"],
              EMIT_RGB["P2"] if core_dim else EMIT_RGB["P0"])
    if not core_dim:
        body.px(cx + 3, cy - 14, 6, PAL["C0"], EMIT_RGB["C0"])
    f.composite(body, cast_shadow_on_prev=True)

    # 5. Main scythe arm
    main_s = f.layer()
    ax, ay = cx - 1, cy - 3
    hx, hy = rot_pt(ax, ay, 7, 3, scythe_deg * 0.45)
    main_s.line(ax, ay, hx, hy, 1, thickness=2)
    draw_scythe(main_s, hx, hy, scythe_deg, 1.05)
    f.composite(main_s, cast_shadow_on_prev=True)


def draw_void_harvester(row: int, col: int) -> PixelFrame:
    f = PixelFrame(56, 56)
    if row == 2:
        return _harvester_down(f, col)

    if row == 0:
        bob = [0, -1, 0, 1, 0, -1][col]
        dx = 0
        stride = [-6, -2, 3, 6, 2, -3][col]
        cape_wave = col
        scythe_deg = [-8, -14, -10, -4, 0, -4][col]
        off_deg = [18, 22, 16, 10, 8, 12][col]
        slash_phase = 0
    else:
        bob = [2, 2, 0, 0, 1, 0][col]
        dx = [-2, -2, 3, 4, 2, 0][col]
        stride = [-3, -4, 5, 4, 2, 0][col]
        cape_wave = (col * 2) % 6
        scythe_deg = [-44, -55, 35, 58, 40, -5][col]
        off_deg = [35, 50, 20, -45, -18, 12][col]
        slash_phase = col if col in (2, 3, 4) else 0

    _paint_harvester_body(f, 22 + dx, 26 + bob, stride, cape_wave, scythe_deg, off_deg)
    f.finalize_outline()

    if slash_phase:
        vfx = f.layer()
        if slash_phase == 2:
            vfx.line(29, 10, 46, 22, 6, PAL["C0"], EMIT_RGB["C0"], thickness=2)
            vfx.line(46, 22, 50, 37, 6, PAL["C1"], EMIT_RGB["C1"], thickness=2)
            vfx.line(33, 16, 47, 34, 7, PAL["P1"], EMIT_RGB["P1"])
        elif slash_phase == 3:
            vfx.line(34, 17, 51, 29, 7, PAL["P0"], EMIT_RGB["P0"], thickness=2)
            vfx.line(51, 29, 43, 43, 6, PAL["C1"], EMIT_RGB["C1"], thickness=2)
        else:
            vfx.px(47, 32, 6, PAL["C1"], EMIT_RGB["C1"])
            vfx.px(43, 40, 7, PAL["P1"], EMIT_RGB["P1"])
        f.add_vfx(vfx)
    return f


def _harvester_down(f: PixelFrame, col: int) -> PixelFrame:
    if col == 0:
        _paint_harvester_body(f, 21, 25, 3, 1, 25, 40, drop_knees=2, core_dim=False)
        vfx = f.layer()
        vfx.px(26, 22, 7, PAL["P0"], EMIT_RGB["P0"])
        vfx.px(19, 25, 6, PAL["C0"], EMIT_RGB["C0"])
        f.add_vfx(vfx)
    elif col in (1, 2):
        drop = 4 if col == 1 else 7
        _paint_harvester_body(f, 21, 24 + drop, 5, 3, 40, 52, drop_knees=drop, core_dim=True)
    else:
        b = f.layer()
        b.poly([(11, 41), (25, 39), (32, 47), (10, 49)], 4)
        b.poly([(21, 40), (31, 41), (32, 48), (20, 49)], 2)
        b.rect(28, 38, 8, 7, 2)
        b.line(29, 39, 26, 36, 3)  # fallen helm horn
        b.line(18, 48, 43, 48, 3)
        b.poly([(41, 44), (47, 46), (45, 50), (41, 49)], 6, PAL["C2"] if col == 4 else PAL["C3"],
               EMIT_RGB["C2"] if col == 4 else None)
        b.px(26, 44, 7, PAL["P2"] if col == 4 else PAL["P3"],
             EMIT_RGB["P2"] if col == 4 else EMIT_RGB["P3"])
        f.composite(b)
    f.finalize_outline()
    return f


# ==============================================================================
# 6. CREATURE: COLOSSUS (72x72 native -> 144x144 cell -> 864x432) — 3-Phase Boss!
# ==============================================================================
def _paint_colossus_body(f: PixelFrame, cx: int, cy: int, stride: int, crys_bob: int,
                         halo_phase: int, sword_deg: float, fist_deg: float,
                         draw_halo: bool = True, draw_arms: bool = True,
                         core_dim: bool = False) -> None:
    if draw_halo:
        halo = f.layer()
        hc_x, hc_y = cx, cy - 11
        for deg in range(195, 346, 7):
            rad = math.radians(deg)
            rx = int(round(hc_x + math.cos(rad) * 21.0))
            ry = int(round(hc_y + math.sin(rad) * 19.0))
            halo.px(rx, ry, 3)
            halo.px(rx, ry - 1, 3)
        for ni, ndeg in enumerate([202, 236, 270, 304, 338]):
            rad = math.radians(ndeg)
            nx = int(round(hc_x + math.cos(rad) * 21.0))
            ny = int(round(hc_y + math.sin(rad) * 19.0))
            lit = (ni == (halo_phase % 5)) and not core_dim
            halo.disc(nx, ny, 1.5, 6, PAL["C0"] if lit else PAL["G0"],
                      EMIT_RGB["C0"] if lit else EMIT_RGB["G1"])
        f.composite(halo)

    if draw_arms:
        back_arm = f.layer()
        bx0, by0 = cx + 12, cy - 8
        fx, fy = rot_pt(bx0, by0, 11, 10, fist_deg)
        back_arm.line(bx0, by0, fx, fy, 2, thickness=4)
        back_arm.rect(fx - 4, fy - 4, 8, 8, 1)
        back_arm.px(fx + 2, fy, 6, PAL["C1"], EMIT_RGB["C1"])
        f.composite(back_arm, shade_shift=1)

    # Widely planted, heavily armored greaves with clear stance gap (feet at y=66)
    for is_front, st in [(False, -stride), (True, stride)]:
        leg = f.layer()
        hip_x = cx + (-6 if is_front else 6)
        knee_x = hip_x + st // 2 + (-1 if is_front else 1)
        foot_x = hip_x + st + (-1 if is_front else 1)
        hip_y = min(54, cy + 12)
        knee_y = min(59, cy + 21)
        leg.poly([(hip_x - 3, hip_y), (hip_x + 3, hip_y), (knee_x + 3, knee_y + 1), (knee_x - 3, knee_y + 1)], 2 if not is_front else 1)
        leg.poly([(knee_x - 3, knee_y), (knee_x + 4, knee_y), (foot_x + 4, 64), (foot_x - 4, 64)], 2 if not is_front else 1)
        leg.rect(foot_x - 4, 63, 9, 4, 1)
        leg.rect(knee_x - 2, knee_y - 1, 5, 3, 3)
        leg.px(foot_x, 66, 6, PAL["C1"], EMIT_RGB["C1"])
        f.composite(leg, shade_shift=1 if not is_front else 0)

    # Sculpted V-tapered chestplate + flared armored tassets + hexagonal reactor
    torso = f.layer()
    torso.poly([(cx - 13, cy - 11), (cx + 13, cy - 11), (cx + 8, cy + 11), (cx - 8, cy + 11)], 2)
    torso.poly([(cx - 11, cy - 9), (cx - 3, cy - 9), (cx - 4, cy + 4), (cx - 8, cy + 4)], 1)
    torso.poly([(cx + 3, cy - 9), (cx + 11, cy - 9), (cx + 8, cy + 4), (cx + 4, cy + 4)], 1)
    torso.rect(cx - 8, cy + 9, 16, 4, 3)
    # Flared side armor tassets
    tas_bot = min(63, cy + 20)
    tab_bot = min(65, cy + 26)
    torso.poly([(cx - 9, cy + 12), (cx - 4, cy + 12), (cx - 6, tas_bot), (cx - 11, tas_bot - 1)], 1)
    torso.poly([(cx + 4, cy + 12), (cx + 9, cy + 12), (cx + 11, tas_bot - 1), (cx + 6, tas_bot)], 1)
    # Central void tabard
    torso.poly([(cx - 4, cy + 13), (cx + 4, cy + 13), (cx + 3, tab_bot - 2), (cx, tab_bot), (cx - 3, tab_bot - 2)], 4)
    torso.line(cx, cy + 15, cx, min(63, cy + 23), 6, PAL["C2"], EMIT_RGB["C2"])
    # Hexagonal reactor core
    torso.poly([(cx, cy - 7), (cx + 5, cy - 3), (cx + 5, cy + 2), (cx, cy + 6), (cx - 5, cy + 2), (cx - 5, cy - 3)], 3)
    torso.poly([(cx, cy - 5), (cx + 3, cy - 2), (cx + 3, cy + 1), (cx, cy + 4), (cx - 3, cy + 1), (cx - 3, cy - 2)],
               6, PAL["C2"] if core_dim else PAL["C1"], EMIT_RGB["C2"] if core_dim else EMIT_RGB["C1"])
    if not core_dim:
        torso.disc(cx, cy - 1, 2.0, 6, PAL["C0"], EMIT_RGB["C0"])
    f.composite(torso, cast_shadow_on_prev=True)

    # Monumental tiered pauldrons, crowned helm & floating shoulder crystals
    upper = f.layer()
    upper.poly([(cx - 20, cy - 14), (cx - 8, cy - 16), (cx - 7, cy - 5), (cx - 18, cy - 6)], 1)
    upper.poly([(cx + 8, cy - 16), (cx + 20, cy - 14), (cx + 18, cy - 6), (cx + 7, cy - 5)], 1)
    upper.line(cx - 20, cy - 14, cx - 8, cy - 16, 3, thickness=2)
    upper.line(cx + 8, cy - 16, cx + 20, cy - 14, 3, thickness=2)
    upper.poly([(cx - 5, cy - 23), (cx + 5, cy - 23), (cx + 6, cy - 13), (cx - 6, cy - 13)], 2)
    upper.line(cx - 5, cy - 21, cx - 8, cy - 27, 3, thickness=2)
    upper.line(cx + 5, cy - 21, cx + 8, cy - 27, 3, thickness=2)
    upper.px(cx, cy - 22, 7, PAL["P0"], EMIT_RGB["P0"])
    upper.line(cx - 3, cy - 18, cx - 1, cy - 18, 6, PAL["C2"] if core_dim else PAL["C0"],
               EMIT_RGB["C2"] if core_dim else EMIT_RGB["C0"])
    upper.line(cx + 2, cy - 18, cx + 4, cy - 18, 6, PAL["C2"] if core_dim else PAL["C0"],
               EMIT_RGB["C2"] if core_dim else EMIT_RGB["C0"])
    if not core_dim:
        for sx_off, cb in [(-15, crys_bob), (15, -crys_bob)]:
            sx = cx + sx_off
            sy = cy - 22 + cb
            upper.poly([(sx, sy - 5), (sx + 3, sy), (sx, sy + 5), (sx - 3, sy)], 6, PAL["C1"], EMIT_RGB["C1"])
            upper.line(sx, sy - 4, sx, sy + 3, 6, PAL["C0"], EMIT_RGB["C0"])
    f.composite(upper, cast_shadow_on_prev=True)

    if draw_arms:
        front_arm = f.layer()
        ax0, ay0 = cx - 12, cy - 8
        hx, hy = rot_pt(ax0, ay0, 7, 13, sword_deg * 0.35)
        front_arm.line(ax0, ay0, hx, hy, 1, thickness=4)
        front_arm.rect(hx - 3, hy - 3, 7, 6, 3)
        g0 = rot_pt(hx, hy, 2, -5, sword_deg)
        g1 = rot_pt(hx, hy, 2, 5, sword_deg)
        front_arm.line(g0[0], g0[1], g1[0], g1[1], 3, thickness=2)
        tip = rot_pt(hx, hy, 26, 0, sword_deg)
        b_top = rot_pt(hx, hy, 21, -3, sword_deg)
        b_bot = rot_pt(hx, hy, 21, 3, sword_deg)
        b_base0 = rot_pt(hx, hy, 4, -2, sword_deg)
        b_base1 = rot_pt(hx, hy, 4, 2, sword_deg)
        front_arm.poly([b_base0, b_top, tip, b_bot, b_base1], 6, PAL["C1"], EMIT_RGB["C1"])
        c_tip = rot_pt(hx, hy, 4, 0, sword_deg)
        front_arm.line(c_tip[0], c_tip[1], tip[0], tip[1], 6, PAL["C0"], EMIT_RGB["C0"])
        f.composite(front_arm, cast_shadow_on_prev=True)


def draw_colossus(row: int, col: int) -> PixelFrame:
    f = PixelFrame(72, 72)
    if row == 2:
        return _colossus_down(f, col)

    if row == 0:
        bob = [0, -1, -1, 0, 1, 0][col]
        stride = [-4, -2, 2, 4, 2, -2][col]
        crys_bob = [0, -1, -2, -1, 0, 1][col]
        halo_phase = col
        # Ready diagonal battle angle so chest reactor & tabard shine clearly
        sword_deg = [26, 22, 20, 26, 30, 28][col]
        fist_deg = [-8, -14, -10, -2, 4, -2][col]
        slam_vfx = 0
    else:
        bob = [0, -1, -2, 3, 2, 0][col]
        stride = [-3, -4, -2, 4, 3, 0][col]
        crys_bob = [-1, -2, -2, 2, 1, 0][col]
        halo_phase = col
        sword_deg = [-54, -92, -98, 48, 42, 24][col]
        fist_deg = [-46, -86, -92, 52, 46, 0][col]
        slam_vfx = col if col in (2, 3, 4) else 0

    _paint_colossus_body(f, 32, 35 + bob, stride, crys_bob, halo_phase, sword_deg, fist_deg)
    f.finalize_outline()

    if slam_vfx:
        vfx = f.layer()
        if slam_vfx == 2:
            vfx.line(41, 8, 59, 26, 6, PAL["C0"], EMIT_RGB["C0"], thickness=2)
            vfx.line(45, 14, 61, 34, 7, PAL["P1"], EMIT_RGB["P1"])
        elif slam_vfx == 3:
            vfx.line(39, 63, 68, 63, 6, PAL["C0"], EMIT_RGB["C0"], thickness=3)
            vfx.line(47, 61, 66, 47, 6, PAL["C1"], EMIT_RGB["C1"], thickness=2)
            vfx.line(43, 59, 55, 39, 7, PAL["P0"], EMIT_RGB["P0"], thickness=2)
            vfx.disc(55, 63, 4.5, 6, PAL["C0"], EMIT_RGB["C0"])
        else:
            for mx, my in [(44, 59), (53, 55), (62, 60), (57, 50), (66, 64)]:
                vfx.px(mx, my, 6, PAL["C1"], EMIT_RGB["C1"])
        f.add_vfx(vfx)
    return f


def _colossus_down(f: PixelFrame, col: int) -> PixelFrame:
    if col == 0:
        _paint_colossus_body(f, 32, 35, 3, 0, 0, 35, 15, draw_halo=True, core_dim=False)
        vfx = f.layer()
        vfx.line(25, 28, 39, 40, 7, PAL["P0"], EMIT_RGB["P0"])
        vfx.line(37, 27, 27, 42, 6, PAL["C0"], EMIT_RGB["C0"])
        f.add_vfx(vfx)
    elif col == 1:
        _paint_colossus_body(f, 32, 37, 4, 1, 2, 50, 35, draw_halo=False, core_dim=True)
        b = f.layer()
        b.line(16, 12, 24, 9, 3, thickness=2)
        b.line(41, 10, 49, 14, 3, thickness=2)
        f.composite(b)
    elif col in (2, 3):
        drop = 5 if col == 2 else 10
        _paint_colossus_body(f, 32, 34 + drop, 5, 0, 0, 72, 60, draw_halo=False, draw_arms=False, core_dim=True)
        b = f.layer()
        b.line(46, 36 + drop, 53, 65, 6, PAL["C2"], EMIT_RGB["C2"], thickness=2)
        f.composite(b)
    else:
        b = f.layer()
        b.poly([(15, 53), (27, 51), (29, 64), (13, 65)], 1)
        b.poly([(25, 50), (45, 52), (44, 64), (24, 64)], 2)
        b.poly([(42, 54), (54, 53), (56, 64), (41, 65)], 1)
        b.rect(30, 46, 10, 9, 2)
        b.line(30, 47, 25, 43, 3, thickness=2)
        b.line(40, 47, 45, 43, 3, thickness=2)
        b.line(18, 63, 31, 65, 3, thickness=2)
        b.line(49, 61, 62, 64, 3, thickness=2)
        if col == 4:
            b.disc(34, 58, 3.0, 6, PAL["C1"], EMIT_RGB["C1"])
            b.px(35, 51, 7, PAL["P1"], EMIT_RGB["P1"])
        else:
            b.disc(34, 58, 2.0, 7, PAL["P2"], EMIT_RGB["P2"])
            b.px(59, 63, 6, PAL["C3"], EMIT_RGB["C3"])
        f.composite(b)
    f.finalize_outline()
    return f


# ==============================================================================
# 7. RUINS TWIN-STATE ALTAR (64x64 native -> 4x NEAREST -> 256x256/frame -> 768x256)
# ==============================================================================
ALTAR_RUNE_GLYPHS = [
    ".C.",
    "CCC",
    ".C.",
    ".C.",
    "C.C",
    ".C.",
]


def draw_ruins_altar_frame(frame_idx: int) -> PixelFrame:
    """0 = dormant, 1 = active stasis (cyan), 2 = active overclock (gold/amber)."""
    f = PixelFrame(64, 64)
    cx, base_y = 32, 50

    if frame_idx == 0:
        rune_mat, r0, r1, r2 = 7, "P2", "P3", "P3"
        crys_hi, crys_mid, crys_lo = "C2", "C3", "P3"
        crys_y = 11
    elif frame_idx == 1:
        rune_mat, r0, r1, r2 = 6, "C0", "C1", "C2"
        crys_hi, crys_mid, crys_lo = "C0", "C1", "C2"
        crys_y = 8
    else:
        rune_mat, r0, r1, r2 = 8, "E0", "E1", "G1"
        crys_hi, crys_mid, crys_lo = "E0", "E1", "E2"
        crys_y = 8

    # 1. Stepped Basalt Dais Plinth (centered at cx=32, base_y=50)
    dais = f.layer()
    dais.disc(cx, base_y + 1, 22.0, 5, ry=9.0)
    dais.disc(cx, base_y - 1, 21.0, 5, ry=8.0)
    dais.disc(cx, base_y - 3, 15.0, 5, ry=6.0)
    for sx in (cx - 12, cx - 5, cx + 5, cx + 12):
        dais.line(sx, base_y + 2, sx + (1 if sx > cx else -1), base_y + 6, 5, PAL["S4"])
    for deg in range(0, 360, 15):
        rad = math.radians(deg)
        rx = int(round(cx + math.cos(rad) * 18.0))
        ry = int(round(base_y + math.sin(rad) * 6.8))
        dais.px(rx, ry, rune_mat, PAL[r1] if (deg % 30 == 0) else PAL[r2],
                EMIT_RGB[r1] if frame_idx > 0 else (EMIT_RGB[r2] if deg % 60 == 0 else None))
    f.composite(dais)

    # 2. Tiered Monolith Obelisk Spire with Clamping Bands & Masonry Seams
    spire = f.layer()
    spire.poly([(cx - 10, base_y - 3), (cx - 6, base_y - 14), (cx - 6, base_y - 2)], 5)
    spire.poly([(cx + 6, base_y - 14), (cx + 10, base_y - 3), (cx + 6, base_y - 2)], 5)
    spire.poly([(cx - 6, base_y - 3), (cx - 5, 19), (cx, 15), (cx + 5, 19), (cx + 6, base_y - 3)], 5)
    # Stone brick mortar seams for tactile basalt stonework
    spire.line(cx - 4, 21, cx + 4, 21, 5, PAL["S4"])
    spire.line(cx - 5, 33, cx + 5, 33, 5, PAL["S4"])
    # Bronze/Iron clamping bands
    spire.rect(cx - 6, 37, 13, 3, 3)
    spire.rect(cx - 5, 24, 11, 3, 3)
    spire.line(cx - 5, 19, cx - 6, 13, 5, thickness=2)
    spire.line(cx + 5, 19, cx + 6, 13, 5, thickness=2)
    spire.line(cx, 20, cx, 43, rune_mat, PAL[r1], EMIT_RGB[r1] if frame_idx > 0 else EMIT_RGB[r2], thickness=2)
    spire.line(cx, 22, cx, 42, rune_mat, PAL[r0], EMIT_RGB[r0] if frame_idx > 0 else EMIT_RGB[r2], thickness=1)
    spire.stamp(cx - 1, 29, ALTAR_RUNE_GLYPHS, {"C": (rune_mat, r0, r0 if frame_idx > 0 else r2)})
    f.composite(spire, cast_shadow_on_prev=True)

    # 3. Levitating Apex Crystal Diamond
    crys = f.layer()
    crys.poly([(cx, crys_y - 5), (cx + 4, crys_y), (cx, crys_y + 5), (cx - 4, crys_y)],
              rune_mat, PAL[crys_mid], EMIT_RGB[crys_mid])
    crys.poly([(cx, crys_y - 5), (cx, crys_y + 5), (cx - 4, crys_y)],
              rune_mat, PAL[crys_hi], EMIT_RGB[crys_hi])
    crys.line(cx, crys_y - 4, cx, crys_y + 4, rune_mat, PAL[crys_hi], EMIT_RGB[crys_hi])
    crys.line(cx + 1, crys_y, cx + 3, crys_y + 1, rune_mat, PAL[crys_lo], EMIT_RGB[crys_lo])
    f.composite(crys)

    f.finalize_outline()

    if frame_idx > 0:
        vfx = f.layer()
        vfx.line(cx - 7, crys_y, cx - 5, crys_y, rune_mat, PAL[r0], EMIT_RGB[r0])
        vfx.line(cx + 5, crys_y, cx + 7, crys_y, rune_mat, PAL[r0], EMIT_RGB[r0])
        vfx.px(cx, crys_y - 7, rune_mat, PAL[r0], EMIT_RGB[r0])
        motes = [(cx - 12, 22), (cx + 13, 27), (cx - 11, 35), (cx + 11, 17)]
        if frame_idx == 2:
            motes = [(cx - 13, 18), (cx + 12, 23), (cx - 10, 32), (cx + 13, 35), (cx - 7, 11), (cx + 8, 12)]
        for mx, my in motes:
            vfx.px(mx, my, rune_mat, PAL[r0], EMIT_RGB[r0])
            vfx.px(mx, my + 1, rune_mat, PAL[r1], EMIT_RGB[r1])
        f.add_vfx(vfx)
    return f


# ==============================================================================
# BUILD PIPELINE & VALIDATION
# ==============================================================================
CREATURES = [
    ("construct_hound", 40, 40, 2, draw_construct_hound),
    ("rune_warden", 48, 48, 2, draw_rune_warden),
    ("astral_prism", 48, 48, 2, draw_astral_prism),
    ("rift_bomber", 40, 40, 2, draw_rift_bomber),
    ("void_harvester", 56, 56, 2, draw_void_harvester),
    ("colossus", 72, 72, 2, draw_colossus),
]


def _save_nearest(arr: np.ndarray, scale: int, out_path: Path) -> Image.Image:
    im = Image.fromarray(arr)
    if scale > 1:
        im = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
    im.save(out_path, optimize=True)
    return im


def build_all() -> dict[str, float]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    anchors: dict[str, float] = {}

    for key, cw, ch, scale, drawer in CREATURES:
        sheet_rgba = np.zeros((ch * 3, cw * 6, 4), dtype=np.uint8)
        sheet_emit = np.zeros((ch * 3, cw * 6, 4), dtype=np.uint8)
        for row in range(3):
            for col in range(6):
                frame = drawer(row, col)
                y0, y1 = row * ch, (row + 1) * ch
                x0, x1 = col * cw, (col + 1) * cw
                sheet_rgba[y0:y1, x0:x1] = frame.rgba
                sheet_emit[y0:y1, x0:x1] = frame.emit
                assert frame.rgba[:, :, 3].max() > 0, f"Empty frame {key} ({row},{col})"
                # Verify strict binary pixel-art alpha (zero fuzzy anti-aliased alpha).
                uniq_alpha = set(np.unique(frame.rgba[:, :, 3]).tolist())
                assert uniq_alpha.issubset({0, 255}), f"Anti-aliased alpha found in {key}: {uniq_alpha}"

        out_albedo = OUT_DIR / f"creature_{key}.png"
        out_emit = OUT_DIR / f"creature_{key}_emit.png"
        im = _save_nearest(sheet_rgba, scale, out_albedo)
        _save_nearest(sheet_emit, scale, out_emit)

        sw, sh = im.size
        feet_vals = []
        for col in range(6):
            cell = im.crop((round(col * sw / 6), 0, round((col + 1) * sw / 6), round(sh / 3)))
            bounds = cell.getchannel("A").point(lambda a: 255 if a > 100 else 0).getbbox()
            feet_vals.append(bounds[3] / cell.height if bounds else 0.9)
        anchors[f"creature_{key}"] = round(median(feet_vals), 5)
        print(f"BUILT {out_albedo.name}: {im.size}, emit={out_emit.name}, anchor={anchors[f'creature_{key}']}")

    altar_rgba = np.zeros((64, 64 * 3, 4), dtype=np.uint8)
    altar_emit = np.zeros((64, 64 * 3, 4), dtype=np.uint8)
    for fi in range(3):
        fr = draw_ruins_altar_frame(fi)
        altar_rgba[:, fi * 64:(fi + 1) * 64] = fr.rgba
        altar_emit[:, fi * 64:(fi + 1) * 64] = fr.emit
    im_altar = _save_nearest(altar_rgba, 4, OUT_DIR / "ruins_altar.png")
    _save_nearest(altar_emit, 4, OUT_DIR / "ruins_altar_emit.png")
    assert im_altar.size == (768, 256), f"Expected 768x256 altar, got {im_altar.size}"
    print(f"BUILT ruins_altar.png: {im_altar.size}, emit=ruins_altar_emit.png")
    return anchors


if __name__ == "__main__":
    anchors = build_all()
    print("ANCHORS:", anchors)
