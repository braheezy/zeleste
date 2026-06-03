const gba = @import("gba");
const background = @import("../../world/background.zig");
const camera_mod = @import("../../world/camera.zig");
const falling_blocks = @import("falling_blocks.zig");
const foreground_stamps = @import("../../room/foreground_stamps.zig");
const level = @import("../../generated_rooms.zig");
const oam = @import("../../core/oam.zig");
const room_data = @import("../../world/room_data.zig");

const Camera = camera_mod.Camera;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

pub const base_tile: u10 = 208;
pub const palette_bank: u4 = 3;

const max_chunks = 48;
const rooms = level.rooms;

const Chunk = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    tile_offset: u16 = 0,
    phase: u8 = 0,
    sag: u8 = 0,
};

var chunks: [max_chunks]Chunk = [_]Chunk{.{}} ** max_chunks;
var chunk_count: usize = 0;
var disable_drawing_for_perf_test: bool = false;

pub fn load(room_index: usize, bridge_active: bool) void {
    chunks = [_]Chunk{.{}} ** max_chunks;
    chunk_count = 0;
    hideObjects(bridge_active);

    const room = rooms[room_index];
    const data = room.wires;
    if (data.len < 2) return;
    if (background.roomFitsHardwareBackground(room) and background.canStampStaticRoomWires(room)) return;

    if (room.wire_tiles.len != 0) {
        const tile_count = room.wire_tiles.len / 32;
        const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(room.wire_tiles.ptr);
        gba.display.memcpyObjectTiles4Bpp(base_tile, tiles[0..tile_count]);
    }

    const count = @min(readU16Le(data, 0), max_chunks);
    var offset: usize = 2;
    var index: usize = 0;
    while (index < count and offset + 8 <= data.len) : ({
        index += 1;
        offset += 8;
    }) {
        chunks[chunk_count] = .{
            .active = true,
            .x = readI16Le(data, offset),
            .y = readI16Le(data, offset + 2),
            .tile_offset = readU16Le(data, offset + 4),
            .phase = data[offset + 6],
        };
        chunk_count += 1;
    }
}

pub fn draw(camera: Camera, bridge_active: bool) void {
    if (disable_drawing_for_perf_test) return;
    if (chunk_count == 0) return;

    var index: usize = 0;
    while (index < max_chunks) : (index += 1) {
        const object_index = objectIndex(index, bridge_active) orelse continue;
        if (index >= chunk_count or !chunks[index].active) {
            hideObject(object_index);
            continue;
        }

        const chunk = chunks[index];
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = .size_32x8,
            .x = objX(chunk.x - camera.x),
            .y = objY(chunk.y - camera.y),
            .base_tile = base_tile + @as(u10, @intCast(chunk.tile_offset)),
            .priority = 1,
            .palette = palette_bank,
        });
    }
}

pub fn hideObjects(bridge_active: bool) void {
    const used_falling_objects = falling_blocks.usedObjectCount();
    var index: usize = used_falling_objects;
    while (index < falling_blocks.object_capacity) : (index += 1) {
        hideObject(falling_blocks.first_object + index);
    }

    if (bridge_active) return;
    index = foreground_stamps.behindObjectCount();
    while (index < foreground_stamps.max_stamps) : (index += 1) {
        hideObject(foreground_stamps.behind_first_object + index);
    }
}

fn objectIndex(index: usize, bridge_active: bool) ?usize {
    const used_falling_objects = falling_blocks.usedObjectCount();
    const falling_object_capacity = falling_blocks.object_capacity;
    if (used_falling_objects >= falling_object_capacity) return null;
    const free_falling_objects = falling_object_capacity - used_falling_objects;
    if (index < free_falling_objects) return falling_blocks.first_object + used_falling_objects + index;

    if (bridge_active) return null;
    const behind_count = foreground_stamps.behindObjectCount();
    const behind_index = index - free_falling_objects;
    if (behind_index >= foreground_stamps.max_stamps - behind_count) return null;
    return foreground_stamps.behind_first_object + behind_count + behind_index;
}
