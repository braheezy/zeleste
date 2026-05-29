#!/usr/bin/env python3
"""Build all rooms from a level manifest and generate a Zig room table."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from split_foreground_tileset import read_png_rgba


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


def cue_literal(cue: dict | None) -> str:
    cue = cue or {}
    return (
        ".{"
        f" .actor = {zig_string(str(cue.get('actor', 'granny')))},"
        f" .animation = {zig_string(str(cue.get('animation', '')))},"
        f" .mode = {zig_string(str(cue.get('mode', '')))},"
        " }"
    )


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


def build_room(manifest_dir: Path, generated_root: Path, prefix: str, room: dict, rgb_bits: int) -> tuple[str, dict]:
    room_name = zig_room_name(prefix, str(room["id"]))
    output_dir = generated_root / room_name
    image = manifest_dir / str(room["image"])
    command = [
        sys.executable,
        str(Path(__file__).with_name("build_room_bundle.py")),
        str(image),
        str(output_dir),
        "--rgb-bits",
        str(int(room.get("rgbBits", rgb_bits))),
    ]
    subprocess.run(command, check=True)

    if "parallax" in room:
        parallax = room["parallax"]
        subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("pack_parallax_obj.py")),
                "--input",
                str(manifest_dir / str(parallax["image"])),
                "--output-dir",
                str(output_dir),
                "--name",
                str(parallax.get("name", "parallax_fg")),
            ],
            check=True,
        )

    image_data = read_png_rgba(image)
    return room_name, {"width": image_data.width, "height": image_data.height}


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

    for room_name, room in zip(room_names, rooms):
        room_dir = generated_root / room_name
        rel = str(room_dir.relative_to(path.parent))
        for suffix, filename in [
            ("bg_tiles", "bg_tiles.bin"),
            ("bg_map", "bg_map.bin"),
            ("bg_palette", "bg_palette.bin"),
            ("spawn", "spawn.bin"),
            ("collision", "collision.bin"),
            ("falling_blocks", "falling_blocks.bin"),
            ("foreground_stamps", "foreground_stamps.bin"),
            ("generic_stamps", "generic_stamps.bin"),
            ("bird_npcs", "bird_npcs.bin"),
            ("wires", "wires.bin"),
            ("wire_tiles", "wire_tiles.bin"),
            ("bridge_ending", "bridge_ending.bin"),
        ]:
            lines.append(f"const {room_name}_{suffix} align(4) = @embedFile({zig_string(rel + '/' + filename)}).*;")
        if "parallax" in room:
            name = str(room["parallax"].get("name", "parallax_fg"))
            lines.append(f"const {room_name}_{name}_tiles align(4) = @embedFile({zig_string(rel + '/' + name + '_tiles.bin')}).*;")
            lines.append(f"const {room_name}_{name}_map align(4) = @embedFile({zig_string(rel + '/' + name + '_map.bin')}).*;")
            lines.append(f"const {room_name}_{name}_palette align(4) = @embedFile({zig_string(rel + '/' + name + '_palette.bin')}).*;")
        cutscene_path = cutscene_path_for_image(manifest_dir / str(room["image"]))
        if cutscene_path.exists():
            emit_granny_cutscene(lines, room_name, json.loads(cutscene_path.read_text()))
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
                f"        .falling_blocks = &{room_name}_falling_blocks,",
                f"        .foreground_stamps = &{room_name}_foreground_stamps,",
                f"        .generic_stamps = &{room_name}_generic_stamps,",
                f"        .bird_npcs = &{room_name}_bird_npcs,",
                f"        .wires = &{room_name}_wires,",
                f"        .wire_tiles = &{room_name}_wire_tiles,",
                f"        .bridge_ending = &{room_name}_bridge_ending,",
                f"        .granny_cutscene = {'&' + room_name + '_granny_cutscene' if cutscene_path_for_image(manifest_dir / str(room['image'])).exists() else 'null'},",
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--generated-root", type=Path, required=True)
    parser.add_argument("--zig-output", type=Path, required=True)
    parser.add_argument("--rgb-bits", type=int, default=4)
    parser.add_argument("--chapter-index", type=int, default=0)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    manifest_dir = args.manifest.parent
    prefix = str(manifest.get("outputPrefix", manifest["id"]))
    room_names: list[str] = []
    room_sizes: list[dict] = []
    for room in manifest["rooms"]:
        room_name, size = build_room(manifest_dir, args.generated_root, prefix, room, args.rgb_bits)
        room_names.append(room_name)
        room_sizes.append(size)

    emit_generated_zig(args.zig_output, manifest_dir, args.generated_root, prefix, manifest, room_names, room_sizes, args.chapter_index)
    print(f"generated {args.zig_output} for {len(room_names)} rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
