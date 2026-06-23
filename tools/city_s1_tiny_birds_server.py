#!/usr/bin/env python3
"""Serve the Chapter 1 s1 tiny-bird annotation editor."""

from __future__ import annotations

import argparse
import json
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def png_size(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) >= 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
        return (
            int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"),
        )
    return (0, 0)


class CityS1TinyBirdsHandler(SimpleHTTPRequestHandler):
    repo_root: Path
    chapter: str
    room: str

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.repo_root), **kwargs)

    def do_GET(self) -> None:
        if self.path == "/api/city-s1-tiny-birds":
            self.send_state()
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/city-s1-tiny-birds/save":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            data = request["data"]
            self.validate_data(data)
            path = self.data_path()
            path.write_text(json.dumps(data, indent=2) + "\n")
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return
        self.send_json(200, {"ok": True, "path": str(path.relative_to(self.repo_root))})

    def send_state(self) -> None:
        try:
            path = self.data_path()
            data = json.loads(path.read_text()) if path.exists() else self.default_data()
            image = self.image_path()
            width, height = png_size(image)
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return
        self.send_json(
            200,
            {
                "ok": True,
                "image": str(image.relative_to(self.repo_root)),
                "sprite": "assets/animations/tiny_bird/idle.png",
                "path": str(path.relative_to(self.repo_root)),
                "width": width,
                "height": height,
                "data": data,
                "variants": ["cyan", "pink", "red", "blue", "green", "gold"],
                "roles": ["ambient"],
                "directions": ["up", "up-left", "up-right", "left", "right", "down-left", "down", "down-right"],
            },
        )

    def default_data(self) -> dict:
        image = self.image_path().relative_to(self.repo_root)
        return {
            "version": 1,
            "id": "city_s1_tiny_birds",
            "chapter": self.chapter,
            "room": self.room,
            "image": str(image),
            "puzzleCluster": {"x": 216, "y": 66},
            "puzzleAntennaTip": {"enabled": False, "x": 216, "y": 66},
            "birds": [],
        }

    def validate_data(self, data: dict) -> None:
        if data.get("version") != 1:
            raise ValueError("unsupported tiny-bird annotation version")
        if data.get("chapter") != self.chapter:
            raise ValueError(f"expected chapter {self.chapter}")
        if data.get("room") != self.room:
            raise ValueError(f"expected room {self.room}")
        birds = data.get("birds")
        if not isinstance(birds, list):
            raise ValueError("birds must be a list")
        cluster = data.get("puzzleCluster")
        if cluster is not None:
            if not isinstance(cluster, dict):
                raise ValueError("puzzleCluster must be an object")
            int(cluster.get("x", 0))
            int(cluster.get("y", 0))
        antenna_tip = data.get("puzzleAntennaTip")
        if antenna_tip is not None:
            if not isinstance(antenna_tip, dict):
                raise ValueError("puzzleAntennaTip must be an object")
            bool(antenna_tip.get("enabled", False))
            int(antenna_tip.get("x", 0))
            int(antenna_tip.get("y", 0))
        for index, bird in enumerate(birds):
            if not isinstance(bird, dict):
                raise ValueError(f"bird {index} must be an object")
            int(bird.get("x", 0))
            int(bird.get("y", 0))
            group = int(bird.get("group", 0))
            if group < 0 or group > 15:
                raise ValueError(f"bird {index} group must be 0..15")
            role = str(bird.get("role", "ambient"))
            if role not in {"ambient", "puzzle"}:
                raise ValueError(f"bird {index} role must be ambient or puzzle")

    def image_path(self) -> Path:
        return self.repo_root / "assets" / "chapters" / self.chapter / f"{self.room}.png"

    def data_path(self) -> Path:
        return self.image_path().with_name(f"{self.room}_tiny_birds.json")

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
    parser.add_argument("--port", type=int, default=8795)
    parser.add_argument("--chapter", default="1_city")
    parser.add_argument("--room", default="s1")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    CityS1TinyBirdsHandler.repo_root = Path(__file__).resolve().parents[1]
    CityS1TinyBirdsHandler.chapter = args.chapter
    CityS1TinyBirdsHandler.room = args.room

    image_path = CityS1TinyBirdsHandler.repo_root / "assets" / "chapters" / args.chapter / f"{args.room}.png"
    if not image_path.exists():
        raise SystemExit(f"missing room image: {image_path}")

    server = ThreadingHTTPServer((args.host, args.port), CityS1TinyBirdsHandler)
    url = f"http://{args.host}:{args.port}/tools/city_s1_tiny_birds_editor.html"
    print(f"serving {url}")
    print(f"saves: assets/chapters/{args.chapter}/{args.room}_tiny_birds.json")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
