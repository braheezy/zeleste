const room_data = @import("room_data.zig");
const math = @import("../core/math.zig");
const video = @import("../core/video.zig");

pub const Camera = struct {
    x: i16,
    y: i16,
};

pub fn forPlayer(player_x: i32, player_y: i32, room: room_data.RoomBackground) Camera {
    const desired_x = math.fixedToPixel(player_x) - 120;
    const desired_y = math.fixedToPixel(player_y) - 120;
    return .{
        .x = math.clampI16(desired_x, 0, room.width_pixels - video.screen_width),
        .y = math.clampI16(desired_y, 0, room.height_pixels - video.screen_height),
    };
}

pub fn withOffset(base: Camera, room: room_data.RoomBackground, offset_x: i16, offset_y: i16) Camera {
    return .{
        .x = math.clampI16(base.x + offset_x, 0, room.width_pixels - video.screen_width),
        .y = math.clampI16(base.y + offset_y, 0, room.height_pixels - video.screen_height),
    };
}
