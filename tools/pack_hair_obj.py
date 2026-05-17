#!/usr/bin/env python3
"""Pack Madeline hair parts into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from split_foreground_tileset import read_png_rgba


PARTS = [
    ("root1", "root1.png"),
    ("root2", "root2.png"),
    ("tail", "tail-normal.png"),
]


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    root2_path = args.input_dir / "root2.png"
    sources = []
    colors = set()
    for name, filename in PARTS:
        path = args.input_dir / filename
        if not path.exists() and name == "tail":
            path = root2_path
        image = read_png_rgba(path)
        if image.width != 8 or image.height != 8:
            raise ValueError(f"{path} must be 8x8, got {image.width}x{image.height}")
        for index in range(0, len(image.pixels), 4):
            color = tuple(image.pixels[index : index + 4])
            if color[3] != 0:
                colors.add(color)
        sources.append((name, path, image))

    opaque = sorted(colors)
    if len(opaque) > 15:
        raise ValueError(f"hair uses {len(opaque)} opaque colors; 4bpp supports 15")
    palette = [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (16 - 1 - len(opaque))
    palette_index = {color: index for index, color in enumerate(palette)}

    tiles = bytearray()
    parts = []
    for name, path, image in sources:
        tile_pixels = []
        for y in range(8):
            for x in range(8):
                offset = (y * image.width + x) * 4
                color = tuple(image.pixels[offset : offset + 4])
                tile_pixels.append(0 if color[3] == 0 else palette_index[color])
        parts.append({"name": name, "source": str(path), "baseTile": len(tiles) // 32})
        write_tile_4bpp(tiles, tile_pixels)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "hair_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "hair_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "hair.json").write_text(
        json.dumps(
            {
                "tileCount": len(tiles) // 32,
                "parts": parts,
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed hair: {len(tiles) // 32} tiles, {len(opaque)} opaque colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
