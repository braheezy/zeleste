#!/usr/bin/env python3
"""Convert a room PNG into an 8bpp GBA normal background tilemap."""

from __future__ import annotations

import argparse
import json
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from split_foreground_tileset import read_png_rgba  # noqa: E402
from split_foreground_tileset import Image, write_png_rgba  # noqa: E402


MAX_COLORS = 256
# BG0 uses screenblock 29 for a 64x32 map. In 8bpp each tile is 64 bytes,
# so tile data must stay below screenblock 29 to avoid overwriting the map.
MAX_TILES = 928


def gba_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def quantize_color(color: tuple[int, int, int, int], rgb_bits: int) -> tuple[int, int, int, int]:
    if rgb_bits >= 8 or color[3] == 0:
        return color
    shift = 8 - rgb_bits
    r, g, b, a = color
    return ((r >> shift) << shift, (g >> shift) << shift, (b >> shift) << shift, a)


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


def tile_distance(a: bytes, b: bytes) -> int:
    distance = 0
    for left, right in zip(a, b):
        distance += abs(left - right)
    return distance


def find_nearest_tile(tiles: list[bytes], tile: bytes) -> tuple[int, bool, bool]:
    best_index = 0
    best_flip_x = False
    best_flip_y = False
    best_distance = tile_distance(tiles[0], tile)
    for index, existing in enumerate(tiles):
        for flip_x, flip_y in ((False, False), (True, False), (False, True), (True, True)):
            candidate = flipped_tile(existing, flip_x, flip_y) if flip_x or flip_y else existing
            distance = tile_distance(candidate, tile)
            if distance < best_distance:
                best_index = index
                best_flip_x = flip_x
                best_flip_y = flip_y
                best_distance = distance
    return best_index, best_flip_x, best_flip_y


def reconstruct_pixels(
    tiles: list[bytes],
    tilemap: list[int],
    palette: list[tuple[int, int, int, int]],
    width: int,
    height: int,
    source_width_tiles: int,
) -> bytes:
    out = bytearray(width * height * 4)
    for tile_y in range(height // 8):
        for tile_x in range(width // 8):
            entry = tilemap[tile_y * source_width_tiles + tile_x]
            tile_index = entry & 0x03FF
            flip_x = (entry & 0x0400) != 0
            flip_y = (entry & 0x0800) != 0
            tile = flipped_tile(tiles[tile_index], flip_x, flip_y)
            for pixel_y in range(8):
                for pixel_x in range(8):
                    color = palette[tile[pixel_y * 8 + pixel_x]]
                    output_x = tile_x * 8 + pixel_x
                    output_y = tile_y * 8 + pixel_y
                    offset = (output_y * width + output_x) * 4
                    out[offset : offset + 4] = bytes(color)
    return bytes(out)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_png", type=Path)
    parser.add_argument("tiles_output", type=Path)
    parser.add_argument("map_output", type=Path)
    parser.add_argument("palette_output", type=Path)
    parser.add_argument("--rgb-bits", type=int, default=8, choices=range(1, 9))
    parser.add_argument("--allow-overflow-approx", action="store_true")
    parser.add_argument("--reconstruct-output", type=Path, default=None)
    parser.add_argument("--metadata-output", type=Path, default=None)
    args = parser.parse_args()

    image = read_png_rgba(args.input_png)
    if image.width == 0 or image.height == 0:
        raise ValueError("empty image")
    if image.width % 8 != 0 or image.height % 8 != 0:
        raise ValueError(f"image size must be a multiple of 8, got {image.width}x{image.height}")

    pixels = [quantize_color(tuple(image.pixels[i : i + 4]), args.rgb_bits) for i in range(0, len(image.pixels), 4)]
    counts = Counter(pixels)
    colors = [color for color, _ in counts.most_common()]
    if len(colors) > MAX_COLORS:
        raise ValueError(f"{args.input_png} has {len(colors)} colors; 8bpp BG supports {MAX_COLORS}")
    palette_index = {color: index for index, color in enumerate(colors)}

    source_width_tiles = image.width // 8
    source_height_tiles = image.height // 8
    tilemap = [0] * (source_width_tiles * source_height_tiles)
    tiles: list[bytes] = []
    approximated_tiles = 0

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
                if len(tiles) < MAX_TILES:
                    match = (len(tiles), False, False)
                    tiles.append(tile_bytes)
                elif args.allow_overflow_approx:
                    match = find_nearest_tile(tiles, tile_bytes)
                    approximated_tiles += 1
                else:
                    raise ValueError(
                        f"too many deduped tiles: {len(tiles) + 1}; "
                        f"try lowering --rgb-bits or splitting/streaming the room"
                    )
            index, flip_x, flip_y = match
            tilemap[tile_y * source_width_tiles + tile_x] = screen_entry(index, flip_x, flip_y)

    args.tiles_output.parent.mkdir(parents=True, exist_ok=True)
    args.map_output.parent.mkdir(parents=True, exist_ok=True)
    args.palette_output.parent.mkdir(parents=True, exist_ok=True)
    args.tiles_output.write_bytes(b"".join(tiles))
    args.map_output.write_bytes(b"".join(struct.pack("<H", entry) for entry in tilemap))
    palette = colors + [(0, 0, 0, 255)] * (MAX_COLORS - len(colors))
    args.palette_output.write_bytes(b"".join(struct.pack("<H", gba_rgb555(color)) for color in palette))

    reconstructed = reconstruct_pixels(tiles, tilemap, palette, image.width, image.height, source_width_tiles)
    expected = bytearray()
    for color in pixels:
        expected.extend(color)
    mismatch_tiles = 0
    for tile_y in range(source_height_tiles):
        for tile_x in range(source_width_tiles):
            mismatch = False
            for pixel_y in range(8):
                for pixel_x in range(8):
                    pixel = ((tile_y * 8 + pixel_y) * image.width + tile_x * 8 + pixel_x) * 4
                    if reconstructed[pixel : pixel + 4] != expected[pixel : pixel + 4]:
                        mismatch = True
                        break
                if mismatch:
                    break
            if mismatch:
                mismatch_tiles += 1
    if args.reconstruct_output:
        args.reconstruct_output.parent.mkdir(parents=True, exist_ok=True)
        write_png_rgba(args.reconstruct_output, Image(image.width, image.height, reconstructed))
    if args.metadata_output:
        metadata = {
            "sourceWidth": image.width,
            "sourceHeight": image.height,
            "sourceWidthTiles": source_width_tiles,
            "sourceHeightTiles": source_height_tiles,
            "mapWidthTiles": source_width_tiles,
            "mapHeightTiles": source_height_tiles,
            "mapLayout": "linear-logical",
            "tileCount": len(tiles),
            "colorCount": len(colors),
            "rgbBits": args.rgb_bits,
            "approximatedTiles": approximated_tiles,
            "reconstructionMismatchTiles": mismatch_tiles,
        }
        args.metadata_output.write_text(json.dumps(metadata, indent=2) + "\n")
    if mismatch_tiles:
        raise ValueError(f"generated tilemap failed reconstruction check: {mismatch_tiles} mismatched tiles")

    print(
        f"wrote 8bpp tilemap: {len(tiles)} tiles, {len(colors)} colors, "
        f"{source_width_tiles}x{source_height_tiles} logical map"
        + (f", approximated {approximated_tiles} overflow tiles" if approximated_tiles else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
