#!/usr/bin/env python3
"""Serve the collision editor and save collision annotations into the repo."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse


class AnnotationHandler(SimpleHTTPRequestHandler):
    repo_root: Path

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/backgrounds":
            self.send_json(200, {"backgrounds": self.backgrounds()})
            return
        if parsed.path == "/api/foreground-stamps":
            self.send_json(200, {"stamps": self.foreground_stamps()})
            return
        if parsed.path == "/api/annotation":
            query = parse_qs(parsed.query)
            image_path = query.get("image", [""])[0]
            self.send_annotation(image_path)
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/save-annotation":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            if "path" in request:
                relative_path = self.safe_relative_path(str(request["path"]))
            else:
                relative_path = self.annotation_path_for_image(str(request["image"]))
            data = request["data"]
            output_path = self.repo_root / relative_path
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(json.dumps(data, indent=2) + "\n")
            bundle_path = self.generate_collision_bundle(request, relative_path)
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return

        self.send_json(200, {"ok": True, "path": str(relative_path), "bundle": str(bundle_path)})

    def backgrounds(self) -> list[dict]:
        backgrounds = []
        roots = [
            self.repo_root / "assets" / "rooms",
            self.repo_root / "assets" / "backgrounds",
        ]
        for root in roots:
            if not root.exists():
                continue
            paths = root.rglob("*.png") if root.name == "rooms" else root.glob("*.png")
            for path in sorted(paths):
                if self.is_entity_art(path):
                    continue
                relative = path.relative_to(self.repo_root)
                annotation = self.annotation_path_for_image(str(relative))
                backgrounds.append(
                    {
                        "image": str(relative),
                        "annotation": str(annotation),
                        "hasAnnotation": (self.repo_root / annotation).exists(),
                    }
                )
        return backgrounds

    def foreground_stamps(self) -> list[dict]:
        stamps = []
        roots = [
            self.repo_root / "assets" / "Animations" / "foreground",
            self.repo_root / "assets" / "Animations" / "foregound",
        ]
        for root in roots:
            if not root.exists():
                continue
            generated_grass = root / "grass_generated"
            if generated_grass.exists():
                frames = sorted(
                    generated_grass.glob("*.png"),
                    key=lambda path: int(path.stem) if path.stem.isdigit() else path.stem,
                )
                mirror_frames = sorted(
                    (root / "grass_generated_mirror").glob("*.png"),
                    key=lambda path: int(path.stem) if path.stem.isdigit() else path.stem,
                )
                if frames:
                    metadata = self.stamp_metadata(generated_grass)
                    stamps.append(
                        {
                            "id": "grass1",
                            "name": "grass1",
                            "preview": str(frames[0].relative_to(self.repo_root)),
                            "mirrorPreview": str(mirror_frames[0].relative_to(self.repo_root)) if mirror_frames else None,
                            "anchorX": metadata.get("anchorX", 8),
                            "anchorY": metadata.get("anchorY", 8),
                        }
                    )
            for directory in sorted(path for path in root.iterdir() if path.is_dir()):
                if directory.name in {"grass1", "grass_generated", "grass_generated_mirror"}:
                    continue
                if directory.name.endswith("_mirror"):
                    continue
                metadata = self.stamp_metadata(directory)
                if not metadata:
                    continue
                frames = sorted(
                    directory.glob("*.png"),
                    key=lambda path: int(path.stem) if path.stem.isdigit() else path.stem,
                )
                if not frames:
                    continue
                relative = frames[0].relative_to(self.repo_root)
                mirror_directory = root / f"{directory.name}_mirror"
                mirror_frames = sorted(
                    mirror_directory.glob("*.png"),
                    key=lambda path: int(path.stem) if path.stem.isdigit() else path.stem,
                ) if mirror_directory.exists() else []
                stamp_id = directory.name.removesuffix("_generated")
                source_preview = root / f"{stamp_id}.png"
                preview = source_preview if source_preview.exists() else frames[0]
                stamps.append(
                    {
                        "id": stamp_id,
                        "name": stamp_id,
                        "preview": str(preview.relative_to(self.repo_root)),
                        "generatedPreview": str(relative),
                        "mirrorPreview": str(mirror_frames[0].relative_to(self.repo_root)) if mirror_frames else None,
                        "anchorX": metadata.get("anchorX", 8),
                        "anchorY": metadata.get("anchorY", 8),
                    }
                )
        return stamps

    @staticmethod
    def stamp_metadata(directory: Path) -> dict:
        for name in ("stamp.json", "sway.json"):
            path = directory / name
            if path.exists():
                try:
                    return json.loads(path.read_text())
                except json.JSONDecodeError:
                    return {}
        return {}

    @staticmethod
    def is_entity_art(path: Path) -> bool:
        name = path.stem.lower()
        return "-block" in name or name.endswith("_block")

    @staticmethod
    def room_id_for_image(image_path: Path) -> str:
        if image_path.parent.name == "prologue_a":
            if image_path.stem.startswith("-"):
                return f"prologue_m{image_path.stem[1:]}"
            return f"prologue_{image_path.stem}"
        return image_path.stem.replace("-", "_")

    def send_annotation(self, image_path: str) -> None:
        try:
            annotation_path = self.annotation_path_for_image(image_path)
            full_path = self.repo_root / annotation_path
            if not full_path.exists():
                self.send_json(200, {"ok": True, "path": str(annotation_path), "data": None})
                return
            self.send_json(
                200,
                {
                    "ok": True,
                    "path": str(annotation_path),
                    "data": json.loads(full_path.read_text()),
                },
            )
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})

    @staticmethod
    def annotation_path_for_image(image_path: str) -> Path:
        relative = AnnotationHandler.safe_relative_path(image_path, expected_suffix=".png")
        return relative.with_name(f"{relative.stem}_annotations.json")

    def generate_collision_bundle(self, request: dict, annotation_path: Path) -> Path:
        if "image" not in request:
            return Path()
        image_path = self.safe_relative_path(str(request["image"]), expected_suffix=".png")
        room_id = self.room_id_for_image(image_path)
        output_dir = Path("assets/generated/rooms") / room_id
        subprocess.run(
            [
                sys.executable,
                str(self.repo_root / "tools" / "build_room_bundle.py"),
                str(self.repo_root / image_path),
                str(self.repo_root / output_dir),
                "--annotations",
                str(self.repo_root / annotation_path),
                "--collision-only",
            ],
            check=True,
        )
        return output_dir

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
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    AnnotationHandler.repo_root = repo_root
    server = ThreadingHTTPServer((args.host, args.port), AnnotationHandler)
    url = f"http://{args.host}:{args.port}/tools/collision_editor.html"
    print(f"serving {url}")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
