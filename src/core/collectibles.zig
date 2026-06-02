pub const max_rooms = 128;
pub const max_strawberries_per_room = 32;
pub const max_strawberries = max_rooms * max_strawberries_per_room;

pub const flags_per_word = 32;
pub const flag_word_count = (max_strawberries + flags_per_word - 1) / flags_per_word;

var strawberry_flags: [flag_word_count]u32 = [_]u32{0} ** flag_word_count;
var strawberry_count: u16 = 0;
var strawberry_score: u32 = 0;
var strawberry_one_ups: u16 = 0;

pub fn strawberryId(room_index: usize, local_index: usize) ?u16 {
    const value = room_index * max_strawberries_per_room + local_index;
    if (value >= max_strawberries) return null;
    return @intCast(value);
}

pub fn isStrawberryCollected(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (strawberry_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn markStrawberryCollected(id: u16, combo_index: u8) bool {
    if (isStrawberryCollected(id)) return false;
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    strawberry_flags[word_index] |= @as(u32, 1) << shift;
    strawberry_count += 1;
    const score_value = strawberryScoreForCombo(combo_index);
    if (score_value == 0) {
        strawberry_one_ups += 1;
    } else {
        strawberry_score += score_value;
    }
    return true;
}

pub fn collectedStrawberries() u16 {
    return strawberry_count;
}

pub fn strawberryScore() u32 {
    return strawberry_score;
}

pub fn strawberryOneUps() u16 {
    return strawberry_one_ups;
}

pub fn copyStrawberryFlags(out: *[flag_word_count]u32) void {
    out.* = strawberry_flags;
}

pub fn restoreStrawberries(flags: *const [flag_word_count]u32, count: u16, score: u32, one_ups: u16) void {
    strawberry_flags = flags.*;
    strawberry_count = count;
    strawberry_score = score;
    strawberry_one_ups = one_ups;
}

pub fn resetSession() void {
    strawberry_flags = [_]u32{0} ** flag_word_count;
    strawberry_count = 0;
    strawberry_score = 0;
    strawberry_one_ups = 0;
}

pub fn strawberryScoreForCombo(combo_index: u8) u32 {
    return switch (combo_index) {
        0 => 1000,
        1 => 2000,
        2 => 3000,
        3 => 4000,
        4 => 5000,
        else => 0,
    };
}
