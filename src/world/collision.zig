pub fn rectsOverlap(a_left: i16, a_top: i16, a_right: i16, a_bottom: i16, b_left: i16, b_top: i16, b_right: i16, b_bottom: i16) bool {
    return a_left < b_right and a_right > b_left and a_top < b_bottom and a_bottom > b_top;
}

pub const SpikeDirection = enum(u8) {
    up = 3,
    down = 4,
    left = 5,
    right = 6,
};

pub const SpikeHit = struct {
    direction: SpikeDirection,
};

pub fn solidRectAt(room: anytype, x: i16, y: i16, width: i16, height: i16) bool {
    const left = x;
    const right = x + width - 1;
    const top = y;
    const bottom = y + height - 1;
    if (left < 0 or right >= room.width_pixels) return true;
    if (top >= room.height_pixels) return false;
    if (bottom < 0) return false;

    const tile_left: usize = @intCast(@divTrunc(left, 8));
    const tile_right: usize = @intCast(@divTrunc(right, 8));
    const clipped_top: i16 = if (top < 0) 0 else top;
    const clipped_bottom: i16 = if (bottom >= room.height_pixels) room.height_pixels - 1 else bottom;
    const tile_top: usize = @intCast(@divTrunc(clipped_top, 8));
    const tile_bottom: usize = @intCast(@divTrunc(clipped_bottom, 8));
    var tile_y = tile_top;
    while (tile_y <= tile_bottom) : (tile_y += 1) {
        var tile_x = tile_left;
        while (tile_x <= tile_right) : (tile_x += 1) {
            if (room.collision[tile_y * room.width_tiles + tile_x] == 1) return true;
        }
    }
    return false;
}

pub fn spikeRectAt(room: anytype, x: i16, y: i16, width: i16, height: i16, speed_x: i32, speed_y: i32) bool {
    return spikeHitAt(room, x, y, width, height, speed_x, speed_y) != null;
}

pub fn spikeHitAt(room: anytype, x: i16, y: i16, width: i16, height: i16, speed_x: i32, speed_y: i32) ?SpikeHit {
    const left = x;
    const right = x + width - 1;
    const top = y;
    const bottom = y + height - 1;
    const rect_left = x;
    const rect_right = x + width;
    const rect_top = y;
    const rect_bottom = y + height;
    if (right < 0 or left >= room.width_pixels) return null;
    if (bottom < 0 or top >= room.height_pixels) return null;

    const clipped_left: i16 = if (left < 0) 0 else left;
    const clipped_right: i16 = if (right >= room.width_pixels) room.width_pixels - 1 else right;
    const clipped_top: i16 = if (top < 0) 0 else top;
    const clipped_bottom: i16 = if (bottom >= room.height_pixels) room.height_pixels - 1 else bottom;
    const tile_left: usize = @intCast(@divTrunc(clipped_left, 8));
    const tile_right: usize = @intCast(@divTrunc(clipped_right, 8));
    const tile_top: usize = @intCast(@divTrunc(clipped_top, 8));
    const tile_bottom: usize = @intCast(@divTrunc(clipped_bottom, 8));
    var tile_y = tile_top;
    while (tile_y <= tile_bottom) : (tile_y += 1) {
        var tile_x = tile_left;
        while (tile_x <= tile_right) : (tile_x += 1) {
            const collision_value = room.collision[tile_y * room.width_tiles + tile_x];
            if (spikeDirection(collision_value)) |direction| {
                const spike_left: i16 = @as(i16, @intCast(tile_x)) * 8;
                const spike_top: i16 = @as(i16, @intCast(tile_y)) * 8;
                if (!movingWithSpike(direction, speed_x, speed_y) and
                    spikeTipTouchesRect(direction, rect_left, rect_top, rect_right, rect_bottom, spike_left, spike_top))
                {
                    return .{ .direction = direction };
                }
            }
        }
    }
    return null;
}

fn spikeDirection(collision_value: u8) ?SpikeDirection {
    return switch (collision_value) {
        3 => .up,
        4 => .down,
        5 => .left,
        6 => .right,
        else => null,
    };
}

fn movingWithSpike(direction: SpikeDirection, speed_x: i32, speed_y: i32) bool {
    return switch (direction) {
        .up => speed_y < 0,
        .down => speed_y > 0,
        .left => speed_x < 0,
        .right => speed_x > 0,
    };
}

fn spikeTipTouchesRect(direction: SpikeDirection, rect_left: i16, rect_top: i16, rect_right: i16, rect_bottom: i16, tile_left: i16, tile_top: i16) bool {
    switch (direction) {
        .up => return horizontalEdgeTouchesSpike(direction, rect_bottom - 1, rect_left, rect_right, tile_left, tile_top),
        .down => return horizontalEdgeTouchesSpike(direction, rect_top, rect_left, rect_right, tile_left, tile_top),
        .left => return verticalEdgeTouchesSpike(direction, rect_left, rect_top, rect_bottom, tile_left, tile_top),
        .right => return verticalEdgeTouchesSpike(direction, rect_right - 1, rect_top, rect_bottom, tile_left, tile_top),
    }
}

fn horizontalEdgeTouchesSpike(direction: SpikeDirection, edge_y: i16, rect_left: i16, rect_right: i16, tile_left: i16, tile_top: i16) bool {
    if (edge_y < tile_top or edge_y >= tile_top + 8) return false;

    const start_x = @max(rect_left, tile_left);
    const end_x = @min(rect_right, tile_left + 8);
    var x = start_x;
    while (x < end_x) : (x += 1) {
        if (spikePixelAt(direction, x, edge_y, tile_left, tile_top)) return true;
    }
    return false;
}

fn verticalEdgeTouchesSpike(direction: SpikeDirection, edge_x: i16, rect_top: i16, rect_bottom: i16, tile_left: i16, tile_top: i16) bool {
    if (edge_x < tile_left or edge_x >= tile_left + 8) return false;

    const start_y = @max(rect_top, tile_top);
    const end_y = @min(rect_bottom, tile_top + 8);
    var y = start_y;
    while (y < end_y) : (y += 1) {
        if (spikePixelAt(direction, edge_x, y, tile_left, tile_top)) return true;
    }
    return false;
}

fn spikePixelAt(direction: SpikeDirection, x: i16, y: i16, tile_left: i16, tile_top: i16) bool {
    const local_x = x - tile_left;
    const local_y = y - tile_top;
    return switch (direction) {
        .up => local_y >= 3 and inSpikeBand(local_x, local_y - 3),
        .down => local_y <= 4 and inSpikeBand(local_x, 4 - local_y),
        .left => local_x >= 3 and inSpikeBand(local_y, local_x - 3),
        .right => local_x <= 4 and inSpikeBand(local_y, 4 - local_x),
    };
}

fn inSpikeBand(axis: i16, from_tip: i16) bool {
    const reach = @min(from_tip, @as(i16, 3));
    return axis >= 3 - reach and axis <= 4 + reach;
}

pub fn oneWayPlatformTopAtBottom(room: anytype, x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    if (x < 0 or x >= room.width_pixels or next_bottom < 0 or next_bottom >= room.height_pixels) return null;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(next_bottom, 8));
    if (room.collision[tile_y * room.width_tiles + tile_x] != 2) return null;

    const platform_top = @as(i16, @intCast(tile_y)) * 8;
    if (old_bottom <= platform_top and next_bottom >= platform_top and next_bottom < platform_top + 4) {
        return platform_top;
    }
    return null;
}

pub fn oneWayPlatformAtBottom(room: anytype, x: i16, bottom_y: i16) bool {
    if (x < 0 or x >= room.width_pixels or bottom_y < 0 or bottom_y >= room.height_pixels) return false;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(bottom_y, 8));
    if (room.collision[tile_y * room.width_tiles + tile_x] != 2) return false;
    const platform_top = @as(i16, @intCast(tile_y)) * 8;
    return bottom_y >= platform_top and bottom_y < platform_top + 4;
}
