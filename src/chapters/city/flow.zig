const level = @import("../../generated_rooms.zig");

pub const chapter_index: i32 = 1;
pub const first_room_id = "1";

const generated_first_room_id = "city_1";
const generated_room_prefix = "city_";

pub fn firstRoomIndex() ?usize {
    return generatedRoomIndexFor(first_room_id);
}

pub fn ownsGeneratedRoomIndex(room_index: usize) bool {
    if (room_index >= level.room_ids.len) return false;
    return startsWith(level.room_ids[room_index], generated_room_prefix);
}

pub fn roomIndexFor(chapter: i32, room_id: []const u8) ?usize {
    if (chapter != chapter_index) return null;
    if (startsWith(room_id, generated_room_prefix)) return generatedRoomIndexFor(room_id[generated_room_prefix.len..]);
    return generatedRoomIndexFor(room_id);
}

fn generatedRoomIndexFor(room_id: []const u8) ?usize {
    for (level.room_ids, 0..) |candidate, index| {
        if (!startsWith(candidate, generated_room_prefix)) continue;
        if (bytesEqual(candidate[generated_room_prefix.len..], room_id)) return index;
    }
    if (bytesEqual(room_id, first_room_id)) {
        return level.roomIndexFor(level.chapter_index, generated_first_room_id);
    }
    return null;
}

fn bytesEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |value, index| {
        if (value != b[index]) return false;
    }
    return true;
}

fn startsWith(value: []const u8, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;
    return bytesEqual(value[0..prefix.len], prefix);
}
