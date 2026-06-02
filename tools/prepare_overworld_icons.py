#!/usr/bin/env python3
"""Split chapter icon pairs and prepare small overworld navigation icons."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba


CHAPTERS = [
    "prologue",
    "city",
    "old-site",
    "resort",
    "ridge",
    "temple",
    "reflection",
    "summit",
    "core",
    "farewell",
]

IMPLEMENTED_CHAPTERS = {
    "prologue",
    "city",
}

CHAPTER_LAYOUT = {
    "prologue": (0, 18, 122),
    "city": (0, 58, 108),
    "old-site": (0, 98, 86),
    "resort": (0, 134, 66),
    "ridge": (0, 90, 44),
    "temple": (1, 190, 122),
    "reflection": (1, 150, 104),
    "summit": (1, 110, 82),
    "core": (1, 72, 58),
    "farewell": (1, 112, 24),
}

REVERSED_ICON_CHAPTERS = {
    "prologue",
    "summit",
}


def crop(image: Image, x0: int, y0: int, width: int, height: int) -> Image:
    pixels = bytearray(width * height * 4)
    for y in range(height):
        source = ((y0 + y) * image.width + x0) * 4
        target = y * width * 4
        pixels[target : target + width * 4] = image.pixels[source : source + width * 4]
    return Image(width, height, bytes(pixels))


def resize_nearest_fit(image: Image, width: int, height: int) -> Image:
    scale = min(width / image.width, height / image.height)
    resized_width = max(1, min(width, round(image.width * scale)))
    resized_height = max(1, min(height, round(image.height * scale)))

    resized = bytearray(resized_width * resized_height * 4)
    for y in range(resized_height):
        source_y = min(image.height - 1, (y * image.height) // resized_height)
        for x in range(resized_width):
            source_x = min(image.width - 1, (x * image.width) // resized_width)
            source = (source_y * image.width + source_x) * 4
            target = (y * resized_width + x) * 4
            resized[target : target + 4] = image.pixels[source : source + 4]

    canvas = bytearray(width * height * 4)
    offset_x = (width - resized_width) // 2
    offset_y = (height - resized_height) // 2
    paste(Image(resized_width, resized_height, bytes(resized)), Image(width, height, bytes(canvas)), offset_x, offset_y, canvas)
    return Image(width, height, bytes(canvas))


def paste(source: Image, target_image: Image, x0: int, y0: int, target_pixels: bytearray) -> None:
    for y in range(source.height):
        target_y = y0 + y
        if target_y < 0 or target_y >= target_image.height:
            continue
        for x in range(source.width):
            target_x = x0 + x
            if target_x < 0 or target_x >= target_image.width:
                continue
            source_offset = (y * source.width + x) * 4
            target_offset = (target_y * target_image.width + target_x) * 4
            alpha = source.pixels[source_offset + 3]
            if alpha == 0:
                continue
            target_pixels[target_offset : target_offset + 4] = source.pixels[source_offset : source_offset + 4]


def split_pair(image: Image) -> tuple[Image, Image]:
    half_width = image.width // 2
    return crop(image, 0, 0, half_width, image.height), crop(image, half_width, 0, image.width - half_width, image.height)


def side_for_chapter(chapter: str, default_icon_side: str) -> str:
    icon_side = default_icon_side
    if chapter in REVERSED_ICON_CHAPTERS:
        icon_side = "right" if default_icon_side == "left" else "left"
    return icon_side


def clamp_color(value: int) -> int:
    return max(0, min(255, value))


def other_side_background(image: Image) -> Image:
    pixels = bytearray(image.width * image.height * 4)
    for y in range(image.height):
        for x in range(image.width):
            source_offset = (y * image.width + (image.width - 1 - x)) * 4
            target_offset = (y * image.width + x) * 4
            r, g, b, a = image.pixels[source_offset : source_offset + 4]
            pixels[target_offset + 0] = clamp_color((r * 68 + 28 * 32) // 100)
            pixels[target_offset + 1] = clamp_color((g * 76 + 20 * 24) // 100)
            pixels[target_offset + 2] = clamp_color((b * 92 + 54 * 18) // 100)
            pixels[target_offset + 3] = a
    return Image(image.width, image.height, bytes(pixels))


def write_page(background: Image, icons: list[tuple[Image, int, int]], output: Path) -> None:
    pixels = bytearray(background.pixels)
    for icon, x, y in icons:
        paste(icon, background, x, y, pixels)
    write_png_rgba(output, Image(background.width, background.height, bytes(pixels)))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=Path("assets/icons"))
    parser.add_argument("--output-dir", type=Path, default=Path("assets/generated/overworld/icons"))
    parser.add_argument("--background", type=Path, default=Path("assets/overworld.png"))
    parser.add_argument("--icon-width", type=int, default=32)
    parser.add_argument("--icon-height", type=int, default=32)
    parser.add_argument("--icon-side", choices=("left", "right"), default="left")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    split_dir = args.output_dir / "split"
    resized_dir = args.output_dir / "resized"
    page_dir = args.output_dir / "pages"
    split_dir.mkdir(parents=True, exist_ok=True)
    resized_dir.mkdir(parents=True, exist_ok=True)
    page_dir.mkdir(parents=True, exist_ok=True)

    background = read_png_rgba(args.background)
    page_backgrounds = [
        background,
        other_side_background(background),
    ]
    for page, page_background in enumerate(page_backgrounds):
        write_png_rgba(page_dir / f"page_{page}_bg.png", page_background)

    manifest_chapters = []
    resized_by_chapter: dict[str, dict[str, Image]] = {}

    for index, chapter in enumerate(CHAPTERS):
        source_path = args.input_dir / f"{chapter}.png"
        source = read_png_rgba(source_path)
        left, right = split_pair(source)
        split_left = split_dir / f"{chapter}_left.png"
        split_right = split_dir / f"{chapter}_right.png"
        write_png_rgba(split_left, left)
        write_png_rgba(split_right, right)

        icon_side = side_for_chapter(chapter, args.icon_side)
        icon_source = left if icon_side == "left" else right
        icon = resize_nearest_fit(icon_source, args.icon_width, args.icon_height)
        icon_path = resized_dir / f"{chapter}.png"
        write_png_rgba(icon_path, icon)
        resized_by_chapter[chapter] = {
            "icon": icon,
        }

        page, x, y = CHAPTER_LAYOUT[chapter]
        manifest_chapters.append(
            {
                "id": chapter,
                "source": str(source_path),
                "splitLeft": str(split_left),
                "splitRight": str(split_right),
                "icon": str(icon_path),
                "iconSide": icon_side,
                "implemented": chapter in IMPLEMENTED_CHAPTERS,
                "page": page,
                "x": x,
                "y": y,
            }
        )

    pages = []
    page_count = 1 + max(page for page, _, _ in CHAPTER_LAYOUT.values())
    for page in range(page_count):
        page_chapters = [chapter for chapter in CHAPTERS if CHAPTER_LAYOUT[chapter][0] == page]
        output = page_dir / f"page_{page}_icons.png"
        write_page(
            page_backgrounds[page],
            [(resized_by_chapter[chapter]["icon"], CHAPTER_LAYOUT[chapter][1], CHAPTER_LAYOUT[chapter][2]) for chapter in page_chapters],
            output,
        )
        pages.append(
            {
                "page": page,
                "image": str(output),
                "chapters": page_chapters,
            }
        )

    manifest = {
        "iconWidth": args.icon_width,
        "iconHeight": args.icon_height,
        "defaultIconSide": args.icon_side,
        "reversedChapters": sorted(REVERSED_ICON_CHAPTERS),
        "implementedChapters": sorted(IMPLEMENTED_CHAPTERS),
        "chaptersPerPage": 5,
        "chapters": manifest_chapters,
        "pages": pages,
    }
    (args.output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"prepared {len(CHAPTERS)} overworld icons at {args.icon_width}x{args.icon_height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
