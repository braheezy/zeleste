const player_render = @import("../player/render.zig");

pub const max_falling_blocks = 8;
pub const falling_objects_per_block = 3;
pub const first_object = player_render.sweat_object + 1;
pub const object_capacity = max_falling_blocks * falling_objects_per_block;
