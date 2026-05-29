#!/usr/bin/env python3
"""Build generated assets for one edited room background."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

WIRE_COLOR_INDEX = 6
MAX_WIRE_CHUNKS = 48
SPIKE_COLLISION_VALUES = {
    "up": 3,
    "down": 4,
    "left": 5,
    "right": 6,
}


def spike_collision_value(tile: dict) -> int:
    direction = str(tile.get("direction") or tile.get("orientation") or "up")
    return SPIKE_COLLISION_VALUES.get(direction, SPIKE_COLLISION_VALUES["up"])


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
            elif kind in ("spike", "hazard"):
                collision[y * width_tiles + x] = spike_collision_value(tile)

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

    build_scene_wires(args.background_png, args.output_dir)
    build_scene_bridge_ending(args.background_png, args.output_dir)

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
