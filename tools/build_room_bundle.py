#!/usr/bin/env python3
"""Build generated assets for one edited room background."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def room_id_from_background(path: Path) -> str:
    return path.stem.replace("-", "_")


def build_collision(annotations_json: Path, output_dir: Path) -> None:
    data = json.loads(annotations_json.read_text())
    tile_size = int(data["tileSize"])
    width = int(data["width"])
    height = int(data["height"])
    width_tiles = (width + tile_size - 1) // tile_size
    height_tiles = (height + tile_size - 1) // tile_size
    collision = bytearray(width_tiles * height_tiles)

    for tile in data.get("tiles", []):
        if tile.get("kind", "solid") != "solid":
            continue
        x = int(tile["x"])
        y = int(tile["y"])
        if 0 <= x < width_tiles and 0 <= y < height_tiles:
            collision[y * width_tiles + x] = 1

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "collision.bin").write_bytes(bytes(collision))
    rows = []
    for y in range(height_tiles):
        row = collision[y * width_tiles : (y + 1) * width_tiles]
        rows.append("".join("#" if value else "." for value in row))
    (output_dir / "collision.txt").write_text("\n".join(rows) + "\n")

    metadata = {
        "tileSize": tile_size,
        "width": width,
        "height": height,
        "widthTiles": width_tiles,
        "heightTiles": height_tiles,
        "collision": "collision.bin",
    }
    (output_dir / "collision.json").write_text(json.dumps(metadata, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("background_png", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--annotations", type=Path, default=None)
    parser.add_argument("--collision-only", action="store_true")
    args = parser.parse_args()

    annotations = args.annotations or args.background_png.with_name(f"{args.background_png.stem}_annotations.json")
    args.output_dir.mkdir(parents=True, exist_ok=True)

    if not args.collision_only:
        subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("convert_room_tilemap_8bpp.py")),
                str(args.background_png),
                str(args.output_dir / "bg_tiles.bin"),
                str(args.output_dir / "bg_map.bin"),
                str(args.output_dir / "bg_palette.bin"),
            ],
            check=True,
        )

    if annotations.exists():
        build_collision(annotations, args.output_dir)
    else:
        print(f"warning: no annotations found at {annotations}")

    room = {
        "id": room_id_from_background(args.background_png),
        "background": str(args.background_png),
        "annotations": str(annotations) if annotations.exists() else None,
        "assets": {
            "tiles": "bg_tiles.bin",
            "map": "bg_map.bin",
            "palette": "bg_palette.bin",
            "collision": "collision.bin" if annotations.exists() else None,
        },
    }
    (args.output_dir / "room.json").write_text(json.dumps(room, indent=2) + "\n")
    print(f"wrote room bundle {room['id']} to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
