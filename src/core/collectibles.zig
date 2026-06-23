pub const max_rooms = 128;
pub const max_strawberries_per_room = 32;
pub const max_strawberries = max_rooms * max_strawberries_per_room;
pub const max_cassettes_per_room = 4;
pub const max_cassettes = max_rooms * max_cassettes_per_room;
pub const max_crystal_hearts_per_room = 1;
pub const max_crystal_hearts = max_rooms * max_crystal_hearts_per_room;
pub const max_golden_strawberries = 32;

pub const flags_per_word = 32;
pub const flag_word_count = (max_strawberries + flags_per_word - 1) / flags_per_word;
pub const cassette_flag_word_count = (max_cassettes + flags_per_word - 1) / flags_per_word;
pub const crystal_heart_flag_word_count = (max_crystal_hearts + flags_per_word - 1) / flags_per_word;
pub const golden_strawberry_flag_word_count = (max_golden_strawberries + flags_per_word - 1) / flags_per_word;

var strawberry_flags: [flag_word_count]u32 = [_]u32{0} ** flag_word_count;
var cassette_flags: [cassette_flag_word_count]u32 = [_]u32{0} ** cassette_flag_word_count;
var crystal_heart_flags: [crystal_heart_flag_word_count]u32 = [_]u32{0} ** crystal_heart_flag_word_count;
var golden_strawberry_flags: [golden_strawberry_flag_word_count]u32 = [_]u32{0} ** golden_strawberry_flag_word_count;
var run_start_strawberry_flags: [flag_word_count]u32 = [_]u32{0} ** flag_word_count;
var run_start_cassette_flags: [cassette_flag_word_count]u32 = [_]u32{0} ** cassette_flag_word_count;
var run_start_crystal_heart_flags: [crystal_heart_flag_word_count]u32 = [_]u32{0} ** crystal_heart_flag_word_count;
var run_start_golden_strawberry_flags: [golden_strawberry_flag_word_count]u32 = [_]u32{0} ** golden_strawberry_flag_word_count;
var strawberry_count: u16 = 0;
var strawberry_score: u32 = 0;
var strawberry_one_ups: u16 = 0;

pub fn strawberryId(room_index: usize, local_index: usize) ?u16 {
    const value = room_index * max_strawberries_per_room + local_index;
    if (value >= max_strawberries) return null;
    return @intCast(value);
}

pub fn cassetteId(room_index: usize, local_index: usize) ?u16 {
    const value = room_index * max_cassettes_per_room + local_index;
    if (value >= max_cassettes) return null;
    return @intCast(value);
}

pub fn crystalHeartId(room_index: usize) ?u16 {
    const value = room_index * max_crystal_hearts_per_room;
    if (value >= max_crystal_hearts) return null;
    return @intCast(value);
}

pub fn goldenStrawberryId(chapter: u8) ?u16 {
    if (chapter >= max_golden_strawberries) return null;
    return @intCast(chapter);
}

pub fn isStrawberryCollected(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (strawberry_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn isCassetteCollected(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (cassette_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn isCrystalHeartCollected(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (crystal_heart_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn isGoldenStrawberryCollected(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (golden_strawberry_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn wasStrawberryCollectedBeforeRun(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (run_start_strawberry_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn wasCassetteCollectedBeforeRun(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (run_start_cassette_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn wasCrystalHeartCollectedBeforeRun(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (run_start_crystal_heart_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn wasGoldenStrawberryCollectedBeforeRun(id: u16) bool {
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    return (run_start_golden_strawberry_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

pub fn beginChapterRun() void {
    run_start_strawberry_flags = strawberry_flags;
    run_start_cassette_flags = cassette_flags;
    run_start_crystal_heart_flags = crystal_heart_flags;
    run_start_golden_strawberry_flags = golden_strawberry_flags;
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

pub fn markCassetteCollected(id: u16) bool {
    if (isCassetteCollected(id)) return false;
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    cassette_flags[word_index] |= @as(u32, 1) << shift;
    return true;
}

pub fn markCrystalHeartCollected(id: u16) bool {
    if (isCrystalHeartCollected(id)) return false;
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    crystal_heart_flags[word_index] |= @as(u32, 1) << shift;
    return true;
}

pub fn markGoldenStrawberryCollected(id: u16) bool {
    if (isGoldenStrawberryCollected(id)) return false;
    const word_index: usize = @as(usize, id) / flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (flags_per_word - 1));
    golden_strawberry_flags[word_index] |= @as(u32, 1) << shift;
    return true;
}

pub fn collectedStrawberries() u16 {
    return strawberry_count;
}

pub fn collectedCassettes() u16 {
    return countCassetteFlags(&cassette_flags);
}

pub fn collectedCrystalHearts() u16 {
    return countCrystalHeartFlags(&crystal_heart_flags);
}

pub fn collectedGoldenStrawberries() u16 {
    return countGoldenStrawberryFlags(&golden_strawberry_flags);
}

pub fn countCassetteFlags(flags: *const [cassette_flag_word_count]u32) u16 {
    var count: u16 = 0;
    var word_index: usize = 0;
    while (word_index < cassette_flag_word_count) : (word_index += 1) {
        count += @intCast(@popCount(flags[word_index]));
    }
    return count;
}

pub fn countCrystalHeartFlags(flags: *const [crystal_heart_flag_word_count]u32) u16 {
    var count: u16 = 0;
    var word_index: usize = 0;
    while (word_index < crystal_heart_flag_word_count) : (word_index += 1) {
        count += @intCast(@popCount(flags[word_index]));
    }
    return count;
}

pub fn countGoldenStrawberryFlags(flags: *const [golden_strawberry_flag_word_count]u32) u16 {
    var count: u16 = 0;
    var word_index: usize = 0;
    while (word_index < golden_strawberry_flag_word_count) : (word_index += 1) {
        count += @intCast(@popCount(flags[word_index]));
    }
    return count;
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

pub fn copyCassetteFlags(out: *[cassette_flag_word_count]u32) void {
    out.* = cassette_flags;
}

pub fn copyCrystalHeartFlags(out: *[crystal_heart_flag_word_count]u32) void {
    out.* = crystal_heart_flags;
}

pub fn copyGoldenStrawberryFlags(out: *[golden_strawberry_flag_word_count]u32) void {
    out.* = golden_strawberry_flags;
}

pub fn restoreStrawberries(flags: *const [flag_word_count]u32, count: u16, score: u32, one_ups: u16) void {
    strawberry_flags = flags.*;
    run_start_strawberry_flags = flags.*;
    strawberry_count = count;
    strawberry_score = score;
    strawberry_one_ups = one_ups;
}

pub fn restoreCassettes(flags: *const [cassette_flag_word_count]u32) void {
    cassette_flags = flags.*;
    run_start_cassette_flags = flags.*;
}

pub fn restoreCrystalHearts(flags: *const [crystal_heart_flag_word_count]u32) void {
    crystal_heart_flags = flags.*;
    run_start_crystal_heart_flags = flags.*;
}

pub fn restoreGoldenStrawberries(flags: *const [golden_strawberry_flag_word_count]u32) void {
    golden_strawberry_flags = flags.*;
    run_start_golden_strawberry_flags = flags.*;
}

pub fn resetSession() void {
    strawberry_flags = [_]u32{0} ** flag_word_count;
    cassette_flags = [_]u32{0} ** cassette_flag_word_count;
    crystal_heart_flags = [_]u32{0} ** crystal_heart_flag_word_count;
    golden_strawberry_flags = [_]u32{0} ** golden_strawberry_flag_word_count;
    run_start_strawberry_flags = [_]u32{0} ** flag_word_count;
    run_start_cassette_flags = [_]u32{0} ** cassette_flag_word_count;
    run_start_crystal_heart_flags = [_]u32{0} ** crystal_heart_flag_word_count;
    run_start_golden_strawberry_flags = [_]u32{0} ** golden_strawberry_flag_word_count;
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
