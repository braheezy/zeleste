#!/usr/bin/env python3
"""Serve a tiny editor for generated foreground grass animation frames."""

from __future__ import annotations

import argparse
import base64
import json
import re
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba

FRAME_RE = re.compile(r"^(\d+)\.png$")


def frame_sort_key(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        return 999999
    return int(match.group(1))


class GrassFrameHandler(SimpleHTTPRequestHandler):
    repo_root: Path

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/grass/sets":
            self.send_json(200, {"sets": self.grass_sets()})
            return
        if parsed.path == "/api/grass/frame":
            query = parse_qs(parsed.query)
            self.send_frame(
                query.get("set", [""])[0], int(query.get("frame", ["1"])[0])
            )
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path == "/api/grass/save-frame":
            self.save_frame()
            return
        self.send_error(404)

    def grass_sets(self) -> list[dict]:
        root = self.repo_root / "assets" / "generated" / "foreground"
        sets = []
        if not root.exists():
            return sets
        for directory in sorted(path for path in root.iterdir() if path.is_dir()):
            if not directory.name.endswith(
                "_generated"
            ) and not directory.name.endswith("_generated_mirror"):
                continue
            frames = sorted(
                (path for path in directory.glob("*.png") if FRAME_RE.match(path.name)),
                key=frame_sort_key,
            )
            if not frames:
                continue
            metadata = self.read_metadata(directory)
            image = read_png_rgba(frames[0])
            relative = directory.relative_to(self.repo_root)
            sets.append(
                {
                    "name": directory.name,
                    "path": str(relative),
                    "frameCount": len(frames),
                    "width": image.width,
                    "height": image.height,
                    "preset": metadata.get("preset"),
                    "positions": metadata.get("positions"),
                    "source": metadata.get("source"),
                    "frames": [
                        str(path.relative_to(self.repo_root)) for path in frames
                    ],
                }
            )
        return sets

    def send_frame(self, raw_set: str, frame: int) -> None:
        try:
            directory = self.safe_set_path(raw_set)
            frame_path = directory / f"{frame}.png"
            if not frame_path.exists():
                raise ValueError("frame does not exist")
            image = read_png_rgba(frame_path)
            self.send_json(
                200,
                {
                    "ok": True,
                    "frame": frame,
                    "path": str(frame_path.relative_to(self.repo_root)),
                    "width": image.width,
                    "height": image.height,
                    "pixels": base64.b64encode(image.pixels).decode("ascii"),
                },
            )
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})

    def save_frame(self) -> None:
        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            directory = self.safe_set_path(str(request["set"]))
            frame = int(request["frame"])
            width = int(request["width"])
            height = int(request["height"])
            pixels = base64.b64decode(str(request["pixels"]))
            if len(pixels) != width * height * 4:
                raise ValueError("pixel buffer length does not match frame dimensions")
            frame_path = directory / f"{frame}.png"
            if not frame_path.exists():
                raise ValueError("frame does not exist")
            write_png_rgba(frame_path, Image(width, height, pixels))
            self.send_json(
                200, {"ok": True, "path": str(frame_path.relative_to(self.repo_root))}
            )
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})

    def safe_set_path(self, raw_path: str) -> Path:
        normalized = unquote(raw_path).replace("\\", "/").lstrip("/")
        relative = Path(normalized)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("path must stay inside the project")
        full = self.repo_root / relative
        root = self.repo_root / "assets" / "generated" / "foreground"
        if not full.is_dir() or root not in full.parents:
            raise ValueError("set must be under assets/generated/foreground")
        if not full.name.endswith("_generated") and not full.name.endswith(
            "_generated_mirror"
        ):
            raise ValueError("set must be a generated grass directory")
        return full

    @staticmethod
    def read_metadata(directory: Path) -> dict:
        path = directory / "sway.json"
        if not path.exists():
            return {}
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            return {}

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
    parser.add_argument("--port", type=int, default=8791)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    GrassFrameHandler.repo_root = repo_root
    server = ThreadingHTTPServer((args.host, args.port), GrassFrameHandler)
    url = f"http://{args.host}:{args.port}/tools/grass_frame_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
