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


def png_size(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) >= 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
        return (
            int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"),
        )
    return (16, 16)


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
    source_visual_stamps = [stamp for stamp in source_stamps if str(stamp.get("id", "grass1")) in stamp_kind]
    source_bridge_poles = [stamp for stamp in source_stamps if bridge_pole_kind(str(stamp.get("id", ""))) is not None]
    source_generic_stamps = [
        stamp
        for stamp in source_stamps
        if str(stamp.get("id", "grass1")) not in stamp_kind and bridge_pole_kind(str(stamp.get("id", ""))) is None
    ]

    foreground_stamps = []
    foreground_binary = bytearray()
    foreground_binary.extend(len(source_visual_stamps).to_bytes(2, "little"))
    for stamp in source_visual_stamps:
        stamp_id = str(stamp.get("id", "grass1"))
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
            "bridgePoles": "bridge_poles.bin" if annotations.exists() else None,
            "genericStamps": "generic_stamps.bin" if annotations.exists() else None,
            "birdNpcs": "bird_npcs.bin" if annotations.exists() else None,
        },
    }
    (args.output_dir / "room.json").write_text(json.dumps(room, indent=2) + "\n")
    print(f"wrote room bundle {room['id']} to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
