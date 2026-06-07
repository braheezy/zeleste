#!/usr/bin/env python3
"""Pack dash refill animation frames into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


IDLE_RE = re.compile(r"^idle(\d+)\.png$")
FLASH_RE = re.compile(r"^flash(\d+)\.png$")
CELL_WIDTH = 16
CELL_HEIGHT = 16
OPAQUE_PALETTE_SIZE = 15


def frame_index(regex: re.Pattern[str], path: Path) -> int:
    match = regex.match(path.name)
    if not match:
        raise ValueError(f"unexpected dash refill frame name: {path}")
    return int(match.group(1))


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


def load_animation(input_dir: Path) -> tuple[list[tuple[Path, object]], list[tuple[Path, object]], tuple[Path, object]]:
    idle_paths = sorted(input_dir.glob("idle*.png"), key=lambda path: frame_index(IDLE_RE, path))
    flash_paths = sorted(input_dir.glob("flash*.png"), key=lambda path: frame_index(FLASH_RE, path))
    outline_path = input_dir / "outline.png"

    if not idle_paths:
        raise ValueError(f"no idle*.png dash refill frames found in {input_dir}")
    if not flash_paths:
        raise ValueError(f"no flash*.png dash refill frames found in {input_dir}")
    if not outline_path.exists():
        raise ValueError(f"missing {outline_path}")

    def load(path: Path) -> tuple[Path, object]:
        image = read_png_rgba(path)
        if image.width != CELL_WIDTH or image.height != CELL_HEIGHT:
            raise ValueError(f"{path} must be {CELL_WIDTH}x{CELL_HEIGHT}, got {image.width}x{image.height}")
        return path, image

    return [load(path) for path in idle_paths], [load(path) for path in flash_paths], load(outline_path)


def build_palette(frames: list[tuple[Path, object]]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    first_seen: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for _, image in frames:
        for index in range(0, len(image.pixels), 4):
            r, g, b, a = image.pixels[index : index + 4]
            if a == 0:
                continue
            color = (r, g, b, 255)
            colors[color] += 1
            if color not in seen:
                seen.add(color)
                first_seen.append(color)

    if not colors:
        raise ValueError("dash refill frames contain no opaque pixels")

    if len(first_seen) <= OPAQUE_PALETTE_SIZE:
        opaque = first_seen
    else:
        keep = {color for color, _ in colors.most_common(OPAQUE_PALETTE_SIZE)}
        opaque = [color for color in first_seen if color in keep]

    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (OPAQUE_PALETTE_SIZE - len(opaque))


def pack_frames(frames: list[tuple[Path, object]], palette: list[tuple[int, int, int, int]]) -> bytes:
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
    for path, image in frames:
        if image.width != CELL_WIDTH or image.height != CELL_HEIGHT:
            raise ValueError(f"{path} must be {CELL_WIDTH}x{CELL_HEIGHT}, got {image.width}x{image.height}")
        for tile_y in range(CELL_HEIGHT // 8):
            for tile_x in range(CELL_WIDTH // 8):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x
                        image_y = tile_y * 8 + y
                        offset = (image_y * image.width + image_x) * 4
                        tile_pixels.append(pixel_index(tuple(image.pixels[offset : offset + 4])))
                write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def write_meta(path: Path, idle_count: int, flash_count: int) -> None:
    tiles_per_frame = (CELL_WIDTH // 8) * (CELL_HEIGHT // 8)
    outline_frame_index = idle_count + flash_count
    path.write_text(
        "\n".join(
            [
                f"pub const idle_frame_count: u16 = {idle_count};",
                f"pub const flash_frame_count: u16 = {flash_count};",
                f"pub const outline_frame_index: u16 = {outline_frame_index};",
                f"pub const frame_count: u16 = {outline_frame_index + 1};",
                f"pub const cell_width: i16 = {CELL_WIDTH};",
                f"pub const cell_height: i16 = {CELL_HEIGHT};",
                f"pub const tiles_per_frame: u16 = {tiles_per_frame};",
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    idle_frames, flash_frames, outline_frame = load_animation(args.input_dir)
    frames = idle_frames + flash_frames + [outline_frame]
    palette = build_palette(frames)
    tiles = pack_frames(frames, palette)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "dash_refill_tiles.bin").write_bytes(tiles)
    (args.output_dir / "dash_refill_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    write_meta(args.output_dir / "dash_refill_meta.zig", len(idle_frames), len(flash_frames))
    (args.output_dir / "dash_refill.json").write_text(
        json.dumps(
            {
                "source": str(args.input_dir),
                "idleFrameCount": len(idle_frames),
                "flashFrameCount": len(flash_frames),
                "outlineFrameIndex": len(idle_frames) + len(flash_frames),
                "frameCount": len(frames),
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "tilesPerFrame": (CELL_WIDTH // 8) * (CELL_HEIGHT // 8),
                "paletteRgba": [list(color) for color in palette],
                "frames": [path.name for path, _ in frames],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed dash refill: idle={len(idle_frames)}, flash={len(flash_frames)}, outline=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
