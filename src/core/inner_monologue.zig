const gba = @import("gba");
const mm = @import("maxmod");

const audio = @import("audio.zig");
const background = @import("../world/background.zig");
const oam = @import("oam.zig");
const video = @import("video.zig");

const width_tiles = 30;
const height_tiles = 20;

const gradient_color_start: u8 = 1;
const gradient_color_count: usize = 48;
const text_shadow: u8 = 252;
const text_color: u8 = 253;
const snow_base_tile: u10 = 0;
const snow_tile_count = 3;
const snow_palette_bank: u4 = 0;
const snow_first_object: usize = 0;
const snow_color_dim: u4 = 1;
const snow_color_mid: u4 = 2;
const snow_color_bright: u4 = 3;

const fade_in_frames: u16 = 44;
const hold_frames: u16 = 108;
const fade_out_frames: u16 = 44;
const screen_frames: u16 = fade_in_frames + hold_frames + fade_out_frames;
const gap_frames: u16 = 12;
const snow_count: usize = 44;
const text_scale: i16 = 2;
const text_y: i16 = 73;
const text_band_top: usize = 63;
const text_band_bottom: usize = 99;

const Color = struct {
    r: u5,
    g: u5,
    b: u5,
};

const prologue_intro_lines = [_][]const u8{
    "This is it, Madeline.",
    "Just breathe.",
    "Why are you so nervous?",
};

const snow_tiles: [snow_tile_count]gba.display.Tile4Bpp align(4) = .{
    gba.display.Tile4Bpp.init(.{
        0, 0,    0, 0,
        0, 0,    0, 0,
        0, 0,    0, 0,
        0, 0x10, 0, 0,
        0, 0,    0, 0,
        0, 0,    0, 0,
        0, 0,    0, 0,
        0, 0,    0, 0,
    }),
    gba.display.Tile4Bpp.init(.{
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0x20, 0x02, 0,
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0,    0,    0,
    }),
    gba.display.Tile4Bpp.init(.{
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0x30, 0,    0,
        0, 0x33, 0x03, 0,
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0,    0,    0,
        0, 0,    0,    0,
    }),
};

pub fn showPrologueIntro() void {
    show(&prologue_intro_lines);
}

pub fn show(lines: []const []const u8) void {
    audio.stopSoundEffects();
    audio.stopMusic();
    loadScreen();

    var input: gba.input.BufferedKeysState = .{};
    var confirm_released = false;
    var snow_tick: u16 = 0;

    for (lines, 0..) |line, line_index| {
        prepareLine(line);
        if (line_index == 0) enableDisplay();
        var local_frame: u16 = 0;
        while (local_frame < screen_frames) {
            input.poll();
            const confirm_down = input.isPressed(.A) or input.isPressed(.B) or input.isPressed(.start);
            if (!confirm_down) confirm_released = true;
            if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.B) or input.isJustPressed(.start))) {
                local_frame = fade_in_frames + hold_frames;
            }

            syncFrame();
            setTextPalette(textAlpha(local_frame));
            drawSnowObjects(snow_tick);

            local_frame += 1;
            snow_tick +%= 1;
        }

        if (line_index + 1 < lines.len) {
            prepareLine("");
            var gap: u16 = 0;
            while (gap < gap_frames) : (gap += 1) {
                input.poll();
                syncFrame();
                setTextPalette(0);
                drawSnowObjects(snow_tick);
                snow_tick +%= 1;
            }
        }
    }
    hideSnowObjects();
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
    drawBackground();
    loadSnowObjects();
    drawSnowObjects(0);
    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
}

fn enableDisplay() void {
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = false,
        .obj = true,
    });
}

fn loadPalette() void {
    var index: usize = 0;
    while (index < 256) : (index += 1) {
        gba.display.bg_palette.colors[index] = .black;
    }

    index = 0;
    while (index < gradient_color_count) : (index += 1) {
        gba.display.bg_palette.colors[@as(usize, gradient_color_start) + index] = gradientColor(index);
    }

    setTextPalette(0);
}

fn prepareLine(line: []const u8) void {
    clearTextBand();
    setTextPalette(0);
    if (line.len == 0) return;

    const x = @divTrunc(video.screen_width - textPixelWidth(line), 2);
    drawTextLine(line, x + 2, text_y + 2, text_shadow);
    drawTextLine(line, x, text_y, text_color);
}

fn drawBackground() void {
    var tile_y: usize = 0;
    while (tile_y < height_tiles) : (tile_y += 1) {
        var tile_x: usize = 0;
        while (tile_x < width_tiles) : (tile_x += 1) {
            const tile_index = tile_y * width_tiles + tile_x;
            var local_y: usize = 0;
            while (local_y < 8) : (local_y += 1) {
                var local_x: usize = 0;
                while (local_x < 8) : (local_x += 2) {
                    const x = tile_x * 8 + local_x;
                    const y = tile_y * 8 + local_y;
                    const left = backgroundColorIndex(x, y);
                    const right = backgroundColorIndex(x + 1, y);
                    gba.display.bg_blocks.tiles_8bpp[tile_index].data_16[local_y * 4 + local_x / 2] =
                        @as(u16, left) | (@as(u16, right) << 8);
                }
            }
        }
    }
}

fn clearTextBand() void {
    var y: usize = text_band_top;
    while (y < text_band_bottom) : (y += 1) {
        var x: usize = 0;
        while (x < video.screen_width) : (x += 2) {
            const left = backgroundColorIndex(x, y);
            const right = backgroundColorIndex(x + 1, y);
            setPixelPair(x, y, left, right);
        }
    }
}

fn backgroundColorIndex(x: usize, y: usize) u8 {
    const vertical = @divTrunc(y * gradient_color_count, video.screen_height);
    const diagonal = @divTrunc(x * 9, video.screen_width);
    const soft_wave = @divTrunc((x / 6 + y / 9) % 12, 3);
    const color_index = (vertical + diagonal + soft_wave) % gradient_color_count;
    return gradient_color_start + @as(u8, @intCast(color_index));
}

fn loadSnowObjects() void {
    const base = @as(usize, snow_palette_bank) * 16;
    gba.display.obj_palette.colors[base + 0] = .black;
    gba.display.obj_palette.colors[base + snow_color_dim] = gba.ColorRgb555.rgb(12, 16, 23);
    gba.display.obj_palette.colors[base + snow_color_mid] = gba.ColorRgb555.rgb(19, 23, 28);
    gba.display.obj_palette.colors[base + snow_color_bright] = gba.ColorRgb555.rgb(27, 29, 31);
    gba.display.memcpyObjectTiles4Bpp(snow_base_tile, &snow_tiles);
}

fn drawSnowObjects(tick: u16) void {
    var index: usize = 0;
    while (index < snow_count) : (index += 1) {
        const speed: u16 = 1 + @as(u16, @intCast(index & 3));
        const base_x: u16 = @intCast((index * 41 + 17) % video.screen_width);
        const drift_phase: u16 = @intCast((@as(usize, tick / 3) + index * 7) % 32);
        const drift = @as(i16, @intCast(drift_phase)) - 16;
        var x = @as(i16, @intCast(base_x)) + drift;
        while (x < 0) : (x += video.screen_width) {}
        while (x >= video.screen_width) : (x -= video.screen_width) {}

        const y_cycle: u16 = video.screen_height + 18;
        const y_raw: u16 = (@as(u16, @intCast(index * 29 + 5)) + tick * speed) % y_cycle;
        const y = @as(i16, @intCast(y_raw)) - 10;

        gba.display.objects[snow_first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = oam.objX(x),
            .y = oam.objY(y),
            .base_tile = snow_base_tile + @as(u10, @intCast(index % snow_tile_count)),
            .priority = 0,
            .palette = snow_palette_bank,
        });
    }
}

fn hideSnowObjects() void {
    var index: usize = 0;
    while (index < snow_count) : (index += 1) {
        oam.hideObject(snow_first_object + index);
    }
}

fn textAlpha(local_frame: u16) u8 {
    if (local_frame < fade_in_frames) {
        return @intCast(@divTrunc(local_frame * 16, fade_in_frames));
    }
    if (local_frame < fade_in_frames + hold_frames) return 16;

    const fade_frame = local_frame - fade_in_frames - hold_frames;
    if (fade_frame >= fade_out_frames) return 0;
    return @intCast(16 - @divTrunc(fade_frame * 16, fade_out_frames));
}

fn setTextPalette(alpha: u8) void {
    gba.display.bg_palette.colors[text_shadow] = mixColor(.{ .r = 1, .g = 1, .b = 5 }, .{ .r = 4, .g = 4, .b = 10 }, alpha, 16);
    gba.display.bg_palette.colors[text_color] = mixColor(.{ .r = 5, .g = 6, .b = 12 }, .{ .r = 27, .g = 29, .b = 31 }, alpha, 16);
}

fn gradientColor(index: usize) gba.ColorRgb555 {
    const purple = Color{ .r = 4, .g = 2, .b = 11 };
    const pink = Color{ .r = 12, .g = 3, .b = 13 };
    const green = Color{ .r = 2, .g = 10, .b = 8 };
    const violet = Color{ .r = 7, .g = 4, .b = 14 };

    if (index < 16) {
        return mixColor(purple, pink, @intCast(index), 15);
    }
    if (index < 32) {
        return mixColor(pink, green, @intCast(index - 16), 15);
    }
    return mixColor(green, violet, @intCast(index - 32), 15);
}

fn mixColor(a: Color, b: Color, amount: u8, max_amount: u8) gba.ColorRgb555 {
    return gba.ColorRgb555.rgb(
        mixChannel(a.r, b.r, amount, max_amount),
        mixChannel(a.g, b.g, amount, max_amount),
        mixChannel(a.b, b.b, amount, max_amount),
    );
}

fn mixChannel(a: u5, b: u5, amount: u8, max_amount: u8) u5 {
    const max_u16 = @as(u16, max_amount);
    const amount_u16 = @as(u16, amount);
    const mixed = (@as(u16, a) * (max_u16 - amount_u16) + @as(u16, b) * amount_u16) / max_u16;
    return @intCast(mixed);
}

fn textPixelWidth(source: []const u8) i16 {
    var width: i16 = 0;
    for (source, 0..) |ch, index| {
        width += glyphAdvance(ch) * text_scale;
        width += spacingAfter(source, index);
    }
    return width;
}

fn drawTextLine(source: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (source, 0..) |ch, index| {
        if (ch != ' ') drawGlyph(ch, cursor, y, color);
        cursor += glyphAdvance(ch) * text_scale + spacingAfter(source, index);
    }
}

fn spacingAfter(source: []const u8, index: usize) i16 {
    if (index + 1 >= source.len) return 0;
    if (source[index] == ' ' or source[index + 1] == ' ') return 0;
    return 1;
}

fn glyphAdvance(ch: u8) i16 {
    return switch (ch) {
        ' ', ',', '.', '\'' => 4,
        'i', 'l', 'I' => 4,
        else => 5,
    };
}

fn drawGlyph(ch: u8, x: i16, y: i16, color: u8) void {
    const rows = glyphRows(ch);
    for (rows, 0..) |row_bits, row| {
        var col: usize = 0;
        while (col < 5) : (col += 1) {
            if ((row_bits & (@as(u8, 1) << @intCast(4 - col))) == 0) continue;
            drawScaledPixel(x + @as(i16, @intCast(col)) * text_scale, y + @as(i16, @intCast(row)) * text_scale, color);
        }
    }
}

fn drawScaledPixel(x: i16, y: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < text_scale) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < text_scale) : (xx += 1) {
            setPixel(x + xx, y + yy, color);
        }
    }
}

fn glyphRows(ch: u8) [7]u8 {
    return switch (ch) {
        'A' => .{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'B' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 },
        'C' => .{ 0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111 },
        'D' => .{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 },
        'E' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 },
        'F' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 },
        'G' => .{ 0b01111, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110 },
        'H' => .{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'I' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111 },
        'J' => .{ 0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100 },
        'K' => .{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
        'L' => .{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 },
        'M' => .{ 0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001 },
        'N' => .{ 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001 },
        'O' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'P' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 },
        'Q' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 },
        'R' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 },
        'S' => .{ 0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110 },
        'U' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'V' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100 },
        'T' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
        'W' => .{ 0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010 },
        'X' => .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001 },
        'Y' => .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100 },
        'Z' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111 },
        'a' => .{ 0, 0b01110, 0b00001, 0b01111, 0b10001, 0b10011, 0b01101 },
        'b' => .{ 0b10000, 0b10000, 0b10110, 0b11001, 0b10001, 0b10001, 0b11110 },
        'c' => .{ 0, 0, 0b01110, 0b10000, 0b10000, 0b10001, 0b01110 },
        'd' => .{ 0b00001, 0b00001, 0b01101, 0b10011, 0b10001, 0b10001, 0b01111 },
        'e' => .{ 0, 0b01110, 0b10001, 0b11111, 0b10000, 0b10001, 0b01110 },
        'f' => .{ 0b00110, 0b01000, 0b11100, 0b01000, 0b01000, 0b01000, 0b01000 },
        'g' => .{ 0, 0b01111, 0b10001, 0b10001, 0b01111, 0b00001, 0b01110 },
        'h' => .{ 0b10000, 0b10000, 0b10110, 0b11001, 0b10001, 0b10001, 0b10001 },
        'i' => .{ 0b00100, 0, 0b01100, 0b00100, 0b00100, 0b00100, 0b01110 },
        'j' => .{ 0b00010, 0, 0b00110, 0b00010, 0b00010, 0b10010, 0b01100 },
        'k' => .{ 0b10000, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
        'l' => .{ 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        'm' => .{ 0, 0, 0b11010, 0b10101, 0b10101, 0b10101, 0b10101 },
        'n' => .{ 0, 0, 0b10110, 0b11001, 0b10001, 0b10001, 0b10001 },
        'o' => .{ 0, 0, 0b01110, 0b10001, 0b10001, 0b10001, 0b01110 },
        'p' => .{ 0, 0, 0b11110, 0b10001, 0b11110, 0b10000, 0b10000 },
        'q' => .{ 0, 0, 0b01111, 0b10001, 0b01111, 0b00001, 0b00001 },
        'r' => .{ 0, 0, 0b10110, 0b11001, 0b10000, 0b10000, 0b10000 },
        's' => .{ 0, 0b01111, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110 },
        't' => .{ 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0b00100, 0b00011 },
        'u' => .{ 0, 0, 0b10001, 0b10001, 0b10001, 0b10011, 0b01101 },
        'v' => .{ 0, 0, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100 },
        'w' => .{ 0, 0, 0b10001, 0b10001, 0b10101, 0b10101, 0b01010 },
        'x' => .{ 0, 0, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001 },
        'y' => .{ 0, 0, 0b10001, 0b10001, 0b01111, 0b00001, 0b01110 },
        'z' => .{ 0, 0, 0b11111, 0b00010, 0b00100, 0b01000, 0b11111 },
        '0' => .{ 0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110 },
        '1' => .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        '2' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b10000, 0b10000, 0b11111 },
        '3' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 },
        '4' => .{ 0b10010, 0b10010, 0b10010, 0b11111, 0b00010, 0b00010, 0b00010 },
        '5' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110 },
        '6' => .{ 0b01111, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
        '7' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
        '8' => .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
        '9' => .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b11110 },
        '.' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01100 },
        ',' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01000 },
        '?' => .{ 0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0, 0b00100 },
        '!' => .{ 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0, 0b00100 },
        '\'' => .{ 0b00100, 0b00100, 0b01000, 0, 0, 0, 0 },
        '"' => .{ 0b01010, 0b01010, 0, 0, 0, 0, 0 },
        '-' => .{ 0, 0, 0, 0b11110, 0, 0, 0 },
        ':' => .{ 0, 0b01100, 0b01100, 0, 0b01100, 0b01100, 0 },
        '/' => .{ 0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000 },
        else => .{ 0, 0, 0, 0, 0, 0, 0 },
    };
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= video.screen_width or y >= video.screen_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    setPixelUnchecked(ux, uy, color);
}

fn setPixelUnchecked(ux: usize, uy: usize, color: u8) void {
    const tile_x = ux / 8;
    const tile_y = uy / 8;
    const tile_index = tile_y * width_tiles + tile_x;
    const local_x = ux & 7;
    const halfword_index = (uy & 7) * 4 + local_x / 2;
    const old_value = gba.display.bg_blocks.tiles_8bpp[tile_index].data_16[halfword_index];
    gba.display.bg_blocks.tiles_8bpp[tile_index].data_16[halfword_index] = if ((local_x & 1) == 0)
        (old_value & 0xff00) | color
    else
        (old_value & 0x00ff) | (@as(u16, color) << 8);
}

fn setPixelPair(x: usize, y: usize, left: u8, right: u8) void {
    const tile_x = x / 8;
    const tile_y = y / 8;
    const tile_index = tile_y * width_tiles + tile_x;
    const halfword_index = (y & 7) * 4 + (x & 7) / 2;
    gba.display.bg_blocks.tiles_8bpp[tile_index].data_16[halfword_index] =
        @as(u16, left) | (@as(u16, right) << 8);
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

fn syncFrame() void {
    audio.keepMusicLooping();
    mm.gba.frame();
    gba.bios.vblankIntrWait();
}
