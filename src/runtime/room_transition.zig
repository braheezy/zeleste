const gba = @import("gba");
const collision = @import("collision.zig");
const falling_blocks = @import("falling_blocks.zig");
const funny_cars = @import("funny_cars.zig");
const level = @import("../generated_rooms.zig");
const math = @import("math.zig");
const player_mod = @import("player.zig");
const prologue_bridge = @import("prologue_bridge.zig");
const room_data = @import("room_data.zig");

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

pub fn trySwitch(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize, respawn: *Spawn) bool {
    if (player.room_transition_cooldown > 0) return false;

    const room = rooms[room_index.*];
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    if (input.isPressed(.right) and player_x >= room.width_pixels - player_body_width) {
        if (room.right) |next_room| {
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, room_index.*, next_room);
            room_index.* = next_room;
            enterRoomFromLeft(player);
            fitOrSnapPlayerAfterSideRoomEntry(player, room_index.*, source_floor_world_y);
            respawn.* = rooms[room_index.*].spawn_left;
            startCooldown(player);
            return true;
        }
    }
    if (input.isPressed(.left) and player_x <= 0) {
        if (room.left) |next_room| {
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, room_index.*, next_room);
            room_index.* = next_room;
            enterRoomFromRight(player, room_index.*);
            fitOrSnapPlayerAfterSideRoomEntry(player, room_index.*, source_floor_world_y);
            respawn.* = rooms[room_index.*].spawn_right;
            startCooldown(player);
            return true;
        }
    }
    if (player_y <= 0) {
        if (room.up) |next_room| {
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromBottom(player, room_index.*);
            fitPlayerAfterRoomEntry(player, room_index.*);
            respawn.* = rooms[room_index.*].spawn_bottom;
            startCooldown(player);
            return true;
        }
    }
    if (player_y >= room.height_pixels - player_body_height - 1) {
        if (room.down) |next_room| {
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromTop(player);
            fitPlayerAfterRoomEntry(player, room_index.*);
            respawn.* = rooms[room_index.*].spawn_top;
            startCooldown(player);
            return true;
        }
    }
    return false;
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
    const room = rooms[room_index];
    const clamped_y = clampI16(fixedToPixel(player.y), -player_body_height + 1, room.height_pixels - player_body_height - 1);
    player.y = pixelToFixed(clamped_y);
    if (!roomEntryCollidesAt(fixedToPixel(player.x), fixedToPixel(player.y), room_index)) return;

    var offset: i16 = 1;
    while (offset <= 64) : (offset += 1) {
        const up_y = clamped_y - offset;
        if (up_y >= -player_body_height + 1 and !roomEntryCollidesAt(fixedToPixel(player.x), up_y, room_index)) {
            player.y = pixelToFixed(up_y);
            player.vy = 0;
            player.grounded = false;
            return;
        }

        const down_y = clamped_y + offset;
        if (down_y <= room.height_pixels - player_body_height - 1 and !roomEntryCollidesAt(fixedToPixel(player.x), down_y, room_index)) {
            player.y = pixelToFixed(down_y);
            player.vy = 0;
            player.grounded = false;
            return;
        }
    }
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
    return collidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index) or funny_cars.floorAt(x, y);
}

fn collidesAt(x: i16, y: i16, room_index: usize) bool {
    return collision.solidRectAt(rooms[room_index], x, y, player_body_width, player_body_height) or
        falling_blocks.solidRectAt(x, y, player_body_width, player_body_height) or
        prologue_bridge.solidRectAt(x, y, player_body_width, player_body_height);
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
