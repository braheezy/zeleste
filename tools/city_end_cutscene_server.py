#!/usr/bin/env python3
"""Serve the Chapter 1 ending cutscene editor."""

from __future__ import annotations

import argparse
import json
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def dialogue_page(speaker: str, portrait: str, text: str) -> dict:
    return {"speaker": speaker, "portrait": portrait, "text": text}


class CityEndCutsceneHandler(SimpleHTTPRequestHandler):
    repo_root: Path
    chapter: str
    room: str

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.repo_root), **kwargs)

    def do_GET(self) -> None:
        if self.path == "/api/city-end-cutscene":
            self.send_cutscene()
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/city-end-cutscene/save":
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

        self.send_json(
            200,
            {
                "ok": True,
                "image": str(self.image_path().relative_to(self.repo_root)),
                "path": str(path.relative_to(self.repo_root)),
                "portraits": self.portrait_options(),
                "data": data,
            },
        )

    def default_cutscene(self) -> dict:
        return {
            "version": 1,
            "id": "city_end_outro",
            "chapter": self.chapter,
            "room": self.room,
            "image": str(self.image_path().relative_to(self.repo_root)),
            "memorial": {
                "trigger": {"x": 124, "y": 92, "w": 76, "h": 56},
                "dialogueBox": {"x": 8, "y": 8, "w": 224, "h": 56},
                "page": dialogue_page(
                    "Memorial",
                    "none",
                    "- - CELESTE MOUNTAIN - -\nThis memorial dedicated to those\nWho perished on the climb",
                ),
            },
            "outro": {
                "trigger": {"x": 252, "y": 124, "w": 48, "h": 56},
                "markers": {
                    "madeline_rest": {"x": 238, "y": 136},
                    "campfire": {"x": 262, "y": 150},
                    "bird_start": {"x": 314, "y": 88},
                    "bird_land": {"x": 242, "y": 126},
                    "camera_focus": {"x": 246, "y": 118},
                    "dialogue_box": {"x": 8, "y": 8, "w": 224, "h": 56},
                },
                "timings": {
                    "pausePastFireFrames": 90,
                    "turnBackFrames": 30,
                    "sitDownFrames": 36,
                    "makeCampfireFrames": 90,
                    "birdSwoopFrames": 90,
                    "birdCawFrames": 42,
                    "wipeFrames": 32,
                },
                "dialogue": [
                    dialogue_page("Madeline", "madeline_distracted_short", "Ugh, I'm exhausted."),
                    dialogue_page("Madeline", "madeline_deadpan_noblink", "This might have been a mistake."),
                ],
            },
            "script": self.default_script(),
        }

    @staticmethod
    def default_script() -> list[dict]:
        return [
            {"op": "lock_player"},
            {"op": "walk_player_past", "marker": "campfire"},
            {"op": "wait_frames", "frames": 90, "label": "pause_past_fire"},
            {"op": "face", "actor": "player", "dir": "left"},
            {"op": "wait_frames", "frames": 30},
            {"op": "say", "dialogue": 0},
            {"op": "walk_player_to", "marker": "madeline_rest"},
            {"op": "play_placeholder", "actor": "campfire", "marker": "campfire"},
            {"op": "wait_frames", "frames": 90, "label": "start_fire"},
            {"op": "wait_frames", "frames": 36, "label": "sit_down"},
            {"op": "bird_swoop", "from": "bird_start", "to": "bird_land", "frames": 90},
            {"op": "bird_caw", "frames": 42, "firstFrame": 8, "lastFrame": 14},
            {"op": "say", "dialogue": 1},
            {"op": "screen_wipe", "to": "black"},
            {"op": "chapter_complete", "art": "chapter_endings/city-nap"},
        ]

    def validate_cutscene(self, data: dict) -> None:
        if data.get("version") != 1:
            raise ValueError("unsupported cutscene version")
        if data.get("id") != "city_end_outro":
            raise ValueError("expected city_end_outro cutscene id")
        if data.get("room") != self.room:
            raise ValueError(f"expected room {self.room}")
        if not isinstance(data.get("memorial"), dict):
            raise ValueError("memorial must be an object")
        if not isinstance(data.get("outro"), dict):
            raise ValueError("outro must be an object")
        if not isinstance(data["outro"].get("dialogue"), list):
            raise ValueError("outro.dialogue must be a list")
        if not isinstance(data.get("script"), list):
            raise ValueError("script must be a list")

    def image_path(self) -> Path:
        return self.repo_root / "assets" / "chapters" / self.chapter / f"{self.room}.png"

    def cutscene_path(self) -> Path:
        return self.image_path().with_name(f"{self.room}_cutscene.json")

    def portrait_options(self) -> dict[str, list[dict[str, str]]]:
        return {
            "Madeline": self.portrait_options_for("madeline", "madeline"),
            "Memorial": [{"label": "none", "value": "none"}],
        }

    def portrait_options_for(self, folder: str, prefix: str) -> list[dict[str, str]]:
        portrait_dir = self.repo_root / "assets" / "portraits" / folder
        if not portrait_dir.exists():
            return []
        preferred = ["idle", "angry", "sad", "upset", "distracted-short", "deadpan-noblink"]

        def sort_key(path: Path) -> tuple[int, str]:
            try:
                return (preferred.index(path.stem), path.stem)
            except ValueError:
                return (len(preferred), path.stem)

        options = []
        for path in sorted(portrait_dir.glob("*.png"), key=sort_key):
            stem = path.stem.replace("-", "_")
            options.append({"label": stem.replace("_", " "), "value": f"{prefix}_{stem}"})
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
    parser.add_argument("--port", type=int, default=8794)
    parser.add_argument("--chapter", default="1_city")
    parser.add_argument("--room", default="end")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    CityEndCutsceneHandler.repo_root = Path(__file__).resolve().parents[1]
    CityEndCutsceneHandler.chapter = args.chapter
    CityEndCutsceneHandler.room = args.room

    image_path = CityEndCutsceneHandler.repo_root / "assets" / "chapters" / args.chapter / f"{args.room}.png"
    if not image_path.exists():
        raise SystemExit(f"missing room image: {image_path}")

    server = ThreadingHTTPServer((args.host, args.port), CityEndCutsceneHandler)
    url = f"http://{args.host}:{args.port}/tools/city_end_cutscene_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
