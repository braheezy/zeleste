const gba = @import("gba");
const background = @import("../../world/background.zig");
const camera_mod = @import("../../world/camera.zig");
const collision = @import("../../world/collision.zig");
const cutscene_dialogue = @import("../../cutscene/dialogue.zig");
const laugh_text = @import("laugh_text.zig");
const dash_effects = @import("../../player/dash_effects.zig");
const dust = @import("../../effects/dust.zig");
const falling_blocks = @import("falling_blocks.zig");
const granny_npc = @import("granny_npc.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const text_mod = @import("../../core/text.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const GrannyCutscene = room_data.GrannyCutscene;
const SceneRect = room_data.SceneRect;
const Spawn = room_data.Spawn;

const pixelToFixed = math.pixelToFixed;
const fixedToPixel = math.fixedToPixel;
const absI16 = math.absI16;
const signI16 = math.signI16;
const rectsOverlap = collision.rectsOverlap;
const readU16Le = room_data.readU16Le;

const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const dialogue_first_object = falling_blocks.first_object;
const granny_scene_room_index = level.roomIndexFor(level.chapter_index, "2") orelse rooms.len;
const granny_laugh_carry_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;
const ominous_reveal_interval_frames: u8 = 12;
const ominous_words_per_tick: u8 = 2;
const ominous_shake_frames: u8 = 14;

const Phase = enum(u8) {
    inactive,
    dialogue,
    walk_talk,
    walk_edge,
    laugh_pause,
};

const State = struct {
    active: bool = false,
    room_index: usize = 0,
    phase: Phase = .inactive,
    dialogue_index: u8 = 0,
    dialogue_offset: usize = 0,
    dialogue_next_offset: usize = 0,
    dialogue_reveal_offset: usize = 0,
    dialogue_reveal_timer: u8 = 0,
    dialogue_cache: cutscene_dialogue.Cache = .{},
    see_shake_started: bool = false,
    shake_timer: u8 = 0,
    laugh_pause_timer: u8 = 0,
    madeline_speaker_x: i16 = 0,
    madeline_speaker_y: i16 = 0,
};

var intro_done: bool = false;
var state: State = .{};
var bg_darkened: bool = false;

pub fn resetPaletteState() void {
    bg_darkened = false;
}

pub fn resetOnRoomLoad(room_index: usize) void {
    if (!laughTextAllowedInRoom(room_index)) {
        laugh_text.stop();
    }
    if (!state.active) return;
    state = .{};
    bg_darkened = false;
    cutscene_dialogue.hideObjects(dialogue_first_object);
}

pub fn update(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    const maybe_cutscene = rooms[room_index].granny_cutscene;
    if (!state.active) {
        if (maybe_cutscene) |cutscene| {
            if (!intro_done and playerOverlapsSceneRect(player.*, cutscene.trigger)) {
                start(player, room_index);
            }
        }
    }

    if (!state.active) return false;
    const cutscene = rooms[state.room_index].granny_cutscene orelse return false;
    lockPlayer(player);
    state.madeline_speaker_x = fixedToPixel(player.x) + player_body_width / 2;
    state.madeline_speaker_y = fixedToPixel(player.y) + player_body_height / 2;

    switch (state.phase) {
        .inactive => {},
        .dialogue => {
            updateDialogueReveal(cutscene);
            updateDialogue(input, cutscene);
        },
        .walk_talk => {
            player.facing_left = false;
            if (movePlayerTowardPoint(player, cutscene.madeline_talk, 1)) {
                startDialogue(1);
            }
        },
        .walk_edge => {
            player.facing_left = false;
            if (movePlayerTowardPoint(player, cutscene.madeline_edge, 1)) {
                player.facing_left = true;
                startDialogue(3);
            }
        },
        .laugh_pause => {
            player.facing_left = true;
            if (state.laugh_pause_timer > 0) {
                state.laugh_pause_timer -= 1;
            } else {
                startDialogue(4);
            }
        },
    }

    if (state.active) {
        setDarkened(state.room_index, ominousPage(cutscene));
        if (state.shake_timer > 0) {
            state.shake_timer -= 1;
        }
    }
    return state.active;
}

pub fn updateEffects(room_index: usize, camera: Camera) void {
    if (!laughTextAllowedInRoom(room_index)) {
        laugh_text.stop();
        return;
    }
    laugh_text.update(room_index, camera);
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    _ = from_room;
    if (!intro_done or !laugh_text.active()) return;
    if (!laughTextAllowedInRoom(to_room)) {
        laugh_text.stop();
    }
}

pub fn handlePlayerDeathStart() void {
    if (intro_done and laugh_text.active()) {
        laugh_text.stop();
    }
}

pub fn drawNpc(camera: Camera, room_index: usize, object: usize, anim_counter: u16) void {
    const cutscene = rooms[room_index].granny_cutscene orelse {
        granny_npc.hide(object);
        return;
    };

    const animation = npcAnimationForRoom(room_index);
    granny_npc.draw(camera, object, cutscene.granny, animation, anim_counter, npcFacingLeftForRoom(cutscene, room_index));
}

pub fn drawOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
    if (state.active and state.room_index == room_index and state.phase == .dialogue) {
        if (rooms[room_index].granny_cutscene) |cutscene| {
            renderDialogueTiles(cutscene);
            if (state.dialogue_index < cutscene.dialogue.len) {
                cutscene_dialogue.drawObjects(camera, dialogue_first_object, cutscene.dialogue_box, cutscene.dialogue[state.dialogue_index], anim_counter);
            }
        }
    } else {
        cutscene_dialogue.hideObjects(dialogue_first_object);
    }

    if (laughTextAllowedInRoom(room_index)) {
        laugh_text.draw(camera, room_index);
    } else if (laugh_text.active()) {
        laugh_text.stop();
    }
}

pub fn shakeOffset() ?Spawn {
    if (!state.active or state.shake_timer == 0) return null;
    return switch (state.shake_timer & 7) {
        0 => .{ .x = 2, .y = 0 },
        1 => .{ .x = -2, .y = 1 },
        2 => .{ .x = 1, .y = -1 },
        3 => .{ .x = -1, .y = 0 },
        4 => .{ .x = 2, .y = 1 },
        5 => .{ .x = -1, .y = -1 },
        6 => .{ .x = 1, .y = 0 },
        else => .{ .x = 0, .y = 0 },
    };
}

fn start(player: *Player, room_index: usize) void {
    _ = player;
    state = .{
        .active = true,
        .room_index = room_index,
    };
    startDialogue(0);
    dust.clear();
    dash_effects.clear();
    cutscene_dialogue.hideObjects(dialogue_first_object);
}

fn lockPlayer(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    player.moving = false;
    player.grounded = true;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.dash_timer = 0;
    player.dash_cooldown_timer = 0;
}

fn updateDialogue(input: gba.input.BufferedKeysState, cutscene: *const GrannyCutscene) void {
    if (state.dialogue_index >= cutscene.dialogue.len) {
        finish(cutscene);
        return;
    }
    if (!(input.isJustPressed(.A) or input.isJustPressed(.B))) return;

    const page = cutscene.dialogue[state.dialogue_index];
    const page_end = cutscene_dialogue.wrappedNextOffset(page, state.dialogue_offset);
    if (dialogueUsesTypewriter(page.text) and state.dialogue_reveal_offset < page_end) {
        revealDialogueTo(page.text, page_end);
        return;
    }

    if (page_end < page.text.len) {
        state.dialogue_offset = page_end;
        state.dialogue_cache.invalidate();
        resetDialogueReveal(cutscene);
        return;
    }

    const completed_page = state.dialogue_index;
    if (completed_page == 0) {
        state.phase = .walk_talk;
        cutscene_dialogue.hideObjects(dialogue_first_object);
        return;
    }
    if (completed_page == 2) {
        state.phase = .walk_edge;
        cutscene_dialogue.hideObjects(dialogue_first_object);
        return;
    }
    if (completed_page == 3) {
        state.phase = .laugh_pause;
        state.laugh_pause_timer = laugh_text.pause_frames;
        cutscene_dialogue.hideObjects(dialogue_first_object);
        laugh_text.startFromCutscene(cutscene, state.room_index, 3, false, false);
        return;
    }
    const next_page = completed_page + 1;
    if (next_page >= cutscene.dialogue.len) {
        finish(cutscene);
    } else {
        startDialogue(next_page);
    }
}

fn startDialogue(index: u8) void {
    state.phase = .dialogue;
    state.dialogue_index = index;
    state.dialogue_offset = 0;
    state.dialogue_next_offset = 0;
    state.dialogue_cache.invalidate();
    if (rooms[state.room_index].granny_cutscene) |cutscene| {
        resetDialogueReveal(cutscene);
    }
}

fn finish(cutscene: *const GrannyCutscene) void {
    const room_index = state.room_index;
    intro_done = true;
    setDarkened(room_index, false);
    state = .{};
    cutscene_dialogue.hideObjects(dialogue_first_object);
    laugh_text.startFromCutscene(cutscene, room_index, 0, true, true);
}

fn resetDialogueReveal(cutscene: *const GrannyCutscene) void {
    if (state.dialogue_index >= cutscene.dialogue.len) return;
    const page = cutscene.dialogue[state.dialogue_index];
    const start_offset = text_mod.skipSpaces(page.text, state.dialogue_offset);
    state.dialogue_reveal_offset = if (dialogueUsesTypewriter(page.text)) start_offset else page.text.len;
    state.dialogue_reveal_timer = 0;
    state.dialogue_cache.invalidate();
    state.see_shake_started = false;
}

fn updateDialogueReveal(cutscene: *const GrannyCutscene) void {
    if (state.dialogue_index >= cutscene.dialogue.len) return;
    const page = cutscene.dialogue[state.dialogue_index];
    if (!dialogueUsesTypewriter(page.text)) {
        state.dialogue_reveal_offset = page.text.len;
        return;
    }

    const target = cutscene_dialogue.wrappedNextOffset(page, state.dialogue_offset);
    if (state.dialogue_reveal_offset < state.dialogue_offset) {
        state.dialogue_reveal_offset = text_mod.skipSpaces(page.text, state.dialogue_offset);
    }
    if (state.dialogue_reveal_offset >= target) return;

    state.dialogue_reveal_timer +%= 1;
    if (state.dialogue_reveal_timer < ominous_reveal_interval_frames) return;
    state.dialogue_reveal_timer = 0;

    const old_offset = state.dialogue_reveal_offset;
    const new_offset = text_mod.advanceRevealByWords(page.text, old_offset, target, ominous_words_per_tick);
    revealDialogueTo(page.text, new_offset);
}

fn revealDialogueTo(text: []const u8, offset: usize) void {
    const old_offset = state.dialogue_reveal_offset;
    state.dialogue_reveal_offset = offset;
    maybeTriggerSeeShake(text, old_offset, offset);
    state.dialogue_cache.invalidate();
}

fn maybeTriggerSeeShake(text: []const u8, old_offset: usize, new_offset: usize) void {
    if (state.see_shake_started) return;
    const phrase_start = text_mod.findSubstring(text, "see things") orelse return;
    const see_end = phrase_start + 3;
    if (old_offset < see_end and new_offset >= see_end) {
        state.shake_timer = ominous_shake_frames;
        state.see_shake_started = true;
    }
}

fn ominousPage(cutscene: *const GrannyCutscene) bool {
    if (state.phase == .laugh_pause) return true;
    if (state.phase != .dialogue or state.dialogue_index >= cutscene.dialogue.len) return false;
    return state.dialogue_index >= 3 or dialogueUsesTypewriter(cutscene.dialogue[state.dialogue_index].text);
}

fn dialogueUsesTypewriter(text: []const u8) bool {
    return text_mod.contains(text, "strange place") or
        text_mod.contains(text, "see things") or
        text_mod.contains(text, "ready to see");
}

fn laughTextAllowedInRoom(room_index: usize) bool {
    return room_index == granny_scene_room_index or room_index == granny_laugh_carry_room_index;
}

fn playerOverlapsSceneRect(player: Player, rect: SceneRect) bool {
    const left = fixedToPixel(player.x);
    const top = fixedToPixel(player.y);
    return rectsOverlap(left, top, left + player_body_width, top + player_body_height, rect.x, rect.y, rect.right(), rect.bottom());
}

fn movePlayerTowardPoint(player: *Player, point: Spawn, speed: i16) bool {
    const target = playerTarget(point);
    const x = fixedToPixel(player.x);
    const y = fixedToPixel(player.y);
    const dx = target.x - x;
    const dy = target.y - y;
    if (absI16(dx) <= speed and absI16(dy) <= speed) {
        player.x = pixelToFixed(target.x);
        player.y = pixelToFixed(target.y);
        player.moving = false;
        return true;
    }
    player.x = pixelToFixed(x + signI16(dx) * @min(absI16(dx), speed));
    player.y = pixelToFixed(y + signI16(dy) * @min(absI16(dy), speed));
    player.moving = dx != 0;
    return false;
}

fn playerTarget(point: Spawn) Spawn {
    return .{
        .x = point.x - player_body_width / 2,
        .y = point.y - player_body_height,
    };
}

fn renderDialogueTiles(cutscene: *const GrannyCutscene) void {
    if (state.dialogue_index >= cutscene.dialogue.len) return;
    const page = cutscene.dialogue[state.dialogue_index];
    state.dialogue_next_offset = cutscene_dialogue.renderPage(
        page,
        state.dialogue_index,
        state.dialogue_offset,
        state.dialogue_reveal_offset,
        dialogueUsesTypewriter(page.text),
        &state.dialogue_cache,
    );
}

fn npcAnimationForRoom(room_index: usize) granny_npc.Animation {
    if (laugh_text.activeInRoom(room_index)) return .laugh;
    if (state.active and state.room_index == room_index and state.phase == .laugh_pause) return .laugh;
    if (state.active and state.room_index == room_index and state.phase == .dialogue and state.dialogue_index == 4) return .quotes;
    return .idle;
}

fn npcFacingLeftForRoom(cutscene: *const GrannyCutscene, room_index: usize) bool {
    if (state.active and state.room_index == room_index) {
        return switch (state.phase) {
            .walk_edge, .laugh_pause => false,
            .dialogue => if (state.dialogue_index >= 3) false else cutscene.granny_facing_left,
            else => cutscene.granny_facing_left,
        };
    }
    if (intro_done) return false;
    return cutscene.granny_facing_left;
}

fn setDarkened(room_index: usize, enabled: bool) void {
    if (bg_darkened == enabled) return;
    bg_darkened = enabled;
    applyRoomPaletteWithMood(room_index, enabled);
}

fn applyRoomPaletteWithMood(room_index: usize, dark: bool) void {
    const room = rooms[room_index];
    const color_count = @min(room.palette.len / 2, @as(usize, 256));
    var index: usize = 0;
    while (index < color_count) : (index += 1) {
        const color: gba.ColorRgb555 = @bitCast(readU16Le(room.palette, index * 2));
        gba.display.bg_palette.colors[index] = if (dark) darkenColor(color) else color;
    }
    gba.display.bg_palette.colors[background.static_wire_bg_color_index] = if (dark)
        darkenColor(gba.ColorRgb555.rgb(13, 14, 18))
    else
        gba.ColorRgb555.rgb(13, 14, 18);
}

fn darkenColor(color: gba.ColorRgb555) gba.ColorRgb555 {
    const r: u8 = @intCast(color.r);
    const g: u8 = @intCast(color.g);
    const b: u8 = @intCast(color.b);
    return gba.ColorRgb555.rgb(
        @intCast(@divTrunc(r * 2, 3)),
        @intCast(@divTrunc(g * 2, 3)),
        @intCast(@divTrunc(b * 2, 3)),
    );
}
