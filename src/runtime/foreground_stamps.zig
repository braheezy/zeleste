const gba = @import("gba");
const assets = @import("assets.zig");
const camera_mod = @import("camera.zig");
const falling_blocks = @import("falling_blocks.zig");
const level = @import("../generated_rooms.zig");
const oam = @import("oam.zig");
const room_data = @import("room_data.zig");

const Camera = camera_mod.Camera;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const grass1_tiles_data align(4) = assets.grass1_tiles_data;
const grass1_palette_data align(4) = assets.grass1_palette_data;
const grass1_mirror_tiles_data align(4) = assets.grass1_mirror_tiles_data;
const grass2_tiles_data align(4) = assets.grass2_tiles_data;
const grass2_palette_data align(4) = assets.grass2_palette_data;
const grass2_mirror_tiles_data align(4) = assets.grass2_mirror_tiles_data;

pub const occluding_first_object = 8;
pub const max_stamps = 24;
pub const behind_first_object = falling_blocks.first_object + falling_blocks.object_capacity;
pub const base_tile: u10 = 576;

const grass1_frame_count = 42;
const grass1_tiles_per_frame = 4;
const grass2_frame_count = 42;
const grass2_tiles_per_frame = 1;
const anim_speed = 2;
const mirror_base_tile: u10 = base_tile + grass1_frame_count * grass1_tiles_per_frame;
const stamp2_base_tile: u10 = mirror_base_tile + grass1_frame_count * grass1_tiles_per_frame;
const stamp2_mirror_base_tile: u10 = stamp2_base_tile + grass2_frame_count * grass2_tiles_per_frame;
const palette_bank: u4 = 6;
const stamp2_palette_bank: u4 = 7;

const rooms = level.rooms;

const Stamp = struct {
    active: bool = false,
    kind: u8 = 0,
    x: i16 = 0,
    y: i16 = 0,
    phase: u8 = 0,
    flags: u8 = 0,
};

var stamps: [max_stamps]Stamp = [_]Stamp{.{}} ** max_stamps;
var stamp_count: usize = 0;

pub fn loadGraphics() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&grass1_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, stamp2_palette_bank) * 16], @ptrCast(&grass2_palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&grass1_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(mirror_base_tile, @ptrCast(&grass1_mirror_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(stamp2_base_tile, @ptrCast(&grass2_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(stamp2_mirror_base_tile, @ptrCast(&grass2_mirror_tiles_data));
}

pub fn load(room_index: usize) void {
    stamps = [_]Stamp{.{}} ** max_stamps;
    stamp_count = 0;
    hideObjects();

    const data = rooms[room_index].foreground_stamps;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_stamps);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + 8 <= data.len) : ({
        source_index += 1;
        source_offset += 8;
    }) {
        stamps[stamp_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
            .kind = data[source_offset + 4],
            .phase = data[source_offset + 5],
            .flags = data[source_offset + 6],
        };
        stamp_count += 1;
    }
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    var behind_index: usize = 0;
    var occluding_index: usize = 0;
    var source_index: usize = 0;
    while (source_index < stamp_count) : (source_index += 1) {
        const stamp = stamps[source_index];
        if (!stamp.active) continue;
        if (stamp.kind > 1) continue;

        const occludes = (stamp.flags & 4) != 0;
        const object_index = if (occludes)
            occluding_first_object + occluding_index
        else
            behind_first_object + behind_index;
        if (occludes) {
            occluding_index += 1;
        } else {
            behind_index += 1;
        }
        if (occluding_index > max_stamps or behind_index > max_stamps) continue;

        const frame = stampFrame(anim_counter);
        const flip_x = (stamp.flags & 1) != 0;
        const stamp_base_tile: u10 = switch (stamp.kind) {
            1 => if (flip_x) stamp2_mirror_base_tile else stamp2_base_tile,
            else => if (flip_x) mirror_base_tile else base_tile,
        };
        const palette: u4 = switch (stamp.kind) {
            1 => stamp2_palette_bank,
            else => palette_bank,
        };
        const tiles_per_frame: u16 = switch (stamp.kind) {
            1 => grass2_tiles_per_frame,
            else => grass1_tiles_per_frame,
        };
        const object_size = switch (stamp.kind) {
            1 => gba.display.Object.Size.size_8x8,
            else => gba.display.Object.Size.size_16x16,
        };
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = object_size,
            .x = objX(stamp.x - camera.x),
            .y = objY(stamp.y - camera.y),
            .base_tile = stamp_base_tile + @as(u10, @intCast(frame * tiles_per_frame)),
            .priority = if (occludes) 0 else 1,
            .palette = palette,
            .flip = gba.math.Vec2B.init(false, (stamp.flags & 2) != 0),
        });
    }

    var index: usize = occluding_index;
    while (index < max_stamps) : (index += 1) {
        hideObject(occluding_first_object + index);
    }
    index = behind_index;
    while (index < max_stamps) : (index += 1) {
        hideObject(behind_first_object + index);
    }
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < max_stamps) : (index += 1) {
        hideObject(occluding_first_object + index);
        hideObject(behind_first_object + index);
    }
}

pub fn behindObjectCount() usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < stamp_count) : (index += 1) {
        const stamp = stamps[index];
        if (!stamp.active or stamp.kind > 1 or (stamp.flags & 4) != 0) continue;
        count += 1;
    }
    return count;
}

fn stampFrame(anim_counter: u16) u16 {
    const forward_frames = grass1_frame_count;
    const cycle = forward_frames * 2 - 2;
    const tick = (anim_counter / anim_speed) % cycle;
    if (tick < forward_frames) return tick;
    return cycle - tick;
}
