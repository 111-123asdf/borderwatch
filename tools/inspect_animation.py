from pathlib import Path
import struct


root = Path(__file__).resolve().parents[1] / 'assets/tiny_swords/Tiny Swords (Update 010)'
targets = [
    'Factions/Knights/Troops/Warrior/Blue/Warrior_Blue.aseprite',
    'Factions/Knights/Troops/Archer/Blue/Archer_Blue.aseprite',
    'Factions/Goblins/Troops/Torch/Red/Torch_Red.aseprite',
    'Factions/Goblins/Troops/TNT/Red/TNT_Red.aseprite',
]
for name in targets:
    data = (root / name).read_bytes()
    frame_count = struct.unpack_from('<H', data, 6)[0]
    offset = 128
    tags = []
    durations = []
    for frame in range(frame_count):
        length, magic, chunk_count, duration = struct.unpack_from('<IHHH', data, offset)
        durations.append(duration)
        position = offset + 16
        for chunk in range(chunk_count):
            size, kind = struct.unpack_from('<IH', data, position)
            if kind == 0x2018:
                total = struct.unpack_from('<H', data, position + 6)[0]
                tag_position = position + 16
                for tag in range(total):
                    start, end = struct.unpack_from('<HH', data, tag_position)
                    text_length = struct.unpack_from('<H', data, tag_position + 17)[0]
                    title = data[tag_position + 19:tag_position + 19 + text_length].decode('utf-8', errors='replace')
                    tags.append((start, end, title))
                    tag_position += 19 + text_length
            position += size
        offset += length
    print(name, 'frames', frame_count, 'durations', sorted(set(durations)), 'tags', tags)
