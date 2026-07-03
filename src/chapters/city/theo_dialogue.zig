const gba = @import("gba");

const assets = @import("../../core/assets.zig");
const camera_mod = @import("../../world/camera.zig");
const cutscene_dialogue = @import("../../cutscene/dialogue.zig");
const theo_dialogue_data = @import("../../generated/assets/city/6zb_dialogue.zig");
const flow = @import("flow.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const obj_vram = @import("../../core/obj_vram.zig");
const object_slots = @import("../../room/object_slots.zig");
const oam = @import("../../core/oam.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const text_mod = @import("../../core/text.zig");
const ui_sfx = @import("../../core/ui_sfx.zig");

const Camera = camera_mod.Camera;
const CutsceneDialoguePage = room_data.CutsceneDialoguePage;
const Player = player_mod.State;
const SceneRect = room_data.SceneRect;
const Spawn = room_data.Spawn;

const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const tiles_data align(4) = assets.speech_bubble_tiles_data;
const palette_data align(4) = assets.speech_bubble_palette_data;
const meta = assets.speech_bubble_meta;

const theo_room_index = flow.roomIndexFor(1, "6zb") orelse level.rooms.len;
const dialogue_first_object = object_slots.cutscene_dialogue_first_object;
const bubble_object = 127;
const bubble_base_tile: u10 = @intCast(obj_vram.theo_prompt_bubble.start);
const bubble_palette_bank: u4 = 6;
const dialogue_reveal_interval_frames: u8 = 5;
const dialogue_words_per_tick: u8 = 1;
const prompt_distance_x: i16 = 28;
const prompt_distance_y: i16 = 24;
const dialogue_min_distance_x: i16 = 20;
const theo_feet: Spawn = theo_dialogue_data.theo_feet;
const bubble_top_left: Spawn = .{ .x = theo_feet.x - 16, .y = theo_feet.y - 56 };
const dialogue_box: SceneRect = theo_dialogue_data.dialogue_box;
const conversations = theo_dialogue_data.conversations;

const State = struct {
    active: bool = false,
    conversation_index: u8 = 0,
    page_index: u8 = 0,
    dialogue_offset: usize = 0,
    dialogue_reveal_offset: usize = 0,
    dialogue_reveal_timer: u8 = 0,
    dialogue_next_offset: usize = 0,
    dialogue_portrait_timer: u16 = 0,
    dialogue_cache: cutscene_dialogue.Cache = .{},
    near_prompt: bool = false,
};

var state: State = .{};
var bubble_visible: bool = false;

pub fn loadGraphics(room_index: usize) void {
    if (!isTheoRoom(room_index)) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bubble_palette_bank) * 16], @ptrCast(&palette_data), 16);
    loadBubbleTiles();
    cutscene_dialogue.setTextboxSkin(.chapter1);
    cutscene_dialogue.resetTextboxGraphics();
}

pub fn resetOnRoomLoad(room_index: usize) void {
    if (isTheoRoom(room_index)) return;
    abortDialogue();
    hideBubble();
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    if (isTheoRoom(from_room) and !isTheoRoom(to_room)) {
        abortDialogue();
        hideBubble();
    }
}

pub fn handlePlayerDeathStart() void {
    abortDialogue();
    hideBubble();
}

pub fn update(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    if (!isTheoRoom(room_index)) {
        state.near_prompt = false;
        return false;
    }

    if (!state.active) {
        const can_start_dialogue = hasAvailableConversation() and playerCanStartTheoDialogue(player.*);
        state.near_prompt = can_start_dialogue;
        if (can_start_dialogue and input.isJustPressed(.A)) {
            startDialogue(player);
        }
    }

    if (!state.active) return false;

    lockPlayer(player);
    state.dialogue_portrait_timer +|= 1;
    updateDialogueReveal();
    updateDialogue(input);
    return state.active;
}

pub fn drawOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
    _ = anim_counter;
    if (!isTheoRoom(room_index)) {
        cutscene_dialogue.hideObjects(dialogue_first_object);
        hideBubble();
        return;
    }

    if (state.active) {
        hideBubble();
        renderDialogueTiles();
        const pages = currentPages();
        if (state.page_index < pages.len) {
            cutscene_dialogue.drawObjects(camera, dialogue_first_object, dialogue_box, pages[state.page_index], state.dialogue_portrait_timer, dialogueTextRevealing());
        }
        return;
    }

    cutscene_dialogue.hideObjects(dialogue_first_object);
    if (hasAvailableConversation()) {
        drawBubble(camera, state.near_prompt);
    } else {
        hideBubble();
    }
}

fn startDialogue(player: *Player) void {
    alignPlayerForDialogue(player);
    state.active = true;
    state.page_index = 0;
    state.dialogue_offset = 0;
    resetDialogueReveal(currentPage());
    state.dialogue_next_offset = 0;
    state.dialogue_portrait_timer = 0;
    state.dialogue_cache.invalidate();
    hideBubble();
    cutscene_dialogue.setTextboxSkin(.chapter1);
    cutscene_dialogue.resetTextboxGraphics();
    ui_sfx.dialogueBoxIn(pageSpeakerIsMadeline(currentPage()));
}

fn alignPlayerForDialogue(player: *Player) void {
    const center_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const side = playerSideForDialogue(center_x, player.facing_left);
    const distance = absI16(center_x - theo_feet.x);
    const target_center_x = if (distance < dialogue_min_distance_x)
        theo_feet.x + side * dialogue_min_distance_x
    else
        center_x;

    player.x = pixelToFixed(target_center_x - player_mod.body_width / 2);
    player.facing_left = side > 0;
    player.animation = .idle;
    player.animation_timer = 0;
    player.idle_first_frame = player_mod.idle_neutral_first_frame;
    player.idle_frame_count = player_mod.idle_neutral_frame_count;
    player.frame = player_mod.idle_neutral_first_frame;
}

fn playerSideForDialogue(center_x: i16, facing_left: bool) i16 {
    if (center_x < theo_feet.x) return -1;
    if (center_x > theo_feet.x) return 1;
    return if (facing_left) 1 else -1;
}

fn updateDialogue(input: gba.input.BufferedKeysState) void {
    const pages = currentPages();
    if (state.page_index >= pages.len) {
        finishDialogue();
        return;
    }
    if (!(input.isJustPressed(.A) or input.isJustPressed(.B))) return;

    const page_data = pages[state.page_index];
    const page_end = cutscene_dialogue.wrappedNextOffset(page_data, state.dialogue_offset);
    if (state.dialogue_reveal_offset < page_end) {
        ui_sfx.dialogueAdvance(pageSpeakerIsMadeline(page_data));
        revealDialogueTo(page_data, page_end);
        return;
    }

    if (page_end < page_data.text.len) {
        ui_sfx.dialogueAdvance(pageSpeakerIsMadeline(page_data));
        state.dialogue_offset = page_end;
        resetDialogueReveal(page_data);
        state.dialogue_cache.invalidate();
        return;
    }

    const next_page = state.page_index + 1;
    if (next_page >= pages.len) {
        ui_sfx.dialogueBoxOut(pageSpeakerIsMadeline(page_data));
        finishDialogue();
    } else {
        ui_sfx.dialogueAdvance(pageSpeakerIsMadeline(page_data));
        state.page_index = @intCast(next_page);
        state.dialogue_offset = 0;
        resetDialogueReveal(pages[next_page]);
        state.dialogue_cache.invalidate();
        state.dialogue_portrait_timer = 0;
    }
}

fn finishDialogue() void {
    if (state.conversation_index < conversations.len) {
        state.conversation_index += 1;
    }
    state.active = false;
    state.page_index = 0;
    state.dialogue_offset = 0;
    state.dialogue_reveal_offset = 0;
    state.dialogue_reveal_timer = 0;
    state.dialogue_next_offset = 0;
    state.dialogue_portrait_timer = 0;
    state.dialogue_cache.invalidate();
    cutscene_dialogue.hideObjects(dialogue_first_object);
}

fn abortDialogue() void {
    if (!state.active) return;
    state.active = false;
    state.page_index = 0;
    state.dialogue_offset = 0;
    state.dialogue_reveal_offset = 0;
    state.dialogue_reveal_timer = 0;
    state.dialogue_next_offset = 0;
    state.dialogue_portrait_timer = 0;
    state.dialogue_cache.invalidate();
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
    player.climb_dir = 0;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
}

fn renderDialogueTiles() void {
    const pages = currentPages();
    if (state.page_index >= pages.len) return;
    const page_data = pages[state.page_index];
    const page_end = cutscene_dialogue.wrappedNextOffset(page_data, state.dialogue_offset);
    cutscene_dialogue.setTextboxSkin(.chapter1);
    cutscene_dialogue.preloadPortrait(page_data, state.dialogue_portrait_timer, state.dialogue_reveal_offset < page_end);
    state.dialogue_next_offset = cutscene_dialogue.renderPage(
        page_data,
        state.page_index,
        state.dialogue_offset,
        state.dialogue_reveal_offset,
        false,
        &state.dialogue_cache,
    );
}

fn dialogueTextRevealing() bool {
    return state.dialogue_reveal_offset < state.dialogue_next_offset;
}

fn resetDialogueReveal(page_data: CutsceneDialoguePage) void {
    state.dialogue_reveal_offset = text_mod.skipSpaces(page_data.text, state.dialogue_offset);
    state.dialogue_reveal_timer = 0;
    state.dialogue_cache.invalidate();
}

fn updateDialogueReveal() void {
    const pages = currentPages();
    if (state.page_index >= pages.len) return;
    const page_data = pages[state.page_index];
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
    revealDialogueTo(page_data, new_offset);
    if (new_offset != old_offset) ui_sfx.dialogueText(dialogueVoice(page_data));
}

fn revealDialogueTo(page_data: CutsceneDialoguePage, offset: usize) void {
    _ = page_data;
    state.dialogue_reveal_offset = offset;
}

fn currentPages() []const CutsceneDialoguePage {
    return conversations[@min(state.conversation_index, conversations.len - 1)].pages;
}

fn currentPage() CutsceneDialoguePage {
    return currentPages()[state.page_index];
}

fn hasAvailableConversation() bool {
    return state.conversation_index < conversations.len;
}

fn playerNearTheo(player: Player) bool {
    const center_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const center_y = fixedToPixel(player.y) + player_mod.body_height / 2;
    return absI16(center_x - theo_feet.x) <= prompt_distance_x and absI16(center_y - (theo_feet.y - 12)) <= prompt_distance_y;
}

fn playerCanStartTheoDialogue(player: Player) bool {
    return player_mod.canStartInteraction(player) and playerNearTheo(player);
}

fn drawBubble(camera: Camera, prompt: bool) void {
    loadBubbleTiles();
    const frame: u16 = if (prompt) meta.prompt_frame_index else meta.idle_frame_index;
    const tile = bubble_base_tile + @as(u10, @intCast(frame * meta.tiles_per_frame));
    gba.display.objects[bubble_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(bubble_top_left.x - camera.x),
        .y = objY(bubble_top_left.y - camera.y),
        .base_tile = tile,
        .priority = 0,
        .palette = bubble_palette_bank,
    });
    bubble_visible = true;
}

fn loadBubbleTiles() void {
    gba.display.memcpyObjectTiles4Bpp(bubble_base_tile, @ptrCast(&tiles_data));
}

fn hideBubble() void {
    if (!bubble_visible) return;
    hideObject(bubble_object);
    bubble_visible = false;
}

fn pageSpeakerIsMadeline(page_data: CutsceneDialoguePage) bool {
    return text_mod.startsWith(page_data.speaker, "Madeline");
}

fn dialogueVoice(page_data: CutsceneDialoguePage) ui_sfx.DialogueVoice {
    return if (pageSpeakerIsMadeline(page_data)) .madeline_normal else .generic;
}

fn isTheoRoom(room_index: usize) bool {
    return room_index == theo_room_index;
}

fn absI16(value: i16) i16 {
    return if (value < 0) -value else value;
}
