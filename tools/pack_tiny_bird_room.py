#!/usr/bin/env python3
"""Generate runtime tiny-bird room data from a room annotation JSON."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


VARIANT_ALIASES = {
    "cyan": "cyan",
    "red": "red",
    "pink": "red",
    "blue": "blue",
    "green": "green",
    "gold": "gold",
    "yellow": "gold",
}
PUZZLE_COLOR_ALIASES = {
    "white": "white",
    "purple": "purple",
    "blue": "blue",
    "red": "red",
    "pink": "red",
    "yellow": "yellow",
    "gold": "yellow",
}
MAX_AMBIENT_BIRDS = 8
MAX_PUZZLE_BIRDS = 6

DEFAULT_VELOCITIES: dict[str, tuple[int, int]] = {
    "up": (0x00, -0x150),
    "up-left": (-0x70, -0x130),
    "up-right": (0x70, -0x130),
    "left": (-0x100, -0x80),
    "right": (0x100, -0x80),
    "down-left": (-0x80, 0x60),
    "down": (0x00, 0x80),
    "down-right": (0x80, 0x60),
}

PUZZLE_SPOKES: dict[str, tuple[int, int]] = {
    "up": (0, -34),
    "up-left": (-30, -30),
    "up-right": (30, -30),
    "left": (-38, 0),
    "right": (38, 0),
    "down-left": (-30, 30),
    "down": (0, 34),
    "down-right": (30, 30),
}

PUZZLE_CLUSTER_SEQUENCE: tuple[tuple[str, int, int, int], ...] = (
    ("white", 0, -42, 0),
    ("purple", -48, 0, 11),
    ("blue", 40, 40, 22),
    ("red", 40, -40, 33),
    ("yellow", -40, -40, 44),
)


def zig_ident(value: str, fallback: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_]+", "_", value.strip().lower()).strip("_")
    if not value:
        value = fallback
    if value[0].isdigit():
        value = f"_{value}"
    return value


def bird_velocity(bird: dict) -> tuple[int, int]:
    if "vx" in bird or "vy" in bird:
        return (int(bird.get("vx", 0)), int(bird.get("vy", 0)))
    direction = str(bird.get("direction", "up")).strip().lower()
    if direction not in DEFAULT_VELOCITIES:
        raise ValueError(f"unknown bird direction {direction!r}")
    return DEFAULT_VELOCITIES[direction]


def runtime_variant(value: object) -> str:
    variant = str(value).strip().lower()
    if variant not in VARIANT_ALIASES:
        raise ValueError(f"unsupported bird variant {variant!r}")
    return VARIANT_ALIASES[variant]


def puzzle_color(value: object) -> str:
    color = str(value).strip().lower()
    if color not in PUZZLE_COLOR_ALIASES:
        raise ValueError(f"unsupported puzzle bird color {color!r}")
    return PUZZLE_COLOR_ALIASES[color]


def puzzle_spoke(bird: dict) -> tuple[int, int]:
    if "dx" in bird or "dy" in bird:
        return (int(bird.get("dx", 0)), int(bird.get("dy", 0)))
    direction = str(bird.get("direction", "up")).strip().lower()
    if direction not in PUZZLE_SPOKES:
        raise ValueError(f"unknown puzzle bird direction {direction!r}")
    return PUZZLE_SPOKES[direction]


def birds_with_role(data: dict, role: str) -> list[dict]:
    birds = data.get("birds")
    if not isinstance(birds, list):
        raise ValueError("birds must be a list")
    return [
        bird
        for bird in birds
        if isinstance(bird, dict)
        and bird.get("enabled", True)
        and str(bird.get("role", "ambient")).strip().lower() == role
    ]


def ambient_birds(data: dict) -> list[dict]:
    return birds_with_role(data, "ambient")


def puzzle_birds(data: dict) -> list[dict]:
    return birds_with_role(data, "puzzle")


def puzzle_cluster(data: dict):
    cluster = data.get("puzzleCluster")
    if cluster is None:
        cluster = data.get("puzzle_cluster")
    if cluster is None:
        return None
    if not isinstance(cluster, dict):
        raise ValueError("puzzleCluster must be an object")
    if cluster.get("enabled", True) is False:
        return None
    return {
        "x": int(cluster.get("x", 0)),
        "y": int(cluster.get("y", 0)),
    }


def puzzle_antenna_tip(data: dict):
    tip = data.get("puzzleAntennaTip")
    if tip is None:
        tip = data.get("puzzle_antenna_tip")
    if tip is None:
        return None
    if not isinstance(tip, dict):
        raise ValueError("puzzleAntennaTip must be an object")
    if tip.get("enabled", True) is False:
        return None
    return {
        "x": int(tip.get("x", 0)),
        "y": int(tip.get("y", 0)),
    }


def puzzle_birds_from_cluster(cluster: dict) -> list[dict]:
    x = int(cluster["x"])
    y = int(cluster["y"])
    return [
        {
            "x": x,
            "y": y,
            "variant": color,
            "dx": dx,
            "dy": dy,
            "phase": phase,
        }
        for color, dx, dy, phase in PUZZLE_CLUSTER_SEQUENCE
    ]


def validate_bird(bird: dict, index: int) -> None:
    try:
        runtime_variant(bird.get("variant", ""))
    except ValueError as exc:
        raise ValueError(f"ambient bird {index} has {exc}") from exc
    group = int(bird.get("group", 0))
    if group < 0 or group > 15:
        raise ValueError(f"ambient bird {index} group must be 0..15")


def validate_puzzle_bird(bird: dict, index: int) -> None:
    try:
        puzzle_color(bird.get("variant", bird.get("color", "")))
        puzzle_spoke(bird)
    except ValueError as exc:
        raise ValueError(f"puzzle bird {index} has {exc}") from exc


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    data = json.loads(args.input.read_text())
    if data.get("version") != 1:
        raise ValueError("unsupported tiny-bird annotation version")

    birds = ambient_birds(data)
    cluster = puzzle_cluster(data)
    antenna_tip = puzzle_antenna_tip(data)
    puzzle = puzzle_birds(data)
    if cluster is not None:
        puzzle.extend(puzzle_birds_from_cluster(cluster))
    if len(birds) > MAX_AMBIENT_BIRDS:
        raise ValueError(f"too many ambient tiny birds: {len(birds)} > {MAX_AMBIENT_BIRDS}")
    if len(puzzle) > MAX_PUZZLE_BIRDS:
        raise ValueError(f"too many puzzle tiny birds: {len(puzzle)} > {MAX_PUZZLE_BIRDS}")

    const_name = zig_ident(str(data.get("id", "tiny_birds")), "tiny_birds")
    puzzle_const_name = f"{const_name}_puzzle"
    lines = [
        "const tiny_birds = @import(\"../../../room/tiny_birds.zig\");",
        "",
        f"pub const source_bird_count: usize = {len(data.get('birds', []))};",
        f"pub const ambient_bird_count: usize = {len(birds)};",
        f"pub const puzzle_bird_count: usize = {len(puzzle)};",
        "",
        f"pub const {const_name} = [_]tiny_birds.Start{{",
    ]

    for index, bird in enumerate(birds):
        validate_bird(bird, index)
        vx, vy = bird_velocity(bird)
        variant = runtime_variant(bird.get("variant", ""))
        lines.append(
            "    .{"
            f" .x = {int(bird.get('x', 0))},"
            f" .y = {int(bird.get('y', 0))},"
            f" .variant = .{variant},"
            f" .group = {int(bird.get('group', 0))},"
            f" .vx = {vx},"
            f" .vy = {vy},"
            f" .phase = {int(bird.get('phase', index * 7)) & 0xff},"
            " },"
        )

    lines.extend(["};", ""])

    lines.append(f"pub const {puzzle_const_name} = [_]tiny_birds.PuzzleStart{{")
    for index, bird in enumerate(puzzle):
        validate_puzzle_bird(bird, index)
        color = puzzle_color(bird.get("variant", bird.get("color", "")))
        dx, dy = puzzle_spoke(bird)
        lines.append(
            "    .{"
            f" .x = {int(bird.get('x', 0))},"
            f" .y = {int(bird.get('y', 0))},"
            f" .color = .{color},"
            f" .dx = {dx},"
            f" .dy = {dy},"
            f" .phase = {int(bird.get('phase', index * 11)) & 0xff},"
            " },"
        )

    lines.extend(["};", ""])

    if antenna_tip is None:
        lines.append("pub const antenna_tip: ?tiny_birds.AntennaTipStart = null;")
    else:
        lines.append(
            "pub const antenna_tip: ?tiny_birds.AntennaTipStart = .{"
            f" .x = {antenna_tip['x']},"
            f" .y = {antenna_tip['y']},"
            " };"
        )

    lines.extend(
        [
            "",
            f"pub const starts: []const tiny_birds.Start = &{const_name};",
            f"pub const puzzle_starts: []const tiny_birds.PuzzleStart = &{puzzle_const_name};",
            "",
        ]
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines))
    tip_status = "antenna tip" if antenna_tip is not None else "no antenna tip"
    print(f"generated tiny birds: {len(birds)} ambient, {len(puzzle)} puzzle, {tip_status} from {len(data.get('birds', []))} annotated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
