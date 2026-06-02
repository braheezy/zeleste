#!/usr/bin/env python3
"""Pack spring animation frames into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba


FRAME_RE = re.compile(r"^frame_(\d+)\.png$")
SOURCE_FRAME_WIDTH = 24
SOURCE_FRAME_HEIGHT = 32
DRAW_WIDTH = 14
DRAW_HEIGHT = round(SOURCE_FRAME_HEIGHT * DRAW_WIDTH / SOURCE_FRAME_WIDTH)
CELL_WIDTH = 16
CELL_HEIGHT = 32
SHEET_NAME = "spring_14px_sheet.png"
OPAQUE_PALETTE_SIZE = 15


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected spring frame name: {path}")
    return int(match.group(1))


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


def resize_nearest(image: Image, width: int, height: int) -> Image:
    pixels = bytearray(width * height * 4)
    for y in range(height):
        source_y = min(image.height - 1, int((y + 0.5) * image.height / height))
        for x in range(width):
            source_x = min(image.width - 1, int((x + 0.5) * image.width / width))
            source_offset = (source_y * image.width + source_x) * 4
            target_offset = (y * width + x) * 4
            pixels[target_offset : target_offset + 4] = image.pixels[source_offset : source_offset + 4]
    return Image(width, height, bytes(pixels))


def paste_into_cell(image: Image) -> Image:
    if image.width > CELL_WIDTH or image.height > CELL_HEIGHT:
        raise ValueError(f"spring frame {image.width}x{image.height} is larger than {CELL_WIDTH}x{CELL_HEIGHT}")
    pad_x = (CELL_WIDTH - image.width) // 2
    pixels = bytearray(CELL_WIDTH * CELL_HEIGHT * 4)
    for y in range(image.height):
        source_offset = y * image.width * 4
        target_offset = (y * CELL_WIDTH + pad_x) * 4
        pixels[target_offset : target_offset + image.width * 4] = image.pixels[
            source_offset : source_offset + image.width * 4
        ]
    return Image(CELL_WIDTH, CELL_HEIGHT, bytes(pixels))


def crop_cell(sheet: Image, frame: int) -> Image:
    pixels = bytearray(CELL_WIDTH * CELL_HEIGHT * 4)
    start_x = frame * CELL_WIDTH
    for y in range(CELL_HEIGHT):
        source_offset = (y * sheet.width + start_x) * 4
        target_offset = y * CELL_WIDTH * 4
        pixels[target_offset : target_offset + CELL_WIDTH * 4] = sheet.pixels[
            source_offset : source_offset + CELL_WIDTH * 4
        ]
    return Image(CELL_WIDTH, CELL_HEIGHT, bytes(pixels))


def write_sheet(path: Path, frames: list[tuple[Path, Image]]) -> None:
    sheet_width = CELL_WIDTH * len(frames)
    pixels = bytearray(sheet_width * CELL_HEIGHT * 4)
    for frame_index_out, (_, image) in enumerate(frames):
        start_x = frame_index_out * CELL_WIDTH
        for y in range(CELL_HEIGHT):
            source_offset = y * CELL_WIDTH * 4
            target_offset = (y * sheet_width + start_x) * 4
            pixels[target_offset : target_offset + CELL_WIDTH * 4] = image.pixels[
                source_offset : source_offset + CELL_WIDTH * 4
            ]
    write_png_rgba(path, Image(sheet_width, CELL_HEIGHT, bytes(pixels)))


def load_source_frames(input_dir: Path) -> list[tuple[Path, Image]]:
    frame_paths = sorted(input_dir.glob("frame_*.png"), key=frame_index)
    if not frame_paths:
        raise ValueError(f"no spring frame_*.png files found in {input_dir}")

    frames = []
    for path in frame_paths:
        image = read_png_rgba(path)
        if image.width != SOURCE_FRAME_WIDTH or image.height != SOURCE_FRAME_HEIGHT:
            raise ValueError(
                f"{path} must be {SOURCE_FRAME_WIDTH}x{SOURCE_FRAME_HEIGHT}, got {image.width}x{image.height}"
            )
        frames.append((path, paste_into_cell(resize_nearest(image, DRAW_WIDTH, DRAW_HEIGHT))))
    return frames


def load_frames(input_dir: Path) -> list[tuple[Path, Image]]:
    sheet_path = input_dir / SHEET_NAME
    if not sheet_path.exists():
        frames = load_source_frames(input_dir)
        write_sheet(sheet_path, frames)
        return frames

    sheet = read_png_rgba(sheet_path)
    if sheet.height != CELL_HEIGHT or sheet.width % CELL_WIDTH != 0:
        raise ValueError(f"{sheet_path} must be a row of {CELL_WIDTH}x{CELL_HEIGHT} cells")
    frames = []
    for index in range(sheet.width // CELL_WIDTH):
        frames.append((Path(f"sheet_{index:04d}"), crop_cell(sheet, index)))
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


def split_bucket(bucket: list[tuple[tuple[int, int, int, int], int]]) -> tuple[
    list[tuple[tuple[int, int, int, int], int]],
    list[tuple[tuple[int, int, int, int], int]],
]:
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


def build_palette(frames: list[tuple[Path, object]]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for _, image in frames:
        for index in range(0, len(image.pixels), 4):
            r, g, b, a = image.pixels[index : index + 4]
            if a != 0:
                colors[(r, g, b, 255)] += 1
    if not colors:
        raise ValueError("spring frames contain no opaque pixels")
    return quantized_palette(colors)


def pack_frames(frames: list[tuple[Path, object]], palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_opaque = [color for color in palette if color[3] != 0]

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
        return palette.index(closest)

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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    frames = load_frames(args.input_dir)
    palette = build_palette(frames)
    tiles = pack_frames(frames, palette)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "spring_tiles.bin").write_bytes(tiles)
    (args.output_dir / "spring_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "spring.json").write_text(
        json.dumps(
            {
                "source": str(args.input_dir),
                "frameCount": len(frames),
                "sourceFrameWidth": SOURCE_FRAME_WIDTH,
                "sourceFrameHeight": SOURCE_FRAME_HEIGHT,
                "drawWidth": DRAW_WIDTH,
                "drawHeight": DRAW_HEIGHT,
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "tilesPerFrame": (CELL_WIDTH // 8) * (CELL_HEIGHT // 8),
                "horizontalPad": (CELL_WIDTH - DRAW_WIDTH) // 2,
                "idleTop": 14,
                "editableSheet": SHEET_NAME,
                "paletteRgba": [list(color) for color in palette],
                "frames": [{"source": path.name, "sourceFrame": index} for index, (path, _) in enumerate(frames)],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed spring: {len(frames)} frames, {len(tiles) // 32} tiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
