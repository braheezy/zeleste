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


def foreground_stamp_metadata(stamp_id: str) -> dict:
    repo_root = Path(__file__).resolve().parents[1]
    candidates = [
        repo_root / "assets" / "generated" / "foreground" / f"{stamp_id}_generated" / "sway.json",
        repo_root / "assets" / "animations" / "foreground" / f"{stamp_id}_generated" / "sway.json",
        repo_root / "assets" / "Animations" / "foreground" / f"{stamp_id}_generated" / "sway.json",
    ]
    for path in candidates:
        if path.exists():
            return json.loads(path.read_text())
    return {}


def build_collision(annotations_json: Path, output_dir: Path) -> None:
    data = json.loads(annotations_json.read_text())
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

    stamp_kind = {f"grass{index}": index - 1 for index in range(1, 9)}
    source_stamps = data.get("foregroundStamps", [])
    foreground_stamps = []
    foreground_binary = bytearray()
    foreground_binary.extend(len(source_stamps).to_bytes(2, "little"))
    for stamp in source_stamps:
        stamp_id = str(stamp.get("id", "grass1"))
        if stamp_id not in stamp_kind:
            raise ValueError(f"unknown foreground stamp id: {stamp_id}")
        metadata = foreground_stamp_metadata(stamp_id)
        x = int(stamp.get("x", 0)) + int(metadata.get("cropX", 0))
        y = int(stamp.get("y", 0)) + int(metadata.get("cropY", 0))
        phase = max(0, min(255, int(stamp.get("phase", 0))))
        flags = (1 if stamp.get("flipX") else 0) | (2 if stamp.get("flipY") else 0)
        if stamp.get("occludes"):
            flags |= 4
        foreground_stamps.append({"id": stamp_id, "x": x, "y": y, "phase": phase, "flags": flags})
        foreground_binary.extend(x.to_bytes(2, "little", signed=True))
        foreground_binary.extend(y.to_bytes(2, "little", signed=True))
        foreground_binary.append(stamp_kind[stamp_id])
        foreground_binary.append(phase)
        foreground_binary.append(flags)
        foreground_binary.append(0)
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
        "respawnPoints": respawn_points,
        "respawns": {
            "left": spawn_points[1],
            "right": spawn_points[2],
            "top": spawn_points[3],
            "bottom": spawn_points[4],
        },
        "fallingBlocks": "falling_blocks.bin",
        "fallingBlockCount": len(falling_blocks),
        "foregroundStamps": "foreground_stamps.bin",
        "foregroundStampCount": len(foreground_stamps),
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
            "foregroundStamps": "foreground_stamps.bin" if annotations.exists() else None,
        },
    }
    (args.output_dir / "room.json").write_text(json.dumps(room, indent=2) + "\n")
    print(f"wrote room bundle {room['id']} to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
