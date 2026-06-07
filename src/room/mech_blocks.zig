const gba = @import("gba");

const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dynamic_object_slots = @import("dynamic_object_slots.zig");
const falling_blocks = @import("falling_blocks.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mover_sfx = @import("mover_sfx.zig");
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

const record_bytes = 18;
const charge_frames: u8 = 15;
const outbound_frames: u8 = 20;
const pause_frames: u8 = 48;
const return_frames: u8 = 96;
const cooldown_frames: u8 = 10;
const grab_trigger_frames: u8 = 6;
const terminal_lift_boost_frames: u8 = 5;
const tile_size: i16 = 8;
const base_tile: u10 = 432;
const max_tiles = 104;
const light_frame_tiles: u10 = 2;
const light_frame_width: i16 = 8;
const light_visible_height: i16 = 12;
const light_red_tile: u10 = 0;
const light_yellow_tile: u10 = light_red_tile + light_frame_tiles;
const light_green_tile: u10 = light_yellow_tile + light_frame_tiles;
const palette_bank: u4 = 1;
const screen_width: i16 = 240;
const screen_height: i16 = 160;

const State = enum(u8) {
    idle,
    charge,
    moving_out,
    pause,
    returning,
    cooldown,
};

const MoveEase = enum {
    linear,
    ease_in,
    ease_out,
};

const Contact = struct {
    standing: bool = false,
    holding_dir: i16 = 0,

    fn any(self: Contact) bool {
        return self.standing or self.holding_dir != 0;
    }

    fn holding(self: Contact) bool {
        return self.holding_dir != 0;
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
    spike_tile_offset: u16 = 0,
    spike_up_mask: u8 = 0,
    spike_down_mask: u8 = 0,
    spike_left_mask: u8 = 0,
    spike_right_mask: u8 = 0,
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

    const data = rooms[room_index].mech_blocks;
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
        const spike_tile_offset = readU16Le(data, source_offset + 12);
        const spike_up_mask = data[source_offset + 14];
        const spike_down_mask = data[source_offset + 15];
        const spike_left_mask = data[source_offset + 16];
        const spike_right_mask = data[source_offset + 17];
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
            .spike_tile_offset = spike_tile_offset,
            .spike_up_mask = spike_up_mask,
            .spike_down_mask = spike_down_mask,
            .spike_left_mask = spike_left_mask,
            .spike_right_mask = spike_right_mask,
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

        const old_fixed_x = block.x;
        const old_fixed_y = block.y;
        const old_x = fixedToPixel(block.x);
        const old_y = fixedToPixel(block.y);
        const contact = playerContactAt(player.*, block.*, old_x, old_y);
        const previous_state = block.state;
        updateTrigger(block, contact);
        advanceState(block);

        const new_x = fixedToPixel(block.x);
        const new_y = fixedToPixel(block.y);
        const dx = new_x - old_x;
        const dy = new_y - old_y;
        const fixed_dx = block.x - old_fixed_x;
        const fixed_dy = block.y - old_fixed_y;
        if (fixed_dx != 0 or fixed_dy != 0 or dx != 0 or dy != 0) {
            if (movePlayerOrCrush(player, room_index, block.*, old_x, old_y, new_x, new_y, fixed_dx, fixed_dy, contact)) {
                result.killed_player = true;
                return result;
            }
        }
        if (contact.any() and terminalStopReached(previous_state, block.state)) {
            shortenLiftBoost(player, terminal_lift_boost_frames);
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

pub fn spikeHitAt(x: i16, y: i16, width: i16, height: i16, speed_x: i32, speed_y: i32) ?collision.SpikeHit {
    const rect_left = x;
    const rect_top = y;
    const rect_right = x + width;
    const rect_bottom = y + height;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active or !hasSpikes(block)) continue;
        const block_x = fixedToPixel(block.x);
        const block_y = fixedToPixel(block.y);
        if (spikeMaskHit(block.spike_up_mask, .up, block_x, block_y - 8, true, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
        if (spikeMaskHit(block.spike_down_mask, .down, block_x, block_y + @as(i16, @intCast(block.h)), true, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
        if (spikeMaskHit(block.spike_left_mask, .left, block_x - 8, block_y, false, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
        if (spikeMaskHit(block.spike_right_mask, .right, block_x + @as(i16, @intCast(block.w)), block_y, false, rect_left, rect_top, rect_right, rect_bottom, speed_x, speed_y)) |hit| return hit;
    }
    return null;
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
    return dynamic_object_slots.first_object + falling_blocks.usedObjectCount();
}

fn objectCapacity() usize {
    const used = falling_blocks.usedObjectCount();
    if (used >= dynamic_object_slots.object_capacity) return 0;
    return dynamic_object_slots.object_capacity - used;
}

fn updateTrigger(block: *Block, contact: Contact) void {
    if (block.state != .idle or !pathMoves(block.*)) {
        block.hold_frames = if (contact.holding()) block.hold_frames else 0;
        return;
    }

    var trigger = contact.standing;
    if (contact.holding() and !contact.standing) {
        if (block.hold_frames < grab_trigger_frames) block.hold_frames += 1;
        trigger = block.hold_frames >= grab_trigger_frames;
    } else {
        block.hold_frames = 0;
    }

    if (!trigger) return;
    block.state = .charge;
    block.timer = 0;
    block.hold_frames = 0;
    mover_sfx.zipmoverTouch();
}

fn advanceState(block: *Block) void {
    switch (block.state) {
        .idle => {},
        .charge => {
            if (advanceTimer(block, charge_frames)) startMoveOut(block);
        },
        .moving_out => {
            if (advanceMove(block, outbound_frames, .ease_in)) {
                block.state = .pause;
                block.timer = 0;
                block.x = block.target_x;
                block.y = block.target_y;
                mover_sfx.zipmoverImpact();
            }
        },
        .pause => {
            if (advanceTimer(block, pause_frames)) startReturn(block);
        },
        .returning => {
            if (advanceMove(block, return_frames, .ease_out)) {
                block.state = .cooldown;
                block.timer = 0;
                block.x = block.start_x;
                block.y = block.start_y;
                mover_sfx.zipmoverReset();
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

fn advanceMove(block: *Block, duration: u8, ease: MoveEase) bool {
    block.timer += 1;
    block.x = interpolateFixed(block.move_from_x, block.move_to_x, block.timer, duration, ease);
    block.y = interpolateFixed(block.move_from_y, block.move_to_y, block.timer, duration, ease);
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
    mover_sfx.zipmoverReturn();
}

fn interpolateFixed(from: i32, to: i32, timer: u8, duration: u8, ease: MoveEase) i32 {
    const t: i64 = @intCast(@min(timer, duration));
    const d: i64 = @intCast(duration);
    const delta: i64 = @intCast(to - from);
    const remaining = d - t;
    const numerator = switch (ease) {
        .linear => t,
        .ease_in => t * t,
        .ease_out => d * d - remaining * remaining,
    };
    const denominator = switch (ease) {
        .linear => d,
        .ease_in, .ease_out => d * d,
    };
    return from + @as(i32, @intCast(@divTrunc(delta * numerator, denominator)));
}

fn pathMoves(block: Block) bool {
    return block.start_x != block.target_x or block.start_y != block.target_y;
}

fn terminalStopReached(previous_state: State, next_state: State) bool {
    return (previous_state == .moving_out and next_state == .pause) or
        (previous_state == .returning and next_state == .cooldown);
}

fn movePlayerOrCrush(
    player: *Player,
    room_index: usize,
    block: Block,
    old_x: i16,
    old_y: i16,
    new_x: i16,
    new_y: i16,
    fixed_dx: i32,
    fixed_dy: i32,
    contact: Contact,
) bool {
    if (contact.standing) {
        player.x += fixed_dx;
        player.y += fixed_dy;
        storeLiftBoost(player, fixed_dx, fixed_dy);
        return playerCollidesWithStatic(player.*, room_index);
    }

    if (contact.holding()) {
        player.x = pixelToFixed(if (contact.holding_dir > 0)
            new_x - player_mod.body_width
        else
            new_x + @as(i16, @intCast(block.w)));
        player.y += fixed_dy;
        player.climb_dir = contact.holding_dir;
        player.facing_left = contact.holding_dir < 0;
        storeLiftBoost(player, fixed_dx, fixed_dy);
        return playerCollidesWithStatic(player.*, room_index);
    }

    return moveOverlappingPlayerOrCrush(player, room_index, new_x, new_y, block.w, block.h, new_x - old_x, new_y - old_y, fixed_dx, fixed_dy);
}

fn storeLiftBoost(player: *Player, fixed_dx: i32, fixed_dy: i32) void {
    player.lift_boost_x = @max(-player_mod.lift_boost_x_cap, @min(player_mod.lift_boost_x_cap, fixed_dx));
    player.lift_boost_y = if (fixed_dy > 0) 0 else @max(player_mod.lift_boost_y_cap, fixed_dy);
    player.lift_boost_timer = player_mod.lift_boost_frames;
}

fn shortenLiftBoost(player: *Player, frames: u8) void {
    if (player.lift_boost_timer > frames) {
        player.lift_boost_timer = frames;
    }
}

fn playerCollidesWithStatic(player: Player, room_index: usize) bool {
    return playerCollidesWithStaticAt(room_index, fixedToPixel(player.x), fixedToPixel(player.y));
}

fn playerCollidesWithStaticAt(room_index: usize, x: i16, y: i16) bool {
    return collision.solidRectAt(
        rooms[room_index],
        x,
        y,
        player_mod.body_width,
        player_mod.body_height,
    );
}

fn playerContactAt(player: Player, block: Block, block_x: i16, block_y: i16) Contact {
    return .{
        .standing = playerStandingOnBlock(player, block, block_x, block_y),
        .holding_dir = playerHoldingBlockDir(player, block, block_x, block_y),
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

fn playerHoldingBlockDir(player: Player, block: Block, block_x: i16, block_y: i16) i16 {
    if (!player.climbing and !player.climb_dangling) return 0;

    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width;
    const player_top = fixedToPixel(player.y);
    const player_bottom = player_top + player_mod.body_height;
    const block_right = block_x + @as(i16, @intCast(block.w));
    const block_bottom = block_y + @as(i16, @intCast(block.h));
    const side_slop: i16 = 4;
    const vertical_overlap = player_bottom > block_y + 1 and player_top < block_bottom - 1;
    if (!vertical_overlap) return 0;

    const left_contact = player_right >= block_x - side_slop and player_right <= block_x + side_slop;
    const right_contact = player_left <= block_right + side_slop and player_left >= block_right - side_slop;
    if (player.climb_dir > 0 and left_contact) return 1;
    if (player.climb_dir < 0 and right_contact) return -1;
    if (left_contact) return 1;
    if (right_contact) return -1;
    return 0;
}

fn moveOverlappingPlayerOrCrush(
    player: *Player,
    room_index: usize,
    new_x: i16,
    new_y: i16,
    w: u8,
    h: u8,
    dx: i16,
    dy: i16,
    fixed_dx: i32,
    fixed_dy: i32,
) bool {
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

    if (dx == 0 and dy == 0) return false;

    const prefer_horizontal = absI16(dx) >= absI16(dy);
    if (prefer_horizontal) {
        if (tryPushPlayerHorizontal(player, room_index, block_left, block_right, dx, fixed_dx, fixed_dy)) return false;
        if (tryPushPlayerVertical(player, room_index, block_top, block_bottom, dy, fixed_dx, fixed_dy)) return false;
    } else {
        if (tryPushPlayerVertical(player, room_index, block_top, block_bottom, dy, fixed_dx, fixed_dy)) return false;
        if (tryPushPlayerHorizontal(player, room_index, block_left, block_right, dx, fixed_dx, fixed_dy)) return false;
    }

    return true;
}

fn tryPushPlayerHorizontal(player: *Player, room_index: usize, block_left: i16, block_right: i16, dx: i16, fixed_dx: i32, fixed_dy: i32) bool {
    if (dx > 0 and tryPlacePushedPlayer(player, room_index, block_right, fixedToPixel(player.y), fixed_dx, fixed_dy, false)) return true;
    if (dx < 0 and tryPlacePushedPlayer(player, room_index, block_left - player_mod.body_width, fixedToPixel(player.y), fixed_dx, fixed_dy, false)) return true;
    return false;
}

fn tryPushPlayerVertical(player: *Player, room_index: usize, block_top: i16, block_bottom: i16, dy: i16, fixed_dx: i32, fixed_dy: i32) bool {
    if (dy < 0 and tryPlacePushedPlayer(player, room_index, fixedToPixel(player.x), block_top - player_mod.body_height, fixed_dx, fixed_dy, true)) return true;
    if (dy > 0 and tryPlacePushedPlayer(player, room_index, fixedToPixel(player.x), block_bottom, fixed_dx, fixed_dy, false)) return true;
    return false;
}

fn tryPlacePushedPlayer(player: *Player, room_index: usize, x: i16, y: i16, fixed_dx: i32, fixed_dy: i32, grounded: bool) bool {
    if (playerCollidesWithStaticAt(room_index, x, y)) return false;
    player.x = pixelToFixed(x);
    player.y = pixelToFixed(y);
    if (grounded) {
        player.vy = 0;
        player.grounded = true;
    }
    storeLiftBoost(player, fixed_dx, fixed_dy);
    return true;
}

fn absI16(value: i16) i16 {
    return if (value < 0) -value else value;
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
        return count + light_count + spikeCountFor(block);
    }
    return columns * rows + light_count + spikeCountFor(block);
}

fn drawBlock(block: Block, camera: Camera, first_object: usize, object_offset: *usize, capacity: usize) void {
    const shake_x: i16 = if ((block.state == .charge or block.state == .pause) and (block.timer & 3) == 0) if ((block.timer & 4) == 0) -1 else 1 else 0;
    const shake_y: i16 = if (block.state == .pause and (block.timer & 7) == 0) 1 else 0;
    const block_x = fixedToPixel(block.x);
    const block_y = fixedToPixel(block.y);
    const screen_x = block_x + shake_x - camera.x;
    const screen_y = block_y + shake_y - camera.y;
    const columns = tileColumns(block);
    const rows = tileRows(block);
    var body_drawn = false;

    if (object_offset.* < capacity) {
        if (drawObject(
            first_object + object_offset.*,
            screen_x + centeredOffset(block.w, light_frame_width),
            screen_y,
            lightTileForState(block.state),
            .size_8x16,
        )) {
            object_offset.* += 1;
        }
    }

    if (columns != 0 and fullWidthChunksSupported(columns)) {
        var row: usize = 0;
        while (row < rows and object_offset.* < capacity) {
            const remaining = rows - row;
            const maybe_chunk = fullWidthChunk(columns, remaining);
            if (maybe_chunk == null) break;
            const chunk = maybe_chunk.?;
            if (drawObject(
                first_object + object_offset.*,
                screen_x,
                screen_y + @as(i16, @intCast(row * 8)),
                @as(u10, @intCast(block.tile_offset + @as(u16, @intCast(row * columns)))),
                chunk.size,
            )) {
                object_offset.* += 1;
            }
            row += chunk.height_tiles;
        }
        body_drawn = row >= rows;
    }

    if (!body_drawn) {
        var row: usize = 0;
        while (row < rows and object_offset.* < capacity) : (row += 1) {
            var col: usize = 0;
            while (col < columns and object_offset.* < capacity) : (col += 1) {
                if (drawObject(
                    first_object + object_offset.*,
                    screen_x + @as(i16, @intCast(col * 8)),
                    screen_y + @as(i16, @intCast(row * 8)),
                    @as(u10, @intCast(block.tile_offset + @as(u16, @intCast(row * columns + col)))),
                    .size_8x8,
                )) {
                    object_offset.* += 1;
                }
            }
        }
    }

    drawSpikes(block, camera, first_object, object_offset, capacity, block_x + shake_x, block_y + shake_y);
}

fn hasSpikes(block: Block) bool {
    return block.spike_up_mask != 0 or
        block.spike_down_mask != 0 or
        block.spike_left_mask != 0 or
        block.spike_right_mask != 0;
}

fn spikeCountFor(block: Block) usize {
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
        const tile_x = base_x + if (horizontal) offset else 0;
        const tile_y = base_y + if (horizontal) 0 else offset;
        if (spikeCoveredByStaticSolid(tile_x, tile_y)) continue;
        if (collision.spikeTileHitAt(direction, rect_left, rect_top, rect_right, rect_bottom, tile_x, tile_y, speed_x, speed_y)) {
            return .{ .direction = direction };
        }
    }
    return null;
}

fn drawSpikes(block: Block, camera: Camera, first_object: usize, object_offset: *usize, capacity: usize, block_x: i16, block_y: i16) void {
    if (!hasSpikes(block) or block.spike_tile_offset >= max_tiles) return;

    var spike_tile = block.spike_tile_offset;
    drawSpikeMask(block.spike_up_mask, block_x, block_y - 8, true, camera, first_object, object_offset, capacity, &spike_tile);
    drawSpikeMask(block.spike_down_mask, block_x, block_y + @as(i16, @intCast(block.h)), true, camera, first_object, object_offset, capacity, &spike_tile);
    drawSpikeMask(block.spike_left_mask, block_x - 8, block_y, false, camera, first_object, object_offset, capacity, &spike_tile);
    drawSpikeMask(block.spike_right_mask, block_x + @as(i16, @intCast(block.w)), block_y, false, camera, first_object, object_offset, capacity, &spike_tile);
}

fn drawSpikeMask(
    mask: u8,
    base_x: i16,
    base_y: i16,
    horizontal: bool,
    camera: Camera,
    first_object: usize,
    object_offset: *usize,
    capacity: usize,
    spike_tile: *u16,
) void {
    var bit: u4 = 0;
    while (bit < 8) : (bit += 1) {
        if ((mask & (@as(u8, 1) << @as(u3, @intCast(bit)))) == 0) continue;
        if (object_offset.* >= capacity or spike_tile.* >= max_tiles) return;
        const offset: i16 = @as(i16, @intCast(@as(u16, bit) * 8));
        const x = base_x + if (horizontal) offset else 0;
        const y = base_y + if (horizontal) 0 else offset;
        if (!spikeCoveredByStaticSolid(x, y) and drawObject(first_object + object_offset.*, x - camera.x, y - camera.y, @intCast(spike_tile.*), .size_8x8)) {
            object_offset.* += 1;
        }
        spike_tile.* += 1;
    }
}

fn spikeCoveredByStaticSolid(x: i16, y: i16) bool {
    return collision.solidRectAt(rooms[active_room_index], x, y, tile_size, tile_size);
}

fn centeredOffset(size: u8, child_size: i16) i16 {
    return @as(i16, @intCast(@divTrunc(@as(i32, size) - @as(i32, child_size), 2)));
}

fn drawObject(object_index: usize, x: i16, y: i16, tile_offset: u10, size: gba.display.Object.Size) bool {
    const dimensions = objectDimensions(size);
    if (!visible(x, y, dimensions.width, dimensions.height)) return false;

    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = base_tile + tile_offset,
        .priority = 1,
        .palette = palette_bank,
    });
    return true;
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < screen_width and y < screen_height and x + width > 0 and y + height > 0;
}

fn objectDimensions(size: gba.display.Object.Size) struct { width: i16, height: i16 } {
    return switch (size.shape) {
        .square => switch (size.shape_size) {
            .size_2 => .{ .width = 8, .height = 8 },
            .size_4 => .{ .width = 16, .height = 16 },
            .size_16 => .{ .width = 32, .height = 32 },
            .size_64 => .{ .width = 64, .height = 64 },
        },
        .wide => switch (size.shape_size) {
            .size_2 => .{ .width = 16, .height = 8 },
            .size_4 => .{ .width = 32, .height = 8 },
            .size_16 => .{ .width = 32, .height = 16 },
            .size_64 => .{ .width = 64, .height = 32 },
        },
        .tall => switch (size.shape_size) {
            .size_2 => .{ .width = 8, .height = 16 },
            .size_4 => .{ .width = 8, .height = 32 },
            .size_16 => .{ .width = 16, .height = 32 },
            .size_64 => .{ .width = 32, .height = 64 },
        },
    };
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
