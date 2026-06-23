const gba = @import("gba");

const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dust = @import("../effects/dust.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const ice_tiles_data align(4) = assets.smashable_ice_tiles_data;
const ice_palette_data align(4) = assets.smashable_ice_palette_data;
const ice_6c_tiles_data align(4) = assets.smashable_ice_6c_tiles_data;
const ice_6c_palette_data align(4) = assets.smashable_ice_6c_palette_data;
const ice_7z_tiles_data align(4) = assets.smashable_ice_7z_tiles_data;
const ice_7z_palette_data align(4) = assets.smashable_ice_7z_palette_data;
const dirt_tiles_data align(4) = assets.smashable_dirt_tiles_data;
const dirt_palette_data align(4) = assets.smashable_dirt_palette_data;

const rooms = level.rooms;

pub const max_walls = 16;

pub const DashImpact = struct {
    normal_x: i16 = 0,
    normal_y: i16 = 0,
    dash_dir_x: i16 = 0,
    dash_dir_y: i16 = 0,
    wall_x: i16 = 0,
    wall_y: i16 = 0,
    wall_right: i16 = 0,
    wall_bottom: i16 = 0,
};

const record_bytes = 8;
const invalid_room_index = ~@as(usize, 0);
const impact_shake_frames: u8 = 10;
const sprite_width: i16 = 16;
const sprite_height: i16 = 32;
const ice_wall_height: i16 = 32;
const ice_6c_wall_height: i16 = 24;
const ice_7z_wall_width: i16 = 32;
const ice_7z_wall_height: i16 = 16;
const dirt_wall_height: i16 = 24;
const objects_per_sprite = 1;
const first_object = 120;
const object_capacity = 3;
const ice_base_tile: u10 = @intCast(obj_vram.breakable_ice.start);
const dirt_base_tile: u10 = @intCast(obj_vram.breakable_dirt.start);
const ice_6c_base_tile: u10 = @intCast(obj_vram.breakable_ice_6c.start);
const ice_7z_base_tile: u10 = @intCast(obj_vram.breakable_ice_7z.start);
const ice_palette_bank: u4 = 6;
const dirt_palette_bank: u4 = 7;
const ice_6c_palette_bank: u4 = 8;

const Material = enum(u8) {
    ice = 0,
    dirt = 1,
};

const VisualSpec = struct {
    base_tile: u10,
    palette_bank: u4,
    width: i16,
    height: i16,
    size: gba.display.Object.Size,
};

const Wall = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    material: Material = .ice,
    source_index: u8 = 0,
};

var walls: [max_walls]Wall = [_]Wall{.{}} ** max_walls;
var wall_count: usize = 0;
var loaded_room_index: usize = invalid_room_index;
var broken_masks: [rooms.len]u16 = [_]u16{0} ** rooms.len;
var impact_shake_timer: u8 = 0;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    walls = [_]Wall{.{}} ** max_walls;
    wall_count = 0;
    loaded_room_index = room_index;
    impact_shake_timer = 0;
    hideObjects();

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
            .material = materialFromId(data[source_offset + 6]),
            .source_index = @intCast(source_index),
        };
        wall_count += 1;
    }
}

pub fn loadGraphics() void {
    if (!hasDrawableWalls()) return;
    if (hasDrawableIceSize(sprite_width, ice_wall_height)) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, ice_palette_bank) * 16], @ptrCast(&ice_palette_data), 16);
        gba.display.memcpyObjectTiles4Bpp(ice_base_tile, @ptrCast(&ice_tiles_data));
    }
    if (hasDrawableIceSize(sprite_width, ice_6c_wall_height)) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, ice_6c_palette_bank) * 16], @ptrCast(&ice_6c_palette_data), 16);
        gba.display.memcpyObjectTiles4Bpp(ice_6c_base_tile, @ptrCast(&ice_6c_tiles_data));
    }
    if (hasDrawableIceSize(ice_7z_wall_width, ice_7z_wall_height)) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, ice_palette_bank) * 16], @ptrCast(&ice_7z_palette_data), 16);
        gba.display.memcpyObjectTiles4Bpp(ice_7z_base_tile, @ptrCast(&ice_7z_tiles_data));
    }
    if (hasDrawableMaterial(.dirt)) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, dirt_palette_bank) * 16], @ptrCast(&dirt_palette_data), 16);
        gba.display.memcpyObjectTiles4Bpp(dirt_base_tile, @ptrCast(&dirt_tiles_data));
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

pub fn tryBreakDashCollision(player: *Player, room_index: usize) ?DashImpact {
    if (room_index != loaded_room_index or player.dash_timer == 0) return null;
    if (player.dash_dir_x == 0 and player.dash_dir_y == 0) return null;

    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    const end_x = fixedToPixel(player.x + player.vx);
    const end_y = fixedToPixel(player.y + player.vy);

    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        if (!walls[index].active) continue;
        const impact = dashImpact(player.*, start_x, start_y, end_x, end_y, walls[index]) orelse continue;

        breakWall(room_index, index);
        return impact;
    }
    return null;
}

pub fn bgTileBroken(room_index: usize, tile_x: i16, tile_y: i16) bool {
    _ = room_index;
    _ = tile_x;
    _ = tile_y;
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

pub fn updateImpactShake() void {
    if (impact_shake_timer > 0) {
        impact_shake_timer -= 1;
    }
}

pub fn impactShakeOffset() ?room_data.Spawn {
    if (impact_shake_timer == 0) return null;
    return switch (impact_shake_timer & 3) {
        0 => .{ .x = 1, .y = 0 },
        1 => .{ .x = -1, .y = 0 },
        2 => .{ .x = 0, .y = 1 },
        else => .{ .x = 0, .y = -1 },
    };
}

pub fn draw(camera: Camera) void {
    if (wall_count == 0 and last_drawn_objects == 0) return;

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < wall_count and object_offset + objects_per_sprite <= object_capacity) : (index += 1) {
        const wall = walls[index];
        if (!wall.active) continue;
        const spec = visualSpec(wall) orelse continue;

        const x = wall.x - camera.x;
        const y = wall.y - camera.y;
        if (!visible(x, y, spec.width, spec.height)) continue;

        drawChunk(first_object + object_offset, x, y, spec);
        object_offset += objects_per_sprite;
    }

    const drawn_objects = object_offset;
    const hide_until = @min(last_drawn_objects, object_capacity);
    while (object_offset < hide_until) : (object_offset += 1) {
        hideObject(first_object + object_offset);
    }
    last_drawn_objects = drawn_objects;
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < object_capacity) : (index += 1) {
        hideObject(first_object + index);
    }
    last_drawn_objects = 0;
}

fn breakWall(room_index: usize, wall_index: usize) void {
    const wall = &walls[wall_index];
    if (!wall.active) return;
    wall.active = false;
    markBroken(room_index, wall.source_index);
    impact_shake_timer = impact_shake_frames;
    dust.spawnBreakableWallSmoke(wall.x, wall.y, wall.w, wall.h);
}

fn drawChunk(object_index: usize, x: i16, y: i16, spec: VisualSpec) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = spec.size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = spec.base_tile,
        .priority = 1,
        .palette = spec.palette_bank,
    });
}

fn drawableWall(wall: Wall) bool {
    return visualSpec(wall) != null;
}

fn hasDrawableWalls() bool {
    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        if (walls[index].active and drawableWall(walls[index])) return true;
    }
    return false;
}

fn hasDrawableMaterial(material: Material) bool {
    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        if (!walls[index].active or walls[index].material != material or !drawableWall(walls[index])) continue;
        return true;
    }
    return false;
}

fn hasDrawableIceSize(width: i16, height: i16) bool {
    var index: usize = 0;
    while (index < wall_count) : (index += 1) {
        if (!walls[index].active or walls[index].material != .ice or walls[index].w != width or walls[index].h != height) continue;
        return true;
    }
    return false;
}

fn visualSpec(wall: Wall) ?VisualSpec {
    return switch (wall.material) {
        .ice => if (wall.w == sprite_width) switch (wall.h) {
            ice_wall_height => .{
                .base_tile = ice_base_tile,
                .palette_bank = ice_palette_bank,
                .width = sprite_width,
                .height = sprite_height,
                .size = .size_16x32,
            },
            ice_6c_wall_height => .{
                .base_tile = ice_6c_base_tile,
                .palette_bank = ice_6c_palette_bank,
                .width = sprite_width,
                .height = sprite_height,
                .size = .size_16x32,
            },
            else => null,
        } else if (wall.w == ice_7z_wall_width and wall.h == ice_7z_wall_height) .{
            .base_tile = ice_7z_base_tile,
            .palette_bank = ice_palette_bank,
            .width = ice_7z_wall_width,
            .height = ice_7z_wall_height,
            .size = .size_32x16,
        } else null,
        .dirt => if (wall.h == dirt_wall_height) .{
            .base_tile = dirt_base_tile,
            .palette_bank = dirt_palette_bank,
            .width = sprite_width,
            .height = sprite_height,
            .size = .size_16x32,
        } else null,
    };
}

fn materialFromId(id: u8) Material {
    return switch (id) {
        1 => .dirt,
        else => .ice,
    };
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < 240 and y < 160 and x + width > 0 and y + height > 0;
}

fn dashImpact(player: Player, start_x: i16, start_y: i16, end_x: i16, end_y: i16, wall: Wall) ?DashImpact {
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
        return null;
    }

    var x_normal: i16 = 0;
    var x_dist: i32 = 0;
    var x_total: i32 = 1;
    var has_x = false;
    if (player.dash_dir_x > 0 and start_right <= wall.x and end_right >= wall.x) {
        x_normal = -1;
        x_dist = @as(i32, wall.x - start_right);
        x_total = @max(1, @as(i32, end_right - start_right));
        has_x = true;
    } else if (player.dash_dir_x < 0 and start_left >= wallRight(wall) and end_left <= wallRight(wall)) {
        x_normal = 1;
        x_dist = @as(i32, start_left - wallRight(wall));
        x_total = @max(1, @as(i32, start_left - end_left));
        has_x = true;
    }

    var y_normal: i16 = 0;
    var y_dist: i32 = 0;
    var y_total: i32 = 1;
    var has_y = false;
    if (player.dash_dir_y > 0 and start_bottom <= wall.y and end_bottom >= wall.y) {
        y_normal = -1;
        y_dist = @as(i32, wall.y - start_bottom);
        y_total = @max(1, @as(i32, end_bottom - start_bottom));
        has_y = true;
    } else if (player.dash_dir_y < 0 and start_top >= wallBottom(wall) and end_top <= wallBottom(wall)) {
        y_normal = 1;
        y_dist = @as(i32, start_top - wallBottom(wall));
        y_total = @max(1, @as(i32, start_top - end_top));
        has_y = true;
    }

    var normal_x: i16 = 0;
    var normal_y: i16 = 0;
    if (has_x and has_y) {
        if (x_dist * y_total <= y_dist * x_total) {
            normal_x = x_normal;
        } else {
            normal_y = y_normal;
        }
    } else if (has_x) {
        normal_x = x_normal;
    } else if (has_y) {
        normal_y = y_normal;
    } else if (collision.rectsOverlap(end_left, end_top, end_right, end_bottom, wall.x, wall.y, wallRight(wall), wallBottom(wall))) {
        if (player.dash_dir_x != 0) {
            normal_x = -player.dash_dir_x;
        } else {
            normal_y = -player.dash_dir_y;
        }
    } else {
        return null;
    }

    return .{
        .normal_x = normal_x,
        .normal_y = normal_y,
        .dash_dir_x = player.dash_dir_x,
        .dash_dir_y = player.dash_dir_y,
        .wall_x = wall.x,
        .wall_y = wall.y,
        .wall_right = wallRight(wall),
        .wall_bottom = wallBottom(wall),
    };
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
