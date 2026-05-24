#!/usr/bin/env python3
"""Pack 16x16 foreground stamp animations into 4bpp OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


VALID_FRAME_SIZES = {(8, 8), (8, 16), (16, 8), (16, 16)}


def frame_sort_key(path: Path) -> int | str:
    return int(path.stem) if path.stem.isdigit() else path.stem


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--name", required=True)
    args = parser.parse_args()

    frame_paths = sorted(args.input_dir.glob("*.png"), key=frame_sort_key)
    if not frame_paths:
        raise ValueError(f"no PNG frames in {args.input_dir}")

    frames = []
    colors: Counter[tuple[int, int, int, int]] = Counter()
    frame_width = 0
    frame_height = 0
    for path in frame_paths:
        image = read_png_rgba(path)
        if (image.width, image.height) not in VALID_FRAME_SIZES:
            raise ValueError(f"{path} must be 8x8, 8x16, 16x8, or 16x16, got {image.width}x{image.height}")
        if frame_width == 0:
            frame_width = image.width
            frame_height = image.height
        elif image.width != frame_width or image.height != frame_height:
            raise ValueError(f"{path} is {image.width}x{image.height}; expected {frame_width}x{frame_height}")
        frames.append((path, image))
        for index in range(0, len(image.pixels), 4):
            color = tuple(image.pixels[index : index + 4])
            if color[3] != 0:
                colors[color] += 1

    opaque = [color for color, _ in colors.most_common()]
    if len(opaque) > 15:
        raise ValueError(f"{args.input_dir} uses {len(opaque)} opaque colors; 4bpp supports 15")
    palette = [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (15 - len(opaque))
    palette_index = {color: index for index, color in enumerate(palette)}

    tiles = bytearray()
    for _, image in frames:
        for tile_y in range(image.height // 8):
            for tile_x in range(image.width // 8):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x
                        image_y = tile_y * 8 + y
                        offset = (image_y * image.width + image_x) * 4
                        color = tuple(image.pixels[offset : offset + 4])
                        tile_pixels.append(0 if color[3] == 0 else palette_index[color])
                write_tile_4bpp(tiles, tile_pixels)

    tiles_per_frame = (frame_width // 8) * (frame_height // 8)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / f"{args.name}_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / f"{args.name}_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / f"{args.name}.json").write_text(
        json.dumps(
            {
                "name": args.name,
                "frameCount": len(frames),
                "tilesPerFrame": tiles_per_frame,
                "width": frame_width,
                "height": frame_height,
                "sourceFrames": [path.name for path, _ in frames],
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed foreground stamp {args.name}: {len(frames)} frames, {len(opaque)} opaque colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
