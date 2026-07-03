#!/usr/bin/env python3
"""Pack strawberry OBJ animations into 4bpp GBA tiles."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba


FRAME_RE = re.compile(r"^f(\d+)\.png$")
ANIMATIONS = {
    "idle": {"cellWidth": 32, "cellHeight": 16},
    "flap": {"cellWidth": 64, "cellHeight": 32},
    "collect": {"cellWidth": 32, "cellHeight": 16},
}
SCORE_VARIANTS = 6
SCORE_CELL_WIDTH = 32
SCORE_CELL_HEIGHT = 16


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected frame name: {path}")
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


def load_frames(input_dir: Path) -> dict[str, list[tuple[Path, object]]]:
    out = {}
    for name in ANIMATIONS:
        frame_paths = sorted((input_dir / name).glob("f*.png"), key=frame_index)
        if not frame_paths:
            raise ValueError(f"no frames found in {input_dir / name}")
        out[name] = [(path, read_png_rgba(path)) for path in frame_paths]
    return out


def build_palette_from_frame_lists(frame_lists: list[list[tuple[Path, object]]]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for animation_frames in frame_lists:
        for _, image in animation_frames:
            for index in range(0, len(image.pixels), 4):
                color = tuple(image.pixels[index : index + 4])
                if color[3] != 0:
                    colors[color] += 1
    opaque = [color for color, _ in colors.most_common(15)]
    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (15 - len(opaque))


def build_palette(frames: dict[str, list[tuple[Path, object]]], animation_names: list[str]) -> list[tuple[int, int, int, int]]:
    return build_palette_from_frame_lists([frames[name] for name in animation_names])


def pack_cell_frames(
    name: str,
    frames: list[tuple[Path, object]],
    palette: list[tuple[int, int, int, int]],
    cell_width: int,
    cell_height: int,
) -> tuple[bytes, dict]:
    tiles_per_frame = (cell_width // 8) * (cell_height // 8)
    palette_opaque = [color for color in palette if color[3] != 0]
    palette_index = {color: index for index, color in enumerate(palette)}
    for color in palette:
        if color[3] == 0:
            palette_index[color] = 0

    def pixel_index(color: tuple[int, int, int, int]) -> int:
        if color[3] == 0:
            return 0
        if color in palette_index:
            return palette_index[color]
        closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
        return palette_index[closest]

    tiles = bytearray()
    manifest_frames = []
    source_width = 0
    source_height = 0
    for path, image in frames:
        if image.width > cell_width or image.height > cell_height:
            raise ValueError(f"{path} is {image.width}x{image.height}, larger than {cell_width}x{cell_height}")
        if source_width == 0:
            source_width = image.width
            source_height = image.height
        elif image.width != source_width or image.height != source_height:
            raise ValueError(f"{path} is {image.width}x{image.height}; expected {source_width}x{source_height}")

        pad_x = (cell_width - image.width) // 2
        pad_y = (cell_height - image.height) // 2
        for tile_y in range(cell_height // 8):
            for tile_x in range(cell_width // 8):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x - pad_x
                        image_y = tile_y * 8 + y - pad_y
                        if image_x < 0 or image_y < 0 or image_x >= image.width or image_y >= image.height:
                            tile_pixels.append(0)
                            continue
                        offset = (image_y * image.width + image_x) * 4
                        color = tuple(image.pixels[offset : offset + 4])
                        tile_pixels.append(pixel_index(color))
                write_tile_4bpp(tiles, tile_pixels)
        manifest_frames.append({"source": path.name, "sourceFrame": frame_index(path)})

    return bytes(tiles), {
        "name": name,
        "frameCount": len(frames),
        "sourceWidth": source_width,
        "sourceHeight": source_height,
        "cellWidth": cell_width,
        "cellHeight": cell_height,
        "tilesPerFrame": tiles_per_frame,
        "frames": manifest_frames,
    }


def pack_animation(name: str, frames: list[tuple[Path, object]], palette: list[tuple[int, int, int, int]]) -> tuple[bytes, dict]:
    cell_width = int(ANIMATIONS[name]["cellWidth"])
    cell_height = int(ANIMATIONS[name]["cellHeight"])
    return pack_cell_frames(name, frames, palette, cell_width, cell_height)


def load_score_frames(input_dir: Path) -> list[list[tuple[Path, object]]]:
    variants = []
    for variant in range(SCORE_VARIANTS):
        variant_dir = input_dir / f"fade{variant}"
        frame_paths = sorted(variant_dir.glob("f*.png"), key=frame_index)
        if not frame_paths:
            raise ValueError(f"no frames found in {variant_dir}")
        variants.append([(path, read_png_rgba(path)) for path in frame_paths])
    return variants


def pack_score_variants(
    score_variants: list[list[tuple[Path, object]]],
    palette: list[tuple[int, int, int, int]],
) -> tuple[bytes, dict]:
    max_frame_count = max(len(frames) for frames in score_variants)
    tiles = bytearray()
    manifest_variants = []

    for variant, frames in enumerate(score_variants):
        padded_frames = list(frames)
        while len(padded_frames) < max_frame_count:
            padded_frames.append(frames[-1])
        variant_tiles, manifest = pack_cell_frames(
            f"fade{variant}",
            padded_frames,
            palette,
            SCORE_CELL_WIDTH,
            SCORE_CELL_HEIGHT,
        )
        tiles.extend(variant_tiles)
        manifest["sourceFrameCount"] = len(frames)
        manifest_variants.append(manifest)

    return bytes(tiles), {
        "name": "score",
        "variantCount": len(score_variants),
        "frameCount": max_frame_count,
        "cellWidth": SCORE_CELL_WIDTH,
        "cellHeight": SCORE_CELL_HEIGHT,
        "tilesPerFrame": (SCORE_CELL_WIDTH // 8) * (SCORE_CELL_HEIGHT // 8),
        "variants": manifest_variants,
    }


def write_score_meta(path: Path, manifest: dict) -> None:
    path.write_text(
        "\n".join(
            [
                f"pub const variant_count: u16 = {manifest['variantCount']};",
                f"pub const frame_count: u16 = {manifest['frameCount']};",
                f"pub const cell_width: i16 = {manifest['cellWidth']};",
                f"pub const cell_height: i16 = {manifest['cellHeight']};",
                f"pub const tiles_per_frame: u16 = {manifest['tilesPerFrame']};",
                "",
            ]
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--name", default="strawberry")
    parser.add_argument("--score-input", type=Path)
    args = parser.parse_args()

    frames = load_frames(args.input)
    berry_palette = build_palette(frames, ["idle", "flap"])
    collect_palette = build_palette(frames, ["collect"])
    args.output_dir.mkdir(parents=True, exist_ok=True)

    manifest = {
        "source": str(args.input),
        "animations": {},
        "berryPaletteRgba": [list(color) for color in berry_palette],
        "collectPaletteRgba": [list(color) for color in collect_palette],
    }
    for name, animation_frames in frames.items():
        palette = collect_palette if name == "collect" else berry_palette
        tiles, animation_manifest = pack_animation(name, animation_frames, palette)
        (args.output_dir / f"{args.name}_{name}_tiles.bin").write_bytes(tiles)
        manifest["animations"][name] = animation_manifest

    if args.score_input is not None:
        score_variants = load_score_frames(args.score_input)
        score_palette = collect_palette
        score_tiles, score_manifest = pack_score_variants(score_variants, score_palette)
        (args.output_dir / f"{args.name}_score_tiles.bin").write_bytes(score_tiles)
        (args.output_dir / f"{args.name}_score_palette.bin").write_bytes(
            b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in score_palette)
        )
        write_score_meta(args.output_dir / f"{args.name}_score_meta.zig", score_manifest)
        manifest["score"] = score_manifest
        manifest["scorePaletteRgba"] = [list(color) for color in score_palette]

    (args.output_dir / f"{args.name}_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in berry_palette)
    )
    (args.output_dir / f"{args.name}_collect_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in collect_palette)
    )
    (args.output_dir / f"{args.name}.json").write_text(json.dumps(manifest, indent=2) + "\n")
    berry_opaque = sum(1 for color in berry_palette if color[3] != 0)
    collect_opaque = sum(1 for color in collect_palette if color[3] != 0)
    print(
        f"packed {args.name} animations: idle={len(frames['idle'])}, flap={len(frames['flap'])}, "
        f"collect={len(frames['collect'])}, berry={berry_opaque} opaque colors, collect={collect_opaque} opaque colors"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
