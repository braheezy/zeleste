#!/usr/bin/env python3
"""Pack cassette tape spin sheets into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba


CELL_WIDTH = 32
CELL_HEIGHT = 16
OPAQUE_PALETTE_SIZE = 15


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def opaque(image: Image, x: int, y: int) -> bool:
    return image.pixels[(y * image.width + x) * 4 + 3] != 0


def component_bounds(image: Image) -> list[tuple[int, int, int, int]]:
    seen: set[tuple[int, int]] = set()
    bounds: list[tuple[int, int, int, int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            if (x, y) in seen or not opaque(image, x, y):
                continue
            stack = [(x, y)]
            seen.add((x, y))
            xs: list[int] = []
            ys: list[int] = []
            while stack:
                cx, cy = stack.pop()
                xs.append(cx)
                ys.append(cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= image.width or ny >= image.height:
                        continue
                    if (nx, ny) in seen or not opaque(image, nx, ny):
                        continue
                    seen.add((nx, ny))
                    stack.append((nx, ny))
            bounds.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1, len(xs)))

    return [(x0, y0, x1, y1) for x0, y0, x1, y1, area in sorted(bounds, key=lambda item: (item[1], item[0])) if area > 2]


def crop(image: Image, bounds: tuple[int, int, int, int]) -> Image:
    x0, y0, x1, y1 = bounds
    width = x1 - x0
    height = y1 - y0
    pixels = bytearray(width * height * 4)
    for y in range(height):
        source_offset = ((y0 + y) * image.width + x0) * 4
        target_offset = y * width * 4
        pixels[target_offset : target_offset + width * 4] = image.pixels[source_offset : source_offset + width * 4]
    return Image(width, height, bytes(pixels))


def paste_into_cell(image: Image) -> Image:
    if image.width > CELL_WIDTH or image.height > CELL_HEIGHT:
        raise ValueError(f"cassette frame {image.width}x{image.height} is larger than {CELL_WIDTH}x{CELL_HEIGHT}")
    pad_x = (CELL_WIDTH - image.width) // 2
    pad_y = (CELL_HEIGHT - image.height) // 2
    pixels = bytearray(CELL_WIDTH * CELL_HEIGHT * 4)
    for y in range(image.height):
        source_offset = y * image.width * 4
        target_offset = ((pad_y + y) * CELL_WIDTH + pad_x) * 4
        pixels[target_offset : target_offset + image.width * 4] = image.pixels[
            source_offset : source_offset + image.width * 4
        ]
    return Image(CELL_WIDTH, CELL_HEIGHT, bytes(pixels))


def load_frames(path: Path) -> list[Image]:
    source = read_png_rgba(path)
    frames = [paste_into_cell(crop(source, bounds)) for bounds in component_bounds(source)]
    if not frames:
        raise ValueError(f"no cassette frames found in {path}")
    return frames


def write_preview(path: Path, frames: list[Image]) -> None:
    pixels = bytearray(CELL_WIDTH * len(frames) * CELL_HEIGHT * 4)
    sheet_width = CELL_WIDTH * len(frames)
    for frame_index, image in enumerate(frames):
        x0 = frame_index * CELL_WIDTH
        for y in range(CELL_HEIGHT):
            source_offset = y * CELL_WIDTH * 4
            target_offset = (y * sheet_width + x0) * 4
            pixels[target_offset : target_offset + CELL_WIDTH * 4] = image.pixels[
                source_offset : source_offset + CELL_WIDTH * 4
            ]
    write_png_rgba(path, Image(sheet_width, CELL_HEIGHT, bytes(pixels)))


def build_palette(frame_sets: list[list[Image]]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    first_seen: list[tuple[int, int, int, int]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for frames in frame_sets:
        for image in frames:
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
        raise ValueError("cassette frames contain no opaque pixels")

    if len(first_seen) <= OPAQUE_PALETTE_SIZE:
        opaque_colors = first_seen
    else:
        keep = {color for color, _ in colors.most_common(OPAQUE_PALETTE_SIZE)}
        opaque_colors = [color for color in first_seen if color in keep]

    return [(0, 0, 0, 0)] + opaque_colors + [(0, 0, 0, 255)] * (OPAQUE_PALETTE_SIZE - len(opaque_colors))


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def pack_frames(frames: list[Image], palette: list[tuple[int, int, int, int]], cell_width: int = CELL_WIDTH, cell_height: int = CELL_HEIGHT) -> bytes:
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
    for image in frames:
        for tile_y in range(cell_height // 8):
            for tile_x in range(cell_width // 8):
                tile_pixels: list[int] = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x
                        image_y = tile_y * 8 + y
                        offset = (image_y * cell_width + image_x) * 4
                        tile_pixels.append(pixel_index(tuple(image.pixels[offset : offset + 4])))
                write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def fit_into_cell(image: Image, width: int, height: int) -> Image:
    if image.width > width or image.height > height:
        raise ValueError(f"frame {image.width}x{image.height} is larger than {width}x{height}")
    pad_x = (width - image.width) // 2
    pad_y = (height - image.height) // 2
    pixels = bytearray(width * height * 4)
    for y in range(image.height):
        source_offset = y * image.width * 4
        target_offset = ((pad_y + y) * width + pad_x) * 4
        pixels[target_offset : target_offset + image.width * 4] = image.pixels[
            source_offset : source_offset + image.width * 4
        ]
    return Image(width, height, bytes(pixels))


def write_meta(path: Path, uncollected_count: int, collected_count: int) -> None:
    tiles_per_frame = (CELL_WIDTH // 8) * (CELL_HEIGHT // 8)
    path.write_text(
        "\n".join(
            [
                f"pub const uncollected_frame_count: u16 = {uncollected_count};",
                f"pub const collected_frame_count: u16 = {collected_count};",
                f"pub const cell_width: i16 = {CELL_WIDTH};",
                f"pub const cell_height: i16 = {CELL_HEIGHT};",
                f"pub const tiles_per_frame: u16 = {tiles_per_frame};",
                "pub const bubble_cell_width: i16 = 32;",
                "pub const bubble_cell_height: i16 = 32;",
                "pub const bubble_tiles_per_frame: u16 = 16;",
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uncollected", type=Path, required=True)
    parser.add_argument("--collected", type=Path, required=True)
    parser.add_argument("--bubble", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    uncollected_frames = load_frames(args.uncollected)
    collected_frames = load_frames(args.collected)
    palette = build_palette([uncollected_frames, collected_frames])
    bubble_frames = [fit_into_cell(read_png_rgba(args.bubble), 32, 32)]
    bubble_palette = build_palette([bubble_frames])

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "cassette_uncollected_tiles.bin").write_bytes(pack_frames(uncollected_frames, palette))
    (args.output_dir / "cassette_collected_tiles.bin").write_bytes(pack_frames(collected_frames, palette))
    (args.output_dir / "cassette_bubble_tiles.bin").write_bytes(pack_frames(bubble_frames, bubble_palette, 32, 32))
    (args.output_dir / "cassette_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "cassette_bubble_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in bubble_palette)
    )
    write_meta(args.output_dir / "cassette_meta.zig", len(uncollected_frames), len(collected_frames))
    write_preview(args.output_dir / "cassette_uncollected_preview.png", uncollected_frames)
    write_preview(args.output_dir / "cassette_collected_preview.png", collected_frames)
    (args.output_dir / "cassette.json").write_text(
        json.dumps(
            {
                "uncollectedSource": str(args.uncollected),
                "collectedSource": str(args.collected),
                "bubbleSource": str(args.bubble),
                "uncollectedFrameCount": len(uncollected_frames),
                "collectedFrameCount": len(collected_frames),
                "cellWidth": CELL_WIDTH,
                "cellHeight": CELL_HEIGHT,
                "tilesPerFrame": (CELL_WIDTH // 8) * (CELL_HEIGHT // 8),
                "paletteRgba": [list(color) for color in palette],
                "bubblePaletteRgba": [list(color) for color in bubble_palette],
            },
            indent=2,
        )
        + "\n"
    )
    print(f"packed cassette: uncollected={len(uncollected_frames)}, collected={len(collected_frames)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
