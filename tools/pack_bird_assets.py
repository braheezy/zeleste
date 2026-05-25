#!/usr/bin/env python3
"""Pack prologue bird NPC sprites and hint bubbles into 4bpp OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


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


def palette_for(images, limit: int = 15) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for image in images:
        for index in range(0, len(image.pixels), 4):
            color = tuple(image.pixels[index : index + 4])
            if color[3] != 0:
                colors[color] += 1
    opaque = [color for color, _ in colors.most_common(limit)]
    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (16 - 1 - len(opaque))


def pack_image(image, out_width: int, out_height: int, palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_opaque = [color for color in palette if color[3] != 0]
    palette_index = {color: index for index, color in enumerate(palette)}

    def pixel_index(x: int, y: int) -> int:
        if x >= image.width or y >= image.height:
            return 0
        offset = (y * image.width + x) * 4
        color = tuple(image.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color not in palette_index:
            closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
            return palette_index[closest]
        return palette_index[color]

    tiles = bytearray()
    for tile_y in range(out_height // 8):
        for tile_x in range(out_width // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def slice_row(path: Path, frame_width: int, frame_height: int):
    source = read_png_rgba(path)
    if source.height != frame_height or source.width % frame_width != 0:
        raise ValueError(f"{path} must be a row of {frame_width}x{frame_height} frames")
    frames = []
    for frame in range(source.width // frame_width):
        pixels = bytearray(frame_width * frame_height * 4)
        for y in range(frame_height):
            src = (y * source.width + frame * frame_width) * 4
            dst = y * frame_width * 4
            pixels[dst : dst + frame_width * 4] = source.pixels[src : src + frame_width * 4]
        frames.append(type(source)(frame_width, frame_height, pixels))
    return frames


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--intro", type=Path, required=True)
    parser.add_argument("--fly", type=Path, required=True)
    parser.add_argument("--hold-hint", type=Path, required=True)
    parser.add_argument("--climb-hint", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    frame_width = 32
    frame_height = 24
    intro_frames = slice_row(args.intro, frame_width, frame_height)
    fly_frames = slice_row(args.fly, frame_width, frame_height)
    frames = intro_frames + fly_frames

    hold_hint = read_png_rgba(args.hold_hint)
    climb_hint = read_png_rgba(args.climb_hint)
    bird_palette = palette_for(frames)
    hint_palette = palette_for([hold_hint, climb_hint])

    bird_tiles = bytearray()
    for frame in frames:
        bird_tiles.extend(pack_image(frame, 32, 32, bird_palette))

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "bird_intro_tiles.bin").write_bytes(bytes(bird_tiles))
    (args.output_dir / "bird_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in bird_palette)
    )
    (args.output_dir / "hold_hint_tiles.bin").write_bytes(pack_image(hold_hint, 64, 64, hint_palette))
    (args.output_dir / "climb_hint_tiles.bin").write_bytes(pack_image(climb_hint, 64, 64, hint_palette))
    (args.output_dir / "hint_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in hint_palette)
    )
    (args.output_dir / "bird.json").write_text(
        json.dumps(
            {
                "frameWidth": frame_width,
                "frameHeight": frame_height,
                "packedWidth": 32,
                "packedHeight": 32,
                "frameCount": len(frames),
                "introFrameCount": len(intro_frames),
                "flyFirstFrame": len(intro_frames),
                "flyFrameCount": len(fly_frames),
                "tilesPerFrame": 16,
                "hintWidth": 64,
                "hintHeight": 64,
                "hintTiles": 64,
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed bird: {len(frames)} frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
