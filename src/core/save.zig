const gba = @import("gba");

const collectibles = @import("collectibles.zig");
const level = @import("../generated_rooms.zig");
const room_data = @import("../world/room_data.zig");

const Spawn = room_data.Spawn;

const magic = [_]u8{ 'Z', 'E', 'L', 'E', 'S', 'A', 'V', '1' };
const version: u16 = 1;
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
const slot_player_name_offset: usize = slot_strawberry_flags_offset + collectibles.flag_word_count * 4;
pub const player_name_len: usize = 8;

const default_player_name = [_]u8{ 'M', 'A', 'D', 'E', 'L', 'I', 'N', 'E' };

const fnv_offset_basis: u32 = 2166136261;
const fnv_prime: u32 = 16777619;

const SaveSlot = struct {
    exists: bool = false,
    has_session: bool = false,
    current_chapter: u8 = 0,
    current_room_index: u16 = 0,
    respawn: Spawn = .{ .x = 0, .y = 0 },
    total_deaths: u32 = 0,
    playtime_frames: u32 = 0,
    unlocked_chapters: u32 = 1,
    completed_chapters: u32 = 0,
    strawberry_count: u16 = 0,
    strawberry_one_ups: u16 = 0,
    strawberry_score: u32 = 0,
    strawberry_flags: [collectibles.flag_word_count]u32 = [_]u32{0} ** collectibles.flag_word_count,
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
    strawberry_one_ups: u16,
    strawberry_score: u32,
    player_name: [player_name_len]u8,
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
    if (!persistence_enabled) return;
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
    if (!persistence_enabled) return;
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn noteDeath() void {
    if (!persistence_enabled) return;
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    if (slot.total_deaths != 0xffffffff) slot.total_deaths += 1;
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn tickPlaytime() void {
    if (!persistence_enabled) return;
    if (!initialized) return;
    var slot = activeSlotPtr();
    if (!slot.exists) return;
    if (slot.playtime_frames != 0xffffffff) slot.playtime_frames += 1;
}

pub fn finishChapter(chapter: u8) void {
    if (!persistence_enabled) return;
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
    if (!persistence_enabled) return;
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.exists = true;
    slot.unlocked_chapters |= chapterBit(chapter);
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn clearActiveSession() void {
    if (!persistence_enabled) return;
    ensureInitialized();
    var slot = activeSlotPtr();
    slot.has_session = false;
    snapshotCollectibles(slot);
    writeNextCopy();
}

pub fn selectSlot(slot_index: u8) void {
    if (!persistence_enabled) return;
    if (slot_index >= slot_count) return;
    ensureInitialized();
    active_slot = slot_index;
    restoreActiveSlotCollectibles();
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

pub fn setActivePlayerName(name: []const u8) void {
    setSlotPlayerName(active_slot, name);
}

pub fn setSlotPlayerName(slot_index: usize, name: []const u8) void {
    if (!persistence_enabled) return;
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
    if (room_index == level.start_room_index) return true;
    if (room_index >= level.room_ids.len) return false;

    const room_id = level.room_ids[room_index];
    if (bytesEqual(room_id, "city_1")) return true;
    if (bytesEqual(room_id, "city_6")) return true;
    if (bytesEqual(room_id, "city_9b")) return true;
    return false;
}

pub fn commitSerial() u32 {
    if (!persistence_enabled) return 0;
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
}

fn snapshotCollectibles(slot: *SaveSlot) void {
    collectibles.copyStrawberryFlags(&slot.strawberry_flags);
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
    slot.unlocked_chapters = readU32(base + slot_unlocked_offset);
    slot.completed_chapters = readU32(base + slot_completed_offset);
    slot.strawberry_count = readU16(base + slot_strawberry_count_offset);
    slot.strawberry_one_ups = readU16(base + slot_strawberry_oneups_offset);
    slot.strawberry_score = readU32(base + slot_strawberry_score_offset);

    var word_index: usize = 0;
    while (word_index < collectibles.flag_word_count) : (word_index += 1) {
        slot.strawberry_flags[word_index] = readU32(base + slot_strawberry_flags_offset + word_index * 4);
    }
    readPlayerName(base, &slot.player_name);
    return slot;
}

fn writeNextCopy() void {
    if (!persistence_enabled) return;
    generation +%= 1;
    commit_serial +%= 1;
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

    var name_index: usize = 0;
    while (name_index < player_name_len) : (name_index += 1) {
        writeByte(base + slot_player_name_offset + name_index, slot.player_name[name_index]);
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
