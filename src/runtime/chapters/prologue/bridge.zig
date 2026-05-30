const gba = @import("gba");
const assets = @import("../../assets.zig");
const camera_mod = @import("../../camera.zig");
const collision = @import("../../collision.zig");
const dust = @import("../../dust.zig");
const falling_blocks = @import("../../falling_blocks.zig");
const foreground_stamps = @import("../../foreground_stamps.zig");
const level = @import("../../../generated_rooms.zig");
const math = @import("../../math.zig");
const oam = @import("../../oam.zig");
const player_mod = @import("../../player.zig");
const room_data = @import("../../room_data.zig");
const video = @import("../../video.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const SceneRect = room_data.SceneRect;
const Spawn = room_data.Spawn;
const approach = math.approach;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const rectsOverlap = collision.rectsOverlap;

const tiles_data align(4) = assets.bridge_tiles_data;
const palette_data align(4) = assets.bridge_palette_data;
const layout_data align(4) = assets.bridge_layout_data;
const groups_data align(4) = assets.bridge_groups_data;

const base_tile: u10 = 128;
const palette_bank: u4 = 5;
const falling_palette_bank: u4 = 11;
const chunk_width = 8;
const chunk_height = 32;
const visual_height = 25;
const tiles_per_chunk = 4;
const empty_chunk = 255;
const no_group = 255;
const world_x: i16 = 64;
const world_y: i16 = 126;
const ending_early_shake_frames: u8 = 12;
const ending_gap_chunks = 3;
const max_chunks = 128;
const max_objects = 30;
const first_object = foreground_stamps.behind_first_object;
const shake_frames: u8 = 34;
const fall_gravity: i32 = 0x48;
const fall_max_speed: i32 = 0x4C0;
const rooms = level.rooms;

const ChunkState = enum(u8) {
    inactive,
    solid,
    shaking,
    falling,
    gone,
};

const Chunk = struct {
    state: ChunkState = .inactive,
    variant: u8 = empty_chunk,
    group: u8 = no_group,
    x: i16 = 0,
    y: i32 = 0,
    timer: u8 = 0,
    vy: i32 = 0,
};

const Ending = struct {
    active: bool = false,
    final_triggered: bool = false,
    platform: SceneRect = .{},
    trigger: SceneRect = .{},
    hint: SceneRect = .{},
    start_index: usize = max_chunks,
    end_index: usize = max_chunks,
};

var chunks: [max_chunks]Chunk = [_]Chunk{.{}} ** max_chunks;
var chunk_count: usize = 0;
var drawn_object_count: usize = 0;
var bridge_active: bool = false;
var sequence_started: bool = false;
var ending_hold: bool = false;
var ending_dash_started: bool = false;
var collapse_shake_tick: u8 = 0;
var ending_start_index: usize = max_chunks;
var ending: Ending = .{};

pub fn load(room_index: usize, active_room: bool) void {
    chunks = [_]Chunk{.{}} ** max_chunks;
    chunk_count = 0;
    drawn_object_count = 0;
    bridge_active = active_room;
    sequence_started = false;
    ending_hold = false;
    ending_dash_started = false;
    collapse_shake_tick = 0;
    ending_start_index = max_chunks;
    ending = .{};
    hideObjects();
    if (!bridge_active) return;

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    loadDarkPalette();
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));

    if (layout_data.len < 2) return;
    const count = @min(readU16Le(&layout_data, 0), max_chunks);
    var index: usize = 0;
    while (index < count and 2 + index < layout_data.len) : (index += 1) {
        const variant = layout_data[2 + index];
        if (variant != empty_chunk) {
            const group = if (groups_data.len >= 2 + count and 2 + index < groups_data.len)
                groups_data[2 + index]
            else
                no_group;
            chunks[index] = .{
                .state = .solid,
                .variant = variant,
                .group = group,
                .x = world_x + @as(i16, @intCast(index * chunk_width)),
                .y = pixelToFixed(world_y),
            };
        }
    }
    chunk_count = count;
    ending_start_index = finalPlatformStart();
    loadEnding(room_index);
}

pub fn update(player: *Player, active_room: bool) void {
    if (!bridge_active or !active_room) return;

    var live_chunks: usize = 0;
    const player_center_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    if (endingTriggerActive(player.*)) {
        triggerEndingPlatformEarly();
    }
    const trigger_y_min = world_y - 4;
    const trigger_y_max = world_y + 12;
    if (player_bottom >= trigger_y_min and player_bottom <= trigger_y_max) {
        if (chunkIndexAtX(player_center_x)) |chunk_index| {
            const chunk = &chunks[chunk_index];
            if (chunk.state == .solid and player_center_x >= chunk.x - 4 and player_center_x < chunk.x + chunk_width + 2) {
                triggerChunkRun(chunk_index);
            }
        }
    }

    var index: usize = 0;
    while (index < chunk_count) : (index += 1) {
        const chunk = &chunks[index];
        switch (chunk.state) {
            .inactive, .gone => {},
            .solid => {
                if (sequence_started and chunk.x + chunk_width < player_center_x - 56) {
                    chunk.state = .gone;
                } else {
                    live_chunks += 1;
                }
            },
            .shaking => {
                live_chunks += 1;
                if (chunk.timer > 0) {
                    chunk.timer -= 1;
                } else {
                    spawnSnow(chunk.*);
                    chunk.state = .falling;
                    chunk.vy = 0;
                }
            },
            .falling => {
                live_chunks += 1;
                chunk.vy = approach(chunk.vy, fall_max_speed, fall_gravity);
                chunk.y += chunk.vy;
                if (fixedToPixel(chunk.y) > world_y + video.screen_height + chunk_height) {
                    chunk.state = .gone;
                }
            },
        }
    }

    if (sequence_started and live_chunks == 0) {
        bridge_active = false;
        hideObjects();
    }
}

pub fn draw(camera: Camera) void {
    if (!bridge_active) {
        if (drawn_object_count != 0) hideObjects();
        return;
    }

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < chunk_count and object_offset < max_objects) : (index += 1) {
        const chunk = chunks[index];
        if (chunk.state == .inactive or chunk.state == .gone or chunk.variant == empty_chunk) continue;

        const screen_x = chunk.x - camera.x;
        if (screen_x < -chunk_width or screen_x >= video.screen_width) continue;

        const shake_x: i16 = if (chunk.state == .shaking and (chunk.timer & 3) == 0) -1 else 0;
        const shake_y: i16 = if (chunk.state == .shaking and (chunk.timer & 7) == 0) 1 else 0;
        const screen_y = fixedToPixel(chunk.y) - camera.y;
        if (screen_y < -chunk_height or screen_y >= video.screen_height) continue;

        const tile = base_tile + @as(u10, @intCast(@as(u16, chunk.variant) * tiles_per_chunk));
        const palette = if (chunk.state == .falling) falling_palette_bank else palette_bank;
        gba.display.objects[first_object + object_offset] = gba.display.Object.init(.{
            .size = .size_8x32,
            .x = objX(screen_x + shake_x),
            .y = objY(screen_y + shake_y),
            .base_tile = tile,
            .priority = 1,
            .palette = palette,
        });
        object_offset += 1;
    }

    var hide_offset = object_offset;
    while (hide_offset < drawn_object_count) : (hide_offset += 1) {
        hideObject(first_object + hide_offset);
    }
    drawn_object_count = object_offset;
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < max_objects) : (index += 1) {
        hideObject(first_object + index);
    }
    drawn_object_count = 0;
}

pub fn active() bool {
    return bridge_active;
}

pub fn sequenceStarted() bool {
    return sequence_started;
}

pub fn endingHoldActive() bool {
    return ending_hold;
}

pub fn shouldStartEndingHold(player: Player, active_room: bool) bool {
    if (!bridge_active or !active_room or !ending.active or !ending.final_triggered) return false;
    const player_center_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    return player_center_x >= ending.platform.x - 16 and
        player_center_x <= ending.platform.right() + 56 and
        player_bottom > ending.platform.y + 10 and
        player.vy > 0;
}

pub fn startEndingHold() void {
    ending_hold = true;
}

pub fn markEndingDashStarted() void {
    ending_hold = false;
    ending_dash_started = true;
}

pub fn shouldStartEndLevelTransition(player: Player, active_room: bool, transition_active: bool) bool {
    if (transition_active) return false;
    if (!active_room or !ending.active or !ending.final_triggered) return false;
    if (!ending_dash_started) return false;
    return playerReachedEndingExitZone(player);
}

pub fn endingHintOrDefault(player_x: i16, player_y: i16) Spawn {
    return .{
        .x = if (ending.hint.w > 0) ending.hint.x else player_x - 32,
        .y = if (ending.hint.h > 0) ending.hint.y else player_y - 72,
    };
}

pub fn deactivateForOverworld() void {
    bridge_active = false;
    ending_hold = false;
    ending_dash_started = false;
    ending = .{};
    collapse_shake_tick = 0;
    hideObjects();
}

pub fn clearCollapseShake() void {
    collapse_shake_tick = 0;
}

pub fn updateCollapseShake(active_room: bool, player_grounded: bool) void {
    if (player_grounded and collapseShakeActive(active_room)) {
        collapse_shake_tick +%= 1;
    } else {
        collapse_shake_tick = 0;
    }
}

pub fn collapseShakeOffset() ?Spawn {
    if (collapse_shake_tick == 0) return null;
    return switch (collapse_shake_tick & 7) {
        0 => .{ .x = 1, .y = 0 },
        1 => .{ .x = -1, .y = 0 },
        2 => .{ .x = 0, .y = -1 },
        3 => .{ .x = -1, .y = 1 },
        4 => .{ .x = 1, .y = 0 },
        5 => .{ .x = 0, .y = -1 },
        6 => .{ .x = 1, .y = 1 },
        else => .{ .x = 0, .y = 0 },
    };
}

pub fn floorAtPlayer(player: Player) bool {
    if (!bridge_active) return false;
    const player_x = fixedToPixel(player.x);
    const bottom = fixedToPixel(player.y) + player_mod.body_height;
    return floorAt(player_x + 1, bottom) or
        floorAt(player_x + player_mod.body_width / 2, bottom) or
        floorAt(player_x + player_mod.body_width - 2, bottom);
}

pub fn solidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    if (!bridge_active) return false;

    const right = x + width;
    const bottom = y + height;
    if (endingSolidRectAt(x, y, right, bottom)) return true;

    const start = chunkIndexAtX(x) orelse 0;
    const end = chunkIndexAtX(right - 1) orelse if (right <= world_x) 0 else chunk_count - 1;
    var index = start;
    while (index <= end and index < chunk_count) : (index += 1) {
        const chunk = chunks[index];
        if (chunk.state != .solid and chunk.state != .shaking) continue;
        const chunk_y = fixedToPixel(chunk.y);
        if (right > chunk.x and x < chunk.x + chunk_width and bottom > chunk_y and y < chunk_y + visual_height) {
            return true;
        }
    }
    return false;
}

fn loadEnding(room_index: usize) void {
    const data = rooms[room_index].bridge_ending;
    if (data.len < 26 or readU16Le(data, 0) == 0) return;

    const platform = readSceneRect(data, 2);
    const trigger = readSceneRect(data, 10);
    const hint = readSceneRect(data, 18);
    if (platform.w <= 0 or platform.h <= 0 or trigger.w <= 0 or trigger.h <= 0) return;

    const start = ending_start_index;
    if (start >= chunk_count) return;
    const platform_chunks: usize = @intCast(@max(1, @divTrunc(platform.w + chunk_width - 1, chunk_width)));
    const end = @min(chunk_count - 1, start + platform_chunks - 1);
    const actual_chunks = end - start + 1;
    const platform_width: i16 = @intCast(actual_chunks * chunk_width);
    const platform_x = platform.right() - platform_width;
    const gap_left = platform_x - ending_gap_chunks * chunk_width;
    const platform_right = platform_x + platform_width;

    var index = start;
    while (index <= end) : (index += 1) {
        chunks[index].x = platform_x + @as(i16, @intCast((index - start) * chunk_width));
        chunks[index].y = pixelToFixed(platform.y);
    }

    index = 0;
    while (index < chunk_count) : (index += 1) {
        if (index >= start and index <= end) continue;
        const chunk_right = chunks[index].x + chunk_width;
        if (chunk_right > gap_left and chunks[index].x < platform_right) {
            chunks[index].state = .inactive;
            chunks[index].variant = empty_chunk;
            chunks[index].group = no_group;
        }
    }

    ending = .{
        .active = true,
        .platform = .{ .x = platform_x, .y = platform.y, .w = platform_width, .h = platform.h },
        .trigger = trigger,
        .hint = hint,
        .start_index = start,
        .end_index = end,
    };
}

fn readSceneRect(data: []align(4) const u8, offset: usize) SceneRect {
    return .{
        .x = readI16Le(data, offset),
        .y = readI16Le(data, offset + 2),
        .w = readI16Le(data, offset + 4),
        .h = readI16Le(data, offset + 6),
    };
}

fn finalPlatformStart() usize {
    var index = chunk_count;
    while (index > 0) {
        index -= 1;
        const chunk = chunks[index];
        if (chunk.state == .inactive or chunk.variant == empty_chunk) continue;
        break;
    }
    while (index > 0) {
        index -= 1;
        const chunk = chunks[index];
        if (chunk.state == .inactive or chunk.variant == empty_chunk) return index + 1;
    }
    return 0;
}

fn loadDarkPalette() void {
    const source: [*]align(2) const gba.ColorRgb555 = @ptrCast(&palette_data);
    var index: usize = 0;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[@as(usize, falling_palette_bank) * 16 + index] = darkenColor(source[index]);
    }
}

fn darkenColor(color: gba.ColorRgb555) gba.ColorRgb555 {
    return gba.ColorRgb555.rgb(
        @intCast(@as(u8, color.r) / 2),
        @intCast(@as(u8, color.g) / 2),
        @intCast(@as(u8, color.b) / 2),
    );
}

fn triggerChunkRun(start_index: usize) void {
    const group = chunks[start_index].group;
    if (group == no_group) {
        triggerChunk(start_index, 0);
        return;
    }

    var index: usize = 0;
    while (index < chunk_count) : (index += 1) {
        if (chunks[index].group != group) continue;
        triggerChunk(index, 0);
    }
}

fn triggerChunk(index: usize, delay: u8) void {
    const chunk = &chunks[index];
    if (chunk.state != .solid) return;
    beginSequence();
    chunk.state = .shaking;
    chunk.timer = shake_frames + delay;
}

fn beginSequence() void {
    if (sequence_started) return;
    sequence_started = true;
}

fn collapseShakeActive(active_room: bool) bool {
    if (!bridge_active or !active_room or !sequence_started) return false;
    if (ending.final_triggered or ending_hold or ending_dash_started) return false;

    var index: usize = 0;
    while (index < chunk_count) : (index += 1) {
        const state = chunks[index].state;
        if (state == .shaking or state == .falling) return true;
    }
    return false;
}

fn triggerEndingPlatformEarly() void {
    if (!ending.active or ending.final_triggered) return;
    if (ending.start_index >= chunk_count or ending.end_index >= chunk_count) return;
    ending.final_triggered = true;
    var index: usize = ending.start_index;
    while (index <= ending.end_index) : (index += 1) {
        const chunk = &chunks[index];
        if (chunk.state != .solid) continue;
        chunk.state = .shaking;
        chunk.timer = ending_early_shake_frames;
    }
}

fn endingTriggerActive(player: Player) bool {
    if (!ending.active or ending.final_triggered) return false;
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;
    const trigger = ending.trigger;
    return rectsOverlap(player_left, player_top, player_right, player_bottom, trigger.x, trigger.y, trigger.right(), trigger.bottom());
}

fn chunkIndexAtX(x: i16) ?usize {
    if (!bridge_active or x < world_x) return null;
    const relative = x - world_x;
    const index: usize = @intCast(@divTrunc(relative, chunk_width));
    if (index >= chunk_count) return null;
    return index;
}

fn spawnSnow(chunk: Chunk) void {
    const block = falling_blocks.Block{
        .active = true,
        .x = chunk.x,
        .y = chunk.y,
        .w = chunk_width,
        .h = visual_height,
        .max_y = fixedToPixel(chunk.y) + visual_height,
    };
    dust.spawnSnowFromBlock(block);
}

fn floorAt(x: i16, bottom_y: i16) bool {
    if (!bridge_active) return false;
    if (ending.active and bottom_y >= ending.platform.y and bottom_y < ending.platform.y + 4 and x >= ending.platform.x and x < ending.platform.right()) {
        return true;
    }

    const chunk_index = chunkIndexAtX(x) orelse return false;
    if (chunk_index >= chunk_count) return false;
    const chunk = chunks[chunk_index];
    if (chunk.state != .solid and chunk.state != .shaking) return false;
    const chunk_y = fixedToPixel(chunk.y);
    return bottom_y >= chunk_y and bottom_y < chunk_y + 4;
}

fn playerReachedEndingExitZone(player: Player) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_bottom = player_top + player_mod.body_height;
    const player_center_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const platform = ending.platform;
    const platform_bottom = platform.y + visual_height;
    const dash_finished = player.dash_timer == 0;
    const crosses_end_zone = player_center_x >= platform.x - 8 and
        player_left <= platform.right() + 24;
    const near_end_height = player_bottom >= platform.y - 64 and
        player_top <= platform_bottom + 56;
    return dash_finished and player.grounded and crosses_end_zone and near_end_height;
}

fn endingSolidRectAt(x: i16, y: i16, right: i16, bottom: i16) bool {
    if (!ending.active) return false;
    if (!rectsOverlap(x, y, right, bottom, ending.platform.x, ending.platform.y, ending.platform.right(), ending.platform.y + visual_height)) {
        return false;
    }

    var index = ending.start_index;
    while (index <= ending.end_index and index < chunk_count) : (index += 1) {
        const chunk = chunks[index];
        if (chunk.state != .solid and chunk.state != .shaking) continue;
        const chunk_y = fixedToPixel(chunk.y);
        if (right > chunk.x and x < chunk.x + chunk_width and bottom > chunk_y and y < chunk_y + visual_height) {
            return true;
        }
    }
    return false;
}
