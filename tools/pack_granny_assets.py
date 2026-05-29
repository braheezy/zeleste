#!/usr/bin/env python3
"""Pack Granny actor sprites into 4bpp OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


FRAME_WIDTH = 32
FRAME_HEIGHT = 32
HA_SOURCE_FRAME_WIDTH = 14
HA_FRAME_WIDTH = 16
HA_FRAME_HEIGHT = 16
HA_COLOR_INDICES = {
    (255, 255, 255, 255): 1,
    (0, 0, 0, 255): 5,
    (173, 173, 173, 255): 9,
}
TRANSPARENT_RGB = {
    (255, 0, 255),
    (173, 0, 255),
    (0, 255, 255),
    (0, 173, 255),
}


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def is_transparent(color: tuple[int, int, int, int]) -> bool:
    return color[3] == 0 or color[:3] in TRANSPARENT_RGB


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def slice_nonempty_grid(path: Path) -> list[Image]:
    source = read_png_rgba(path)
    if source.width % FRAME_WIDTH != 0 or source.height % FRAME_HEIGHT != 0:
        raise ValueError(f"{path} must be a {FRAME_WIDTH}x{FRAME_HEIGHT} grid")

    frames: list[Image] = []
    for frame_y in range(source.height // FRAME_HEIGHT):
        for frame_x in range(source.width // FRAME_WIDTH):
            pixels = bytearray(FRAME_WIDTH * FRAME_HEIGHT * 4)
            opaque_count = 0
            for y in range(FRAME_HEIGHT):
                for x in range(FRAME_WIDTH):
                    src_offset = ((frame_y * FRAME_HEIGHT + y) * source.width + frame_x * FRAME_WIDTH + x) * 4
                    dst_offset = (y * FRAME_WIDTH + x) * 4
                    color = tuple(source.pixels[src_offset : src_offset + 4])
                    if is_transparent(color):
                        pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                    else:
                        pixels[dst_offset : dst_offset + 4] = bytes(color)
                        opaque_count += 1
            if opaque_count != 0:
                frames.append(Image(FRAME_WIDTH, FRAME_HEIGHT, bytes(pixels)))
    return frames


def palette_for(frames: list[Image]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for frame in frames:
        for offset in range(0, len(frame.pixels), 4):
            color = tuple(frame.pixels[offset : offset + 4])
            if color[3] != 0:
                colors[color] += 1
    opaque = [color for color, _ in colors.most_common(15)]
    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (15 - len(opaque))


def pack_frame(frame: Image, palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_opaque = [color for color in palette if color[3] != 0]
    palette_index = {color: index for index, color in enumerate(palette)}

    def pixel_index(x: int, y: int) -> int:
        offset = (y * frame.width + x) * 4
        color = tuple(frame.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color not in palette_index:
            closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
            return palette_index[closest]
        return palette_index[color]

    tiles = bytearray()
    for tile_y in range(frame.height // 8):
        for tile_x in range(frame.width // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def slice_strip(path: Path, frame_width: int, frame_height: int, output_width: int | None = None) -> list[Image]:
    source = read_png_rgba(path)
    output_width = frame_width if output_width is None else output_width
    if output_width < frame_width or output_width % 8 != 0:
        raise ValueError("output frame width must be >= source frame width and tile aligned")
    if source.height != frame_height:
        raise ValueError(f"{path} must be {frame_height}px high")
    frame_count = source.width // frame_width
    if frame_count == 0:
        raise ValueError(f"{path} is too narrow for {frame_width}px frames")
    trailing_start = frame_count * frame_width
    for y in range(source.height):
        for x in range(trailing_start, source.width):
            src_offset = (y * source.width + x) * 4
            if not is_transparent(tuple(source.pixels[src_offset : src_offset + 4])):
                raise ValueError(f"{path} has non-transparent trailing pixels after {frame_count} frames")

    frames: list[Image] = []
    for frame_x in range(frame_count):
        pixels = bytearray(output_width * frame_height * 4)
        opaque_count = 0
        for y in range(frame_height):
            for x in range(frame_width):
                src_offset = (y * source.width + frame_x * frame_width + x) * 4
                dst_offset = (y * output_width + x) * 4
                color = tuple(source.pixels[src_offset : src_offset + 4])
                if is_transparent(color):
                    pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                else:
                    pixels[dst_offset : dst_offset + 4] = bytes(color)
                    opaque_count += 1
        if opaque_count != 0:
            frames.append(Image(output_width, frame_height, bytes(pixels)))
    return frames


def pack_frame_with_indices(frame: Image, color_indices: dict[tuple[int, int, int, int], int]) -> bytes:
    def pixel_index(x: int, y: int) -> int:
        offset = (y * frame.width + x) * 4
        color = tuple(frame.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color in color_indices:
            return color_indices[color]
        luminance = (color[0] + color[1] + color[2]) // 3
        if luminance > 220:
            return 1
        if luminance > 80:
            return 9
        return 5

    tiles = bytearray()
    for tile_y in range(frame.height // 8):
        for tile_x in range(frame.width // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    idle_frames = slice_nonempty_grid(args.input_dir / "idle.png")
    if not idle_frames:
        raise ValueError("idle.png produced no frames")
    laugh_frames = slice_nonempty_grid(args.input_dir / "laugh.png")
    if not laugh_frames:
        raise ValueError("laugh.png produced no frames")
    quote_frames = slice_nonempty_grid(args.input_dir / "quotes.png")
    if not quote_frames:
        raise ValueError("quotes.png produced no frames")
    haha_frames = slice_strip(args.input_dir / "ha-ha.png", HA_SOURCE_FRAME_WIDTH, HA_FRAME_HEIGHT, HA_FRAME_WIDTH)
    if not haha_frames:
        raise ValueError("ha-ha.png produced no frames")
    palette = palette_for(idle_frames + laugh_frames + quote_frames)

    tiles = bytearray()
    for frame in idle_frames:
        tiles.extend(pack_frame(frame, palette))
    laugh_tiles = bytearray()
    for frame in laugh_frames:
        laugh_tiles.extend(pack_frame(frame, palette))
    quote_tiles = bytearray()
    for frame in quote_frames:
        quote_tiles.extend(pack_frame(frame, palette))

    haha_tiles = bytearray()
    for frame in haha_frames:
        haha_tiles.extend(pack_frame_with_indices(frame, HA_COLOR_INDICES))

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "granny_idle_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "granny_laugh_tiles.bin").write_bytes(bytes(laugh_tiles))
    (args.output_dir / "granny_quotes_tiles.bin").write_bytes(bytes(quote_tiles))
    (args.output_dir / "granny_haha_tiles.bin").write_bytes(bytes(haha_tiles))
    (args.output_dir / "granny_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "granny.json").write_text(
        json.dumps(
            {
                "frameWidth": FRAME_WIDTH,
                "frameHeight": FRAME_HEIGHT,
                "idleFrameCount": len(idle_frames),
                "laughFrameCount": len(laugh_frames),
                "quoteFrameCount": len(quote_frames),
                "hahaFrameCount": len(haha_frames),
                "tilesPerFrame": (FRAME_WIDTH // 8) * (FRAME_HEIGHT // 8),
                "hahaSourceFrameWidth": HA_SOURCE_FRAME_WIDTH,
                "hahaTilesPerFrame": (HA_FRAME_WIDTH // 8) * (HA_FRAME_HEIGHT // 8),
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(
        f"packed granny idle: {len(idle_frames)} frames, "
        f"laugh: {len(laugh_frames)} frames, "
        f"quotes: {len(quote_frames)} frames, "
        f"haha: {len(haha_frames)} frames, {sum(1 for color in palette if color[3] != 0)} opaque colors"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
