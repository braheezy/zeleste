#!/usr/bin/env python3
"""Prepare file-select background and scroll animation assets."""

from __future__ import annotations

import argparse
import math
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from split_foreground_tileset import Image, read_png_rgba, write_png_rgba  # noqa: E402


SCREEN_WIDTH = 240
SCREEN_HEIGHT = 160
SCROLL_PALETTE_BASE = 240
SCROLL_PALETTE_LIMIT = 10
SCROLL_FRAME_COUNT = 7


def gba_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def lerp(left: int, right: int, amount: float) -> float:
    return left + (right - left) * amount


def sample_bilinear(image: Image, x: float, y: float) -> tuple[int, int, int, int]:
    x = min(max(x, 0.0), image.width - 1)
    y = min(max(y, 0.0), image.height - 1)
    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    x1 = min(x0 + 1, image.width - 1)
    y1 = min(y0 + 1, image.height - 1)
    tx = x - x0
    ty = y - y0

    def pixel(px: int, py: int) -> tuple[int, int, int, int]:
        offset = (py * image.width + px) * 4
        return tuple(image.pixels[offset : offset + 4])

    c00 = pixel(x0, y0)
    c10 = pixel(x1, y0)
    c01 = pixel(x0, y1)
    c11 = pixel(x1, y1)
    out = []
    for channel in range(4):
        top = lerp(c00[channel], c10[channel], tx)
        bottom = lerp(c01[channel], c11[channel], tx)
        out.append(int(round(lerp(top, bottom, ty))))
    return tuple(out)


def resize_cover(image: Image, width: int, height: int) -> Image:
    scale = max(width / image.width, height / image.height)
    scaled_width = image.width * scale
    scaled_height = image.height * scale
    crop_x = (scaled_width - width) / 2
    crop_y = (scaled_height - height) / 2

    pixels = bytearray(width * height * 4)
    for y in range(height):
        source_y = (y + crop_y + 0.5) / scale - 0.5
        for x in range(width):
            source_x = (x + crop_x + 0.5) / scale - 0.5
            offset = (y * width + x) * 4
            pixels[offset : offset + 4] = bytes(sample_bilinear(image, source_x, source_y))
    return Image(width, height, bytes(pixels))


def pack_scroll(
    scroll: Image,
) -> tuple[bytes, list[tuple[int, int, int, int]], int, int, int, list[tuple[int, int, int, int]]]:
    frame_height = scroll.height
    frame_count = SCROLL_FRAME_COUNT
    if frame_height == 0 or scroll.width % frame_count != 0:
        raise ValueError(
            f"scroll sheet must contain {frame_count} even horizontal frames, got {scroll.width}x{scroll.height}"
        )
    frame_width = scroll.width // frame_count

    counts: Counter[tuple[int, int, int, int]] = Counter()
    for offset in range(0, len(scroll.pixels), 4):
        color = tuple(scroll.pixels[offset : offset + 4])
        if color[3] != 0:
            counts[color] += 1
    colors = [color for color, _ in counts.most_common()]
    if len(colors) > SCROLL_PALETTE_LIMIT:
        raise ValueError(f"scroll has {len(colors)} opaque colors; limit is {SCROLL_PALETTE_LIMIT}")
    color_index = {color: SCROLL_PALETTE_BASE + index for index, color in enumerate(colors)}

    packed = bytearray(frame_count * frame_width * frame_height)
    bounds: list[tuple[int, int, int, int]] = []
    for frame in range(frame_count):
        min_x = frame_width
        min_y = frame_height
        max_x = 0
        max_y = 0
        has_pixels = False
        for y in range(frame_height):
            for x in range(frame_width):
                src_offset = (y * scroll.width + frame * frame_width + x) * 4
                color = tuple(scroll.pixels[src_offset : src_offset + 4])
                dst_offset = frame * frame_width * frame_height + y * frame_width + x
                packed[dst_offset] = 0 if color[3] == 0 else color_index[color]
                if color[3] != 0:
                    min_x = min(min_x, x)
                    min_y = min(min_y, y)
                    max_x = max(max_x, x + 1)
                    max_y = max(max_y, y + 1)
                    has_pixels = True
        bounds.append((min_x, min_y, max_x, max_y) if has_pixels else (0, 0, 0, 0))

    return bytes(packed), colors, frame_width, frame_height, frame_count, bounds


def zig_array(name: str, values: list[int]) -> str:
    return f"pub const {name}: [{len(values)}]u16 = .{{ {', '.join(str(value) for value in values)} }};"


def write_meta(
    path: Path,
    frame_width: int,
    frame_height: int,
    frame_count: int,
    palette_count: int,
    bounds: list[tuple[int, int, int, int]],
) -> None:
    path.write_text(
        "\n".join(
            [
                f"pub const frame_width: u16 = {frame_width};",
                f"pub const frame_height: u16 = {frame_height};",
                f"pub const frame_count: u16 = {frame_count};",
                f"pub const palette_base: u8 = {SCROLL_PALETTE_BASE};",
                f"pub const palette_count: u8 = {palette_count};",
                zig_array("frame_min_x", [bound[0] for bound in bounds]),
                zig_array("frame_min_y", [bound[1] for bound in bounds]),
                zig_array("frame_max_x", [bound[2] for bound in bounds]),
                zig_array("frame_max_y", [bound[3] for bound in bounds]),
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--scroll", type=Path, required=True)
    parser.add_argument("--background-output", type=Path, required=True)
    parser.add_argument("--scroll-pixels-output", type=Path, required=True)
    parser.add_argument("--scroll-palette-output", type=Path, required=True)
    parser.add_argument("--scroll-meta-output", type=Path, required=True)
    args = parser.parse_args()

    background = resize_cover(read_png_rgba(args.background), SCREEN_WIDTH, SCREEN_HEIGHT)
    args.background_output.parent.mkdir(parents=True, exist_ok=True)
    write_png_rgba(args.background_output, background)

    pixels, palette, frame_width, frame_height, frame_count, bounds = pack_scroll(read_png_rgba(args.scroll))
    args.scroll_pixels_output.parent.mkdir(parents=True, exist_ok=True)
    args.scroll_pixels_output.write_bytes(pixels)
    args.scroll_palette_output.write_bytes(b"".join(struct.pack("<H", gba_rgb555(color)) for color in palette))
    write_meta(args.scroll_meta_output, frame_width, frame_height, frame_count, len(palette), bounds)

    print(
        f"prepared file select bg {SCREEN_WIDTH}x{SCREEN_HEIGHT}; "
        f"scroll {frame_count} frames {frame_width}x{frame_height}, {len(palette)} colors"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
