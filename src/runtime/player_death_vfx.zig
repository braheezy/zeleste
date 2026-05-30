const gba = @import("gba");
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const oam = @import("oam.zig");
const player_mod = @import("player.zig");
const player_render = @import("player_render.zig");
const video = @import("video.zig");

const Camera = camera_mod.Camera;
const clampI16 = math.clampI16;
const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

pub const Intro = struct {
    first_frame: u16 = 0,
    frame_count: u16 = 0,
    total_frames: u8 = 0,
    player_x: i32 = 0,
    player_y: i32 = 0,
    offset_x: i32 = 0,
    offset_y: i32 = 0,
    facing_left: bool = false,
};

const first_object = 0;
const spoke_count = 8;
const object_count = spoke_count + 1;
const base_tile: u10 = player_render.sweat_base_tile + player_render.sweat_tiles_per_frame;
const palette_bank: u4 = 3;

var tiles: [6]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 6;

pub fn loadTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 6;
    drawDisc(0, 3, 3, 3, 5);
    drawDisc(0, 3, 3, 2, 1);
    setTilePixel(0, 1, 2, 1);
    setTilePixel(0, 2, 1, 1);
    setTilePixel(0, 4, 1, 1);
    setTilePixel(0, 5, 2, 1);
    setTilePixel(0, 1, 4, 1);
    setTilePixel(0, 2, 5, 1);
    setTilePixel(0, 4, 5, 1);
    setTilePixel(0, 5, 4, 1);
    setTilePixel(0, 5, 3, 2);

    drawDisc(1, 3, 3, 3, 5);
    drawDisc(1, 3, 3, 2, 3);
    setTilePixel(1, 1, 2, 3);
    setTilePixel(1, 2, 1, 3);
    setTilePixel(1, 4, 1, 3);
    setTilePixel(1, 5, 2, 3);
    setTilePixel(1, 1, 4, 3);
    setTilePixel(1, 2, 5, 3);
    setTilePixel(1, 4, 5, 3);
    setTilePixel(1, 5, 4, 3);
    setTilePixel(1, 4, 4, 4);

    drawBlob16(2, 1);
    drawBlob16(2, 3);
    setPixel16(2, 8, 8, 4);
    setPixel16(2, 9, 8, 4);
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
}

pub fn drawDeath(camera: Camera, elapsed: u8, origin_x: i32, origin_y: i32, intro: Intro) void {
    if (intro.frame_count != 0 and elapsed < intro.total_frames) {
        drawIntro(camera, intro, elapsed);
        hideObjects();
        return;
    }

    hideObject(player_render.object);
    if (intro.frame_count != 0) {
        drawBalls(camera, origin_x, origin_y, elapsed - intro.total_frames);
        return;
    }

    drawBurst(camera, origin_x, origin_y, elapsed);
}

pub fn drawRespawn(camera: Camera, origin_x: i32, origin_y: i32, respawn_timer: u8) void {
    drawBalls(camera, origin_x, origin_y, respawn_timer + 6);
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        hideObject(first_object + index);
    }
}

fn drawIntro(camera: Camera, intro: Intro, elapsed: u8) void {
    const frame_offset: u16 = @min(
        intro.frame_count - 1,
        @as(u16, elapsed / player_mod.death_intro_frame_hold),
    );
    player_render.loadNormalPalette();
    player_render.loadFrame(intro.first_frame + frame_offset);
    const travel_elapsed = @min(elapsed, intro.total_frames);
    const draw_world_x = intro.player_x + @divTrunc(intro.offset_x * @as(i32, travel_elapsed), @as(i32, intro.total_frames));
    const draw_world_y = intro.player_y + @divTrunc(intro.offset_y * @as(i32, travel_elapsed), @as(i32, intro.total_frames));
    const draw_x = clampI16(fixedToPixel(draw_world_x) - camera.x + player_mod.draw_offset_x, -8, video.screen_width - 24);
    const draw_y = clampI16(fixedToPixel(draw_world_y) - camera.y + player_mod.draw_offset_y, -8, video.screen_height - 32);
    gba.display.objects[player_render.object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = 0,
        .priority = 0,
        .palette = 0,
        .flip = gba.math.Vec2B.init(intro.facing_left, false),
    });
}

fn drawBurst(camera: Camera, origin_x: i32, origin_y: i32, elapsed: u8) void {
    if (elapsed < 3) {
        drawCore(camera, origin_x, origin_y, .size_8x8, base_tile, -4, -4);
        return;
    }
    if (elapsed < 6) {
        drawCore(camera, origin_x, origin_y, .size_8x8, base_tile + 1, -4, -4);
        return;
    }
    if (elapsed < 10) {
        drawCore(camera, origin_x, origin_y, .size_16x16, base_tile + 2, -8, -8);
        return;
    }

    drawBalls(camera, origin_x, origin_y, elapsed - 10);
}

fn drawCore(camera: Camera, origin_x: i32, origin_y: i32, size: gba.display.Object.Size, tile: u10, x_offset: i16, y_offset: i16) void {
    const draw_origin_x = clampI16(fixedToPixel(origin_x) - camera.x - 4, 4, video.screen_width - 12);
    const draw_origin_y = clampI16(fixedToPixel(origin_y) - camera.y - 4, 4, video.screen_height - 12);
    gba.display.objects[first_object] = gba.display.Object.init(.{
        .size = size,
        .x = objX(draw_origin_x + x_offset + 4),
        .y = objY(draw_origin_y + y_offset + 4),
        .base_tile = tile,
        .priority = 0,
        .palette = palette_bank,
    });
    var index: usize = 1;
    while (index < object_count) : (index += 1) {
        hideObject(first_object + index);
    }
}

fn drawBalls(camera: Camera, origin_x: i32, origin_y: i32, progress: u8) void {
    const directions = [_][2]i16{
        .{ 0, -16 },
        .{ 11, -11 },
        .{ 16, 0 },
        .{ 11, 11 },
        .{ 0, 16 },
        .{ -11, 11 },
        .{ -16, 0 },
        .{ -11, -11 },
    };
    const draw_origin_x = clampI16(fixedToPixel(origin_x) - camera.x - 4, 4, video.screen_width - 12);
    const draw_origin_y = clampI16(fixedToPixel(origin_y) - camera.y - 4, 4, video.screen_height - 12);
    const radius: i16 = burstRadius(progress);
    const flash_white = (progress & 0x10) != 0;
    const ball_base_tile: u10 = base_tile + if (flash_white) @as(u10, 0) else @as(u10, 1);

    var index: usize = 0;
    while (index < spoke_count) : (index += 1) {
        const dx = @divTrunc(directions[index][0] * radius, 16);
        const dy = @divTrunc(directions[index][1] * radius, 16);
        gba.display.objects[first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(draw_origin_x + dx),
            .y = objY(draw_origin_y + dy),
            .base_tile = ball_base_tile,
            .priority = 0,
            .palette = palette_bank,
        });
    }
    hideObject(first_object + spoke_count);
}

fn burstRadius(progress: u8) i16 {
    const radii = [_]i16{
        4,  5,  6,  7,  8,  9,  10, 11,
        12, 13, 14, 15, 16, 17, 18, 19,
        20, 20, 21, 21, 22, 22, 23, 23,
        24, 24, 25, 25, 25, 25, 25, 25,
    };
    if (progress < radii.len) return radii[progress];
    return 25;
}

fn drawDisc(tile_index: usize, center_x: i16, center_y: i16, radius: u8, color: u4) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setTilePixel(tile_index, center_x + x, center_y + y, color);
            }
        }
    }
}

fn drawBlob16(first_tile_index: usize, color: u4) void {
    var y: i16 = 1;
    while (y < 15) : (y += 1) {
        var x: i16 = 1;
        while (x < 15) : (x += 1) {
            const dx = x - 8;
            const dy = y - 8;
            if (dx * dx + dy * dy <= 42) {
                setPixel16(first_tile_index, x, y, color);
            }
        }
    }
    setPixel16(first_tile_index, 8, 1, color);
    setPixel16(first_tile_index, 8, 15, color);
    setPixel16(first_tile_index, 1, 8, color);
    setPixel16(first_tile_index, 15, 8, color);
}

fn setPixel16(first_tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 16 or y < 0 or y >= 16) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const tile_x = ux / 8;
    const tile_y = uy / 8;
    const local_x: i16 = @intCast(ux % 8);
    const local_y: i16 = @intCast(uy % 8);
    setTilePixel(first_tile_index + tile_y * 2 + tile_x, local_x, local_y, color);
}

fn setTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8 or tile_index >= tiles.len) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const byte_index = uy * 4 + ux / 2;
    if ((ux & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}
