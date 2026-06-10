#!/usr/bin/env python3
"""Pack the cutscene textbox frame into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


WIDTH = 224
HEIGHT = 64
COLS = 7
ROWS = 4
OBJ_WIDTH = 32
OBJ_HEIGHT = 16
TILES_PER_OBJECT = 8
OPAQUE_ART_COLORS = 11
BODY_TEXT_COLOR = (236, 236, 232, 255)
MADELINE_NAME_COLOR = (133, 178, 230, 255)
GRANNY_NAME_COLOR = (232, 210, 154, 255)
DEFAULT_NAME_COLOR = (210, 210, 224, 255)
FORCED_COLORS = [
    BODY_TEXT_COLOR,
    MADELINE_NAME_COLOR,
    GRANNY_NAME_COLOR,
    DEFAULT_NAME_COLOR,
]


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def weighted_average(bucket: list[tuple[tuple[int, int, int, int], int]]) -> tuple[int, int, int, int]:
    total = sum(count for _, count in bucket)
    if total == 0:
        return (0, 0, 0, 255)
    r = sum(color[0] * count for color, count in bucket) // total
    g = sum(color[1] * count for color, count in bucket) // total
    b = sum(color[2] * count for color, count in bucket) // total
    return (r, g, b, 255)


def bucket_score(bucket: list[tuple[tuple[int, int, int, int], int]]) -> int:
    if len(bucket) <= 1:
        return -1
    ranges = []
    for channel in range(3):
        values = [color[channel] for color, _ in bucket]
        ranges.append(max(values) - min(values))
    return max(ranges) * sum(count for _, count in bucket)


def split_bucket(
    bucket: list[tuple[tuple[int, int, int, int], int]],
) -> tuple[list[tuple[tuple[int, int, int, int], int]], list[tuple[tuple[int, int, int, int], int]]]:
    ranges = []
    for channel in range(3):
        values = [color[channel] for color, _ in bucket]
        ranges.append(max(values) - min(values))
    channel = max(range(3), key=lambda index: ranges[index])
    sorted_bucket = sorted(bucket, key=lambda item: item[0][channel])
    half = sum(count for _, count in sorted_bucket) / 2
    running = 0
    split_at = 1
    for index, (_, count) in enumerate(sorted_bucket):
        running += count
        if running >= half:
            split_at = max(1, min(len(sorted_bucket) - 1, index + 1))
            break
    return sorted_bucket[:split_at], sorted_bucket[split_at:]


def collect_art_colors(image: Image) -> Counter[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for index in range(0, len(image.pixels), 4):
        r, g, b, a = image.pixels[index : index + 4]
        if a == 0:
            continue
        colors[(r, g, b, 255)] += 1
    if not colors:
        raise ValueError("textbox has no opaque pixels")
    return colors


def quantized_art_palette(colors: Counter[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    buckets: list[list[tuple[tuple[int, int, int, int], int]]] = [list(colors.items())]
    while len(buckets) < OPAQUE_ART_COLORS:
        bucket_index = max(range(len(buckets)), key=lambda index: bucket_score(buckets[index]))
        if bucket_score(buckets[bucket_index]) < 0:
            break
        left, right = split_bucket(buckets.pop(bucket_index))
        buckets.append(left)
        buckets.append(right)
    palette = [weighted_average(bucket) for bucket in buckets]
    palette.sort(key=lambda color: (color[0] + color[1] + color[2], color[0], color[1], color[2]))
    while len(palette) < OPAQUE_ART_COLORS:
        palette.append((0, 0, 0, 255))
    return palette[:OPAQUE_ART_COLORS]


def full_palette(image: Image) -> list[tuple[int, int, int, int]]:
    return [(0, 0, 0, 0)] + quantized_art_palette(collect_art_colors(image)) + FORCED_COLORS


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def pack_tiles(image: Image, palette: list[tuple[int, int, int, int]]) -> bytes:
    art_palette = palette[1 : 1 + OPAQUE_ART_COLORS]

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        color = (color[0], color[1], color[2], 255)
        return 1 + min(range(len(art_palette)), key=lambda index: color_distance(color, art_palette[index]))

    output = bytearray()
    for row in range(ROWS):
        for col in range(COLS):
            object_x = col * OBJ_WIDTH
            object_y = row * OBJ_HEIGHT
            for tile_y in range(OBJ_HEIGHT // 8):
                for tile_x in range(OBJ_WIDTH // 8):
                    tile_pixels: list[int] = []
                    for y in range(8):
                        for x in range(8):
                            image_x = object_x + tile_x * 8 + x
                            image_y = object_y + tile_y * 8 + y
                            offset = (image_y * image.width + image_x) * 4
                            tile_pixels.append(pixel_index(tuple(image.pixels[offset : offset + 4])))
                    write_tile_4bpp(output, tile_pixels)
    return bytes(output)


def write_meta(path: Path) -> None:
    path.write_text(
        "\n".join(
            [
                f"pub const width: i16 = {WIDTH};",
                f"pub const height: i16 = {HEIGHT};",
                f"pub const cols: usize = {COLS};",
                f"pub const rows: usize = {ROWS};",
                f"pub const tiles_per_object: u16 = {TILES_PER_OBJECT};",
                f"pub const tile_count: u16 = {COLS * ROWS * TILES_PER_OBJECT};",
                "pub const body_text_color: u8 = 12;",
                "pub const madeline_name_color: u8 = 13;",
                "pub const granny_name_color: u8 = 14;",
                "pub const default_name_color: u8 = 15;",
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    if image.width != WIDTH or image.height != HEIGHT:
        raise ValueError(f"{args.input} must be {WIDTH}x{HEIGHT}, got {image.width}x{image.height}")

    palette = full_palette(image)
    tiles = pack_tiles(image, palette)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "textbox_tiles.bin").write_bytes(tiles)
    (args.output_dir / "textbox_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    write_meta(args.output_dir / "textbox_meta.zig")
    (args.output_dir / "textbox.json").write_text(
        json.dumps(
            {
                "source": str(args.input),
                "width": WIDTH,
                "height": HEIGHT,
                "cols": COLS,
                "rows": ROWS,
                "tilesPerObject": TILES_PER_OBJECT,
                "tileCount": COLS * ROWS * TILES_PER_OBJECT,
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed textbox: {WIDTH}x{HEIGHT}, {COLS * ROWS * TILES_PER_OBJECT} tiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
