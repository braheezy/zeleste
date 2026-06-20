const gba = @import("gba");

const collectibles = @import("collectibles.zig");
const level = @import("../generated_rooms.zig");
const room_data = @import("../world/room_data.zig");

const Spawn = room_data.Spawn;

const magic = [_]u8{ 'Z', 'E', 'L', 'E', 'S', 'A', 'V', '1' };
const version: u16 = 2;
const copy_size: usize = 4096;
const copy_count: usize = 2;
pub const slot_count: usize = 3;
const slot_size: usize = 1024;
const header_size: usize = 32;

const version_offset: usize = 8;
const size_offset: usize = 10;
const generation_offset: usize = 12;
const checksum_offset: usize = 16;
const active_slot_offset: usize = 20;

const slot_exists_offset: usize = 0;
const slot_session_offset: usize = 1;
const slot_chapter_offset: usize = 2;
const slot_room_offset: usize = 4;
const slot_respawn_x_offset: usize = 6;
const slot_respawn_y_offset: usize = 8;
const slot_deaths_offset: usize = 12;
const slot_playtime_offset: usize = 16;
const slot_unlocked_offset: usize = 20;
const slot_completed_offset: usize = 24;
const slot_strawberry_count_offset: usize = 28;
const slot_strawberry_oneups_offset: usize = 30;
const slot_strawberry_score_offset: usize = 32;
const slot_strawberry_flags_offset: usize = 36;
const slot_cassette_flags_offset: usize = slot_strawberry_flags_offset + collectibles.flag_word_count * 4;
const slot_player_name_offset: usize = slot_cassette_flags_offset + collectibles.cassette_flag_word_count * 4;
const slot_chapter_playtime_offset: usize = slot_player_name_offset + player_name_len;
pub const player_name_len: usize = 8;
const max_timed_chapters: usize = 8;

const default_player_name = [_]u8{ 'M', 'A', 'D', 'E', 'L', 'I', 'N', 'E' };

const fnv_offset_basis: u32 = 2166136261;
const fnv_prime: u32 = 16777619;
const strawberry_record_bytes: usize = 8;
const cassette_record_bytes: usize = 8;
pub const max_chapter_area_count: usize = 3;

const SaveSlot = struct {
    exists: bool = false,
    has_session: bool = false,
    current_chapter: u8 = 0,
    current_room_index: u16 = 0,
    respawn: Spawn = .{ .x = 0, .y = 0 },
    total_deaths: u32 = 0,
    playtime_frames: u32 = 0,
    chapter_playtime_frames: [max_timed_chapters]u32 = [_]u32{0} ** max_timed_chapters,
    unlocked_chapters: u32 = 1,
    completed_chapters: u32 = 0,
    strawberry_count: u16 = 0,
    strawberry_one_ups: u16 = 0,
    strawberry_score: u32 = 0,
    strawberry_flags: [collectibles.flag_word_count]u32 = [_]u32{0} ** collectibles.flag_word_count,
    cassette_flags: [collectibles.cassette_flag_word_count]u32 = [_]u32{0} ** collectibles.cassette_flag_word_count,
    player_name: [player_name_len]u8 = default_player_name,
};

pub const SlotSummary = struct {
    exists: bool,
    has_session: bool,
    current_chapter: u8,
    current_room_index: u16,
    total_deaths: u32,
    playtime_frames: u32,
    unlocked_chapters: u32,
    completed_chapters: u32,
    strawberry_count: u16,
    cassette_count: u16,
    strawberry_one_ups: u16,
    strawberry_score: u32,
    player_name: [player_name_len]u8,
};

pub const CollectibleCount = struct {
    collected: u16 = 0,
    total: u16 = 0,
};

pub const ChapterStats = struct {
    strawberries: CollectibleCount = .{},
    cassettes: CollectibleCount = .{},
    future: CollectibleCount = .{},
    playtime_frames: u32 = 0,
};

pub const ChapterAreaSummary = struct {
    label: []const u8 = "",
    checkpoint_room_index: usize = 0,
    unlocked: bool = false,
    strawberries: CollectibleCount = .{},
};

const LoadedCopy = struct {
    index: usize,
    generation: u32,
};

var slots: [slot_count]SaveSlot = [_]SaveSlot{.{}} ** slot_count;
var active_slot: u8 = 0;
var generation: u32 = 0;
var loaded_copy_index: usize = 0;
var initialized: bool = false;
var commit_serial: u32 = 0;
var persistence_enabled: bool = true;

pub fn initForBoot(enable_persistence: bool) void {
    persistence_enabled = enable_persistence;
    if (!enable_persistence) {
        resetVolatileState();
        initialized = true;
        collectibles.resetSession();
        return;
    }
    init();
}

pub fn init() void {
    persistence_enabled = true;
    if (loadNewestValidCopy()) |loaded| {
        loaded_copy_index = loaded.index;
        generation = loaded.generation;
    } else {
        slots = [_]SaveSlot{.{}} ** slot_count;
        active_slot = 0;
        generation = 0;
        loaded_copy_index = 0;
    }
    initialized = true;
    restoreActiveSlotCollectibles();
}

pub fn hasActiveSession() bool {
    if (!persistence_enabled) return false;
    const slot = activeSlot();
    return slot.exists and slot.has_session and slot.current_room_index < level.rooms.len;
}

pub fn resumeRoomIndex() ?usize {
    if (!hasActiveSession()) return null;
    return activeSlot().current_room_index;
}

pub fn resumeSpawn(default_spawn: Spawn) Spawn {
    if (!hasActiveSession()) return default_spawn;
    return activeSlot().respawn;
}

pub fn commitSession(room_index: usize, respawn: Spawn) void {
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    slot.has_session = true;
    slot.current_room_index = @intCast(@min(room_index, 0xffff));
    slot.current_chapter = chapterForRoom(room_index);
    slot.respawn = respawn;
    slot.unlocked_chapters |= chapterBit(slot.current_chapter);
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn commitSessionCheckpoint(room_index: usize, respawn: Spawn) bool {
    if (!isSessionCheckpointRoom(room_index)) return false;
    commitSession(room_index, respawn);
    return true;
}

pub fn commitProgress() void {
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn beginChapterRunForRoom(room_index: usize) void {
    ensureInitialized();
    var slot = activeSlotPtr();
    const chapter = chapterForRoom(room_index);
    slot.exists = true;
    slot.current_chapter = chapter;
    slot.current_room_index = @intCast(@min(room_index, 0xffff));
    slot.unlocked_chapters |= chapterBit(chapter);
    collectibles.beginChapterRun();
}

pub fn noteDeathInRoom(_: usize) void {
    noteDeath();
}

pub fn noteDeath() void {
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    if (slot.total_deaths != 0xffffffff) slot.total_deaths += 1;
}

pub fn tickPlaytime(room_index: usize, paused: bool) void {
    if (paused) return;
    if (!initialized) return;
    var slot = activeSlotPtr();
    if (!slot.exists) return;
    const chapter = chapterForRoom(room_index);
    slot.current_chapter = chapter;
    if (slot.playtime_frames != 0xffffffff) slot.playtime_frames += 1;
    if (chapter < max_timed_chapters and slot.chapter_playtime_frames[chapter] != 0xffffffff) {
        slot.chapter_playtime_frames[chapter] += 1;
    }
}

pub fn finishChapter(chapter: u8) void {
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    slot.has_session = false;
    slot.unlocked_chapters |= chapterBit(chapter);
    slot.completed_chapters |= chapterBit(chapter);
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn unlockChapter(chapter: u8) void {
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    slot.unlocked_chapters |= chapterBit(chapter);
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn clearActiveSession() void {
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.has_session = false;
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn selectSlot(slot_index: u8) void {
    if (slot_index >= slot_count) return;
    ensureInitialized();
    active_slot = slot_index;
    restoreActiveSlotCollectibles();
    writeNextCopy();
}

pub fn deleteSlot(slot_index: usize) void {
    if (slot_index >= slot_count) return;
    ensureInitialized();
    slots[slot_index] = .{};
    if (slot_index == active_slot) {
        collectibles.resetSession();
    }
    writeNextCopy();
}

pub fn activeSlotIndex() u8 {
    return active_slot;
}

pub fn slotSummary(slot_index: usize) SlotSummary {
    ensureInitialized();
    if (slot_index >= slot_count) return emptySlotSummary();
    return summaryForSlot(slots[slot_index]);
}

pub fn slotExists(slot_index: usize) bool {
    ensureInitialized();
    if (slot_index >= slot_count) return false;
    return slots[slot_index].exists;
}

pub fn activeChapterStats(chapter: u8) ChapterStats {
    ensureInitialized();
    return chapterStatsForSlot(activeSlot(), chapter);
}

pub fn activeChapterAreaCount(chapter: u8) usize {
    return chapterAreaDefs(chapter).len;
}

pub fn activeChapterAreaSummary(chapter: u8, area_index: usize) ChapterAreaSummary {
    ensureInitialized();
    const defs = chapterAreaDefs(chapter);
    if (area_index >= defs.len) return .{};
    return chapterAreaSummaryForSlot(activeSlot(), chapter, area_index, defs[area_index]);
}

pub fn setActivePlayerName(name: []const u8) void {
    setSlotPlayerName(active_slot, name);
}

pub fn setSlotPlayerName(slot_index: usize, name: []const u8) void {
    ensureInitialized();
    if (slot_index >= slot_count) return;
    slots[slot_index].player_name = normalizedPlayerName(name);
    writeNextCopy();
}

pub fn totalDeaths() u32 {
    return activeSlot().total_deaths;
}

pub fn completedChapters() u32 {
    return activeSlot().completed_chapters;
}

pub fn isChapterCompleted(chapter: u8) bool {
    return (activeSlot().completed_chapters & chapterBit(chapter)) != 0;
}

pub fn isChapterUnlocked(chapter: u8) bool {
    return (activeSlot().unlocked_chapters & chapterBit(chapter)) != 0;
}

pub fn isSessionCheckpointRoom(room_index: usize) bool {
    if (room_index >= level.room_ids.len) return false;

    const room_id = level.room_ids[room_index];
    // Prologue saves when the chapter exits. City only updates the saved
    // respawn at explicit checkpoint screens.
    if (bytesEqual(room_id, "city_6")) return true;
    if (bytesEqual(room_id, "city_9b")) return true;
    return false;
}

pub fn commitSerial() u32 {
    return commit_serial;
}

fn ensureInitialized() void {
    if (!initialized) init();
}

fn activeSlot() *const SaveSlot {
    return &slots[@as(usize, active_slot)];
}

fn activeSlotPtr() *SaveSlot {
    return &slots[@as(usize, active_slot)];
}

fn summaryForSlot(slot: SaveSlot) SlotSummary {
    return .{
        .exists = slot.exists,
        .has_session = slot.has_session,
        .current_chapter = slot.current_chapter,
        .current_room_index = slot.current_room_index,
        .total_deaths = slot.total_deaths,
        .playtime_frames = slot.playtime_frames,
        .unlocked_chapters = slot.unlocked_chapters,
        .completed_chapters = slot.completed_chapters,
        .strawberry_count = slot.strawberry_count,
        .cassette_count = collectibles.countCassetteFlags(&slot.cassette_flags),
        .strawberry_one_ups = slot.strawberry_one_ups,
        .strawberry_score = slot.strawberry_score,
        .player_name = slot.player_name,
    };
}

fn emptySlotSummary() SlotSummary {
    return summaryForSlot(.{ .player_name = default_player_name });
}

fn normalizedPlayerName(name: []const u8) [player_name_len]u8 {
    var out = [_]u8{0} ** player_name_len;
    const limit = @min(name.len, player_name_len);
    var index: usize = 0;
    while (index < limit) : (index += 1) {
        const ch = name[index];
        out[index] = if (ch >= 'a' and ch <= 'z') ch - 32 else ch;
    }
    return out;
}

fn restoreActiveSlotCollectibles() void {
    const slot = activeSlot();
    if (!slot.exists) {
        collectibles.resetSession();
        return;
    }
    collectibles.restoreStrawberries(&slot.strawberry_flags, slot.strawberry_count, slot.strawberry_score, slot.strawberry_one_ups);
    collectibles.restoreCassettes(&slot.cassette_flags);
}

fn snapshotCollectibles(slot: *SaveSlot) void {
    collectibles.copyStrawberryFlags(&slot.strawberry_flags);
    collectibles.copyCassetteFlags(&slot.cassette_flags);
    slot.strawberry_count = collectibles.collectedStrawberries();
    slot.strawberry_score = collectibles.strawberryScore();
    slot.strawberry_one_ups = collectibles.strawberryOneUps();
}

fn resetVolatileState() void {
    slots = [_]SaveSlot{.{}} ** slot_count;
    active_slot = 0;
    generation = 0;
    loaded_copy_index = 0;
    commit_serial = 0;
}

fn chapterForRoom(room_index: usize) u8 {
    if (room_index < level.room_ids.len and startsWith(level.room_ids[room_index], "city_")) return 1;
    return 0;
}

fn chapterBit(chapter: u8) u32 {
    if (chapter >= 31) return 0;
    return @as(u32, 1) << @intCast(chapter);
}

const ChapterAreaDef = struct {
    label: []const u8,
    start_room_id: []const u8,
    end_room_id_exclusive: ?[]const u8 = null,
};

const prologue_area_defs = [_]ChapterAreaDef{
    .{ .label = "PROLOGUE", .start_room_id = "0" },
};

const city_area_defs = [_]ChapterAreaDef{
    .{ .label = "START", .start_room_id = "city_1", .end_room_id_exclusive = "city_6" },
    .{ .label = "CROSSING", .start_room_id = "city_6", .end_room_id_exclusive = "city_9b" },
    .{ .label = "CHASM", .start_room_id = "city_9b" },
};

fn chapterAreaDefs(chapter: u8) []const ChapterAreaDef {
    return switch (chapter) {
        0 => &prologue_area_defs,
        1 => &city_area_defs,
        else => &.{},
    };
}

fn chapterStatsForSlot(slot: *const SaveSlot, chapter: u8) ChapterStats {
    var stats: ChapterStats = .{
        .playtime_frames = chapterPlaytimeForSlot(slot, chapter),
    };
    var room_index: usize = 0;
    while (room_index < level.rooms.len) : (room_index += 1) {
        if (!roomBelongsToChapter(room_index, chapter)) continue;
        addCollectibleCount(&stats.strawberries, strawberryCountForRoom(slot, room_index));
        addCollectibleCount(&stats.cassettes, cassetteCountForRoom(slot, room_index));
    }
    return stats;
}

fn chapterPlaytimeForSlot(slot: *const SaveSlot, chapter: u8) u32 {
    if (chapter < max_timed_chapters) {
        const stored = slot.chapter_playtime_frames[chapter];
        if (stored != 0 or slot.playtime_frames == 0) return stored;
    }
    if (slot.current_chapter == chapter and slot.completed_chapters == 0) return slot.playtime_frames;
    return 0;
}

fn chapterAreaSummaryForSlot(slot: *const SaveSlot, chapter: u8, area_index: usize, def: ChapterAreaDef) ChapterAreaSummary {
    const start = roomIndexForId(def.start_room_id) orelse return .{ .label = def.label };
    const end = if (def.end_room_id_exclusive) |room_id| roomIndexForId(room_id) orelse level.rooms.len else level.rooms.len;
    const bounded_end = @min(@max(end, start), level.rooms.len);

    var strawberries: CollectibleCount = .{};
    var room_index = start;
    while (room_index < bounded_end) : (room_index += 1) {
        if (!roomBelongsToChapter(room_index, chapter)) continue;
        addCollectibleCount(&strawberries, strawberryCountForRoom(slot, room_index));
    }

    return .{
        .label = def.label,
        .checkpoint_room_index = start,
        .unlocked = areaUnlocked(slot, chapter, area_index, start),
        .strawberries = strawberries,
    };
}

fn addCollectibleCount(total: *CollectibleCount, value: CollectibleCount) void {
    total.collected += value.collected;
    total.total += value.total;
}

fn strawberryCountForRoom(slot: *const SaveSlot, room_index: usize) CollectibleCount {
    const data = level.rooms[room_index].strawberries;
    if (data.len < 2) return .{};
    const annotated_count = room_data.readU16Le(data, 0);
    var result: CollectibleCount = .{};
    var source_offset: usize = 2;
    var local_index: usize = 0;
    while (local_index < annotated_count and source_offset + strawberry_record_bytes <= data.len) : ({
        local_index += 1;
        source_offset += strawberry_record_bytes;
    }) {
        if (data[source_offset + 4] == 0 or data[source_offset + 5] == 0) continue;
        result.total += 1;
        const global_id = collectibles.strawberryId(room_index, local_index) orelse continue;
        if (slotStrawberryCollected(slot, global_id)) result.collected += 1;
    }
    return result;
}

fn cassetteCountForRoom(slot: *const SaveSlot, room_index: usize) CollectibleCount {
    const data = level.rooms[room_index].cassettes;
    if (data.len < 2) return .{};
    const annotated_count = room_data.readU16Le(data, 0);
    var result: CollectibleCount = .{};
    var source_offset: usize = 2;
    var local_index: usize = 0;
    while (local_index < annotated_count and source_offset + cassette_record_bytes <= data.len) : ({
        local_index += 1;
        source_offset += cassette_record_bytes;
    }) {
        if (data[source_offset + 4] == 0 or data[source_offset + 5] == 0) continue;
        result.total += 1;
        const global_id = collectibles.cassetteId(room_index, local_index) orelse continue;
        if (slotCassetteCollected(slot, global_id)) result.collected += 1;
    }
    return result;
}

fn slotStrawberryCollected(slot: *const SaveSlot, id: u16) bool {
    const word_index: usize = @as(usize, id) / collectibles.flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (collectibles.flags_per_word - 1));
    return word_index < slot.strawberry_flags.len and
        (slot.strawberry_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

fn slotCassetteCollected(slot: *const SaveSlot, id: u16) bool {
    const word_index: usize = @as(usize, id) / collectibles.flags_per_word;
    const shift: u5 = @intCast(@as(usize, id) & (collectibles.flags_per_word - 1));
    return word_index < slot.cassette_flags.len and
        (slot.cassette_flags[word_index] & (@as(u32, 1) << shift)) != 0;
}

fn areaUnlocked(slot: *const SaveSlot, chapter: u8, area_index: usize, start_room_index: usize) bool {
    if ((slot.unlocked_chapters & chapterBit(chapter)) == 0 and (slot.completed_chapters & chapterBit(chapter)) == 0) return false;
    if (area_index == 0) return true;
    if ((slot.completed_chapters & chapterBit(chapter)) != 0) return true;
    return slot.has_session and slot.current_chapter == chapter and slot.current_room_index >= start_room_index;
}

fn roomBelongsToChapter(room_index: usize, chapter: u8) bool {
    if (room_index >= level.room_ids.len) return false;
    const room_id = level.room_ids[room_index];
    return switch (chapter) {
        0 => !startsWith(room_id, "city_"),
        1 => startsWith(room_id, "city_"),
        else => false,
    };
}

fn roomIndexForId(room_id: []const u8) ?usize {
    return level.roomIndexFor(level.chapter_index, room_id);
}

fn bytesEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |value, index| {
        if (value != b[index]) return false;
    }
    return true;
}

fn loadNewestValidCopy() ?LoadedCopy {
    var best: ?LoadedCopy = null;
    var copy_index: usize = 0;
    while (copy_index < copy_count) : (copy_index += 1) {
        const base = copy_index * copy_size;
        if (!copyIsValid(base)) continue;
        const copy_generation = readU32(base + generation_offset);
        if (best == null or copy_generation >= best.?.generation) {
            best = .{ .index = copy_index, .generation = copy_generation };
        }
    }

    if (best) |loaded| {
        readRecord(loaded.index * copy_size);
        return loaded;
    }
    return null;
}

fn copyIsValid(base: usize) bool {
    var index: usize = 0;
    while (index < magic.len) : (index += 1) {
        if (readByte(base + index) != magic[index]) return false;
    }
    if (readU16(base + version_offset) != version) return false;
    if (readU16(base + size_offset) != copy_size) return false;
    return checksumRecord(base) == readU32(base + checksum_offset);
}

fn readRecord(base: usize) void {
    active_slot = readByte(base + active_slot_offset);
    if (active_slot >= slot_count) active_slot = 0;

    var slot_index: usize = 0;
    while (slot_index < slot_count) : (slot_index += 1) {
        slots[slot_index] = readSlot(base + header_size + slot_index * slot_size);
    }
}

fn readSlot(base: usize) SaveSlot {
    var slot: SaveSlot = .{};
    slot.exists = readByte(base + slot_exists_offset) != 0;
    slot.has_session = readByte(base + slot_session_offset) != 0;
    slot.current_chapter = readByte(base + slot_chapter_offset);
    slot.current_room_index = readU16(base + slot_room_offset);
    slot.respawn = .{
        .x = readI16(base + slot_respawn_x_offset),
        .y = readI16(base + slot_respawn_y_offset),
    };
    slot.total_deaths = readU32(base + slot_deaths_offset);
    slot.playtime_frames = readU32(base + slot_playtime_offset);
    var chapter_index: usize = 0;
    while (chapter_index < max_timed_chapters) : (chapter_index += 1) {
        slot.chapter_playtime_frames[chapter_index] = readU32(base + slot_chapter_playtime_offset + chapter_index * 4);
    }
    slot.unlocked_chapters = readU32(base + slot_unlocked_offset);
    slot.completed_chapters = readU32(base + slot_completed_offset);
    slot.strawberry_count = readU16(base + slot_strawberry_count_offset);
    slot.strawberry_one_ups = readU16(base + slot_strawberry_oneups_offset);
    slot.strawberry_score = readU32(base + slot_strawberry_score_offset);

    var word_index: usize = 0;
    while (word_index < collectibles.flag_word_count) : (word_index += 1) {
        slot.strawberry_flags[word_index] = readU32(base + slot_strawberry_flags_offset + word_index * 4);
    }

    word_index = 0;
    while (word_index < collectibles.cassette_flag_word_count) : (word_index += 1) {
        slot.cassette_flags[word_index] = readU32(base + slot_cassette_flags_offset + word_index * 4);
    }

    readPlayerName(base, &slot.player_name);
    return slot;
}

fn writeNextCopy() void {
    generation +%= 1;
    commit_serial +%= 1;
    if (!persistence_enabled) return;
    loaded_copy_index = (loaded_copy_index + 1) % copy_count;
    const base = loaded_copy_index * copy_size;

    var index: usize = 0;
    while (index < copy_size) : (index += 1) {
        writeByte(base + index, 0);
    }

    index = 0;
    while (index < magic.len) : (index += 1) {
        writeByte(base + index, magic[index]);
    }
    writeU16(base + version_offset, version);
    writeU16(base + size_offset, @intCast(copy_size));
    writeU32(base + generation_offset, generation);
    writeU32(base + checksum_offset, 0);
    writeByte(base + active_slot_offset, active_slot);

    var slot_index: usize = 0;
    while (slot_index < slot_count) : (slot_index += 1) {
        writeSlot(base + header_size + slot_index * slot_size, slots[slot_index]);
    }

    writeU32(base + checksum_offset, checksumRecord(base));
}

fn writeSlot(base: usize, slot: SaveSlot) void {
    writeByte(base + slot_exists_offset, if (slot.exists) 1 else 0);
    writeByte(base + slot_session_offset, if (slot.has_session) 1 else 0);
    writeByte(base + slot_chapter_offset, slot.current_chapter);
    writeU16(base + slot_room_offset, slot.current_room_index);
    writeI16(base + slot_respawn_x_offset, slot.respawn.x);
    writeI16(base + slot_respawn_y_offset, slot.respawn.y);
    writeU32(base + slot_deaths_offset, slot.total_deaths);
    writeU32(base + slot_playtime_offset, slot.playtime_frames);
    writeU32(base + slot_unlocked_offset, slot.unlocked_chapters);
    writeU32(base + slot_completed_offset, slot.completed_chapters);
    writeU16(base + slot_strawberry_count_offset, slot.strawberry_count);
    writeU16(base + slot_strawberry_oneups_offset, slot.strawberry_one_ups);
    writeU32(base + slot_strawberry_score_offset, slot.strawberry_score);

    var word_index: usize = 0;
    while (word_index < collectibles.flag_word_count) : (word_index += 1) {
        writeU32(base + slot_strawberry_flags_offset + word_index * 4, slot.strawberry_flags[word_index]);
    }

    word_index = 0;
    while (word_index < collectibles.cassette_flag_word_count) : (word_index += 1) {
        writeU32(base + slot_cassette_flags_offset + word_index * 4, slot.cassette_flags[word_index]);
    }

    var name_index: usize = 0;
    while (name_index < player_name_len) : (name_index += 1) {
        writeByte(base + slot_player_name_offset + name_index, slot.player_name[name_index]);
    }

    var chapter_index: usize = 0;
    while (chapter_index < max_timed_chapters) : (chapter_index += 1) {
        writeU32(base + slot_chapter_playtime_offset + chapter_index * 4, slot.chapter_playtime_frames[chapter_index]);
    }
}

fn readPlayerName(base: usize, out: *[player_name_len]u8) void {
    var stored_name = [_]u8{0} ** player_name_len;
    var has_non_zero = false;
    var index: usize = 0;
    while (index < player_name_len) : (index += 1) {
        const value = readByte(base + slot_player_name_offset + index);
        stored_name[index] = value;
        if (value != 0) has_non_zero = true;
    }
    if (!has_non_zero) return;
    out.* = stored_name;
}

fn checksumRecord(base: usize) u32 {
    var hash: u32 = fnv_offset_basis;
    var index: usize = 0;
    while (index < copy_size) : (index += 1) {
        const byte = if (index >= checksum_offset and index < checksum_offset + 4)
            0
        else
            readByte(base + index);
        hash = (hash ^ byte) *% fnv_prime;
    }
    return hash;
}

fn readByte(offset: usize) u8 {
    return gba.mem.sram.*[offset];
}

fn writeByte(offset: usize, value: u8) void {
    gba.mem.sram.*[offset] = value;
}

fn readU16(offset: usize) u16 {
    return @as(u16, readByte(offset)) | (@as(u16, readByte(offset + 1)) << 8);
}

fn readI16(offset: usize) i16 {
    return @bitCast(readU16(offset));
}

fn readU32(offset: usize) u32 {
    return @as(u32, readByte(offset)) |
        (@as(u32, readByte(offset + 1)) << 8) |
        (@as(u32, readByte(offset + 2)) << 16) |
        (@as(u32, readByte(offset + 3)) << 24);
}

fn writeU16(offset: usize, value: u16) void {
    writeByte(offset, @truncate(value));
    writeByte(offset + 1, @truncate(value >> 8));
}

fn writeI16(offset: usize, value: i16) void {
    writeU16(offset, @bitCast(value));
}

fn writeU32(offset: usize, value: u32) void {
    writeByte(offset, @truncate(value));
    writeByte(offset + 1, @truncate(value >> 8));
    writeByte(offset + 2, @truncate(value >> 16));
    writeByte(offset + 3, @truncate(value >> 24));
}

fn startsWith(value: []const u8, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;
    var index: usize = 0;
    while (index < prefix.len) : (index += 1) {
        if (value[index] != prefix[index]) return false;
    }
    return true;
}
