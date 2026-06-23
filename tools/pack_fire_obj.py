#!/usr/bin/env python3
"""Pack small fire animation frames into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


FRAME_RE = re.compile(r"^f(\d+)\.png$")
SHEET_NAME = "sheet.png"
CELL_WIDTH = 16
CELL_HEIGHT = 32
OPAQUE_PALETTE_SIZE = 15


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected fire frame name: {path}")
    return int(match.group(1))


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def crop_sheet_frame(sheet: Image, index: int) -> Image:
    pixels = bytearray(CELL_WIDTH * CELL_HEIGHT * 4)
    start_x = index * CELL_WIDTH
    for y in range(CELL_HEIGHT):
        source_offset = (y * sheet.width + start_x) * 4
        target_offset = y * CELL_WIDTH * 4
        pixels[target_offset : target_offset + CELL_WIDTH * 4] = sheet.pixels[
            source_offset : source_offset + CELL_WIDTH * 4
        ]
    return Image(CELL_WIDTH, CELL_HEIGHT, bytes(pixels))


def load_frames(input_dir: Path) -> list[tuple[Path, Image]]:
    sheet_path = input_dir / SHEET_NAME
    if sheet_path.exists():
        sheet = read_png_rgba(sheet_path)
        if sheet.height != CELL_HEIGHT or sheet.width % CELL_WIDTH != 0:
            raise ValueError(f"{sheet_path} must be a row of {CELL_WIDTH}x{CELL_HEIGHT} cells")
        return [
            (Path(f"sheet_{index:04d}"), crop_sheet_frame(sheet, index))
            for index in range(sheet.width // CELL_WIDTH)
        ]

    frame_paths = sorted(input_dir.glob("f*.png"), key=frame_index)
    if not frame_paths:
        raise ValueError(f"no f*.png fire frames found in {input_dir}")

    frames: list[tuple[Path, Image]] = []
    for path in frame_paths:
        image = read_png_rgba(path)
        if image.width != CELL_WIDTH or image.height != CELL_HEIGHT:
            raise ValueError(f"{path} must be {CELL_WIDTH}x{CELL_HEIGHT}, got {image.width}x{image.height}")
        frames.append((path, image))
    return frames


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


def build_palette(frames: list[tuple[Path, Image]]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    first_seen: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for _, image in frames:
        for index in range(0, len(image.pixels), 4):
            r, g, b, a = image.pixels[index : index + 4]
            if a == 0:
                continue
            color = (r, g, b, 255)
            colors[color] += 1
            if color not in seen:
                seen.add(color)
                first_seen.append(color)

    if not colors:
        raise ValueError("fire frames contain no opaque pixels")
    if len(first_seen) <= OPAQUE_PALETTE_SIZE:
        return [(0, 0, 0, 0)] + first_seen + [(0, 0, 0, 255)] * (OPAQUE_PALETTE_SIZE - len(first_seen))
    return quantized_palette(colors)


def pack_frames(frames: list[tuple[Path, Image]], palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_index = {color: index for index, color in enumerate(palette)}
    palette_opaque = [color for color in palette if color[3] != 0]

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        color = (color[0], color[1], color[2], 255)
        if color in palette_index:
            return palette_index[color]
        closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
        return palette_index[closest]

    tiles = bytearray()
    for path, image in frames:
        if image.width != CELL_WIDTH or image.height != CELL_HEIGHT:
            raise ValueError(f"{path} must be {CELL_WIDTH}x{CELL_HEIGHT}, got {image.width}x{image.height}")
        for tile_y in range(CELL_HEIGHT // 8):
            for tile_x in range(CELL_WIDTH // 8):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x
                        image_y = tile_y * 8 + y
                        offset = (image_y * image.width + image_x) * 4
                        tile_pixels.append(pixel_index(tuple(image.pixels[offset : offset + 4])))
                write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def write_meta(path: Path, frame_count: int) -> None:
    tiles_per_frame = (CELL_WIDTH // 8) * (CELL_HEIGHT // 8)
    path.write_text(
        "\n".join(
            [
                f"pub const frame_count: u16 = {frame_count};",
                f"pub const cell_width: i16 = {CELL_WIDTH};",
                f"pub const cell_height: i16 = {CELL_HEIGHT};",
                f"pub const tiles_per_frame: u16 = {tiles_per_frame};",
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    frames = load_frames(args.input_dir)
    palette = build_palette(frames)
    tiles = pack_frames(frames, palette)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "fire_small1_tiles.bin").write_bytes(tiles)
    (args.output_dir / "fire_small1_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    write_meta(args.output_dir / "fire_small1_meta.zig", len(frames))
    (args.output_dir / "fire_small1.json").write_text(
        json.dumps(
            {
                "source": str(args.input_dir),
                "frameCount": len(frames),
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "tilesPerFrame": (CELL_WIDTH // 8) * (CELL_HEIGHT // 8),
                "paletteRgba": [list(color) for color in palette],
                "frames": [{"source": path.name, "sourceFrame": index} for index, (path, _) in enumerate(frames)],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed small fire: {len(frames)} frames, {len(tiles) // 32} tiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
