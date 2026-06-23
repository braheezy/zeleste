#!/usr/bin/env python3
"""Generate runtime Theo dialogue data from the Chapter 1 6zb cutscene JSON."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def zig_string(value: str) -> str:
    return json.dumps(value)


def zig_ident(value: str, fallback: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_]+", "_", value.strip().lower()).strip("_")
    if not value:
        value = fallback
    if value[0].isdigit():
        value = f"_{value}"
    return value


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
    portrait = str(page.get("portrait", page.get("face", ""))).strip().lower().replace("-", "_")
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
        raise ValueError(f"unknown Theo dialogue portrait {portrait!r}")
    return mapping[portrait]


def page_literal(page: dict) -> str:
    return (
        ".{"
        f" .speaker = {zig_string(str(page.get('speaker', '')))},"
        f" .text = {zig_string(str(page.get('text', '')))},"
        f" .portrait = {portrait_literal(page)},"
        " }"
    )


def dialogue_pages(cutscene: dict) -> list[dict]:
    pages = cutscene.get("dialogue") or []
    if not isinstance(pages, list):
        raise ValueError("dialogue must be a list")
    return pages


def post_conversations(cutscene: dict) -> list[dict]:
    conversations = cutscene.get("postConversations")
    if conversations is None:
        post_dialogue = cutscene.get("postDialogue") or []
        if post_dialogue:
            return [{"id": "post", "pages": post_dialogue}]
        return []
    if not isinstance(conversations, list):
        raise ValueError("postConversations must be a list")
    return conversations


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    cutscene = json.loads(args.input.read_text())
    markers = cutscene.get("markers") or {}
    actors = cutscene.get("actors") or []
    theo = next((actor for actor in actors if actor.get("id") == "npc" or actor.get("kind") == "theo"), {})

    conversation_sources = [{"id": "intro", "pages": dialogue_pages(cutscene)}] + post_conversations(cutscene)

    lines: list[str] = [
        "const root = @import(\"root\");",
        "",
        "pub const Conversation = struct {",
        "    pages: []const root.CutsceneDialoguePage,",
        "};",
        "",
        f"pub const dialogue_box = {rect_literal(markers.get('dialogue_box'))};",
        f"pub const theo_feet = {spawn_literal(theo)};",
        "",
    ]

    conversation_names: list[str] = []
    for index, conversation in enumerate(conversation_sources):
        name = f"{zig_ident(str(conversation.get('id', 'conversation')), f'conversation_{index}')}_pages"
        conversation_names.append(name)
        pages = conversation.get("pages") or []
        if not isinstance(pages, list):
            raise ValueError(f"{conversation.get('id', index)} pages must be a list")
        lines.append(f"const {name} = [_]root.CutsceneDialoguePage{{")
        for page in pages:
            lines.append(f"    {page_literal(page)},")
        lines.append("};")
        lines.append("")

    lines.append("pub const conversations = [_]Conversation{")
    for name in conversation_names:
        lines.append(f"    .{{ .pages = &{name} }},")
    lines.append("};")
    lines.append("")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines))
    print(f"generated Theo dialogue: {len(conversation_names)} conversations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
