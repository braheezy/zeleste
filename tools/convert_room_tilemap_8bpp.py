#!/usr/bin/env python3
"""Convert a room PNG into an 8bpp GBA normal background tilemap."""

from __future__ import annotations

import argparse
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from split_foreground_tileset import read_png_rgba  # noqa: E402


MAX_COLORS = 256
MAX_TILES = 1024


def gba_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def screen_entry(tile: int, flip_x: bool = False, flip_y: bool = False) -> int:
    return tile | (int(flip_x) << 10) | (int(flip_y) << 11)


def normal_map_index(x: int, y: int, map_width_tiles: int) -> int:
    screenblock_x = x >> 5
    screenblock_y = y >> 5
    screenblock_columns = map_width_tiles >> 5
    screenblock_index = screenblock_x + (screenblock_y * screenblock_columns)
    return (screenblock_index << 10) + (x & 31) + ((y & 31) << 5)


def flipped_tile(tile: bytes, flip_x: bool, flip_y: bool) -> bytes:
    out = bytearray(64)
    for y in range(8):
        for x in range(8):
            src_x = 7 - x if flip_x else x
            src_y = 7 - y if flip_y else y
            out[y * 8 + x] = tile[src_y * 8 + src_x]
    return bytes(out)


def find_tile(tiles: list[bytes], tile: bytes) -> tuple[int, bool, bool] | None:
    for index, existing in enumerate(tiles):
        if existing == tile:
            return index, False, False
        if flipped_tile(existing, True, False) == tile:
            return index, True, False
        if flipped_tile(existing, False, True) == tile:
            return index, False, True
        if flipped_tile(existing, True, True) == tile:
            return index, True, True
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_png", type=Path)
    parser.add_argument("tiles_output", type=Path)
    parser.add_argument("map_output", type=Path)
    parser.add_argument("palette_output", type=Path)
    args = parser.parse_args()

    image = read_png_rgba(args.input_png)
    if image.width == 0 or image.height == 0:
        raise ValueError("empty image")
    if image.width % 8 != 0 or image.height % 8 != 0:
        raise ValueError(f"image size must be a multiple of 8, got {image.width}x{image.height}")

    pixels = [
        tuple(image.pixels[i : i + 4])
        for i in range(0, len(image.pixels), 4)
    ]
    counts = Counter(pixels)
    colors = [color for color, _ in counts.most_common()]
    if len(colors) > MAX_COLORS:
        raise ValueError(f"{args.input_png} has {len(colors)} colors; 8bpp BG supports {MAX_COLORS}")
    palette_index = {color: index for index, color in enumerate(colors)}

    source_width_tiles = image.width // 8
    source_height_tiles = image.height // 8
    if source_width_tiles > 64 or source_height_tiles > 64:
        raise ValueError("normal BG map is too large")
    map_width_tiles = 32 if source_width_tiles <= 32 else 64
    map_height_tiles = 32 if source_height_tiles <= 32 else 64
    tilemap = [0] * (map_width_tiles * map_height_tiles)
    tiles: list[bytes] = []

    for tile_y in range(source_height_tiles):
        for tile_x in range(source_width_tiles):
            tile = bytearray(64)
            for pixel_y in range(8):
                for pixel_x in range(8):
                    image_x = tile_x * 8 + pixel_x
                    image_y = tile_y * 8 + pixel_y
                    tile[pixel_y * 8 + pixel_x] = palette_index[pixels[image_y * image.width + image_x]]
            tile_bytes = bytes(tile)
            match = find_tile(tiles, tile_bytes)
            if match is None:
                if len(tiles) >= MAX_TILES:
                    raise ValueError(f"too many deduped tiles: {len(tiles) + 1}")
                match = (len(tiles), False, False)
                tiles.append(tile_bytes)
            index, flip_x, flip_y = match
            tilemap[normal_map_index(tile_x, tile_y, map_width_tiles)] = screen_entry(index, flip_x, flip_y)

    args.tiles_output.parent.mkdir(parents=True, exist_ok=True)
    args.map_output.parent.mkdir(parents=True, exist_ok=True)
    args.palette_output.parent.mkdir(parents=True, exist_ok=True)
    args.tiles_output.write_bytes(b"".join(tiles))
    args.map_output.write_bytes(b"".join(struct.pack("<H", entry) for entry in tilemap))
    palette = colors + [(0, 0, 0, 255)] * (MAX_COLORS - len(colors))
    args.palette_output.write_bytes(b"".join(struct.pack("<H", gba_rgb555(color)) for color in palette))

    print(
        f"wrote 8bpp tilemap: {len(tiles)} tiles, {len(colors)} colors, "
        f"{map_width_tiles}x{map_height_tiles} map"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
