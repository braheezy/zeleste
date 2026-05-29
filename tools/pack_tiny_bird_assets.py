#!/usr/bin/env python3
"""Pack recolored 8x8 tiny-bird OBJ tiles."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from split_foreground_tileset import read_png_rgba


FRAME_NAMES = ("idle.png", "flap.png")
FRAME_WIDTH = 8
FRAME_HEIGHT = 8
VARIANTS = [
    ("cyan", ((56, 184, 216, 255), (96, 224, 248, 255), (168, 248, 255, 255))),
    ("red", ((168, 56, 72, 255), (224, 80, 96, 255), (248, 144, 152, 255))),
    ("blue", ((64, 96, 200, 255), (96, 144, 248, 255), (160, 200, 255, 255))),
    ("green", ((64, 168, 80, 255), (104, 224, 104, 255), (176, 248, 152, 255))),
    ("gold", ((184, 136, 40, 255), (232, 192, 72, 255), (248, 232, 144, 255))),
]


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def pixel_luma(color: tuple[int, int, int, int]) -> int:
    return (color[0] * 30 + color[1] * 59 + color[2] * 11) // 100


def shade_for(color: tuple[int, int, int, int]) -> int:
    luma = pixel_luma(color)
    if luma < 235:
        return 0
    if luma < 250:
        return 1
    return 2


def pack_frame(path: Path, variant_index: int) -> bytes:
    image = read_png_rgba(path)
    if image.width != FRAME_WIDTH or image.height != FRAME_HEIGHT:
        raise ValueError(f"{path} must be {FRAME_WIDTH}x{FRAME_HEIGHT}")

    pixels: list[int] = []
    for y in range(FRAME_HEIGHT):
        for x in range(FRAME_WIDTH):
            offset = (y * image.width + x) * 4
            color = tuple(image.pixels[offset : offset + 4])
            if color[3] == 0:
                pixels.append(0)
            else:
                pixels.append(1 + variant_index * 3 + shade_for(color))
    output = bytearray()
    write_tile_4bpp(output, pixels)
    return bytes(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    tiles = bytearray()
    for variant_index, _variant in enumerate(VARIANTS):
        for name in FRAME_NAMES:
            tiles.extend(pack_frame(args.input_dir / name, variant_index))

    palette = [(0, 0, 0, 0)]
    for _name, colors in VARIANTS:
        palette.extend(colors)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "tiny_bird_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "tiny_bird_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "tiny_bird.json").write_text(
        json.dumps(
            {
                "frameWidth": FRAME_WIDTH,
                "frameHeight": FRAME_HEIGHT,
                "frameCount": len(FRAME_NAMES),
                "variantCount": len(VARIANTS),
                "variants": [name for name, _colors in VARIANTS],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed tiny birds: {len(VARIANTS)} variants, {len(FRAME_NAMES)} frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
