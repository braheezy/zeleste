#!/usr/bin/env python3
"""Generate and pack the prologue collapsing bridge OBJ chunks."""

from __future__ import annotations

import argparse
import json
import random
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


EMPTY_CHUNK = 255
NO_GROUP = 255
FRAME_WIDTH = 8
FRAME_HEIGHT = 32


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def crop_chunk(image: Image, x0: int, width: int = 8) -> Image:
    pixels = bytearray(width * image.height * 4)
    for y in range(image.height):
        src = (y * image.width + x0) * 4
        dst = y * width * 4
        pixels[dst : dst + width * 4] = image.pixels[src : src + width * 4]
    return Image(width, image.height, bytes(pixels))


def pad_chunk(image: Image) -> Image:
    if image.width != FRAME_WIDTH:
        raise ValueError(f"bridge chunk must be {FRAME_WIDTH}px wide, got {image.width}")
    if image.height > FRAME_HEIGHT:
        raise ValueError(f"bridge chunk must be at most {FRAME_HEIGHT}px tall, got {image.height}")
    pixels = bytearray(FRAME_WIDTH * FRAME_HEIGHT * 4)
    for y in range(image.height):
        src = y * image.width * 4
        dst = y * FRAME_WIDTH * 4
        pixels[dst : dst + FRAME_WIDTH * 4] = image.pixels[src : src + FRAME_WIDTH * 4]
    return Image(FRAME_WIDTH, FRAME_HEIGHT, bytes(pixels))


def image_key(image: Image) -> bytes:
    return image.pixels


def add_variant(variants: list[Image], variant_ids: dict[bytes, int], image: Image) -> int:
    padded = pad_chunk(image)
    key = image_key(padded)
    if key in variant_ids:
        return variant_ids[key]
    variant_id = len(variants)
    variant_ids[key] = variant_id
    variants.append(padded)
    return variant_id


def chunk_color_counts(images: list[Image]) -> Counter[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for image in images:
        for index in range(0, len(image.pixels), 4):
            color = tuple(image.pixels[index : index + 4])
            if color[3] != 0:
                colors[color] += 1
    return colors


def pack_chunk(image: Image, palette: list[tuple[int, int, int, int]]) -> bytes:
    opaque = [color for color in palette if color[3] != 0]
    palette_index = {color: index for index, color in enumerate(palette)}

    def pixel_index(x: int, y: int) -> int:
        offset = (y * image.width + x) * 4
        color = tuple(image.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color not in palette_index:
            closest = min(opaque, key=lambda candidate: color_distance(color, candidate))
            return palette_index[closest]
        return palette_index[color]

    tiles = bytearray()
    for tile_y in range(FRAME_HEIGHT // 8):
        for tile_x in range(FRAME_WIDTH // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def choose_chunks(rng: random.Random, pool: list[int], count: int) -> list[int]:
    return [rng.choice(pool) for _ in range(count)]


def thick_group_pattern(rng: random.Random, chunk_count: int) -> list[int]:
    patterns = [
        [chunk_count],
        [3, chunk_count - 3],
        [4, chunk_count - 4],
        [2, 3, chunk_count - 5],
    ]
    valid_patterns = [pattern for pattern in patterns if all(size > 0 for size in pattern)]
    return rng.choice(valid_patterns)


def append_thick(
    layout: list[int],
    groups: list[int],
    thick_layout: list[int],
    rng: random.Random,
    next_group_id: int,
) -> int:
    layout.extend(thick_layout)
    for size in thick_group_pattern(rng, len(thick_layout)):
        groups.extend([next_group_id] * size)
        next_group_id += 1
    return next_group_id


def append_random_chunks(
    layout: list[int],
    groups: list[int],
    rng: random.Random,
    pool: list[int],
    count: int,
    next_group_id: int,
) -> int:
    layout.extend(choose_chunks(rng, pool, count))
    groups.extend(range(next_group_id, next_group_id + count))
    return next_group_id + count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    thick = read_png_rgba(args.input_dir / "thick1.png")
    if thick.width % FRAME_WIDTH != 0:
        raise ValueError("thick1.png width must be divisible by 8")

    variants: list[Image] = []
    variant_ids: dict[bytes, int] = {}
    thick_layout = [add_variant(variants, variant_ids, crop_chunk(thick, x)) for x in range(0, thick.width, 8)]

    pool = []
    for path in sorted(args.input_dir.glob("bridge_*.png")):
        image = read_png_rgba(path)
        pool.append(add_variant(variants, variant_ids, image))
    if len(pool) < 6:
        raise ValueError(f"expected at least 6 bridge_*.png chunks in {args.input_dir}")

    rng = random.Random(args.seed)
    layout: list[int] = []
    groups: list[int] = []
    next_group_id = 0
    for index in range(5):
        next_group_id = append_thick(layout, groups, thick_layout, rng, next_group_id)
        if index != 4:
            next_group_id = append_random_chunks(layout, groups, rng, pool, 2 if index == 0 else 6, next_group_id)
    next_group_id = append_random_chunks(layout, groups, rng, pool, 7, next_group_id)
    for index in range(4):
        next_group_id = append_thick(layout, groups, thick_layout, rng, next_group_id)
        if index != 3:
            if index == 2:
                next_group_id = append_random_chunks(layout, groups, rng, pool, 4, next_group_id)
                layout.extend([EMPTY_CHUNK] * 2)
                groups.extend([NO_GROUP] * 2)
            else:
                next_group_id = append_random_chunks(layout, groups, rng, pool, 6, next_group_id)

    colors = chunk_color_counts(variants)
    opaque = [color for color, _ in colors.most_common(15)]
    palette = [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (15 - len(opaque))

    tiles = bytearray()
    for image in variants:
        tiles.extend(pack_chunk(image, palette))

    layout_binary = bytearray()
    layout_binary.extend(len(layout).to_bytes(2, "little"))
    layout_binary.extend(layout)
    group_binary = bytearray()
    group_binary.extend(len(groups).to_bytes(2, "little"))
    group_binary.extend(groups)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "bridge_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "bridge_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "bridge_layout.bin").write_bytes(bytes(layout_binary))
    (args.output_dir / "bridge_groups.bin").write_bytes(bytes(group_binary))
    (args.output_dir / "bridge.json").write_text(
        json.dumps(
            {
                "chunkWidth": FRAME_WIDTH,
                "chunkHeight": FRAME_HEIGHT,
                "layoutCount": len(layout),
                "variantCount": len(variants),
                "tilesPerVariant": 4,
                "emptyChunk": EMPTY_CHUNK,
                "noGroup": NO_GROUP,
                "paletteRgba": [list(color) for color in palette],
                "layout": layout,
                "groups": groups,
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed bridge: {len(layout)} chunks, {len(variants)} variants, {len(opaque)} opaque colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
