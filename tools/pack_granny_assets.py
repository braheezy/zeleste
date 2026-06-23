#!/usr/bin/env python3
"""Pack Granny actor sprites into 4bpp OBJ tiles."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba


FRAME_WIDTH = 32
FRAME_HEIGHT = 32
PORTRAIT_FRAME_WIDTH = 32
PORTRAIT_FRAME_HEIGHT = 32
PORTRAIT_EXPRESSIONS = ("normal", "mock", "laugh")
HA_SOURCE_FRAME_WIDTH = 14
HA_FRAME_WIDTH = 16
HA_FRAME_HEIGHT = 16
HA_COLOR_INDICES = {
    (255, 255, 255, 255): 1,
    (0, 0, 0, 255): 5,
    (173, 173, 173, 255): 9,
}
TRANSPARENT_RGB = {
    (255, 0, 255),
    (173, 0, 255),
    (0, 255, 255),
    (0, 173, 255),
}


def rgba_to_rgb555(color: tuple[int, int, int, int]) -> int:
    r, g, b, _ = color
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def color_distance(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def is_transparent(color: tuple[int, int, int, int]) -> bool:
    return color[3] == 0 or color[:3] in TRANSPARENT_RGB


def write_tile_4bpp(output: bytearray, pixels: list[int]) -> None:
    for y in range(8):
        for x_pair in range(4):
            output.append(pixels[y * 8 + x_pair * 2] | (pixels[y * 8 + x_pair * 2 + 1] << 4))


def slice_nonempty_grid(path: Path, frame_width: int = FRAME_WIDTH, frame_height: int = FRAME_HEIGHT) -> list[Image]:
    source = read_png_rgba(path)
    if source.width % frame_width != 0 or source.height % frame_height != 0:
        raise ValueError(f"{path} must be a {frame_width}x{frame_height} grid")

    frames: list[Image] = []
    for frame_y in range(source.height // frame_height):
        for frame_x in range(source.width // frame_width):
            pixels = bytearray(frame_width * frame_height * 4)
            opaque_count = 0
            for y in range(frame_height):
                for x in range(frame_width):
                    src_offset = ((frame_y * frame_height + y) * source.width + frame_x * frame_width + x) * 4
                    dst_offset = (y * frame_width + x) * 4
                    color = tuple(source.pixels[src_offset : src_offset + 4])
                    if is_transparent(color):
                        pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                    else:
                        pixels[dst_offset : dst_offset + 4] = bytes(color)
                        opaque_count += 1
            if opaque_count != 0:
                frames.append(Image(frame_width, frame_height, bytes(pixels)))
    return frames


def slice_nonempty_scaled_grid(
    path: Path,
    source_frame_width: int,
    source_frame_height: int,
    output_width: int,
    output_height: int,
) -> list[Image]:
    source = read_png_rgba(path)
    if source.width % source_frame_width != 0 or source.height % source_frame_height != 0:
        raise ValueError(f"{path} must be a {source_frame_width}x{source_frame_height} grid")
    if source_frame_width % output_width != 0 or source_frame_height % output_height != 0:
        raise ValueError(f"{path} source frames must scale evenly to {output_width}x{output_height}")

    frames: list[Image] = []
    for frame_y in range(source.height // source_frame_height):
        for frame_x in range(source.width // source_frame_width):
            pixels = bytearray(output_width * output_height * 4)
            opaque_count = 0
            for y in range(output_height):
                src_y = (y * source_frame_height) // output_height
                for x in range(output_width):
                    src_x = (x * source_frame_width) // output_width
                    src_offset = ((frame_y * source_frame_height + src_y) * source.width + frame_x * source_frame_width + src_x) * 4
                    dst_offset = (y * output_width + x) * 4
                    color = tuple(source.pixels[src_offset : src_offset + 4])
                    if is_transparent(color):
                        pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                    else:
                        pixels[dst_offset : dst_offset + 4] = bytes(color)
                        opaque_count += 1
            if opaque_count != 0:
                frames.append(Image(output_width, output_height, bytes(pixels)))
    return frames


def slice_portrait_grid(path: Path) -> list[Image]:
    source = read_png_rgba(path)
    if source.width % 64 == 0 and source.height % 64 == 0:
        return slice_nonempty_scaled_grid(path, 64, 64, PORTRAIT_FRAME_WIDTH, PORTRAIT_FRAME_HEIGHT)
    return slice_nonempty_grid(path, PORTRAIT_FRAME_WIDTH, PORTRAIT_FRAME_HEIGHT)


def palette_for(frames: list[Image]) -> list[tuple[int, int, int, int]]:
    colors: Counter[tuple[int, int, int, int]] = Counter()
    for frame in frames:
        for offset in range(0, len(frame.pixels), 4):
            color = tuple(frame.pixels[offset : offset + 4])
            if color[3] != 0:
                colors[color] += 1
    opaque = [color for color, _ in colors.most_common(15)]
    return [(0, 0, 0, 0)] + opaque + [(0, 0, 0, 255)] * (15 - len(opaque))


def pack_frame(frame: Image, palette: list[tuple[int, int, int, int]]) -> bytes:
    palette_opaque = [color for color in palette if color[3] != 0]
    palette_index = {color: index for index, color in enumerate(palette)}

    def pixel_index(x: int, y: int) -> int:
        offset = (y * frame.width + x) * 4
        color = tuple(frame.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color not in palette_index:
            closest = min(palette_opaque, key=lambda candidate: color_distance(color, candidate))
            return palette_index[closest]
        return palette_index[color]

    tiles = bytearray()
    for tile_y in range(frame.height // 8):
        for tile_x in range(frame.width // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def slice_strip(path: Path, frame_width: int, frame_height: int, output_width: int | None = None) -> list[Image]:
    source = read_png_rgba(path)
    output_width = frame_width if output_width is None else output_width
    if output_width < frame_width or output_width % 8 != 0:
        raise ValueError("output frame width must be >= source frame width and tile aligned")
    if source.height != frame_height:
        raise ValueError(f"{path} must be {frame_height}px high")
    frame_count = source.width // frame_width
    if frame_count == 0:
        raise ValueError(f"{path} is too narrow for {frame_width}px frames")
    trailing_start = frame_count * frame_width
    for y in range(source.height):
        for x in range(trailing_start, source.width):
            src_offset = (y * source.width + x) * 4
            if not is_transparent(tuple(source.pixels[src_offset : src_offset + 4])):
                raise ValueError(f"{path} has non-transparent trailing pixels after {frame_count} frames")

    frames: list[Image] = []
    for frame_x in range(frame_count):
        pixels = bytearray(output_width * frame_height * 4)
        opaque_count = 0
        for y in range(frame_height):
            for x in range(frame_width):
                src_offset = (y * source.width + frame_x * frame_width + x) * 4
                dst_offset = (y * output_width + x) * 4
                color = tuple(source.pixels[src_offset : src_offset + 4])
                if is_transparent(color):
                    pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                else:
                    pixels[dst_offset : dst_offset + 4] = bytes(color)
                    opaque_count += 1
        if opaque_count != 0:
            frames.append(Image(output_width, frame_height, bytes(pixels)))
    return frames


def slice_padded_strip(path: Path, frame_width: int, frame_height: int, output_width: int) -> list[Image]:
    source = read_png_rgba(path)
    if output_width < frame_width or output_width % 8 != 0:
        raise ValueError("output frame width must be >= source frame width and tile aligned")
    if source.height != frame_height:
        raise ValueError(f"{path} must be {frame_height}px high")

    frame_count = (source.width + frame_width - 1) // frame_width
    if frame_count == 0:
        raise ValueError(f"{path} is too narrow for {frame_width}px frames")

    frames: list[Image] = []
    for frame_x in range(frame_count):
        source_x = frame_x * frame_width
        source_width = min(frame_width, source.width - source_x)
        if frame_x + 1 == frame_count and source_width < frame_width // 2:
            raise ValueError(f"{path} final portrait frame is only {source_width}px wide")

        pixels = bytearray(output_width * frame_height * 4)
        opaque_count = 0
        for y in range(frame_height):
            for x in range(source_width):
                src_offset = (y * source.width + source_x + x) * 4
                dst_offset = (y * output_width + x) * 4
                color = tuple(source.pixels[src_offset : src_offset + 4])
                if is_transparent(color):
                    pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                else:
                    pixels[dst_offset : dst_offset + 4] = bytes(color)
                    opaque_count += 1
        if opaque_count != 0:
            frames.append(Image(output_width, frame_height, bytes(pixels)))
    return frames


def pack_frame_with_indices(frame: Image, color_indices: dict[tuple[int, int, int, int], int]) -> bytes:
    def pixel_index(x: int, y: int) -> int:
        offset = (y * frame.width + x) * 4
        color = tuple(frame.pixels[offset : offset + 4])
        if color[3] == 0:
            return 0
        if color in color_indices:
            return color_indices[color]
        luminance = (color[0] + color[1] + color[2]) // 3
        if luminance > 220:
            return 1
        if luminance > 80:
            return 9
        return 5

    tiles = bytearray()
    for tile_y in range(frame.height // 8):
        for tile_x in range(frame.width // 8):
            tile_pixels = []
            for y in range(8):
                for x in range(8):
                    tile_pixels.append(pixel_index(tile_x * 8 + x, tile_y * 8 + y))
            write_tile_4bpp(tiles, tile_pixels)
    return bytes(tiles)


def slice_portrait_asset(path: Path) -> list[Image]:
    source = read_png_rgba(path)
    if source.height == PORTRAIT_FRAME_HEIGHT and source.width % PORTRAIT_FRAME_WIDTH != 0:
        if source.width % 29 == 0:
            return slice_strip(path, 29, PORTRAIT_FRAME_HEIGHT, PORTRAIT_FRAME_WIDTH)
        return slice_padded_strip(path, PORTRAIT_FRAME_WIDTH, PORTRAIT_FRAME_HEIGHT, PORTRAIT_FRAME_WIDTH)
    return slice_portrait_grid(path)


def slice_portrait_runs(path: Path) -> list[Image]:
    source = read_png_rgba(path)
    if source.height != PORTRAIT_FRAME_HEIGHT:
        raise ValueError(f"{path} must be {PORTRAIT_FRAME_HEIGHT}px high")

    frames: list[Image] = []
    x = 0
    while x < source.width:
        gap_start = x
        while x < source.width and portraitColumnEmpty(source, x):
            x += 1
        if x > gap_start and x - gap_start > 2:
            raise ValueError(f"{path} has a {x - gap_start}px portrait frame gap at x={gap_start}; expected 1-2px")
        if x >= source.width:
            break;
        if x + PORTRAIT_FRAME_WIDTH > source.width:
            raise ValueError(f"{path} has a partial portrait frame at x={x}")
        if portraitColumnEmpty(source, x) or portraitColumnEmpty(source, x + PORTRAIT_FRAME_WIDTH - 1):
            raise ValueError(f"{path} has an empty edge inside portrait frame at x={x}")
        pixels = bytearray(PORTRAIT_FRAME_WIDTH * PORTRAIT_FRAME_HEIGHT * 4)
        opaque_count = 0
        for y in range(PORTRAIT_FRAME_HEIGHT):
            for frame_x in range(PORTRAIT_FRAME_WIDTH):
                src_offset = (y * source.width + x + frame_x) * 4
                dst_offset = (y * PORTRAIT_FRAME_WIDTH + frame_x) * 4
                color = tuple(source.pixels[src_offset : src_offset + 4])
                if is_transparent(color):
                    pixels[dst_offset : dst_offset + 4] = b"\x00\x00\x00\x00"
                else:
                    pixels[dst_offset : dst_offset + 4] = bytes(color)
                    opaque_count += 1
        if opaque_count != 0:
            frames.append(Image(PORTRAIT_FRAME_WIDTH, PORTRAIT_FRAME_HEIGHT, bytes(pixels)))
        x += PORTRAIT_FRAME_WIDTH
    return frames


def portraitColumnEmpty(source: Image, x: int) -> bool:
    for y in range(source.height):
        offset = (y * source.width + x) * 4
        if not is_transparent(tuple(source.pixels[offset : offset + 4])):
            return False
    return True


def pack_portraits(granny_dir: Path, madeline_dir: Path, theo_dir: Path, output_dir: Path) -> tuple[int, int]:
    portrait_sources = [
        ("madeline_idle", madeline_dir / "idle.png", slice_portrait_asset),
        ("madeline_angry", madeline_dir / "angry.png", slice_portrait_asset),
        ("madeline_sad", madeline_dir / "sad.png", slice_portrait_asset),
        ("madeline_upset", madeline_dir / "upset.png", slice_portrait_asset),
        ("madeline_distracted_short", madeline_dir / "distracted-short.png", slice_portrait_asset),
        ("madeline_deadpan_noblink", madeline_dir / "deadpan-noblink.png", slice_portrait_asset),
        ("normal", granny_dir / "normal.png", slice_portrait_asset),
        ("mock", granny_dir / "mock.png", slice_portrait_asset),
        ("laugh", granny_dir / "laugh.png", slice_portrait_asset),
        ("creep_a", granny_dir / "creepA.png", slice_portrait_asset),
        ("creep_b", granny_dir / "creepB.png", slice_portrait_asset),
        ("theo_normal", theo_dir / "normal.png", slice_portrait_runs),
        ("theo_excited", theo_dir / "excited.png", slice_portrait_runs),
        ("theo_serious", theo_dir / "serious.png", slice_portrait_runs),
        ("theo_thinking", theo_dir / "thinking.png", slice_portrait_runs),
        ("theo_nailed_it", theo_dir / "nailed-it.png", slice_portrait_runs),
        ("theo_yolo", theo_dir / "yolo.png", slice_portrait_runs),
    ]
    frames_by_expression: dict[str, list[Image]] = {}
    all_frames: list[Image] = []
    for expression, path, slicer in portrait_sources:
        frames = slicer(path)
        if not frames:
            raise ValueError(f"{path} produced no portrait frames")
        frames_by_expression[expression] = frames
        all_frames.extend(frames)

    palette = palette_for(all_frames)
    tiles = bytearray()
    ranges: dict[str, dict[str, int]] = {}
    frame_offset = 0
    for expression, _, _ in portrait_sources:
        frames = frames_by_expression[expression]
        ranges[expression] = {
            "firstFrame": frame_offset,
            "frameCount": len(frames),
        }
        for frame in frames:
            tiles.extend(pack_frame(frame, palette))
        frame_offset += len(frames)

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "granny_portrait_tiles.bin").write_bytes(bytes(tiles))
    (output_dir / "granny_portrait_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (output_dir / "granny_portrait_meta.zig").write_text(
        "\n".join(
            [
                f"pub const frame_width: u8 = {PORTRAIT_FRAME_WIDTH};",
                f"pub const frame_height: u8 = {PORTRAIT_FRAME_HEIGHT};",
                f"pub const tiles_per_frame: u16 = {(PORTRAIT_FRAME_WIDTH // 8) * (PORTRAIT_FRAME_HEIGHT // 8)};",
                f"pub const madeline_idle_first_frame: u16 = {ranges['madeline_idle']['firstFrame']};",
                f"pub const madeline_idle_frame_count: u16 = {ranges['madeline_idle']['frameCount']};",
                f"pub const madeline_angry_first_frame: u16 = {ranges['madeline_angry']['firstFrame']};",
                f"pub const madeline_angry_frame_count: u16 = {ranges['madeline_angry']['frameCount']};",
                f"pub const madeline_sad_first_frame: u16 = {ranges['madeline_sad']['firstFrame']};",
                f"pub const madeline_sad_frame_count: u16 = {ranges['madeline_sad']['frameCount']};",
                f"pub const madeline_upset_first_frame: u16 = {ranges['madeline_upset']['firstFrame']};",
                f"pub const madeline_upset_frame_count: u16 = {ranges['madeline_upset']['frameCount']};",
                f"pub const madeline_distracted_short_first_frame: u16 = {ranges['madeline_distracted_short']['firstFrame']};",
                f"pub const madeline_distracted_short_frame_count: u16 = {ranges['madeline_distracted_short']['frameCount']};",
                f"pub const madeline_deadpan_noblink_first_frame: u16 = {ranges['madeline_deadpan_noblink']['firstFrame']};",
                f"pub const madeline_deadpan_noblink_frame_count: u16 = {ranges['madeline_deadpan_noblink']['frameCount']};",
                f"pub const normal_first_frame: u16 = {ranges['normal']['firstFrame']};",
                f"pub const normal_frame_count: u16 = {ranges['normal']['frameCount']};",
                f"pub const mock_first_frame: u16 = {ranges['mock']['firstFrame']};",
                f"pub const mock_frame_count: u16 = {ranges['mock']['frameCount']};",
                f"pub const laugh_first_frame: u16 = {ranges['laugh']['firstFrame']};",
                f"pub const laugh_frame_count: u16 = {ranges['laugh']['frameCount']};",
                f"pub const creep_a_first_frame: u16 = {ranges['creep_a']['firstFrame']};",
                f"pub const creep_a_frame_count: u16 = {ranges['creep_a']['frameCount']};",
                f"pub const creep_b_first_frame: u16 = {ranges['creep_b']['firstFrame']};",
                f"pub const creep_b_frame_count: u16 = {ranges['creep_b']['frameCount']};",
                f"pub const theo_normal_first_frame: u16 = {ranges['theo_normal']['firstFrame']};",
                f"pub const theo_normal_frame_count: u16 = {ranges['theo_normal']['frameCount']};",
                f"pub const theo_excited_first_frame: u16 = {ranges['theo_excited']['firstFrame']};",
                f"pub const theo_excited_frame_count: u16 = {ranges['theo_excited']['frameCount']};",
                f"pub const theo_serious_first_frame: u16 = {ranges['theo_serious']['firstFrame']};",
                f"pub const theo_serious_frame_count: u16 = {ranges['theo_serious']['frameCount']};",
                f"pub const theo_thinking_first_frame: u16 = {ranges['theo_thinking']['firstFrame']};",
                f"pub const theo_thinking_frame_count: u16 = {ranges['theo_thinking']['frameCount']};",
                f"pub const theo_nailed_it_first_frame: u16 = {ranges['theo_nailed_it']['firstFrame']};",
                f"pub const theo_nailed_it_frame_count: u16 = {ranges['theo_nailed_it']['frameCount']};",
                f"pub const theo_yolo_first_frame: u16 = {ranges['theo_yolo']['firstFrame']};",
                f"pub const theo_yolo_frame_count: u16 = {ranges['theo_yolo']['frameCount']};",
                "",
            ]
        )
    )
    (output_dir / "granny_portrait.json").write_text(
        json.dumps(
            {
                "frameWidth": PORTRAIT_FRAME_WIDTH,
                "frameHeight": PORTRAIT_FRAME_HEIGHT,
                "tilesPerFrame": (PORTRAIT_FRAME_WIDTH // 8) * (PORTRAIT_FRAME_HEIGHT // 8),
                "expressions": ranges,
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    return frame_offset, sum(1 for color in palette if color[3] != 0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--portrait-dir", type=Path, required=True)
    parser.add_argument("--madeline-portrait-dir", type=Path, required=True)
    parser.add_argument("--theo-portrait-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    idle_frames = slice_nonempty_grid(args.input_dir / "idle.png")
    if not idle_frames:
        raise ValueError("idle.png produced no frames")
    laugh_frames = slice_nonempty_grid(args.input_dir / "laugh.png")
    if not laugh_frames:
        raise ValueError("laugh.png produced no frames")
    quote_frames = slice_nonempty_grid(args.input_dir / "quotes.png")
    if not quote_frames:
        raise ValueError("quotes.png produced no frames")
    haha_frames = slice_strip(args.input_dir / "ha-ha.png", HA_SOURCE_FRAME_WIDTH, HA_FRAME_HEIGHT, HA_FRAME_WIDTH)
    if not haha_frames:
        raise ValueError("ha-ha.png produced no frames")
    palette = palette_for(idle_frames + laugh_frames + quote_frames)

    tiles = bytearray()
    for frame in idle_frames:
        tiles.extend(pack_frame(frame, palette))
    laugh_tiles = bytearray()
    for frame in laugh_frames:
        laugh_tiles.extend(pack_frame(frame, palette))
    quote_tiles = bytearray()
    for frame in quote_frames:
        quote_tiles.extend(pack_frame(frame, palette))

    haha_tiles = bytearray()
    for frame in haha_frames:
        haha_tiles.extend(pack_frame_with_indices(frame, HA_COLOR_INDICES))

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "granny_idle_tiles.bin").write_bytes(bytes(tiles))
    (args.output_dir / "granny_laugh_tiles.bin").write_bytes(bytes(laugh_tiles))
    (args.output_dir / "granny_quotes_tiles.bin").write_bytes(bytes(quote_tiles))
    (args.output_dir / "granny_haha_tiles.bin").write_bytes(bytes(haha_tiles))
    (args.output_dir / "granny_palette.bin").write_bytes(
        b"".join(rgba_to_rgb555(color).to_bytes(2, "little") for color in palette)
    )
    (args.output_dir / "granny.json").write_text(
        json.dumps(
            {
                "frameWidth": FRAME_WIDTH,
                "frameHeight": FRAME_HEIGHT,
                "idleFrameCount": len(idle_frames),
                "laughFrameCount": len(laugh_frames),
                "quoteFrameCount": len(quote_frames),
                "hahaFrameCount": len(haha_frames),
                "tilesPerFrame": (FRAME_WIDTH // 8) * (FRAME_HEIGHT // 8),
                "hahaSourceFrameWidth": HA_SOURCE_FRAME_WIDTH,
                "hahaTilesPerFrame": (HA_FRAME_WIDTH // 8) * (HA_FRAME_HEIGHT // 8),
                "paletteRgba": [list(color) for color in palette],
            },
            indent=2,
        )
        + "\n"
    )
    portrait_frame_count, portrait_color_count = pack_portraits(args.portrait_dir, args.madeline_portrait_dir, args.theo_portrait_dir, args.output_dir)
    print(
        f"packed granny idle: {len(idle_frames)} frames, "
        f"laugh: {len(laugh_frames)} frames, "
        f"quotes: {len(quote_frames)} frames, "
        f"haha: {len(haha_frames)} frames, "
        f"portrait: {portrait_frame_count} frames, "
        f"{sum(1 for color in palette if color[3] != 0)} sprite opaque colors, "
        f"{portrait_color_count} portrait opaque colors"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
