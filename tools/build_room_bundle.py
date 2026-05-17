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
    spawn = data.get("spawn") or {"x": 24, "y": 128}
    spawn_x = int(spawn.get("x", 24))
    spawn_y = int(spawn.get("y", 128))
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

    source_blocks = data.get("fallingBlocks", [])
    for block in source_blocks:
        block_x0 = int(block.get("x", 0)) // tile_size
        block_y0 = int(block.get("y", 0)) // tile_size
        block_x1 = (int(block.get("x", 0)) + int(block.get("w", tile_size)) + tile_size - 1) // tile_size
        block_y1 = (int(block.get("y", 0)) + int(block.get("h", tile_size)) + tile_size - 1) // tile_size
        for y in range(max(0, block_y0), min(height_tiles, block_y1)):
            for x in range(max(0, block_x0), min(width_tiles, block_x1)):
                collision[y * width_tiles + x] = 0

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "collision.bin").write_bytes(bytes(collision))
    (output_dir / "spawn.bin").write_bytes(spawn_x.to_bytes(2, "little", signed=True))
    with (output_dir / "spawn.bin").open("ab") as file:
        file.write(spawn_y.to_bytes(2, "little", signed=True))
    rows = []
    for y in range(height_tiles):
        row = collision[y * width_tiles : (y + 1) * width_tiles]
        rows.append("".join("#" if value == 1 else "^" if value == 2 else "." for value in row))
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

    metadata = {
        "tileSize": tile_size,
        "width": width,
        "height": height,
        "widthTiles": width_tiles,
        "heightTiles": height_tiles,
        "collision": "collision.bin",
        "spawn": "spawn.bin",
        "spawnX": spawn_x,
        "spawnY": spawn_y,
        "fallingBlocks": "falling_blocks.bin",
        "fallingBlockCount": len(falling_blocks),
    }
    (output_dir / "collision.json").write_text(json.dumps(metadata, indent=2) + "\n")


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

    if not args.collision_only:
        subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("convert_room_tilemap_8bpp.py")),
                str(args.background_png),
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
            "spawn": "spawn.bin" if annotations.exists() else None,
            "fallingBlocks": "falling_blocks.bin" if annotations.exists() else None,
        },
    }
    (args.output_dir / "room.json").write_text(json.dumps(room, indent=2) + "\n")
    print(f"wrote room bundle {room['id']} to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
