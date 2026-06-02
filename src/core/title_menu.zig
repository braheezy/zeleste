const gba = @import("gba");

const assets = @import("assets.zig");
const background = @import("../world/background.zig");
const frame = @import("frame.zig");
const video = @import("video.zig");

const tiles_data align(4) = assets.title_screen_tiles_data;
const map_data align(4) = assets.title_screen_map_data;
const palette_data align(4) = assets.title_screen_palette_data;
const font_masks_data align(4) = assets.bitmap_font_masks_data;
const font_meta = assets.bitmap_font_meta;

const width_tiles = 30;
const height_tiles = 20;
const screen_tile_count = width_tiles * height_tiles;

const prompt_shadow: u8 = 249;
const prompt_color: u8 = 250;
const prompt_x: i16 = 105;
const prompt_y: i16 = 149;
const prompt_scale: i16 = 1;
const prompt_advance: i16 = 4;
const blink_period_frames: u16 = 96;
const blink_visible_frames: u16 = 62;

var screen_tiles: [screen_tile_count]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** screen_tile_count;

pub fn showAndWait() void {
    loadScreen();
    render(true);

    var input: gba.input.BufferedKeysState = .{};
    var confirm_released = false;
    var tick: u16 = 0;
    var prompt_visible = true;
    while (true) {
        input.poll();
        if (!input.isPressed(.A)) confirm_released = true;
        if (confirm_released and input.isJustPressed(.A)) return;

        tick = (tick + 1) % blink_period_frames;
        const next_prompt_visible = tick < blink_visible_frames;
        if (next_prompt_visible != prompt_visible) {
            prompt_visible = next_prompt_visible;
            render(prompt_visible);
        }

        frame.syncFrontend();
    }
}

fn loadScreen() void {
    gba.display.hideAllObjects();
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    background.clearParallaxMap();
    background.resetRoomStream();
    background.resetParallaxStream();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 0,
        .base_screenblock = video.bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });

    loadPalette();
    drawMap();
    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = false,
        .obj = false,
    });
}

fn loadPalette() void {
    gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&palette_data), palette_data.len);
    gba.display.bg_palette.colors[prompt_shadow] = gba.ColorRgb555.rgb(3, 4, 9);
    gba.display.bg_palette.colors[prompt_color] = gba.ColorRgb555.rgb(19, 22, 31);
}

fn render(prompt_visible: bool) void {
    rebuildScreenTiles();
    if (prompt_visible) {
        drawFontLine("PRESS A", prompt_x + 1, prompt_y + 1, prompt_shadow);
        drawFontLine("PRESS A", prompt_x, prompt_y, prompt_color);
    }
    gba.display.memcpyBackgroundTiles8Bpp(0, &screen_tiles);
}

fn rebuildScreenTiles() void {
    var tile_y: usize = 0;
    while (tile_y < height_tiles) : (tile_y += 1) {
        var tile_x: usize = 0;
        while (tile_x < width_tiles) : (tile_x += 1) {
            const map_offset = (tile_y * width_tiles + tile_x) * 2;
            const raw_entry = @as(u16, map_data[map_offset]) |
                (@as(u16, map_data[map_offset + 1]) << 8);
            copySourceTile(tile_y * width_tiles + tile_x, raw_entry);
        }
    }
}

fn copySourceTile(destination_tile: usize, raw_entry: u16) void {
    const source_tile = @as(usize, raw_entry & 0x03ff);
    const flip_x = (raw_entry & 0x0400) != 0;
    const flip_y = (raw_entry & 0x0800) != 0;
    const source_offset = source_tile * 64;

    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            const source_x = if (flip_x) 7 - x else x;
            const source_y = if (flip_y) 7 - y else y;
            screen_tiles[destination_tile].data_8[y * 8 + x] =
                tiles_data[source_offset + source_y * 8 + source_x];
        }
    }
}

fn drawMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    var index: usize = 0;
    while (index < video.bg_hardware_width_tiles * video.bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < width_tiles) : (x += 1) {
            const tile_index: u16 = @intCast(y * width_tiles + x);
            entries[background.normalBgMapIndex(x, y, video.bg_hardware_width_tiles)] = @bitCast(tile_index);
        }
    }
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= video.screen_width or y >= video.screen_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const tile_x = ux / 8;
    const tile_y = uy / 8;
    const tile_index = tile_y * width_tiles + tile_x;
    const byte_index = (uy & 7) * 8 + (ux & 7);
    screen_tiles[tile_index].data_8[byte_index] = color;
}

fn drawFontLine(source: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (source) |ch| {
        drawFontGlyph(ch, cursor, y, color);
        cursor += prompt_advance;
    }
}

fn drawFontGlyph(input: u8, x: i16, y: i16, color: u8) void {
    const glyph = glyphIndex(input) orelse return;
    const glyph_offset = glyph * font_meta.glyph_height;
    var row: usize = 0;
    while (row < font_meta.glyph_height) : (row += 1) {
        const bits = font_masks_data[glyph_offset + row];
        var col: usize = 0;
        while (col < font_meta.glyph_width) : (col += 1) {
            if ((bits & (@as(u8, 1) << @intCast(font_meta.glyph_width - 1 - col))) == 0) continue;
            drawScaledPixel(x + @as(i16, @intCast(col)) * prompt_scale, y + @as(i16, @intCast(row)) * prompt_scale, color);
        }
    }
}

fn drawScaledPixel(x: i16, y: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < prompt_scale) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < prompt_scale) : (xx += 1) {
            setPixel(x + xx, y + yy, color);
        }
    }
}

fn glyphIndex(input: u8) ?usize {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    if (ch == ' ') return null;
    for (font_meta.chars, 0..) |candidate, index| {
        if (candidate == ch) return index;
    }
    return null;
}
