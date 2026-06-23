const gba = @import("gba");

const assets = @import("../core/assets.zig");
const background = @import("background.zig");
const video = @import("../core/video.zig");

const screen_width_tiles = 30;
const screen_height_tiles = 20;
const city_nap_source_width_tiles = 32;
const city_nap_source_height_tiles = 18;
const city_nap_crop_tile_x = 1;
const city_nap_dest_tile_y = 1;
const black_color_index: u8 = 255;
const title_shadow_color_index: u8 = 253;
const title_text_color_index: u8 = 254;
const title_text = "CHAPTER COMPLETE";
const title_scale: i16 = 3;
const title_y: i16 = 12;
const title_shadow_offset: i16 = 2;

const city_nap_tiles_data align(4) = assets.city_nap_ending_tiles_data;
const city_nap_map_data align(4) = assets.city_nap_ending_map_data;
const city_nap_palette_data align(4) = assets.city_nap_ending_palette_data;
const font_masks_data align(4) = assets.bitmap_font_masks_data;
const font_meta = assets.bitmap_font_meta;

var screen_tiles: [screen_width_tiles * screen_height_tiles]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** (screen_width_tiles * screen_height_tiles);

pub fn loadCityNap() void {
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

    gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&city_nap_palette_data), city_nap_palette_data.len);
    gba.display.bg_palette.colors[title_shadow_color_index] = gba.ColorRgb555.rgb(1, 2, 7);
    gba.display.bg_palette.colors[title_text_color_index] = gba.ColorRgb555.rgb(30, 30, 31);
    gba.display.bg_palette.colors[black_color_index] = .black;
    rebuildCityNapScreenTiles();
    drawChapterCompleteTitle();
    gba.display.memcpyBackgroundTiles8Bpp(0, &screen_tiles);
    drawSequentialMap();
    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = false,
        .obj = false,
    });
}

fn rebuildCityNapScreenTiles() void {
    var dest_y: usize = 0;
    while (dest_y < screen_height_tiles) : (dest_y += 1) {
        var dest_x: usize = 0;
        while (dest_x < screen_width_tiles) : (dest_x += 1) {
            const dest_tile = dest_y * screen_width_tiles + dest_x;
            if (dest_y < city_nap_dest_tile_y or dest_y >= city_nap_dest_tile_y + city_nap_source_height_tiles) {
                fillTile(dest_tile, black_color_index);
                continue;
            }
            const source_x = dest_x + city_nap_crop_tile_x;
            const source_y = dest_y - city_nap_dest_tile_y;
            copySourceTile(dest_tile, source_x, source_y);
        }
    }
}

fn fillTile(destination_tile: usize, color: u8) void {
    var index: usize = 0;
    while (index < 64) : (index += 1) {
        screen_tiles[destination_tile].data_8[index] = color;
    }
}

fn copySourceTile(destination_tile: usize, source_x: usize, source_y: usize) void {
    if (source_x >= city_nap_source_width_tiles or source_y >= city_nap_source_height_tiles) {
        fillTile(destination_tile, black_color_index);
        return;
    }

    const map_offset = (source_y * city_nap_source_width_tiles + source_x) * 2;
    const raw_entry = @as(u16, city_nap_map_data[map_offset]) |
        (@as(u16, city_nap_map_data[map_offset + 1]) << 8);
    const source_tile = @as(usize, raw_entry & 0x03ff);
    const flip_x = (raw_entry & 0x0400) != 0;
    const flip_y = (raw_entry & 0x0800) != 0;
    const source_offset = source_tile * 64;

    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            const read_x = if (flip_x) 7 - x else x;
            const read_y = if (flip_y) 7 - y else y;
            screen_tiles[destination_tile].data_8[y * 8 + x] =
                city_nap_tiles_data[source_offset + read_y * 8 + read_x];
        }
    }
}

fn drawChapterCompleteTitle() void {
    const title_width = textPixelWidth(title_text, title_scale);
    const title_x = @divTrunc(video.screen_width - title_width, 2);
    drawFontLine(title_text, title_x + title_shadow_offset, title_y + title_shadow_offset, title_scale, title_shadow_color_index);
    drawFontLine(title_text, title_x, title_y, title_scale, title_text_color_index);
}

fn textPixelWidth(source: []const u8, scale: i16) i16 {
    var width: i16 = 0;
    for (source) |ch| {
        width += if (ch == ' ') scale * 2 else (@as(i16, font_meta.glyph_width) + 1) * scale;
    }
    if (width > 0) width -= scale;
    return width;
}

fn drawFontLine(source: []const u8, x: i16, y: i16, scale: i16, color: u8) void {
    var cursor = x;
    for (source) |ch| {
        if (ch == ' ') {
            cursor += scale * 2;
            continue;
        }
        drawFontGlyph(ch, cursor, y, scale, color);
        cursor += (@as(i16, font_meta.glyph_width) + 1) * scale;
    }
}

fn drawFontGlyph(input: u8, x: i16, y: i16, scale: i16, color: u8) void {
    const glyph = glyphIndex(input) orelse return;
    const glyph_offset = glyph * font_meta.glyph_height;
    var row: usize = 0;
    while (row < font_meta.glyph_height) : (row += 1) {
        const bits = font_masks_data[glyph_offset + row];
        var col: usize = 0;
        while (col < font_meta.glyph_width) : (col += 1) {
            if ((bits & (@as(u8, 1) << @intCast(font_meta.glyph_width - 1 - col))) == 0) continue;
            drawScaledPixel(x + @as(i16, @intCast(col)) * scale, y + @as(i16, @intCast(row)) * scale, scale, color);
        }
    }
}

fn drawScaledPixel(x: i16, y: i16, scale: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < scale) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < scale) : (xx += 1) {
            setPixel(x + xx, y + yy, color);
        }
    }
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= video.screen_width or y >= video.screen_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const tile_x = ux / 8;
    const tile_y = uy / 8;
    const tile_index = tile_y * screen_width_tiles + tile_x;
    const byte_index = (uy & 7) * 8 + (ux & 7);
    screen_tiles[tile_index].data_8[byte_index] = color;
}

fn glyphIndex(input: u8) ?usize {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    for (font_meta.chars, 0..) |candidate, index| {
        if (candidate == ch) return index;
    }
    return null;
}

fn drawSequentialMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    var index: usize = 0;
    while (index < video.bg_hardware_width_tiles * video.bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < screen_height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < screen_width_tiles) : (x += 1) {
            const tile_index: u16 = @intCast(y * screen_width_tiles + x);
            entries[background.normalBgMapIndex(x, y, video.bg_hardware_width_tiles)] = @bitCast(tile_index);
        }
    }
}
