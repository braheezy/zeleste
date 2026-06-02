const gba = @import("gba");

const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dynamic_object_slots = @import("dynamic_object_slots.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mech_blocks = @import("mech_blocks.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixed_shift = math.fixed_shift;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const rooms = level.rooms;

pub const max_blocks = 8;

const record_bytes = 12;
const charge_frames: u8 = 6;
const outbound_frames: u8 = 32;
const pause_frames: u8 = 48;
const return_frames: u8 = 128;
const cooldown_frames: u8 = 10;
const grab_trigger_frames: u8 = 8;
const base_tile: u10 = 432;
const max_tiles = 104;
const light_frame_tiles: u10 = 2;
const light_red_tile: u10 = 0;
const light_yellow_tile: u10 = light_red_tile + light_frame_tiles;
const light_green_tile: u10 = light_yellow_tile + light_frame_tiles;
const palette_bank: u4 = 1;

const State = enum(u8) {
    idle,
    charge,
    moving_out,
    pause,
    returning,
    cooldown,
};

const Contact = struct {
    standing: bool = false,
    holding: bool = false,

    fn any(self: Contact) bool {
        return self.standing or self.holding;
    }
};

const Block = struct {
    active: bool = false,
    state: State = .idle,
    x: i32 = 0,
    y: i32 = 0,
    start_x: i32 = 0,
    start_y: i32 = 0,
    target_x: i32 = 0,
    target_y: i32 = 0,
    move_from_x: i32 = 0,
    move_from_y: i32 = 0,
    move_to_x: i32 = 0,
    move_to_y: i32 = 0,
    w: u8 = 0,
    h: u8 = 0,
    tile_offset: u16 = 0,
    timer: u8 = 0,
    hold_frames: u8 = 0,
};

pub const UpdateResult = struct {
    killed_player: bool = false,
};

const ChunkSpec = struct {
    height_tiles: usize,
    size: gba.display.Object.Size,
};

var blocks: [max_blocks]Block = [_]Block{.{}} ** max_blocks;
var block_count: usize = 0;
var active_room_index: usize = 0;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    blocks = [_]Block{.{}} ** max_blocks;
    block_count = 0;
    active_room_index = room_index;
    hideObjects();

    const data = rooms[room_index].traffic_blocks;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_blocks);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const start_x = pixelToFixed(readI16Le(data, source_offset));
        const start_y = pixelToFixed(readI16Le(data, source_offset + 2));
        const target_x = pixelToFixed(readI16Le(data, source_offset + 4));
        const target_y = pixelToFixed(readI16Le(data, source_offset + 6));
        const w = data[source_offset + 8];
        const h = data[source_offset + 9];
        const tile_offset = readU16Le(data, source_offset + 10);
        if (w == 0 or h == 0 or tile_offset >= max_tiles) continue;

        blocks[block_count] = .{
            .active = true,
            .x = start_x,
            .y = start_y,
            .start_x = start_x,
            .start_y = start_y,
            .target_x = target_x,
            .target_y = target_y,
            .move_from_x = start_x,
            .move_from_y = start_y,
            .move_to_x = target_x,
            .move_to_y = target_y,
            .w = w,
            .h = h,
            .tile_offset = tile_offset,
        };
        block_count += 1;
    }
}

pub fn loadGraphics() void {
    if (block_count == 0) return;
    const room = rooms[active_room_index];
    if (room.traffic_block_palette.len >= 32) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(room.traffic_block_palette.ptr), 16);
    }
    const tile_count = @min(room.traffic_block_tiles.len / 32, max_tiles);
    if (tile_count == 0) return;
    const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(room.traffic_block_tiles.ptr);
    gba.display.memcpyObjectTiles4Bpp(base_tile, tiles[0..tile_count]);
}

pub fn update(player: *Player, room_index: usize) UpdateResult {
    var result: UpdateResult = .{};
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = &blocks[index];
        if (!block.active) continue;

        const old_x = fixedToPixel(block.x);
        const old_y = fixedToPixel(block.y);
        const contact = playerContactAt(player.*, block.*, old_x, old_y);
        updateTrigger(block, contact);
        advanceState(block);

        const new_x = fixedToPixel(block.x);
        const new_y = fixedToPixel(block.y);
        const dx = new_x - old_x;
        const dy = new_y - old_y;
        if (dx != 0 or dy != 0) {
            if (movePlayerOrCrush(player, room_index, block.*, old_x, old_y, new_x, new_y, dx, dy, contact)) {
                result.killed_player = true;
                return result;
            }
        } else if (contact.any()) {
            storeLiftBoost(player, 0, 0);
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
        const block_x = fixedToPixel(block.x);
        const block_y = fixedToPixel(block.y);
        if (x >= block_x and x < block_x + @as(i16, @intCast(block.w)) and bottom_y >= block_y and bottom_y < block_y + 4) {
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
        const block_x = fixedToPixel(block.x);
        const block_y = fixedToPixel(block.y);
        if (right > block_x and x < block_x + @as(i16, @intCast(block.w)) and bottom > block_y and y < block_y + @as(i16, @intCast(block.h))) {
            return true;
        }
    }
    return false;
}

pub fn draw(camera: Camera) void {
    if (block_count == 0 and last_drawn_objects == 0) return;

    const first_object = firstObject();
    const capacity = objectCapacity();
    var object_offset: usize = 0;

    var index: usize = 0;
    while (index < block_count and object_offset < capacity) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        drawBlock(block, camera, first_object, &object_offset, capacity);
    }

    const drawn_objects = object_offset;
    const hide_until = @min(last_drawn_objects, capacity);
    while (object_offset < hide_until) : (object_offset += 1) {
        hideObject(first_object + object_offset);
    }
    last_drawn_objects = drawn_objects;
}

pub fn hideObjects() void {
    const first_object = firstObject();
    const capacity = objectCapacity();
    var index: usize = 0;
    while (index < capacity) : (index += 1) {
        hideObject(first_object + index);
    }
    last_drawn_objects = 0;
}

pub fn usedObjectCount() usize {
    const capacity = objectCapacity();
    var count: usize = 0;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        count += objectCountFor(block);
        if (count >= capacity) return capacity;
    }
    return count;
}

fn firstObject() usize {
    return dynamic_object_slots.first_object + mech_blocks.usedObjectCount();
}

fn objectCapacity() usize {
    const used = mech_blocks.usedObjectCount();
    if (used >= dynamic_object_slots.object_capacity) return 0;
    return dynamic_object_slots.object_capacity - used;
}

fn updateTrigger(block: *Block, contact: Contact) void {
    if (block.state != .idle or !pathMoves(block.*)) {
        block.hold_frames = if (contact.holding) block.hold_frames else 0;
        return;
    }

    var trigger = contact.standing;
    if (contact.holding and !contact.standing) {
        if (block.hold_frames < grab_trigger_frames) block.hold_frames += 1;
        trigger = block.hold_frames >= grab_trigger_frames;
    } else {
        block.hold_frames = 0;
    }

    if (!trigger) return;
    block.state = .charge;
    block.timer = 0;
    block.hold_frames = 0;
}

fn advanceState(block: *Block) void {
    switch (block.state) {
        .idle => {},
        .charge => {
            if (advanceTimer(block, charge_frames)) startMoveOut(block);
        },
        .moving_out => {
            if (advanceMove(block, outbound_frames)) {
                block.state = .pause;
                block.timer = 0;
                block.x = block.target_x;
                block.y = block.target_y;
            }
        },
        .pause => {
            if (advanceTimer(block, pause_frames)) startReturn(block);
        },
        .returning => {
            if (advanceMove(block, return_frames)) {
                block.state = .cooldown;
                block.timer = 0;
                block.x = block.start_x;
                block.y = block.start_y;
            }
        },
        .cooldown => {
            if (advanceTimer(block, cooldown_frames)) {
                block.state = .idle;
                block.timer = 0;
                block.x = block.start_x;
                block.y = block.start_y;
            }
        },
    }
}

fn advanceTimer(block: *Block, duration: u8) bool {
    block.timer += 1;
    return block.timer >= duration;
}

fn advanceMove(block: *Block, duration: u8) bool {
    block.timer += 1;
    block.x = interpolateFixed(block.move_from_x, block.move_to_x, block.timer, duration);
    block.y = interpolateFixed(block.move_from_y, block.move_to_y, block.timer, duration);
    return block.timer >= duration;
}

fn startMoveOut(block: *Block) void {
    block.state = .moving_out;
    block.timer = 0;
    block.move_from_x = block.x;
    block.move_from_y = block.y;
    block.move_to_x = block.target_x;
    block.move_to_y = block.target_y;
}

fn startReturn(block: *Block) void {
    block.state = .returning;
    block.timer = 0;
    block.move_from_x = block.x;
    block.move_from_y = block.y;
    block.move_to_x = block.start_x;
    block.move_to_y = block.start_y;
}

fn interpolateFixed(from: i32, to: i32, timer: u8, duration: u8) i32 {
    const t: i32 = @intCast(@min(timer, duration));
    const d: i32 = @intCast(duration);
    return from + @divTrunc((to - from) * t, d);
}

fn pathMoves(block: Block) bool {
    return block.start_x != block.target_x or block.start_y != block.target_y;
}

fn movePlayerOrCrush(
    player: *Player,
    room_index: usize,
    block: Block,
    old_x: i16,
    old_y: i16,
    new_x: i16,
    new_y: i16,
    dx: i16,
    dy: i16,
    contact: Contact,
) bool {
    if (contact.any()) {
        player.x += @as(i32, dx) << fixed_shift;
        player.y += @as(i32, dy) << fixed_shift;
        storeLiftBoost(player, dx, dy);
        return playerCollidesWithStatic(player.*, room_index);
    }

    return movingBlockCrushesPlayer(player.*, old_x, old_y, new_x, new_y, block.w, block.h);
}

fn storeLiftBoost(player: *Player, dx: i16, dy: i16) void {
    player.lift_boost_x = @as(i32, dx) << fixed_shift;
    player.lift_boost_y = @as(i32, dy) << fixed_shift;
    player.lift_boost_timer = player_mod.lift_boost_frames;
}

fn playerCollidesWithStatic(player: Player, room_index: usize) bool {
    return collision.solidRectAt(
        rooms[room_index],
        fixedToPixel(player.x),
        fixedToPixel(player.y),
        player_mod.body_width,
        player_mod.body_height,
    );
}

fn playerContactAt(player: Player, block: Block, block_x: i16, block_y: i16) Contact {
    return .{
        .standing = playerStandingOnBlock(player, block, block_x, block_y),
        .holding = playerHoldingBlock(player, block, block_x, block_y),
    };
}

fn playerStandingOnBlock(player: Player, block: Block, block_x: i16, block_y: i16) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    return player_right >= block_x and
        player_left < block_x + @as(i16, @intCast(block.w)) and
        player_bottom >= block_y - 1 and
        player_bottom <= block_y + 2;
}

fn playerHoldingBlock(player: Player, block: Block, block_x: i16, block_y: i16) bool {
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

fn objectCountFor(block: Block) usize {
    const columns = tileColumns(block);
    const rows = tileRows(block);
    if (columns == 0 or rows == 0) return 0;
    const light_count: usize = 1;
    if (fullWidthChunksSupported(columns)) {
        var count: usize = 0;
        var row: usize = 0;
        while (row < rows) : (count += 1) {
            const remaining = rows - row;
            if (fullWidthChunk(columns, remaining)) |chunk| {
                row += chunk.height_tiles;
            } else {
                return columns * rows + light_count;
            }
        }
        return count + light_count;
    }
    return columns * rows + light_count;
}

fn drawBlock(block: Block, camera: Camera, first_object: usize, object_offset: *usize, capacity: usize) void {
    const shake_x: i16 = if ((block.state == .charge or block.state == .pause) and (block.timer & 3) == 0) if ((block.timer & 4) == 0) -1 else 1 else 0;
    const shake_y: i16 = if (block.state == .pause and (block.timer & 7) == 0) 1 else 0;
    const block_x = fixedToPixel(block.x);
    const block_y = fixedToPixel(block.y);
    const columns = tileColumns(block);
    const rows = tileRows(block);
    var body_drawn = false;

    if (columns != 0 and fullWidthChunksSupported(columns)) {
        var row: usize = 0;
        while (row < rows and object_offset.* < capacity) {
            const remaining = rows - row;
            const maybe_chunk = fullWidthChunk(columns, remaining);
            if (maybe_chunk == null) break;
            const chunk = maybe_chunk.?;
            drawObject(
                first_object + object_offset.*,
                block_x + shake_x - camera.x,
                block_y + @as(i16, @intCast(row * 8)) + shake_y - camera.y,
                @as(u10, @intCast(block.tile_offset + @as(u16, @intCast(row * columns)))),
                chunk.size,
            );
            object_offset.* += 1;
            row += chunk.height_tiles;
        }
        body_drawn = row >= rows;
    }

    if (!body_drawn) {
        var row: usize = 0;
        while (row < rows and object_offset.* < capacity) : (row += 1) {
            var col: usize = 0;
            while (col < columns and object_offset.* < capacity) : (col += 1) {
                drawObject(
                    first_object + object_offset.*,
                    block_x + @as(i16, @intCast(col * 8)) + shake_x - camera.x,
                    block_y + @as(i16, @intCast(row * 8)) + shake_y - camera.y,
                    @as(u10, @intCast(block.tile_offset + @as(u16, @intCast(row * columns + col)))),
                    .size_8x8,
                );
                object_offset.* += 1;
            }
        }
    }

    if (object_offset.* < capacity) {
        drawObject(
            first_object + object_offset.*,
            block_x + @as(i16, @intCast(@divTrunc(@as(i32, block.w), 2) - 4)) + shake_x - camera.x,
            block_y + shake_y - camera.y,
            lightTileForState(block.state),
            .size_8x16,
        );
        object_offset.* += 1;
    }
}

fn drawObject(object_index: usize, x: i16, y: i16, tile_offset: u10, size: gba.display.Object.Size) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = base_tile + tile_offset,
        .priority = 1,
        .palette = palette_bank,
    });
}

fn lightTileForState(state: State) u10 {
    return switch (state) {
        .idle, .cooldown => light_red_tile,
        .returning => light_yellow_tile,
        .charge, .moving_out, .pause => light_green_tile,
    };
}

fn tileColumns(block: Block) usize {
    return (@as(usize, block.w) + 7) / 8;
}

fn tileRows(block: Block) usize {
    return (@as(usize, block.h) + 7) / 8;
}

fn fullWidthChunksSupported(columns: usize) bool {
    return columns == 1 or columns == 2 or columns == 4 or columns == 8;
}

fn fullWidthChunk(columns: usize, remaining_rows: usize) ?ChunkSpec {
    return switch (columns) {
        1 => if (remaining_rows >= 4)
            .{ .height_tiles = 4, .size = .size_8x32 }
        else if (remaining_rows >= 2)
            .{ .height_tiles = 2, .size = .size_8x16 }
        else
            .{ .height_tiles = 1, .size = .size_8x8 },
        2 => if (remaining_rows >= 4)
            .{ .height_tiles = 4, .size = .size_16x32 }
        else if (remaining_rows >= 2)
            .{ .height_tiles = 2, .size = .size_16x16 }
        else
            .{ .height_tiles = 1, .size = .size_16x8 },
        4 => if (remaining_rows >= 8)
            .{ .height_tiles = 8, .size = .size_32x64 }
        else if (remaining_rows >= 4)
            .{ .height_tiles = 4, .size = .size_32x32 }
        else if (remaining_rows >= 2)
            .{ .height_tiles = 2, .size = .size_32x16 }
        else
            .{ .height_tiles = 1, .size = .size_32x8 },
        8 => if (remaining_rows >= 8)
            .{ .height_tiles = 8, .size = .size_64x64 }
        else if (remaining_rows >= 4)
            .{ .height_tiles = 4, .size = .size_64x32 }
        else
            null,
        else => null,
    };
}
