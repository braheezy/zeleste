const gba = @import("gba");
const assets = @import("../../core/assets.zig");
const camera_mod = @import("../../world/camera.zig");
const collision = @import("../../world/collision.zig");
const dynamic_object_slots = @import("../../room/dynamic_object_slots.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const oam = @import("../../core/oam.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixed_shift = math.fixed_shift;
const pixelToFixed = math.pixelToFixed;
const fixedToPixel = math.fixedToPixel;
const approach = math.approach;
const objX = oam.objX;
const objY = oam.objY;
const hideObject = oam.hideObject;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const tiles_data align(4) = assets.falling_block_tiles_data;
const palette_data align(4) = assets.falling_block_palette_data;

pub const max_blocks = dynamic_object_slots.max_falling_blocks;
pub const first_object = dynamic_object_slots.first_object;
pub const objects_per_block = dynamic_object_slots.falling_objects_per_block;
pub const object_capacity = dynamic_object_slots.object_capacity;

const shake_frames = 18;
const gravity: i32 = 0x58;
const max_fall: i32 = 0x560;
const base_tile: u10 = 32;
const palette_bank: u4 = 1;

const State = enum(u8) {
    idle,
    shaking,
    falling,
    landed,
};

pub const Block = struct {
    active: bool = false,
    state: State = .idle,
    x: i16 = 0,
    y: i32 = 0,
    w: u8 = 0,
    h: u8 = 0,
    max_y: i16 = 0,
    timer: u8 = 0,
    vy: i32 = 0,
};

pub const UpdateResult = struct {
    killed_player: bool = false,
    snow_blocks: [max_blocks]Block = [_]Block{.{}} ** max_blocks,
    snow_count: usize = 0,

    fn addSnow(result: *UpdateResult, block: Block) void {
        if (result.snow_count >= result.snow_blocks.len) return;
        result.snow_blocks[result.snow_count] = block;
        result.snow_count += 1;
    }
};

const rooms = level.rooms;

var blocks: [max_blocks]Block = [_]Block{.{}} ** max_blocks;
var block_count: usize = 0;
var landed_masks: [rooms.len]u8 = [_]u8{0} ** rooms.len;

pub fn loadGraphics() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
}

pub fn load(room_index: usize) void {
    blocks = [_]Block{.{}} ** max_blocks;
    block_count = 0;
    hideObjects();

    const data = rooms[room_index].falling_blocks;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_blocks);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + 10 <= data.len) : ({
        source_index += 1;
        source_offset += 10;
    }) {
        const x = readI16Le(data, source_offset);
        const y = readI16Le(data, source_offset + 2);
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        const max_y = readI16Le(data, source_offset + 6);
        if (w == 0 or h == 0) continue;

        var block = Block{
            .active = true,
            .x = x,
            .y = pixelToFixed(y),
            .w = w,
            .h = h,
            .max_y = max_y - @as(i16, @intCast(h)),
        };

        if (landed(room_index, block_count)) {
            block.y = pixelToFixed(block.max_y);
            block.vy = 0;
            block.state = .landed;
        }

        blocks[block_count] = block;
        block_count += 1;
    }
}

pub fn update(room_index: usize, player: *Player) UpdateResult {
    var result: UpdateResult = .{};
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = &blocks[index];
        if (!block.active) continue;

        switch (block.state) {
            .idle => {
                if (playerBelowBlock(player.*, block.*)) {
                    block.state = .shaking;
                    block.timer = shake_frames;
                }
            },
            .shaking => {
                if (block.timer > 0) {
                    block.timer -= 1;
                } else {
                    result.addSnow(block.*);
                    block.state = .falling;
                    block.vy = 0;
                }
            },
            .falling => {
                const old_x = block.x;
                const old_y = fixedToPixel(block.y);
                block.vy = approach(block.vy, max_fall, gravity);
                block.y += block.vy;
                if (fixedToPixel(block.y) >= block.max_y) {
                    block.y = pixelToFixed(block.max_y);
                    block.vy = 0;
                    block.state = .landed;
                    markLanded(room_index, index);
                }

                const dy = fixedToPixel(block.y) - old_y;
                if (dy > 0 and playerStandingOnBlock(player.*, block.*)) {
                    player.y += @as(i32, dy) << fixed_shift;
                } else if (movingBlockCrushesPlayer(player.*, old_x, old_y, block.x, fixedToPixel(block.y), block.w, block.h)) {
                    result.killed_player = true;
                    return result;
                }
            },
            .landed => {},
        }
    }
    return result;
}

pub fn updateDuringDeath(room_index: usize) UpdateResult {
    var result: UpdateResult = .{};
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = &blocks[index];
        if (!block.active) continue;

        switch (block.state) {
            .idle => {},
            .shaking => {
                if (block.timer > 0) {
                    block.timer -= 1;
                } else {
                    result.addSnow(block.*);
                    block.state = .falling;
                    block.vy = 0;
                }
            },
            .falling => {
                block.vy = approach(block.vy, max_fall, gravity);
                block.y += block.vy;
                if (fixedToPixel(block.y) >= block.max_y) {
                    block.y = pixelToFixed(block.max_y);
                    block.vy = 0;
                    block.state = .landed;
                    markLanded(room_index, index);
                }
            },
            .landed => {},
        }
    }
    return result;
}

pub fn floorAtPlayer(player: Player) bool {
    const player_x = fixedToPixel(player.x);
    const bottom = fixedToPixel(player.y) + player_mod.body_height;
    return floorAt(player_x + 1, bottom) or
        floorAt(player_x + player_mod.body_width / 2, bottom) or
        floorAt(player_x + player_mod.body_width - 2, bottom);
}

pub fn floorAt(x: i16, bottom_y: i16) bool {
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        const block_y = fixedToPixel(block.y);
        if (x >= block.x and x < block.x + block.w and bottom_y >= block_y and bottom_y < block_y + 4) {
            return true;
        }
    }
    return false;
}

pub fn solidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    const right = x + width;
    const bottom = y + height;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        const block_y = fixedToPixel(block.y);
        if (right > block.x and x < block.x + block.w and bottom > block_y and y < block_y + block.h) {
            return true;
        }
    }
    return false;
}

pub fn draw(camera: Camera) void {
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) {
            hideObjectForBlock(index);
            continue;
        }

        const shake_x: i16 = if (block.state == .shaking and block.timer < 32 and (block.timer & 3) == 0) -1 else 0;
        const shake_y: i16 = if (block.state == .shaking and block.timer < 16 and (block.timer & 7) == 0) 1 else 0;
        const draw_x = block.x - camera.x + shake_x;
        const draw_y = fixedToPixel(block.y) - camera.y + shake_y;
        const object_index = first_object + index * objects_per_block;
        drawChunk(object_index, draw_x, draw_y, base_tile, .size_32x32);
        drawChunk(object_index + 1, draw_x + 32, draw_y, base_tile + 16, .size_16x32);
        drawChunk(object_index + 2, draw_x + 48, draw_y, base_tile + 24, .size_8x32);
    }
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < object_capacity) : (index += 1) {
        hideObject(first_object + index);
    }
}

pub fn usedObjectCount() usize {
    return block_count * objects_per_block;
}

fn drawChunk(object_index: usize, x: i16, y: i16, tile: u10, size: gba.display.Object.Size) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = tile,
        .priority = 1,
        .palette = palette_bank,
    });
}

fn hideObjectForBlock(block_index: usize) void {
    var index: usize = 0;
    while (index < objects_per_block) : (index += 1) {
        hideObject(first_object + block_index * objects_per_block + index);
    }
}

fn landed(room_index: usize, block_index: usize) bool {
    if (block_index >= max_blocks) return false;
    const mask = @as(u8, 1) << @as(u3, @intCast(block_index));
    return (landed_masks[room_index] & mask) != 0;
}

fn markLanded(room_index: usize, block_index: usize) void {
    if (block_index >= max_blocks) return;
    const mask = @as(u8, 1) << @as(u3, @intCast(block_index));
    landed_masks[room_index] |= mask;
}

fn playerBelowBlock(player: Player, block: Block) bool {
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const player_center_x = player_x + player_mod.body_width / 2;
    const trigger_left = block.x + @as(i16, @intCast(@divTrunc(@as(u16, block.w), 2)));
    const trigger_right = block.x + @as(i16, @intCast(block.w)) + 2;
    return player_center_x >= trigger_left and
        player_center_x < trigger_right and
        player_y >= fixedToPixel(block.y) + block.h and
        player_y <= block.max_y + block.h;
}

fn playerStandingOnBlock(player: Player, block: Block) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    const block_top = fixedToPixel(block.y);
    return player_right >= block.x and
        player_left < block.x + block.w and
        player_bottom >= block_top - 1 and
        player_bottom <= block_top + 2;
}

fn movingBlockCrushesPlayer(player: Player, old_x: i16, old_y: i16, new_x: i16, new_y: i16, w: u8, h: u8) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;

    const block_left = new_x;
    const block_top = new_y;
    const block_right = new_x + @as(i16, @intCast(w));
    const block_bottom = new_y + @as(i16, @intCast(h));
    if (!collision.rectsOverlap(player_left, player_top, player_right, player_bottom, block_left, block_top, block_right, block_bottom)) {
        return false;
    }

    const old_right = old_x + @as(i16, @intCast(w));
    const old_bottom = old_y + @as(i16, @intCast(h));
    const dx = new_x - old_x;
    const dy = new_y - old_y;

    if (dy > 0 and old_bottom <= player_top + 1) return true;
    if (dy < 0 and old_y >= player_bottom - 1) return true;
    if (dx > 0 and old_right <= player_left + 1) return true;
    if (dx < 0 and old_x >= player_right - 1) return true;
    return dx != 0 or dy != 0;
}
