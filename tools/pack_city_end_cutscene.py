#!/usr/bin/env python3
"""Generate runtime data for the Chapter 1 ending cutscene."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def zig_string(value: str) -> str:
    return json.dumps(value)


def rect_literal(rect: dict | None) -> str:
    rect = rect or {}
    return (
        "root.SceneRect{"
        f" .x = {int(rect.get('x', 0))},"
        f" .y = {int(rect.get('y', 0))},"
        f" .w = {int(rect.get('w', 0))},"
        f" .h = {int(rect.get('h', 0))},"
        " }"
    )


def spawn_literal(point: dict | None) -> str:
    point = point or {}
    return f"root.Spawn{{ .x = {int(point.get('x', 0))}, .y = {int(point.get('y', 0))} }}"


def portrait_literal(page: dict) -> str:
    portrait = str(page.get("portrait", "")).strip().lower().replace("-", "_")
    mapping = {
        "": ".none",
        "none": ".none",
        "madeline": ".madeline_idle",
        "madeline_neutral": ".madeline_idle",
        "madeline_idle": ".madeline_idle",
        "madeline_angry": ".madeline_angry",
        "madeline_sad": ".madeline_sad",
        "madeline_upset": ".madeline_upset",
        "distracted_short": ".madeline_distracted_short",
        "madeline_distracted_short": ".madeline_distracted_short",
        "deadpan_noblink": ".madeline_deadpan_noblink",
        "madeline_deadpan_noblink": ".madeline_deadpan_noblink",
        "theo": ".theo_normal",
        "theo_neutral": ".theo_normal",
        "theo_normal": ".theo_normal",
        "theo_excited": ".theo_excited",
        "theo_serious": ".theo_serious",
        "theo_thinking": ".theo_thinking",
        "theo_nailed_it": ".theo_nailed_it",
        "theo_yolo": ".theo_yolo",
    }
    if portrait not in mapping:
        raise ValueError(f"unknown city ending portrait {portrait!r}")
    return mapping[portrait]


def page_literal(page: dict) -> str:
    return (
        ".{"
        f" .speaker = {zig_string(str(page.get('speaker', '')))},"
        f" .text = {zig_string(str(page.get('text', '')))},"
        f" .portrait = {portrait_literal(page)},"
        " }"
    )


def timing_value(timings: dict, key: str, default: int) -> int:
    value = int(timings.get(key, default))
    if value < 0:
        raise ValueError(f"{key} must be non-negative")
    return value


def validate(cutscene: dict) -> None:
    if cutscene.get("version") != 1:
        raise ValueError("unsupported cutscene version")
    if cutscene.get("id") != "city_end_outro":
        raise ValueError("expected city_end_outro cutscene id")
    if cutscene.get("room") != "end":
        raise ValueError("expected room end")
    if not isinstance(cutscene.get("memorial"), dict):
        raise ValueError("memorial must be an object")
    if not isinstance(cutscene.get("outro"), dict):
        raise ValueError("outro must be an object")
    dialogue = cutscene["outro"].get("dialogue")
    if not isinstance(dialogue, list) or len(dialogue) < 2:
        raise ValueError("outro.dialogue must contain at least two pages")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    cutscene = json.loads(args.input.read_text())
    validate(cutscene)
    memorial = cutscene["memorial"]
    outro = cutscene["outro"]
    markers = outro.get("markers") or {}
    timings = outro.get("timings") or {}
    dialogue = outro.get("dialogue") or []

    lines: list[str] = [
        "const root = @import(\"root\");",
        "",
        "pub const Timings = struct {",
        "    pause_past_fire_frames: u8,",
        "    turn_back_frames: u8,",
        "    sit_down_frames: u8,",
        "    make_campfire_frames: u8,",
        "    fall_asleep_frames: u8,",
        "    bird_swoop_frames: u8,",
        "    bird_caw_frames: u8,",
        "    wipe_frames: u8,",
        "};",
        "",
        "pub const Memorial = struct {",
        "    trigger: root.SceneRect,",
        "    dialogue_box: root.SceneRect,",
        "    page: root.CutsceneDialoguePage,",
        "};",
        "",
        "pub const Outro = struct {",
        "    trigger: root.SceneRect,",
        "    dialogue_box: root.SceneRect,",
        "    madeline_rest: root.Spawn,",
        "    campfire: root.Spawn,",
        "    bird_start: root.Spawn,",
        "    bird_land: root.Spawn,",
        "    camera_focus: root.Spawn,",
        "    timings: Timings,",
        "    dialogue: []const root.CutsceneDialoguePage,",
        "};",
        "",
        "pub const memorial = Memorial{",
        f"    .trigger = {rect_literal(memorial.get('trigger'))},",
        f"    .dialogue_box = {rect_literal(memorial.get('dialogueBox'))},",
        f"    .page = {page_literal(memorial.get('page') or {})},",
        "};",
        "",
        "const outro_dialogue = [_]root.CutsceneDialoguePage{",
    ]
    for page in dialogue:
        lines.append(f"    {page_literal(page)},")
    lines += [
        "};",
        "",
        "pub const outro = Outro{",
        f"    .trigger = {rect_literal(outro.get('trigger'))},",
        f"    .dialogue_box = {rect_literal(markers.get('dialogue_box'))},",
        f"    .madeline_rest = {spawn_literal(markers.get('madeline_rest'))},",
        f"    .campfire = {spawn_literal(markers.get('campfire'))},",
        f"    .bird_start = {spawn_literal(markers.get('bird_start'))},",
        f"    .bird_land = {spawn_literal(markers.get('bird_land'))},",
        f"    .camera_focus = {spawn_literal(markers.get('camera_focus'))},",
        "    .timings = .{",
        f"        .pause_past_fire_frames = {timing_value(timings, 'pausePastFireFrames', 90)},",
        f"        .turn_back_frames = {timing_value(timings, 'turnBackFrames', 30)},",
        f"        .sit_down_frames = {timing_value(timings, 'sitDownFrames', 36)},",
        f"        .make_campfire_frames = {timing_value(timings, 'makeCampfireFrames', 90)},",
        f"        .fall_asleep_frames = {timing_value(timings, 'fallAsleepFrames', 60)},",
        f"        .bird_swoop_frames = {timing_value(timings, 'birdSwoopFrames', 90)},",
        f"        .bird_caw_frames = {timing_value(timings, 'birdCawFrames', 42)},",
        f"        .wipe_frames = {timing_value(timings, 'wipeFrames', 32)},",
        "    },",
        "    .dialogue = &outro_dialogue,",
        "};",
        "",
    ]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines))
    print(f"generated city ending cutscene: {len(dialogue)} dialogue pages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
