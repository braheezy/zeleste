pub fn rectsOverlap(a_left: i16, a_top: i16, a_right: i16, a_bottom: i16, b_left: i16, b_top: i16, b_right: i16, b_bottom: i16) bool {
    return a_left < b_right and a_right > b_left and a_top < b_bottom and a_bottom > b_top;
}

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

pub fn spikeRectAt(room: anytype, x: i16, y: i16, width: i16, height: i16) bool {
    const left = x;
    const right = x + width - 1;
    const top = y;
    const bottom = y + height - 1;
    const rect_left = x;
    const rect_right = x + width;
    const rect_top = y;
    const rect_bottom = y + height;
    if (right < 0 or left >= room.width_pixels) return false;
    if (bottom < 0 or top >= room.height_pixels) return false;

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
            if (collision_value >= 3 and collision_value <= 6) {
                const spike_left: i16 = @as(i16, @intCast(tile_x)) * 8;
                var hit_left = spike_left;
                var hit_top: i16 = @as(i16, @intCast(tile_y)) * 8;
                var hit_right = spike_left + 8;
                var hit_bottom = hit_top + 8;
                switch (collision_value) {
                    3 => hit_top += 3,
                    4 => hit_bottom = hit_top + 5,
                    5 => hit_left += 3,
                    6 => hit_right = hit_left + 5,
                    else => {},
                }
                if (rectsOverlap(rect_left, rect_top, rect_right, rect_bottom, hit_left, hit_top, hit_right, hit_bottom)) return true;
            }
        }
    }
    return false;
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
