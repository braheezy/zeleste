#!/usr/bin/env python3
"""Pack disappearing platform 8x8 OBJ tile variants into 4bpp GBA tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


OUTLINE_COLOR = (203, 219, 252, 255)


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    if image.width % 8 != 0 or image.height != 8:
        raise ValueError(f"{args.input} must be a horizontal strip of 8x8 tiles, got {image.width}x{image.height}")

    colors: Counter[tuple[int, int, int, int]] = Counter()
    for index in range(0, len(image.pixels), 4):
        color = tuple(image.pixels[index : index + 4])
        if color[3] != 0:
            colors[color] += 1

    palette_opaque = [color for color, _ in colors.most_common() if color != OUTLINE_COLOR]
    palette = [(0, 0, 0, 0)] + palette_opaque[:14]
    while len(palette) < 15:
        palette.append((0, 0, 0, 255))
    palette.append(OUTLINE_COLOR)
    palette_index = {color: index for index, color in enumerate(palette)}

    def pixel_index(x: int, y: int) -> int:
        offset = (y * image.width + x) * 4
        color = tuple(image.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color in palette_index:
            return palette_index[color]
        closest = min(palette[1:], key=lambda candidate: color_distance(color, candidate))
        return palette_index[closest]

    tile_count = image.width // 8
    tiles = bytearray()
    for tile_x in range(tile_count):
        tile_pixels = []
        for y in range(8):
            for x in range(8):
                tile_pixels.append(pixel_index(tile_x * 8 + x, y))
        write_tile_4bpp(tiles, tile_pixels)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "disappearing_platform_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "disappearing_platform_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "disappearing_platform.json").write_text(
        json.dumps(
            {
                "source": str(args.input),
                "variantCount": tile_count,
                "tileCount": tile_count,
                "outlineColorIndex": 15,
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed disappearing platform: {tile_count} variants, {len(palette_opaque)} source colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
