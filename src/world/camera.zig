const room_data = @import("room_data.zig");
const math = @import("../core/math.zig");
const video = @import("../core/video.zig");

pub const Camera = struct {
    x: i16,
    y: i16,
};

const follow_deadzone_pixels: i16 = 1;
const shallow_room_vertical_slop: i16 = 24;
const shallow_room_upward_margin: i16 = 40;

pub fn forPlayer(player_x: i32, player_y: i32, room: room_data.RoomBackground) Camera {
    const max_scroll_y = room.height_pixels - video.screen_height;
    const player_pixel_y = math.fixedToPixel(player_y);
    const desired_x = math.fixedToPixel(player_x) - 120;
    const desired_y = desiredVerticalScroll(player_pixel_y, max_scroll_y);
    return .{
        .x = math.clampI16(desired_x, 0, room.width_pixels - video.screen_width),
        .y = math.clampI16(desired_y, 0, max_scroll_y),
    };
}

pub fn followPlayer(previous: Camera, player_x: i32, player_y: i32, room: room_data.RoomBackground) Camera {
    const desired = forPlayer(player_x, player_y, room);
    return .{
        .x = followAxis(previous.x, desired.x, 0, room.width_pixels - video.screen_width),
        .y = followAxis(previous.y, desired.y, 0, room.height_pixels - video.screen_height),
    };
}

pub fn withOffset(base: Camera, room: room_data.RoomBackground, offset_x: i16, offset_y: i16) Camera {
    return .{
        .x = math.clampI16(base.x + offset_x, 0, room.width_pixels - video.screen_width),
        .y = math.clampI16(base.y + offset_y, 0, room.height_pixels - video.screen_height),
    };
}

fn desiredVerticalScroll(player_y: i16, max_scroll_y: i16) i16 {
    if (max_scroll_y > 0 and max_scroll_y <= shallow_room_vertical_slop) {
        return math.clampI16(player_y - shallow_room_upward_margin, 0, max_scroll_y);
    }
    return player_y - 120;
}

fn followAxis(previous: i16, desired: i16, min_value: i16, max_value: i16) i16 {
    if (desired > previous + follow_deadzone_pixels) {
        return math.clampI16(desired - follow_deadzone_pixels, min_value, max_value);
    }
    if (desired < previous - follow_deadzone_pixels) {
        return math.clampI16(desired + follow_deadzone_pixels, min_value, max_value);
    }
    return math.clampI16(previous, min_value, max_value);
}
