const gba = @import("gba");

const assets = @import("../../core/assets.zig");
const audio = @import("../../core/audio.zig");
const camera_mod = @import("../../world/camera.zig");
const cutscene_dialogue = @import("../../cutscene/dialogue.zig");
const ending_data = @import("../../generated/assets/city/end_cutscene.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const obj_vram = @import("../../core/obj_vram.zig");
const object_slots = @import("../../room/object_slots.zig");
const oam = @import("../../core/oam.zig");
const player_collision = @import("../../player/collision.zig");
const player_controller = @import("../../player/controller.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const text_mod = @import("../../core/text.zig");
const ui_sfx = @import("../../core/ui_sfx.zig");
const video = @import("../../core/video.zig");

const Camera = camera_mod.Camera;
const CutsceneDialoguePage = room_data.CutsceneDialoguePage;
const Player = player_mod.State;
const SceneRect = room_data.SceneRect;
const Spawn = room_data.Spawn;

const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const end_room_index = level.roomIndexFor(level.chapter_index, "city_end") orelse level.rooms.len;
const sound_ids = assets.sound_ids;
const dialogue_object_range = object_slots.cutscene_dialogue_slots;
const dialogue_first_object = object_slots.cutscene_dialogue_first_object;
const dialogue_reveal_interval_frames: u8 = 5;
const dialogue_words_per_tick: u8 = 1;
const scripted_walk_speed: i32 = fixed_one;
const walk_past_fire_offset_x: i16 = 24;
const scripted_walk_timeout_frames: u16 = 180;

const memorial_object_first = dialogue_first_object;
const memorial_max_objects: usize = 17;
const memorial_tiles_per_object: u10 = 4;
const memorial_tile_count: usize = memorial_max_objects * @as(usize, memorial_tiles_per_object);
const memorial_base_tile: u10 = @intCast(obj_vram.city_end_memorial_text.start);
const memorial_palette_bank: u4 = 7;
const memorial_width: i16 = 224;
const memorial_chunk_width: i16 = 32;
const memorial_chunk_height: i16 = 8;
const memorial_line_step: i16 = 10;
const memorial_max_lines: usize = 3;
const memorial_shadow_color: u8 = 5;
const memorial_text_color: u8 = 6;
const bird_object = 125;
const campfire_object = 124;
const actor_tile_range = obj_vram.city_end_actor;
const bird_base_tile = actor_tile_range.baseTile();
const bird_palette_bank: u4 = 8;
const bird_tiles_per_frame: u10 = 16;
const bird_fly_first_frame: u16 = 49;
const bird_fly_frame_count: u16 = 4;
const bird_landed_frame: u16 = 0;
const bird_caw_first_frame: u16 = 8;
const bird_caw_frame_count: u16 = 7;
const bird_anim_speed: u16 = 4;
const bird_caw_settle_frames: u16 = 8;
const bird_caw_settle_y: i16 = 1;
const bird_origin_offset_x: i16 = 5;
const bird_origin_offset_y: i16 = 9;
const bird_landed_visible_bottom_y: i16 = 12;
const bird_perch_sink_y: i16 = 3;
const bird_perch_adjust_x: i16 = -3;
const bird_perch_adjust_y: i16 = -4;
const asleep_visual_ground_adjust_y: i16 = 1;
const asleep_head_anchor_x: i16 = 7;
const asleep_head_anchor_y: i16 = 18;
const start_fire_bend_frame_offset: u16 = 8;
const rest_floor_snap_max_pixels: u8 = 24;
const campfire_base_tile = actor_tile_range.tile(bird_tiles_per_frame);
const campfire_palette_bank: u4 = 10;
const campfire_tiles_per_frame: u10 = @intCast(assets.fire_small1_meta.tiles_per_frame);
const campfire_frame_count: u16 = assets.fire_small1_meta.frame_count;
const campfire_anim_speed: u16 = 6;
const campfire_width: i16 = assets.fire_small1_meta.cell_width;
const campfire_height: i16 = assets.fire_small1_meta.cell_height;

const bird_tiles_data align(4) = assets.bird_intro_tiles_data;
const bird_palette_data align(4) = assets.bird_palette_data;
const fire_small1_tiles_data align(4) = assets.fire_small1_tiles_data;
const fire_small1_palette_data align(4) = assets.fire_small1_palette_data;

const Phase = enum(u8) {
    inactive,
    walk_past_fire,
    pause_past_fire,
    turn_back,
    first_line,
    walk_to_rest,
    sit_down,
    start_campfire,
    fall_asleep,
    bird_swoop,
    bird_caw,
    second_line,
    completion_pending,
};

const DialogueKind = enum(u8) {
    none,
    outro,
};

const State = struct {
    phase: Phase = .inactive,
    dialogue_kind: DialogueKind = .none,
    dialogue_page: u8 = 0,
    dialogue_offset: usize = 0,
    dialogue_reveal_offset: usize = 0,
    dialogue_reveal_timer: u8 = 0,
    dialogue_next_offset: usize = 0,
    dialogue_portrait_timer: u16 = 0,
    dialogue_cache: cutscene_dialogue.Cache = .{},
    timer: u16 = 0,
    memorial_visible: bool = false,
    completion_requested: bool = false,
};

var state: State = .{};
const MemorialChunk = struct {
    x: i16 = 0,
    y: i16 = 0,
};

var memorial_tiles: [memorial_tile_count]gba.display.Tile4Bpp align(4) =
    [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** memorial_tile_count;
var memorial_chunks: [memorial_max_objects]MemorialChunk = [_]MemorialChunk{.{}} ** memorial_max_objects;
var memorial_object_count: usize = 0;
var memorial_tiles_dirty: bool = true;
var memorial_tile_write_base: usize = 0;
var bird_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var campfire_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};

pub fn loadGraphics(room_index: usize) void {
    if (!isEndRoom(room_index)) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bird_palette_bank) * 16], @ptrCast(&bird_palette_data), 16);
    loadMemorialPalette();
    cutscene_dialogue.setTextboxSkin(.chapter1);
    cutscene_dialogue.resetTextboxGraphics();
    invalidateCutsceneActorTiles();
    loadCampfireGraphics();
}

pub fn resetOnRoomLoad(room_index: usize) void {
    if (isEndRoom(room_index)) {
        hidePlaceholders();
        hideMemorialTextObjects();
        cutscene_dialogue.hideObjects(dialogue_object_range);
        if (state.phase == .completion_pending) return;
        if (state.phase != .inactive) {
            state = .{};
        }
        return;
    }
    state = .{};
    hidePlaceholders();
    hideMemorialTextObjects();
    cutscene_dialogue.hideObjects(dialogue_object_range);
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    if (isEndRoom(from_room) and !isEndRoom(to_room)) {
        state = .{};
        hidePlaceholders();
        hideMemorialTextObjects();
        cutscene_dialogue.hideObjects(dialogue_object_range);
    }
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    if (!isEndRoom(room_index)) return;
    state = .{};
    hidePlaceholders();
    hideMemorialTextObjects();
    cutscene_dialogue.hideObjects(dialogue_object_range);
}

pub fn update(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    if (!isEndRoom(room_index)) return false;

    if (state.phase == .inactive) {
        state.memorial_visible = playerOverlaps(player.*, ending_data.memorial.trigger);
        if (playerOverlaps(player.*, ending_data.outro.trigger)) {
            startOutro(player);
        }
    } else {
        state.memorial_visible = false;
    }

    switch (state.phase) {
        .inactive => return false,
        .walk_past_fire => updateWalkPastFire(player, room_index),
        .pause_past_fire => {
            holdPlayer(player);
            player.facing_left = false;
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.pause_past_fire_frames) {
                state.phase = .turn_back;
                state.timer = 0;
            }
        },
        .turn_back => {
            holdPlayer(player);
            player.facing_left = true;
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.turn_back_frames) {
                startOutroDialogue(0, .first_line);
            }
        },
        .first_line => {
            holdPlayer(player);
            updateDialogue(input);
            if (!dialogueActive()) {
                state.phase = .walk_to_rest;
                state.timer = 0;
            }
        },
        .walk_to_rest => updateWalkToRest(player, room_index),
        .sit_down => {
            holdPlayer(player);
            player.facing_left = false;
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.sit_down_frames) {
                state.phase = .bird_swoop;
                state.timer = 0;
            }
        },
        .start_campfire => {
            holdPlayer(player);
            player.facing_left = false;
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.make_campfire_frames) {
                state.phase = .sit_down;
                state.timer = 0;
            }
        },
        .fall_asleep => {
            holdPlayer(player);
            player.facing_left = false;
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.fall_asleep_frames) {
                state.phase = .bird_swoop;
                state.timer = 0;
            }
        },
        .bird_swoop => {
            holdPlayer(player);
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.bird_swoop_frames) {
                startBirdCaw();
            }
        },
        .bird_caw => {
            holdPlayer(player);
            player.facing_left = false;
            state.timer += 1;
            if (state.timer >= ending_data.outro.timings.bird_caw_frames) {
                startOutroDialogue(1, .second_line);
            }
        },
        .second_line => {
            holdPlayer(player);
            updateDialogue(input);
            if (!dialogueActive()) {
                state.phase = .completion_pending;
                state.completion_requested = true;
                hidePlaceholders();
            }
        },
        .completion_pending => holdPlayer(player),
    }

    return true;
}

pub fn applyPlayerFrameOverride(player: *Player, room_index: usize) void {
    if (!isEndRoom(room_index) or !cutsceneRestFrameActive()) return;
    player.y = pixelToFixed(madelineCutsceneRestPlayerY(room_index));
    player.frame = cutsceneRestFrame();
    player.animation_timer = 0;
    player.moving = false;
}

pub fn drawOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
    if (!isEndRoom(room_index)) {
        cutscene_dialogue.hideObjects(dialogue_object_range);
        hidePlaceholders();
        hideMemorialTextObjects();
        return;
    }

    if (dialogueActive()) {
        hideMemorialTextObjects();
        drawPlaceholders(camera, room_index, anim_counter);
        renderDialogueTiles();
        const page_data = currentPage();
        cutscene_dialogue.drawObjects(camera, dialogue_object_range, activeDialogueBox(), page_data, state.dialogue_portrait_timer, dialogueTextRevealing());
    } else {
        cutscene_dialogue.hideObjects(dialogue_object_range);
        drawPlaceholders(camera, room_index, anim_counter);
        if (state.memorial_visible and state.phase == .inactive) {
            drawMemorialText(camera);
        } else {
            hideMemorialTextObjects();
        }
    }
}

pub fn endingHairOverrideActive(room_index: usize) bool {
    if (!isEndRoom(room_index)) return false;
    return state.phase == .sit_down or state.phase == .start_campfire or state.phase == .fall_asleep or
        state.phase == .bird_swoop or state.phase == .bird_caw or state.phase == .second_line or state.phase == .completion_pending;
}

pub fn playerHairSuppressed(room_index: usize) bool {
    return isEndRoom(room_index) and cutsceneRestFrameActive();
}

pub fn ownsRoom(room_index: usize) bool {
    return isEndRoom(room_index);
}

pub fn completionRequested() bool {
    return state.completion_requested;
}

pub fn consumeCompletionRequest() bool {
    if (!state.completion_requested) return false;
    state.completion_requested = false;
    return true;
}

pub fn wipeFrames() u8 {
    return ending_data.outro.timings.wipe_frames;
}

pub fn deactivateAfterChapterComplete() void {
    state = .{};
    hidePlaceholders();
    hideMemorialTextObjects();
    cutscene_dialogue.hideObjects(dialogue_object_range);
}

fn startOutro(player: *Player) void {
    state.phase = .walk_past_fire;
    state.dialogue_kind = .none;
    state.timer = 0;
    player.vy = 0;
    player.grounded = true;
    player.facing_left = false;
    player.moving = true;
    player.animation = .run;
    player.animation_timer = 0;
}

fn startOutroDialogue(page_index: u8, next_phase: Phase) void {
    state.phase = next_phase;
    state.dialogue_kind = .outro;
    state.dialogue_page = page_index;
    state.timer = 0;
    startDialogue();
}

fn startBirdCaw() void {
    state.phase = .bird_caw;
    state.timer = 0;
    _ = audio.playSoundEffect(sound_ids.sfx_squawk);
}

fn startDialogue() void {
    state.dialogue_offset = 0;
    state.dialogue_reveal_offset = 0;
    state.dialogue_reveal_timer = 0;
    state.dialogue_next_offset = 0;
    state.dialogue_portrait_timer = 0;
    state.dialogue_cache.invalidate();
    resetDialogueReveal(currentPage());
    cutscene_dialogue.setTextboxSkin(.chapter1);
    cutscene_dialogue.resetTextboxGraphics();
    invalidateCutsceneActorTiles();
    ui_sfx.dialogueBoxIn(pageSpeakerIsMadeline(currentPage()));
}

fn finishDialogue() void {
    const page_data = currentPage();
    ui_sfx.dialogueBoxOut(pageSpeakerIsMadeline(page_data));
    state.dialogue_kind = .none;
    state.dialogue_offset = 0;
    state.dialogue_reveal_offset = 0;
    state.dialogue_reveal_timer = 0;
    state.dialogue_next_offset = 0;
    state.dialogue_portrait_timer = 0;
    state.dialogue_cache.invalidate();
    cutscene_dialogue.hideObjects(dialogue_object_range);
}

fn updateDialogue(input: gba.input.BufferedKeysState) void {
    if (!dialogueActive()) return;
    state.dialogue_portrait_timer +|= 1;
    updateDialogueReveal();
    if (!(input.isJustPressed(.A) or input.isJustPressed(.B))) return;

    const page_data = currentPage();
    const page_end = cutscene_dialogue.wrappedNextOffset(page_data, state.dialogue_offset);
    if (state.dialogue_reveal_offset < page_end) {
        ui_sfx.dialogueAdvance(pageSpeakerIsMadeline(page_data));
        revealDialogueTo(page_end);
        return;
    }

    if (page_end < page_data.text.len) {
        ui_sfx.dialogueAdvance(pageSpeakerIsMadeline(page_data));
        state.dialogue_offset = page_end;
        resetDialogueReveal(page_data);
        state.dialogue_cache.invalidate();
        return;
    }

    finishDialogue();
}

fn renderDialogueTiles() void {
    if (!dialogueActive()) return;
    const page_data = currentPage();
    const page_end = cutscene_dialogue.wrappedNextOffset(page_data, state.dialogue_offset);
    cutscene_dialogue.setTextboxSkin(.chapter1);
    cutscene_dialogue.preloadPortrait(page_data, state.dialogue_portrait_timer, state.dialogue_reveal_offset < page_end);
    state.dialogue_next_offset = cutscene_dialogue.renderPage(
        page_data,
        state.dialogue_page,
        state.dialogue_offset,
        state.dialogue_reveal_offset,
        false,
        &state.dialogue_cache,
    );
}

fn updateDialogueReveal() void {
    if (!dialogueActive()) return;
    const page_data = currentPage();
    const target = cutscene_dialogue.wrappedNextOffset(page_data, state.dialogue_offset);
    if (state.dialogue_reveal_offset < state.dialogue_offset) {
        state.dialogue_reveal_offset = text_mod.skipSpaces(page_data.text, state.dialogue_offset);
    }
    if (state.dialogue_reveal_offset >= target) return;

    state.dialogue_reveal_timer +%= 1;
    if (state.dialogue_reveal_timer < dialogue_reveal_interval_frames) return;
    state.dialogue_reveal_timer = 0;

    const old_offset = state.dialogue_reveal_offset;
    const new_offset = text_mod.advanceRevealByWords(page_data.text, old_offset, target, dialogue_words_per_tick);
    revealDialogueTo(new_offset);
    if (new_offset != old_offset) ui_sfx.dialogueText(dialogueVoice(page_data));
}

fn resetDialogueReveal(page_data: CutsceneDialoguePage) void {
    state.dialogue_reveal_offset = text_mod.skipSpaces(page_data.text, state.dialogue_offset);
    state.dialogue_reveal_timer = 0;
    state.dialogue_cache.invalidate();
}

fn revealDialogueTo(offset: usize) void {
    state.dialogue_reveal_offset = offset;
}

fn dialogueTextRevealing() bool {
    return state.dialogue_reveal_offset < state.dialogue_next_offset;
}

fn dialogueActive() bool {
    return state.dialogue_kind != .none;
}

fn cutsceneRestFrameActive() bool {
    return state.phase == .sit_down or state.phase == .start_campfire or state.phase == .fall_asleep or
        state.phase == .bird_swoop or state.phase == .bird_caw or state.phase == .second_line or state.phase == .completion_pending;
}

fn cutsceneRestFrame() u16 {
    if (state.phase == .start_campfire) {
        const frame_offset = @min(start_fire_bend_frame_offset, player_mod.sit_down_frame_count - 1);
        return @as(u16, player_mod.sit_down_first_frame) + frame_offset;
    }
    if (state.phase != .sit_down) return player_mod.asleep_first_frame;

    const total = @max(@as(u16, ending_data.outro.timings.sit_down_frames), 1);
    const progress = @min(state.timer, total - 1);
    const frame_count: u16 = player_mod.sit_down_frame_count;
    const frame_offset = @min(
        frame_count - 1,
        @divTrunc(progress * frame_count, total),
    );
    return @as(u16, player_mod.sit_down_first_frame) + frame_offset;
}

fn currentPage() CutsceneDialoguePage {
    return switch (state.dialogue_kind) {
        .outro => ending_data.outro.dialogue[@min(state.dialogue_page, ending_data.outro.dialogue.len - 1)],
        .none => ending_data.outro.dialogue[0],
    };
}

fn activeDialogueBox() SceneRect {
    return switch (state.dialogue_kind) {
        .outro => ending_data.outro.dialogue_box,
        .none => ending_data.outro.dialogue_box,
    };
}

fn updateWalkToRest(player: *Player, room_index: usize) void {
    const target_x = madelineRestPlayerX(room_index);
    const target_y = madelineRestPlayerY(room_index);
    const player_left = fixedToPixel(player.x);
    const dx = target_x - player_left;
    const reached_target = math.absI16(dx) <= 1 or state.timer > 180;
    player.vy = 0;
    player.grounded = true;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.facing_left = dx < 0;
    player.moving = !reached_target;
    if (!reached_target) {
        player.vx = if (dx < 0) -scripted_walk_speed else scripted_walk_speed;
        player_controller.moveHorizontal(player, player.vx, room_index);
        snapPlayerDownToFloor(player, room_index);
        state.timer += 1;
    } else {
        player.x = pixelToFixed(target_x);
        player.y = pixelToFixed(target_y);
        snapPlayerDownToFloor(player, room_index);
        player.vx = 0;
        player.moving = false;
        player.facing_left = false;
        player.animation = .idle;
        player.animation_timer = 0;
        state.phase = .start_campfire;
        state.timer = 0;
    }
}

fn updateWalkPastFire(player: *Player, room_index: usize) void {
    const target_x = walkPastFireTargetX(room_index);
    const player_left = fixedToPixel(player.x);
    const reached_target = player_left >= target_x or state.timer > scripted_walk_timeout_frames;
    player.vy = 0;
    player.grounded = true;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.facing_left = false;
    player.moving = !reached_target;
    if (!reached_target) {
        player.vx = scripted_walk_speed;
        player_controller.moveHorizontal(player, player.vx, room_index);
        snapPlayerDownToFloor(player, room_index);
        state.timer += 1;
    } else {
        if (player_left < target_x) {
            player.x = pixelToFixed(target_x);
        }
        snapPlayerDownToFloor(player, room_index);
        player.vx = 0;
        player.moving = false;
        player.animation = .idle;
        player.animation_timer = 0;
        state.phase = .pause_past_fire;
        state.timer = 0;
    }
}

fn holdPlayer(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    player.moving = false;
    player.grounded = true;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
}

fn snapPlayerDownToFloor(player: *Player, room_index: usize) void {
    var steps: u8 = 0;
    while (steps < 8 and !player_collision.floorContact(player.*, room_index)) : (steps += 1) {
        player.grounded = false;
        player_controller.moveVertical(player, fixed_one, room_index);
    }
    player.grounded = player_collision.floorContact(player.*, room_index);
    player.vy = 0;
}

fn drawPlaceholders(camera: Camera, room_index: usize, anim_counter: u16) void {
    switch (state.phase) {
        .start_campfire, .sit_down, .fall_asleep, .bird_swoop, .bird_caw, .second_line, .completion_pending => drawCampfire(camera, anim_counter),
        else => hideObject(campfire_object),
    }

    switch (state.phase) {
        .bird_swoop, .bird_caw, .second_line, .completion_pending => drawBird(camera, room_index, anim_counter),
        else => hideObject(bird_object),
    }
}

fn drawMemorialText(camera: Camera) void {
    loadMemorialTextTiles();
    const box = ending_data.memorial.dialogue_box;
    const base_x = math.clampI16(box.x - camera.x, 8, video.screen_width - memorial_width - 8);
    const base_y = math.clampI16(box.y - camera.y, 8, video.screen_height - memorial_line_step * @as(i16, @intCast(memorial_max_lines)));
    var index: usize = 0;
    while (index < memorial_object_count) : (index += 1) {
        const chunk = memorial_chunks[index];
        gba.display.objects[memorial_object_first + index] = gba.display.Object.init(.{
            .size = .size_32x8,
            .x = objX(base_x + chunk.x),
            .y = objY(base_y + chunk.y),
            .base_tile = memorial_base_tile + @as(u10, @intCast(index)) * memorial_tiles_per_object,
            .priority = 0,
            .palette = memorial_palette_bank,
        });
    }
    while (index < memorial_max_objects) : (index += 1) {
        hideObject(memorial_object_first + index);
    }
}

fn drawCampfire(camera: Camera, anim_counter: u16) void {
    const frame = campfireFrame(anim_counter);
    loadCampfireFrame(frame);
    const point = ending_data.outro.campfire;
    gba.display.objects[campfire_object] = gba.display.Object.init(.{
        .size = .size_16x32,
        .x = objX(point.x - campfire_width / 2 - camera.x),
        .y = objY(point.y - campfire_height - camera.y),
        .base_tile = campfire_base_tile,
        .priority = 1,
        .palette = campfire_palette_bank,
    });
}

fn campfireFrame(anim_counter: u16) u16 {
    return @intCast(@divTrunc(anim_counter, campfire_anim_speed) % campfire_frame_count);
}

fn drawBird(camera: Camera, room_index: usize, anim_counter: u16) void {
    const point = birdPosition(room_index);
    const frame = birdFrame(anim_counter);
    loadBirdFrame(frame);
    gba.display.objects[bird_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(point.x - bird_origin_offset_x - camera.x),
        .y = objY(point.y - bird_origin_offset_y - camera.y),
        .base_tile = bird_base_tile,
        .priority = birdPriority(),
        .palette = bird_palette_bank,
        .flip = gba.math.Vec2B.init(true, false),
    });
}

fn birdPriority() u2 {
    return if (state.phase == .bird_swoop) 0 else 2;
}

fn birdFrame(anim_counter: u16) u16 {
    if (state.phase == .bird_swoop) {
        return bird_fly_first_frame + @as(u16, @intCast(@divTrunc(anim_counter, bird_anim_speed) % bird_fly_frame_count));
    }
    if (state.phase == .bird_caw) {
        const total = @max(@as(u16, ending_data.outro.timings.bird_caw_frames), 1);
        const progress = @min(state.timer, total - 1);
        const frame_offset = @min(
            bird_caw_frame_count - 1,
            @divTrunc(progress * bird_caw_frame_count, total),
        );
        return bird_caw_first_frame + frame_offset;
    }
    return bird_landed_frame;
}

fn loadBirdFrame(frame: u16) void {
    bird_frame_cache.upload4Bpp(actor_tile_range, &bird_tiles_data, frame, bird_tiles_per_frame);
}

fn birdPosition(room_index: usize) Spawn {
    const target = birdLandPoint(room_index);
    if (state.phase != .bird_swoop) {
        return .{
            .x = target.x,
            .y = target.y + birdSettledOffsetY(),
        };
    }
    const total = @max(@as(u16, ending_data.outro.timings.bird_swoop_frames), 1);
    const progress = @min(state.timer, total);
    const start = ending_data.outro.bird_start;
    return .{
        .x = lerpI16(start.x, target.x, progress, total),
        .y = lerpI16(start.y, target.y, progress, total),
    };
}

fn birdSettledOffsetY() i16 {
    return switch (state.phase) {
        .bird_caw => if (state.timer >= bird_caw_settle_frames) bird_caw_settle_y else 0,
        .second_line, .completion_pending => bird_caw_settle_y,
        else => 0,
    };
}

fn birdLandPoint(room_index: usize) Spawn {
    const draw_x = madelineRestPlayerX(room_index) + player_mod.draw_offset_x;
    const draw_y = madelineCutsceneRestPlayerY(room_index) + player_mod.draw_offset_y;
    return .{
        .x = draw_x + asleep_head_anchor_x + bird_perch_adjust_x,
        .y = draw_y + asleep_head_anchor_y - bird_landed_visible_bottom_y + bird_perch_sink_y + bird_perch_adjust_y,
    };
}

fn loadCampfireGraphics() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, campfire_palette_bank) * 16], @ptrCast(&fire_small1_palette_data), 16);
    campfire_frame_cache.invalidate();
}

fn loadMemorialPalette() void {
    const base = @as(usize, memorial_palette_bank) * 16;
    gba.display.obj_palette.colors[base + 0] = .black;
    gba.display.obj_palette.colors[base + memorial_shadow_color] = gba.ColorRgb555.rgb(1, 2, 5);
    gba.display.obj_palette.colors[base + memorial_text_color] = gba.ColorRgb555.rgb(27, 30, 31);
    memorial_tiles_dirty = true;
}

fn loadCampfireFrame(frame: u16) void {
    campfire_frame_cache.upload4BppAt(actor_tile_range, bird_tiles_per_frame, &fire_small1_tiles_data, frame, campfire_tiles_per_frame);
}

fn invalidateCutsceneActorTiles() void {
    bird_frame_cache.invalidate();
    campfire_frame_cache.invalidate();
}

fn loadMemorialTextTiles() void {
    if (!memorial_tiles_dirty) return;
    buildMemorialTextTiles();
    gba.display.memcpyObjectTiles4Bpp(memorial_base_tile, @ptrCast(&memorial_tiles));
    memorial_tiles_dirty = false;
}

fn buildMemorialTextTiles() void {
    memorial_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** memorial_tile_count;
    memorial_chunks = [_]MemorialChunk{.{}} ** memorial_max_objects;
    memorial_object_count = 0;

    const source = ending_data.memorial.page.text;
    var offset: usize = 0;
    var line_index: usize = 0;
    while (line_index < memorial_max_lines and offset <= source.len and memorial_object_count < memorial_max_objects) : (line_index += 1) {
        const line_start = offset;
        while (offset < source.len and source[offset] != '\n') : (offset += 1) {}
        drawMemorialLine(source[line_start..offset], @intCast(line_index));
        if (offset >= source.len) break;
        offset += 1;
    }
}

fn drawMemorialLine(line: []const u8, line_index: i16) void {
    const raw_width: i16 = @intCast(@min(line.len * 6, @as(usize, memorial_width)));
    const line_width = @max(@as(i16, 1), raw_width);
    const start_x = @divTrunc(memorial_width - line_width, 2);
    const end_x = start_x + line_width;
    const first_chunk_x = @divTrunc(start_x, memorial_chunk_width) * memorial_chunk_width;
    const chunk_count = @min(memorial_max_objects - memorial_object_count, @as(usize, @intCast(@divTrunc(end_x - first_chunk_x + memorial_chunk_width - 1, memorial_chunk_width))));
    var chunk_index: usize = 0;
    while (chunk_index < chunk_count) : (chunk_index += 1) {
        const object_index = memorial_object_count;
        const chunk_x = first_chunk_x + @as(i16, @intCast(chunk_index * @as(usize, @intCast(memorial_chunk_width))));
        memorial_chunks[object_index] = .{
            .x = chunk_x,
            .y = line_index * memorial_line_step,
        };
        memorial_tile_write_base = object_index * @as(usize, memorial_tiles_per_object);
        text_mod.drawLine(setMemorialTextPixel, memorial_chunk_width, line, start_x - chunk_x + 1, 1, memorial_shadow_color);
        text_mod.drawLine(setMemorialTextPixel, memorial_chunk_width, line, start_x - chunk_x, 0, memorial_text_color);
        memorial_object_count += 1;
    }
}

fn hidePlaceholders() void {
    hideObject(campfire_object);
    hideObject(bird_object);
}

fn hideMemorialTextObjects() void {
    var index: usize = 0;
    while (index < memorial_max_objects) : (index += 1) {
        hideObject(memorial_object_first + index);
    }
}

fn setMemorialTextPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= memorial_chunk_width or y >= memorial_chunk_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const tile_index = memorial_tile_write_base + ux / 8;
    const byte_index = (uy & 7) * 4 + (ux & 7) / 2;
    if ((ux & 1) == 0) {
        memorial_tiles[tile_index].data_8[byte_index] = (memorial_tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        memorial_tiles[tile_index].data_8[byte_index] = (memorial_tiles[tile_index].data_8[byte_index] & 0x0f) | (color << 4);
    }
}

fn playerOverlaps(player: Player, rect: SceneRect) bool {
    const left = fixedToPixel(player.x);
    const top = fixedToPixel(player.y);
    const right = left + player_mod.body_width;
    const bottom = top + player_mod.body_height;
    return right > rect.x and left < rect.right() and bottom > rect.y and top < rect.bottom();
}

fn pageSpeakerIsMadeline(page_data: CutsceneDialoguePage) bool {
    return text_mod.startsWith(page_data.speaker, "Madeline");
}

fn dialogueVoice(page_data: CutsceneDialoguePage) ui_sfx.DialogueVoice {
    return if (pageSpeakerIsMadeline(page_data)) .madeline_normal else .generic;
}

fn isEndRoom(room_index: usize) bool {
    return room_index == end_room_index;
}

fn madelineRestPlayerX(room_index: usize) i16 {
    const room = level.rooms[room_index];
    return math.clampI16(
        ending_data.outro.madeline_rest.x - player_mod.body_width / 2,
        0,
        room.width_pixels - player_mod.body_width,
    );
}

fn madelineRestPlayerY(room_index: usize) i16 {
    const room = level.rooms[room_index];
    const x = madelineRestPlayerX(room_index);
    var y = math.clampI16(
        ending_data.outro.madeline_rest.y - player_mod.body_height,
        0,
        room.height_pixels - player_mod.body_height,
    );
    var steps: u8 = 0;
    while (steps < rest_floor_snap_max_pixels and !player_collision.floorContactAt(x, y, room_index)) : (steps += 1) {
        if (y >= room.height_pixels - player_mod.body_height) break;
        y += 1;
    }
    return y;
}

fn madelineCutsceneRestPlayerY(room_index: usize) i16 {
    const room = level.rooms[room_index];
    return math.clampI16(
        madelineRestPlayerY(room_index) + asleep_visual_ground_adjust_y,
        0,
        room.height_pixels - player_mod.body_height,
    );
}

fn walkPastFireTargetX(room_index: usize) i16 {
    const room = level.rooms[room_index];
    return math.clampI16(
        ending_data.outro.campfire.x + walk_past_fire_offset_x,
        0,
        room.width_pixels - player_mod.body_width,
    );
}

fn lerpI16(start: i16, target: i16, step: u16, total: u16) i16 {
    const delta = @as(i32, target) - @as(i32, start);
    const offset = @divTrunc(delta * @as(i32, step), @as(i32, total));
    return @intCast(@as(i32, start) + offset);
}
