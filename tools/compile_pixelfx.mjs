#!/usr/bin/env node
// Offline sprite-sheet compiler powered by patch-gg/pixelfx (MIT).
// Renders Starfall Purple-Cyan-Gold / Dark Battlefield 64x64 horizontal transparent sheets into assets/v016/.

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  createFrame,
  clearFrame,
  createFx,
  composite,
  painterFor,
  Particles,
  Bits,
  Lights,
  P,
  B,
  Rng,
  fit,
  rng,
  clamp,
  smooth,
  ease,
  rand,
  flare,
  sparkle,
  band,
  TAU,
  WHITE,
} from "./vendor/pixelfx/src/core/index.js";
import { encodePNG } from "./vendor/pixelfx/tools/lib/png.mjs";
import { bowed, zigzag, stroke, crackle } from "./vendor/pixelfx/src/fx/lightning/_lib.js";
import { spikes, star, brokenRing } from "./vendor/pixelfx/src/fx/impacts/_lib.js";

import * as swordSlash from "./vendor/pixelfx/src/fx/melee/sword-slash.js";
import * as plasmaExplosion from "./vendor/pixelfx/src/fx/explosions/plasma-explosion.js";
import * as manaBurst from "./vendor/pixelfx/src/fx/arcane/mana-burst.js";
import * as zapHit from "./vendor/pixelfx/src/fx/lightning/zap-hit.js";
import * as frostNova from "./vendor/pixelfx/src/fx/ice/frost-nova.js";
import * as snowflakeBurst from "./vendor/pixelfx/src/fx/ice/snowflake-burst.js";
import * as hitSpark from "./vendor/pixelfx/src/fx/impacts/hit-spark.js";
import * as critHit from "./vendor/pixelfx/src/fx/impacts/crit-hit.js";
import * as brazier from "./vendor/pixelfx/src/fx/fire/brazier.js";
import * as groundSlam from "./vendor/pixelfx/src/fx/impacts/ground-slam.js";
import * as magicCircleCast from "./vendor/pixelfx/src/fx/arcane/magic-circle-cast.js";
import * as collectBurst from "./vendor/pixelfx/src/fx/pickups/collect-burst.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = join(ROOT, "assets", "v016");
const CELL = 64;

// Dark Night Battlefield / Starfall Purple-Cyan-Gold Palettes
const PALETTES = {
  slash: {
    palette: ["#1a0f36", "#442282", "#345ec4", "#56cef8", "#f6d268", "#fff3be", "#ffffff"],
    sparks: ["#ffffff", "#ffe26b", "#7ae8ff", "#c084fc"],
  },
  arcane: {
    palette: ["#100828", "#241868", "#3444b8", "#4c88f0", "#7ae4ff", "#d4f6ff", "#ffffff"],
    accent: ["#1c0834", "#4a1a8c", "#8f3ee8", "#f0b848", "#fff0a8"],
  },
  lightning: {
    palette: ["#120930", "#2c1778", "#4b36c4", "#4078f0", "#62d8ff", "#b8f4ff", "#ffe88a", "#ffffff"],
    sparks: ["#ffffff", "#ffe88a", "#62d8ff", "#a46cff"],
  },
  frost: {
    palette: ["#101238", "#20246a", "#2c54a8", "#3c92dc", "#68d8ff", "#b8f4ff", "#e8fcff", "#ffffff"],
  },
  shield: {
    palette: ["#140a32", "#2c1a6e", "#4638b8", "#4886ec", "#74dcff", "#cef6ff", "#ffe89a", "#ffffff"],
    sparks: ["#ffffff", "#ffe47a", "#74dcff", "#c47aff"],
  },
  spark: {
    palette: ["#220d36", "#5a2078", "#c84c28", "#ff9634", "#ffd954", "#fff3ae", "#ffffff"],
  },
  brazier: {
    palette: ["#2a0b1e", "#641628", "#a82c22", "#e2581e", "#ff942a", "#ffcc48", "#ffea88", "#fff7cc", "#ffffff"],
    iron: ["#0b0814", "#1b162a", "#302846", "#4f446c", "#7c6ea0"],
  },
  slam: {
    palette: ["#1e0c2c", "#50205c", "#983e3a", "#e47e38", "#ffcb5c", "#fff0ad", "#ffffff"],
    stone: "#423862",
  },
  upgrade: {
    palette: ["#180d36", "#3a1e72", "#5648c4", "#50a8f0", "#7be8ff", "#ffd85c", "#fff4b8", "#ffffff"],
  },
};

/**
 * Circular smoothstep fade on the `light` buffer so glow never clips into a visible rectangle at cell borders.
 */
function radialLightFade(f, cx = f.w * 0.5, cy = f.h * 0.5, rInner = f.w * 0.24, rOuter = f.w * 0.48) {
  const { w, h, light: L } = f;
  for (let y = 0; y < h; y++) {
    const dy = y + 0.5 - cy;
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const l = L[i];
      if (!(l & 0xffffff)) continue;
      const d = Math.hypot(x + 0.5 - cx, dy);
      if (d <= rInner) continue;
      if (d >= rOuter) {
        L[i] = 0;
        continue;
      }
      const u = 1 - (d - rInner) / (rOuter - rInner);
      const k = u * u * (3 - 2 * u);
      L[i] =
        (l & 0xff000000) |
        Math.round((l & 255) * k) |
        (Math.round(((l >>> 8) & 255) * k) << 8) |
        (Math.round(((l >>> 16) & 255) * k) << 16);
    }
  }
}

/**
 * Soft top-margin fade on `color` alpha (for rising smoke plumes in 1:1 frames so smoke never clips flat at y=0).
 */
function topSmokeFade(f, fadeRows = 10) {
  const { w, color: C } = f;
  for (let y = 0; y < fadeRows; y++) {
    const k = (y + 0.5) / fadeRows;
    const s = k * k * (3 - 2 * k);
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const c = C[i];
      const a = c >>> 24;
      if (!a) continue;
      const na = Math.round(a * s);
      C[i] = (na << 24) | (c & 0xffffff);
    }
  }
}

/**
 * Crisp integer block downsample (N*64 -> 64x64) tuned for pixel-art VFX:
 * preserves thin 1px bolts/sparks via peak-saliency selection while blending soft halos cleanly.
 */
function downsampleCrisp(src, sw, sh, factor) {
  if (factor === 1) return src;
  const dw = (sw / factor) | 0;
  const dh = (sh / factor) | 0;
  const out = new Uint8ClampedArray(dw * dh * 4);
  for (let dy = 0; dy < dh; dy++) {
    for (let dx = 0; dx < dw; dx++) {
      let bestScore = -1;
      let br = 0, bg = 0, bb = 0, ba = 0;
      let sumR = 0, sumG = 0, sumB = 0, sumA = 0, maxA = 0, count = 0;
      for (let sy = 0; sy < factor; sy++) {
        for (let sx = 0; sx < factor; sx++) {
          const i = ((dy * factor + sy) * sw + (dx * factor + sx)) * 4;
          const r = src[i], g = src[i + 1], b = src[i + 2], a = src[i + 3];
          if (a === 0) continue;
          const luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
          const score = (a / 255) * (0.45 + 0.55 * luma);
          if (score > bestScore) {
            bestScore = score;
            br = r; bg = g; bb = b; ba = a;
          }
          sumR += r * a;
          sumG += g * a;
          sumB += b * a;
          sumA += a;
          if (a > maxA) maxA = a;
          count++;
        }
      }
      if (count === 0) continue;
      const avgR = sumR / sumA;
      const avgG = sumG / sumA;
      const avgB = sumB / sumA;
      const covA = sumA / (factor * factor);
      const sharp = ba >= 200 ? 0.82 : 0.45;
      const j = (dy * dw + dx) * 4;
      out[j] = Math.min(255, Math.round(br * sharp + avgR * (1 - sharp)));
      out[j + 1] = Math.min(255, Math.round(bg * sharp + avgG * (1 - sharp)));
      out[j + 2] = Math.min(255, Math.round(bb * sharp + avgB * (1 - sharp)));
      out[j + 3] = Math.min(255, Math.round(maxA * 0.65 + covA * 0.35));
    }
  }
  return out;
}

/** Step an effect through specific timestamps and return 64x64 RGBA buffers. */
function captureAtTimes(
  mod,
  times,
  { scale = 1, origin, options = {}, lightK = 0.85, radialCenter, preAdvance = 0, overlay = null, topFade = 0 } = {}
) {
  const W = CELL * scale;
  const H = CELL * scale;
  const ox = origin ? origin[0] : W * 0.5;
  const oy = origin ? origin[1] : H * 0.5;
  const frame = createFrame(W, H);
  const inst = createFx(mod, { x: ox, y: oy, light: lightK, ...options });
  const stepDt = 1 / 120;
  let curT = 0;

  if (preAdvance > 0) {
    while (curT + 1e-6 < preAdvance) {
      const dt = Math.min(stepDt, preAdvance - curT);
      inst.update(dt);
      curT += dt;
    }
  }

  const results = [];
  for (let fi = 0; fi < times.length; fi++) {
    const targetT = times[fi];
    while (curT + 1e-6 < targetT) {
      const dt = Math.min(stepDt, targetT - curT);
      inst.update(dt);
      curT += dt;
    }
    clearFrame(frame);
    inst.draw(frame, "back");
    inst.draw(frame, "front");
    if (overlay) overlay(frame, targetT, fi, ox, oy);
    if (topFade > 0) topSmokeFade(frame, topFade * scale);
    const rc = radialCenter ?? [W * 0.5, H * 0.5];
    radialLightFade(frame, rc[0], rc[1], W * 0.2, W * 0.47);
    const rgba = composite(frame, new Uint8ClampedArray(W * H * 4), null, lightK);
    results.push(downsampleCrisp(rgba, W, H, scale));
  }
  return results;
}

/** Pack an array of 64x64 RGBA frames into a horizontal strip PNG buffer. */
function packHorizontalStrip(frames) {
  const n = frames.length;
  const sheetW = n * CELL;
  const sheetH = CELL;
  const out = new Uint8ClampedArray(sheetW * sheetH * 4);
  for (let i = 0; i < n; i++) {
    const f = frames[i];
    const xOff = i * CELL;
    for (let y = 0; y < CELL; y++) {
      const srcOff = y * CELL * 4;
      const dstOff = (y * sheetW + xOff) * 4;
      out.set(f.subarray(srcOff, srcOff + CELL * 4), dstOff);
    }
  }
  return encodePNG(sheetW, sheetH, out);
}

/**
 * 1. fx_slash.png — Starfall crescent blade slash (native 64x64, centered at arc pivot [32, 32]).
 */
function buildSlash() {
  const times = [0.012, 0.032, 0.058, 0.09, 0.13, 0.18, 0.24, 0.32];
  // sword-slash draws arc around (cx: 6, cy: -26) relative to origin.
  // With radius: 22 and origin [26, 56], arc center is (32, 30) and all sparks fit inside 64x64.
  const frames = captureAtTimes(swordSlash, times, {
    scale: 1,
    origin: [26, 56],
    options: { ...PALETTES.slash, radius: 22, seed: 11 },
    lightK: 0.78,
    radialCenter: [32, 30],
  });
  return { name: "fx_slash", frames, fps: 24, loop: false, source: "melee/sword-slash", pivot: [32, 32] };
}

/**
 * 2. fx_arcane_blast.png — Starfall arcane burst (plasma-explosion + mana-burst runes, 4x -> 64x64).
 */
function buildArcaneBlast() {
  const times = [0.025, 0.07, 0.13, 0.21, 0.31, 0.43, 0.56, 0.72];
  const scale = 4;
  const W = CELL * scale;
  const H = CELL * scale;
  const frame = createFrame(W, H);
  const plasma = createFx(plasmaExplosion, {
    x: W * 0.5,
    y: H * 0.5,
    ...PALETTES.arcane,
    seed: 19,
    light: 0.8,
  });
  const mana = createFx(manaBurst, {
    x: W * 0.5,
    y: H * 0.5 + 28,
    palette: ["#100828", "#241868", "#4c38b0", "#62c8ff", "#ffd866", "#ffe99e", "#fff7d6", "#ffffff"],
    seed: 23,
    light: 0.7,
  });

  for (let i = 0; i < 28; i++) mana.update(0.22 / 28);

  const frames = [];
  let curT = 0;
  const dtStep = 1 / 120;
  for (const targetT of times) {
    while (curT + 1e-6 < targetT) {
      const dt = Math.min(dtStep, targetT - curT);
      plasma.update(dt);
      mana.update(dt);
      curT += dt;
    }
    clearFrame(frame);
    mana.draw(frame, "back");
    plasma.draw(frame, "back");
    plasma.draw(frame, "front");
    mana.draw(frame, "front");
    radialLightFade(frame, W * 0.5, H * 0.5, W * 0.18, W * 0.47);
    const rgba = composite(frame, new Uint8ClampedArray(W * H * 4), null, 0.8);
    frames.push(downsampleCrisp(rgba, W, H, scale));
  }
  return { name: "fx_arcane_blast", frames, fps: 18, loop: false, source: "explosions/plasma-explosion+arcane/mana-burst", pivot: [32, 32] };
}

/**
 * 3. fx_lightning_arc.png — Tower/Conduit chain lightning arc (zap-hit + bowed/zigzag bolts).
 */
function buildLightningArc() {
  const C = fit(PALETTES.lightning.palette, 8);
  const times = [0.045, 0.075, 0.11, 0.15, 0.21, 0.28, 0.36, 0.48];
  const frames = captureAtTimes(zapHit, times, {
    scale: 2,
    origin: [78, 64],
    options: { palette: PALETTES.lightning.palette, seed: 37 },
    lightK: 0.82,
    overlay: (frame, t, fi, ox, oy) => {
      const p = painterFor(frame).place(ox - 14, oy, false, 0);
      const r = rng(401, fi, 7);
      const strength = fi === 0 ? 1.0 : fi < 5 ? 0.9 - fi * 0.08 : Math.max(0.22, 0.68 - (fi - 4) * 0.16);
      const bow = (fi % 2 === 0 ? -1 : 1) * (5 + (fi % 3) * 3);
      const mainBolt = bowed(r, -54, 0, 52, 0, bow, 0.24, 0.42);
      stroke(p, mainBolt, strength, C, 0.85, { hero: fi === 0, light: 0.5 });
      if (fi >= 1 && fi <= 5) {
        const secondary = zigzag(r, -46, r.range(-10, 10), 46, r.range(-10, 10), 0.3, 0.35);
        crackle(p, secondary, strength * 0.72, C, 0.32);
      }
      if (fi < 6) {
        for (const ex of [-50, 50]) {
          p.circle(ex, 0, 2.8 * strength + 0.8, C[4]);
          p.circle(ex, 0, 1.8 * strength, WHITE);
          p.glow(ex, 0, 12, C[4], 0.45 * strength);
        }
      }
    },
  });
  return { name: "fx_lightning_arc", frames, fps: 20, loop: false, source: "lightning/zap-hit+lightning/_lib", pivot: [32, 32] };
}

/**
 * 4. fx_frost_shatter.png — Frost nova crystal eruption + shattering ice shards & snowflakes.
 */
function buildFrostShatter() {
  const C = fit(PALETTES.frost.palette, 8);
  const novaTimes = [0.43, 0.49, 0.58, 0.72, 0.92, 1.98, 2.24, 2.52];
  const W = CELL;
  const H = CELL;
  const frame = createFrame(W, H);
  const nova = createFx(frostNova, { x: 32, y: 49, ...PALETTES.frost, reach: 26, seed: 14, light: 0.65 });
  const burst = createFx(snowflakeBurst, { x: 32, y: 74, ...PALETTES.frost, count: 8, seed: 42, light: 0.65 });

  // Advance frostNova to CHARGE = 0.42, snowflakeBurst to POP = 0.16
  let nT = 0;
  while (nT + 1e-6 < 0.42) {
    const dt = Math.min(1 / 120, 0.42 - nT);
    nova.update(dt);
    nT += dt;
  }
  let bT = 0;
  while (bT + 1e-6 < 0.16) {
    const dt = Math.min(1 / 120, 0.16 - bT);
    burst.update(dt);
    bT += dt;
  }

  // Also add radial shattering crystal shards via pixelfx Bits + Particles
  const R = new Rng(88);
  const bits = new Bits({ ground: () => 56 });
  const ps = new Particles({ rng: R, ground: () => 56, sparks: [WHITE, C[6], C[5], C[4]] });
  for (let i = 0; i < 20; i++) {
    const a = -Math.PI * 0.92 + (i / 19) * Math.PI * 0.84 + R.range(-0.1, 0.1);
    const sp = R.range(55, 130);
    bits.add({
      kind: B.SHARD,
      x: 32 + R.range(-10, 10),
      y: 40 + R.range(-8, 2),
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 12,
      g: 0.7,
      drag: 0.8,
      bounce: 0.3,
      life: R.range(0.5, 0.95),
      a: R.range(0, TAU),
      va: R.range(-20, 20),
      s: R.range(1.6, 3.0),
      c: R.pick([WHITE, C[6], C[5], C[4]]),
    });
  }

  const frames = [];
  const shardTimes = [0.02, 0.08, 0.16, 0.25, 0.36, 0.48, 0.62, 0.78];
  let sT = 0;
  for (let i = 0; i < novaTimes.length; i++) {
    const tNova = novaTimes[i];
    const tBurst = 0.17 + i * 0.1;
    const tShard = shardTimes[i];
    while (nT + 1e-6 < tNova) {
      const dt = Math.min(1 / 120, tNova - nT);
      nova.update(dt);
      nT += dt;
    }
    while (bT + 1e-6 < tBurst) {
      const dt = Math.min(1 / 120, tBurst - bT);
      burst.update(dt);
      bT += dt;
    }
    while (sT + 1e-6 < tShard) {
      const dt = Math.min(1 / 120, tShard - sT);
      bits.update(dt);
      ps.update(dt);
      sT += dt;
    }
    clearFrame(frame);
    nova.draw(frame, "back");
    nova.draw(frame, "front");
    if (i >= 1) burst.draw(frame, "front");
    if (i >= 2) {
      const p = painterFor(frame);
      bits.draw(p);
      ps.draw(p);
    }
    radialLightFade(frame, 32, 36, 12, 30);
    frames.push(composite(frame, new Uint8ClampedArray(W * H * 4), null, 0.68));
  }
  return { name: "fx_frost_shatter", frames, fps: 16, loop: false, source: "ice/frost-nova+ice/snowflake-burst", pivot: [32, 42] };
}

/**
 * 5. fx_shield_break.png — Starfall diamond-lattice barrier shatter & ripple wave (no grey EMP puck).
 *    Adapts pixelfx impacts/shield-block lattice + brokenRing + star + crackle + Particles.
 */
function buildShieldBreak() {
  const C = fit(PALETTES.shield.palette, 8);
  const S = fit(PALETTES.shield.sparks, 4);
  const R = new Rng(54);
  const ps = new Particles({ rng: R, sparks: S });
  const bits = new Bits({});
  const lights = new Lights();

  const RX = 22, RY = 21;
  const GRID = 3.2;
  const hitSpike = spikes(R, 10, -0.2, { len: [6, 10], w: [1.4, 2.0], fwd: 1.4, back: 0.8 });
  const segs = Array.from({ length: 8 }, (_, i) => ({
    a: (i / 8) * TAU + 0.15,
    gap: R.range(0.55, 0.85),
    dr: R.range(0.12, 0.38),
    w: R.range(0.8, 1.25),
  }));

  // Burst sparks & diamond shard fragments at break
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * TAU + R.range(-0.15, 0.15);
    const sp = R.range(55, 130);
    ps.spawn(P.SPARK, Math.cos(a) * 14, Math.sin(a) * 14, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.22, 0.55), WHITE, 1);
  }
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * TAU + R.range(-0.2, 0.2);
    const sp = R.range(35, 95);
    bits.add({
      kind: B.SHARD,
      x: Math.cos(a) * 16,
      y: Math.sin(a) * 15,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 10,
      g: 0.25,
      drag: 1.4,
      bounce: 0.2,
      life: R.range(0.45, 0.85),
      a: R.range(0, TAU),
      va: R.range(-18, 18),
      s: R.range(1.6, 2.8),
      c: R.pick([C[6], C[5], C[4], WHITE]),
    });
  }
  lights.add(0, 0, 26, C[4], 0.75, 0.35);

  const times = [0.015, 0.05, 0.095, 0.15, 0.21, 0.28, 0.36, 0.45];
  const frame = createFrame(CELL, CELL);
  const frames = [];
  let curT = 0;
  const stepDt = 1 / 120;

  for (let fi = 0; fi < times.length; fi++) {
    const t = times[fi];
    while (curT + 1e-6 < t) {
      const dt = Math.min(stepDt, t - curT);
      if (curT >= 0.12) {
        ps.update(dt);
        bits.update(dt);
      }
      lights.update(dt);
      curT += dt;
    }

    clearFrame(frame);
    const p = painterFor(frame).place(32, 32, false, 0);

    // Phase 1-5: Diamond-lattice arcane shield sphere cracking & blinking out cell-by-cell
    const shatterU = clamp((t - 0.14) / 0.32);
    const domeFade = 1 - smooth(0.28, 0.52, t);
    if (domeFade > 0.02) {
      const rScale = 1 + 0.16 * ease.outCubic(clamp(t / 0.35));
      const rx = RX * rScale;
      const ry = RY * rScale;
      for (let y = Math.floor(-ry - 1); y <= Math.ceil(ry + 1); y++) {
        for (let x = Math.floor(-rx - 1); x <= Math.ceil(rx + 1); x++) {
          const u = (x + 0.5) / rx;
          const v = (y + 0.5) / ry;
          const q = u * u + v * v;
          if (q > 1) continue;
          const z = Math.sqrt(1 - q);
          const lon = Math.atan2(u, z);
          const lat = Math.asin(clamp(v, -1, 1));
          const a = (lon + lat) * GRID;
          const b = (lon - lat) * GRID;
          const fa = a - Math.floor(a);
          const fb = b - Math.floor(b);
          const cellSeed = rand(Math.floor(a) + 7, Math.floor(b) + 13, 31);
          if (shatterU > cellSeed * 0.92 + 0.08) continue;
          const line = Math.min(fa, 1 - fa, fb, 1 - fb) < 0.15;
          const ripple = Math.exp(-Math.pow((Math.sqrt(q) - clamp(t / 0.22)) * 6.5, 2));
          const flash = t < 0.04;
          const blink = shatterU > cellSeed * 0.92 - 0.06;
          if (q > 0.82) {
            p.dot(x, y, flash || ripple > 0.45 ? WHITE : C[6], domeFade);
          } else if (line) {
            p.dot(x, y, flash || blink ? C[6] : ripple > 0.35 ? C[5] : C[4], domeFade * 0.92);
          } else {
            p.blend(x, y, flash || ripple > 0.4 ? C[5] : C[2], domeFade * (0.16 + 0.28 * q + ripple * 0.4));
          }
        }
      }
    }

    // Expanding outer shockwave ring + breaking hex-arc fragments
    const uWave = clamp(t / 0.48);
    if (uWave > 0 && uWave < 1) {
      const rw = 10 + 19 * ease.outCubic(uWave);
      const th = Math.max(1, 3.2 * (1 - uWave));
      brokenRing(p, 0, 0, rw, th, segs, smooth(0.18, 0.95, uWave), uWave < 0.25 ? WHITE : uWave < 0.55 ? C[6] : C[4], C[3], 1 - uWave * 0.85, 0.88);
      p.glowRing(0, 0, rw, 5, C[4], 0.35 * (1 - uWave));
    }

    // Initial impact star + crackle bolts at shatter moment
    if (t < 0.08) {
      star(p, 0, 0, hitSpike, 1.0 + t * 4, 1 - t * 6, [C[3], C[5], C[6], WHITE], 1 - t * 10, 2.0);
    }
    if (t >= 0.06 && t <= 0.38) {
      const rArc = rng(903, fi, 5);
      const arcK = 1 - (t - 0.06) / 0.32;
      for (let k = 0; k < 3; k++) {
        const ang = (k / 3) * TAU + fi * 0.6;
        const b = zigzag(rArc, Math.cos(ang) * 8, Math.sin(ang) * 8, Math.cos(ang) * 24, Math.sin(ang) * 22, 0.35, 0.3);
        crackle(p, b, arcK * 0.85, C, 0.3);
      }
    }

    if (t >= 0.12) {
      bits.draw(p);
      ps.draw(p);
    }
    lights.draw(p);
    radialLightFade(frame, 32, 32, 12, 30);
    frames.push(composite(frame, new Uint8ClampedArray(CELL * CELL * 4), null, 0.82));
  }
  return { name: "fx_shield_break", frames, fps: 18, loop: false, source: "impacts/shield-block+impacts/_lib", pivot: [32, 32] };
}

/**
 * 6. fx_hit_spark.png — Punchy centered impact flare + spark spray (2x -> 64x64).
 */
function buildHitSpark() {
  const times = [0.008, 0.025, 0.05, 0.085, 0.13, 0.19, 0.26, 0.35];
  const scale = 2;
  const W = CELL * scale;
  const H = CELL * scale;
  const frame = createFrame(W, H);
  const hs = createFx(hitSpark, {
    x: W * 0.5,
    y: H * 0.5,
    ...PALETTES.spark,
    height: 0,
    aim: 0.0,
    seed: 12,
    light: 0.85,
  });
  const ch = createFx(critHit, {
    x: W * 0.5,
    y: H * 0.5,
    palette: ["#1e0a2e", "#4b1866", "#8c2440", "#d44b28", "#ff9632", "#ffda58", "#fff3b0", "#ffffff"],
    height: 0,
    aim: 0.08,
    seed: 21,
    light: 0.72,
  });

  const frames = [];
  let curT = 0;
  const dtStep = 1 / 120;
  for (const targetT of times) {
    while (curT + 1e-6 < targetT) {
      const dt = Math.min(dtStep, targetT - curT);
      hs.update(dt);
      ch.update(dt);
      curT += dt;
    }
    clearFrame(frame);
    ch.draw(frame, "front");
    hs.draw(frame, "front");
    radialLightFade(frame, W * 0.5, H * 0.5, W * 0.16, W * 0.46);
    const rgba = composite(frame, new Uint8ClampedArray(W * H * 4), null, 0.85);
    frames.push(downsampleCrisp(rgba, W, H, scale));
  }
  return { name: "fx_hit_spark", frames, fps: 24, loop: false, source: "impacts/hit-spark+impacts/crit-hit", pivot: [32, 32] };
}

/**
 * 7. fx_fire_brazier.png — Seamless looping iron brazier flame (native 64x64, 12 frames over 3.0s loop).
 */
function buildFireBrazier() {
  const count = 12;
  const duration = brazier.meta.duration;
  const times = Array.from({ length: count }, (_, i) => (i / count) * duration);
  const frames = captureAtTimes(brazier, times, {
    scale: 1,
    origin: [32, 62],
    options: { ...PALETTES.brazier, seed: 8 },
    lightK: 0.72,
    radialCenter: [32, 36],
    topFade: 10,
  });
  return { name: "fx_fire_brazier", frames, fps: 8, loop: true, source: "fire/brazier", pivot: [32, 59] };
}

/**
 * 8. fx_ground_slam.png — Earth-shaking rock & crescent shockwave slam (3x -> 64x64).
 */
function buildGroundSlam() {
  const times = [0.015, 0.05, 0.11, 0.2, 0.32, 0.48, 0.72, 1.05];
  const frames = captureAtTimes(groundSlam, times, {
    scale: 3,
    origin: [96, 152],
    options: { ...PALETTES.slam, reach: 74, seed: 17 },
    lightK: 0.78,
    radialCenter: [96, 126],
  });
  return { name: "fx_ground_slam", frames, fps: 18, loop: false, source: "impacts/ground-slam", pivot: [32, 50] };
}

/**
 * 9. fx_upgrade_sigil.png — Starfall arcane circle flash & rising starlight column (magic-circle-cast + collect-burst).
 */
function buildUpgradeSigil() {
  // Capture magic-circle-cast from rune flash (1.42) through column burst & dissolve, fading top cleanly
  const circleTimes = [1.44, 1.52, 1.58, 1.68, 1.85, 2.15, 2.52, 2.78];
  const burstTimes = [0.015, 0.05, 0.1, 0.18, 0.28, 0.42, 0.62, 0.86];
  const scale = 3;
  const W = CELL * scale;
  const H = CELL * scale;
  const frame = createFrame(W, H);
  const mc = createFx(magicCircleCast, {
    x: W * 0.5,
    y: H - 28,
    palette: PALETTES.upgrade.palette,
    seed: 15,
    light: 0.85,
  });
  const cb = createFx(collectBurst, {
    x: W * 0.5,
    y: H - 6,
    palette: PALETTES.upgrade.palette,
    seed: 29,
    light: 0.8,
  });

  let mT = 0;
  while (mT + 1e-6 < 1.42) {
    const dt = Math.min(1 / 120, 1.42 - mT);
    mc.update(dt);
    mT += dt;
  }

  const frames = [];
  let bT = 0;
  for (let i = 0; i < circleTimes.length; i++) {
    while (mT + 1e-6 < circleTimes[i]) {
      const dt = Math.min(1 / 120, circleTimes[i] - mT);
      mc.update(dt);
      mT += dt;
    }
    while (bT + 1e-6 < burstTimes[i]) {
      const dt = Math.min(1 / 120, burstTimes[i] - bT);
      cb.update(dt);
      bT += dt;
    }
    clearFrame(frame);
    mc.draw(frame, "back");
    mc.draw(frame, "front");
    cb.draw(frame, "front");
    topSmokeFade(frame, 18 * scale);
    radialLightFade(frame, W * 0.5, H * 0.54, W * 0.2, W * 0.47);
    const rgba = composite(frame, new Uint8ClampedArray(W * H * 4), null, 0.82);
    frames.push(downsampleCrisp(rgba, W, H, scale));
  }
  return { name: "fx_upgrade_sigil", frames, fps: 16, loop: false, source: "arcane/magic-circle-cast+pickups/collect-burst", pivot: [32, 54] };
}

function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  const builders = [
    buildSlash,
    buildArcaneBlast,
    buildLightningArc,
    buildFrostShatter,
    buildShieldBreak,
    buildHitSpark,
    buildFireBrazier,
    buildGroundSlam,
    buildUpgradeSigil,
  ];

  const manifest = {
    generator: "tools/compile_pixelfx.mjs",
    library: "patch-gg/pixelfx (MIT)",
    palette: "Dark Battlefield / Starfall Purple-Cyan-Gold",
    cellSize: [CELL, CELL],
    sheets: {},
  };

  for (const fn of builders) {
    const sheet = fn();
    const pngBuf = packHorizontalStrip(sheet.frames);
    const outPath = join(OUT_DIR, `${sheet.name}.png`);
    writeFileSync(outPath, pngBuf);
    manifest.sheets[sheet.name] = {
      file: `${sheet.name}.png`,
      width: sheet.frames.length * CELL,
      height: CELL,
      frameSize: [CELL, CELL],
      frames: sheet.frames.length,
      fps: sheet.fps,
      loop: sheet.loop,
      pivot: sheet.pivot,
      source: sheet.source,
    };
    console.log(
      `Compiled ${sheet.name}.png (${sheet.frames.length}x ${CELL}x${CELL} -> ${sheet.frames.length * CELL}x${CELL}, ${pngBuf.length} bytes)`
    );
  }

  const manifestPath = join(OUT_DIR, "fx_manifest.json");
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
  console.log(`Wrote ${manifestPath}`);
}

main();
