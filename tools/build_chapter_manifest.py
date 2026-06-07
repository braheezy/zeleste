#!/usr/bin/env python3
"""Generate the combined room manifest used by the GBA build."""

from __future__ import annotations

import argparse
import json
import re
from collections import deque
from pathlib import Path


OPPOSITE = {
    "left": "right",
    "right": "left",
    "up": "down",
    "down": "up",
}

SYNTHETIC_CITY_EXITS = [
    {"source": "city_9", "direction": "right", "target": "city_9b", "x1": 319, "y1": 40, "x2": 319, "y2": 72},
    {"source": "city_12", "direction": "right", "target": "city_12a", "x1": 415, "y1": 160, "x2": 415, "y2": 184},
]

CITY_ROOM_RGB_BITS = {
    "6b": 2,
}


def png_size(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) >= 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
        return (
            int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"),
        )
    return (320, 184)


def natural_key(value: str) -> tuple:
    parts = re.split(r"(\d+)", value)
    out = []
    for part in parts:
        if not part:
            continue
        out.append((0, int(part)) if part.isdigit() else (1, part))
    return tuple(out)


def annotation_path_for_image(image: Path) -> Path:
    return image.with_name(f"{image.stem}_annotations.json")


def is_room_source_image(path: Path) -> bool:
    stem = path.stem
    helper_suffixes = (
        "-plx",
        "-overlay",
        "_overlay",
        "-hidden-cover",
        "_hidden_cover",
    )
    return not stem.endswith(helper_suffixes)


def read_annotation(image: Path) -> dict:
    path = annotation_path_for_image(image)
    if not path.exists():
        width, height = png_size(image)
        return {
            "image": image.name,
            "tileSize": 8,
            "width": width,
            "height": height,
            "spawn": {"x": 24, "y": max(0, height - 40)},
            "exits": [],
            "pitDeathLines": [],
            "tiles": [],
        }
    return json.loads(path.read_text())


def exit_direction(exit_line: dict, width: int, height: int) -> str:
    x1 = int(exit_line.get("x1", 0))
    x2 = int(exit_line.get("x2", x1))
    y1 = int(exit_line.get("y1", 0))
    y2 = int(exit_line.get("y2", y1))
    min_x = min(x1, x2)
    max_x = max(x1, x2)
    min_y = min(y1, y2)
    max_y = max(y1, y2)
    tolerance = 2
    if max_x <= tolerance:
        return "left"
    if min_x >= width - 1 - tolerance:
        return "right"
    if max_y <= tolerance:
        return "up"
    if min_y >= height - 1 - tolerance:
        return "down"

    distances = {
        "left": min_x,
        "right": width - 1 - max_x,
        "up": min_y,
        "down": height - 1 - max_y,
    }
    return min(distances.items(), key=lambda item: item[1])[0]


def exit_midpoint(exit_line: dict) -> tuple[int, int]:
    x1 = int(exit_line.get("x1", 0))
    x2 = int(exit_line.get("x2", x1))
    y1 = int(exit_line.get("y1", 0))
    y2 = int(exit_line.get("y2", y1))
    return (round((x1 + x2) / 2), round((y1 + y2) / 2))


def clamp(value: int, minimum: int, maximum: int) -> int:
    if maximum <= minimum:
        return minimum
    return max(minimum, min(maximum, value))


def annotation_respawn_points(annotation: dict, width: int, height: int) -> list[dict]:
    spawn = annotation.get("spawn") or {"x": 24, "y": max(0, height - 40)}
    points = [spawn]
    points.extend(annotation.get("respawnPoints") or [])
    points.extend(point for point in (annotation.get("respawns") or {}).values() if point)

    out = []
    seen = set()
    for point in points:
        next_point = {
            "x": int(point.get("x", 0)),
            "y": int(point.get("y", 0)),
        }
        key = (next_point["x"], next_point["y"])
        if key in seen:
            continue
        seen.add(key)
        out.append(next_point)
    return out


def city_target_id(raw_target: str, room_id: str, fallback: str, city_ids: set[str]) -> str | None:
    target = str(raw_target or "").strip()
    fallback = str(fallback or "").strip()
    if (not target or target == room_id) and fallback and fallback != room_id:
        target = fallback
    if not target:
        return None
    if target.startswith("city_"):
        target = target[5:]
    if target not in city_ids:
        return None
    return f"city_{target}"


def city_exit_edge(source: str, direction: str, target: str, x1: int, y1: int, x2: int, y2: int) -> dict:
    return {
        "source": source,
        "direction": direction,
        "target": target,
        "x1": x1,
        "y1": y1,
        "x2": x2,
        "y2": y2,
        "x": round((x1 + x2) / 2),
        "y": round((y1 + y2) / 2),
    }


def collect_city_rooms(city_dir: Path) -> list[dict]:
    images = sorted(
        [path for path in city_dir.glob("*.png") if is_room_source_image(path)],
        key=lambda path: natural_key(path.stem),
    )
    city_ids = {image.stem for image in images}
    rooms = []
    by_id: dict[str, dict] = {}
    explicit_edges: list[dict] = []

    for image in images:
        annotation = read_annotation(image)
        room_id = image.stem
        width = int(annotation.get("width") or png_size(image)[0])
        height = int(annotation.get("height") or png_size(image)[1])
        room = {
            "id": f"city_{room_id}",
            "image": str(image.resolve()),
            "worldX": 0,
            "worldY": 0,
            "rgbBits": CITY_ROOM_RGB_BITS.get(room_id, 3),
            "_width": width,
            "_height": height,
            "_edges": {},
            "_edgeTargets": {},
            "_exitLines": [],
            "_respawnPoints": annotation_respawn_points(annotation, width, height),
            "exitLines": [],
        }
        fallback = str(annotation.get("exitTargetRoom") or "")
        for exit_line in annotation.get("exits", []) or []:
            target = city_target_id(str(exit_line.get("targetRoom") or ""), room_id, fallback, city_ids)
            if target is None:
                continue
            direction = exit_direction(exit_line, width, height)
            x1 = int(exit_line.get("x1", 0))
            x2 = int(exit_line.get("x2", x1))
            y1 = int(exit_line.get("y1", 0))
            y2 = int(exit_line.get("y2", y1))
            edge = city_exit_edge(room["id"], direction, target, x1, y1, x2, y2)
            room["_exitLines"].append(edge)
            room["_edgeTargets"].setdefault(direction, set()).add(target)
            explicit_edges.append(edge)
        rooms.append(room)
        by_id[room["id"]] = room

    add_synthetic_city_exits(by_id, explicit_edges)

    for room in rooms:
        for direction, targets in room["_edgeTargets"].items():
            if len(targets) == 1:
                room["_edges"][direction] = next(iter(targets))

    for edge in explicit_edges:
        target_room = by_id.get(edge["target"])
        if not target_room:
            continue
        opposite = OPPOSITE[edge["direction"]]
        target_room["_edges"].setdefault(opposite, edge["source"])

    assign_world_positions(rooms, by_id, explicit_edges)
    apply_city_layout(by_id, load_city_layout(city_dir, by_id))
    build_city_exit_lines(rooms, by_id, explicit_edges)

    out = []
    for room in rooms:
        next_room = {key: value for key, value in room.items() if not key.startswith("_")}
        next_room.update(room["_edges"])
        out.append(next_room)
    return out


def add_synthetic_city_exits(by_id: dict[str, dict], explicit_edges: list[dict]) -> None:
    for synthetic in SYNTHETIC_CITY_EXITS:
        source = by_id.get(synthetic["source"])
        target = by_id.get(synthetic["target"])
        if source is None or target is None:
            continue
        direction = str(synthetic["direction"])
        target_id = str(synthetic["target"])
        if target_id in source["_edgeTargets"].get(direction, set()):
            continue
        edge = city_exit_edge(
            str(synthetic["source"]),
            direction,
            target_id,
            int(synthetic["x1"]),
            int(synthetic["y1"]),
            int(synthetic["x2"]),
            int(synthetic["y2"]),
        )
        source["_exitLines"].append(edge)
        source["_edgeTargets"].setdefault(direction, set()).add(target_id)
        explicit_edges.append(edge)


def build_city_exit_lines(rooms: list[dict], by_id: dict[str, dict], explicit_edges: list[dict]) -> None:
    for room in rooms:
        room["exitLines"] = []

    for edge in explicit_edges:
        append_city_exit_line(by_id[edge["source"]], edge)

    for edge in explicit_edges:
        if has_reciprocal_exit_line(edge, by_id, explicit_edges):
            continue
        reverse = projected_reciprocal_edge(edge, by_id)
        append_city_exit_line(by_id[reverse["source"]], reverse)


def append_city_exit_line(room: dict, edge: dict) -> None:
    line = {
        "kind": "exit",
        "x1": int(edge["x1"]),
        "y1": int(edge["y1"]),
        "x2": int(edge["x2"]),
        "y2": int(edge["y2"]),
        "targetRoom": edge["target"],
    }
    for existing in room["exitLines"]:
        if existing.get("targetRoom") != line["targetRoom"]:
            continue
        if exit_direction(existing, room["_width"], room["_height"]) != edge["direction"]:
            continue
        if exit_line_interval_overlap(existing, line, edge["direction"]) > 0:
            return
    if line not in room["exitLines"]:
        room["exitLines"].append(line)


def exit_line_interval_overlap(a: dict, b: dict, direction: str) -> int:
    if direction in ("up", "down"):
        a0 = min(int(a["x1"]), int(a["x2"]))
        a1 = max(int(a["x1"]), int(a["x2"])) + 1
        b0 = min(int(b["x1"]), int(b["x2"]))
        b1 = max(int(b["x1"]), int(b["x2"])) + 1
    else:
        a0 = min(int(a["y1"]), int(a["y2"]))
        a1 = max(int(a["y1"]), int(a["y2"])) + 1
        b0 = min(int(b["y1"]), int(b["y2"]))
        b1 = max(int(b["y1"]), int(b["y2"])) + 1
    return max(0, min(a1, b1) - max(a0, b0))


def has_reciprocal_exit_line(edge: dict, by_id: dict[str, dict], explicit_edges: list[dict]) -> bool:
    opposite = OPPOSITE[edge["direction"]]
    for candidate in explicit_edges:
        if candidate["source"] != edge["target"] or candidate["target"] != edge["source"] or candidate["direction"] != opposite:
            continue
        if projected_interval_overlap(edge, candidate, by_id) > 0:
            return True
    return False


def projected_interval_overlap(edge: dict, candidate: dict, by_id: dict[str, dict]) -> int:
    source = by_id[edge["source"]]
    candidate_source = by_id[candidate["source"]]
    if edge["direction"] in ("up", "down"):
        a0 = source["worldX"] + min(int(edge["x1"]), int(edge["x2"]))
        a1 = source["worldX"] + max(int(edge["x1"]), int(edge["x2"])) + 1
        b0 = candidate_source["worldX"] + min(int(candidate["x1"]), int(candidate["x2"]))
        b1 = candidate_source["worldX"] + max(int(candidate["x1"]), int(candidate["x2"])) + 1
    else:
        a0 = source["worldY"] + min(int(edge["y1"]), int(edge["y2"]))
        a1 = source["worldY"] + max(int(edge["y1"]), int(edge["y2"])) + 1
        b0 = candidate_source["worldY"] + min(int(candidate["y1"]), int(candidate["y2"]))
        b1 = candidate_source["worldY"] + max(int(candidate["y1"]), int(candidate["y2"])) + 1
    return max(0, min(a1, b1) - max(a0, b0))


def projected_reciprocal_edge(edge: dict, by_id: dict[str, dict]) -> dict:
    projected = projected_world_reciprocal_edge(edge, by_id)
    if reciprocal_projection_collapsed(edge, projected):
        return local_reciprocal_edge(edge, by_id)
    return projected


def reciprocal_projection_collapsed(edge: dict, reverse: dict) -> bool:
    if edge["direction"] in ("up", "down"):
        source_span = abs(int(edge["x2"]) - int(edge["x1"]))
        reverse_span = abs(int(reverse["x2"]) - int(reverse["x1"]))
    else:
        source_span = abs(int(edge["y2"]) - int(edge["y1"]))
        reverse_span = abs(int(reverse["y2"]) - int(reverse["y1"]))
    return source_span >= 4 and reverse_span < min(source_span, 4)


def projected_world_reciprocal_edge(edge: dict, by_id: dict[str, dict]) -> dict:
    source = by_id[edge["source"]]
    target = by_id[edge["target"]]
    opposite = OPPOSITE[edge["direction"]]
    if edge["direction"] == "up":
        x1 = clamp(source["worldX"] + int(edge["x1"]) - target["worldX"], 0, target["_width"] - 1)
        x2 = clamp(source["worldX"] + int(edge["x2"]) - target["worldX"], 0, target["_width"] - 1)
        y = target["_height"] - 1
        return city_exit_edge(edge["target"], opposite, edge["source"], x1, y, x2, y)
    if edge["direction"] == "down":
        x1 = clamp(source["worldX"] + int(edge["x1"]) - target["worldX"], 0, target["_width"] - 1)
        x2 = clamp(source["worldX"] + int(edge["x2"]) - target["worldX"], 0, target["_width"] - 1)
        return city_exit_edge(edge["target"], opposite, edge["source"], x1, 0, x2, 0)
    if edge["direction"] == "right":
        y1 = clamp(source["worldY"] + int(edge["y1"]) - target["worldY"], 0, target["_height"] - 1)
        y2 = clamp(source["worldY"] + int(edge["y2"]) - target["worldY"], 0, target["_height"] - 1)
        return city_exit_edge(edge["target"], opposite, edge["source"], 0, y1, 0, y2)
    if edge["direction"] == "left":
        y1 = clamp(source["worldY"] + int(edge["y1"]) - target["worldY"], 0, target["_height"] - 1)
        y2 = clamp(source["worldY"] + int(edge["y2"]) - target["worldY"], 0, target["_height"] - 1)
        x = target["_width"] - 1
        return city_exit_edge(edge["target"], opposite, edge["source"], x, y1, x, y2)
    raise ValueError(f"unknown edge direction: {edge['direction']}")


def local_reciprocal_edge(edge: dict, by_id: dict[str, dict]) -> dict:
    target = by_id[edge["target"]]
    opposite = OPPOSITE[edge["direction"]]
    if edge["direction"] == "up":
        x1 = clamp(int(edge["x1"]), 0, target["_width"] - 1)
        x2 = clamp(int(edge["x2"]), 0, target["_width"] - 1)
        y = target["_height"] - 1
        return city_exit_edge(edge["target"], opposite, edge["source"], x1, y, x2, y)
    if edge["direction"] == "down":
        x1 = clamp(int(edge["x1"]), 0, target["_width"] - 1)
        x2 = clamp(int(edge["x2"]), 0, target["_width"] - 1)
        return city_exit_edge(edge["target"], opposite, edge["source"], x1, 0, x2, 0)
    if edge["direction"] == "right":
        y1 = clamp(int(edge["y1"]), 0, target["_height"] - 1)
        y2 = clamp(int(edge["y2"]), 0, target["_height"] - 1)
        return city_exit_edge(edge["target"], opposite, edge["source"], 0, y1, 0, y2)
    if edge["direction"] == "left":
        y1 = clamp(int(edge["y1"]), 0, target["_height"] - 1)
        y2 = clamp(int(edge["y2"]), 0, target["_height"] - 1)
        x = target["_width"] - 1
        return city_exit_edge(edge["target"], opposite, edge["source"], x, y1, x, y2)
    raise ValueError(f"unknown edge direction: {edge['direction']}")


def assign_world_positions(rooms: list[dict], by_id: dict[str, dict], explicit_edges: list[dict]) -> None:
    if not rooms:
        return
    placement_edges = placement_adjacency(by_id, explicit_edges)
    start_id = "city_1" if "city_1" in by_id else rooms[0]["id"]
    placed = {start_id}
    queue = deque([start_id])
    by_id[start_id]["worldX"] = 0
    by_id[start_id]["worldY"] = 0

    while queue:
        source_id = queue.popleft()
        source = by_id[source_id]
        for edge in placement_edges.get(source_id, []):
            target_id = edge["target"]
            if target_id not in by_id or target_id in placed:
                continue
            target = by_id[target_id]
            if edge["direction"] == "right":
                target["worldX"] = source["worldX"] + source["_width"]
                target["worldY"] = source["worldY"] + edge["sourceAnchorY"] - edge["targetAnchorY"]
            elif edge["direction"] == "left":
                target["worldX"] = source["worldX"] - target["_width"]
                target["worldY"] = source["worldY"] + edge["sourceAnchorY"] - edge["targetAnchorY"]
            elif edge["direction"] == "up":
                target["worldX"] = source["worldX"] + edge["sourceAnchorX"] - edge["targetAnchorX"]
                target["worldY"] = source["worldY"] - target["_height"]
            elif edge["direction"] == "down":
                target["worldX"] = source["worldX"] + edge["sourceAnchorX"] - edge["targetAnchorX"]
                target["worldY"] = source["worldY"] + source["_height"]
            placed.add(target_id)
            queue.append(target_id)

    cursor_x = 0
    cursor_y = 512
    for room in rooms:
        if room["id"] in placed:
            continue
        room["worldX"] = cursor_x
        room["worldY"] = cursor_y
        cursor_x += room["_width"] + 32
        if cursor_x > 1600:
            cursor_x = 0
            cursor_y += 384


def load_city_layout(city_dir: Path, by_id: dict[str, dict]) -> dict[str, tuple[int, int]]:
    path = city_dir / "layout.json"
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}

    raw_rooms = data.get("rooms") or {}
    if not isinstance(raw_rooms, dict):
        return {}

    anchor_id = layout_room_id(str(data.get("anchorRoom") or "city_1"), by_id)
    map_entries: dict[str, tuple[int, int]] = {}
    world_entries: dict[str, tuple[int, int]] = {}
    for raw_id, raw in raw_rooms.items():
        room_id = layout_room_id(str(raw_id), by_id)
        if room_id is None or not isinstance(raw, dict):
            continue
        if "worldX" in raw and "worldY" in raw:
            world_entries[room_id] = (int(raw["worldX"]), int(raw["worldY"]))
            continue
        if "mapX" in raw and "mapY" in raw:
            map_entries[room_id] = (int(raw["mapX"]), int(raw["mapY"]))

    if map_entries:
        if anchor_id not in map_entries:
            anchor_id = sorted(map_entries.keys(), key=natural_key)[0]
        anchor_x, anchor_y = map_entries[anchor_id]
        for room_id, (map_x, map_y) in map_entries.items():
            world_entries[room_id] = (map_x - anchor_x, map_y - anchor_y)
    return world_entries


def layout_room_id(raw_id: str, by_id: dict[str, dict]) -> str | None:
    if raw_id in by_id:
        return raw_id
    candidate = f"city_{raw_id}" if not raw_id.startswith("city_") else raw_id
    return candidate if candidate in by_id else None


def apply_city_layout(by_id: dict[str, dict], layout: dict[str, tuple[int, int]]) -> None:
    for room_id, (world_x, world_y) in layout.items():
        room = by_id.get(room_id)
        if room is None:
            continue
        room["worldX"] = world_x
        room["worldY"] = world_y


def placement_adjacency(by_id: dict[str, dict], explicit_edges: list[dict]) -> dict[str, list[dict]]:
    out: dict[str, list[dict]] = {}
    for edge in explicit_edges:
        source = by_id.get(edge["source"])
        target = by_id.get(edge["target"])
        if source is None or target is None:
            continue
        forward = placement_edge(edge, source, target, explicit_edges)
        reverse = {
            "source": forward["target"],
            "target": forward["source"],
            "direction": OPPOSITE[forward["direction"]],
            "sourceAnchorX": forward["targetAnchorX"],
            "sourceAnchorY": forward["targetAnchorY"],
            "targetAnchorX": forward["sourceAnchorX"],
            "targetAnchorY": forward["sourceAnchorY"],
        }
        out.setdefault(forward["source"], []).append(forward)
        out.setdefault(reverse["source"], []).append(reverse)
    return out


def placement_edge(edge: dict, source: dict, target: dict, explicit_edges: list[dict]) -> dict:
    target_anchor = reciprocal_anchor(edge, explicit_edges)
    if target_anchor is None:
        target_anchor = default_target_anchor(edge, target)
    return {
        "source": edge["source"],
        "target": edge["target"],
        "direction": edge["direction"],
        "sourceAnchorX": clamp(int(edge["x"]), 0, source["_width"] - 1),
        "sourceAnchorY": clamp(int(edge["y"]), 0, source["_height"] - 1),
        "targetAnchorX": target_anchor[0],
        "targetAnchorY": target_anchor[1],
    }


def reciprocal_anchor(edge: dict, explicit_edges: list[dict]) -> tuple[int, int] | None:
    opposite = OPPOSITE[edge["direction"]]
    candidates = [
        candidate
        for candidate in explicit_edges
        if candidate["source"] == edge["target"] and candidate["target"] == edge["source"] and candidate["direction"] == opposite
    ]
    if not candidates:
        return None
    if edge["direction"] in ("left", "right"):
        candidate = min(candidates, key=lambda item: abs(int(item["y"]) - int(edge["y"])))
    else:
        candidate = min(candidates, key=lambda item: abs(int(item["x"]) - int(edge["x"])))
    return (int(candidate["x"]), int(candidate["y"]))


def default_target_anchor(edge: dict, target: dict) -> tuple[int, int]:
    source_x = int(edge["x"])
    source_y = int(edge["y"])
    if edge["direction"] == "right":
        return (0, clamp(source_y, 0, target["_height"] - 1))
    if edge["direction"] == "left":
        return (target["_width"] - 1, clamp(source_y, 0, target["_height"] - 1))
    if edge["direction"] == "up":
        return (clamp(source_x, 0, target["_width"] - 1), target["_height"] - 1)
    if edge["direction"] == "down":
        return (clamp(source_x, 0, target["_width"] - 1), 0)
    raise ValueError(f"unknown edge direction: {edge['direction']}")


def build_manifest(base_manifest: Path, city_dir: Path) -> dict:
    manifest = json.loads(base_manifest.read_text())
    base_dir = base_manifest.parent
    base_rooms = []
    for room in manifest["rooms"]:
        if str(room.get("id", "")).startswith("city_"):
            continue
        next_room = dict(room)
        next_room["image"] = str((base_dir / str(room["image"])).resolve())
        if "parallax" in next_room:
            parallax = dict(next_room["parallax"])
            parallax["image"] = str((base_dir / str(parallax["image"])).resolve())
            next_room["parallax"] = parallax
        base_rooms.append(next_room)
    manifest["rooms"] = base_rooms
    manifest["rooms"].extend(collect_city_rooms(city_dir))
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--city-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    manifest = build_manifest(args.base, args.city_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"generated {args.output} with {len(manifest['rooms'])} rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
