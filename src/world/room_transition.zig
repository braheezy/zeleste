const gba = @import("gba");
const breakable_walls = @import("../room/breakable_walls.zig");
const chapter_systems = @import("../chapters/systems.zig");
const collision = @import("collision.zig");
const disappearing_platforms = @import("../room/disappearing_platforms.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mech_blocks = @import("../room/mech_blocks.zig");
const player_mod = @import("../player/state.zig");
const rhythm_blocks = @import("../room/rhythm_blocks.zig");
const room_data = @import("room_data.zig");
const traffic_blocks = @import("../room/traffic_blocks.zig");

const Player = player_mod.State;
const Spawn = room_data.Spawn;

const fixed_shift = math.fixed_shift;
const pixelToFixed = math.pixelToFixed;
const fixedToPixel = math.fixedToPixel;
const absI16 = math.absI16;
const clampI16 = math.clampI16;

const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const transition_cooldown_frames = player_mod.room_transition_cooldown_frames;
const exit_line_min_overlap_px: i16 = 4;

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

pub fn respawnForDeath(room_index: usize, player: Player) Spawn {
    const room = rooms[room_index];
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const candidates = [_]Spawn{
        room.spawn,
        room.spawn_left,
        room.spawn_right,
        room.spawn_top,
        room.spawn_bottom,
    };

    var best = candidates[0];
    var best_distance: i32 = respawnDistance(player_x, player_y, best);
    for (candidates[1..]) |candidate| {
        const distance = respawnDistance(player_x, player_y, candidate);
        if (distance < best_distance) {
            best = candidate;
            best_distance = distance;
        }
    }
    return best;
}

pub fn trySwitch(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize) bool {
    if (player.room_transition_cooldown > 0) return false;

    const room = rooms[room_index.*];
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    if (tryExitLineSwitch(player, input, room_index, player_x, player_y)) return true;
    if (input.isPressed(.right) and player_x >= room.width_pixels - player_body_width and !hasExitLine(room, .right)) {
        if (room.right) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .right, player_x, player_y)) return false;
            const previous_room = room_index.*;
            const previous_player = player.*;
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, previous_room, next_room);
            room_index.* = next_room;
            enterRoomFromLeft(player);
            if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .left, source_floor_world_y)) {
                player.* = previous_player;
                room_index.* = previous_room;
                return false;
            }
            startCooldown(player);
            return true;
        }
    }
    if (input.isPressed(.left) and player_x <= 0 and !hasExitLine(room, .left)) {
        if (room.left) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .left, player_x, player_y)) return false;
            const previous_room = room_index.*;
            const previous_player = player.*;
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, previous_room, next_room);
            room_index.* = next_room;
            enterRoomFromRight(player, room_index.*);
            if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .right, source_floor_world_y)) {
                player.* = previous_player;
                room_index.* = previous_room;
                return false;
            }
            startCooldown(player);
            return true;
        }
    }
    if (player_y <= 0 and player.vy < 0 and !hasExitLine(room, .up)) {
        if (room.up) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .up, player_x, player_y)) return false;
            alignPlayerBetweenRooms(player, room_index.*, next_room);
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromBottom(player, room_index.*);
            fitPlayerAfterRoomEntry(player, room_index.*);
            startCooldown(player);
            return true;
        }
    }
    if (player_y >= room.height_pixels - player_body_height - 1 and player.vy > 0 and !hasExitLine(room, .down)) {
        if (room.down) |next_room| {
            if (!implicitEdgeTransitionAllowed(room_index.*, next_room, .down, player_x, player_y)) return false;
            alignPlayerBetweenRooms(player, room_index.*, next_room);
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromTop(player);
            fitPlayerAfterRoomEntry(player, room_index.*);
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
) bool {
    const room = rooms[room_index.*];
    for (room.exit_lines) |exit_line| {
        switch (exit_line.direction) {
            .right => {
                if (!input.isPressed(.right) or player_x < room.width_pixels - player_body_width) continue;
                if (!lineRangeOverlapsBy(player_y, player_y + player_body_height, exit_line.y1, exit_line.y2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                    sideTransitionSourceFloorWorldY(player.*, room_index.*)
                else
                    null;
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                room_index.* = exit_line.target;
                enterRoomFromLeft(player);
                if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .left, source_floor_world_y)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                startCooldown(player);
                return true;
            },
            .left => {
                if (!input.isPressed(.left) or player_x > 0) continue;
                if (!lineRangeOverlapsBy(player_y, player_y + player_body_height, exit_line.y1, exit_line.y2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                    sideTransitionSourceFloorWorldY(player.*, room_index.*)
                else
                    null;
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                room_index.* = exit_line.target;
                enterRoomFromRight(player, room_index.*);
                if (!fitPlayerAfterSideRoomEntry(player, room_index.*, previous_room, .right, source_floor_world_y)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                startCooldown(player);
                return true;
            },
            .up => {
                if (player_y > 0 or player.vy >= 0) continue;
                if (!lineRangeOverlapsBy(player_x, player_x + player_body_width, exit_line.x1, exit_line.x2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                room_index.* = exit_line.target;
                clampPlayerToRoom(player, room_index.*);
                enterRoomFromBottom(player, room_index.*);
                if (!fitPlayerAfterLineRoomEntry(player, room_index.*, previous_room, .down)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
                startCooldown(player);
                return true;
            },
            .down => {
                if (player_y < room.height_pixels - player_body_height - 1 or player.vy <= 0) continue;
                if (!lineRangeOverlapsBy(player_x, player_x + player_body_width, exit_line.x1, exit_line.x2, exit_line_min_overlap_px)) continue;
                const previous_room = room_index.*;
                const previous_player = player.*;
                alignPlayerBetweenRooms(player, previous_room, exit_line.target);
                room_index.* = exit_line.target;
                clampPlayerToRoom(player, room_index.*);
                enterRoomFromTop(player);
                if (!fitPlayerAfterLineRoomEntry(player, room_index.*, previous_room, .up)) {
                    player.* = previous_player;
                    room_index.* = previous_room;
                    continue;
                }
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

fn respawnDistance(player_x: i16, player_y: i16, spawn: Spawn) i32 {
    return absI32(@as(i32, player_x) - spawn.x) + absI32(@as(i32, player_y) - spawn.y);
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

fn enterRoomFromLeft(player: *Player) void {
    player.x = pixelToFixed(1);
    resetPlayerStateForSideRoomEntry(player);
}

fn enterRoomFromRight(player: *Player, room_index: usize) void {
    player.x = pixelToFixed(rooms[room_index].width_pixels - player_body_width - 1);
    resetPlayerStateForSideRoomEntry(player);
}

fn enterRoomFromTop(player: *Player) void {
    player.y = pixelToFixed(1);
    resetPlayerMotionForRoomEntry(player);
}

fn enterRoomFromBottom(player: *Player, room_index: usize) void {
    player.y = pixelToFixed(rooms[room_index].height_pixels - player_body_height - 8);
    resetPlayerMotionForRoomEntry(player);
}

fn alignPlayerBetweenRooms(player: *Player, from_room: usize, to_room: usize) void {
    const from = rooms[from_room];
    const to = rooms[to_room];
    player.x += @as(i32, from.world_x - to.world_x) << fixed_shift;
    player.y += @as(i32, from.world_y - to.world_y) << fixed_shift;
}

fn resetPlayerMotionForRoomEntry(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    resetPlayerStateForSideRoomEntry(player);
}

fn resetPlayerStateForSideRoomEntry(player: *Player) void {
    player.grounded = false;
    player.dust_suppress_timer = 2;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_ledge_timer = 0;
}

fn fitPlayerAfterRoomEntry(player: *Player, room_index: usize) void {
    _ = tryFitPlayerAfterRoomEntryAt(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y));
}

fn tryFitPlayerAfterRoomEntryAt(player: *Player, room_index: usize, start_x: i16, start_y: i16) bool {
    const room = rooms[room_index];
    const clamped_x = clampI16(start_x, 1, room.width_pixels - player_body_width - 1);
    const clamped_y = clampI16(start_y, -player_body_height + 1, room.height_pixels - player_body_height - 1);
    player.x = pixelToFixed(clamped_x);
    player.y = pixelToFixed(clamped_y);
    if (!roomEntryCollidesAt(clamped_x, clamped_y, room_index)) return true;

    var offset: i16 = 1;
    while (offset <= 64) : (offset += 1) {
        const up_y = clamped_y - offset;
        if (up_y >= -player_body_height + 1 and !roomEntryCollidesAt(clamped_x, up_y, room_index)) {
            player.y = pixelToFixed(up_y);
            player.vy = 0;
            player.grounded = false;
            return true;
        }

        const down_y = clamped_y + offset;
        if (down_y <= room.height_pixels - player_body_height - 1 and !roomEntryCollidesAt(clamped_x, down_y, room_index)) {
            player.y = pixelToFixed(down_y);
            player.vy = 0;
            player.grounded = false;
            return true;
        }
    }
    return false;
}

fn fitPlayerAfterLineRoomEntry(player: *Player, room_index: usize, from_room: usize, entry_direction: room_data.ExitDirection) bool {
    if (reciprocalExitLine(room_index, from_room, entry_direction)) |exit_line| {
        return switch (entry_direction) {
            .up, .down => fitPlayerWithinHorizontalExitLine(player, room_index, exit_line),
            .left, .right => fitPlayerWithinVerticalExitLine(player, room_index, exit_line),
        };
    }
    return tryFitPlayerAfterRoomEntryAt(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y));
}

fn reciprocalExitLine(room_index: usize, from_room: usize, direction: room_data.ExitDirection) ?room_data.ExitLine {
    for (rooms[room_index].exit_lines) |exit_line| {
        if (exit_line.direction == direction and exit_line.target == from_room) return exit_line;
    }
    return null;
}

fn fitPlayerWithinHorizontalExitLine(player: *Player, room_index: usize, exit_line: room_data.ExitLine) bool {
    const room = rooms[room_index];
    const room_min = @as(i16, 1);
    const room_max = room.width_pixels - player_body_width - 1;
    const min_x = clampI16(@min(exit_line.x1, exit_line.x2), room_min, room_max);
    var max_x = clampI16(@max(exit_line.x1, exit_line.x2) - player_body_width, room_min, room_max);
    if (max_x < min_x) max_x = min_x;
    return tryFitPlayerInXRange(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), min_x, max_x);
}

fn fitPlayerWithinVerticalExitLine(player: *Player, room_index: usize, exit_line: room_data.ExitLine) bool {
    const room = rooms[room_index];
    const room_min = -player_body_height + 1;
    const room_max = room.height_pixels - player_body_height - 1;
    const min_y = clampI16(@min(exit_line.y1, exit_line.y2), room_min, room_max);
    var max_y = clampI16(@max(exit_line.y1, exit_line.y2) - player_body_height, room_min, room_max);
    if (max_y < min_y) max_y = min_y;
    return tryFitPlayerInYRange(player, room_index, fixedToPixel(player.x), fixedToPixel(player.y), min_y, max_y);
}

fn tryFitPlayerInXRange(player: *Player, room_index: usize, start_x: i16, start_y: i16, min_x: i16, max_x: i16) bool {
    const clamped_start = clampI16(start_x, min_x, max_x);
    const max_distance = @max(absI16(clamped_start - min_x), absI16(max_x - clamped_start));
    var offset: i16 = 0;
    while (offset <= max_distance) : (offset += 1) {
        const left_x = clamped_start - offset;
        if (left_x >= min_x and tryFitPlayerAfterRoomEntryAt(player, room_index, left_x, start_y)) return true;

        const right_x = clamped_start + offset;
        if (offset != 0 and right_x <= max_x and tryFitPlayerAfterRoomEntryAt(player, room_index, right_x, start_y)) return true;
    }
    return false;
}

fn tryFitPlayerInYRange(player: *Player, room_index: usize, start_x: i16, start_y: i16, min_y: i16, max_y: i16) bool {
    const clamped_start = clampI16(start_y, min_y, max_y);
    const max_distance = @max(absI16(clamped_start - min_y), absI16(max_y - clamped_start));
    var offset: i16 = 0;
    while (offset <= max_distance) : (offset += 1) {
        const up_y = clamped_start - offset;
        if (up_y >= min_y and tryFitPlayerAfterRoomEntryAt(player, room_index, start_x, up_y)) return true;

        const down_y = clamped_start + offset;
        if (offset != 0 and down_y <= max_y and tryFitPlayerAfterRoomEntryAt(player, room_index, start_x, down_y)) return true;
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
) bool {
    if (reciprocalExitLine(room_index, from_room, entry_direction)) |exit_line| {
        return fitPlayerWithinVerticalExitLine(player, room_index, exit_line);
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
        breakable_walls.solidRectAt(x, y, player_body_width, player_body_height) or
        mech_blocks.solidRectAt(x, y, player_body_width, player_body_height) or
        traffic_blocks.solidRectAt(x, y, player_body_width, player_body_height) or
        rhythm_blocks.solidRectAt(x, y, player_body_width, player_body_height) or
        disappearing_platforms.solidRectAt(x, y, player_body_width, player_body_height) or
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
