#!/usr/bin/env python3
"""Pack file-select portrait cells into indexed BG pixels."""

from __future__ import annotations

import argparse
from pathlib import Path

from split_foreground_tileset import read_png_rgba


FRAME_WIDTH = 28
FRAME_HEIGHT = 28
GRID_COLUMNS = 4
GRID_ROWS = 2
PALETTE_BASE = 228


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_at(image, x: int, y: int) -> tuple[int, int, int, int]:
    offset = (y * image.width + x) * 4
    return tuple(image.pixels[offset : offset + 4])  # type: ignore[return-value]


def frame_bounds(image_width: int, col: int) -> tuple[int, int]:
    start = (col * image_width + GRID_COLUMNS // 2) // GRID_COLUMNS
    end = ((col + 1) * image_width + GRID_COLUMNS // 2) // GRID_COLUMNS
    return start, end


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--pixels-output", type=Path, required=True)
    parser.add_argument("--palette-output", type=Path, required=True)
    parser.add_argument("--meta-output", type=Path, required=True)
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    if image.height != FRAME_HEIGHT * GRID_ROWS:
        raise ValueError(f"{args.input} must be {FRAME_HEIGHT * GRID_ROWS}px tall")

    palette: list[tuple[int, int, int, int]] = []
    palette_index: dict[tuple[int, int, int, int], int] = {}
    pixels = bytearray()
    for row in range(GRID_ROWS):
        source_y = row * FRAME_HEIGHT
        for col in range(GRID_COLUMNS):
            source_x, source_end_x = frame_bounds(image.width, col)
            source_width = source_end_x - source_x
            for y in range(FRAME_HEIGHT):
                for x in range(FRAME_WIDTH):
                    if x >= source_width:
                        pixels.append(0)
                        continue
                    color = color_at(image, source_x + x, source_y + y)
                    if color[3] == 0:
                        pixels.append(0)
                        continue
                    normalized = (color[0], color[1], color[2], 255)
                    if normalized not in palette_index:
                        if len(palette) >= 12:
                            raise ValueError(f"{args.input} has too many opaque portrait colors")
                        palette_index[normalized] = len(palette)
                        palette.append(normalized)
                    pixels.append(PALETTE_BASE + palette_index[normalized])

    args.pixels_output.parent.mkdir(parents=True, exist_ok=True)
    args.pixels_output.write_bytes(bytes(pixels))
    args.palette_output.write_bytes(b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette))
    args.meta_output.write_text(
        "\n".join(
            [
                f"pub const frame_width: u16 = {FRAME_WIDTH};",
                f"pub const frame_height: u16 = {FRAME_HEIGHT};",
                f"pub const frame_count: u16 = {GRID_COLUMNS * GRID_ROWS};",
                f"pub const palette_base: u8 = {PALETTE_BASE};",
                f"pub const palette_count: u8 = {len(palette)};",
                "",
            ]
        )
    )
    print(f"packed file-select portraits: {GRID_COLUMNS * GRID_ROWS} frames, {len(palette)} colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
