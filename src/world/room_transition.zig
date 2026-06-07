const gba = @import("gba");
const chapter_entities = @import("../chapters/entities.zig");
const chapter_systems = @import("../chapters/systems.zig");
const collision = @import("collision.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("room_data.zig");

const Player = player_mod.State;
const Spawn = room_data.Spawn;

const fixed_shift = math.fixed_shift;
const pixelToFixed = math.pixelToFixed;
const fixedToPixel = math.fixedToPixel;
const absI16 = math.absI16;
const clampI16 = math.clampI16;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const transition_cooldown_frames = player_mod.room_transition_cooldown_frames;
const exit_line_min_overlap_px: i16 = 4;
const vertical_transition_overlap_px: i16 = 8;
const entry_wall_restore_x_px: i16 = 14;
const entry_wall_restore_y_px: i16 = 10;

const EntryYBounds = struct {
    min: i16,
    max: i16,
};

const EntryPosition = struct {
    x: i16,
    y: i16,
};

const EntryActionContext = struct {
    wall_dir: i16 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    climbing: bool = false,
    climb_dangling: bool = false,
    wall_sliding: bool = false,
};

pub fn spawnPlayer(room_index: usize) Player {
    return spawnPlayerAt(rooms[room_index].spawn);
}

pub fn spawnPlayerAt(spawn: Spawn) Player {
    return .{
        .x = pixelToFixed(spawn.x),
        .y = pixelToFixed(spawn.y),
        .dust_suppress_timer = 2,
    };
}

pub fn respawnForEntrySide(room_index: usize, entry_side: room_data.ExitDirection) Spawn {
    const room = rooms[room_index];
    return switch (entry_side) {
        .left => room.spawn_left,
        .right => room.spawn_right,
        .up => room.spawn_top,
        .down => room.spawn_bottom,
    };
}

pub fn respawnForEntry(room_index: usize, player: Player, entry_side: room_data.ExitDirection) Spawn {
    return nearestRespawnPoint(room_index, fixedToPixel(player.x), fixedToPixel(player.y)) orelse
        respawnForEntrySide(room_index, entry_side);
}

pub fn respawnPointAt(room_index: usize, point_index: usize) ?Spawn {
    const data = rooms[room_index].respawn_points;
    if (data.len < 2) return null;

    const count = @min(@as(usize, readU16Le(data, 0)), (data.len - 2) / 4);
    if (point_index >= count) return null;

    const offset = 2 + point_index * 4;
    return .{
        .x = readI16Le(data, offset),
        .y = readI16Le(data, offset + 2),
    };
}

fn nearestRespawnPoint(room_index: usize, x: i16, y: i16) ?Spawn {
    const data = rooms[room_index].respawn_points;
    if (data.len < 2) return null;

    const count = @min(@as(usize, readU16Le(data, 0)), (data.len - 2) / 4);
    if (count == 0) return null;

    var best = Spawn{
        .x = readI16Le(data, 2),
        .y = readI16Le(data, 4),
    };
    var best_distance = respawnDistanceSquared(best, x, y);
    var index: usize = 1;
    var offset: usize = 6;
    while (index < count) : ({
        index += 1;
        offset += 4;
    }) {
        const candidate = Spawn{
            .x = readI16Le(data, offset),
            .y = readI16Le(data, offset + 2),
        };
        const distance = respawnDistanceSquared(candidate, x, y);
        if (distance < best_distance) {
            best = candidate;
            best_distance = distance;
        }
    }
    return best;
}

fn respawnDistanceSquared(spawn: Spawn, x: i16, y: i16) i32 {
    const dx = @as(i32, spawn.x) - @as(i32, x);
    const dy = @as(i32, spawn.y) - @as(i32, y);
    return dx * dx + dy * dy;
}

pub fn trySwitch(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize, entry_side: *room_data.ExitDirection) bool {
    if (player.room_transition_cooldown > 0) return false;

    const room = rooms[room_index.*];
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    if (tryExitLineSwitch(player, input, room_index, player_x, player_y, entry_side)) return true;
    if (input.isPressed(.right) and player_x >= room.width_pixels - player_body_width and !hasExitLine(room, .right)) {
        if (room.right) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .right, player_x, player_y)) return false;
            const previous_room = room_index.*;
            const previous_player = player.*;
            const entry_context = entryActionContext(player.*, previous_room);
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, previous_room, next_room);
            const aligned_entry = entryPosition(player.*);
            room_index.* = next_room;
            enterRoomFromLeft(player);
            if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .left, source_floor_world_y, aligned_entry)) {
                player.* = previous_player;
                room_index.* = previous_room;
                return false;
            }
            restoreEntryActionContact(player, room_index.*, entry_context);
            entry_side.* = oppositeDirection(.right);
            startCooldown(player);
            return true;
        }
    }
    if (input.isPressed(.left) and player_x <= 0 and !hasExitLine(room, .left)) {
        if (room.left) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .left, player_x, player_y)) return false;
            const previous_room = room_index.*;
            const previous_player = player.*;
            const entry_context = entryActionContext(player.*, previous_room);
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, previous_room, next_room);
            const aligned_entry = entryPosition(player.*);
            room_index.* = next_room;
            enterRoomFromRight(player, room_index.*);
            if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .right, source_floor_world_y, aligned_entry)) {
                player.* = previous_player;
                room_index.* = previous_room;
                return false;
            }
            restoreEntryActionContact(player, room_index.*, entry_context);
            entry_side.* = oppositeDirection(.left);
            startCooldown(player);
            return true;
        }
    }
    if (player_y <= -vertical_transition_overlap_px and player.vy <= 0 and !hasExitLine(room, .up)) {
        if (room.up) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .up, player_x, player_y)) return false;
            const previous_room = room_index.*;
            const entry_context = entryActionContext(player.*, previous_room);
            alignPlayerBetweenRooms(player, previous_room, next_room);
            const aligned_entry = entryPosition(player.*);
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromBottom(player, room_index.*);
            fitPlayerAfterVerticalRoomEntry(player, room_index.*, aligned_entry);
            restoreEntryActionContact(player, room_index.*, entry_context);
            entry_side.* = oppositeDirection(.up);
            startCooldown(player);
            return true;
        }
    }
    if (player_y >= room.height_pixels - player_body_height + vertical_transition_overlap_px and player.vy > 0 and !hasExitLine(room, .down)) {
        if (room.down) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .down, player_x, player_y)) return false;
            const previous_room = room_index.*;
            const entry_context = entryActionContext(player.*, previous_room);
            alignPlayerBetweenRooms(player, previous_room, next_room);
            const aligned_entry = entryPosition(player.*);
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromTop(player);
            fitPlayerAfterVerticalRoomEntry(player, room_index.*, aligned_entry);
            restoreEntryActionContact(player, room_index.*, entry_context);
            entry_side.* = oppositeDirection(.down);
            startCooldown(player);
            return true;
        }
    }
    return false;
}

fn hasExitLine(room: room_data.RoomBackground, direction: room_data.ExitDirection) bool {
    for (room.exit_lines) |exit_line| {
        if (exit_line.direction == direction) return true;
    }
    return false;
}

fn implicitEdgeTransitionAllowed(from_room: usize, to_room: usize, direction: room_data.ExitDirection, player_x: i16, player_y: i16) bool {
    const target = rooms[to_room];
    const opposite = oppositeDirection(direction);
    var has_reciprocal_exit = false;

    for (target.exit_lines) |exit_line| {
        if (exit_line.direction != opposite or exit_line.target != from_room) continue;
        has_reciprocal_exit = true;
        if (direction == .up or direction == .down) {
            const line_x1 = target.world_x + exit_line.x1 - rooms[from_room].world_x;
            const line_x2 = target.world_x + exit_line.x2 - rooms[from_room].world_x;
            if (lineRangeOverlapsBy(player_x, player_x + player_body_width, line_x1, line_x2, exit_line_min_overlap_px)) return true;
        } else {
            const line_y1 = target.world_y + exit_line.y1 - rooms[from_room].world_y;
            const line_y2 = target.world_y + exit_line.y2 - rooms[from_room].world_y;
            if (lineRangeOverlapsBy(player_y, player_y + player_body_height, line_y1, line_y2, exit_line_min_overlap_px)) return true;
        }
    }

    return !has_reciprocal_exit;
}

fn oppositeDirection(direction: room_data.ExitDirection) room_data.ExitDirection {
    return switch (direction) {
        .left => .right,
        .right => .left,
        .up => .down,
        .down => .up,
    };
}

fn tryExitLineSwitch(
    player: *Player,
    input: gba.input.BufferedKeysState,
    room_index: *usize,
    player_x: i16,
    player_y: i16,
    entry_side: *room_data.ExitDirection,
) bool {
    const room = rooms[room_index.*];
    for (room.exit_lines) |exit_line| {
        switch (exit_line.direction) {
            .right => {
                if (!input.isPressed(.right) or player_x < room.width_pixels - player_body_width) continue;
                if (!lineRangeOverlapsBy(player_y, player_y + player_body_height, exit_line.y1, exit_line.y2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                const entry_context = entryActionContext(player.*, previous_room);
                const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                    sideTransitionSourceFloorWorldY(player.*, room_index.*)
                else
                    null;
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                const aligned_entry = entryPosition(player.*);
                room_index.* = exit_line.target;
                enterRoomFromLeft(player);
                if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .left, source_floor_world_y, aligned_entry)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                restoreEntryActionContact(player, room_index.*, entry_context);
                entry_side.* = oppositeDirection(exit_line.direction);
                startCooldown(player);
                return true;
            },
            .left => {
                if (!input.isPressed(.left) or player_x > 0) continue;
                if (!lineRangeOverlapsBy(player_y, player_y + player_body_height, exit_line.y1, exit_line.y2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                const entry_context = entryActionContext(player.*, previous_room);
                const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                    sideTransitionSourceFloorWorldY(player.*, room_index.*)
                else
                    null;
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                const aligned_entry = entryPosition(player.*);
                room_index.* = exit_line.target;
                enterRoomFromRight(player, room_index.*);
                if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .right, source_floor_world_y, aligned_entry)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                restoreEntryActionContact(player, room_index.*, entry_context);
                entry_side.* = oppositeDirection(exit_line.direction);
                startCooldown(player);
                return true;
            },
            .up => {
                if (player_y > -vertical_transition_overlap_px or player.vy > 0) continue;
                if (!lineRangeOverlapsBy(player_x, player_x + player_body_width, exit_line.x1, exit_line.x2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                const entry_context = entryActionContext(player.*, previous_room);
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                const aligned_entry = entryPosition(player.*);
                room_index.* = exit_line.target;
                clampPlayerToRoom(player, room_index.*);
                enterRoomFromBottom(player, room_index.*);
                if (!fitPlayerAfterLineRoomEntry(player, room_index.*, previous_room, .down, verticalEntryYBounds(room_index.*), aligned_entry)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                restoreEntryActionContact(player, room_index.*, entry_context);
                entry_side.* = oppositeDirection(exit_line.direction);
                startCooldown(player);
                return true;
            },
            .down => {
                if (player_y < room.height_pixels - player_body_height + vertical_transition_overlap_px or player.vy <= 0) continue;
                if (!lineRangeOverlapsBy(player_x, player_x + player_body_width, exit_line.x1, exit_line.x2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                const entry_context = entryActionContext(player.*, previous_room);
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                const aligned_entry = entryPosition(player.*);
                room_index.* = exit_line.target;
                clampPlayerToRoom(player, room_index.*);
                enterRoomFromTop(player);
                if (!fitPlayerAfterLineRoomEntry(player, room_index.*, previous_room, .up, verticalEntryYBounds(room_index.*), aligned_entry)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                restoreEntryActionContact(player, room_index.*, entry_context);
                entry_side.* = oppositeDirection(exit_line.direction);
                startCooldown(player);
                return true;
            },
        }
    }
    return false;
}

fn lineRangeOverlapsBy(a_min: i16, a_max: i16, b0: i16, b1: i16, minimum: i16) bool {
    const b_min = @min(b0, b1);
    const b_max = @max(b0, b1) + 1;
    const overlap_min = @max(a_min, b_min);
    const overlap_max = @min(a_max, b_max);
    return overlap_max - overlap_min >= minimum;
}

fn enterRoomFromLeft(player: *Player) void {
    if (fixedToPixel(player.x) < 1) {
        player.x = pixelToFixed(1);
    }
    markPlayerRoomEntry(player);
}

fn enterRoomFromRight(player: *Player, room_index: usize) void {
    const max_x = rooms[room_index].width_pixels - player_body_width - 1;
    if (fixedToPixel(player.x) > max_x) {
        player.x = pixelToFixed(max_x);
    }
    markPlayerRoomEntry(player);
}

fn enterRoomFromTop(player: *Player) void {
    const min_y = -player_body_height + vertical_transition_overlap_px;
    if (fixedToPixel(player.y) < min_y) {
        player.y = pixelToFixed(min_y);
    }
    markPlayerRoomEntry(player);
}

fn enterRoomFromBottom(player: *Player, room_index: usize) void {
    const max_y = rooms[room_index].height_pixels - vertical_transition_overlap_px;
    if (fixedToPixel(player.y) > max_y) {
        player.y = pixelToFixed(max_y);
    }
    markPlayerRoomEntry(player);
}

fn alignPlayerBetweenRooms(player: *Player, from_room: usize, to_room: usize) void {
    const from = rooms[from_room];
    const to = rooms[to_room];
    const dx = @as(i32, from.world_x - to.world_x) << fixed_shift;
    const dy = @as(i32, from.world_y - to.world_y) << fixed_shift;
    player.x += dx;
    player.y += dy;
    player.climb_ledge_start_x += dx;
    player.climb_ledge_start_y += dy;
    player.climb_ledge_target_x += dx;
    player.climb_ledge_target_y += dy;
}

fn markPlayerRoomEntry(player: *Player) void {
    player.grounded = false;
    player.dust_suppress_timer = 2;
}

fn entryPosition(player: Player) EntryPosition {
    return .{
        .x = fixedToPixel(player.x),
        .y = fixedToPixel(player.y),
    };
}

fn restoreAlignedEntryPosition(player: *Player, room_index: usize, position: EntryPosition, y_bounds: EntryYBounds) bool {
    if (position.y < y_bounds.min or position.y > y_bounds.max) return false;
    if (roomEntryCollidesAt(position.x, position.y, room_index)) return false;
    player.x = pixelToFixed(position.x);
    player.y = pixelToFixed(position.y);
    return true;
}

fn entryActionContext(player: Player, room_index: usize) EntryActionContext {
    var wall_dir = entryWallContactDirection(player, room_index);
    if (wall_dir == 0 and (player.climbing or player.climb_dangling or player.wall_sliding)) {
        wall_dir = if (player.facing_left) -1 else 1;
    }
    return .{
        .wall_dir = wall_dir,
        .vx = player.vx,
        .vy = player.vy,
        .climbing = player.climbing,
        .climb_dangling = player.climb_dangling,
        .wall_sliding = player.wall_sliding,
    };
}

fn restoreEntryActionContact(player: *Player, room_index: usize, context: EntryActionContext) void {
    const preserves_wall_action = context.climbing or context.climb_dangling or context.wall_sliding;
    if (!preserves_wall_action) return;

    player.vx = context.vx;
    player.vy = context.vy;
    player.grounded = false;

    if (context.wall_dir == 0) return;
    restoreWallContactAfterEntry(player, room_index, context.wall_dir);
    if (!entryWallContactAtPlayer(player.*, context.wall_dir, room_index)) return;

    player.facing_left = context.wall_dir < 0;
    player.climbing = context.climbing;
    player.climb_dangling = context.climb_dangling;
    player.climb_dir = if (context.climbing or context.climb_dangling) context.wall_dir else 0;
    player.wall_sliding = context.wall_sliding;
}

fn restoreWallContactAfterEntry(player: *Player, room_index: usize, wall_dir: i16) void {
    if (entryWallContactAtPlayer(player.*, wall_dir, room_index)) return;

    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    if (tryRestoreWallContactAtX(player, room_index, wall_dir, start_x, start_y)) return;
    var x_offset: i16 = 1;
    while (x_offset <= entry_wall_restore_x_px) : (x_offset += 1) {
        const toward_wall_x = start_x + wall_dir * x_offset;
        if (tryRestoreWallContactAtX(player, room_index, wall_dir, toward_wall_x, start_y)) return;
        const away_from_wall_x = start_x - wall_dir * x_offset;
        if (tryRestoreWallContactAtX(player, room_index, wall_dir, away_from_wall_x, start_y)) return;
    }
}

fn tryRestoreWallContactAtX(player: *Player, room_index: usize, wall_dir: i16, x: i16, start_y: i16) bool {
    var y_offset: i16 = 0;
    while (y_offset <= entry_wall_restore_y_px) : (y_offset += 1) {
        if (tryRestoreWallContactAt(player, room_index, wall_dir, x, start_y - y_offset)) return true;
        if (y_offset != 0 and tryRestoreWallContactAt(player, room_index, wall_dir, x, start_y + y_offset)) return true;
    }
    return false;
}

fn tryRestoreWallContactAt(player: *Player, room_index: usize, wall_dir: i16, x: i16, y: i16) bool {
    if (roomEntryCollidesAt(x, y, room_index)) return false;
    if (!entryWallContactAt(x, y, wall_dir, room_index)) return false;
    player.x = pixelToFixed(x);
    player.y = pixelToFixed(y);
    return true;
}

fn entryWallContactDirection(player: Player, room_index: usize) i16 {
    const facing_dir: i16 = if (player.facing_left) -1 else 1;
    if (entryWallContactAtPlayer(player, facing_dir, room_index)) return facing_dir;
    if (entryWallContactAtPlayer(player, -facing_dir, room_index)) return -facing_dir;
    return 0;
}

fn entryWallContactAtPlayer(player: Player, dir: i16, room_index: usize) bool {
    return entryWallContactAt(fixedToPixel(player.x), fixedToPixel(player.y), dir, room_index);
}

fn entryWallContactAt(x: i16, y: i16, dir: i16, room_index: usize) bool {
    const side_offset: i16 = if (dir < 0) -1 else player_body_width;
    const wall_x = x + side_offset;
    return roomEntryWallSolidAtPixel(wall_x, y + 2, room_index) or
        roomEntryWallSolidAtPixel(wall_x, y + player_body_height - 3, room_index);
}

fn roomEntryWallSolidAtPixel(x: i16, y: i16, room_index: usize) bool {
    return collision.solidRectAt(rooms[room_index], x, y, 1, 1);
}

fn fitPlayerAfterRoomEntry(player: *Player, room_index: usize) void {
    _ = tryFitPlayerAfterRoomEntryAt(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), fullEntryYBounds(room_index));
}

fn fitPlayerAfterVerticalRoomEntry(player: *Player, room_index: usize, aligned_entry: EntryPosition) void {
    const y_bounds = verticalEntryYBounds(room_index);
    if (restoreAlignedEntryPosition(player, room_index, aligned_entry, y_bounds)) return;
    _ = tryFitPlayerAfterRoomEntryAt(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), y_bounds);
}

fn fullEntryYBounds(room_index: usize) EntryYBounds {
    const room = rooms[room_index];
    return .{
        .min = -player_body_height + 1,
        .max = room.height_pixels - player_body_height - 1,
    };
}

fn verticalEntryYBounds(room_index: usize) EntryYBounds {
    const room = rooms[room_index];
    return .{
        .min = -player_body_height + vertical_transition_overlap_px,
        .max = room.height_pixels - vertical_transition_overlap_px,
    };
}

fn tryFitPlayerAfterRoomEntryAt(player: *Player, room_index: usize, start_x: i16, start_y: i16, y_bounds: EntryYBounds) bool {
    const room = rooms[room_index];
    const clamped_x = clampI16(start_x, 1, room.width_pixels - player_body_width - 1);
    const clamped_y = clampI16(start_y, y_bounds.min, y_bounds.max);
    player.x = pixelToFixed(clamped_x);
    player.y = pixelToFixed(clamped_y);
    if (!roomEntryCollidesAt(clamped_x, clamped_y, room_index)) return true;

    var offset: i16 = 1;
    while (offset <= 64) : (offset += 1) {
        const up_y = clamped_y - offset;
        if (up_y >= y_bounds.min and !roomEntryCollidesAt(clamped_x, up_y, room_index)) {
            player.y = pixelToFixed(up_y);
            player.vy = 0;
            player.grounded = false;
            return true;
        }

        const down_y = clamped_y + offset;
        if (down_y <= y_bounds.max and !roomEntryCollidesAt(clamped_x, down_y, room_index)) {
            player.y = pixelToFixed(down_y);
            player.vy = 0;
            player.grounded = false;
            return true;
        }
    }
    return false;
}

fn fitPlayerAfterLineRoomEntry(player: *Player, room_index: usize, from_room: usize, entry_direction: room_data.ExitDirection, y_bounds: EntryYBounds, aligned_entry: EntryPosition) bool {
    if (restoreAlignedEntryPosition(player, room_index, aligned_entry, y_bounds)) return true;
    if (reciprocalExitLine(room_index, from_room, entry_direction)) |exit_line| {
        return switch (entry_direction) {
            .up, .down => fitPlayerWithinHorizontalExitLine(player, room_index, exit_line, y_bounds),
            .left, .right => fitPlayerWithinVerticalExitLine(player, room_index, exit_line, y_bounds),
        };
    }
    return tryFitPlayerAfterRoomEntryAt(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), y_bounds);
}

fn reciprocalExitLine(room_index: usize, from_room: usize, direction: room_data.ExitDirection) ?room_data.ExitLine {
    for (rooms[room_index].exit_lines) |exit_line| {
        if (exit_line.direction == direction and exit_line.target == from_room) return exit_line;
    }
    return null;
}

fn fitPlayerWithinHorizontalExitLine(player: *Player, room_index: usize, exit_line: room_data.ExitLine, y_bounds: EntryYBounds) bool {
    const room = rooms[room_index];
    const room_min = @as(i16, 1);
    const room_max = room.width_pixels - player_body_width - 1;
    const min_x = clampI16(@min(exit_line.x1, exit_line.x2), room_min, room_max);
    var max_x = clampI16(@max(exit_line.x1, exit_line.x2) - player_body_width, room_min, room_max);
    if (max_x < min_x) max_x = min_x;
    return tryFitPlayerInXRange(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), min_x, max_x, y_bounds);
}

fn fitPlayerWithinVerticalExitLine(player: *Player, room_index: usize, exit_line: room_data.ExitLine, y_bounds: EntryYBounds) bool {
    const room_min = y_bounds.min;
    const room_max = y_bounds.max;
    const min_y = clampI16(@min(exit_line.y1, exit_line.y2), room_min, room_max);
    var max_y = clampI16(@max(exit_line.y1, exit_line.y2) - player_body_height, room_min, room_max);
    if (max_y < min_y) max_y = min_y;
    return tryFitPlayerInYRange(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), min_y, max_y, y_bounds);
}

fn tryFitPlayerInXRange(player: *Player, room_index: usize, start_x: i16, start_y: i16, min_x: i16, max_x: i16, y_bounds: EntryYBounds) bool {
    const clamped_start = clampI16(start_x, min_x, max_x);
    const max_distance = @max(absI16(clamped_start - min_x), absI16(max_x - clamped_start));
    var offset: i16 = 0;
    while (offset <= max_distance) : (offset += 1) {
        const left_x = clamped_start - offset;
        if (left_x >= min_x and tryFitPlayerAfterRoomEntryAt(player, room_index, left_x, start_y, y_bounds)) return true;

        const right_x = clamped_start + offset;
        if (offset != 0 and right_x <= max_x and tryFitPlayerAfterRoomEntryAt(player, room_index, right_x, start_y, y_bounds)) return true;
    }
    return false;
}

fn tryFitPlayerInYRange(player: *Player, room_index: usize, start_x: i16, start_y: i16, min_y: i16, max_y: i16, y_bounds: EntryYBounds) bool {
    const clamped_start = clampI16(start_y, min_y, max_y);
    const max_distance = @max(absI16(clamped_start - min_y), absI16(max_y - clamped_start));
    var offset: i16 = 0;
    while (offset <= max_distance) : (offset += 1) {
        const up_y = clamped_start - offset;
        if (up_y >= min_y and tryFitPlayerAfterRoomEntryAt(player, room_index, start_x, up_y, y_bounds)) return true;

        const down_y = clamped_start + offset;
        if (offset != 0 and down_y <= max_y and tryFitPlayerAfterRoomEntryAt(player, room_index, start_x, down_y, y_bounds)) return true;
    }
    return false;
}

fn sideTransitionSourceFloorWorldY(player: Player, room_index: usize) ?i16 {
    const room = rooms[room_index];
    const x = clampI16(fixedToPixel(player.x), 1, room.width_pixels - player_body_width - 1);
    const start_y = fixedToPixel(player.y);
    var best_y: i16 = 0;
    var best_distance: i16 = 32767;

    var offset: i16 = 0;
    while (offset <= 32) : (offset += 1) {
        if (sideTransitionFloorCandidate(x, start_y - offset, room_index)) |candidate_y| {
            best_y = candidate_y;
            best_distance = offset;
            break;
        }
        if (offset != 0) {
            if (sideTransitionFloorCandidate(x, start_y + offset, room_index)) |candidate_y| {
                best_y = candidate_y;
                best_distance = offset;
                break;
            }
        }
    }

    if (best_distance == 32767) return null;
    return best_y + room.world_y;
}

fn fitPlayerAfterSideRoomEntry(
    player: *Player,
    room_index: usize,
    from_room: usize,
    entry_direction: room_data.ExitDirection,
    source_floor_world_y: ?i16,
    aligned_entry: EntryPosition,
) bool {
    if (restoreAlignedEntryPosition(player, room_index, aligned_entry, fullEntryYBounds(room_index))) return true;
    if (reciprocalExitLine(room_index, from_room, entry_direction)) |exit_line| {
        return fitPlayerWithinVerticalExitLine(player, room_index, exit_line, fullEntryYBounds(room_index));
    }
    fitOrSnapPlayerAfterSideRoomEntry(player, room_index, source_floor_world_y);
    return !roomEntryCollidesAt(fixedToPixel(player.x), fixedToPixel(player.y), room_index);
}

fn fitOrSnapPlayerAfterSideRoomEntry(player: *Player, room_index: usize, source_floor_world_y: ?i16) void {
    if (source_floor_world_y) |floor_world_y| {
        if (snapPlayerToMatchingWorldFloorAfterSideEntry(player, room_index, floor_world_y)) return;
    }
    fitPlayerAfterRoomEntry(player, room_index);
}

fn snapPlayerToMatchingWorldFloorAfterSideEntry(player: *Player, room_index: usize, source_floor_world_y: i16) bool {
    const room = rooms[room_index];
    const x = fixedToPixel(player.x);
    var best_y: i16 = 0;
    var best_distance: i16 = 32767;

    var y: i16 = -player_body_height + 1;
    while (y <= room.height_pixels - player_body_height - 1) : (y += 1) {
        if (sideTransitionFloorCandidate(x, y, room_index)) |candidate_y| {
            const candidate_world_y = candidate_y + room.world_y;
            const distance = absI16(candidate_world_y - source_floor_world_y);
            if (distance < best_distance) {
                best_distance = distance;
                best_y = candidate_y;
            }
        }
    }

    if (best_distance == 32767 or best_distance > 24) return false;
    player.y = pixelToFixed(best_y);
    player.vy = 0;
    player.grounded = true;
    return true;
}

fn sideTransitionFloorCandidate(x: i16, y: i16, room_index: usize) ?i16 {
    if (roomEntryCollidesAt(x, y, room_index)) return null;
    if (!roomEntryFloorContactAt(x, y, room_index)) return null;
    return y;
}

fn clampPlayerToRoom(player: *Player, room_index: usize) void {
    const room = rooms[room_index];
    const x = clampI16(fixedToPixel(player.x), 1, room.width_pixels - player_body_width - 1);
    player.x = pixelToFixed(x);
}

fn startCooldown(player: *Player) void {
    player.room_transition_cooldown = transition_cooldown_frames;
}

fn floorContact(player: Player, room_index: usize) bool {
    return floorContactAt(fixedToPixel(player.x), fixedToPixel(player.y), room_index);
}

fn floorContactAt(x: i16, y: i16, room_index: usize) bool {
    return collidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index) or chapter_systems.actorFloorAt(room_index, x, y);
}

fn collidesAt(x: i16, y: i16, room_index: usize) bool {
    return collision.solidRectAt(rooms[room_index], x, y, player_body_width, player_body_height) or
        chapter_entities.dynamicSolidRectAt(room_index, x, y, player_body_width, player_body_height) or
        chapter_systems.dynamicSolidRectAt(room_index, x, y, player_body_width, player_body_height);
}

fn roomEntryCollidesAt(x: i16, y: i16, room_index: usize) bool {
    return collision.solidRectAt(rooms[room_index], x, y, player_body_width, player_body_height);
}

fn roomEntryFloorContactAt(x: i16, y: i16, room_index: usize) bool {
    return roomEntryCollidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index);
}

fn oneWayFloorAt(x: i16, player_y: i16, room_index: usize) bool {
    const player_bottom = player_y + player_body_height;
    return collision.oneWayPlatformAtBottom(rooms[room_index], x, player_bottom) or
        collision.oneWayPlatformAtBottom(rooms[room_index], x + player_body_width - 1, player_bottom);
}
