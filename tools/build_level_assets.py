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
    generated_root: Path,
    prefix: str,
    manifest: dict,
    room_names: list[str],
    room_sizes: list[dict],
) -> None:
    rooms = manifest["rooms"]
    indices = room_index_by_id(rooms)
    start = indices[str(manifest["start"])]

    lines: list[str] = [
        "const root = @import(\"root\");",
        "",
        "pub const start_room_index: usize = " + str(start) + ";",
        "",
    ]

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
        ]:
            lines.append(f"const {room_name}_{suffix} align(4) = @embedFile({zig_string(rel + '/' + filename)}).*;")
        if "parallax" in room:
            name = str(room["parallax"].get("name", "parallax_fg"))
            lines.append(f"const {room_name}_{name}_tiles align(4) = @embedFile({zig_string(rel + '/' + name + '_tiles.bin')}).*;")
            lines.append(f"const {room_name}_{name}_palette align(4) = @embedFile({zig_string(rel + '/' + name + '_palette.bin')}).*;")
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
                    f"            .palette = &{room_name}_{name}_palette,",
                    f"            .width = {int(parallax['width'])},",
                    f"            .height = {int(parallax['height'])},",
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

    emit_generated_zig(args.zig_output, args.generated_root, prefix, manifest, room_names, room_sizes)
    print(f"generated {args.zig_output} for {len(room_names)} rooms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
