#!/usr/bin/env python3
"""Pack a 3x5 bitmap font sheet into glyph masks."""

from __future__ import annotations

import argparse
from pathlib import Path

from split_foreground_tileset import read_png_rgba


DEFAULT_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
GLYPH_WIDTH = 3
GLYPH_HEIGHT = 5
GRID_ADVANCE = 4
ROW_HEIGHT = 6


def opaque(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[3] != 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--meta-output", type=Path, required=True)
    parser.add_argument("--chars", default=DEFAULT_CHARS)
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    glyphs = bytearray()
    for index, _ in enumerate(args.chars):
        row = index // (image.width // GRID_ADVANCE)
        col = index % (image.width // GRID_ADVANCE)
        origin_x = col * GRID_ADVANCE
        origin_y = row * ROW_HEIGHT
        if origin_x + GLYPH_WIDTH > image.width or origin_y + GLYPH_HEIGHT > image.height:
            raise ValueError(f"glyph {index} falls outside {args.input}")
        for y in range(GLYPH_HEIGHT):
            bits = 0
            for x in range(GLYPH_WIDTH):
                offset = ((origin_y + y) * image.width + origin_x + x) * 4
                if opaque(tuple(image.pixels[offset : offset + 4])):
                    bits |= 1 << (GLYPH_WIDTH - 1 - x)
            glyphs.append(bits)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(bytes(glyphs))
    args.meta_output.write_text(
        "\n".join(
            [
                f'pub const chars = "{args.chars}";',
                f"pub const glyph_width: u8 = {GLYPH_WIDTH};",
                f"pub const glyph_height: u8 = {GLYPH_HEIGHT};",
                f"pub const glyph_count: u8 = {len(args.chars)};",
                "",
            ]
        )
    )
    print(f"packed bitmap font: {len(args.chars)} glyphs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
