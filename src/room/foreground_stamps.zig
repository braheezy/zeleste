const dynamic_object_slots = @import("dynamic_object_slots.zig");
const oam = @import("../core/oam.zig");

pub const occluding_first_object = 8;
pub const max_stamps = 24;
pub const behind_first_object = dynamic_object_slots.first_object + dynamic_object_slots.object_capacity;
pub const base_tile: u10 = 576;

pub fn load(room_index: usize) void {
    _ = room_index;
    hideObjects();
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < max_stamps) : (index += 1) {
        oam.hideObject(occluding_first_object + index);
        oam.hideObject(behind_first_object + index);
    }
}

pub fn behindObjectCount() usize {
    return 0;
}
