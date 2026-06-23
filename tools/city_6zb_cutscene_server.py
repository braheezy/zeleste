#!/usr/bin/env python3
"""Serve the chapter 1 room 6zb NPC cutscene editor."""

from __future__ import annotations

import argparse
import json
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def dialogue_page(speaker: str, text: str) -> dict:
    portrait = "madeline_neutral" if speaker == "Madeline" else "theo_neutral"
    return {"speaker": speaker, "portrait": portrait, "text": text}


INTRO_DIALOGUE = [
    dialogue_page("Theo", "Ho there, fellow traveller!"),
    dialogue_page("Madeline", "Oh... hi."),
    dialogue_page("Theo", "What a killer night for a hike!"),
    dialogue_page("Madeline", "I guess so."),
    dialogue_page("Theo", "This place is so crazy.\nI kind of can't believe it exists!"),
    dialogue_page("Madeline", "Not the easiest climb, is it?\nBut I guess that's what I was looking for..."),
    dialogue_page(
        "Theo",
        "Whoa, that sounds pretty serious.\nI'm just happy to see another human in such a lonely place.\nI'm Theo by the way, an adventurer from a far off land!",
    ),
    dialogue_page("Madeline", "..."),
    dialogue_page(
        "Theo",
        "Not much of a talker, are you?\nMysterious lone wolf type, I get it. I'll just imagine some dark backstory for you.",
    ),
]


POST_CONVERSATIONS = [
    {
        "id": "second",
        "title": "Second",
        "pages": [
            dialogue_page("Madeline", "Hey, sorry. I'm Madeline.\nI've got a lot on my mind."),
            dialogue_page(
                "Theo",
                "Well, Madeline, I'd say you've come to the right place!\nI'm freezing my toes off, but I can't imagine a better place to be for some quiet reflection.",
            ),
            dialogue_page("Madeline", "Yeah, maybe you're right.\nWhat \"far off land\" do you hail from?"),
            dialogue_page(
                "Theo",
                "Well, my inquisitive compatriot, I doth hail from the mystical, exotic kingdom of...",
            ),
            dialogue_page("Theo", "Seattle."),
            dialogue_page("Madeline", "It sounds like a special place."),
        ],
    },
    {
        "id": "third",
        "title": "Third",
        "pages": [
            dialogue_page("Theo", "This place is wild!\nWhy would an entire city be abandoned?"),
            dialogue_page(
                "Madeline",
                "I read that some mega-corporation started building it, but then no one wanted to live here.\nI wonder why...",
            ),
            dialogue_page("Theo", "My money's on a government cover-up."),
            dialogue_page("Madeline", "What a waste, to build all of this for no reason..."),
            dialogue_page("Theo", "At least we get to enjoy the leftovers."),
        ],
    },
    {
        "id": "fourth",
        "title": "Fourth",
        "pages": [
            dialogue_page("Madeline", "Are you here to explore this city?"),
            dialogue_page("Theo", "Yeah, I have a thing for abandoned places.\nAnd I like to think of myself as a budding photographer."),
            dialogue_page("Madeline", "Oh really? Cool!\nDo you have a blog or something?"),
            dialogue_page("Theo", "A blog?\nMadeline.\nEveryone uses InstaPix now.\nI'm TheoUnderStars, look me up!"),
        ],
    },
    {
        "id": "fifth",
        "title": "Fifth",
        "pages": [
            dialogue_page("Theo", "This terrain is pretty tricky, are you turning back soon?"),
            dialogue_page("Madeline", "Nope. I'm heading for the summit."),
            dialogue_page("Theo", "I can really see the determination in your eyes!\nIt's inspiring."),
            dialogue_page("Madeline", "If you say so.\nI bet you could make it to the summit too."),
            dialogue_page(
                "Theo",
                "Maybe.\nI don't really care about reaching the top, TBH.\nOh! But I heard there are some legit old ruins up beyond the city.\nLike 1800's legit.\nI know it's risky but I have to see them for myself.",
            ),
        ],
    },
    {
        "id": "sixth",
        "title": "Sixth",
        "pages": [
            dialogue_page("Theo", "What's that thing you say right before you do something irresponsible?"),
            dialogue_page("Madeline", "Uh... \"throw caution to the wind?\""),
            dialogue_page("Theo", "No, that's not it.\nOh right..."),
            dialogue_page("Theo", "YOLOOOOOOOOO!!"),
        ],
    },
]


class City6zbCutsceneHandler(SimpleHTTPRequestHandler):
    repo_root: Path
    chapter: str
    room: str

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.repo_root), **kwargs)

    def do_GET(self) -> None:
        if self.path == "/api/city-6zb-cutscene":
            self.send_cutscene()
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/city-6zb-cutscene/save":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            data = request["data"]
            self.validate_cutscene(data)
            path = self.cutscene_path()
            path.write_text(json.dumps(data, indent=2) + "\n")
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return

        self.send_json(200, {"ok": True, "path": str(path.relative_to(self.repo_root))})

    def send_cutscene(self) -> None:
        try:
            path = self.cutscene_path()
            if path.exists():
                data = json.loads(path.read_text())
            else:
                data = self.default_cutscene()
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return

        image = self.image_path().relative_to(self.repo_root)
        self.send_json(
            200,
            {
                "ok": True,
                "image": str(image),
                "path": str(path.relative_to(self.repo_root)),
                "portraits": self.portrait_options(),
                "data": data,
            },
        )

    def default_cutscene(self) -> dict:
        image = self.image_path().relative_to(self.repo_root)
        width, height = self.room_dimensions()

        return {
            "version": 1,
            "id": "city_6zb_intro",
            "chapter": self.chapter,
            "room": self.room,
            "image": str(image),
            "triggers": [
                {"id": "left_approach", "x": 40, "y": max(0, height - 80), "w": 48, "h": 56},
                {"id": "right_approach", "x": max(0, width - 96), "y": max(0, height - 80), "w": 48, "h": 56},
            ],
            "actors": [
                {
                    "id": "npc",
                    "kind": "theo",
                    "x": min(width - 48, 184),
                    "y": min(height - 48, 128),
                    "facing": "left",
                    "sprite": "theo",
                }
            ],
            "markers": {
                "madeline_talk": {"x": min(width - 80, 152), "y": min(height - 48, 128)},
                "camera_focus": {"x": min(width - 80, 160), "y": min(height - 80, 96)},
                "dialogue_box": {"x": 8, "y": 8, "w": 224, "h": 56},
            },
            "dialogue": INTRO_DIALOGUE,
            "postConversations": POST_CONVERSATIONS,
            "postDialogue": [],
            "script": self.default_script(),
        }

    def room_dimensions(self) -> tuple[int, int]:
        annotations_path = self.image_path().with_name(f"{self.room}_annotations.json")
        if not annotations_path.exists():
            return (320, 184)
        annotations = json.loads(annotations_path.read_text())
        return (int(annotations.get("width", 320)), int(annotations.get("height", 184)))

    @staticmethod
    def default_script() -> list[dict]:
        return [
            {"op": "lock_player"},
            {"op": "walk_player_to", "marker": "madeline_talk"},
            {"op": "face", "actor": "player", "dir": "right"},
            {"op": "face", "actor": "npc", "dir": "left"},
            {"op": "camera_to", "marker": "camera_focus", "frames": 24},
            {"op": "say", "dialogue": 0},
            {"op": "say", "dialogue": 1},
            {"op": "set_flag", "flag": "city_6zb_intro_done"},
            {"op": "unlock_player"},
        ]

    def validate_cutscene(self, data: dict) -> None:
        if data.get("version") != 1:
            raise ValueError("unsupported cutscene version")
        if data.get("id") != "city_6zb_intro":
            raise ValueError("expected city_6zb_intro cutscene id")
        if data.get("room") != self.room:
            raise ValueError(f"expected room {self.room}")
        if not isinstance(data.get("triggers"), list) or not data["triggers"]:
            raise ValueError("triggers must be a non-empty list")
        if not isinstance(data.get("dialogue"), list):
            raise ValueError("dialogue must be a list")
        if "postDialogue" in data and not isinstance(data.get("postDialogue"), list):
            raise ValueError("postDialogue must be a list")
        if not isinstance(data.get("postConversations"), list):
            raise ValueError("postConversations must be a list")
        if not isinstance(data.get("script"), list):
            raise ValueError("script must be a list")

    def image_path(self) -> Path:
        return self.repo_root / "assets" / "chapters" / self.chapter / f"{self.room}.png"

    def cutscene_path(self) -> Path:
        return self.image_path().with_name(f"{self.room}_cutscene.json")

    def portrait_options(self) -> dict[str, list[dict[str, str]]]:
        return {
            "Madeline": self.portrait_options_for("madeline", "madeline"),
            "Theo": self.portrait_options_for("theo", "theo"),
        }

    def portrait_options_for(self, folder: str, prefix: str) -> list[dict[str, str]]:
        portrait_dir = self.repo_root / "assets" / "portraits" / folder
        if not portrait_dir.exists():
            return []
        preferred = {
            "madeline": ["idle", "angry", "sad", "upset"],
            "theo": ["normal", "excited", "serious", "thinking", "nailed-it", "yolo"],
        }.get(folder, [])

        def sort_key(path: Path) -> tuple[int, str]:
            try:
                return (preferred.index(path.stem), path.stem)
            except ValueError:
                return (len(preferred), path.stem)

        options = []
        for path in sorted(portrait_dir.glob("*.png"), key=sort_key):
            stem = path.stem.replace("-", "_")
            options.append({
                "label": stem.replace("_", " "),
                "value": f"{prefix}_{stem}",
            })
        return options

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8793)
    parser.add_argument("--chapter", default="1_city")
    parser.add_argument("--room", default="6zb")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    City6zbCutsceneHandler.repo_root = Path(__file__).resolve().parents[1]
    City6zbCutsceneHandler.chapter = args.chapter
    City6zbCutsceneHandler.room = args.room

    image_path = City6zbCutsceneHandler.repo_root / "assets" / "chapters" / args.chapter / f"{args.room}.png"
    if not image_path.exists():
        raise SystemExit(f"missing room image: {image_path}")

    server = ThreadingHTTPServer((args.host, args.port), City6zbCutsceneHandler)
    url = f"http://{args.host}:{args.port}/tools/city_6zb_cutscene_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
