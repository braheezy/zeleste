#!/usr/bin/env python3
"""Build generated assets for one edited room background."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba

WIRE_COLOR_INDEX = 6
MAX_WIRE_CHUNKS = 48
MAX_TRAFFIC_BLOCK_TILES = 104
TRAFFIC_BLOCK_TILE_SIZE = 8
TRAFFIC_LIGHT_FRAME_WIDTH = 8
TRAFFIC_LIGHT_FRAME_COUNT = 3
TRAFFIC_LIGHT_CELL_HEIGHT = 16
TRAFFIC_LIGHT_TILE_COUNT = TRAFFIC_LIGHT_FRAME_COUNT * (TRAFFIC_LIGHT_CELL_HEIGHT // TRAFFIC_BLOCK_TILE_SIZE)
TRAFFIC_BLOCK_EXACT_CROPS = {
    (2, 6): [
        [
            [(0, 0), (1, 0)],
            [(0, 1), (1, 1)],
            [(0, 2), (1, 2)],
            [(0, 3), (1, 3)],
            [(0, 4), (1, 4)],
            [(0, 6), (1, 6)],
        ]
    ],
    (4, 2): [
        [
            [(16, 0), (17, 0), (18, 0), (19, 0)],
            [(16, 1), (17, 1), (18, 1), (19, 1)],
        ],
        [
            [(12, 0), (13, 0), (14, 0), (15, 0)],
            [(12, 1), (13, 1), (14, 1), (15, 1)],
        ],
    ],
}
TRAFFIC_BLOCK_TEMPLATE_CROPS = {
    "top_left": [(16, 0), (6, 2), (12, 0)],
    "top": [(17, 0), (19, 0), (20, 0), (21, 0), (13, 2)],
    "top_right": [(22, 0), (10, 2), (15, 0)],
    "left": [(16, 1), (16, 3), (12, 3), (6, 3)],
    "right": [(22, 1), (22, 3), (14, 3), (10, 3)],
    "bottom_left": [(16, 5), (6, 6), (12, 5)],
    "bottom": [(17, 5), (18, 5), (19, 5), (20, 5), (21, 5), (13, 5)],
    "bottom_right": [(22, 5), (10, 6), (14, 5)],
    "interior": [
        (17, 1),
        (19, 1),
        (20, 1),
        (21, 1),
        (17, 3),
        (18, 3),
        (19, 3),
        (20, 3),
        (21, 3),
        (17, 4),
        (18, 4),
        (19, 4),
        (20, 4),
        (21, 4),
    ],
}
SPIKE_COLLISION_VALUES = {
    "up": 3,
    "down": 4,
    "left": 5,
    "right": 6,
}
SPRING_DIRECTION_VALUES = {
    "up": 0,
    "down": 1,
    "left": 2,
    "right": 3,
}
STRAWBERRY_TYPE_VALUES = {
    "normal": 0,
    "red": 0,
    "flying": 1,
}
RHYTHM_BLOCK_COLOR_VALUES = {
    "blue": 0,
    "pink": 1,
}


def spike_collision_value(tile: dict) -> int:
    direction = str(tile.get("direction") or tile.get("orientation") or "up")
    return SPIKE_COLLISION_VALUES.get(direction, SPIKE_COLLISION_VALUES["up"])


def spring_direction_value(spring: dict) -> int:
    direction = str(spring.get("direction") or spring.get("orientation") or "up")
    return SPRING_DIRECTION_VALUES.get(direction, SPRING_DIRECTION_VALUES["up"])


def spring_direction_name(value: int) -> str:
    for name, candidate in SPRING_DIRECTION_VALUES.items():
        if candidate == value:
            return name
    return "up"


def strawberry_type_value(strawberry: dict) -> int:
    kind = str(strawberry.get("type") or strawberry.get("kind") or "normal")
    return STRAWBERRY_TYPE_VALUES.get(kind, STRAWBERRY_TYPE_VALUES["normal"])


def strawberry_type_name(value: int) -> str:
    if value == STRAWBERRY_TYPE_VALUES["flying"]:
        return "flying"
    return "normal"


def source_mech_blocks(data: dict) -> list[dict]:
    return list(data.get("mechBlocks") or []) + list(data.get("movingPlatformMechBlocks") or [])


def source_traffic_blocks(data: dict) -> list[dict]:
    return [block for block in source_traffic_block_annotations(data) if not rhythm_block_candidate(block)]


def source_traffic_block_annotations(data: dict) -> list[dict]:
    return (
        list(data.get("trafficBlocks") or [])
        + list(data.get("trafficLightBlocks") or [])
        + list(data.get("zipperBlocks") or [])
        + list(data.get("conveyorBeltPlatforms") or [])
    )


def source_rhythm_blocks(data: dict) -> list[dict]:
    explicit = (
        list(data.get("rhythmBlocks") or [])
        + list(data.get("cassetteBlocks") or [])
        + list(data.get("cassetteRhythmBlocks") or [])
    )
    legacy_static_color_blocks = [
        block for block in source_traffic_block_annotations(data) if rhythm_block_candidate(block)
    ]
    return explicit + legacy_static_color_blocks


def source_runtime_erased_blocks(data: dict) -> list[dict]:
    return source_mech_blocks(data) + source_traffic_blocks(data) + source_rhythm_blocks(data)


def rhythm_block_color(block: dict) -> str | None:
    color = str(block.get("color") or block.get("variant") or block.get("blockColor") or "").lower()
    return color if color in RHYTHM_BLOCK_COLOR_VALUES else None


def rhythm_block_color_value(block: dict) -> int:
    color = rhythm_block_color(block) or "blue"
    return RHYTHM_BLOCK_COLOR_VALUES[color]


def rhythm_block_candidate(block: dict) -> bool:
    kind = str(block.get("kind") or block.get("material") or "").lower()
    if kind in ("rhythmblock", "cassetteblock", "cassette", "cassetteblockrect"):
        return rhythm_block_color(block) is not None
    return rhythm_block_color(block) is not None and not block_path_moves(block)


def block_path_moves(block: dict) -> bool:
    x = int(block.get("x", 0))
    y = int(block.get("y", 0))
    w = max(1, int(block.get("w", 8)))
    h = max(1, int(block.get("h", 8)))
    start_center_x = int(round(float(block.get("startCenterX", block.get("centerX", x + w / 2)))))
    start_center_y = int(round(float(block.get("startCenterY", block.get("centerY", y + h / 2)))))
    target_center_x = int(
        round(float(block.get("targetCenterX", block.get("targetX", block.get("endCenterX", start_center_x)))))
    )
    target_center_y = int(
        round(float(block.get("targetCenterY", block.get("targetY", block.get("endCenterY", start_center_y)))))
    )
    return start_center_x != target_center_x or start_center_y != target_center_y


def collision_debug_char(value: int) -> str:
    if value == 1:
        return "#"
    if value == 2:
        return "^"
    if value == 3:
        return "!"
    if value == 4:
        return "v"
    if value == 5:
        return "<"
    if value == 6:
        return ">"
    return "."


def breakable_tile_components(tiles: set[tuple[int, int]]) -> list[set[tuple[int, int]]]:
    components = []
    pending = set(tiles)
    while pending:
        start = pending.pop()
        component = {start}
        stack = [start]
        while stack:
            x, y = stack.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor not in pending:
                    continue
                pending.remove(neighbor)
                component.add(neighbor)
                stack.append(neighbor)
        components.append(component)
    return components


def breakable_wall_rects(data: dict, tile_size: int, width_tiles: int, height_tiles: int) -> list[dict]:
    tiles: set[tuple[int, int]] = set()
    for tile in data.get("tiles", []):
        kind = str(tile.get("kind", "solid"))
        if kind not in ("breakableWall", "breakable"):
            continue
        x = int(tile["x"])
        y = int(tile["y"])
        if 0 <= x < width_tiles and 0 <= y < height_tiles:
            tiles.add((x, y))

    walls = []
    for component in breakable_tile_components(tiles):
        min_x = min(x for x, _ in component)
        max_x = max(x for x, _ in component)
        min_y = min(y for _, y in component)
        max_y = max(y for _, y in component)
        walls.append(
            {
                "x": min_x * tile_size,
                "y": min_y * tile_size,
                "w": (max_x - min_x + 1) * tile_size,
                "h": (max_y - min_y + 1) * tile_size,
                "tiles": len(component),
            }
        )
    return sorted(walls, key=lambda wall: (wall["y"], wall["x"]))


def room_id_from_background(path: Path) -> str:
    return path.stem.replace("-", "_")


def is_prologue_background(path: Path) -> bool:
    return "prologue_a" in path.parts


def unique_points(points: list[dict]) -> list[dict]:
    out = []
    seen = set()
    for point in points:
        next_point = {"x": int(point.get("x", 24)), "y": int(point.get("y", 128))}
        key = (next_point["x"], next_point["y"])
        if key in seen:
            continue
        seen.add(key)
        out.append(next_point)
    return out


def grouped_stone_platforms(source_platforms: list[dict], tile_size: int) -> list[dict]:
    cells: set[tuple[int, int]] = set()
    for platform in source_platforms:
        x0 = (int(platform.get("x", 0)) // tile_size) * tile_size
        y0 = (int(platform.get("y", 0)) // tile_size) * tile_size
        w = max(tile_size, int(platform.get("w", tile_size)))
        h = max(tile_size, int(platform.get("h", tile_size)))
        x1 = x0 + ((w + tile_size - 1) // tile_size) * tile_size
        y1 = y0 + ((h + tile_size - 1) // tile_size) * tile_size
        y = y0
        while y < y1:
            x = x0
            while x < x1:
                cells.add((x, y))
                x += tile_size
            y += tile_size

    groups = []
    while cells:
        seed = cells.pop()
        stack = [seed]
        group = [seed]
        while stack:
            x, y = stack.pop()
            for neighbor in ((x - tile_size, y), (x + tile_size, y), (x, y - tile_size), (x, y + tile_size)):
                if neighbor not in cells:
                    continue
                cells.remove(neighbor)
                stack.append(neighbor)
                group.append(neighbor)
        min_x = min(x for x, _ in group)
        max_x = max(x for x, _ in group)
        min_y = min(y for _, y in group)
        max_y = max(y for _, y in group)
        groups.append({"x": min_x, "y": min_y, "w": max_x - min_x + tile_size, "h": max_y - min_y + tile_size, "cells": len(group)})

    return sorted(groups, key=lambda platform: (platform["y"], platform["x"]))


def nearest_to_edge(points: list[dict], width: int, height: int, edge: str) -> dict:
    if not points:
        return {"x": 24, "y": 128}
    if edge == "left":
        return min(points, key=lambda point: (point["x"], abs(point["y"] - height // 2)))
    if edge == "right":
        return min(points, key=lambda point: (width - point["x"], abs(point["y"] - height // 2)))
    if edge == "top":
        return min(points, key=lambda point: (point["y"], abs(point["x"] - width // 2)))
    if edge == "bottom":
        return min(points, key=lambda point: (height - point["y"], abs(point["x"] - width // 2)))
    raise ValueError(f"unknown edge: {edge}")


def png_size(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) >= 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
        return (
            int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"),
        )
    return (16, 16)


def quantize_color(color: tuple[int, int, int, int], rgb_bits: int) -> tuple[int, int, int, int]:
    if rgb_bits >= 8 or color[3] == 0:
        return color
    shift = 8 - rgb_bits
    r, g, b, a = color
    return ((r >> shift) << shift, (g >> shift) << shift, (b >> shift) << shift, a)


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def traffic_block_rect(block: dict, image_width: int, image_height: int) -> tuple[int, int, int, int]:
    x = max(0, int(block.get("x", 0)))
    y = max(0, int(block.get("y", 0)))
    w = max(0, int(block.get("w", 8)))
    h = max(0, int(block.get("h", 8)))
    if x >= image_width or y >= image_height:
        return x, y, 0, 0
    return x, y, min(w, image_width - x), min(h, image_height - y)


def image_color_at(image: Image, x: int, y: int) -> tuple[int, int, int, int]:
    offset = (y * image.width + x) * 4
    return tuple(image.pixels[offset : offset + 4])  # type: ignore[return-value]


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def traffic_block_palette(image: Image, blocks: list[dict], rgb_bits: int) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for block in blocks:
        x, y, w, h = traffic_block_rect(block, image.width, image.height)
        for pixel_y in range(y, y + h):
            for pixel_x in range(x, x + w):
                color = quantize_color(image_color_at(image, pixel_x, pixel_y), rgb_bits)
                if color[3] != 0:
                    colors[color] += 1

    palette = [(0, 0, 0, 0)] + [color for color, _ in colors.most_common(15)]
    while len(palette) < 16:
        palette.append((0, 0, 0, 255))
    return palette


def weighted_average(bucket: list[tuple[tuple[int, int, int, int], int]]) -> tuple[int, int, int, int]:
    total = sum(count for _, count in bucket)
    if total == 0:
        return (0, 0, 0, 255)
    r = sum(color[0] * count for color, count in bucket) // total
    g = sum(color[1] * count for color, count in bucket) // total
    b = sum(color[2] * count for color, count in bucket) // total
    return (r, g, b, 255)


def bucket_score(bucket: list[tuple[tuple[int, int, int, int], int]]) -> int:
    if len(bucket) <= 1:
        return -1
    total = sum(count for _, count in bucket)
    ranges = []
    for channel in range(3):
        values = [color[channel] for color, _ in bucket]
        ranges.append(max(values) - min(values))
    return max(ranges) * total


def split_bucket(
    bucket: list[tuple[tuple[int, int, int, int], int]],
) -> tuple[list[tuple[tuple[int, int, int, int], int]], list[tuple[tuple[int, int, int, int], int]]]:
    ranges = []
    for channel in range(3):
        values = [color[channel] for color, _ in bucket]
        ranges.append(max(values) - min(values))
    channel = max(range(3), key=lambda index: ranges[index])
    sorted_bucket = sorted(bucket, key=lambda item: item[0][channel])
    half = sum(count for _, count in sorted_bucket) / 2
    running = 0
    split_at = 1
    for index, (_, count) in enumerate(sorted_bucket):
        running += count
        if running >= half:
            split_at = max(1, min(len(sorted_bucket) - 1, index + 1))
            break
    return sorted_bucket[:split_at], sorted_bucket[split_at:]


def quantized_palette(colors: Counter[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    if not colors:
        return [(0, 0, 0, 0)] + [(0, 0, 0, 255)] * 15

    buckets: list[list[tuple[tuple[int, int, int, int], int]]] = [list(colors.items())]
    while len(buckets) < 15:
        bucket_index = max(range(len(buckets)), key=lambda index: bucket_score(buckets[index]))
        if bucket_score(buckets[bucket_index]) < 0:
            break
        left, right = split_bucket(buckets.pop(bucket_index))
        buckets.append(left)
        buckets.append(right)

    opaque = [weighted_average(bucket) for bucket in buckets]
    opaque.sort(key=lambda color: (color[0] + color[1] + color[2], color[0], color[1], color[2]))
    palette = [(0, 0, 0, 0)] + opaque[:15]
    while len(palette) < 16:
        palette.append((0, 0, 0, 255))
    return palette


def nearest_palette_index(color: tuple[int, int, int, int], palette: list[tuple[int, int, int, int]]) -> int:
    if color[3] == 0:
        return 0
    for index, candidate in enumerate(palette[1:], start=1):
        if color == candidate:
            return index
    return min(range(1, 16), key=lambda index: color_distance(color, palette[index]))


def crop_tile(image: Image, cell_x: int, cell_y: int) -> list[tuple[int, int, int, int]]:
    x0 = cell_x * TRAFFIC_BLOCK_TILE_SIZE
    y0 = cell_y * TRAFFIC_BLOCK_TILE_SIZE
    if x0 + TRAFFIC_BLOCK_TILE_SIZE > image.width or y0 + TRAFFIC_BLOCK_TILE_SIZE > image.height:
        raise ValueError(f"traffic block crop ({cell_x}, {cell_y}) is outside {image.width}x{image.height}")

    pixels = []
    for y in range(TRAFFIC_BLOCK_TILE_SIZE):
        for x in range(TRAFFIC_BLOCK_TILE_SIZE):
            pixels.append(image_color_at(image, x0 + x, y0 + y))
    return pixels


def load_traffic_block_templates() -> tuple[
    dict[str, list[list[tuple[int, int, int, int]]]],
    dict[tuple[int, int], list[list[list[tuple[int, int, int, int]]]]],
    Image,
]:
    repo_root = Path(__file__).resolve().parents[1]
    input_dir = repo_root / "assets" / "animations" / "conveyor_belt_platform"
    block_source = read_png_rgba(input_dir / "blocks.png")
    light_source = read_png_rgba(input_dir / "lights.png")
    if light_source.width != TRAFFIC_LIGHT_FRAME_WIDTH * TRAFFIC_LIGHT_FRAME_COUNT:
        raise ValueError(
            f"{input_dir / 'lights.png'} must be {TRAFFIC_LIGHT_FRAME_WIDTH * TRAFFIC_LIGHT_FRAME_COUNT}px wide"
        )
    if light_source.height > TRAFFIC_LIGHT_CELL_HEIGHT:
        raise ValueError(f"{input_dir / 'lights.png'} must be no taller than {TRAFFIC_LIGHT_CELL_HEIGHT}px")

    templates = {
        name: [crop_tile(block_source, cell_x, cell_y) for cell_x, cell_y in crops]
        for name, crops in TRAFFIC_BLOCK_TEMPLATE_CROPS.items()
    }
    exact_templates = {
        size: [[crop_tile(block_source, cell_x, cell_y) for row in variant for cell_x, cell_y in row] for variant in variants]
        for size, variants in TRAFFIC_BLOCK_EXACT_CROPS.items()
    }
    return templates, exact_templates, light_source


def traffic_object_palette(
    templates: dict[str, list[list[tuple[int, int, int, int]]]],
    exact_templates: dict[tuple[int, int], list[list[list[tuple[int, int, int, int]]]]],
    light_source: Image,
    rgb_bits: int,
) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for variants in templates.values():
        for tile in variants:
            for color in tile:
                color = quantize_color(color, rgb_bits)
                if color[3] != 0:
                    colors[color] += 1

    for variants in exact_templates.values():
        for variant in variants:
            for tile in variant:
                for color in tile:
                    color = quantize_color(color, rgb_bits)
                    if color[3] != 0:
                        colors[color] += 1

    for index in range(0, len(light_source.pixels), 4):
        color = quantize_color(tuple(light_source.pixels[index : index + 4]), rgb_bits)
        if color[3] != 0:
            colors[color] += 8

    palette = quantized_palette(colors)
    replace_index = len(palette) - 1
    for forced in traffic_light_accent_colors(light_source, rgb_bits):
        if forced in palette:
            continue
        while replace_index > 0 and palette[replace_index] in palette[:replace_index]:
            replace_index -= 1
        if replace_index > 0:
            palette[replace_index] = forced
            replace_index -= 1
    return palette


def traffic_light_accent_colors(light_source: Image, rgb_bits: int) -> list[tuple[int, int, int, int]]:
    accents = []
    for frame in range(TRAFFIC_LIGHT_FRAME_COUNT):
        colors: Counter[tuple[int, int, int, int]] = Counter()
        frame_x = frame * TRAFFIC_LIGHT_FRAME_WIDTH
        for y in range(light_source.height):
            for x in range(TRAFFIC_LIGHT_FRAME_WIDTH):
                color = quantize_color(image_color_at(light_source, frame_x + x, y), rgb_bits)
                if color[3] == 0:
                    continue
                if not traffic_light_accent_candidate(frame, color):
                    continue
                colors[color] += 1
        if not colors:
            continue
        accent = max(
            colors,
            key=lambda color: traffic_light_accent_score(frame, color) + colors[color],
        )
        accents.append(accent)
    return accents


def traffic_light_accent_candidate(frame: int, color: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = color
    if frame == 0:
        return r > g + 16 and r > b + 16
    if frame == 1:
        return r > b + 24 and g > b + 24 and abs(r - g) < 96
    return g > r + 16 and g > b + 16


def traffic_light_accent_score(frame: int, color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    if frame == 0:
        return (r - max(g, b)) * 8 + r
    if frame == 1:
        return (min(r, g) - b) * 8 + r + g
    return (g - max(r, b)) * 8 + g


def tile_role(col: int, row: int, columns: int, rows: int) -> str:
    if row == 0:
        if col == 0:
            return "top_left"
        if col == columns - 1:
            return "top_right"
        return "top"
    if row == rows - 1:
        if col == 0:
            return "bottom_left"
        if col == columns - 1:
            return "bottom_right"
        return "bottom"
    if col == 0:
        return "left"
    if col == columns - 1:
        return "right"
    return "interior"


def deterministic_tile_variant(
    templates: dict[str, list[list[tuple[int, int, int, int]]]],
    role: str,
    block_index: int,
    col: int,
    row: int,
    columns: int,
    rows: int,
) -> list[tuple[int, int, int, int]]:
    variants = templates[role]
    seed = block_index * 29 + columns * 7 + rows * 11 + col * 5 + row * 13
    return variants[seed % len(variants)]


def exact_block_tile_variant(
    exact_templates: dict[tuple[int, int], list[list[list[tuple[int, int, int, int]]]]],
    columns: int,
    rows: int,
    block_index: int,
) -> list[list[tuple[int, int, int, int]]] | None:
    variants = exact_templates.get((columns, rows))
    if not variants:
        return None
    return variants[block_index % len(variants)]


def write_source_tile(
    output: bytearray,
    tile: list[tuple[int, int, int, int]],
    palette: list[tuple[int, int, int, int]],
    rgb_bits: int,
) -> None:
    write_tile_4bpp(output, [nearest_palette_index(quantize_color(color, rgb_bits), palette) for color in tile])


def write_traffic_light_tiles(
    output: bytearray,
    light_source: Image,
    palette: list[tuple[int, int, int, int]],
    rgb_bits: int,
) -> None:
    for frame in range(TRAFFIC_LIGHT_FRAME_COUNT):
        frame_x = frame * TRAFFIC_LIGHT_FRAME_WIDTH
        for tile_y in range(TRAFFIC_LIGHT_CELL_HEIGHT // TRAFFIC_BLOCK_TILE_SIZE):
            tile_pixels = []
            for y in range(TRAFFIC_BLOCK_TILE_SIZE):
                source_y = tile_y * TRAFFIC_BLOCK_TILE_SIZE + y
                for x in range(TRAFFIC_BLOCK_TILE_SIZE):
                    if source_y >= light_source.height:
                        tile_pixels.append(0)
                        continue
                    color = quantize_color(image_color_at(light_source, frame_x + x, source_y), rgb_bits)
                    tile_pixels.append(nearest_palette_index(color, palette))
            write_tile_4bpp(output, tile_pixels)


def pack_traffic_block_tiles(
    data: dict,
    output_dir: Path,
    background_png: Path,
    rgb_bits: int,
) -> tuple[list[dict], list[dict], int]:
    source_mechs = source_mech_blocks(data)
    source_blocks = source_traffic_blocks(data)
    templates, exact_templates, light_source = load_traffic_block_templates()
    palette = traffic_object_palette(templates, exact_templates, light_source, rgb_bits)
    palette_binary = b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)

    packed_mechs = []
    packed_blocks = []
    tile_binary = bytearray()
    if source_mechs or source_blocks:
        write_traffic_light_tiles(tile_binary, light_source, palette, rgb_bits)

    image_width, image_height = png_size(background_png)

    def pack_blocks(blocks: list[dict], output: list[dict], block_index_offset: int) -> None:
        nonlocal tile_binary
        for block_index, block in enumerate(blocks, start=block_index_offset):
            x, y, w, h = traffic_block_rect(block, image_width, image_height)
            if w == 0 or h == 0:
                continue
            columns = (w + 7) // 8
            rows = (h + 7) // 8
            tile_offset = len(tile_binary) // 32
            if tile_offset + columns * rows > MAX_TRAFFIC_BLOCK_TILES:
                raise ValueError(
                    f"{background_png} has {tile_offset + columns * rows} traffic block OBJ tiles; "
                    f"runtime supports {MAX_TRAFFIC_BLOCK_TILES}"
                )

            exact_tiles = exact_block_tile_variant(exact_templates, columns, rows, block_index)
            for tile_y in range(rows):
                for tile_x in range(columns):
                    if exact_tiles is not None:
                        tile = exact_tiles[tile_y * columns + tile_x]
                    else:
                        role = tile_role(tile_x, tile_y, columns, rows)
                        tile = deterministic_tile_variant(templates, role, block_index, tile_x, tile_y, columns, rows)
                    write_source_tile(tile_binary, tile, palette, rgb_bits)

            start_center_x = int(round(float(block.get("startCenterX", block.get("centerX", x + w / 2)))))
            start_center_y = int(round(float(block.get("startCenterY", block.get("centerY", y + h / 2)))))
            target_center_x = int(round(float(block.get("targetCenterX", block.get("targetX", block.get("endCenterX", start_center_x))))))
            target_center_y = int(round(float(block.get("targetCenterY", block.get("targetY", block.get("endCenterY", start_center_y))))))
            target_x = target_center_x - w // 2
            target_y = target_center_y - h // 2
            output.append(
                {
                    "x": x,
                    "y": y,
                    "w": w,
                    "h": h,
                    "startCenterX": start_center_x,
                    "startCenterY": start_center_y,
                    "targetCenterX": target_center_x,
                    "targetCenterY": target_center_y,
                    "targetX": target_x,
                    "targetY": target_y,
                    "tileOffset": tile_offset,
                    "tileCount": columns * rows,
                }
            )

    pack_blocks(source_mechs, packed_mechs, 0)
    pack_blocks(source_blocks, packed_blocks, len(packed_mechs))

    (output_dir / "traffic_block_tiles.bin").write_bytes(bytes(tile_binary))
    (output_dir / "traffic_block_palette.bin").write_bytes(palette_binary)
    return packed_mechs, packed_blocks, len(tile_binary) // 32

def traffic_occupied_pixels(image: Image, blocks: list[dict]) -> set[tuple[int, int]]:
    occupied: set[tuple[int, int]] = set()
    for block in blocks:
        x, y, w, h = traffic_block_rect(block, image.width, image.height)
        for pixel_y in range(y, y + h):
            for pixel_x in range(x, x + w):
                occupied.add((pixel_x, pixel_y))
    return occupied


def traffic_erase_color(
    image: Image,
    occupied: set[tuple[int, int]],
    block: dict,
    rgb_bits: int,
) -> tuple[int, int, int, int]:
    x, y, w, h = traffic_block_rect(block, image.width, image.height)
    colors: Counter[tuple[int, int, int, int]] = Counter()
    margin = 2
    for pixel_y in range(max(0, y - margin), min(image.height, y + h + margin)):
        for pixel_x in range(max(0, x - margin), min(image.width, x + w + margin)):
            if x <= pixel_x < x + w and y <= pixel_y < y + h:
                continue
            if (pixel_x, pixel_y) in occupied:
                continue
            color = quantize_color(image_color_at(image, pixel_x, pixel_y), rgb_bits)
            if color[3] != 0:
                colors[color] += 1
    if colors:
        return colors.most_common(1)[0][0]

    whole_image: Counter[tuple[int, int, int, int]] = Counter()
    for index in range(0, len(image.pixels), 4):
        color = quantize_color(tuple(image.pixels[index : index + 4]), rgb_bits)
        if color[3] != 0:
            whole_image[color] += 1
    return whole_image.most_common(1)[0][0] if whole_image else (0, 0, 0, 255)


def prepare_runtime_background(
    background_png: Path,
    annotations_json: Path,
    output_dir: Path,
    rgb_bits: int,
) -> Path:
    if annotations_json.exists():
        data = json.loads(annotations_json.read_text())
    else:
        data = default_annotations(background_png)

    blocks = source_runtime_erased_blocks(data)
    if not blocks:
        return background_png

    image = read_png_rgba(background_png)
    pixels = bytearray(image.pixels)
    occupied = traffic_occupied_pixels(image, blocks)
    for block in blocks:
        erase = traffic_erase_color(image, occupied, block, rgb_bits)
        x, y, w, h = traffic_block_rect(block, image.width, image.height)
        for pixel_y in range(y, y + h):
            for pixel_x in range(x, x + w):
                offset = (pixel_y * image.width + pixel_x) * 4
                pixels[offset : offset + 4] = bytes(erase)

    output = output_dir / "bg_runtime_source.png"
    write_png_rgba(output, Image(image.width, image.height, bytes(pixels)))
    return output


def bridge_pole_size() -> tuple[int, int]:
    repo_root = Path(__file__).resolve().parents[1]
    path = repo_root / "assets" / "source" / "prologue-bridge" / "whole-pole.png"
    if path.exists():
        return png_size(path)
    return (8, 32)


def bridge_pole_kind(stamp_id: str) -> int | None:
    return {
        "bridge_pole": 0,
        "broken_pole": 1,
    }.get(stamp_id)


def generic_stamp_kind(stamp_id: str) -> int | None:
    return {
        "funny_car": 0,
    }.get(stamp_id)


def bird_trigger_action_code(action: str) -> int:
    return {
        "squawk_hold_hint": 1,
        "show_climb_hint": 2,
        "peck_then_fly": 3,
    }.get(action, 0)


def scene_path_for_background(background_png: Path) -> Path:
    return background_png.with_name(f"{background_png.stem}_scene.json")


def raster_line(a: dict, b: dict) -> list[tuple[int, int]]:
    x0 = int(a.get("x", 0))
    y0 = int(a.get("y", 0))
    x1 = int(b.get("x", 0))
    y1 = int(b.get("y", 0))
    dx = abs(x1 - x0)
    sx = 1 if x0 < x1 else -1
    dy = -abs(y1 - y0)
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    points = []
    while True:
        points.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return points


def densify_wire_points(points: list[dict]) -> list[tuple[int, int]]:
    if not points:
        return []
    out = []
    seen = set()
    for index in range(1, len(points)):
        for point in raster_line(points[index - 1], points[index]):
            if point not in seen:
                seen.add(point)
                out.append(point)
    if not out:
        point = (int(points[0].get("x", 0)), int(points[0].get("y", 0)))
        out.append(point)
    return out


def build_scene_wires(background_png: Path, output_dir: Path) -> None:
    scene_path = scene_path_for_background(background_png)
    output_path = output_dir / "wires.bin"
    tiles_output_path = output_dir / "wire_tiles.bin"
    json_output_path = output_dir / "wires.json"
    if not scene_path.exists():
        output_path.write_bytes((0).to_bytes(2, "little"))
        tiles_output_path.write_bytes(b"")
        json_output_path.write_text(json.dumps({"count": 0, "recordBytes": 8, "binary": "wires.bin", "tiles": "wire_tiles.bin", "wires": []}, indent=2) + "\n")
        return

    scene = json.loads(scene_path.read_text())
    wires = scene.get("wires") or []
    if not wires:
        output_path.write_bytes((0).to_bytes(2, "little"))
        tiles_output_path.write_bytes(b"")
        json_output_path.write_text(json.dumps({"count": 0, "recordBytes": 8, "binary": "wires.bin", "tiles": "wire_tiles.bin", "wires": []}, indent=2) + "\n")
        return

    metadata_path = output_dir / "bg_conversion.json"
    if not metadata_path.exists():
        output_path.write_bytes((0).to_bytes(2, "little"))
        tiles_output_path.write_bytes(b"")
        json_output_path.write_text(json.dumps({"count": 0, "recordBytes": 8, "binary": "wires.bin", "tiles": "wire_tiles.bin", "wires": []}, indent=2) + "\n")
        return

    metadata = json.loads(metadata_path.read_text())
    width = int(metadata["sourceWidth"])
    height = int(metadata["sourceHeight"])

    chunks: dict[tuple[int, int, int], list[set[tuple[int, int]]]] = {}
    for wire_index, wire in enumerate(wires):
        wire_points = densify_wire_points(wire.get("points") or [])
        if not wire_points:
            continue
        min_x = min(x for x, _ in wire_points)
        max_x = max(x for x, _ in wire_points)
        span = max(1, max_x - min_x)
        for sag in (0, 1, 2):
            transformed = []
            for x, y in wire_points:
                if x < 0 or y < 0 or x >= width or y >= height:
                    continue
                distance_from_start = x - min_x
                distance_from_end = max_x - x
                anchor_scale = max(0.0, min(1.0, min(distance_from_start, distance_from_end) / 24.0))
                offset_y = int(round(sag * anchor_scale))
                transformed.append({"x": x, "y": max(0, min(height - 1, y + offset_y))})
            if len(transformed) == 1:
                sag_points = [(transformed[0]["x"], transformed[0]["y"])]
            else:
                sag_points = []
                seen = set()
                for index in range(1, len(transformed)):
                    for point in raster_line(transformed[index - 1], transformed[index]):
                        if point not in seen:
                            seen.add(point)
                            sag_points.append(point)
            for x, y in sag_points:
                chunk_x = x // 32
                chunk_y = y // 8
                chunk = chunks.setdefault((wire_index, chunk_x, chunk_y), [set(), set(), set()])
                chunk[sag].add((x & 31, y & 7))

    records = []
    tile_bytes = bytearray()
    for chunk_index, ((wire_index, chunk_x, chunk_y), frames) in enumerate(sorted(chunks.items())):
        if chunk_index >= MAX_WIRE_CHUNKS:
            break
        tile_frames = []
        for points in frames:
            chunk_tiles = [[0] * 64 for _ in range(4)]
            for x, y in points:
                tile_x = x // 8
                local_x = x & 7
                chunk_tiles[tile_x][y * 8 + local_x] = WIRE_COLOR_INDEX
            tile_frames.extend(chunk_tiles)
        for pixels in tile_frames:
            for y in range(8):
                for x_pair in range(4):
                    left = pixels[y * 8 + x_pair * 2]
                    right = pixels[y * 8 + x_pair * 2 + 1]
                    tile_bytes.append(left | (right << 4))
        phase = (wire_index * 41) & 255
        records.append(
            {
                "x": chunk_x * 32,
                "y": chunk_y * 8,
                "tileOffset": chunk_index * 12,
                "wire": wire_index,
                "phase": phase,
                "points": sum(len(points) for points in frames),
            }
        )

    tiles_output_path.write_bytes(bytes(tile_bytes))
    binary = bytearray()
    binary.extend(len(records).to_bytes(2, "little"))
    for record in records:
        binary.extend(int(record["x"]).to_bytes(2, "little", signed=True))
        binary.extend(int(record["y"]).to_bytes(2, "little", signed=True))
        binary.extend(int(record["tileOffset"]).to_bytes(2, "little"))
        binary.append(int(record["phase"]))
        binary.append(0)
    output_path.write_bytes(bytes(binary))
    json_output_path.write_text(
        json.dumps({"count": len(records), "recordBytes": 8, "binary": "wires.bin", "tiles": "wire_tiles.bin", "scene": str(scene_path), "wires": records}, indent=2) + "\n"
    )


def normalized_scene_rect(raw: dict | None) -> dict | None:
    if not raw:
        return None
    x = int(raw.get("x", 0))
    y = int(raw.get("y", 0))
    w = int(raw.get("w", 0))
    h = int(raw.get("h", 0))
    x0 = min(x, x + w)
    y0 = min(y, y + h)
    x1 = max(x, x + w)
    y1 = max(y, y + h)
    if x1 <= x0 or y1 <= y0:
        return None
    return {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}


def build_scene_bridge_ending(background_png: Path, output_dir: Path) -> None:
    scene_path = scene_path_for_background(background_png)
    output_path = output_dir / "bridge_ending.bin"
    json_output_path = output_dir / "bridge_ending.json"
    bridge = None
    if scene_path.exists():
        scene = json.loads(scene_path.read_text())
        source = scene.get("bridgeEnding") or {}
        bridge = {
            "platform": normalized_scene_rect(source.get("platform")),
            "trigger": normalized_scene_rect(source.get("trigger")),
            "hint": normalized_scene_rect(source.get("hint")),
            "scene": str(scene_path),
        }
    enabled = bool(bridge and bridge["platform"] and bridge["trigger"])
    binary = bytearray()
    binary.extend((1 if enabled else 0).to_bytes(2, "little"))
    for key in ("platform", "trigger", "hint"):
        rect = (bridge or {}).get(key) or {"x": 0, "y": 0, "w": 0, "h": 0}
        for field in ("x", "y", "w", "h"):
            binary.extend(int(rect.get(field, 0)).to_bytes(2, "little", signed=True))
    output_path.write_bytes(bytes(binary))
    json_output_path.write_text(
        json.dumps(
            {
                "count": 1 if enabled else 0,
                "recordBytes": 24,
                "binary": "bridge_ending.bin",
                "bridgeEnding": bridge,
            },
            indent=2,
        )
        + "\n"
    )


def default_annotations(background_png: Path) -> dict:
    width, height = png_size(background_png)
    return {
        "image": background_png.name,
        "tileSize": 8,
        "width": width,
        "height": height,
        "spawn": {"x": 24, "y": max(0, height - 40)},
        "respawnPoints": [],
        "fallingBlocks": [],
        "stonePlatforms": [],
        "mechBlocks": [],
        "rhythmBlocks": [],
        "foregroundStamps": [],
        "springs": [],
        "strawberries": [],
        "tiles": [],
    }


def build_collision(annotations_json: Path, output_dir: Path, background_png: Path, rgb_bits: int) -> None:
    if annotations_json.exists():
        data = json.loads(annotations_json.read_text())
    else:
        print(f"warning: no annotations found at {annotations_json}; generating empty collision")
        data = default_annotations(background_png)
    tile_size = int(data["tileSize"])
    width = int(data["width"])
    height = int(data["height"])
    spawn = data.get("spawn") or {"x": 24, "y": 128}
    spawn_x = int(spawn.get("x", 24))
    spawn_y = int(spawn.get("y", 128))
    source_respawn_points = data.get("respawnPoints") or []
    old_respawns = data.get("respawns") or {}
    respawn_points = unique_points(
        [{"x": spawn_x, "y": spawn_y}]
        + list(source_respawn_points)
        + [point for point in old_respawns.values() if point]
    )
    width_tiles = (width + tile_size - 1) // tile_size
    height_tiles = (height + tile_size - 1) // tile_size
    collision = bytearray(width_tiles * height_tiles)

    for tile in data.get("tiles", []):
        kind = tile.get("kind", "solid")
        x = int(tile["x"])
        y = int(tile["y"])
        if 0 <= x < width_tiles and 0 <= y < height_tiles:
            if kind == "solid":
                collision[y * width_tiles + x] = 1
            elif kind == "oneWay":
                collision[y * width_tiles + x] = 2
            elif kind in ("spike", "hazard"):
                collision[y * width_tiles + x] = spike_collision_value(tile)

    source_blocks = data.get("fallingBlocks", []) if is_prologue_background(background_png) else []
    for block in source_blocks:
        block_x0 = int(block.get("x", 0)) // tile_size
        block_y0 = int(block.get("y", 0)) // tile_size
        block_x1 = (int(block.get("x", 0)) + int(block.get("w", tile_size)) + tile_size - 1) // tile_size
        block_y1 = (int(block.get("y", 0)) + int(block.get("h", tile_size)) + tile_size - 1) // tile_size
        for y in range(max(0, block_y0), min(height_tiles, block_y1)):
            for x in range(max(0, block_x0), min(width_tiles, block_x1)):
                collision[y * width_tiles + x] = 0

    source_stone_platforms = data.get("stonePlatforms", [])
    for platform in source_stone_platforms:
        platform_x0 = int(platform.get("x", 0)) // tile_size
        platform_y0 = int(platform.get("y", 0)) // tile_size
        platform_x1 = (int(platform.get("x", 0)) + int(platform.get("w", tile_size)) + tile_size - 1) // tile_size
        platform_y1 = (int(platform.get("y", 0)) + int(platform.get("h", tile_size)) + tile_size - 1) // tile_size
        for y in range(max(0, platform_y0), min(height_tiles, platform_y1)):
            for x in range(max(0, platform_x0), min(width_tiles, platform_x1)):
                collision[y * width_tiles + x] = 0

    source_mechs = source_mech_blocks(data)
    for block in source_mechs:
        block_x0 = int(block.get("x", 0)) // tile_size
        block_y0 = int(block.get("y", 0)) // tile_size
        block_x1 = (int(block.get("x", 0)) + int(block.get("w", tile_size)) + tile_size - 1) // tile_size
        block_y1 = (int(block.get("y", 0)) + int(block.get("h", tile_size)) + tile_size - 1) // tile_size
        for y in range(max(0, block_y0), min(height_tiles, block_y1)):
            for x in range(max(0, block_x0), min(width_tiles, block_x1)):
                collision[y * width_tiles + x] = 0

    source_traffic = source_traffic_blocks(data)
    for block in source_traffic:
        block_x0 = int(block.get("x", 0)) // tile_size
        block_y0 = int(block.get("y", 0)) // tile_size
        block_x1 = (int(block.get("x", 0)) + int(block.get("w", tile_size)) + tile_size - 1) // tile_size
        block_y1 = (int(block.get("y", 0)) + int(block.get("h", tile_size)) + tile_size - 1) // tile_size
        for y in range(max(0, block_y0), min(height_tiles, block_y1)):
            for x in range(max(0, block_x0), min(width_tiles, block_x1)):
                collision[y * width_tiles + x] = 0

    source_rhythm = source_rhythm_blocks(data)
    for block in source_rhythm:
        block_x0 = int(block.get("x", 0)) // tile_size
        block_y0 = int(block.get("y", 0)) // tile_size
        block_x1 = (int(block.get("x", 0)) + int(block.get("w", tile_size)) + tile_size - 1) // tile_size
        block_y1 = (int(block.get("y", 0)) + int(block.get("h", tile_size)) + tile_size - 1) // tile_size
        for y in range(max(0, block_y0), min(height_tiles, block_y1)):
            for x in range(max(0, block_x0), min(width_tiles, block_x1)):
                collision[y * width_tiles + x] = 0

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "collision.bin").write_bytes(bytes(collision))
    spawn_points = [
        {"x": spawn_x, "y": spawn_y},
        nearest_to_edge(respawn_points, width, height, "left"),
        nearest_to_edge(respawn_points, width, height, "right"),
        nearest_to_edge(respawn_points, width, height, "top"),
        nearest_to_edge(respawn_points, width, height, "bottom"),
    ]
    spawn_binary = bytearray()
    for point in spawn_points:
        spawn_binary.extend(int(point["x"]).to_bytes(2, "little", signed=True))
        spawn_binary.extend(int(point["y"]).to_bytes(2, "little", signed=True))
    (output_dir / "spawn.bin").write_bytes(bytes(spawn_binary))
    rows = []
    for y in range(height_tiles):
        row = collision[y * width_tiles : (y + 1) * width_tiles]
        rows.append("".join(collision_debug_char(value) for value in row))
    (output_dir / "collision.txt").write_text("\n".join(rows) + "\n")

    falling_blocks = []
    falling_binary = bytearray()
    falling_binary.extend(len(source_blocks).to_bytes(2, "little"))
    for block in source_blocks:
        x = int(block.get("x", 0))
        y = int(block.get("y", 0))
        w = max(0, min(255, int(block.get("w", tile_size))))
        h = max(0, min(255, int(block.get("h", tile_size))))
        max_y = int(block.get("maxY", y))
        falling_blocks.append({"x": x, "y": y, "w": w, "h": h, "maxY": max_y})
        falling_binary.extend(x.to_bytes(2, "little", signed=True))
        falling_binary.extend(y.to_bytes(2, "little", signed=True))
        falling_binary.append(w)
        falling_binary.append(h)
        falling_binary.extend(max_y.to_bytes(2, "little", signed=True))
        falling_binary.extend((0).to_bytes(2, "little"))
    (output_dir / "falling_blocks.bin").write_bytes(bytes(falling_binary))
    (output_dir / "falling_blocks.json").write_text(
        json.dumps(
            {
                "count": len(falling_blocks),
                "recordBytes": 10,
                "binary": "falling_blocks.bin",
                "blocks": falling_blocks,
            },
            indent=2,
        )
        + "\n"
    )

    stone_platforms = grouped_stone_platforms(source_stone_platforms, tile_size)
    stone_binary = bytearray()
    stone_binary.extend((0).to_bytes(2, "little"))
    for platform in stone_platforms:
        x = int(platform["x"])
        y = int(platform["y"])
        w = max(1, min(255, int(platform["w"])))
        h = max(1, min(255, int(platform["h"])))
        stone_binary.extend(x.to_bytes(2, "little", signed=True))
        stone_binary.extend(y.to_bytes(2, "little", signed=True))
        stone_binary.append(w)
        stone_binary.append(h)
        stone_binary.extend((0).to_bytes(2, "little"))
    stone_binary[0:2] = len(stone_platforms).to_bytes(2, "little")
    (output_dir / "disappearing_platforms.bin").write_bytes(bytes(stone_binary))
    (output_dir / "disappearing_platforms.json").write_text(
        json.dumps(
            {
                "count": len(stone_platforms),
                "recordBytes": 8,
                "binary": "disappearing_platforms.bin",
                "platforms": stone_platforms,
            },
            indent=2,
        )
        + "\n"
    )

    packed_mech_visuals, traffic_blocks, traffic_tile_count = pack_traffic_block_tiles(data, output_dir, background_png, rgb_bits)

    mech_blocks = []
    mech_binary = bytearray()
    mech_binary.extend((0).to_bytes(2, "little"))
    for block in packed_mech_visuals:
        x = int(block.get("x", 0))
        y = int(block.get("y", 0))
        w = max(1, min(255, int(block.get("w", tile_size))))
        h = max(1, min(255, int(block.get("h", tile_size))))
        start_center_x = int(round(float(block.get("startCenterX", block.get("centerX", x + w / 2)))))
        start_center_y = int(round(float(block.get("startCenterY", block.get("centerY", y + h / 2)))))
        target_center_x = int(round(float(block.get("targetCenterX", block.get("targetX", block.get("endCenterX", start_center_x))))))
        target_center_y = int(round(float(block.get("targetCenterY", block.get("targetY", block.get("endCenterY", start_center_y))))))
        target_x = target_center_x - w // 2
        target_y = target_center_y - h // 2
        tile_offset = max(0, min(65535, int(block.get("tileOffset", 0))))
        mech_blocks.append(
            {
                "x": x,
                "y": y,
                "w": w,
                "h": h,
                "startCenterX": start_center_x,
                "startCenterY": start_center_y,
                "targetCenterX": target_center_x,
                "targetCenterY": target_center_y,
                "targetX": target_x,
                "targetY": target_y,
                "tileOffset": tile_offset,
                "tileCount": int(block.get("tileCount", 0)),
            }
        )
        mech_binary.extend(x.to_bytes(2, "little", signed=True))
        mech_binary.extend(y.to_bytes(2, "little", signed=True))
        mech_binary.extend(target_x.to_bytes(2, "little", signed=True))
        mech_binary.extend(target_y.to_bytes(2, "little", signed=True))
        mech_binary.append(w)
        mech_binary.append(h)
        mech_binary.extend(tile_offset.to_bytes(2, "little"))
    mech_binary[0:2] = len(mech_blocks).to_bytes(2, "little")
    (output_dir / "mech_blocks.bin").write_bytes(bytes(mech_binary))
    (output_dir / "mech_blocks.json").write_text(
        json.dumps(
            {
                "count": len(mech_blocks),
                "recordBytes": 12,
                "binary": "mech_blocks.bin",
                "blocks": mech_blocks,
            },
            indent=2,
        )
        + "\n"
    )

    traffic_binary = bytearray()
    traffic_binary.extend((0).to_bytes(2, "little"))
    for block in traffic_blocks:
        x = int(block["x"])
        y = int(block["y"])
        w = max(1, min(255, int(block["w"])))
        h = max(1, min(255, int(block["h"])))
        target_x = int(block["targetX"])
        target_y = int(block["targetY"])
        tile_offset = max(0, min(65535, int(block["tileOffset"])))
        traffic_binary.extend(x.to_bytes(2, "little", signed=True))
        traffic_binary.extend(y.to_bytes(2, "little", signed=True))
        traffic_binary.extend(target_x.to_bytes(2, "little", signed=True))
        traffic_binary.extend(target_y.to_bytes(2, "little", signed=True))
        traffic_binary.append(w)
        traffic_binary.append(h)
        traffic_binary.extend(tile_offset.to_bytes(2, "little"))
    traffic_binary[0:2] = len(traffic_blocks).to_bytes(2, "little")
    (output_dir / "traffic_blocks.bin").write_bytes(bytes(traffic_binary))
    (output_dir / "traffic_blocks.json").write_text(
        json.dumps(
            {
                "count": len(traffic_blocks),
                "recordBytes": 12,
                "binary": "traffic_blocks.bin",
                "tiles": "traffic_block_tiles.bin",
                "palette": "traffic_block_palette.bin",
                "tileCount": traffic_tile_count,
                "blocks": traffic_blocks,
            },
            indent=2,
        )
        + "\n"
    )

    rhythm_blocks = []
    rhythm_binary = bytearray()
    rhythm_binary.extend((0).to_bytes(2, "little"))
    for block in source_rhythm:
        x = int(block.get("x", 0))
        y = int(block.get("y", 0))
        w = max(1, min(255, int(block.get("w", tile_size))))
        h = max(1, min(255, int(block.get("h", tile_size))))
        color = rhythm_block_color_value(block)
        rhythm_blocks.append(
            {
                "x": x,
                "y": y,
                "w": w,
                "h": h,
                "color": "pink" if color == RHYTHM_BLOCK_COLOR_VALUES["pink"] else "blue",
            }
        )
        rhythm_binary.extend(x.to_bytes(2, "little", signed=True))
        rhythm_binary.extend(y.to_bytes(2, "little", signed=True))
        rhythm_binary.append(w)
        rhythm_binary.append(h)
        rhythm_binary.append(color)
        rhythm_binary.append(0)
    rhythm_binary[0:2] = len(rhythm_blocks).to_bytes(2, "little")
    (output_dir / "rhythm_blocks.bin").write_bytes(bytes(rhythm_binary))
    (output_dir / "rhythm_blocks.json").write_text(
        json.dumps(
            {
                "count": len(rhythm_blocks),
                "recordBytes": 8,
                "binary": "rhythm_blocks.bin",
                "blocks": rhythm_blocks,
            },
            indent=2,
        )
        + "\n"
    )

    breakable_walls = breakable_wall_rects(data, tile_size, width_tiles, height_tiles)
    breakable_binary = bytearray()
    breakable_binary.extend((0).to_bytes(2, "little"))
    for wall in breakable_walls:
        x = int(wall["x"])
        y = int(wall["y"])
        w = max(1, min(255, int(wall["w"])))
        h = max(1, min(255, int(wall["h"])))
        breakable_binary.extend(x.to_bytes(2, "little", signed=True))
        breakable_binary.extend(y.to_bytes(2, "little", signed=True))
        breakable_binary.append(w)
        breakable_binary.append(h)
        breakable_binary.append(0)
        breakable_binary.append(0)
    breakable_binary[0:2] = len(breakable_walls).to_bytes(2, "little")
    (output_dir / "breakable_walls.bin").write_bytes(bytes(breakable_binary))
    (output_dir / "breakable_walls.json").write_text(
        json.dumps(
            {
                "count": len(breakable_walls),
                "recordBytes": 8,
                "binary": "breakable_walls.bin",
                "walls": breakable_walls,
            },
            indent=2,
        )
        + "\n"
    )

    source_springs = data.get("springs", [])
    springs = []
    spring_binary = bytearray()
    spring_binary.extend((0).to_bytes(2, "little"))
    for spring in source_springs:
        x = int(spring.get("x", 0))
        y = int(spring.get("y", 0))
        direction_value = spring_direction_value(spring)
        horizontal = direction_value in (SPRING_DIRECTION_VALUES["up"], SPRING_DIRECTION_VALUES["down"])
        default_w = 14 if horizontal else 4
        default_h = 4 if horizontal else 14
        w = max(1, min(255, int(spring.get("w", default_w))))
        h = max(1, min(255, int(spring.get("h", default_h))))
        springs.append({"x": x, "y": y, "w": w, "h": h, "direction": spring_direction_name(direction_value)})
        spring_binary.extend(x.to_bytes(2, "little", signed=True))
        spring_binary.extend(y.to_bytes(2, "little", signed=True))
        spring_binary.append(w)
        spring_binary.append(h)
        spring_binary.append(direction_value)
        spring_binary.append(0)
    spring_binary[0:2] = len(springs).to_bytes(2, "little")
    (output_dir / "springs.bin").write_bytes(bytes(spring_binary))
    (output_dir / "springs.json").write_text(
        json.dumps(
            {
                "count": len(springs),
                "recordBytes": 8,
                "binary": "springs.bin",
                "springs": springs,
            },
            indent=2,
        )
        + "\n"
    )

    source_strawberries = data.get("strawberries", [])
    strawberries = []
    strawberry_binary = bytearray()
    strawberry_binary.extend((0).to_bytes(2, "little"))
    for strawberry in source_strawberries:
        center_x = int(strawberry.get("centerX", strawberry.get("x", 0)))
        center_y = int(strawberry.get("centerY", strawberry.get("y", 0)))
        w = max(1, min(255, int(strawberry.get("w", 18))))
        h = max(1, min(255, int(strawberry.get("h", 16))))
        type_value = strawberry_type_value(strawberry)
        strawberries.append({"centerX": center_x, "centerY": center_y, "w": w, "h": h, "type": strawberry_type_name(type_value)})
        strawberry_binary.extend(center_x.to_bytes(2, "little", signed=True))
        strawberry_binary.extend(center_y.to_bytes(2, "little", signed=True))
        strawberry_binary.append(w)
        strawberry_binary.append(h)
        strawberry_binary.append(type_value)
        strawberry_binary.append(0)
    strawberry_binary[0:2] = len(strawberries).to_bytes(2, "little")
    (output_dir / "strawberries.bin").write_bytes(bytes(strawberry_binary))
    (output_dir / "strawberries.json").write_text(
        json.dumps(
            {
                "count": len(strawberries),
                "recordBytes": 8,
                "binary": "strawberries.bin",
                "strawberries": strawberries,
            },
            indent=2,
        )
        + "\n"
    )

    grass_stamp_ids = {f"grass{index}" for index in range(1, 9)}
    source_stamps = data.get("foregroundStamps", [])
    source_bridge_poles = [stamp for stamp in source_stamps if bridge_pole_kind(str(stamp.get("id", ""))) is not None]
    source_generic_stamps = [
        stamp
        for stamp in source_stamps
        if str(stamp.get("id", "grass1")) not in grass_stamp_ids and bridge_pole_kind(str(stamp.get("id", ""))) is None
    ]

    foreground_stamps = []
    foreground_binary = bytearray()
    foreground_binary.extend((0).to_bytes(2, "little"))
    (output_dir / "foreground_stamps.bin").write_bytes(bytes(foreground_binary))
    (output_dir / "foreground_stamps.json").write_text(
        json.dumps(
            {
                "count": len(foreground_stamps),
                "recordBytes": 8,
                "binary": "foreground_stamps.bin",
                "stamps": foreground_stamps,
            },
            indent=2,
        )
        + "\n"
    )

    bridge_pole_width, bridge_pole_height = bridge_pole_size()
    bridge_poles = []
    bridge_poles_binary = bytearray()
    bridge_poles_binary.extend(len(source_bridge_poles).to_bytes(2, "little"))
    for stamp in source_bridge_poles:
        stamp_id = str(stamp.get("id", "bridge_pole"))
        x = int(stamp.get("x", 0))
        y = int(stamp.get("y", 0))
        flags = (1 if stamp.get("flipX") else 0) | (2 if stamp.get("flipY") else 0)
        kind = bridge_pole_kind(stamp_id) or 0
        bridge_poles.append({"id": stamp_id, "kind": kind, "x": x, "y": y, "w": bridge_pole_width, "h": bridge_pole_height, "flags": flags})
        bridge_poles_binary.extend(x.to_bytes(2, "little", signed=True))
        bridge_poles_binary.extend(y.to_bytes(2, "little", signed=True))
        bridge_poles_binary.append(max(0, min(255, bridge_pole_width)))
        bridge_poles_binary.append(max(0, min(255, bridge_pole_height)))
        bridge_poles_binary.append(flags)
        bridge_poles_binary.append(kind)
    (output_dir / "bridge_poles.bin").write_bytes(bytes(bridge_poles_binary))
    (output_dir / "bridge_poles.json").write_text(
        json.dumps(
            {
                "count": len(bridge_poles),
                "recordBytes": 8,
                "binary": "bridge_poles.bin",
                "poles": bridge_poles,
            },
            indent=2,
        )
        + "\n"
    )

    generic_stamps = []
    generic_binary = bytearray()
    generic_binary.extend((0).to_bytes(2, "little"))
    for stamp in source_generic_stamps:
        stamp_id = str(stamp.get("id", "stamp"))
        x = int(stamp.get("x", 0))
        y = int(stamp.get("y", 0))
        w = max(1, min(255, int(stamp.get("w", 16))))
        h = max(1, min(255, int(stamp.get("h", 16))))
        flags = (1 if stamp.get("flipX") else 0) | (2 if stamp.get("flipY") else 0)
        if stamp.get("occludes"):
            flags |= 4
        kind = generic_stamp_kind(stamp_id)
        if kind is None:
            continue
        generic_stamps.append({"id": stamp_id, "kind": kind, "x": x, "y": y, "w": w, "h": h, "flags": flags})
        generic_binary.extend(x.to_bytes(2, "little", signed=True))
        generic_binary.extend(y.to_bytes(2, "little", signed=True))
        generic_binary.append(w)
        generic_binary.append(h)
        generic_binary.append(flags)
        generic_binary.append(kind)
    generic_binary[0:2] = len(generic_stamps).to_bytes(2, "little")
    (output_dir / "generic_stamps.bin").write_bytes(bytes(generic_binary))
    (output_dir / "generic_stamps.json").write_text(
        json.dumps(
            {
                "count": len(generic_stamps),
                "recordBytes": 8,
                "binary": "generic_stamps.bin",
                "stamps": generic_stamps,
            },
            indent=2,
        )
        + "\n"
    )

    bird = scene_bird_for_annotations(annotations_json) or data.get("birdNpc")
    bird_binary = bytearray()
    if bird:
        bird_binary.extend((1).to_bytes(2, "little"))
        for key in ("x", "y", "hintX", "hintY"):
            bird_binary.extend(int(bird.get(key, 0)).to_bytes(2, "little", signed=True))
        path_points = bird.get("flightPath") or []
        triggers = bird.get("triggers") or []
        bird_binary.append(max(0, min(255, len(path_points))))
        bird_binary.append(max(0, min(255, len(triggers))))
        for point in path_points[:255]:
            bird_binary.extend(int(point.get("x", 0)).to_bytes(2, "little", signed=True))
            bird_binary.extend(int(point.get("y", 0)).to_bytes(2, "little", signed=True))
        for trigger in triggers[:255]:
            rect = trigger.get("rect") or {}
            action_code = bird_trigger_action_code(str(trigger.get("action", "")))
            bird_binary.append(action_code)
            bird_binary.append(0)
            bird_binary.extend(int(rect.get("x", 0)).to_bytes(2, "little", signed=True))
            bird_binary.extend(int(rect.get("y", 0)).to_bytes(2, "little", signed=True))
            bird_binary.extend(int(rect.get("w", 0)).to_bytes(2, "little", signed=True))
            bird_binary.extend(int(rect.get("h", 0)).to_bytes(2, "little", signed=True))
        bird_count = 1
    else:
        bird_binary.extend((0).to_bytes(2, "little"))
        bird_count = 0
    (output_dir / "bird_npcs.bin").write_bytes(bytes(bird_binary))
    (output_dir / "bird_npcs.json").write_text(
        json.dumps(
            {
                "count": bird_count,
                "recordBytes": "12 + path_count * 4 + trigger_count * 10",
                "binary": "bird_npcs.bin",
                "bird": bird,
            },
            indent=2,
        )
        + "\n"
    )

    metadata = {
        "tileSize": tile_size,
        "width": width,
        "height": height,
        "widthTiles": width_tiles,
        "heightTiles": height_tiles,
        "collision": "collision.bin",
        "spikeTileCount": sum(1 for value in collision if value in SPIKE_COLLISION_VALUES.values()),
        "spawn": "spawn.bin",
        "spawnX": spawn_x,
        "spawnY": spawn_y,
        "respawnPoints": respawn_points,
        "respawns": {
            "left": spawn_points[1],
            "right": spawn_points[2],
            "top": spawn_points[3],
            "bottom": spawn_points[4],
        },
        "fallingBlocks": "falling_blocks.bin",
        "fallingBlockCount": len(falling_blocks),
        "breakableWalls": "breakable_walls.bin",
        "breakableWallCount": len(breakable_walls),
        "disappearingPlatforms": "disappearing_platforms.bin",
        "disappearingPlatformCount": len(stone_platforms),
        "mechBlocks": "mech_blocks.bin",
        "mechBlockCount": len(mech_blocks),
        "trafficBlocks": "traffic_blocks.bin",
        "trafficBlockCount": len(traffic_blocks),
        "trafficBlockTiles": "traffic_block_tiles.bin",
        "trafficBlockTileCount": traffic_tile_count,
        "trafficBlockPalette": "traffic_block_palette.bin",
        "rhythmBlocks": "rhythm_blocks.bin",
        "rhythmBlockCount": len(rhythm_blocks),
        "springs": "springs.bin",
        "springCount": len(springs),
        "strawberries": "strawberries.bin",
        "strawberryCount": len(strawberries),
        "foregroundStamps": "foreground_stamps.bin",
        "foregroundStampCount": len(foreground_stamps),
        "bridgePoles": "bridge_poles.bin",
        "bridgePoleCount": len(bridge_poles),
        "genericStamps": "generic_stamps.bin",
        "genericStampCount": len(generic_stamps),
        "birdNpcs": "bird_npcs.bin",
        "birdNpcCount": bird_count,
    }
    (output_dir / "collision.json").write_text(json.dumps(metadata, indent=2) + "\n")


def scene_bird_for_annotations(annotations_json: Path) -> dict | None:
    scene_path = annotations_json.with_name(f"{annotations_json.stem.removesuffix('_annotations')}_scene.json")
    if not scene_path.exists():
        return None
    scene = json.loads(scene_path.read_text())
    for entity in scene.get("entities", []):
        if entity.get("kind") != "bird":
            continue
        origin = entity.get("origin", {})
        hint = entity.get("hint", {})
        path_points = []
        for segment in entity.get("segments", []):
            path_points.extend(segment.get("points", []))
        triggers = []
        for trigger in entity.get("triggers", []):
            rect = trigger.get("rect") or {}
            triggers.append(
                {
                    "id": trigger.get("id"),
                    "action": trigger.get("action"),
                    "rect": {
                        "x": int(rect.get("x", 0)),
                        "y": int(rect.get("y", 0)),
                        "w": int(rect.get("w", 0)),
                        "h": int(rect.get("h", 0)),
                    },
                }
            )
        return {
            "x": int(origin.get("x", 0)),
            "y": int(origin.get("y", 0)),
            "hintX": int(hint.get("x", 0)),
            "hintY": int(hint.get("y", 0)),
            "flightPath": path_points,
            "triggers": triggers,
            "scene": str(scene_path),
        }
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("background_png", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--annotations", type=Path, default=None)
    parser.add_argument("--collision-only", action="store_true")
    parser.add_argument("--rgb-bits", type=int, default=8)
    args = parser.parse_args()

    annotations = args.annotations or args.background_png.with_name(f"{args.background_png.stem}_annotations.json")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    runtime_background = prepare_runtime_background(args.background_png, annotations, args.output_dir, args.rgb_bits)

    if not args.collision_only:
        subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("convert_room_tilemap_8bpp.py")),
                str(runtime_background),
                str(args.output_dir / "bg_tiles.bin"),
                str(args.output_dir / "bg_map.bin"),
                str(args.output_dir / "bg_palette.bin"),
                "--rgb-bits",
                str(args.rgb_bits),
                "--reconstruct-output",
                str(args.output_dir / "bg_reconstructed.png"),
                "--metadata-output",
                str(args.output_dir / "bg_conversion.json"),
            ],
            check=True,
        )

    build_scene_wires(args.background_png, args.output_dir)
    build_scene_bridge_ending(args.background_png, args.output_dir)

    build_collision(annotations, args.output_dir, args.background_png, args.rgb_bits)

    room = {
        "id": room_id_from_background(args.background_png),
        "background": str(args.background_png),
        "annotations": str(annotations) if annotations.exists() else None,
        "assets": {
            "tiles": "bg_tiles.bin",
            "map": "bg_map.bin",
            "palette": "bg_palette.bin",
            "collision": "collision.bin",
            "spawn": "spawn.bin",
            "fallingBlocks": "falling_blocks.bin",
            "breakableWalls": "breakable_walls.bin",
            "disappearingPlatforms": "disappearing_platforms.bin",
            "mechBlocks": "mech_blocks.bin",
            "trafficBlocks": "traffic_blocks.bin",
            "trafficBlockTiles": "traffic_block_tiles.bin",
            "trafficBlockPalette": "traffic_block_palette.bin",
            "rhythmBlocks": "rhythm_blocks.bin",
            "springs": "springs.bin",
            "strawberries": "strawberries.bin",
            "foregroundStamps": "foreground_stamps.bin",
            "bridgePoles": "bridge_poles.bin",
            "genericStamps": "generic_stamps.bin",
            "birdNpcs": "bird_npcs.bin",
            "wires": "wires.bin",
            "wireTiles": "wire_tiles.bin",
            "bridgeEnding": "bridge_ending.bin",
        },
    }
    (args.output_dir / "room.json").write_text(json.dumps(room, indent=2) + "\n")
    print(f"wrote room bundle {room['id']} to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
