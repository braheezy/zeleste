#!/usr/bin/env python3
"""Pack a transparent parallax PNG into 64x64 4bpp OBJ chunks."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


CHUNK_SIZE = 64
MAX_OPAQUE_COLORS = 15


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
    parser.add_argument("--name", required=True)
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    if image.width == 0 or image.height == 0:
        raise ValueError("empty parallax image")
    if image.height > CHUNK_SIZE:
        raise ValueError(f"{args.input} is {image.height}px high; this packer supports one 64px OBJ row")

    colors: Counter[tuple[int, int, int, int]] = Counter()
    for index in range(0, len(image.pixels), 4):
        color = tuple(image.pixels[index : index + 4])
        if color[3] != 0:
            colors[color] += 1

    opaque = [color for color, _ in colors.most_common(MAX_OPAQUE_COLORS)]
    if not opaque and colors:
        raise ValueError("unexpected empty opaque palette")
    palette = [(0, 0, 0, 0)] + opaque
    palette += [(0, 0, 0, 255)] * (16 - len(palette))
    palette_index = {color: index for index, color in enumerate(palette)}

    def pixel_index(x: int, y: int) -> int:
        if x >= image.width or y >= image.height:
            return 0
        offset = (y * image.width + x) * 4
        color = tuple(image.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color not in palette_index:
            closest = min(opaque, key=lambda candidate: color_distance(color, candidate))
            return palette_index[closest]
        return palette_index[color]

    chunk_count = (image.width + CHUNK_SIZE - 1) // CHUNK_SIZE
    tiles = bytearray()
    for chunk in range(chunk_count):
        chunk_x = chunk * CHUNK_SIZE
        for tile_y in range(CHUNK_SIZE // 8):
            for tile_x in range(CHUNK_SIZE // 8):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        tile_pixels.append(pixel_index(chunk_x + tile_x * 8 + x, tile_y * 8 + y))
                write_tile_4bpp(tiles, tile_pixels)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / f"{args.name}_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / f"{args.name}_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / f"{args.name}.json").write_text(
        json.dumps(
            {
                "source": str(args.input),
                "width": image.width,
                "height": image.height,
                "chunkSize": CHUNK_SIZE,
                "chunkCount": chunk_count,
                "tileCount": len(tiles) // 32,
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed parallax {args.name}: {chunk_count} chunks, {len(tiles) // 32} tiles, {len(opaque)} opaque colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
