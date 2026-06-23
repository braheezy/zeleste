const gba = @import("gba");

const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dynamic_object_slots = @import("dynamic_object_slots.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mover_sfx = @import("mover_sfx.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");

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

const record_bytes = 18;
const trigger_grab_flag: u8 = 1;
const shake_frames = 18;
const grab_trigger_frames = 8;
const gravity: i32 = 0x58;
const max_fall: i32 = 0x560;
const tile_size: i16 = 8;
const base_tile: u10 = @intCast(obj_vram.falling_block_fixed.start);
const fixed_sprite_tile_count: u10 = 28;
const generic_16_tile: u10 = @intCast(obj_vram.falling_block_generic.start);
const generic_8x16_tile: u10 = generic_16_tile + 4;
const room_visual_base_tile: u10 = @intCast(obj_vram.falling_block_room_visuals.start);
const max_room_visual_tiles: usize = 80;
const no_tile_offset: u16 = 0xffff;
const palette_bank: u4 = 1;

const State = enum(u8) {
    idle,
    shaking,
    falling,
    landed,
};

const TriggerMode = enum(u8) {
    player_below,
    grab,
};

pub const Block = struct {
    active: bool = false,
    state: State = .idle,
    trigger_mode: TriggerMode = .player_below,
    x: i16 = 0,
    y: i32 = 0,
    w: u8 = 0,
    h: u8 = 0,
    max_y: i16 = 0,
    timer: u8 = 0,
    hold_frames: u8 = 0,
    vy: i32 = 0,
    source_index: u8 = 0,
    tile_offset: u16 = no_tile_offset,
    spike_tile_offset: u16 = no_tile_offset,
    spike_up_mask: u8 = 0,
    spike_down_mask: u8 = 0,
    spike_left_mask: u8 = 0,
    spike_right_mask: u8 = 0,
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
var landed_y: [rooms.len][max_blocks]i16 = [_][max_blocks]i16{[_]i16{0} ** max_blocks} ** rooms.len;
var last_drawn_objects: usize = 0;
var room_visuals_loaded: bool = false;
var active_room_index: usize = 0;

pub fn loadGraphics(room_index: usize) void {
    room_visuals_loaded = false;
    if (block_count == 0) return;

    const room = rooms[room_index];
    if (allBlocksUseFixedSprite()) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
        loadFixedSpriteTiles();
        return;
    }

    if (room.falling_block_tiles.len > 0 and room.falling_block_palette.len >= 32) {
        if (hasFixedSpriteBlock()) {
            loadFixedSpriteTiles();
        }
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(room.falling_block_palette.ptr), 16);
        const tile_count = @min(room.falling_block_tiles.len / 32, max_room_visual_tiles);
        if (tile_count > 0) {
            const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(room.falling_block_tiles.ptr);
            gba.display.memcpyObjectTiles4Bpp(room_visual_base_tile, tiles[0..tile_count]);
            room_visuals_loaded = true;
        }
        return;
    }

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    loadFixedSpriteTiles();
    loadGenericTiles();
}

pub fn load(room_index: usize) void {
    blocks = [_]Block{.{}} ** max_blocks;
    block_count = 0;
    room_visuals_loaded = false;
    active_room_index = room_index;
    hideObjects();

    const data = rooms[room_index].falling_blocks;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_blocks);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const x = readI16Le(data, source_offset);
        const y = readI16Le(data, source_offset + 2);
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        const max_y = readI16Le(data, source_offset + 6);
        const flags = data[source_offset + 8];
        const tile_offset = readU16Le(data, source_offset + 10);
        const spike_tile_offset = readU16Le(data, source_offset + 12);
        const spike_up_mask = data[source_offset + 14];
        const spike_down_mask = data[source_offset + 15];
        const spike_left_mask = data[source_offset + 16];
        const spike_right_mask = data[source_offset + 17];
        if (w == 0 or h == 0) continue;

        const trigger_mode: TriggerMode = if ((flags & trigger_grab_flag) != 0) .grab else .player_below;
        var block = Block{
            .active = true,
            .trigger_mode = trigger_mode,
            .x = x,
            .y = pixelToFixed(y),
            .w = w,
            .h = h,
            .max_y = max_y - @as(i16, @intCast(h)),
            .source_index = @intCast(source_index),
            .tile_offset = tile_offset,
            .spike_tile_offset = spike_tile_offset,
            .spike_up_mask = spike_up_mask,
            .spike_down_mask = spike_down_mask,
            .spike_left_mask = spike_left_mask,
            .spike_right_mask = spike_right_mask,
        };

        if (landed(room_index, source_index)) {
            const top = landed_y[room_index][source_index];
            block.y = pixelToFixed(if (top != 0) top else block.max_y);
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
            .idle => updateIdle(block, player.*),
            .shaking => updateShaking(block, &result),
            .falling => {
                if (updateFalling(room_index, block, player)) {
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
            .shaking => updateShaking(block, &result),
            .falling => _ = updateFallingNoPlayer(room_index, block),
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

pub fn spikeHitAt(x: i16, y: i16, width: i16, height: i16, speed_x: i32, speed_y: i32) ?collision.SpikeHit {
    const rect_left = x;
    const rect_top = y;
    const rect_right = x + width;
    const rect_bottom = y + height;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active or !hasSpikes(block)) continue;
        const block_x = block.x;
        const block_y = fixedToPixel(block.y);
        if (spikeMaskHit(block.spike_up_mask, .up, block_x, block_y - tile_size, true, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
        if (spikeMaskHit(block.spike_down_mask, .down, block_x, block_y + @as(i16, @intCast(block.h)), true, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
        if (spikeMaskHit(block.spike_left_mask, .left, block_x - tile_size, block_y, false, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
        if (spikeMaskHit(block.spike_right_mask, .right, block_x + @as(i16, @intCast(block.w)), block_y, false, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
    }
    return null;
}

pub fn draw(camera: Camera) void {
    if (block_count == 0 and last_drawn_objects == 0) return;

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;

        const shake_x: i16 = if (block.state == .shaking and block.timer < 32 and (block.timer & 3) == 0) -1 else 0;
        const shake_y: i16 = if (block.state == .shaking and block.timer < 16 and (block.timer & 7) == 0) 1 else 0;
        const draw_x = block.x - camera.x + shake_x;
        const draw_y = fixedToPixel(block.y) - camera.y + shake_y;
        if (draw_x < -64 or draw_x > 248 or draw_y < -40 or draw_y > 176) {
            continue;
        }

        drawBlock(block, draw_x, draw_y, block.x + shake_x, fixedToPixel(block.y) + shake_y, &object_offset);
        if (object_offset >= object_capacity) break;
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

pub fn usedObjectCount() usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        count += objectCountFor(block);
        if (count >= object_capacity) return object_capacity;
    }
    return count;
}

fn updateIdle(block: *Block, player: Player) void {
    switch (block.trigger_mode) {
        .player_below => {
            if (playerBelowBlock(player, block.*)) startShaking(block);
        },
        .grab => {
            const contact = playerContactAt(player, block.*, block.x, fixedToPixel(block.y));
            if (contact.standing) {
                startShaking(block);
            } else if (contact.holding) {
                if (block.hold_frames < grab_trigger_frames) block.hold_frames += 1;
                if (block.hold_frames >= grab_trigger_frames) startShaking(block);
            } else {
                block.hold_frames = 0;
            }
        },
    }
}

fn updateShaking(block: *Block, result: *UpdateResult) void {
    if (block.timer > 0) {
        block.timer -= 1;
    } else {
        result.addSnow(block.*);
        block.state = .falling;
        block.vy = 0;
        block.hold_frames = 0;
        mover_sfx.fallingBlockRelease();
    }
}

fn updateFalling(room_index: usize, block: *Block, player: *Player) bool {
    const old_x = block.x;
    const old_y = fixedToPixel(block.y);
    const old_fixed_y = block.y;
    const contact = playerContactAt(player.*, block.*, old_x, old_y);
    const landed_now = moveBlockDown(room_index, block);

    const new_y = fixedToPixel(block.y);
    const dy = new_y - old_y;
    const fixed_dy = block.y - old_fixed_y;
    if (dy > 0 and contact.any()) {
        player.y += fixed_dy;
        storeLiftBoost(player, 0, fixed_dy);
    } else if (movingBlockCrushesPlayer(player.*, old_x, old_y, block.x, new_y, block.w, block.h)) {
        return true;
    }

    if (landed_now) {
        block.vy = 0;
        block.state = .landed;
        markLanded(room_index, block.source_index, fixedToPixel(block.y));
        mover_sfx.fallingBlockImpact();
    }
    return false;
}

fn updateFallingNoPlayer(room_index: usize, block: *Block) bool {
    const landed_now = moveBlockDown(room_index, block);
    if (landed_now) {
        block.vy = 0;
        block.state = .landed;
        markLanded(room_index, block.source_index, fixedToPixel(block.y));
        mover_sfx.fallingBlockImpact();
    }
    return landed_now;
}

fn moveBlockDown(room_index: usize, block: *Block) bool {
    const old_y = fixedToPixel(block.y);
    block.vy = approach(block.vy, max_fall, gravity);
    const proposed_y = block.y + block.vy;
    const target_y = fixedToPixel(proposed_y);
    const capped_y = targetYCap(block.*);
    if (capped_y) |cap| {
        if (target_y >= cap) {
            block.y = pixelToFixed(cap);
            return true;
        }
    }

    var y = old_y;
    while (y < target_y) : (y += 1) {
        const next_y = y + 1;
        if (blockCollidesAt(room_index, block.*, next_y)) {
            block.y = pixelToFixed(y);
            return true;
        }
    }

    block.y = proposed_y;
    return false;
}

fn targetYCap(block: Block) ?i16 {
    if (block.trigger_mode != .player_below) return null;
    if (block.max_y <= fixedToPixel(block.y)) return null;
    return block.max_y;
}

fn blockCollidesAt(room_index: usize, block: Block, y: i16) bool {
    return collision.solidRectAt(rooms[room_index], block.x, y, block.w, block.h);
}

fn startShaking(block: *Block) void {
    block.state = .shaking;
    block.timer = shake_frames;
    block.hold_frames = 0;
    mover_sfx.fallingBlockShake();
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

fn drawBlock(block: Block, draw_x: i16, draw_y: i16, world_x: i16, world_y: i16, object_offset: *usize) void {
    if (fixedSpriteShape(block)) {
        if (object_offset.* + objects_per_block > object_capacity) return;
        const object_index = first_object + object_offset.*;
        drawChunk(object_index, draw_x, draw_y, base_tile, .size_32x32);
        drawChunk(object_index + 1, draw_x + 32, draw_y, base_tile + 16, .size_16x32);
        drawChunk(object_index + 2, draw_x + 48, draw_y, base_tile + 24, .size_8x32);
        object_offset.* += objects_per_block;
        drawSpikes(block, draw_x, draw_y, world_x, world_y, object_offset);
        return;
    }

    if (hasRoomVisual(block)) {
        drawRoomVisualBlock(block, draw_x, draw_y, object_offset);
        drawSpikes(block, draw_x, draw_y, world_x, world_y, object_offset);
        return;
    }

    var y: usize = 0;
    while (y < block.h and object_offset.* < object_capacity) {
        const chunk_h: usize = if (@as(usize, block.h) - y >= 16) 16 else 8;
        var x: usize = 0;
        while (x < block.w and object_offset.* < object_capacity) {
            const chunk_w: usize = if (@as(usize, block.w) - x >= 16) 16 else 8;
            drawChunk(
                first_object + object_offset.*,
                draw_x + @as(i16, @intCast(x)),
                draw_y + @as(i16, @intCast(y)),
                genericTileForChunk(chunk_w, chunk_h),
                objectSize(chunk_w, chunk_h),
            );
            object_offset.* += 1;
            x += chunk_w;
        }
        y += chunk_h;
    }
    drawSpikes(block, draw_x, draw_y, world_x, world_y, object_offset);
}

fn drawRoomVisualBlock(block: Block, draw_x: i16, draw_y: i16, object_offset: *usize) void {
    var tile = room_visual_base_tile + @as(u10, @intCast(block.tile_offset));
    var y: usize = 0;
    while (y < block.h and object_offset.* < object_capacity) {
        const chunk_h: usize = if (@as(usize, block.h) - y >= 16) 16 else 8;
        var x: usize = 0;
        while (x < block.w and object_offset.* < object_capacity) {
            const chunk_w: usize = if (@as(usize, block.w) - x >= 16) 16 else 8;
            drawChunk(
                first_object + object_offset.*,
                draw_x + @as(i16, @intCast(x)),
                draw_y + @as(i16, @intCast(y)),
                tile,
                objectSize(chunk_w, chunk_h),
            );
            tile += chunkTileCount(chunk_w, chunk_h);
            object_offset.* += 1;
            x += chunk_w;
        }
        y += chunk_h;
    }
}

fn objectCountFor(block: Block) usize {
    const body_count = if (fixedSpriteShape(block)) objects_per_block else if (hasRoomVisual(block)) chunkObjectCountFor(block) else chunkObjectCountFor(block);
    return body_count + spikeCountFor(block);
}

fn chunkObjectCountFor(block: Block) usize {
    var count: usize = 0;
    var y: usize = 0;
    while (y < block.h) {
        const chunk_h: usize = if (@as(usize, block.h) - y >= 16) 16 else 8;
        var x: usize = 0;
        while (x < block.w) {
            const chunk_w: usize = if (@as(usize, block.w) - x >= 16) 16 else 8;
            count += 1;
            x += chunk_w;
        }
        y += chunk_h;
    }
    return count;
}

fn hasRoomVisual(block: Block) bool {
    return room_visuals_loaded and block.tile_offset != no_tile_offset;
}

fn fixedSpriteShape(block: Block) bool {
    return block.w == 56 and block.h == 32;
}

fn hasFixedSpriteBlock() bool {
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        if (blocks[index].active and fixedSpriteShape(blocks[index])) return true;
    }
    return false;
}

fn allBlocksUseFixedSprite() bool {
    if (block_count == 0) return false;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        if (blocks[index].active and !fixedSpriteShape(blocks[index])) return false;
    }
    return true;
}

fn loadFixedSpriteTiles() void {
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
}

fn hasSpikes(block: Block) bool {
    return room_visuals_loaded and
        block.spike_tile_offset != no_tile_offset and
        (block.spike_up_mask != 0 or
            block.spike_down_mask != 0 or
            block.spike_left_mask != 0 or
            block.spike_right_mask != 0);
}

fn spikeCountFor(block: Block) usize {
    if (!hasSpikes(block)) return 0;
    return countMask(block.spike_up_mask) +
        countMask(block.spike_down_mask) +
        countMask(block.spike_left_mask) +
        countMask(block.spike_right_mask);
}

fn countMask(mask: u8) usize {
    var count: usize = 0;
    var bits = mask;
    while (bits != 0) {
        count += @as(usize, bits & 1);
        bits >>= 1;
    }
    return count;
}

fn spikeMaskHit(
    mask: u8,
    direction: collision.SpikeDirection,
    base_x: i16,
    base_y: i16,
    horizontal: bool,
    rect_left: i16,
    rect_top: i16,
    rect_right: i16,
    rect_bottom: i16,
    speed_x: i32,
    speed_y: i32,
) ?collision.SpikeHit {
    var bit: u4 = 0;
    while (bit < 8) : (bit += 1) {
        if ((mask & (@as(u8, 1) << @as(u3, @intCast(bit)))) == 0) continue;
        const offset: i16 = @as(i16, @intCast(@as(u16, bit) * 8));
        const spike_x = base_x + if (horizontal) offset else 0;
        const spike_y = base_y + if (horizontal) 0 else offset;
        if (spikeCoveredByStaticSolid(spike_x, spike_y)) continue;
        if (collision.spikeTileHitAt(direction, rect_left, rect_top, rect_right, rect_bottom, spike_x, spike_y, speed_x, speed_y)) {
            return .{ .direction = direction };
        }
    }
    return null;
}

fn drawSpikes(block: Block, draw_x: i16, draw_y: i16, world_x: i16, world_y: i16, object_offset: *usize) void {
    if (!hasSpikes(block)) return;

    var spike_tile = block.spike_tile_offset;
    drawSpikeMask(block.spike_up_mask, draw_x, draw_y - tile_size, world_x, world_y - tile_size, true, object_offset, &spike_tile);
    drawSpikeMask(block.spike_down_mask, draw_x, draw_y + @as(i16, @intCast(block.h)), world_x, world_y + @as(i16, @intCast(block.h)), true, object_offset, &spike_tile);
    drawSpikeMask(block.spike_left_mask, draw_x - tile_size, draw_y, world_x - tile_size, world_y, false, object_offset, &spike_tile);
    drawSpikeMask(block.spike_right_mask, draw_x + @as(i16, @intCast(block.w)), draw_y, world_x + @as(i16, @intCast(block.w)), world_y, false, object_offset, &spike_tile);
}

fn drawSpikeMask(mask: u8, base_x: i16, base_y: i16, world_base_x: i16, world_base_y: i16, horizontal: bool, object_offset: *usize, spike_tile: *u16) void {
    var bit: u4 = 0;
    while (bit < 8) : (bit += 1) {
        if ((mask & (@as(u8, 1) << @as(u3, @intCast(bit)))) == 0) continue;
        if (object_offset.* >= object_capacity or spike_tile.* >= max_room_visual_tiles) return;
        const offset: i16 = @as(i16, @intCast(@as(u16, bit) * 8));
        const x = base_x + if (horizontal) offset else 0;
        const y = base_y + if (horizontal) 0 else offset;
        const world_spike_x = world_base_x + if (horizontal) offset else 0;
        const world_spike_y = world_base_y + if (horizontal) 0 else offset;
        if (!spikeCoveredByStaticSolid(world_spike_x, world_spike_y)) {
            drawChunk(first_object + object_offset.*, x, y, room_visual_base_tile + @as(u10, @intCast(spike_tile.*)), .size_8x8);
            object_offset.* += 1;
        }
        spike_tile.* += 1;
    }
}

fn spikeCoveredByStaticSolid(x: i16, y: i16) bool {
    return collision.solidRectAt(rooms[active_room_index], x, y, tile_size, tile_size);
}

fn objectSize(width: usize, height: usize) gba.display.Object.Size {
    if (width == 16 and height == 16) return .size_16x16;
    if (width == 16) return .size_16x8;
    if (height == 16) return .size_8x16;
    return .size_8x8;
}

fn genericTileForChunk(width: usize, height: usize) u10 {
    if (width == 8 and height == 16) return generic_8x16_tile;
    return generic_16_tile;
}

fn chunkTileCount(width: usize, height: usize) u10 {
    if (width == 16 and height == 16) return 4;
    if (width == 16 or height == 16) return 2;
    return 1;
}

fn loadGenericTiles() void {
    const source_tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(&tiles_data);
    const generic_tiles = [_]gba.display.Tile4Bpp{
        source_tiles[0],
        source_tiles[1],
        source_tiles[4],
        source_tiles[5],
        source_tiles[0],
        source_tiles[4],
    };
    gba.display.memcpyObjectTiles4Bpp(generic_16_tile, &generic_tiles);
}

fn landed(room_index: usize, source_index: usize) bool {
    if (room_index >= rooms.len or source_index >= max_blocks) return false;
    const mask = @as(u8, 1) << @as(u3, @intCast(source_index));
    return (landed_masks[room_index] & mask) != 0;
}

fn markLanded(room_index: usize, source_index: usize, top: i16) void {
    if (room_index >= rooms.len or source_index >= max_blocks) return;
    const mask = @as(u8, 1) << @as(u3, @intCast(source_index));
    landed_masks[room_index] |= mask;
    landed_y[room_index][source_index] = top;
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

fn playerContactAt(player: Player, block: Block, block_x: i16, block_y: i16) Contact {
    return .{
        .standing = playerStandingOnBlock(player, block, block_x, block_y),
        .holding = playerHoldingBlockAt(player, block, block_x, block_y),
    };
}

const Contact = struct {
    standing: bool = false,
    holding: bool = false,

    fn any(self: Contact) bool {
        return self.standing or self.holding;
    }
};

fn playerStandingOnBlock(player: Player, block: Block, block_x: i16, block_y: i16) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    return player_right >= block_x and
        player_left < block_x + block.w and
        player_bottom >= block_y - 1 and
        player_bottom <= block_y + 2;
}

fn playerHoldingBlock(player: Player, block: Block) bool {
    return playerHoldingBlockAt(player, block, block.x, fixedToPixel(block.y));
}

fn playerHoldingBlockAt(player: Player, block: Block, block_x: i16, block_y: i16) bool {
    if (!player.climbing and !player.climb_dangling) return false;

    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width;
    const player_top = fixedToPixel(player.y);
    const player_bottom = player_top + player_mod.body_height;
    const block_right = block_x + @as(i16, @intCast(block.w));
    const block_bottom = block_y + @as(i16, @intCast(block.h));
    const vertical_overlap = player_bottom > block_y + 1 and player_top < block_bottom - 1;
    const left_contact = player_right >= block_x - 1 and player_right <= block_x + 2;
    const right_contact = player_left <= block_right + 1 and player_left >= block_right - 2;
    return vertical_overlap and (left_contact or right_contact);
}

fn storeLiftBoost(player: *Player, fixed_dx: i32, fixed_dy: i32) void {
    player.lift_boost_x = @max(-player_mod.lift_boost_x_cap, @min(player_mod.lift_boost_x_cap, fixed_dx));
    player.lift_boost_y = if (fixed_dy > 0) 0 else @max(player_mod.lift_boost_y_cap, fixed_dy);
    player.lift_boost_timer = player_mod.lift_boost_frames;
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
