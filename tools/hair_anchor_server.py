#!/usr/bin/env python3
"""Serve the hair anchor editor and save per-animation hair placements."""

from __future__ import annotations

import argparse
import json
import re
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse


FRAME_RE = re.compile(r"^f(\d+)\.png$")


def frame_index(path: Path) -> int:
    match = FRAME_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected frame name: {path}")
    return int(match.group(1))


class HairAnchorHandler(SimpleHTTPRequestHandler):
    repo_root: Path

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/hair/animations":
            self.send_json(200, {"animations": self.animations()})
            return
        if parsed.path == "/api/hair/anchors":
            query = parse_qs(parsed.query)
            self.send_anchors(query.get("animation", [""])[0])
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/hair/save":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            animation = self.safe_relative_path(str(request["animation"]), expected_suffix="")
            self.validate_animation_path(animation)
            output_path = self.anchor_path(animation)
            output_path.write_text(json.dumps(request["data"], indent=2) + "\n")
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return

        self.send_json(200, {"ok": True, "path": str(output_path.relative_to(self.repo_root))})

    def animations(self) -> list[dict]:
        root = self.repo_root / "assets" / "Animations" / "player"
        animations = []
        for directory in sorted(path for path in root.iterdir() if path.is_dir()):
            frames = sorted(directory.glob("f*.png"), key=frame_index)
            if not frames:
                continue
            relative = directory.relative_to(self.repo_root)
            animations.append(
                {
                    "name": directory.name,
                    "path": str(relative),
                    "frameCount": len(frames),
                    "frames": [str(path.relative_to(self.repo_root)) for path in frames],
                    "anchorPath": str(self.anchor_path(relative).relative_to(self.repo_root)),
                    "hasAnchors": self.anchor_path(relative).exists(),
                }
            )
        return animations

    def send_anchors(self, animation_path: str) -> None:
        try:
            animation = self.safe_relative_path(animation_path, expected_suffix="")
            self.validate_animation_path(animation)
            path = self.anchor_path(animation)
            if path.exists():
                data = json.loads(path.read_text())
            else:
                data = None
            self.send_json(200, {"ok": True, "path": str(path.relative_to(self.repo_root)), "data": data})
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})

    def validate_animation_path(self, animation: Path) -> None:
        full = self.repo_root / animation
        root = self.repo_root / "assets" / "Animations" / "player"
        if not full.is_dir() or root not in full.parents:
            raise ValueError("animation must be a directory under assets/Animations/player")

    def anchor_path(self, animation: Path) -> Path:
        return self.repo_root / animation / "hair_anchors.json"

    @staticmethod
    def safe_relative_path(raw_path: str, expected_suffix: str = ".json") -> Path:
        normalized = unquote(raw_path).replace("\\", "/").lstrip("/")
        relative = Path(normalized)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("path must stay inside the project")
        if expected_suffix and relative.suffix != expected_suffix:
            raise ValueError(f"path must end in {expected_suffix}")
        return relative

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
    parser.add_argument("--port", type=int, default=8788)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    HairAnchorHandler.repo_root = repo_root
    server = ThreadingHTTPServer((args.host, args.port), HairAnchorHandler)
    url = f"http://{args.host}:{args.port}/tools/hair_anchor_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
