const collision = @import("collision.zig");
const falling_blocks = @import("falling_blocks.zig");
const funny_cars = @import("funny_cars.zig");
const level = @import("../generated_rooms.zig");
const math = @import("math.zig");
const player_mod = @import("player.zig");
const prologue_bridge = @import("prologue_bridge.zig");

const Player = player_mod.State;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;

const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const rooms = level.rooms;

pub fn wallSlideContact(player: Player, horizontal: i16, room_index: usize) bool {
    if (horizontal == 0) return false;
    return wallContact(player, horizontal, room_index);
}

pub fn wallJumpDirection(player: Player, horizontal: i16, room_index: usize) i16 {
    if (wallContact(player, -1, room_index) and horizontal <= 0) return 1;
    if (wallContact(player, 1, room_index) and horizontal >= 0) return -1;
    if (wallContact(player, -1, room_index)) return 1;
    if (wallContact(player, 1, room_index)) return -1;
    return 0;
}

pub fn wallContact(player: Player, dir: i16, room_index: usize) bool {
    const side_offset: i16 = if (dir < 0) -1 else player_body_width;
    const x = fixedToPixel(player.x) + side_offset;
    const y = fixedToPixel(player.y);
    return wallSolidAtPixel(x, y + 2, room_index) or
        wallSolidAtPixel(x, y + player_body_height - 3, room_index);
}

pub fn wallSolidAtPixel(x: i16, y: i16, room_index: usize) bool {
    return solidAtPixel(x, y, room_index) or dynamicSolidAtPixel(x, y);
}

pub fn floorContact(player: Player, room_index: usize) bool {
    return floorContactAt(fixedToPixel(player.x), fixedToPixel(player.y), room_index);
}

pub fn floorContactAt(x: i16, y: i16, room_index: usize) bool {
    return collidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index) or funny_cars.floorAt(x, y);
}

pub fn moveHorizontal(player: *Player, amount: i32, room_index: usize) void {
    if (amount == 0) return;
    const target = player.x + amount;
    const step: i16 = if (amount < 0) -1 else 1;
    var pixel = fixedToPixel(player.x);
    const target_pixel = fixedToPixel(target);
    while (pixel != target_pixel) {
        const next = pixel + step;
        const player_y = fixedToPixel(player.y);
        if (collidesAt(next, player_y, room_index)) {
            if (player.grounded) {
                var lift: i16 = 1;
                while (lift <= 2) : (lift += 1) {
                    const lifted_y = player_y - lift;
                    if (!collidesAt(next, lifted_y, room_index)) {
                        player.y = pixelToFixed(lifted_y);
                        pixel = next;
                        break;
                    }
                } else {
                    player.x = pixelToFixed(pixel);
                    player.vx = 0;
                    return;
                }
            } else {
                player.x = pixelToFixed(pixel);
                player.vx = 0;
                return;
            }
        } else {
            pixel = next;
        }
    }
    player.x = target;
}

pub fn moveVertical(player: *Player, amount: i32, room_index: usize) void {
    if (amount == 0) return;
    const target = player.y + amount;
    const step: i16 = if (amount < 0) -1 else 1;
    var pixel = fixedToPixel(player.y);
    const target_pixel = fixedToPixel(target);
    while (pixel != target_pixel) {
        const next = pixel + step;
        if (collidesAt(fixedToPixel(player.x), next, room_index)) {
            player.y = pixelToFixed(pixel);
            player.vy = 0;
            player.grounded = step > 0;
            return;
        }
        if (step > 0) {
            if (oneWayPlatformTopForPlayer(fixedToPixel(player.x), pixel, next, room_index)) |platform_top| {
                player.y = pixelToFixed(platform_top - player_body_height);
                player.vy = 0;
                player.grounded = true;
                return;
            }
        }
        pixel = next;
    }
    player.y = target;
}

pub fn resolvePlayerEmbedding(player: *Player, room_index: usize) void {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    if (!collidesAt(start_x, start_y, room_index)) return;

    var radius: i16 = 1;
    while (radius <= 10) : (radius += 1) {
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x - radius, start_y)) return;
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x + radius, start_y)) return;
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x, start_y - radius)) return;
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x, start_y + radius)) return;

        var offset: i16 = 1;
        while (offset <= radius) : (offset += 1) {
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x - radius, start_y - offset)) return;
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x + radius, start_y - offset)) return;
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x - radius, start_y + offset)) return;
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x + radius, start_y + offset)) return;
        }
    }
}

pub fn collidesAt(x: i16, y: i16, room_index: usize) bool {
    return solidRectAt(x, y, player_body_width, player_body_height, room_index) or
        dynamicSolidRectAt(x, y, player_body_width, player_body_height);
}

pub fn solidRectAt(x: i16, y: i16, width: i16, height: i16, room_index: usize) bool {
    return collision.solidRectAt(rooms[room_index], x, y, width, height);
}

pub fn dynamicSolidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    if (falling_blocks.solidRectAt(x, y, width, height)) return true;
    return prologue_bridge.solidRectAt(x, y, width, height);
}

fn tryResolvePlayerEmbeddingAt(player: *Player, room_index: usize, x: i16, y: i16) bool {
    if (collidesAt(x, y, room_index)) return false;
    player.x = pixelToFixed(x);
    player.y = pixelToFixed(y);
    player.vx = 0;
    player.vy = 0;
    player.climb_ledge_timer = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.wall_sliding = false;
    player.grounded = floorContactAt(x, y, room_index);
    return true;
}

fn solidAtPixel(x: i16, y: i16, room_index: usize) bool {
    return solidRectAt(x, y, 1, 1, room_index);
}

fn oneWayFloorAt(x: i16, player_y: i16, room_index: usize) bool {
    const player_bottom = player_y + player_body_height;
    return oneWayPlatformAtBottom(x, player_bottom, room_index) or
        oneWayPlatformAtBottom(x + player_body_width - 1, player_bottom, room_index);
}

fn oneWayPlatformTopForPlayer(player_x: i16, old_y: i16, next_y: i16, room_index: usize) ?i16 {
    const old_bottom = old_y + player_body_height - 1;
    const next_bottom = next_y + player_body_height - 1;
    if (oneWayPlatformTopAtBottom(player_x, old_bottom, next_bottom, room_index)) |platform_top| {
        return platform_top;
    }
    if (oneWayPlatformTopAtBottom(player_x + player_body_width - 1, old_bottom, next_bottom, room_index)) |platform_top| {
        return platform_top;
    }
    return funny_cars.topForPlayer(player_x, old_bottom, next_bottom);
}

fn oneWayPlatformTopAtBottom(x: i16, old_bottom: i16, next_bottom: i16, room_index: usize) ?i16 {
    return collision.oneWayPlatformTopAtBottom(rooms[room_index], x, old_bottom, next_bottom);
}

fn oneWayPlatformAtBottom(x: i16, bottom_y: i16, room_index: usize) bool {
    return collision.oneWayPlatformAtBottom(rooms[room_index], x, bottom_y);
}

fn dynamicSolidAtPixel(x: i16, y: i16) bool {
    return dynamicSolidRectAt(x, y, 1, 1);
}
