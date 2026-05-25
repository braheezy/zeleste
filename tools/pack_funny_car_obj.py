#!/usr/bin/env python3
"""Pack the prologue funny car into 4bpp OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


CHUNKS = [
    {"x": 0, "y": 0, "width": 32, "height": 16, "size": "32x16"},
    {"x": 32, "y": 0, "width": 16, "height": 16, "size": "16x16"},
]


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    if image.width > 48 or image.height > 16:
        raise ValueError(f"{args.input} must fit in 48x16, got {image.width}x{image.height}")

    colors: Counter[tuple[int, int, int, int]] = Counter()
    for index in range(0, len(image.pixels), 4):
        color = tuple(image.pixels[index : index + 4])
        if color[3] != 0:
            colors[color] += 1

    opaque = [color for color, _ in colors.most_common(15)]
    palette = [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (15 - len(opaque))
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

    tiles = bytearray()
    manifest_chunks = []
    base_tile = 0
    for chunk in CHUNKS:
        tiles_wide = chunk["width"] // 8
        tiles_high = chunk["height"] // 8
        tile_count = tiles_wide * tiles_high
        manifest_chunks.append({**chunk, "baseTile": base_tile, "tileCount": tile_count})
        base_tile += tile_count
        for tile_y in range(tiles_high):
            for tile_x in range(tiles_wide):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        tile_pixels.append(pixel_index(chunk["x"] + tile_x * 8 + x, chunk["y"] + tile_y * 8 + y))
                write_tile_4bpp(tiles, tile_pixels)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "funny_car_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "funny_car_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "funny_car.json").write_text(
        json.dumps(
            {
                "source": str(args.input),
                "width": image.width,
                "height": image.height,
                "tileCount": len(tiles) // 32,
                "chunks": manifest_chunks,
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed funny car: {len(tiles) // 32} tiles, {len(opaque)} opaque colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
