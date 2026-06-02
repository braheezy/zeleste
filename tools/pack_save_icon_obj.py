#!/usr/bin/env python3
"""Pack the save icon animation into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


FRAME_WIDTH = 45
FRAME_HEIGHT = 45
# The source art is 45x45, but GBA OBJ hardware cannot draw a 48x48
# sprite directly. Pack a 48x48 cell as four contiguous objects:
# 32x32, 16x32, 32x16, 16x16.
CELL_WIDTH = 48
CELL_HEIGHT = 48
FRAME_PAD_X = CELL_WIDTH - FRAME_WIDTH
FRAME_PAD_Y = 0
OPAQUE_PALETTE_SIZE = 15
OBJ_CHUNKS = (
    (0, 0, 32, 32),
    (32, 0, 16, 32),
    (0, 32, 32, 16),
    (32, 32, 16, 16),
)


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def visible_bbox(image) -> tuple[int, int, int, int]:
    left = image.width
    top = image.height
    right = 0
    bottom = 0
    for y in range(image.height):
        for x in range(image.width):
            offset = (y * image.width + x) * 4
            if image.pixels[offset + 3] == 0:
                continue
            left = min(left, x)
            top = min(top, y)
            right = max(right, x + 1)
            bottom = max(bottom, y + 1)
    if right == 0 or bottom == 0:
        raise ValueError("save icon source contains no visible pixels")
    return left, top, right, bottom


def frame_layout(image) -> tuple[int, int, int]:
    left, top, right, _ = visible_bbox(image)
    source_x = (left // FRAME_WIDTH) * FRAME_WIDTH
    source_y = (top // FRAME_HEIGHT) * FRAME_HEIGHT
    max_frames = (image.width - source_x) // FRAME_WIDTH
    visible_frames = (right - source_x + FRAME_WIDTH - 1) // FRAME_WIDTH
    frame_count = max(1, min(max_frames, visible_frames))
    if source_y + FRAME_HEIGHT > image.height:
        raise ValueError(f"save icon frame row at y={source_y} is outside {image.height}px source")
    return source_x, source_y, frame_count


def frame_color(image, source_x: int, source_y: int, frame: int, x: int, y: int) -> tuple[int, int, int, int]:
    x -= FRAME_PAD_X
    y -= FRAME_PAD_Y
    if x >= FRAME_WIDTH or y >= FRAME_HEIGHT:
        return (0, 0, 0, 0)
    if x < 0 or y < 0:
        return (0, 0, 0, 0)
    image_x = source_x + frame * FRAME_WIDTH + x
    image_y = source_y + y
    if image_x < 0 or image_y < 0 or image_x >= image.width or image_y >= image.height:
        return (0, 0, 0, 0)
    offset = (image_y * image.width + image_x) * 4
    r, g, b, a = image.pixels[offset : offset + 4]
    if a == 0:
        return (0, 0, 0, 0)
    return (r, g, b, 255)


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
    total = sum(count for _, count in bucket)
    ranges = []
    for channel in range(3):
        values = [color[channel] for color, _ in bucket]
        ranges.append(max(values) - min(values))
    return max(ranges) * total


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


def quantized_palette(colors: Counter[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    buckets: list[list[tuple[tuple[int, int, int, int], int]]] = [list(colors.items())]
    while len(buckets) < OPAQUE_PALETTE_SIZE:
        bucket_index = max(range(len(buckets)), key=lambda index: bucket_score(buckets[index]))
        if bucket_score(buckets[bucket_index]) < 0:
            break
        left, right = split_bucket(buckets.pop(bucket_index))
        buckets.append(left)
        buckets.append(right)

    opaque = [weighted_average(bucket) for bucket in buckets]
    opaque.sort(key=lambda color: (color[0] + color[1] + color[2], color[0], color[1], color[2]))
    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (OPAQUE_PALETTE_SIZE - len(opaque))


def build_palette(image, source_x: int, source_y: int, frame_count: int) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for frame in range(frame_count):
        for y in range(FRAME_HEIGHT):
            for x in range(FRAME_WIDTH):
                color = frame_color(image, source_x, source_y, frame, x, y)
                if color[3] != 0:
                    colors[color] += 1
    if not colors:
        raise ValueError("save icon frames contain no opaque pixels")
    return quantized_palette(colors)


def pack_tiles(image, source_x: int, source_y: int, frame_count: int, palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_opaque = [color for color in palette if color[3] != 0]

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
        return palette.index(closest)

    tiles = bytearray()
    for frame in range(frame_count):
        for chunk_x, chunk_y, chunk_w, chunk_h in OBJ_CHUNKS:
            for tile_y in range(chunk_h // 8):
                for tile_x in range(chunk_w // 8):
                    tile_pixels = []
                    for y in range(8):
                        for x in range(8):
                            image_x = chunk_x + tile_x * 8 + x
                            image_y = chunk_y + tile_y * 8 + y
                            color = frame_color(image, source_x, source_y, frame, image_x, image_y)
                            tile_pixels.append(pixel_index(color))
                    write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def tiles_per_frame() -> int:
    total = 0
    for _, _, chunk_w, chunk_h in OBJ_CHUNKS:
        total += (chunk_w // 8) * (chunk_h // 8)
    return total


def write_meta(path: Path, frame_count: int, source_x: int, source_y: int) -> None:
    path.write_text(
        "\n".join(
            [
                f"pub const frame_count: u16 = {frame_count};",
                f"pub const frame_width: i16 = {FRAME_WIDTH};",
                f"pub const frame_height: i16 = {FRAME_HEIGHT};",
                f"pub const cell_width: i16 = {CELL_WIDTH};",
                f"pub const cell_height: i16 = {CELL_HEIGHT};",
                f"pub const frame_pad_x: i16 = {FRAME_PAD_X};",
                f"pub const frame_pad_y: i16 = {FRAME_PAD_Y};",
                f"pub const tiles_per_frame: u16 = {tiles_per_frame()};",
                f"pub const source_x: i16 = {source_x};",
                f"pub const source_y: i16 = {source_y};",
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
    source_x, source_y, frame_count = frame_layout(image)
    palette = build_palette(image, source_x, source_y, frame_count)
    tiles = pack_tiles(image, source_x, source_y, frame_count, palette)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "save_icon_tiles.bin").write_bytes(tiles)
    (args.output_dir / "save_icon_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    write_meta(args.output_dir / "save_icon_meta.zig", frame_count, source_x, source_y)
    (args.output_dir / "save_icon.json").write_text(
        json.dumps(
            {
                "source": str(args.input),
                "frameCount": frame_count,
                "sourceX": source_x,
                "sourceY": source_y,
                "frameWidth": FRAME_WIDTH,
                "frameHeight": FRAME_HEIGHT,
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "framePadX": FRAME_PAD_X,
                "framePadY": FRAME_PAD_Y,
                "tilesPerFrame": tiles_per_frame(),
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed save icon: {frame_count} frames from {image.width}x{image.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
