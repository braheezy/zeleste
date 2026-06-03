const gba = @import("gba");
const level = @import("../../generated_rooms.zig");
const camera_mod = @import("../../world/camera.zig");
const dash_effects = @import("../../player/dash_effects.zig");
const oam = @import("../../core/oam.zig");

const Camera = camera_mod.Camera;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const Origin = struct {
    x: i16,
    y: i16,
};

pub const base_tile: u10 = dash_effects.base_tile + 16;
pub const object_count = 3;

const tiles_per_object = 4;
const tile_count = 12;
const palette_bank: u4 = 3;
const soft_color: u4 = 9;
const cycle_frames: u8 = 96;

const rooms = level.rooms;
const room_index = level.roomIndexFor(level.chapter_index, "2") orelse rooms.len;
const origin = Origin{ .x = 194, .y = 49 };

var counter: u8 = 0;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var uploaded_counter: u8 = 0xff;

pub fn loadPalette() void {
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + @as(usize, soft_color)] = gba.ColorRgb555.rgb(25, 28, 29);
}

pub fn reset(first_object: usize) void {
    counter = 0;
    uploaded_counter = 0xff;
    hideObjects(first_object);
}

pub fn update(active_room_index: usize, anim_counter: u16, first_object: usize) void {
    if (!active(active_room_index)) {
        hideObjects(first_object);
        return;
    }
    if ((anim_counter & 1) != 0) return;
    counter +%= 1;
}

pub fn draw(camera: Camera, active_room_index: usize, first_object: usize) void {
    if (!active(active_room_index)) {
        hideObjects(first_object);
        return;
    }

    const upload_tiles = counter != uploaded_counter;
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        const particle_age = age(index);
        if (upload_tiles) {
            clearTile(index);
            drawShape(index, particle_age, index);
        }

        const rise: i16 = @intCast(particle_age / 5);
        const draw_x = origin.x + wobble(particle_age, index) - camera.x - 8;
        const draw_y = origin.y - rise - camera.y - 8;
        gba.display.objects[first_object + index] = gba.display.Object.init(.{
            .size = .size_16x16,
            .x = objX(draw_x),
            .y = objY(draw_y),
            .base_tile = base_tile + @as(u10, @intCast(index * tiles_per_object)),
            .priority = 1,
            .palette = palette_bank,
        });
    }

    if (upload_tiles) {
        gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
        uploaded_counter = counter;
    }
}

pub fn hideObjects(first_object: usize) void {
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        hideObject(first_object + index);
    }
}

fn active(active_room_index: usize) bool {
    return active_room_index == room_index;
}

fn age(index: usize) u8 {
    const offset = @as(u16, @intCast(index)) * (@as(u16, cycle_frames) / object_count);
    return @intCast((@as(u16, counter) + offset) % cycle_frames);
}

fn wobble(particle_age: u8, index: usize) i16 {
    const phase = ((@as(usize, particle_age) / 16) + index) & 3;
    return switch (phase) {
        0 => 0,
        1 => 1,
        2 => 0,
        else => 0,
    };
}

fn drawShape(tile_index: usize, particle_age: u8, variant: usize) void {
    const x_shift: i16 = if (((@as(usize, particle_age) / 24) + variant) & 1 == 0) 0 else 1;
    const stage = particle_age / 24;
    switch (stage) {
        0 => {
            const cx: i16 = 7 + x_shift;
            drawDisc(tile_index, cx, 10, 3, soft_color);
            drawPixelBlock(tile_index, cx, 10, 1);
            setTilePixel(tile_index, cx - 2, 10, 1);
            setTilePixel(tile_index, cx + 2, 9, soft_color);
            setTilePixel(tile_index, cx - 3, 11, soft_color);
        },
        1 => {
            const cx: i16 = 7 + x_shift;
            drawDisc(tile_index, cx, 8, 4, soft_color);
            drawDisc(tile_index, cx + 2, 9, 2, soft_color);
            drawPixelBlock(tile_index, cx, 8, 1);
            setTilePixel(tile_index, cx - 1, 7, 1);
            setTilePixel(tile_index, cx + 2, 8, 1);
            setTilePixel(tile_index, cx - 3, 10, soft_color);
            setTilePixel(tile_index, cx + 4, 10, soft_color);
        },
        2 => {
            const cx: i16 = 8 - x_shift;
            drawDisc(tile_index, cx, 7, 4, soft_color);
            drawDisc(tile_index, cx - 3, 8, 2, soft_color);
            setTilePixel(tile_index, cx, 7, 1);
            setTilePixel(tile_index, cx - 1, 7, 1);
            setTilePixel(tile_index, cx + 1, 6, 1);
            setTilePixel(tile_index, cx + 3, 7, soft_color);
            setTilePixel(tile_index, cx - 4, 9, soft_color);
        },
        else => {
            const cx: i16 = 7 + x_shift;
            drawDisc(tile_index, cx, 6, 2, soft_color);
            setTilePixel(tile_index, cx - 3, 7, soft_color);
            setTilePixel(tile_index, cx + 3, 6, soft_color);
            if (particle_age < 64) {
                setTilePixel(tile_index, cx, 6, 1);
                setTilePixel(tile_index, cx + 1, 7, soft_color);
            }
        },
    }
}

fn drawPixelBlock(tile_index: usize, x: i16, y: i16, color: u4) void {
    setTilePixel(tile_index, x, y, color);
    setTilePixel(tile_index, x + 1, y, color);
    setTilePixel(tile_index, x, y + 1, color);
    setTilePixel(tile_index, x + 1, y + 1, color);
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

fn clearTile(tile_index: usize) void {
    const first_tile = tile_index * tiles_per_object;
    var local_tile: usize = 0;
    while (local_tile < tiles_per_object) : (local_tile += 1) {
        var byte_index: usize = 0;
        while (byte_index < 32) : (byte_index += 1) {
            tiles[first_tile + local_tile].data_8[byte_index] = 0;
        }
    }
}

fn setTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 16 or y < 0 or y >= 16) return;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    const local_x: i16 = @intCast(@mod(x, 8));
    const local_y: i16 = @intCast(@mod(y, 8));
    const object_tile_index = tile_index * tiles_per_object + tile_y * 2 + tile_x;
    const pixel_index: u8 = @intCast(local_y * 8 + local_x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        tiles[object_tile_index].data_8[byte_index] = (tiles[object_tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        tiles[object_tile_index].data_8[byte_index] = (tiles[object_tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}
