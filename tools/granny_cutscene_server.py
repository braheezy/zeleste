#!/usr/bin/env python3
"""Serve the room-2 Granny cutscene editor."""

from __future__ import annotations

import argparse
import json
import struct
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GrannyCutsceneHandler(SimpleHTTPRequestHandler):
    repo_root: Path
    chapter: str
    room: str

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.repo_root), **kwargs)

    def do_GET(self) -> None:
        if self.path == "/api/granny-cutscene":
            self.send_cutscene()
            return
        if self.path == "/api/granny-cutscene/animations":
            self.send_json(200, {"ok": True, "animations": self.animation_assets()})
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/granny-cutscene/save":
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
                "data": data,
            },
        )

    def default_cutscene(self) -> dict:
        image = self.image_path().relative_to(self.repo_root)
        annotations_path = self.image_path().with_name(f"{self.room}_annotations.json")
        width = 320
        height = 184
        if annotations_path.exists():
            annotations = json.loads(annotations_path.read_text())
            width = int(annotations.get("width", width))
            height = int(annotations.get("height", height))

        return {
            "version": 1,
            "id": "granny_intro",
            "chapter": self.chapter,
            "room": self.room,
            "image": str(image),
            "trigger": {"x": 96, "y": 96, "w": 48, "h": 56},
            "actors": [
                {
                    "id": "granny",
                    "kind": "granny",
                    "x": min(width - 48, 224),
                    "y": min(height - 48, 120),
                    "facing": "left",
                    "sprite": "granny",
                }
            ],
            "markers": {
                "madeline_talk": {"x": min(width - 88, 184), "y": min(height - 48, 128)},
                "madeline_edge": {"x": min(width - 32, 280), "y": min(height - 48, 128)},
                "dialogue_box": {"x": 8, "y": 8, "w": 224, "h": 56},
                "laugh_start": {"x": 24, "y": 24},
                "laugh_end": {"x": min(width - 24, 296), "y": 16},
            },
            "laugh": {
                "text": "ha ha ha",
                "speedPxPerFrame": 1,
                "spawnEveryFrames": 28,
                "persistsAcrossRoom": True,
            },
            "dialogue": self.default_dialogue(),
            "script": self.default_script(),
        }

    @staticmethod
    def default_dialogue() -> list[dict]:
        return [
            {"speaker": "Madeline", "text": "Excuse me, ma'am?"},
            {
                "speaker": "Madeline",
                "text": "The sign out front is busted... is this the Mountain trail?",
            },
            {"speaker": "Old Woman", "text": "You're almost there. It's just across the bridge."},
            {
                "speaker": "Madeline",
                "text": 'By the way, you should call someone about your driveway. The ridge collapsed and I nearly died.',
            },
            {
                "speaker": "Old Woman",
                "text": 'If my "driveway" almost did you in, the Mountain might be a bit much for you.',
            },
            {"speaker": "Madeline", "text": "..."},
            {
                "speaker": "Madeline",
                "text": "Well, if an old bat like you can survive out here, I think I'll be fine.",
            },
            {"speaker": "Old Woman", "text": "Suit yourself."},
            {
                "speaker": "Old Woman",
                "text": "But you should know, Celeste Mountain is a strange place.",
            },
            {"speaker": "Old Woman", "text": "You might see things."},
            {"speaker": "Old Woman", "text": "Things you ain't ready to see."},
            {"speaker": "Madeline", "text": "You should seek help, lady."},
        ]

    @staticmethod
    def default_script() -> list[dict]:
        return [
            {"op": "lock_player"},
            {"op": "say", "dialogue": 0},
            {"op": "walk_player_to", "marker": "madeline_talk"},
            {"op": "face", "actor": "player", "dir": "right"},
            {"op": "say", "dialogue": 1},
            {"op": "say", "dialogue": 2},
            {"op": "walk_player_to", "marker": "madeline_edge"},
            {"op": "face", "actor": "player", "dir": "left"},
            {"op": "say", "dialogue": 3},
            {"op": "say", "dialogue": 4},
            {"op": "say", "dialogue": 5},
            {"op": "say", "dialogue": 6},
            {"op": "say", "dialogue": 7},
            {"op": "say", "dialogue": 8},
            {"op": "say", "dialogue": 9},
            {"op": "say", "dialogue": 10},
            {"op": "say", "dialogue": 11},
            {"op": "spawn_laugh_text"},
            {"op": "set_flag", "flag": "granny_intro_done"},
            {"op": "unlock_player"},
        ]

    def validate_cutscene(self, data: dict) -> None:
        if data.get("version") != 1:
            raise ValueError("unsupported cutscene version")
        if data.get("id") != "granny_intro":
            raise ValueError("expected granny_intro cutscene id")
        if data.get("room") != self.room:
            raise ValueError(f"expected room {self.room}")
        if not isinstance(data.get("dialogue"), list):
            raise ValueError("dialogue must be a list")
        if not isinstance(data.get("script"), list):
            raise ValueError("script must be a list")

    def animation_assets(self) -> list[dict]:
        root = self.repo_root / "assets" / "animations" / "granny"
        out = []
        if not root.exists():
            return out
        for path in sorted(root.glob("*.png")):
            width, height = self.png_dimensions(path)
            out.append(
                {
                    "id": path.stem,
                    "name": path.stem,
                    "kind": "laugh_text" if path.stem in {"ha-ha", "haha"} else "actor",
                    "path": str(path.relative_to(self.repo_root)),
                    "width": width,
                    "height": height,
                }
            )
        return out

    @staticmethod
    def png_dimensions(path: Path) -> tuple[int, int]:
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"{path} is not a PNG")
        return struct.unpack(">II", data[16:24])

    def image_path(self) -> Path:
        return self.repo_root / "assets" / "chapters" / self.chapter / f"{self.room}.png"

    def cutscene_path(self) -> Path:
        return self.image_path().with_name(f"{self.room}_cutscene.json")

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
    parser.add_argument("--port", type=int, default=8792)
    parser.add_argument("--chapter", default="prologue_a")
    parser.add_argument("--room", default="2")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    GrannyCutsceneHandler.repo_root = Path(__file__).resolve().parents[1]
    GrannyCutsceneHandler.chapter = args.chapter
    GrannyCutsceneHandler.room = args.room

    image_path = GrannyCutsceneHandler.repo_root / "assets" / "chapters" / args.chapter / f"{args.room}.png"
    if not image_path.exists():
        raise SystemExit(f"missing room image: {image_path}")

    server = ThreadingHTTPServer((args.host, args.port), GrannyCutsceneHandler)
    url = f"http://{args.host}:{args.port}/tools/granny_cutscene_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
