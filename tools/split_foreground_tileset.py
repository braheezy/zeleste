#!/usr/bin/env python3
"""Split the downloaded Celeste foreground atlas into grid-aligned islands.

This intentionally uses only the Python standard library so it can run before
we settle the rest of the asset-tool dependencies. It supports non-interlaced
8-bit RGBA and indexed-color PNGs.
"""

from __future__ import annotations

import argparse
import os
import struct
import zlib
from collections import deque
from dataclasses import dataclass
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


@dataclass(frozen=True)
class Image:
    width: int
    height: int
    pixels: bytes


@dataclass(frozen=True)
class Component:
    min_cell_x: int
    min_cell_y: int
    max_cell_x: int
    max_cell_y: int
    occupied_cells: int

    @property
    def width_cells(self) -> int:
        return self.max_cell_x - self.min_cell_x + 1

    @property
    def height_cells(self) -> int:
        return self.max_cell_y - self.min_cell_y + 1


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png_rgba(path: Path) -> Image:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path} is not a PNG")

    pos = len(PNG_SIGNATURE)
    width = height = None
    compressed = bytearray()
    color_type = bit_depth = None
    palette: list[tuple[int, int, int, int]] = []
    transparency: bytes = b""

    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        payload = data[pos + 8 : pos + 8 + length]
        pos += 12 + length

        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if bit_depth != 8 or color_type not in (3, 6) or compression != 0 or filter_method != 0 or interlace != 0:
                raise ValueError(
                    f"{path} must be non-interlaced 8-bit RGBA or indexed-color PNG; "
                    f"got bit_depth={bit_depth}, color_type={color_type}, interlace={interlace}"
                )
        elif kind == b"PLTE":
            if len(payload) % 3 != 0:
                raise ValueError(f"{path} has invalid PLTE length")
            palette = [(payload[i], payload[i + 1], payload[i + 2], 255) for i in range(0, len(payload), 3)]
        elif kind == b"tRNS":
            transparency = payload
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break

    if width is None or height is None:
        raise ValueError(f"{path} has no IHDR")
    if color_type == 3:
        if not palette:
            raise ValueError(f"{path} is indexed-color but has no PLTE")
        palette = [
            (r, g, b, transparency[index] if index < len(transparency) else a)
            for index, (r, g, b, a) in enumerate(palette)
        ]

    raw = zlib.decompress(bytes(compressed))
    source_bpp = 4 if color_type == 6 else 1
    source_stride = width * source_bpp
    recon_rows = bytearray(height * source_stride)
    src = 0

    for y in range(height):
        filter_type = raw[src]
        src += 1
        scanline = bytearray(raw[src : src + source_stride])
        src += source_stride
        prev_row = recon_rows[(y - 1) * source_stride : y * source_stride] if y else bytes(source_stride)

        for x in range(source_stride):
            left = scanline[x - source_bpp] if x >= source_bpp else 0
            up = prev_row[x]
            up_left = prev_row[x - source_bpp] if x >= source_bpp else 0
            if filter_type == 0:
                recon = scanline[x]
            elif filter_type == 1:
                recon = (scanline[x] + left) & 0xFF
            elif filter_type == 2:
                recon = (scanline[x] + up) & 0xFF
            elif filter_type == 3:
                recon = (scanline[x] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                recon = (scanline[x] + paeth(left, up, up_left)) & 0xFF
            else:
                raise ValueError(f"unsupported PNG filter {filter_type} on row {y}")
            scanline[x] = recon

        recon_rows[y * source_stride : (y + 1) * source_stride] = scanline

    if color_type == 6:
        return Image(width, height, bytes(recon_rows))

    out = bytearray(width * height * 4)
    for index, palette_index in enumerate(recon_rows):
        if palette_index >= len(palette):
            raise ValueError(f"{path} references palette index {palette_index}, but PLTE has {len(palette)} entries")
        out[index * 4 : index * 4 + 4] = bytes(palette[palette_index])
    return Image(width, height, bytes(out))


def write_png_rgba(path: Path, image: Image) -> None:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    stride = image.width * 4
    raw = bytearray()
    for y in range(image.height):
        raw.append(0)
        raw.extend(image.pixels[y * stride : (y + 1) * stride])

    payload = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    path.write_bytes(
        PNG_SIGNATURE
        + chunk(b"IHDR", payload)
        + chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
        + chunk(b"IEND", b"")
    )


def is_occupied_pixel(pixel: bytes, background: tuple[int, int, int]) -> bool:
    r, g, b, a = pixel
    if a == 0:
        return False
    return (r, g, b) != background


def occupied_grid(image: Image, tile_size: int, background: tuple[int, int, int]) -> list[list[bool]]:
    cells_w = (image.width + tile_size - 1) // tile_size
    cells_h = (image.height + tile_size - 1) // tile_size
    grid = [[False for _ in range(cells_w)] for _ in range(cells_h)]

    for cy in range(cells_h):
        for cx in range(cells_w):
            x0 = cx * tile_size
            y0 = cy * tile_size
            x1 = min(x0 + tile_size, image.width)
            y1 = min(y0 + tile_size, image.height)
            found = False
            for y in range(y0, y1):
                row = y * image.width * 4
                for x in range(x0, x1):
                    if is_occupied_pixel(image.pixels[row + x * 4 : row + x * 4 + 4], background):
                        found = True
                        break
                if found:
                    break
            grid[cy][cx] = found

    return grid


def find_components(grid: list[list[bool]]) -> list[Component]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    seen = [[False for _ in range(w)] for _ in range(h)]
    components: list[Component] = []

    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or not grid[sy][sx]:
                continue

            queue: deque[tuple[int, int]] = deque([(sx, sy)])
            seen[sy][sx] = True
            min_x = max_x = sx
            min_y = max_y = sy
            count = 0

            while queue:
                x, y = queue.popleft()
                count += 1
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    if seen[ny][nx] or not grid[ny][nx]:
                        continue
                    seen[ny][nx] = True
                    queue.append((nx, ny))

            components.append(Component(min_x, min_y, max_x, max_y, count))

    components.sort(key=lambda c: (c.min_cell_y, c.min_cell_x))
    return components


def crop_cells(image: Image, component: Component, tile_size: int, background: tuple[int, int, int]) -> Image:
    x0 = component.min_cell_x * tile_size
    y0 = component.min_cell_y * tile_size
    x1 = min((component.max_cell_x + 1) * tile_size, image.width)
    y1 = min((component.max_cell_y + 1) * tile_size, image.height)
    width = x1 - x0
    height = y1 - y0
    pixels = bytearray(width * height * 4)

    for y in range(height):
        src = ((y0 + y) * image.width + x0) * 4
        dst = y * width * 4
        pixels[dst : dst + width * 4] = image.pixels[src : src + width * 4]

    # Make the atlas gutter transparent in the cropped image. True black art is
    # rare in this source; if that changes, add a mask from the original alpha.
    for i in range(0, len(pixels), 4):
        if pixels[i + 3] != 0 and tuple(pixels[i : i + 3]) == background:
            pixels[i + 3] = 0

    return Image(width, height, bytes(pixels))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--tile-size", type=int, default=8)
    parser.add_argument("--background", default="0,0,0", help="RGB gutter color, e.g. 0,0,0")
    parser.add_argument("--min-cells", type=int, default=2)
    args = parser.parse_args()

    background = tuple(int(part) for part in args.background.split(","))
    if len(background) != 3:
        raise ValueError("--background must have three comma-separated RGB values")

    image = read_png_rgba(args.input)
    grid = occupied_grid(image, args.tile_size, background)  # type: ignore[arg-type]
    components = [c for c in find_components(grid) if c.occupied_cells >= args.min_cells]

    args.output_dir.mkdir(parents=True, exist_ok=True)
    report_lines = [
        f"input: {args.input}",
        f"source_size: {image.width}x{image.height}",
        f"tile_size: {args.tile_size}",
        f"background_rgb: {background[0]},{background[1]},{background[2]}",
        f"components: {len(components)}",
        "",
    ]

    for index, component in enumerate(components):
        crop = crop_cells(image, component, args.tile_size, background)  # type: ignore[arg-type]
        name = f"foreground_type_{index:02d}_{crop.width}x{crop.height}.png"
        write_png_rgba(args.output_dir / name, crop)
        report_lines.append(
            f"{index:02d}: {name} "
            f"cells=({component.min_cell_x},{component.min_cell_y})-({component.max_cell_x},{component.max_cell_y}) "
            f"size={crop.width}x{crop.height} occupied_cells={component.occupied_cells}"
        )

    (args.output_dir / "report.txt").write_text("\n".join(report_lines) + "\n")
    print(f"wrote {len(components)} components to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
