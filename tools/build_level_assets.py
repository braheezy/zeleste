#!/usr/bin/env python3
"""Build all rooms from a level manifest and generate a Zig room table."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from split_foreground_tileset import read_png_rgba


ROOM_CACHE_VERSION = 1
ROOM_BUNDLE_OUTPUTS = [
    "bg_tiles.bin",
    "bg_map.bin",
    "bg_palette.bin",
    "spawn.bin",
    "respawn_points.bin",
    "collision.bin",
    "falling_blocks.bin",
    "falling_block_tiles.bin",
    "falling_block_palette.bin",
    "breakable_walls.bin",
    "disappearing_platforms.bin",
    "mech_blocks.bin",
    "traffic_block_tiles.bin",
    "traffic_block_palette.bin",
    "rhythm_blocks.bin",
    "springs.bin",
    "strawberries.bin",
    "cassettes.bin",
    "dash_refills.bin",
    "hidden_covers.bin",
    "hidden_cover_tiles.bin",
    "hidden_cover_map.bin",
    "hidden_cover_groups.bin",
    "hidden_cover_palette.bin",
    "foreground_stamps.bin",
    "bridge_poles.bin",
    "generic_stamps.bin",
    "bird_npcs.bin",
    "wires.bin",
    "wire_tiles.bin",
    "bridge_ending.bin",
    "room.json",
]


def zig_room_name(prefix: str, room_id: str) -> str:
    safe = room_id.replace("-", "m").replace("+", "p")
    safe = "".join(ch if ch.isalnum() or ch == "_" else "_" for ch in safe)
    return f"{prefix}_{safe}"


def zig_string(value: str) -> str:
    return json.dumps(value)


def room_index_by_id(rooms: list[dict]) -> dict[str, int]:
    return {str(room["id"]): index for index, room in enumerate(rooms)}


def neighbor_literal(room: dict, key: str, indices: dict[str, int]) -> str:
    value = room.get(key)
    if value is None:
        return "null"
    return str(indices[str(value)])


def cutscene_path_for_image(image: Path) -> Path:
    return image.with_name(f"{image.stem}_cutscene.json")


def load_granny_cutscene_for_image(image: Path) -> dict | None:
    path = cutscene_path_for_image(image)
    if not path.exists():
        return None
    cutscene = json.loads(path.read_text())
    if cutscene.get("id") != "granny_intro":
        return None
    return cutscene


def point_literal(point: dict | None) -> str:
    point = point or {}
    return f".{{ .x = {int(point.get('x', 0))}, .y = {int(point.get('y', 0))} }}"


def rect_literal(rect: dict | None) -> str:
    rect = rect or {}
    return (
        ".{"
        f" .x = {int(rect.get('x', 0))},"
        f" .y = {int(rect.get('y', 0))},"
        f" .w = {int(rect.get('w', 0))},"
        f" .h = {int(rect.get('h', 0))},"
        " }"
    )


def annotation_path_for_image(image: Path) -> Path:
    return image.with_name(f"{image.stem}_annotations.json")


def hidden_cover_overlay_paths_for_image(image: Path) -> list[Path]:
    return [
        image.with_name(f"{image.stem}-overlay.png"),
        image.with_name(f"{image.stem}_overlay.png"),
        image.with_name(f"{image.stem}-hidden-cover.png"),
        image.with_name(f"{image.stem}_hidden_cover.png"),
    ]


def load_annotation(image: Path) -> dict:
    path = annotation_path_for_image(image)
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def scene_path_for_image(image: Path) -> Path:
    return image.with_name(f"{image.stem}_scene.json")


def update_hash(hasher: "hashlib._Hash", value: str) -> None:
    encoded = value.encode("utf-8", errors="surrogateescape")
    hasher.update(len(encoded).to_bytes(8, "little"))
    hasher.update(encoded)


def stable_path(path: Path | str) -> str:
    return os.path.abspath(os.fspath(path))


def stable_command_part(part: str) -> str:
    if "/" in part or "\\" in part:
        return stable_path(part)
    return part


def hash_file_contents(hasher: "hashlib._Hash", path: Path) -> None:
    with path.open("rb") as file:
        while True:
            chunk = file.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)


def hash_required_file(hasher: "hashlib._Hash", path: Path, label: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"room asset input missing for {label}: {path}")
    update_hash(hasher, f"file:{label}")
    update_hash(hasher, stable_path(path))
    hash_file_contents(hasher, path)


def hash_optional_file(hasher: "hashlib._Hash", path: Path, label: str) -> None:
    update_hash(hasher, f"optional-file:{label}")
    update_hash(hasher, stable_path(path))
    if path.is_file():
        update_hash(hasher, "present")
        hash_file_contents(hasher, path)
    else:
        update_hash(hasher, "missing")


def hash_optional_dir(hasher: "hashlib._Hash", path: Path, label: str) -> None:
    update_hash(hasher, f"optional-dir:{label}")
    update_hash(hasher, stable_path(path))
    if not path.is_dir():
        update_hash(hasher, "missing")
        return
    update_hash(hasher, "present")
    for file in sorted(item for item in path.rglob("*") if item.is_file()):
        relative = file.relative_to(path).as_posix()
        update_hash(hasher, relative)
        hash_file_contents(hasher, file)


def read_room_cache(path: Path) -> dict:
    if not path.is_file():
        return {"version": ROOM_CACHE_VERSION, "rooms": {}}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return {"version": ROOM_CACHE_VERSION, "rooms": {}}
    if data.get("version") != ROOM_CACHE_VERSION or not isinstance(data.get("rooms"), dict):
        return {"version": ROOM_CACHE_VERSION, "rooms": {}}
    return data


def write_room_cache(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)


def run_room_command(command: list[str]) -> str:
    completed = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            "room asset command failed with exit code "
            f"{completed.returncode}: {' '.join(command)}\n{completed.stdout}"
        )
    return completed.stdout


def print_room_log(log: str) -> None:
    if not log:
        return
    print(log, end="" if log.endswith("\n") else "\n")


def expected_room_outputs(room: dict, output_dir: Path) -> list[Path]:
    outputs = [output_dir / filename for filename in ROOM_BUNDLE_OUTPUTS]
    if "parallax" in room:
        name = str(room["parallax"].get("name", "parallax_fg"))
        outputs.extend(
            [
                output_dir / f"{name}_tiles.bin",
                output_dir / f"{name}_map.bin",
                output_dir / f"{name}_palette.bin",
            ]
        )
    return outputs


def room_outputs_exist(room: dict, output_dir: Path) -> bool:
    return all(path.is_file() for path in expected_room_outputs(room, output_dir))


def room_fingerprint(
    manifest_dir: Path,
    output_dir: Path,
    room: dict,
    command: list[str],
    rgb_bits: int,
) -> str:
    image = manifest_dir / str(room["image"])
    tools_dir = Path(__file__).resolve().parent
    repo_root = tools_dir.parent
    hasher = hashlib.sha256()
    update_hash(hasher, f"room-cache-v{ROOM_CACHE_VERSION}")
    update_hash(hasher, stable_path(output_dir))
    update_hash(hasher, json.dumps(room, sort_keys=True, separators=(",", ":")))
    update_hash(hasher, f"rgb-bits:{rgb_bits}")
    for part in command:
        update_hash(hasher, stable_command_part(part))
    hash_required_file(hasher, image, "background")
    hash_optional_file(hasher, annotation_path_for_image(image), "annotations")
    for overlay_path in hidden_cover_overlay_paths_for_image(image):
        hash_optional_file(hasher, overlay_path, f"hidden-cover-overlay:{overlay_path.name}")
    hash_optional_file(hasher, scene_path_for_image(image), "scene")
    for tool in [
        "build_room_bundle.py",
        "convert_room_tilemap_8bpp.py",
        "split_foreground_tileset.py",
    ]:
        hash_required_file(hasher, tools_dir / tool, tool)
    if "parallax" in room:
        parallax = room["parallax"]
        hash_required_file(hasher, manifest_dir / str(parallax["image"]), "parallax")
        hash_required_file(hasher, tools_dir / "pack_parallax_obj.py", "pack_parallax_obj.py")
    hash_optional_dir(hasher, repo_root / "assets" / "animations" / "conveyor_belt_platform", "conveyor_belt_platform")
    hash_optional_file(hasher, repo_root / "assets" / "source" / "prologue-bridge" / "whole-pole.png", "bridge_pole")
    return hasher.hexdigest()


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


def canonical_target_room_id(current_id: str, raw_target: str, fallback: str, indices: dict[str, int]) -> str | None:
    target = str(raw_target or "").strip()
    fallback = str(fallback or "").strip()
    local_current = current_id[5:] if current_id.startswith("city_") else current_id
    if (not target or target == current_id or target == local_current) and fallback and fallback != current_id and fallback != local_current:
        target = fallback
    if not target:
        return None
    if current_id.startswith("city_") and not target.startswith("city_"):
        candidates = [f"city_{target}", target]
    else:
        candidates = [target]
    for candidate in candidates:
        if candidate in indices:
            return candidate
    return None


def emit_room_lines(
    lines: list[str],
    room_name: str,
    room: dict,
    image: Path,
    size: dict,
    indices: dict[str, int],
) -> None:
    data = load_annotation(image)
    current_id = str(room["id"])
    fallback = str(data.get("exitTargetRoom") or "")
    width = int(data.get("width", size["width"]))
    height = int(data.get("height", size["height"]))
    source_exit_lines = room.get("exitLines")
    if source_exit_lines is None:
        source_exit_lines = data.get("exits") or data.get("exitLines") or []

    lines.append(f"const {room_name}_exit_lines = [_]root.ExitLine{{")
    for exit_line in source_exit_lines:
        target_id = canonical_target_room_id(current_id, str(exit_line.get("targetRoom") or ""), fallback, indices)
        if target_id is None:
            continue
        lines.append(
            "    .{"
            f" .direction = .{exit_direction(exit_line, width, height)},"
            f" .x1 = {int(exit_line.get('x1', 0))},"
            f" .y1 = {int(exit_line.get('y1', 0))},"
            f" .x2 = {int(exit_line.get('x2', exit_line.get('x1', 0)))},"
            f" .y2 = {int(exit_line.get('y2', exit_line.get('y1', 0)))},"
            f" .target = {indices[target_id]},"
            " },"
        )
    lines.append("};")

    lines.append(f"const {room_name}_death_lines = [_]root.DeathLine{{")
    for death_line in (data.get("pitDeathLines") or data.get("deathLines") or data.get("pitLines") or []):
        lines.append(
            "    .{"
            f" .x1 = {int(death_line.get('x1', death_line.get('startX', 0)))},"
            f" .y1 = {int(death_line.get('y1', death_line.get('startY', 0)))},"
            f" .x2 = {int(death_line.get('x2', death_line.get('endX', death_line.get('x1', 0))))},"
            f" .y2 = {int(death_line.get('y2', death_line.get('endY', death_line.get('y1', 0))))},"
            " },"
        )
    lines.append("};")
    lines.append("")


def cue_literal(cue: dict | None) -> str:
    cue = cue or {}
    return (
        ".{"
        f" .actor = {zig_string(str(cue.get('actor', 'granny')))},"
        f" .animation = {zig_string(str(cue.get('animation', '')))},"
        f" .mode = {zig_string(str(cue.get('mode', '')))},"
        " }"
    )


def portrait_literal(page: dict) -> str:
    portrait = str(page.get("portrait", page.get("face", ""))).strip().lower().replace("-", "_")
    mapping = {
        "": ".none",
        "none": ".none",
        "madeline": ".madeline_idle",
        "madeline_idle": ".madeline_idle",
        "madeline_neutral": ".madeline_idle",
        "madeline_angry": ".madeline_angry",
        "angry": ".madeline_angry",
        "madeline_sad": ".madeline_sad",
        "sad": ".madeline_sad",
        "madeline_upset": ".madeline_upset",
        "upset": ".madeline_upset",
        "normal": ".granny_normal",
        "granny_normal": ".granny_normal",
        "mock": ".granny_mock",
        "granny_mock": ".granny_mock",
        "laugh": ".granny_laugh",
        "granny_laugh": ".granny_laugh",
        "creepa": ".granny_creep_a",
        "creep_a": ".granny_creep_a",
        "granny_creep_a": ".granny_creep_a",
        "creepb": ".granny_creep_b",
        "creep_b": ".granny_creep_b",
        "granny_creep_b": ".granny_creep_b",
    }
    if portrait not in mapping:
        raise ValueError(f"unknown dialogue portrait {portrait!r}")
    return mapping[portrait]


def emit_granny_cutscene(lines: list[str], room_name: str, cutscene: dict) -> None:
    dialogue = cutscene.get("dialogue") or []
    markers = cutscene.get("markers") or {}
    actors = cutscene.get("actors") or []
    granny = next((actor for actor in actors if actor.get("id") == "granny"), {})
    laugh = cutscene.get("laugh") or {}

    lines.append(f"const {room_name}_granny_dialogue = [_]root.CutsceneDialoguePage{{")
    for page in dialogue:
        lines.append(
            "    .{"
            f" .speaker = {zig_string(str(page.get('speaker', '')))},"
            f" .text = {zig_string(str(page.get('text', '')))},"
            f" .portrait = {portrait_literal(page)},"
            f" .cue = {cue_literal(page.get('cue'))},"
            f" .after_cue = {cue_literal(page.get('afterCue'))},"
            " },"
        )
    lines.append("};")
    lines.append("")

    lines.append(f"const {room_name}_granny_cutscene = root.GrannyCutscene{{")
    lines.append(f"    .trigger = {rect_literal(cutscene.get('trigger'))},")
    lines.append(f"    .granny = {point_literal(granny)},")
    lines.append(f"    .granny_facing_left = {str(str(granny.get('facing', 'left')) != 'right').lower()},")
    lines.append(f"    .madeline_talk = {point_literal(markers.get('madeline_talk'))},")
    lines.append(f"    .madeline_edge = {point_literal(markers.get('madeline_edge'))},")
    lines.append(f"    .dialogue_box = {rect_literal(markers.get('dialogue_box'))},")
    lines.append(f"    .laugh_start = {point_literal(markers.get('laugh_start'))},")
    lines.append(f"    .laugh_end = {point_literal(markers.get('laugh_end'))},")
    lines.append(f"    .laugh_text = {zig_string(str(laugh.get('text', 'ha ha ha')))},")
    lines.append(f"    .laugh_speed_px = {int(float(laugh.get('speedPxPerFrame', 1)))},")
    lines.append(f"    .laugh_spawn_every_frames = {int(laugh.get('spawnEveryFrames', 28))},")
    lines.append(f"    .dialogue = &{room_name}_granny_dialogue,")
    lines.append("};")
    lines.append("")


def build_room(
    manifest_dir: Path,
    generated_root: Path,
    prefix: str,
    room: dict,
    rgb_bits: int,
    cached_rooms: dict,
) -> tuple[str, dict, dict, str]:
    room_name = zig_room_name(prefix, str(room["id"]))
    output_dir = generated_root / room_name
    image = manifest_dir / str(room["image"])
    effective_rgb_bits = int(room.get("rgbBits", rgb_bits))
    log = ""
    command = [
        sys.executable,
        str(Path(__file__).with_name("build_room_bundle.py")),
        str(image),
        str(output_dir),
        "--rgb-bits",
        str(effective_rgb_bits),
    ]
    digest = room_fingerprint(manifest_dir, output_dir, room, command, effective_rgb_bits)
    cached_room = cached_rooms.get(room_name)
    cache_hit = (
        os.environ.get("ASSET_FORCE") != "1"
        and isinstance(cached_room, dict)
        and cached_room.get("fingerprint") == digest
        and room_outputs_exist(room, output_dir)
    )
    if not cache_hit:
        log += run_room_command(command)

        if "parallax" in room:
            parallax = room["parallax"]
            log += run_room_command(
                [
                    sys.executable,
                    str(Path(__file__).with_name("pack_parallax_obj.py")),
                    "--input",
                    str(manifest_dir / str(parallax["image"])),
                    "--output-dir",
                    str(output_dir),
                    "--name",
                    str(parallax.get("name", "parallax_fg")),
                ]
            )
        if not room_outputs_exist(room, output_dir):
            missing = [str(path) for path in expected_room_outputs(room, output_dir) if not path.is_file()]
            raise RuntimeError(f"room bundle {room_name} did not produce expected outputs: {', '.join(missing)}")
    cache_entry = {
        "fingerprint": digest,
        "outputs": [path.name for path in expected_room_outputs(room, output_dir)],
    }

    image_data = read_png_rgba(image)
    return room_name, {"width": image_data.width, "height": image_data.height}, cache_entry, log


def emit_generated_zig(
    path: Path,
    manifest_dir: Path,
    generated_root: Path,
    prefix: str,
    manifest: dict,
    room_names: list[str],
    room_sizes: list[dict],
    chapter_index: int,
) -> None:
    rooms = manifest["rooms"]
    indices = room_index_by_id(rooms)
    start = indices[str(manifest["start"])]

    lines: list[str] = [
        "const root = @import(\"root\");",
        "",
        "pub const chapter_index: i32 = " + str(chapter_index) + ";",
        "pub const start_room_index: usize = " + str(start) + ";",
        "",
    ]

    lines.append("pub const room_ids = [_][]const u8{")
    for room in rooms:
        lines.append(f"    {zig_string(str(room['id']))},")
    lines.append("};")
    lines.append("")
    lines.extend(
        [
            "fn bytesEqual(a: []const u8, b: []const u8) bool {",
            "    if (a.len != b.len) return false;",
            "    for (a, 0..) |value, index| {",
            "        if (value != b[index]) return false;",
            "    }",
            "    return true;",
            "}",
            "",
            "pub fn roomIndexFor(chapter: i32, room_id: []const u8) ?usize {",
            "    if (chapter != chapter_index) return null;",
            "    for (room_ids, 0..) |candidate, index| {",
            "        if (bytesEqual(candidate, room_id)) return index;",
            "    }",
            "    return null;",
            "}",
            "",
        ]
    )

    for room_name, room, size in zip(room_names, rooms, room_sizes):
        room_dir = generated_root / room_name
        rel = str(room_dir.relative_to(path.parent))
        for suffix, filename in [
            ("bg_tiles", "bg_tiles.bin"),
            ("bg_map", "bg_map.bin"),
            ("bg_palette", "bg_palette.bin"),
            ("spawn", "spawn.bin"),
            ("respawn_points", "respawn_points.bin"),
            ("collision", "collision.bin"),
            ("falling_blocks", "falling_blocks.bin"),
            ("falling_block_tiles", "falling_block_tiles.bin"),
            ("falling_block_palette", "falling_block_palette.bin"),
            ("breakable_walls", "breakable_walls.bin"),
            ("disappearing_platforms", "disappearing_platforms.bin"),
            ("mech_blocks", "mech_blocks.bin"),
            ("traffic_block_tiles", "traffic_block_tiles.bin"),
            ("traffic_block_palette", "traffic_block_palette.bin"),
            ("rhythm_blocks", "rhythm_blocks.bin"),
            ("springs", "springs.bin"),
            ("strawberries", "strawberries.bin"),
            ("cassettes", "cassettes.bin"),
            ("dash_refills", "dash_refills.bin"),
            ("hidden_covers", "hidden_covers.bin"),
            ("hidden_cover_tiles", "hidden_cover_tiles.bin"),
            ("hidden_cover_map", "hidden_cover_map.bin"),
            ("hidden_cover_groups", "hidden_cover_groups.bin"),
            ("hidden_cover_palette", "hidden_cover_palette.bin"),
            ("foreground_stamps", "foreground_stamps.bin"),
            ("generic_stamps", "generic_stamps.bin"),
            ("bird_npcs", "bird_npcs.bin"),
            ("wires", "wires.bin"),
            ("wire_tiles", "wire_tiles.bin"),
            ("bridge_ending", "bridge_ending.bin"),
        ]:
            lines.append(f"const {room_name}_{suffix} align(4) = @embedFile({zig_string(rel + '/' + filename)}).*;")
        emit_room_lines(lines, room_name, room, manifest_dir / str(room["image"]), size, indices)
        if "parallax" in room:
            name = str(room["parallax"].get("name", "parallax_fg"))
            lines.append(f"const {room_name}_{name}_tiles align(4) = @embedFile({zig_string(rel + '/' + name + '_tiles.bin')}).*;")
            lines.append(f"const {room_name}_{name}_map align(4) = @embedFile({zig_string(rel + '/' + name + '_map.bin')}).*;")
            lines.append(f"const {room_name}_{name}_palette align(4) = @embedFile({zig_string(rel + '/' + name + '_palette.bin')}).*;")
        granny_cutscene = load_granny_cutscene_for_image(manifest_dir / str(room["image"]))
        if granny_cutscene is not None:
            emit_granny_cutscene(lines, room_name, granny_cutscene)
        lines.append("")

    lines.append("pub const rooms = [_]root.RoomBackground{")
    for room_name, room, size in zip(room_names, rooms, room_sizes):
        width = int(size["width"])
        height = int(size["height"])
        lines.extend(
            [
                "    .{",
                f"        .width_tiles = {((width + 7) // 8)},",
                f"        .height_tiles = {((height + 7) // 8)},",
                f"        .width_pixels = {width},",
                f"        .height_pixels = {height},",
                f"        .world_x = {int(room.get('worldX', 0))},",
                f"        .world_y = {int(room.get('worldY', 0))},",
                f"        .tiles = &{room_name}_bg_tiles,",
                f"        .map = &{room_name}_bg_map,",
                f"        .palette = &{room_name}_bg_palette,",
                f"        .collision = &{room_name}_collision,",
                f"        .spawn = root.spawnFromBytes(&{room_name}_spawn),",
                f"        .spawn_left = root.spawnFromBytesAt(&{room_name}_spawn, 4),",
                f"        .spawn_right = root.spawnFromBytesAt(&{room_name}_spawn, 8),",
                f"        .spawn_top = root.spawnFromBytesAt(&{room_name}_spawn, 12),",
                f"        .spawn_bottom = root.spawnFromBytesAt(&{room_name}_spawn, 16),",
                f"        .respawn_points = &{room_name}_respawn_points,",
                f"        .falling_blocks = &{room_name}_falling_blocks,",
                f"        .falling_block_tiles = &{room_name}_falling_block_tiles,",
                f"        .falling_block_palette = &{room_name}_falling_block_palette,",
                f"        .breakable_walls = &{room_name}_breakable_walls,",
                f"        .disappearing_platforms = &{room_name}_disappearing_platforms,",
                f"        .mech_blocks = &{room_name}_mech_blocks,",
                f"        .traffic_block_tiles = &{room_name}_traffic_block_tiles,",
                f"        .traffic_block_palette = &{room_name}_traffic_block_palette,",
                f"        .rhythm_blocks = &{room_name}_rhythm_blocks,",
                f"        .springs = &{room_name}_springs,",
                f"        .strawberries = &{room_name}_strawberries,",
                f"        .cassettes = &{room_name}_cassettes,",
                f"        .dash_refills = &{room_name}_dash_refills,",
                f"        .hidden_covers = &{room_name}_hidden_covers,",
                f"        .hidden_cover_tiles = &{room_name}_hidden_cover_tiles,",
                f"        .hidden_cover_map = &{room_name}_hidden_cover_map,",
                f"        .hidden_cover_groups = &{room_name}_hidden_cover_groups,",
                f"        .hidden_cover_palette = &{room_name}_hidden_cover_palette,",
                f"        .foreground_stamps = &{room_name}_foreground_stamps,",
                f"        .generic_stamps = &{room_name}_generic_stamps,",
                f"        .bird_npcs = &{room_name}_bird_npcs,",
                f"        .wires = &{room_name}_wires,",
                f"        .wire_tiles = &{room_name}_wire_tiles,",
                f"        .bridge_ending = &{room_name}_bridge_ending,",
                f"        .exit_lines = &{room_name}_exit_lines,",
                f"        .death_lines = &{room_name}_death_lines,",
                f"        .granny_cutscene = {'&' + room_name + '_granny_cutscene' if load_granny_cutscene_for_image(manifest_dir / str(room['image'])) is not None else 'null'},",
                f"        .wind_snow_strength = {int(room.get('windSnowStrength', 0))},",
                f"        .wind_snow_dir_x = {int(room.get('windSnowDirX', -1))},",
                f"        .left = {neighbor_literal(room, 'left', indices)},",
                f"        .right = {neighbor_literal(room, 'right', indices)},",
                f"        .up = {neighbor_literal(room, 'up', indices)},",
                f"        .down = {neighbor_literal(room, 'down', indices)},",
            ]
        )
        if "parallax" in room:
            parallax = room["parallax"]
            name = str(parallax.get("name", "parallax_fg"))
            lines.extend(
                [
                    "        .parallax = .{",
                    f"            .tiles = &{room_name}_{name}_tiles,",
                    f"            .map = &{room_name}_{name}_map,",
                    f"            .palette = &{room_name}_{name}_palette,",
                    f"            .width = {int(parallax['width'])},",
                    f"            .height = {int(parallax['height'])},",
                    f"            .width_tiles = {((int(parallax['width']) + 7) // 8)},",
                    f"            .height_tiles = {((int(parallax['height']) + 7) // 8)},",
                    f"            .world_x = {int(parallax.get('worldX', 0))},",
                    f"            .world_y = {int(parallax.get('worldY', 0))},",
                    f"            .chunk_count = {int(parallax.get('chunkCount', 0))},",
                    f"            .scroll_extra_x_divisor = {int(parallax.get('scrollExtraXDivisor', 0))},",
                    f"            .scroll_extra_y_divisor = {int(parallax.get('scrollExtraYDivisor', 0))},",
                    "        },",
                ]
            )
        lines.extend(["    },"])
    lines.append("};")
    lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines))


def parse_jobs(value: str, source: str) -> int:
    try:
        jobs = int(value)
    except ValueError as err:
        raise ValueError(f"{source} must be an integer, got {value!r}") from err
    if jobs < 1:
        raise ValueError(f"{source} must be at least 1, got {jobs}")
    return jobs


def resolve_jobs(requested_jobs: int | None, room_count: int) -> int:
    if room_count <= 1:
        return 1
    if requested_jobs is not None:
        return min(requested_jobs, room_count)
    env_jobs = os.environ.get("ASSET_JOBS")
    if env_jobs:
        return min(parse_jobs(env_jobs, "ASSET_JOBS"), room_count)
    return max(1, min(os.cpu_count() or 1, room_count))


def build_rooms(
    manifest_dir: Path,
    generated_root: Path,
    prefix: str,
    rooms: list[dict],
    rgb_bits: int,
    room_cache: dict,
    jobs: int,
) -> tuple[list[str], list[dict]]:
    cached_rooms = room_cache["rooms"]
    results: list[tuple[str, dict, dict, str] | None] = [None] * len(rooms)

    if jobs == 1:
        for index, room in enumerate(rooms):
            result = build_room(manifest_dir, generated_root, prefix, room, rgb_bits, cached_rooms)
            print_room_log(result[3])
            results[index] = result
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
            futures = {
                executor.submit(build_room, manifest_dir, generated_root, prefix, room, rgb_bits, cached_rooms): index
                for index, room in enumerate(rooms)
            }
            for future in concurrent.futures.as_completed(futures):
                index = futures[future]
                result = future.result()
                print_room_log(result[3])
                results[index] = result

    room_names: list[str] = []
    room_sizes: list[dict] = []
    for result in results:
        if result is None:
            raise RuntimeError("internal error: missing room build result")
        room_name, size, cache_entry, _log = result
        room_cache["rooms"][room_name] = cache_entry
        room_names.append(room_name)
        room_sizes.append(size)
    return room_names, room_sizes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--generated-root", type=Path, required=True)
    parser.add_argument("--zig-output", type=Path, required=True)
    parser.add_argument("--rgb-bits", type=int, default=4)
    parser.add_argument("--chapter-index", type=int, default=0)
    parser.add_argument(
        "--jobs",
        type=int,
        default=None,
        help="room bundle jobs to run in parallel; defaults to ASSET_JOBS or CPU count",
    )
    args = parser.parse_args()
    if args.jobs is not None and args.jobs < 1:
        parser.error("--jobs must be at least 1")

    manifest = json.loads(args.manifest.read_text())
    manifest_dir = args.manifest.parent
    prefix = str(manifest.get("outputPrefix", manifest["id"]))
    room_cache_path = args.generated_root / ".room_bundle_cache.json"
    room_cache = read_room_cache(room_cache_path)
    try:
        jobs = resolve_jobs(args.jobs, len(manifest["rooms"]))
    except ValueError as err:
        parser.error(str(err))
    room_names, room_sizes = build_rooms(
        manifest_dir,
        args.generated_root,
        prefix,
        manifest["rooms"],
        args.rgb_bits,
        room_cache,
        jobs,
    )

    emit_generated_zig(args.zig_output, manifest_dir, args.generated_root, prefix, manifest, room_names, room_sizes, args.chapter_index)
    write_room_cache(room_cache_path, room_cache)
    print(f"generated {args.zig_output} for {len(room_names)} rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
