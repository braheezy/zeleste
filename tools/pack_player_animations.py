#!/usr/bin/env python3
"""Pack player animation frame PNGs into a single atlas plus manifest."""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba

FRAME_RE = re.compile(r"^f(\d+)\.png$")


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected frame name: {path}")
    return int(match.group(1))


def align_up(value: int, alignment: int) -> int:
    return ((value + alignment - 1) // alignment) * alignment


def animation_dirs(root: Path, names: list[str] | None) -> list[Path]:
    if names:
        return [root / name for name in names]
    return sorted(path for path in root.iterdir() if path.is_dir())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("assets/animations/player"))
    parser.add_argument(
        "--output-dir", type=Path, default=Path("assets/generated/player_animations")
    )
    parser.add_argument("--animations", nargs="*", default=None)
    parser.add_argument("--columns", type=int, default=16)
    parser.add_argument("--cell-width", type=int, default=None)
    parser.add_argument("--cell-height", type=int, default=None)
    args = parser.parse_args()

    selected_dirs = animation_dirs(args.input, args.animations)
    frames: list[dict] = []
    color_counts: Counter[tuple[int, int, int, int]] = Counter()
    max_width = 0
    max_height = 0

    for directory in selected_dirs:
        frame_paths = sorted(directory.glob("f*.png"), key=frame_index)
        if not frame_paths:
            continue
        animation = {
            "name": directory.name,
            "firstFrame": len(frames),
            "frameCount": len(frame_paths),
        }
        for path in frame_paths:
            image = read_png_rgba(path)
            max_width = max(max_width, image.width)
            max_height = max(max_height, image.height)
            for index in range(0, len(image.pixels), 4):
                color_counts[tuple(image.pixels[index : index + 4])] += 1
            frames.append(
                {
                    "animation": directory.name,
                    "frame": frame_index(path),
                    "path": str(path),
                    "width": image.width,
                    "height": image.height,
                    "image": image,
                }
            )
        animation["lastFrame"] = len(frames) - 1

    if not frames:
        raise ValueError(f"no animation frames found in {args.input}")

    cell_width = align_up(args.cell_width or max_width, 8)
    cell_height = align_up(args.cell_height or max_height, 8)
    if cell_width < max_width or cell_height < max_height:
        raise ValueError(
            f"cell {cell_width}x{cell_height} is smaller than largest frame {max_width}x{max_height}"
        )

    columns = max(1, args.columns)
    rows = math.ceil(len(frames) / columns)
    atlas_width = columns * cell_width
    atlas_height = rows * cell_height
    atlas_pixels = bytearray(atlas_width * atlas_height * 4)

    animations: dict[str, dict] = {}
    manifest_frames = []
    for atlas_index, frame in enumerate(frames):
        cell_x = (atlas_index % columns) * cell_width
        cell_y = (atlas_index // columns) * cell_height
        image: Image = frame["image"]
        for y in range(image.height):
            for x in range(image.width):
                src = (y * image.width + x) * 4
                dst = ((cell_y + y) * atlas_width + (cell_x + x)) * 4
                atlas_pixels[dst : dst + 4] = image.pixels[src : src + 4]

        animations.setdefault(
            frame["animation"],
            {
                "name": frame["animation"],
                "firstFrame": atlas_index,
                "frameCount": 0,
                "frames": [],
            },
        )
        animations[frame["animation"]]["frameCount"] += 1
        animations[frame["animation"]]["frames"].append(atlas_index)
        manifest_frames.append(
            {
                "animation": frame["animation"],
                "frame": frame["frame"],
                "atlasIndex": atlas_index,
                "x": cell_x,
                "y": cell_y,
                "width": image.width,
                "height": image.height,
            }
        )

    colors = list(color_counts.keys())
    colors.sort(key=lambda color: (color[3] != 0, -color_counts[color], color))
    manifest = {
        "source": str(args.input),
        "atlas": "player_animations.png",
        "cellWidth": cell_width,
        "cellHeight": cell_height,
        "columns": columns,
        "rows": rows,
        "frameCount": len(frames),
        "animationCount": len(animations),
        "colorCount": len(colors),
        "animations": list(animations.values()),
        "frames": manifest_frames,
        "paletteRgba": [list(color) for color in colors],
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_png_rgba(
        args.output_dir / "player_animations.png",
        Image(atlas_width, atlas_height, bytes(atlas_pixels)),
    )
    (args.output_dir / "player_animations.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )

    report = [
        f"animations: {len(animations)}",
        f"frames: {len(frames)}",
        f"cell: {cell_width}x{cell_height}",
        f"atlas: {atlas_width}x{atlas_height}",
        f"colors: {len(colors)}",
    ]
    (args.output_dir / "report.txt").write_text("\n".join(report) + "\n")
    print(", ".join(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
