const gba = @import("gba");
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const oam = @import("oam.zig");
const player_mod = @import("player.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const absI16 = math.absI16;
const objX = oam.objX;
const objY = oam.objY;
const hideObject = oam.hideObject;

pub const base_tile: u10 = 106;
pub const shadow_palette_bank: u4 = 12;
pub const shadow_palette_count = 3;
pub const effect_palette_bank: u4 = shadow_palette_bank + shadow_palette_count;
pub const tile_count = 16;

const afterimage_life: u8 = 14;
const afterimage_first_object = 0;
const afterimage_count = 3;
const burst_object = afterimage_first_object + afterimage_count;

const Afterimage = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    life: u8 = 0,
    facing_left: bool = false,
    dir_x: i16 = 0,
    dir_y: i16 = 0,
};

const Burst = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    life: u8 = 0,
    flip_x: bool = false,
    flip_y: bool = false,
};

var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var afterimages: [afterimage_count]Afterimage = [_]Afterimage{.{}} ** afterimage_count;
var burst: Burst = .{};

pub fn loadPalettes() void {
    fillShadowPalette(shadow_palette_bank, gba.ColorRgb555.rgb(2, 8, 15), gba.ColorRgb555.rgb(5, 17, 25), gba.ColorRgb555.rgb(8, 22, 31));
    fillShadowPalette(shadow_palette_bank + 1, gba.ColorRgb555.rgb(3, 11, 19), gba.ColorRgb555.rgb(6, 20, 29), gba.ColorRgb555.rgb(10, 25, 31));
    fillShadowPalette(shadow_palette_bank + 2, gba.ColorRgb555.rgb(5, 15, 24), gba.ColorRgb555.rgb(9, 24, 31), gba.ColorRgb555.rgb(14, 28, 31));

    const effect_base = @as(usize, effect_palette_bank) * 16;
    gba.display.obj_palette.colors[effect_base] = .black;
    gba.display.obj_palette.colors[effect_base + 1] = gba.ColorRgb555.rgb(2, 10, 18);
    gba.display.obj_palette.colors[effect_base + 2] = gba.ColorRgb555.rgb(5, 20, 30);
    gba.display.obj_palette.colors[effect_base + 3] = .white;
    gba.display.obj_palette.colors[effect_base + 4] = gba.ColorRgb555.rgb(11, 27, 31);
}

pub fn loadTile() void {
    writeTile(0, 0);
}

pub fn spawnAfterimage(player: Player) void {
    var slot: usize = 0;
    var index: usize = 0;
    while (index < afterimage_count) : (index += 1) {
        if (!afterimages[index].active) {
            slot = index;
            break;
        }
        if (afterimages[index].life < afterimages[slot].life) {
            slot = index;
        }
    }

    afterimages[slot] = .{
        .active = true,
        .x = player.x,
        .y = player.y,
        .life = afterimage_life,
        .facing_left = player.facing_left,
        .dir_x = player.dash_dir_x,
        .dir_y = player.dash_dir_y,
    };
}

pub fn spawnBurst(player: Player) void {
    const dir_x: i16 = player.dash_dir_x;
    const dir_y: i16 = player.dash_dir_y;
    const draw_x = fixedToPixel(player.x) + player_mod.draw_offset_x;
    const draw_y = fixedToPixel(player.y) + player_mod.draw_offset_y;
    writeTile(dir_x, dir_y);
    burst = .{
        .active = true,
        .x = draw_x,
        .y = draw_y,
        .life = 10,
    };
}

pub fn update() void {
    var index: usize = 0;
    while (index < afterimage_count) : (index += 1) {
        if (!afterimages[index].active) continue;
        if (afterimages[index].life > 0) {
            afterimages[index].life -= 1;
        }
        if (afterimages[index].life == 0) {
            afterimages[index].active = false;
        }
    }
    if (burst.active) {
        if (burst.life > 0) {
            burst.life -= 1;
        }
        if (burst.life == 0) {
            burst.active = false;
        }
    }
}

pub fn clear() void {
    afterimages = [_]Afterimage{.{}} ** afterimage_count;
    burst = .{};
    var index: usize = 0;
    while (index < afterimage_count) : (index += 1) {
        hideObject(afterimage_first_object + index);
    }
    hideObject(burst_object);
}

pub fn draw(camera: Camera) void {
    var index: usize = 0;
    while (index < afterimage_count) : (index += 1) {
        const object_index = afterimage_first_object + index;
        const image = afterimages[index];
        if (!image.active) {
            hideObject(object_index);
            continue;
        }
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = .size_32x32,
            .x = objX(fixedToPixel(image.x) + player_mod.draw_offset_x - camera.x),
            .y = objY(fixedToPixel(image.y) + player_mod.draw_offset_y - camera.y),
            .base_tile = 0,
            .priority = 1,
            .palette = afterimagePalette(image.life),
            .flip = gba.math.Vec2B.init(image.facing_left, false),
        });
    }

    if (burst.active) {
        gba.display.objects[burst_object] = gba.display.Object.init(.{
            .size = .size_32x32,
            .x = objX(burst.x - camera.x),
            .y = objY(burst.y - camera.y),
            .base_tile = base_tile,
            .priority = 2,
            .palette = effect_palette_bank,
            .flip = gba.math.Vec2B.init(burst.flip_x, burst.flip_y),
        });
    } else {
        hideObject(burst_object);
    }
}

fn fillShadowPalette(bank: u4, dark: gba.ColorRgb555, mid: gba.ColorRgb555, light: gba.ColorRgb555) void {
    const shadow_base = @as(usize, bank) * 16;
    gba.display.obj_palette.colors[shadow_base] = .black;
    var index: usize = 0;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[shadow_base + index] = if (index == 1)
            dark
        else if (index < 5)
            mid
        else
            light;
    }
}

fn writeTile(dir_x: i16, dir_y: i16) void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;

    const sx: i16 = if (dir_x == 0 and dir_y == 0) 1 else dir_x;
    const sy: i16 = dir_y;
    const back_x = -sx;
    const back_y = -sy;
    const perp_x = -sy;
    const perp_y = sx;
    const center_x: i16 = 16;
    const center_y: i16 = 18;

    drawDisc(center_x + back_x * 4, center_y + back_y * 4, 5, 1);
    drawDisc(center_x + back_x * 4, center_y + back_y * 4, 4, 2);
    drawDisc(center_x + back_x * 8 + perp_x * 2, center_y + back_y * 6 + perp_y * 2, 3, 2);
    drawDisc(center_x + back_x + perp_x * 3, center_y + back_y + perp_y * 2, 2, 4);
    drawDisc(center_x + back_x * 11 - perp_x * 2, center_y + back_y * 8 - perp_y, 2, 4);
    setPixel(center_x + back_x * 13 + perp_x * 4, center_y + back_y * 9 + perp_y * 3, 4);
    setPixel(center_x + back_x * 10 - perp_x * 4, center_y + back_y * 7 - perp_y * 3, 2);

    if (dir_x != 0 or dir_y != 0) {
        drawStreak(dir_x, dir_y);
    }
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
}

fn drawStreak(dir_x: i16, dir_y: i16) void {
    const center_x: i16 = 16;
    const center_y: i16 = 18;
    const tail: i16 = 18;
    const tip: i16 = 5;
    const perp_x: i16 = -dir_y;
    const perp_y: i16 = dir_x;
    const start_x = center_x - dir_x * tail;
    const start_y = center_y - dir_y * tail;
    const end_x = center_x + dir_x * tip;
    const end_y = center_y + dir_y * tip;
    drawLine(start_x, start_y, end_x, end_y, 3);
    drawLine(start_x + perp_x, start_y + perp_y, end_x + perp_x, end_y + perp_y, 3);
    setPixel(start_x + perp_x * 4, start_y + perp_y * 4, 3);
}

fn drawDisc(center_x: i16, center_y: i16, radius: i16, color: u8) void {
    var y: i16 = -radius;
    while (y <= radius) : (y += 1) {
        var x: i16 = -radius;
        while (x <= radius) : (x += 1) {
            if (x * x + y * y <= radius * radius) {
                setPixel(center_x + x, center_y + y, color);
            }
        }
    }
}

fn drawLine(x0_input: i16, y0_input: i16, x1: i16, y1: i16, color: u8) void {
    var x0 = x0_input;
    var y0 = y0_input;
    const dx = absI16(x1 - x0);
    const sx: i16 = if (x0 < x1) 1 else -1;
    const dy = -absI16(y1 - y0);
    const sy: i16 = if (y0 < y1) 1 else -1;
    var err = dx + dy;
    while (true) {
        setPixel(x0, y0, color);
        setPixel(x0 + 1, y0, color);
        if (x0 == x1 and y0 == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y0 += sy;
        }
    }
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= 32 or y < 0 or y >= 32) return;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    const tile_index = tile_y * 4 + tile_x;
    const local_x: usize = @intCast(x & 7);
    const local_y: usize = @intCast(y & 7);
    const byte_index = local_y * 4 + local_x / 2;
    if ((local_x & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xF0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0F) | (color << 4);
    }
}

fn afterimagePalette(life: u8) u4 {
    if (life > 9) return shadow_palette_bank;
    if (life > 4) return shadow_palette_bank + 1;
    return shadow_palette_bank + 2;
}
