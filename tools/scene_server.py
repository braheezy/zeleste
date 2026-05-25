#!/usr/bin/env python3
"""Serve the scene animation editor and save room scene scripts."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse


class SceneHandler(SimpleHTTPRequestHandler):
    repo_root: Path

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/scene/backgrounds":
            self.send_json(200, {"backgrounds": self.backgrounds()})
            return
        if parsed.path == "/api/scene/animations":
            self.send_json(200, {"animations": self.animations()})
            return
        if parsed.path == "/api/scene":
            query = parse_qs(parsed.query)
            self.send_scene(query.get("image", [""])[0])
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/scene/save":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            image = self.safe_relative_path(str(request["image"]), ".png")
            path = self.scene_path_for_image(image)
            output_path = self.repo_root / path
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(json.dumps(request["data"], indent=2) + "\n")
            generated_path = self.rebuild_room_bundle_for_image(image)
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return
        self.send_json(200, {"ok": True, "path": str(path), "generated": generated_path})

    def backgrounds(self) -> list[dict]:
        root = self.repo_root / "assets" / "chapters"
        out = []
        for path in sorted(root.rglob("*.png")) if root.exists() else []:
            if self.is_entity_art(path):
                continue
            rel = path.relative_to(self.repo_root)
            scene = self.scene_path_for_image(rel)
            out.append(
                {
                    "image": str(rel),
                    "scene": str(scene),
                    "hasScene": (self.repo_root / scene).exists(),
                }
            )
        return out

    def animations(self) -> list[dict]:
        root = self.repo_root / "assets" / "source" / "bird" / "intro"
        out = []
        if not root.exists():
            return out
        directories = {path.name: path for path in root.iterdir() if path.is_dir()}
        ordered_directories = [
            directories[name]
            for name in ("squawk", "peck", "liftoff")
            if name in directories
        ]
        ordered_directories.extend(
            directory
            for name, directory in sorted(directories.items())
            if name not in {"squawk", "peck", "liftoff"}
        )
        for directory in ordered_directories:
            frames = sorted(directory.glob("*.png"))
            if not frames:
                continue
            out.append(
                {
                    "id": directory.name,
                    "name": directory.name,
                    "frames": [str(path.relative_to(self.repo_root)) for path in frames],
                }
            )
        loose = sorted(path for path in root.glob("*.png"))
        if loose:
            out.append(
                {
                    "id": "fly",
                    "name": "fly",
                    "frames": [str(path.relative_to(self.repo_root)) for path in loose],
                }
            )
        return out

    def send_scene(self, image_path: str) -> None:
        try:
            image = self.safe_relative_path(image_path, ".png")
            scene_path = self.scene_path_for_image(image)
            full = self.repo_root / scene_path
            if full.exists():
                data = json.loads(full.read_text())
            else:
                data = self.default_scene(image)
            self.send_json(200, {"ok": True, "path": str(scene_path), "data": data})
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})

    def default_scene(self, image: Path) -> dict:
        annotation_path = image.with_name(f"{image.stem}_annotations.json")
        bird = None
        full_annotation = self.repo_root / annotation_path
        if full_annotation.exists():
            bird = json.loads(full_annotation.read_text()).get("birdNpc")
        if not bird:
            bird = {"x": 128, "y": 96, "hintX": 96, "hintY": 48, "flightPath": []}
        x = int(bird.get("x", 128))
        y = int(bird.get("y", 96))
        return {
            "version": 1,
            "image": image.name,
            "entities": [
                {
                    "id": "bird_intro",
                    "kind": "bird",
                    "origin": {"x": x, "y": y},
                    "hint": {"x": int(bird.get("hintX", 96)), "y": int(bird.get("hintY", 48))},
                    "triggers": [
                        {
                            "id": "show_hold_hint",
                            "action": "squawk_hold_hint",
                            "rect": {"x": x - 72, "y": y + 8, "w": 168, "h": 48},
                        },
                        {
                            "id": "clear_hint_top",
                            "action": "peck_then_fly",
                            "rect": {"x": x + 80, "y": y - 56, "w": 112, "h": 96},
                        },
                    ],
                    "segments": [
                        {"animation": "squawk", "frames": 16, "points": []},
                        {"animation": "peck", "frames": 12, "points": []},
                        {
                            "animation": "liftoff",
                            "frames": 20,
                            "points": bird.get("flightPath", []),
                        },
                    ],
                }
            ],
        }

    def rebuild_room_bundle_for_image(self, image: Path) -> str | None:
        manifest_path = image.parent / "room.json"
        full_manifest = self.repo_root / manifest_path
        if not full_manifest.exists():
            return None

        manifest = json.loads(full_manifest.read_text())
        matching_room = None
        for room in manifest.get("rooms", []):
            if str(room.get("image")) == image.name:
                matching_room = room
                break
        if matching_room is None:
            return None

        prefix = str(manifest.get("outputPrefix", manifest.get("id", "room")))
        room_name = self.zig_room_name(prefix, str(matching_room["id"]))
        output_dir = self.repo_root / "src" / "generated" / "assets" / "chapters" / room_name
        subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("build_room_bundle.py")),
                str(self.repo_root / image),
                str(output_dir),
                "--collision-only",
                "--rgb-bits",
                str(int(matching_room.get("rgbBits", 4))),
            ],
            check=True,
        )
        return str(output_dir.relative_to(self.repo_root))

    @staticmethod
    def zig_room_name(prefix: str, room_id: str) -> str:
        safe = room_id.replace("-", "m").replace("+", "p")
        safe = "".join(ch if ch.isalnum() or ch == "_" else "_" for ch in safe)
        return f"{prefix}_{safe}"

    @staticmethod
    def scene_path_for_image(image: Path) -> Path:
        return image.with_name(f"{image.stem}_scene.json")

    @staticmethod
    def is_entity_art(path: Path) -> bool:
        name = path.stem.lower()
        return "-block" in name or name.endswith("_block") or name.endswith("-hint")

    @staticmethod
    def safe_relative_path(raw_path: str, expected_suffix: str) -> Path:
        normalized = unquote(raw_path).replace("\\", "/").lstrip("/")
        relative = Path(normalized)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("path must stay inside the project")
        if relative.suffix != expected_suffix:
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
    parser.add_argument("--port", type=int, default=8789)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    SceneHandler.repo_root = Path(__file__).resolve().parents[1]
    server = ThreadingHTTPServer((args.host, args.port), SceneHandler)
    url = f"http://{args.host}:{args.port}/tools/scene_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
