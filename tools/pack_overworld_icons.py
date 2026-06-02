#!/usr/bin/env python3
"""Pack prepared overworld chapter icons into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


OPAQUE_PALETTE_SIZE = 15
TILE_SIZE = 8
ICON_SIZE = 32


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(TILE_SIZE):
        for x_pair in range(TILE_SIZE // 2):
            left = pixels[y * TILE_SIZE + x_pair * 2]
            right = pixels[y * TILE_SIZE + x_pair * 2 + 1]
            output.append(left | (right << 4))


def image_color(image: Image, x: int, y: int) -> tuple[int, int, int, int]:
    offset = (y * image.width + x) * 4
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


def build_palette(images: list[Image]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for image in images:
        if image.width != ICON_SIZE or image.height != ICON_SIZE:
            raise ValueError(f"expected {ICON_SIZE}x{ICON_SIZE} icon, got {image.width}x{image.height}")
        for y in range(image.height):
            for x in range(image.width):
                color = image_color(image, x, y)
                if color[3] != 0:
                    colors[color] += 1
    if not colors:
        raise ValueError("icon contains no opaque pixels")
    return quantized_palette(colors)


def pixel_index(color: tuple[int, int, int, int], palette: list[tuple[int, int, int, int]]) -> int:
    if color[3] == 0:
        return 0
    opaque = palette[1:]
    closest = min(opaque, key=lambda candidate: color_distance(color, candidate))
    return palette.index(closest)


def pack_icon(image: Image, palette: list[tuple[int, int, int, int]], output: bytearray) -> None:
    for tile_y in range(ICON_SIZE // TILE_SIZE):
        for tile_x in range(ICON_SIZE // TILE_SIZE):
            tile_pixels = []
            for y in range(TILE_SIZE):
                for x in range(TILE_SIZE):
                    image_x = tile_x * TILE_SIZE + x
                    image_y = tile_y * TILE_SIZE + y
                    tile_pixels.append(pixel_index(image_color(image, image_x, image_y), palette))
            write_tile_4bpp(output, tile_pixels)


def write_meta(path: Path, chapters: list[dict], tiles_per_icon: int) -> None:
    lines = [
        "pub const chapter_count: usize = {};".format(len(chapters)),
        "pub const icon_width: i16 = {};".format(ICON_SIZE),
        "pub const icon_height: i16 = {};".format(ICON_SIZE),
        "pub const tiles_per_icon: u16 = {};".format(tiles_per_icon),
        "pub const max_icons_per_page: usize = {};".format(max(sum(1 for chapter in chapters if chapter["page"] == page) for page in {chapter["page"] for chapter in chapters})),
        "pub const Chapter = struct {",
        "    chapter: u8,",
        "    page: u8,",
        "    x: i16,",
        "    y: i16,",
        "    implemented: bool,",
        "    palette_bank: u4,",
        "    tile_offset: u16,",
        "};",
        "pub const chapters = [_]Chapter{",
    ]
    tile_offset = 0
    for index, chapter in enumerate(chapters):
        lines.append(
            "    .{{ .chapter = {}, .page = {}, .x = {}, .y = {}, .implemented = {}, .palette_bank = {}, .tile_offset = {} }},".format(
                index,
                chapter["page"],
                chapter["x"],
                chapter["y"],
                "true" if chapter["implemented"] else "false",
                index,
                tile_offset,
            )
        )
        tile_offset += tiles_per_icon
    lines.extend(["};", ""])
    path.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    chapters = manifest["chapters"]
    tiles_per_icon = (ICON_SIZE // TILE_SIZE) * (ICON_SIZE // TILE_SIZE)

    tiles = bytearray()
    palettes: list[tuple[int, int, int, int]] = []

    for chapter in chapters:
        image = read_png_rgba(Path(chapter["icon"]))
        palette = build_palette([image])
        palettes.extend(palette)
        pack_icon(image, palette, tiles)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "overworld_icon_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "overworld_icon_palettes.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palettes)
    )
    write_meta(args.output_dir / "overworld_icon_meta.zig", chapters, tiles_per_icon)
    print(f"packed overworld icons: {len(chapters)} chapters, {tiles_per_icon} tiles/icon")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
