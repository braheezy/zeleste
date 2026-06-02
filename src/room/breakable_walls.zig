const collision = @import("../world/collision.zig");
const dust = @import("../effects/dust.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");

const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const rooms = level.rooms;

pub const max_walls = 16;

const record_bytes = 8;
const invalid_room_index = ~@as(usize, 0);

const Wall = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    source_index: u8 = 0,
};

var walls: [max_walls]Wall = [_]Wall{.{}} ** max_walls;
var wall_count: usize = 0;
var loaded_room_index: usize = invalid_room_index;
var broken_masks: [rooms.len]u16 = [_]u16{0} ** rooms.len;

pub fn load(room_index: usize) void {
    walls = [_]Wall{.{}} ** max_walls;
    wall_count = 0;
    loaded_room_index = room_index;

    const data = rooms[room_index].breakable_walls;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_walls);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;
        walls[wall_count] = .{
            .active = !isBroken(room_index, source_index),
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
            .source_index = @intCast(source_index),
        };
        wall_count += 1;
    }
}

pub fn solidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    const right = x + width;
    const bottom = y + height;
    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        const wall = walls[index];
        if (!wall.active) continue;
        if (collision.rectsOverlap(x, y, right, bottom, wall.x, wall.y, wallRight(wall), wallBottom(wall))) {
            return true;
        }
    }
    return false;
}

pub fn tryBreakDashCollision(player: *Player, room_index: usize) bool {
    if (room_index != loaded_room_index or player.dash_timer == 0) return false;
    if (player.dash_dir_x == 0 and player.dash_dir_y == 0) return false;

    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    const end_x = fixedToPixel(player.x + player.vx);
    const end_y = fixedToPixel(player.y + player.vy);

    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        if (!walls[index].active) continue;
        if (!dashSweepsWall(player.*, start_x, start_y, end_x, end_y, walls[index])) continue;

        breakWall(room_index, index);
        return true;
    }
    return false;
}

pub fn bgTileBroken(room_index: usize, tile_x: i16, tile_y: i16) bool {
    if (tile_x < 0 or tile_y < 0 or room_index >= rooms.len) return false;
    const mask = broken_masks[room_index];
    if (mask == 0) return false;

    const data = rooms[room_index].breakable_walls;
    if (data.len < 2) return false;

    const count = @min(readU16Le(data, 0), max_walls);
    const pixel_x = tile_x * 8;
    const pixel_y = tile_y * 8;
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        if (!isBroken(room_index, source_index)) continue;
        const x = readI16Le(data, source_offset);
        const y = readI16Le(data, source_offset + 2);
        const w: i16 = @intCast(data[source_offset + 4]);
        const h: i16 = @intCast(data[source_offset + 5]);
        if (pixel_x >= x and pixel_x < x + w and pixel_y >= y and pixel_y < y + h) return true;
    }
    return false;
}

pub fn clearTransient() void {
    if (loaded_room_index == invalid_room_index) return;
    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        if (!isBroken(loaded_room_index, walls[index].source_index)) {
            walls[index].active = true;
        }
    }
}

fn breakWall(room_index: usize, wall_index: usize) void {
    const wall = &walls[wall_index];
    if (!wall.active) return;
    wall.active = false;
    markBroken(room_index, wall.source_index);
    dust.spawnBreakableWallSmoke(wall.x, wall.y, wall.w, wall.h);
}

fn dashSweepsWall(player: Player, start_x: i16, start_y: i16, end_x: i16, end_y: i16, wall: Wall) bool {
    const start_left = start_x;
    const start_top = start_y;
    const start_right = start_x + player_mod.body_width;
    const start_bottom = start_y + player_mod.body_height;
    const end_left = end_x;
    const end_top = end_y;
    const end_right = end_x + player_mod.body_width;
    const end_bottom = end_y + player_mod.body_height;
    const sweep_left = @min(start_left, end_left);
    const sweep_top = @min(start_top, end_top);
    const sweep_right = @max(start_right, end_right);
    const sweep_bottom = @max(start_bottom, end_bottom);
    if (!collision.rectsOverlap(sweep_left, sweep_top, sweep_right, sweep_bottom, wall.x, wall.y, wallRight(wall), wallBottom(wall))) {
        return false;
    }

    if (collision.rectsOverlap(end_left, end_top, end_right, end_bottom, wall.x, wall.y, wallRight(wall), wallBottom(wall))) {
        return true;
    }
    if (player.dash_dir_x > 0 and start_right <= wall.x and end_right >= wall.x) return true;
    if (player.dash_dir_x < 0 and start_left >= wallRight(wall) and end_left <= wallRight(wall)) return true;
    if (player.dash_dir_y > 0 and start_bottom <= wall.y and end_bottom >= wall.y) return true;
    if (player.dash_dir_y < 0 and start_top >= wallBottom(wall) and end_top <= wallBottom(wall)) return true;
    return false;
}

fn wallRight(wall: Wall) i16 {
    return wall.x + @as(i16, @intCast(wall.w));
}

fn wallBottom(wall: Wall) i16 {
    return wall.y + @as(i16, @intCast(wall.h));
}

fn isBroken(room_index: usize, source_index: usize) bool {
    if (room_index >= rooms.len or source_index >= max_walls) return false;
    const mask = @as(u16, 1) << @as(u4, @intCast(source_index));
    return (broken_masks[room_index] & mask) != 0;
}

fn markBroken(room_index: usize, source_index: usize) void {
    if (room_index >= rooms.len or source_index >= max_walls) return;
    const mask = @as(u16, 1) << @as(u4, @intCast(source_index));
    broken_masks[room_index] |= mask;
}
