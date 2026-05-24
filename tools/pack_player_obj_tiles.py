#!/usr/bin/env python3
"""Pack selected player animation frames into 4bpp GBA OBJ tiles."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import read_png_rgba

FRAME_RE = re.compile(r"^f(\d+)\.png$")


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected frame name: {path}")
    return int(match.group(1))


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            left = pixels[y * 8 + x_pair * 2]
            right = pixels[y * 8 + x_pair * 2 + 1]
            output.append(left | (right << 4))


def load_hair_anchors(directory: Path) -> dict[int, dict] | None:
    path = directory / "hair_anchors.json"
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    return {int(frame["index"]): frame for frame in data["frames"]}


def normalize_hair_anchor(anchor_frame: dict | None) -> tuple[int, int, int]:
    if anchor_frame is None:
        return (18, 19, -1)
    direction = int(anchor_frame.get("dir", -1))
    direction = 1 if direction > 0 else -1
    if "anchor" in anchor_frame:
        return (
            int(anchor_frame["anchor"]["x"]),
            int(anchor_frame["anchor"]["y"]),
            direction,
        )
    if "root1" in anchor_frame:
        return (
            int(anchor_frame["root1"]["x"]),
            int(anchor_frame["root1"]["y"]) + 7,
            direction,
        )
    return (18, 19, direction)


def parse_animation_spec(spec: str) -> tuple[str, str]:
    if ":" in spec:
        name, directory = spec.split(":", 1)
        if not name or not directory:
            raise ValueError(f"invalid animation spec: {spec}")
        return name, directory
    return spec, spec


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("assets/animations/player"))
    parser.add_argument(
        "--output-dir", type=Path, default=Path("assets/generated/player")
    )
    parser.add_argument("--animations", nargs="+", default=["idle", "runSlow"])
    parser.add_argument("--cell-width", type=int, default=32)
    parser.add_argument("--cell-height", type=int, default=32)
    args = parser.parse_args()

    frame_sources = []
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for spec in args.animations:
        animation, directory_name = parse_animation_spec(spec)
        directory = args.input / directory_name
        hair_anchors = load_hair_anchors(directory)
        frame_paths = sorted(directory.glob("f*.png"), key=frame_index)
        if not frame_paths:
            raise ValueError(f"no frames found for {directory_name}")
        for path in frame_paths:
            image = read_png_rgba(path)
            if image.width > args.cell_width or image.height > args.cell_height:
                raise ValueError(
                    f"{path} is {image.width}x{image.height}, larger than {args.cell_width}x{args.cell_height}"
                )
            for index in range(0, len(image.pixels), 4):
                colors[tuple(image.pixels[index : index + 4])] += 1
            anchor = normalize_hair_anchor(
                hair_anchors.get(frame_index(path)) if hair_anchors else None
            )
            frame_sources.append((animation, frame_index(path), image, anchor))

    transparent = [(0, 0, 0, 0)]
    opaque = [color for color, _ in colors.most_common() if color[3] != 0]
    if len(opaque) > 15:
        raise ValueError(
            f"selected animations use {len(opaque)} opaque colors; 4bpp supports 15"
        )
    palette = transparent + opaque + [(0, 0, 0, 255)] * (16 - 1 - len(opaque))
    palette_index = {color: index for index, color in enumerate(palette)}
    for color in colors:
        if color[3] == 0:
            palette_index[color] = 0

    tiles = bytearray()
    frames = []
    animations: dict[str, dict] = {}
    tiles_per_row = args.cell_width // 8
    tiles_per_col = args.cell_height // 8
    tiles_per_frame = tiles_per_row * tiles_per_col

    hair_anchor_bytes = bytearray()
    for animation, source_frame, image, hair_anchor in frame_sources:
        frame_index_out = len(frames)
        base_tile = frame_index_out * tiles_per_frame
        animations.setdefault(
            animation,
            {
                "name": animation,
                "firstFrame": frame_index_out,
                "frameCount": 0,
                "frames": [],
            },
        )
        animations[animation]["frameCount"] += 1
        animations[animation]["frames"].append(frame_index_out)
        hair_anchor_bytes.append(max(0, min(args.cell_width - 1, hair_anchor[0])))
        hair_anchor_bytes.append(max(0, min(args.cell_height - 1, hair_anchor[1])))
        hair_anchor_bytes.append(1 if hair_anchor[2] > 0 else 0)

        for tile_y in range(tiles_per_col):
            for tile_x in range(tiles_per_row):
                tile_pixels = []
                for y in range(8):
                    for x in range(8):
                        image_x = tile_x * 8 + x
                        image_y = tile_y * 8 + y
                        if image_x >= image.width or image_y >= image.height:
                            tile_pixels.append(0)
                            continue
                        offset = (image_y * image.width + image_x) * 4
                        color = tuple(image.pixels[offset : offset + 4])
                        tile_pixels.append(palette_index[color])
                write_tile_4bpp(tiles, tile_pixels)

        frames.append(
            {
                "animation": animation,
                "sourceFrame": source_frame,
                "baseTile": base_tile,
                "tileCount": tiles_per_frame,
                "width": args.cell_width,
                "height": args.cell_height,
            }
        )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "madeline_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "madeline_hair_anchors.bin").write_bytes(
        bytes(hair_anchor_bytes)
    )
    (args.output_dir / "madeline_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    manifest = {
        "cellWidth": args.cell_width,
        "cellHeight": args.cell_height,
        "tilesPerFrame": tiles_per_frame,
        "frameCount": len(frames),
        "animations": list(animations.values()),
        "frames": frames,
        "paletteRgba": [list(color) for color in palette],
    }
    (args.output_dir / "madeline_animations.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )
    print(
        f"packed {len(frames)} frames, {tiles_per_frame} tiles/frame, "
        f"{len(opaque)} opaque colors"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
