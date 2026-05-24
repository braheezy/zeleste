#!/usr/bin/env python3
"""Generate small pixel-art grass sway animations from one 16x16 base frame.

The generated mirror variant mirrors the base image first, then applies the
same world-space sway, so wind direction stays consistent across variants.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
from dataclasses import dataclass
from pathlib import Path

from split_foreground_tileset import Image, read_png_rgba, write_png_rgba


@dataclass(frozen=True)
class SwayPreset:
    name: str
    positions: int
    max_operation: int
    root_lock_rows: int
    mirror: bool


PRESETS = {
    "tiny": SwayPreset(
        "tiny", positions=3, max_operation=2, root_lock_rows=3, mirror=False
    ),
    "small": SwayPreset(
        "small", positions=3, max_operation=1, root_lock_rows=2, mirror=True
    ),
    "medium": SwayPreset(
        "medium", positions=5, max_operation=4, root_lock_rows=1, mirror=True
    ),
    "large": SwayPreset(
        "large", positions=7, max_operation=6, root_lock_rows=0, mirror=True
    ),
}


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def opaque_bounds(image: Image) -> tuple[int, int, int, int]:
    xs = []
    ys = []
    for y in range(image.height):
        for x in range(image.width):
            if image.pixels[(y * image.width + x) * 4 + 3] != 0:
                xs.append(x)
                ys.append(y)
    if not xs:
        raise ValueError("base image has no opaque pixels")
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def grass_cell(x: int, y: int, bounds: tuple[int, int, int, int]) -> tuple[int, int]:
    left, top, right, bottom = bounds
    width = max(1, right - left)
    height = max(1, bottom - top)
    # User-facing coordinates: (8,8) is top-left, (1,1) is lower-right.
    cell_x = 8 - clamp(((x - left) * 8) // width, 0, 7)
    cell_y = 8 - clamp(((y - top) * 8) // height, 0, 7)
    return cell_x, cell_y


def operation_hits(
    operation: int, cell_x: int, cell_y: int, preset: SwayPreset
) -> bool:
    if cell_y <= preset.root_lock_rows:
        return False
    if preset.name == "tiny":
        if operation == 1:
            return cell_y in (8, 7, 6, 5)
        if operation == 2:
            return cell_y == 4
        return False
    if operation == 1:
        return cell_y in (8, 7, 6, 5) or (cell_x == 2 and cell_y == 4)
    if operation == 2:
        return cell_y in (3, 2, 1) or (cell_y == 4 and cell_x != 2)
    if operation == 3:
        return cell_y in (6, 5) or (cell_x == 3 and cell_y == 4)
    if operation == 4:
        excluded = (cell_x, cell_y) in ((3, 2), (3, 3), (4, 3), (4, 4))
        return cell_y in (8, 7, 4, 3, 2) and not excluded
    if operation == 5:
        return cell_y in (8, 7)
    if operation == 6:
        return cell_y == 8
    return False


def shift_for_pixel(
    position: int, x: int, y: int, bounds: tuple[int, int, int, int], preset: SwayPreset
) -> int:
    cell_x, cell_y = grass_cell(x, y, bounds)
    shift = 0
    operation_limit = round(
        position * preset.max_operation / max(1, preset.positions - 1)
    )
    operation = 1
    while operation <= operation_limit:
        if operation_hits(operation, cell_x, cell_y, preset):
            shift -= 1
        operation += 1
    return shift


def mirror_image(image: Image) -> Image:
    out = bytearray(len(image.pixels))
    for y in range(image.height):
        for x in range(image.width):
            src = (y * image.width + (image.width - 1 - x)) * 4
            dst = (y * image.width + x) * 4
            out[dst : dst + 4] = image.pixels[src : src + 4]
    return Image(image.width, image.height, bytes(out))


def crop_image(image: Image, left: int, top: int, width: int, height: int) -> Image:
    out = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            src = ((top + y) * image.width + left + x) * 4
            dst = (y * width + x) * 4
            out[dst : dst + 4] = image.pixels[src : src + 4]
    return Image(width, height, bytes(out))


def normalize_stamp_canvas(image: Image, path: Path) -> tuple[Image, int, int]:
    if image.width not in (8, 16) or image.height not in (8, 16):
        raise ValueError(
            f"{path} must be 8x8, 8x16, 16x8, or 16x16, got {image.width}x{image.height}"
        )

    left, top, right, bottom = opaque_bounds(image)
    if (
        right - left <= 8
        and bottom - top <= 8
        and (image.width, image.height) != (8, 8)
    ):
        crop_left = clamp(right - 8, 0, image.width - 8)
        crop_top = clamp(bottom - 8, 0, image.height - 8)
        return crop_image(image, crop_left, crop_top, 8, 8), crop_left, crop_top

    if image.width in (8, 16) and image.height in (8, 16):
        return image, 0, 0
    raise ValueError(
        f"{path} must be 8x8, 8x16, 16x8, or 16x16, got {image.width}x{image.height}"
    )


def opaque_components(image: Image) -> list[list[tuple[int, int]]]:
    seen: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(image.height):
        for x in range(image.width):
            if (x, y) in seen:
                continue
            src = (y * image.width + x) * 4
            if image.pixels[src + 3] == 0:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for ny in range(py - 1, py + 2):
                    for nx in range(px - 1, px + 2):
                        if nx == px and ny == py:
                            continue
                        if nx < 0 or nx >= image.width or ny < 0 or ny >= image.height:
                            continue
                        if (nx, ny) in seen:
                            continue
                        neighbor = (ny * image.width + nx) * 4
                        if image.pixels[neighbor + 3] == 0:
                            continue
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            components.append(component)
    return components


def reconnect_grass_pixels(image: Image) -> Image:
    components = opaque_components(image)
    if len(components) <= 1:
        return image

    # The anchored grass body is the component nearest the ground. Any tiny
    # detached tip created by a sway rule gets nudged back toward that body.
    main = max(components, key=lambda points: (max(y for _, y in points), len(points)))
    main_center_x = sum(x for x, _ in main) / len(main)
    out = bytearray(image.pixels)

    for component in components:
        if component is main:
            continue
        component_set = set(component)
        center_x = sum(x for x, _ in component) / len(component)
        directions = (1, -1) if center_x < main_center_x else (-1, 1)
        moved = False
        for direction in directions:
            for distance in range(1, 5):
                dx = direction * distance
                shifted = [(x + dx, y) for x, y in component]
                if any(x < 0 or x >= image.width for x, _ in shifted):
                    continue
                blocked = False
                for x, y in shifted:
                    dst = (y * image.width + x) * 4
                    if out[dst + 3] != 0 and (x, y) not in component_set:
                        blocked = True
                        break
                if blocked:
                    continue

                candidate = bytearray(out)
                saved = []
                for x, y in component:
                    src = (y * image.width + x) * 4
                    saved.append(bytes(candidate[src : src + 4]))
                    candidate[src : src + 4] = b"\x00\x00\x00\x00"
                for (x, y), color in zip(shifted, saved):
                    dst = (y * image.width + x) * 4
                    candidate[dst : dst + 4] = color
                candidate_image = Image(image.width, image.height, bytes(candidate))
                if len(opaque_components(candidate_image)) < len(
                    opaque_components(Image(image.width, image.height, bytes(out)))
                ):
                    out = candidate
                    moved = True
                    break
            if moved:
                break

    return Image(image.width, image.height, bytes(out))


def infer_preset(image: Image) -> SwayPreset:
    _, top, _, bottom = opaque_bounds(image)
    height = bottom - top
    if height <= 4:
        return PRESETS["tiny"]
    if height <= 6:
        return PRESETS["small"]
    if height <= 7:
        return PRESETS["medium"]
    return PRESETS["large"]


def frame_position(frame_index: int, frame_count: int, preset: SwayPreset) -> int:
    return min(preset.positions - 1, (frame_index * preset.positions) // frame_count)


def generate_frame(
    base: Image, frame_index: int, frame_count: int, amplitude: int, preset: SwayPreset
) -> Image:
    _ = amplitude
    position = frame_position(frame_index, frame_count, preset)
    bounds = opaque_bounds(base)
    out = bytearray(base.width * base.height * 4)
    for y in range(base.height):
        for x in range(base.width):
            src = (y * base.width + x) * 4
            if base.pixels[src + 3] == 0:
                continue
            x_shift = shift_for_pixel(position, x, y, bounds, preset)
            dst_x = clamp(x + x_shift, 0, base.width - 1)
            dst_y = y
            dst = (dst_y * base.width + dst_x) * 4
            out[dst : dst + 4] = base.pixels[src : src + 4]
    return reconnect_grass_pixels(Image(base.width, base.height, bytes(out)))


def collect_palette(frames: list[Image]) -> list[tuple[int, int, int, int]]:
    palette = [(0, 0, 0, 0)]
    seen = {palette[0]}
    for frame in frames:
        for index in range(0, len(frame.pixels), 4):
            color = tuple(frame.pixels[index : index + 4])
            if color[3] == 0:
                continue
            if color not in seen:
                palette.append(color)
                seen.add(color)
    if len(palette) > 256:
        raise ValueError("GIF preview supports up to 256 colors")
    size = 1
    while size < len(palette):
        size *= 2
    size = max(2, size)
    palette.extend([(0, 0, 0, 255)] * (size - len(palette)))
    return palette


def lzw_encode(indices: list[int], min_code_size: int) -> bytes:
    clear = 1 << min_code_size
    end = clear + 1
    code_size = min_code_size + 1
    bit_buffer = 0
    bit_count = 0
    out = bytearray()

    def write_code(code: int) -> None:
        nonlocal bit_buffer, bit_count
        bit_buffer |= code << bit_count
        bit_count += code_size
        while bit_count >= 8:
            out.append(bit_buffer & 0xFF)
            bit_buffer >>= 8
            bit_count -= 8

    write_code(clear)
    codes_since_clear = 0
    # Emit literal pixel codes and reset before the decoder needs a wider
    # code size. This is less compressed, but robust and tiny enough for
    # 16x16 preview GIFs.
    max_literal_codes = max(1, (1 << code_size) - (end + 1))
    for index in indices:
        write_code(index)
        codes_since_clear += 1
        if codes_since_clear >= max_literal_codes:
            write_code(clear)
            codes_since_clear = 0
    write_code(end)
    if bit_count:
        out.append(bit_buffer & 0xFF)
    return bytes(out)


def write_subblocks(file, data: bytes) -> None:
    for offset in range(0, len(data), 255):
        chunk = data[offset : offset + 255]
        file.write(bytes([len(chunk)]))
        file.write(chunk)
    file.write(b"\x00")


def write_gif(path: Path, frames: list[Image], fps: int) -> None:
    preview_frames = frames
    palette = collect_palette(preview_frames)
    palette_lookup = {color: index for index, color in enumerate(palette)}
    table_size_power = int(math.log2(len(palette)))
    packed = 0x80 | ((7) << 4) | (table_size_power - 1)
    delay = max(1, round(100 / fps))
    min_code_size = max(2, table_size_power)

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as file:
        file.write(b"GIF89a")
        file.write(preview_frames[0].width.to_bytes(2, "little"))
        file.write(preview_frames[0].height.to_bytes(2, "little"))
        file.write(bytes([packed, 0, 0]))
        for r, g, b, _ in palette:
            file.write(bytes([r, g, b]))
        file.write(b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00")
        for frame in preview_frames:
            file.write(b"\x21\xf9\x04")
            # Transparent index 0, dispose previous frame to background so
            # transparent pixels do not accumulate in preview viewers.
            file.write(bytes([0x09]))
            file.write(delay.to_bytes(2, "little"))
            file.write(b"\x00\x00")
            file.write(b"\x2c\x00\x00\x00\x00")
            file.write(frame.width.to_bytes(2, "little"))
            file.write(frame.height.to_bytes(2, "little"))
            file.write(b"\x00")
            indices = []
            for index in range(0, len(frame.pixels), 4):
                color = tuple(frame.pixels[index : index + 4])
                indices.append(0 if color[3] == 0 else palette_lookup[color])
            file.write(bytes([min_code_size]))
            write_subblocks(file, lzw_encode(indices, min_code_size))
        file.write(b"\x3b")


def write_frames(frames: list[Image], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for old in output_dir.glob("*.png"):
        old.unlink()
    for index, frame in enumerate(frames, start=1):
        write_png_rgba(output_dir / f"{index}.png", frame)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input", type=Path, required=True, help="single foreground grass PNG"
    )
    parser.add_argument(
        "--output-root", type=Path, default=Path("assets/generated/foreground")
    )
    parser.add_argument("--name", required=True)
    parser.add_argument("--frames", type=int, default=42)
    parser.add_argument("--fps", type=int, default=24)
    parser.add_argument("--preset", choices=["auto", *PRESETS.keys()], default="auto")
    parser.add_argument(
        "--amplitude",
        type=int,
        default=3,
        help="reserved for future presets; grass1 preset uses fixed positions",
    )
    parser.add_argument("--mirror", action="store_true", help="force mirrored output")
    parser.add_argument("--no-mirror", action="store_true", help="skip mirrored output")
    parser.add_argument("--no-gif", action="store_true")
    args = parser.parse_args()

    base, crop_x, crop_y = normalize_stamp_canvas(read_png_rgba(args.input), args.input)
    preset = infer_preset(base) if args.preset == "auto" else PRESETS[args.preset]
    write_mirror = preset.mirror
    if args.mirror:
        write_mirror = True
    if args.no_mirror:
        write_mirror = False

    normal = [
        generate_frame(base, index, args.frames, args.amplitude, preset)
        for index in range(args.frames)
    ]

    normal_dir = args.output_root / args.name
    mirror_dir = args.output_root / f"{args.name}_mirror"
    write_frames(normal, normal_dir)
    mirrored = []
    if write_mirror:
        mirrored_base = mirror_image(base)
        mirrored = [
            generate_frame(mirrored_base, index, args.frames, args.amplitude, preset)
            for index in range(args.frames)
        ]
        write_frames(mirrored, mirror_dir)
    elif mirror_dir.exists():
        shutil.rmtree(mirror_dir)
    metadata = {
        "source": str(args.input),
        "frames": args.frames,
        "fps": args.fps,
        "preset": preset.name,
        "positions": preset.positions,
        "maxOperation": preset.max_operation,
        "rootLockRows": preset.root_lock_rows,
        "anchorX": 8,
        "anchorY": 8,
        "width": base.width,
        "height": base.height,
        "cropX": crop_x,
        "cropY": crop_y,
        "normal": str(normal_dir),
        "mirror": str(mirror_dir) if write_mirror else None,
        "pingPongPreview": False,
    }
    (normal_dir / "sway.json").write_text(json.dumps(metadata, indent=2) + "\n")
    if write_mirror:
        (mirror_dir / "sway.json").write_text(json.dumps(metadata, indent=2) + "\n")

    if not args.no_gif:
        write_gif(normal_dir / f"{args.name}.gif", normal, args.fps)
        if write_mirror:
            write_gif(mirror_dir / f"{args.name}_mirror.gif", mirrored, args.fps)
    if write_mirror:
        print(
            f"generated {args.frames} {preset.name} frames each: {normal_dir} and {mirror_dir}"
        )
    else:
        print(f"generated {args.frames} {preset.name} frames: {normal_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
