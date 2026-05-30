const gba = @import("gba");
const build_options = @import("build_options");

const enabled = build_options.dev_hud;
const timer_index = 3;
const ticks_per_second = 16_384;
const first_object = 126;
const base_tile: u10 = 1000;
const screen_width = 240;

var palette_bank: u4 = 0;
var digit_tiles: [10]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 10;
var last_timer: u16 = 0;
var tick_accum: u32 = 0;
var frame_count: u16 = 0;
var value: u8 = 0;

pub fn init(object_palette_bank: u4) void {
    if (!enabled) return;
    palette_bank = object_palette_bank;

    digit_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 10;
    const rows = [_][7]u8{
        .{ 0b11111, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b11111 },
        .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        .{ 0b11110, 0b00001, 0b00001, 0b11110, 0b10000, 0b10000, 0b11111 },
        .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 },
        .{ 0b10010, 0b10010, 0b10010, 0b11111, 0b00010, 0b00010, 0b00010 },
        .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110 },
        .{ 0b01111, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
        .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
        .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
        .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b11110 },
    };
    for (rows, 0..) |digit_rows, digit| {
        for (digit_rows, 0..) |row, y| {
            var x: usize = 0;
            while (x < 5) : (x += 1) {
                if ((row & (@as(u8, 1) << @intCast(4 - x))) != 0) {
                    setDigitPixel(digit, @intCast(x + 1), @intCast(y), 1);
                }
            }
        }
    }
    gba.display.memcpyObjectTiles4Bpp(base_tile, &digit_tiles);
    gba.timers[timer_index] = gba.Timer.init(0, .{});
    gba.timers[timer_index] = gba.Timer.init(0, .{
        .freq = .cycles_1024,
        .enable = true,
    });
    last_timer = gba.timers[timer_index].counter;
}

pub fn update() void {
    if (!enabled) return;

    const current = gba.timers[timer_index].counter;
    const delta = current -% last_timer;
    last_timer = current;
    tick_accum += delta;
    frame_count += 1;
    while (tick_accum >= ticks_per_second) {
        tick_accum -= ticks_per_second;
        value = @intCast(@min(frame_count, 99));
        frame_count = 0;
    }

    drawDigit(0, value / 10);
    drawDigit(1, value % 10);
}

fn drawDigit(slot: usize, digit: u8) void {
    gba.display.objects[first_object + slot] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(screen_width - 16 + @as(i16, @intCast(slot * 8))),
        .y = objY(0),
        .base_tile = base_tile + @as(u10, digit),
        .priority = 0,
        .palette = palette_bank,
    });
}

fn setDigitPixel(digit: usize, x: u8, y: u8, color: u8) void {
    const byte_index = @as(usize, y) * 4 + @as(usize, x) / 2;
    if ((x & 1) == 0) {
        digit_tiles[digit].data_8[byte_index] = (digit_tiles[digit].data_8[byte_index] & 0xf0) | color;
    } else {
        digit_tiles[digit].data_8[byte_index] = (digit_tiles[digit].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn objX(x: i16) u9 {
    if (x < -64) return 240;
    if (x < 0) return @intCast(512 + x);
    if (x > 511) return 511;
    return @intCast(x);
}

fn objY(y: i16) u8 {
    if (y < -64) return 160;
    if (y < 0) return @intCast(256 + y);
    if (y > 255) return 255;
    return @intCast(y);
}
