#!/usr/bin/env python3
"""Pack a smashable wall sprite into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba


MAX_SPRITE_HEIGHT = 32
OPAQUE_PALETTE_SIZE = 15


def rgb555_to_rgba(color: int) -> tuple[int, int, int, int]:
    return (
        (color & 0x1F) * 255 // 31,
        ((color >> 5) & 0x1F) * 255 // 31,
        ((color >> 10) & 0x1F) * 255 // 31,
        255,
    )


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def read_rgb555_palette(path: Path) -> list[int]:
    data = path.read_bytes()
    if len(data) % 2 != 0:
        raise ValueError(f"{path} has an odd byte length")
    return [data[index] | (data[index + 1] << 8) for index in range(0, len(data), 2)]


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def source_opaque_colors(image: Image) -> list[tuple[int, int, int, int]]:
    counts: Counter[tuple[int, int, int, int]] = Counter()
    first_seen: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for offset in range(0, len(image.pixels), 4):
        r, g, b, a = image.pixels[offset : offset + 4]
        if a == 0:
            continue
        color = (r, g, b, 255)
        counts[color] += 1
        if color not in seen:
            seen.add(color)
            first_seen.append(color)

    if len(first_seen) > OPAQUE_PALETTE_SIZE:
        keep = {color for color, _ in counts.most_common(OPAQUE_PALETTE_SIZE)}
        return [color for color in first_seen if color in keep]
    return first_seen


def build_source_color_map(
    source_colors: list[tuple[int, int, int, int]],
    room_palette: list[int],
) -> tuple[dict[tuple[int, int, int, int], int], list[int]]:
    candidates = [(index, color, rgb555_to_rgba(color)) for index, color in enumerate(room_palette) if index != 0]
    if not candidates:
        raise ValueError("room palette contains no opaque candidates")

    source_to_rgb555: dict[tuple[int, int, int, int], int] = {}
    chosen_rgb555: list[int] = []
    for source in source_colors:
        _, target_rgb555, _ = min(candidates, key=lambda candidate: color_distance(source, candidate[2]))
        source_to_rgb555[source] = target_rgb555
        if target_rgb555 not in chosen_rgb555:
            chosen_rgb555.append(target_rgb555)

    if len(chosen_rgb555) > OPAQUE_PALETTE_SIZE:
        raise ValueError(f"smashable ice needs {len(chosen_rgb555)} opaque palette colors")
    return source_to_rgb555, chosen_rgb555


def object_canvas_size(image: Image) -> tuple[int, int]:
    if image.width == 16 and image.height <= 32 and image.height % 8 == 0:
        return 16, 32
    if image.width == 32 and image.height <= 16 and image.height % 8 == 0:
        return 32, 16
    raise ValueError(f"expected a 16px-wide wall <=32px tall or a 32px-wide wall <=16px tall, got {image.width}x{image.height}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--room-palette", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--name", default="smashable_ice")
    args = parser.parse_args()

    image = read_png_rgba(args.input)
    sprite_width, sprite_height = object_canvas_size(image)

    room_palette = read_rgb555_palette(args.room_palette)
    source_colors = source_opaque_colors(image)
    source_to_rgb555, opaque_rgb555 = build_source_color_map(source_colors, room_palette)

    palette_rgb555 = [0] + opaque_rgb555
    palette_index = {color: index + 1 for index, color in enumerate(opaque_rgb555)}
    palette_rgb555 += [0] * (16 - len(palette_rgb555))
    preview_pixels = bytearray(sprite_width * sprite_height * 4)

    def pixel_index(x: int, y: int) -> int:
        preview_offset = (y * sprite_width + x) * 4
        if x >= image.width or y >= image.height:
            preview_pixels[preview_offset : preview_offset + 4] = bytes((0, 0, 0, 0))
            return 0
        offset = (y * image.width + x) * 4
        color = tuple(image.pixels[offset : offset + 4])
        if color[3] == 0:
            preview_pixels[preview_offset : preview_offset + 4] = bytes((0, 0, 0, 0))
            return 0
        source = (color[0], color[1], color[2], 255)
        mapped = source_to_rgb555[source]
        preview_pixels[preview_offset : preview_offset + 4] = bytes(rgb555_to_rgba(mapped))
        return palette_index[mapped]

    tiles = bytearray()
    for tile_y in range(sprite_height // 8):
        for tile_x in range(sprite_width // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / f"{args.name}_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / f"{args.name}_palette.bin").write_bytes(
        b"".join(color.to_bytes(2, "little") for color in palette_rgb555)
    )
    write_png_rgba(args.output_dir / f"{args.name}_preview.png", Image(sprite_width, sprite_height, bytes(preview_pixels)))
    (args.output_dir / f"{args.name}.json").write_text(
        json.dumps(
            {
                "source": str(args.input),
                "roomPalette": str(args.room_palette),
                "width": sprite_width,
                "height": sprite_height,
                "sourceHeight": image.height,
                "tileCount": len(tiles) // 32,
                "paletteRgb555": [hex(color) for color in palette_rgb555],
                "paletteRgba": [list(rgb555_to_rgba(color)) if index != 0 else [0, 0, 0, 0] for index, color in enumerate(palette_rgb555)],
                "sourceColorMap": [
                    {
                        "sourceRgba": list(source),
                        "targetRgb555": hex(source_to_rgb555[source]),
                        "targetRgba": list(rgb555_to_rgba(source_to_rgb555[source])),
                    }
                    for source in source_colors
                ],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed {args.name}: {len(tiles) // 32} tiles, {len(opaque_rgb555)} opaque colors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
