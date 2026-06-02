#!/usr/bin/env python3
"""Serve the city room layout picker and save room world positions."""

from __future__ import annotations

import argparse
import json
import re
import webbrowser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


def natural_key(value: str) -> tuple:
    parts = re.split(r"(\d+)", value)
    out = []
    for part in parts:
        if not part:
            continue
        out.append((0, int(part)) if part.isdigit() else (1, part))
    return tuple(out)


def png_size(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) >= 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
        return (
            int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"),
        )
    return (0, 0)


class CityLayoutHandler(SimpleHTTPRequestHandler):
    repo_root: Path
    map_path: Path
    city_dir: Path

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/city-layout":
            self.send_json(200, self.layout_state())
            return
        super().do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/city-layout/save":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("content-length", "0"))
            request = json.loads(self.rfile.read(length))
            layout = self.normalize_layout(request)
            output_path = self.city_dir / "layout.json"
            output_path.write_text(json.dumps(layout, indent=2) + "\n")
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return
        self.send_json(
            200,
            {
                "ok": True,
                "path": str(output_path.relative_to(self.repo_root)),
                "placed": len(layout["rooms"]),
            },
        )

    def layout_state(self) -> dict:
        layout_path = self.city_dir / "layout.json"
        layout = {}
        if layout_path.exists():
            try:
                layout = json.loads(layout_path.read_text())
            except json.JSONDecodeError:
                layout = {}

        map_width, map_height = png_size(self.map_path)
        return {
            "map": {
                "image": str(self.map_path.relative_to(self.repo_root)),
                "width": map_width,
                "height": map_height,
            },
            "layoutPath": str(layout_path.relative_to(self.repo_root)),
            "layout": layout,
            "rooms": self.rooms(),
        }

    def rooms(self) -> list[dict]:
        rooms = []
        for image in sorted(self.city_dir.glob("*.png"), key=lambda path: natural_key(path.stem)):
            if annotation_path_for_image(image).exists() is False:
                continue
            width, height = png_size(image)
            rooms.append(
                {
                    "id": f"city_{image.stem}",
                    "name": image.stem,
                    "image": str(image.relative_to(self.repo_root)),
                    "width": width,
                    "height": height,
                }
            )
        return rooms

    def normalize_layout(self, request: dict) -> dict:
        known_rooms = {room["id"]: room for room in self.rooms()}
        raw_rooms = request.get("rooms")
        if not isinstance(raw_rooms, dict):
            raise ValueError("rooms must be an object")

        anchor_room = str(request.get("anchorRoom") or "city_1")
        map_image = self.safe_relative_path(str(request.get("mapImage") or ""), ".png")
        if self.repo_root / map_image != self.map_path:
            raise ValueError("map image does not match this editor")

        placed: dict[str, dict[str, int]] = {}
        for room_id, raw in raw_rooms.items():
            if room_id not in known_rooms or not isinstance(raw, dict):
                continue
            map_x = int(round(float(raw.get("mapX", raw.get("x", 0)))))
            map_y = int(round(float(raw.get("mapY", raw.get("y", 0)))))
            placed[room_id] = {
                "mapX": map_x,
                "mapY": map_y,
            }

        if not placed:
            return {
                "mapImage": str(map_image),
                "anchorRoom": anchor_room,
                "rooms": {},
            }

        if anchor_room not in placed:
            anchor_room = sorted(placed.keys(), key=natural_key)[0]
        anchor_x = placed[anchor_room]["mapX"]
        anchor_y = placed[anchor_room]["mapY"]

        rooms = {}
        for room_id in sorted(placed.keys(), key=natural_key):
            room = known_rooms[room_id]
            map_x = placed[room_id]["mapX"]
            map_y = placed[room_id]["mapY"]
            rooms[room_id] = {
                "mapX": map_x,
                "mapY": map_y,
                "worldX": map_x - anchor_x,
                "worldY": map_y - anchor_y,
                "width": int(room["width"]),
                "height": int(room["height"]),
            }

        return {
            "mapImage": str(map_image),
            "anchorRoom": anchor_room,
            "rooms": rooms,
        }

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


def annotation_path_for_image(image: Path) -> Path:
    return image.with_name(f"{image.stem}_annotations.json")


def default_map_path(repo_root: Path) -> Path:
    preferred = repo_root / "celeste-city-a_4200x3392.png"
    if preferred.exists():
        return preferred

    candidates = []
    for path in repo_root.glob("*.png"):
        width, height = png_size(path)
        candidates.append((width * height, path))
    if not candidates:
        raise FileNotFoundError("could not find a root-level city map PNG")
    return max(candidates)[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8791)
    parser.add_argument("--map", dest="map_image", type=Path)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    map_path = (repo_root / args.map_image) if args.map_image else default_map_path(repo_root)
    map_path = map_path.resolve()
    if not map_path.exists():
        raise FileNotFoundError(map_path)
    if not str(map_path).startswith(str(repo_root.resolve())):
        raise ValueError("map image must be inside the repo")

    handler = partial(CityLayoutHandler, directory=str(repo_root))
    CityLayoutHandler.repo_root = repo_root
    CityLayoutHandler.map_path = map_path
    CityLayoutHandler.city_dir = repo_root / "assets" / "chapters" / "1_city"
    server = ThreadingHTTPServer((args.host, args.port), handler)
    url = f"http://{args.host}:{args.port}/tools/city_layout_picker.html"
    print(f"serving {url}")
    print(f"map: {map_path.relative_to(repo_root)}")
    print("saves: assets/chapters/1_city/layout.json")
    if not args.no_open:
        webbrowser.open(url)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
