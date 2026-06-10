#!/usr/bin/env python3
"""Pack Theo speech bubble prompts into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


CELL_WIDTH = 32
CELL_HEIGHT = 32
OPAQUE_PALETTE_SIZE = 15


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def fit_into_cell(path: Path) -> Image:
    source = read_png_rgba(path)
    if source.width > CELL_WIDTH or source.height > CELL_HEIGHT:
        raise ValueError(f"{path} is {source.width}x{source.height}, larger than {CELL_WIDTH}x{CELL_HEIGHT}")

    pad_x = (CELL_WIDTH - source.width) // 2
    pad_y = CELL_HEIGHT - source.height
    pixels = bytearray(CELL_WIDTH * CELL_HEIGHT * 4)
    for y in range(source.height):
        source_offset = y * source.width * 4
        target_offset = ((pad_y + y) * CELL_WIDTH + pad_x) * 4
        pixels[target_offset : target_offset + source.width * 4] = source.pixels[
            source_offset : source_offset + source.width * 4
        ]
    return Image(CELL_WIDTH, CELL_HEIGHT, bytes(pixels))


def build_palette(frames: list[Image]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    first_seen: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for frame in frames:
        for index in range(0, len(frame.pixels), 4):
            r, g, b, a = frame.pixels[index : index + 4]
            if a == 0:
                continue
            color = (r, g, b, 255)
            colors[color] += 1
            if color not in seen:
                seen.add(color)
                first_seen.append(color)

    if not colors:
        raise ValueError("speech bubble frames contain no opaque pixels")

    if len(first_seen) <= OPAQUE_PALETTE_SIZE:
        opaque = first_seen
    else:
        keep = {color for color, _ in colors.most_common(OPAQUE_PALETTE_SIZE)}
        opaque = [color for color in first_seen if color in keep]

    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (OPAQUE_PALETTE_SIZE - len(opaque))


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def pack_frames(frames: list[Image], palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_index = {color: index for index, color in enumerate(palette)}
    palette_opaque = [color for color in palette if color[3] != 0]

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        color = (color[0], color[1], color[2], 255)
        if color in palette_index:
            return palette_index[color]
        closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
        return palette_index[closest]

    tiles = bytearray()
    for frame in frames:
        for tile_y in range(CELL_HEIGHT // 8):
            for tile_x in range(CELL_WIDTH // 8):
                tile_pixels: list[int] = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x
                        image_y = tile_y * 8 + y
                        offset = (image_y * CELL_WIDTH + image_x) * 4
                        tile_pixels.append(pixel_index(tuple(frame.pixels[offset : offset + 4])))
                write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def write_meta(path: Path) -> None:
    path.write_text(
        "\n".join(
            [
                "pub const idle_frame_index: u16 = 0;",
                "pub const prompt_frame_index: u16 = 1;",
                "pub const frame_count: u16 = 2;",
                f"pub const cell_width: i16 = {CELL_WIDTH};",
                f"pub const cell_height: i16 = {CELL_HEIGHT};",
                f"pub const tiles_per_frame: u16 = {(CELL_WIDTH // 8) * (CELL_HEIGHT // 8)};",
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--idle", type=Path, required=True)
    parser.add_argument("--prompt", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    frames = [fit_into_cell(args.idle), fit_into_cell(args.prompt)]
    palette = build_palette(frames)
    tiles = pack_frames(frames, palette)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "speech_bubble_tiles.bin").write_bytes(tiles)
    (args.output_dir / "speech_bubble_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    write_meta(args.output_dir / "speech_bubble_meta.zig")
    (args.output_dir / "speech_bubble.json").write_text(
        json.dumps(
            {
                "idleSource": str(args.idle),
                "promptSource": str(args.prompt),
                "frameCount": 2,
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "tilesPerFrame": (CELL_WIDTH // 8) * (CELL_HEIGHT // 8),
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print("packed speech bubbles: idle=1, prompt=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
