#!/usr/bin/env python3
"""Extract and pad a single player sprite from the downloaded sprite archive."""

from __future__ import annotations

import argparse
import sys
import tempfile
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from split_foreground_tileset import Image, read_png_rgba, write_png_rgba  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("sprites_zip", type=Path)
    parser.add_argument("sprite_path")
    parser.add_argument("output_png", type=Path)
    parser.add_argument("--width", type=int, default=16)
    parser.add_argument("--height", type=int, default=16)
    args = parser.parse_args()

    with zipfile.ZipFile(args.sprites_zip) as archive:
        sprite_bytes = archive.read(args.sprite_path)

    with tempfile.NamedTemporaryFile(suffix=".png") as temp:
        temp.write(sprite_bytes)
        temp.flush()
        sprite = read_png_rgba(Path(temp.name))

    if sprite.width > args.width or sprite.height > args.height:
        raise ValueError(f"{args.sprite_path} is {sprite.width}x{sprite.height}, larger than {args.width}x{args.height}")

    output = bytearray(args.width * args.height * 4)
    x_offset = (args.width - sprite.width) // 2
    y_offset = args.height - sprite.height

    for y in range(sprite.height):
        for x in range(sprite.width):
            src = (y * sprite.width + x) * 4
            dst = ((y + y_offset) * args.width + (x + x_offset)) * 4
            output[dst : dst + 4] = sprite.pixels[src : src + 4]

    args.output_png.parent.mkdir(parents=True, exist_ok=True)
    write_png_rgba(args.output_png, Image(args.width, args.height, bytes(output)))
    print(f"wrote {args.output_png} from {args.sprite_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
