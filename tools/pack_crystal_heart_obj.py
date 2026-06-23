#!/usr/bin/env python3
"""Pack crystal heart OBJ animations into 4bpp GBA tiles."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


FRAME_RE = re.compile(r"^f(\d+)\.png$")
ANIMATIONS = ("idle", "spin", "fastspin")
CELL_WIDTH = 32
CELL_HEIGHT = 32
OPAQUE_PALETTE_SIZE = 15


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected crystal heart frame name: {path}")
    return int(match.group(1))


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def load_animation(input_dir: Path) -> dict[str, list[tuple[Path, object]]]:
    out = {}
    for name in ANIMATIONS:
        paths = sorted((input_dir / name).glob("f*.png"), key=frame_index)
        if not paths:
            raise ValueError(f"no frames found in {input_dir / name}")
        out[name] = [(path, read_png_rgba(path)) for path in paths]
    return out


def build_palette(frames: dict[str, list[tuple[Path, object]]]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    first_seen: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for animation in ANIMATIONS:
        for _, image in frames[animation]:
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
        raise ValueError("crystal heart frames contain no opaque pixels")

    if len(first_seen) <= OPAQUE_PALETTE_SIZE:
        opaque = first_seen
    else:
        keep = {color for color, _ in colors.most_common(OPAQUE_PALETTE_SIZE)}
        opaque = [color for color in first_seen if color in keep]

    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (OPAQUE_PALETTE_SIZE - len(opaque))


def pack_frames(frames: dict[str, list[tuple[Path, object]]], palette: list[tuple[int, int, int, int]]) -> tuple[bytes, dict[str, int]]:
    palette_index = {color: index for index, color in enumerate(palette)}
    palette_opaque = [color for color in palette if color[3] != 0]
    tiles = bytearray()
    offsets: dict[str, int] = {}
    frame_offset = 0

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        color = (color[0], color[1], color[2], 255)
        if color in palette_index:
            return palette_index[color]
        closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
        return palette_index[closest]

    for animation in ANIMATIONS:
        offsets[animation] = frame_offset
        for path, image in frames[animation]:
            if image.width > CELL_WIDTH or image.height > CELL_HEIGHT:
                raise ValueError(f"{path} is {image.width}x{image.height}, larger than {CELL_WIDTH}x{CELL_HEIGHT}")
            pad_x = (CELL_WIDTH - image.width) // 2
            pad_y = (CELL_HEIGHT - image.height) // 2
            for tile_y in range(CELL_HEIGHT // 8):
                for tile_x in range(CELL_WIDTH // 8):
                    tile_pixels = []
                    for y in range(8):
                        for x in range(8):
                            image_x = tile_x * 8 + x - pad_x
                            image_y = tile_y * 8 + y - pad_y
                            if image_x < 0 or image_y < 0 or image_x >= image.width or image_y >= image.height:
                                tile_pixels.append(0)
                                continue
                            offset = (image_y * image.width + image_x) * 4
                            tile_pixels.append(pixel_index(tuple(image.pixels[offset : offset + 4])))
                    write_tile_4bpp(tiles, tile_pixels)
            frame_offset += 1
    return bytes(tiles), offsets


def write_meta(path: Path, normal_counts: dict[str, int], ghost_counts: dict[str, int], offsets: dict[str, int]) -> None:
    tiles_per_frame = (CELL_WIDTH // 8) * (CELL_HEIGHT // 8)
    path.write_text(
        "\n".join(
            [
                f"pub const cell_width: i16 = {CELL_WIDTH};",
                f"pub const cell_height: i16 = {CELL_HEIGHT};",
                f"pub const tiles_per_frame: u16 = {tiles_per_frame};",
                f"pub const idle_first_frame: u16 = {offsets['idle']};",
                f"pub const idle_frame_count: u16 = {normal_counts['idle']};",
                f"pub const spin_first_frame: u16 = {offsets['spin']};",
                f"pub const spin_frame_count: u16 = {normal_counts['spin']};",
                f"pub const fastspin_first_frame: u16 = {offsets['fastspin']};",
                f"pub const fastspin_frame_count: u16 = {normal_counts['fastspin']};",
                f"pub const frame_count: u16 = {sum(normal_counts.values())};",
                f"pub const ghost_frame_count: u16 = {sum(ghost_counts.values())};",
                "",
            ]
        )
    )


def pack_variant(name: str, input_dir: Path, output_dir: Path) -> tuple[dict[str, int], dict[str, int], list[tuple[int, int, int, int]]]:
    frames = load_animation(input_dir)
    counts = {animation: len(frames[animation]) for animation in ANIMATIONS}
    palette = build_palette(frames)
    tiles, offsets = pack_frames(frames, palette)
    (output_dir / f"crystal_heart_{name}_tiles.bin").write_bytes(tiles)
    (output_dir / f"crystal_heart_{name}_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    return counts, offsets, palette


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--normal", type=Path, required=True)
    parser.add_argument("--ghost", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    normal_counts, offsets, normal_palette = pack_variant("normal", args.normal, args.output_dir)
    ghost_counts, ghost_offsets, ghost_palette = pack_variant("ghost", args.ghost, args.output_dir)
    if ghost_counts != normal_counts or ghost_offsets != offsets:
        raise ValueError("normal and ghost crystal heart animations must have matching frame counts")
    write_meta(args.output_dir / "crystal_heart_meta.zig", normal_counts, ghost_counts, offsets)
    (args.output_dir / "crystal_heart.json").write_text(
        json.dumps(
            {
                "normalSource": str(args.normal),
                "ghostSource": str(args.ghost),
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "tilesPerFrame": (CELL_WIDTH // 8) * (CELL_HEIGHT // 8),
                "animations": normal_counts,
                "offsets": offsets,
                "normalPaletteRgba": [list(color) for color in normal_palette],
                "ghostPaletteRgba": [list(color) for color in ghost_palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(
        "packed crystal heart: "
        f"idle={normal_counts['idle']}, spin={normal_counts['spin']}, fastspin={normal_counts['fastspin']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
