"""Build v0.32 modular 64x64 Rift tilesets, interactive props, and Relic icons."""

from __future__ import annotations
import os
import math
import numpy as np
from PIL import Image, ImageDraw

RAW_ARCHIVE_DIR = r"d:/godot/美术参考/v031_raw"
EXISTING_RIFT_V031 = r"d:/godot/边境守望/assets/rift_v031"
OUT_RIFT = r"d:/godot/边境守望/assets/rift_v032"
OUT_UI = r"d:/godot/边境守望/assets/ui_v032"


def ensure_dirs() -> None:
    os.makedirs(OUT_RIFT, exist_ok=True)
    os.makedirs(OUT_UI, exist_ok=True)


def make_seamless_tile(crop: Image.Image, size: int = 64) -> Image.Image:
    """Resize crop to size x size and blend a 6px border with toroidal wrap for seamless tiling."""
    base = crop.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    arr = np.array(base).astype(np.float32)
    rolled_x = np.roll(arr, size // 2, axis=1)
    rolled_xy = np.roll(rolled_x, size // 2, axis=0)
    yy, xx = np.mgrid[0:size, 0:size]
    edge_x = np.minimum(xx, size - 1 - xx).astype(np.float32) / 10.0
    edge_y = np.minimum(yy, size - 1 - yy).astype(np.float32) / 10.0
    w = np.clip(np.minimum(edge_x, edge_y), 0.0, 1.0)[..., None]
    out = arr * w + rolled_xy * (1.0 - w)
    # Snap subtle pixel look via 2x down/up or crisp quantization
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def build_biome_tilesets() -> None:
    biomes = {
        "wilds": {
            "src": "02_room_wilds.jpg",
            "accent": (122, 224, 118),
            "accent_hi": (196, 255, 168),
            "wall_trim": (94, 128, 74),
            "mortar": (28, 34, 24),
            "corr_tint": (0.94, 1.04, 0.86),
        },
        "abyss": {
            "src": "01_room_abyss.jpg",
            "accent": (72, 232, 226),
            "accent_hi": (176, 255, 252),
            "wall_trim": (62, 134, 146),
            "mortar": (16, 36, 46),
            "corr_tint": (0.82, 1.06, 1.12),
        },
        "void": {
            "src": "03_room_void.jpg",
            "accent": (198, 110, 255),
            "accent_hi": (238, 192, 255),
            "wall_trim": (118, 86, 162),
            "mortar": (22, 16, 38),
            "corr_tint": (0.96, 0.86, 1.16),
        },
    }

    corr_base_path = os.path.join(EXISTING_RIFT_V031, "corridor_tiles.png")
    corr_base = Image.open(corr_base_path).convert("RGBA") if os.path.exists(corr_base_path) else Image.new("RGBA", (128, 128), (74, 82, 92, 255))

    for bkey, cfg in biomes.items():
        room = Image.open(os.path.join(RAW_ARCHIVE_DIR, cfg["src"])).convert("RGBA").resize((920, 580), Image.Resampling.LANCZOS)
        acc = cfg["accent"]
        acc_hi = cfg["accent_hi"]
        mortar = cfg["mortar"]

        # 1. Floor tileset: 4 x 64x64
        floor_sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
        crops = [
            (220, 200, 348, 328),
            (460, 230, 588, 358),
            (590, 175, 718, 303),
            (340, 260, 468, 388),
        ]
        for idx, box in enumerate(crops):
            tile = make_seamless_tile(room.crop(box), 64)
            d = ImageDraw.Draw(tile)
            # Subtle pixel masonry grout hint & unique variant markings
            for gx in (0, 32):
                d.line([(gx, 0), (gx, 63)], fill=(mortar[0], mortar[1], mortar[2], 70), width=1)
            for gy in (0, 32):
                d.line([(0, gy), (63, gy)], fill=(mortar[0], mortar[1], mortar[2], 70), width=1)
            if idx == 1:
                # Weathered cracks
                d.line([(14, 18), (22, 26), (20, 34), (28, 42)], fill=(mortar[0], mortar[1], mortar[2], 190), width=2)
                d.line([(44, 12), (48, 22), (42, 28)], fill=(mortar[0], mortar[1], mortar[2], 170), width=1)
            elif idx == 2:
                # Biome moss / coral / starlight flecks
                for px, py in ((12, 14), (16, 16), (48, 42), (52, 44), (22, 50), (42, 14)):
                    d.rectangle([px, py, px + 3, py + 3], fill=(acc[0], acc[1], acc[2], 210))
                    d.point((px + 1, py + 1), fill=(acc_hi[0], acc_hi[1], acc_hi[2], 240))
            elif idx == 3:
                # Glowing inlaid floor rune
                d.polygon([(32, 18), (46, 32), (32, 46), (18, 32)], outline=(acc[0], acc[1], acc[2], 210))
                d.rectangle([30, 30, 34, 34], fill=(acc_hi[0], acc_hi[1], acc_hi[2], 235))
            floor_sheet.paste(tile, (idx * 64, 0))
        floor_sheet.save(os.path.join(OUT_RIFT, f"tiles_{bkey}_floor.png"))

        # 2. Wall tileset: 4 x 64x64 (0=north wall face, 1=side/south wall cap, 2=doorway arch pillar, 3=corner sconce)
        wall_sheet = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
        top_band = room.crop((280, 12, 408, 120)).resize((64, 64), Image.Resampling.LANCZOS)
        side_band = room.crop((14, 210, 92, 338)).resize((64, 64), Image.Resampling.LANCZOS)

        # Tile 0: North solid wall block with strong bevel
        w0 = top_band.copy()
        d0 = ImageDraw.Draw(w0)
        d0.rectangle([0, 0, 63, 7], fill=(mortar[0], mortar[1], mortar[2], 240))
        d0.rectangle([0, 56, 63, 63], fill=(mortar[0], mortar[1], mortar[2], 255))
        d0.line([(0, 8), (63, 8)], fill=(cfg["wall_trim"][0], cfg["wall_trim"][1], cfg["wall_trim"][2], 210), width=2)
        d0.line([(32, 9), (32, 55)], fill=(mortar[0], mortar[1], mortar[2], 180), width=2)
        wall_sheet.paste(w0, (0, 0))

        # Tile 1: Side / South thick wall block
        w1 = side_band.copy()
        d1 = ImageDraw.Draw(w1)
        d1.rectangle([0, 0, 63, 63], outline=(mortar[0], mortar[1], mortar[2], 235), width=3)
        d1.line([(4, 4), (59, 4)], fill=(cfg["wall_trim"][0], cfg["wall_trim"][1], cfg["wall_trim"][2], 220), width=2)
        d1.line([(4, 32), (59, 32)], fill=(mortar[0], mortar[1], mortar[2], 175), width=2)
        wall_sheet.paste(w1, (64, 0))

        # Tile 2: Doorway stone arch pillar
        w2 = top_band.copy()
        d2 = ImageDraw.Draw(w2)
        d2.rectangle([6, 4, 57, 59], fill=(42, 48, 58, 255), outline=(mortar[0], mortar[1], mortar[2], 255), width=3)
        d2.rectangle([14, 12, 49, 51], fill=(cfg["wall_trim"][0], cfg["wall_trim"][1], cfg["wall_trim"][2], 255))
        d2.polygon([(32, 20), (42, 32), (32, 44), (22, 32)], fill=(acc[0], acc[1], acc[2], 255))
        d2.rectangle([30, 30, 34, 34], fill=(acc_hi[0], acc_hi[1], acc_hi[2], 255))
        wall_sheet.paste(w2, (128, 0))

        # Tile 3: Corner brazier/lantern/crystal sconce wall tile
        w3 = w1.copy()
        d3 = ImageDraw.Draw(w3)
        d3.ellipse([16, 16, 48, 48], fill=(mortar[0], mortar[1], mortar[2], 255), outline=(cfg["wall_trim"][0], cfg["wall_trim"][1], cfg["wall_trim"][2], 255), width=2)
        d3.ellipse([21, 21, 43, 43], fill=(acc[0], acc[1], acc[2], 255))
        d3.ellipse([26, 26, 38, 38], fill=(acc_hi[0], acc_hi[1], acc_hi[2], 255))
        wall_sheet.paste(w3, (192, 0))
        wall_sheet.save(os.path.join(OUT_RIFT, f"tiles_{bkey}_wall.png"))

        # 3. Corridor seamless 128x128 stone bridge segment
        cw, ch = corr_base.size
        seg = corr_base.crop((int(cw * 0.2), 0, int(cw * 0.7), ch)).resize((128, 128), Image.Resampling.LANCZOS)
        carr = np.array(seg).astype(np.float32)
        tint = cfg["corr_tint"]
        carr[..., 0] = np.clip(carr[..., 0] * tint[0], 0, 255)
        carr[..., 1] = np.clip(carr[..., 1] * tint[1], 0, 255)
        carr[..., 2] = np.clip(carr[..., 2] * tint[2], 0, 255)
        corr_out = Image.fromarray(carr.astype(np.uint8), "RGBA")
        # Add glowing rune rivets along rail caps
        dc = ImageDraw.Draw(corr_out)
        for rx in (16, 64, 112):
            dc.rectangle([rx - 2, 10, rx + 2, 14], fill=(acc[0], acc[1], acc[2], 230))
            dc.rectangle([rx - 2, 113, rx + 2, 117], fill=(acc[0], acc[1], acc[2], 230))
        corr_out.save(os.path.join(OUT_RIFT, f"tiles_{bkey}_corridor.png"))

        # 4. Biome obstacle pillar 64x80 (solid cover)
        pil = Image.new("RGBA", (64, 80), (0, 0, 0, 0))
        dp = ImageDraw.Draw(pil)
        # Base ground shadow
        dp.ellipse([8, 60, 56, 76], fill=(10, 12, 18, 150))
        # Plinth + shaft
        dp.rectangle([12, 54, 52, 70], fill=(38, 44, 54, 255), outline=(18, 20, 26, 255), width=2)
        dp.rectangle([16, 18, 48, 58], fill=(64, 72, 84, 255), outline=(18, 20, 26, 255), width=2)
        dp.rectangle([20, 22, 28, 54], fill=(92, 104, 118, 255))
        # Capital & glowing crystal/moss crown
        dp.rectangle([12, 10, 52, 22], fill=(cfg["wall_trim"][0], cfg["wall_trim"][1], cfg["wall_trim"][2], 255), outline=(18, 20, 26, 255), width=2)
        dp.polygon([(32, 24), (40, 36), (32, 48), (24, 36)], fill=(acc[0], acc[1], acc[2], 255))
        dp.polygon([(32, 28), (36, 36), (32, 44), (28, 36)], fill=(acc_hi[0], acc_hi[1], acc_hi[2], 255))
        pil.save(os.path.join(OUT_RIFT, f"prop_pillar_{bkey}.png"))


def build_shared_props() -> None:
    # 1. Volatile Crystal Barrel (64x64)
    barrel = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(barrel)
    d.ellipse([12, 48, 52, 60], fill=(10, 14, 24, 155))
    d.rounded_rectangle([14, 14, 50, 54], radius=8, fill=(44, 50, 74, 255), outline=(18, 20, 32, 255), width=2)
    # Glowing crystal core ribs
    d.rectangle([15, 22, 49, 27], fill=(208, 168, 72, 255))
    d.rectangle([15, 40, 49, 45], fill=(208, 168, 72, 255))
    d.polygon([(32, 10), (42, 30), (32, 48), (22, 30)], fill=(96, 238, 255, 255), outline=(22, 30, 52, 255))
    d.polygon([(32, 16), (37, 30), (32, 42), (27, 30)], fill=(224, 255, 255, 255))
    d.polygon([(26, 6), (32, 14), (38, 6), (32, 2)], fill=(196, 118, 255, 255))
    barrel.save(os.path.join(OUT_RIFT, "prop_barrel_crystal.png"))

    # 2. Blood Pact Altar (96x96)
    altar = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    da = ImageDraw.Draw(altar)
    da.ellipse([14, 70, 82, 90], fill=(16, 8, 14, 175))
    da.rectangle([20, 56, 76, 78], fill=(42, 26, 36, 255), outline=(18, 10, 16, 255), width=3)
    da.rectangle([28, 36, 68, 60], fill=(64, 34, 48, 255), outline=(18, 10, 16, 255), width=2)
    da.rectangle([18, 32, 78, 42], fill=(192, 144, 68, 255), outline=(24, 14, 18, 255), width=2)
    # Floating crimson shard & runes
    da.polygon([(48, 6), (60, 22), (48, 34), (36, 22)], fill=(255, 68, 96, 255), outline=(28, 8, 16, 255))
    da.polygon([(48, 11), (54, 22), (48, 29), (42, 22)], fill=(255, 206, 214, 255))
    da.rectangle([42, 46, 54, 52], fill=(255, 76, 108, 240))
    altar.save(os.path.join(OUT_RIFT, "prop_altar_blood.png"))

    # 3. Defense Forge Anvil (96x96)
    anvil = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    df = ImageDraw.Draw(anvil)
    df.ellipse([14, 70, 82, 90], fill=(10, 14, 22, 175))
    df.rectangle([22, 58, 74, 78], fill=(48, 56, 72, 255), outline=(16, 20, 28, 255), width=3)
    # Anvil horn & face
    df.polygon([(12, 34), (82, 34), (70, 58), (28, 58)], fill=(86, 102, 124, 255), outline=(16, 20, 28, 255))
    df.rectangle([20, 28, 72, 38], fill=(124, 226, 255, 255), outline=(16, 20, 28, 255), width=2)
    # Hammer + sparks
    df.line([(56, 12), (38, 30)], fill=(184, 124, 62, 255), width=4)
    df.rectangle([50, 6, 68, 20], fill=(236, 194, 82, 255), outline=(24, 18, 12, 255), width=2)
    for sx, sy in ((22, 18), (74, 20), (46, 14), (28, 24)):
        df.rectangle([sx, sy, sx + 3, sy + 3], fill=(255, 232, 118, 255))
    anvil.save(os.path.join(OUT_RIFT, "prop_anvil_forge.png"))

    # 4. Star Pedestal (96x96)
    ped = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    dp = ImageDraw.Draw(ped)
    dp.ellipse([18, 70, 78, 88], fill=(10, 14, 24, 165))
    dp.rectangle([24, 58, 72, 76], fill=(58, 70, 88, 255), outline=(18, 22, 32, 255), width=2)
    dp.rectangle([32, 36, 64, 60], fill=(84, 98, 122, 255), outline=(18, 22, 32, 255), width=2)
    dp.rectangle([26, 32, 70, 40], fill=(224, 182, 78, 255), outline=(18, 22, 32, 255), width=2)
    dp.polygon([(48, 6), (62, 20), (48, 34), (34, 20)], fill=(110, 240, 255, 255), outline=(20, 28, 46, 255))
    dp.polygon([(48, 12), (55, 20), (48, 28), (41, 20)], fill=(255, 248, 178, 255))
    ped.save(os.path.join(OUT_RIFT, "prop_pedestal_choice.png"))

    # 5. Deep Descent Gate (128x128)
    gate = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    dg = ImageDraw.Draw(gate)
    dg.ellipse([14, 96, 114, 120], fill=(8, 10, 22, 180))
    dg.ellipse([20, 12, 108, 108], outline=(242, 198, 84, 255), width=7)
    dg.ellipse([26, 18, 102, 102], fill=(42, 22, 78, 235), outline=(112, 238, 255, 255), width=4)
    dg.ellipse([38, 30, 90, 90], fill=(138, 78, 255, 230))
    dg.ellipse([48, 40, 80, 80], fill=(168, 248, 255, 245))
    dg.ellipse([56, 48, 72, 72], fill=(255, 252, 232, 255))
    for ang_deg in range(0, 360, 45):
        ang = math.radians(ang_deg)
        px = int(round(64 + math.cos(ang) * 44))
        py = int(round(60 + math.sin(ang) * 44))
        dg.polygon([(px, py - 5), (px + 5, py), (px, py + 5), (px - 5, py)], fill=(126, 246, 255, 255))
    gate.save(os.path.join(OUT_RIFT, "prop_descent_gate.png"))


def build_relic_icons() -> None:
    specs = {
        "ember_ordnance": ((48, 20, 18), (255, 134, 52), (255, 236, 130), "box"),
        "chrono_prism": ((16, 38, 56), (92, 236, 255), (220, 255, 255), "hourglass"),
        "orbital_beacon": ((18, 32, 58), (110, 238, 255), (255, 228, 112), "beam"),
        "aegis_reactor": ((16, 34, 62), (96, 196, 255), (208, 250, 255), "shield"),
        "chain_detonator": ((38, 18, 62), (196, 102, 255), (124, 246, 255), "crystal"),
        "titan_breaker": ((50, 22, 28), (238, 96, 92), (255, 218, 108), "hammer"),
        "vampiric_chalice": ((54, 14, 30), (242, 62, 104), (255, 198, 216), "chalice"),
        "gilded_compass": ((42, 34, 18), (246, 198, 76), (255, 248, 196), "star"),
    }
    for rid, (bg_col, main_col, hi_col, shape) in specs.items():
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        # Octagonal gold-rimmed badge
        pts = [(14, 4), (50, 4), (60, 14), (60, 50), (50, 60), (14, 60), (4, 50), (4, 14)]
        d.polygon(pts, fill=(bg_col[0], bg_col[1], bg_col[2], 255), outline=(228, 178, 68, 255))
        d.polygon([(16, 7), (48, 7), (57, 16), (57, 48), (48, 57), (16, 57), (7, 48), (7, 16)], outline=(82, 62, 28, 255))
        # Corner cyan gems
        for gx, gy in ((32, 4), (32, 60), (4, 32), (60, 32)):
            d.rectangle([gx - 2, gy - 2, gx + 2, gy + 2], fill=(116, 238, 255, 255))

        if shape == "box":
            d.rectangle([18, 20, 46, 46], fill=main_col, outline=(24, 12, 10, 255), width=2)
            d.polygon([(32, 12), (42, 26), (32, 38), (22, 26)], fill=hi_col)
        elif shape == "hourglass":
            d.polygon([(18, 14), (46, 14), (32, 32)], fill=main_col, outline=hi_col)
            d.polygon([(18, 50), (46, 50), (32, 32)], fill=main_col, outline=hi_col)
            d.rectangle([29, 29, 35, 35], fill=hi_col)
        elif shape == "beam":
            d.rectangle([26, 10, 38, 46], fill=main_col)
            d.rectangle([29, 10, 35, 46], fill=hi_col)
            d.ellipse([14, 42, 50, 52], outline=hi_col, width=2)
        elif shape == "shield":
            d.polygon([(18, 16), (46, 16), (46, 36), (32, 50), (18, 36)], fill=main_col, outline=hi_col)
            d.polygon([(26, 24), (38, 24), (32, 40)], fill=hi_col)
        elif shape == "crystal":
            d.polygon([(32, 12), (46, 28), (39, 48), (25, 48), (18, 28)], fill=main_col, outline=hi_col)
            d.polygon([(32, 18), (38, 30), (32, 42), (26, 30)], fill=hi_col)
        elif shape == "hammer":
            d.line([(20, 48), (42, 24)], fill=hi_col, width=4)
            d.polygon([(28, 14), (50, 24), (42, 36), (20, 26)], fill=main_col, outline=hi_col)
        elif shape == "chalice":
            d.polygon([(18, 16), (46, 16), (40, 34), (24, 34)], fill=main_col, outline=hi_col)
            d.rectangle([29, 34, 35, 44], fill=hi_col)
            d.rectangle([22, 44, 42, 50], fill=hi_col)
        elif shape == "star":
            d.polygon([(32, 11), (37, 26), (52, 32), (37, 38), (32, 53), (27, 38), (12, 32), (27, 26)], fill=main_col, outline=hi_col)
            d.ellipse([27, 27, 37, 37], fill=hi_col)

        img.save(os.path.join(OUT_UI, f"relic_{rid}.png"))


def main() -> None:
    ensure_dirs()
    build_biome_tilesets()
    build_shared_props()
    build_relic_icons()
    print("Built v0.32 modular tiles, props, and relics cleanly.")


if __name__ == "__main__":
    main()
