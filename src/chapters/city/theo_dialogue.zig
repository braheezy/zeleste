const gba = @import("gba");

const assets = @import("../../core/assets.zig");
const camera_mod = @import("../../world/camera.zig");
const cutscene_dialogue = @import("../../cutscene/dialogue.zig");
const flow = @import("flow.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
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
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const tiles_data align(4) = assets.speech_bubble_tiles_data;
const palette_data align(4) = assets.speech_bubble_palette_data;
const meta = assets.speech_bubble_meta;

const theo_room_index = flow.roomIndexFor(1, "6zb") orelse level.rooms.len;
const dialogue_first_object = object_slots.cutscene_dialogue_first_object;
const bubble_object = 127;
const bubble_base_tile: u10 = 992;
const bubble_palette_bank: u4 = 6;
const prompt_distance_x: i16 = 28;
const prompt_distance_y: i16 = 24;
const theo_feet: Spawn = .{ .x = 82, .y = 146 };
const bubble_top_left: Spawn = .{ .x = theo_feet.x - 16, .y = theo_feet.y - 56 };
const dialogue_box: SceneRect = .{ .x = 8, .y = 8, .w = 224, .h = 56 };

const Conversation = struct {
    pages: []const CutsceneDialoguePage,
};

const first_dialogue = [_]CutsceneDialoguePage{
    page("Theo", "Ho there, fellow traveller!"),
    page("Madeline", "Oh... hi."),
    page("Theo", "What a killer night for a hike!"),
    page("Madeline", "I guess so."),
    page("Theo", "This place is so crazy.\nI kind of can't believe it exists!"),
    page("Madeline", "Not the easiest climb, is it?\nBut I guess that's what I was looking for..."),
    page("Theo", "Whoa, that sounds pretty serious.\nI'm just happy to see another human in such a lonely place.\nI'm Theo by the way, an adventurer from a far off land!"),
    page("Madeline", "..."),
    page("Theo", "Not much of a talker, are you?\nMysterious lone wolf type, I get it. I'll just imagine some dark backstory for you."),
};

const second_dialogue = [_]CutsceneDialoguePage{
    page("Madeline", "Hey, sorry. I'm Madeline.\nI've got a lot on my mind."),
    page("Theo", "Well, Madeline, I'd say you've come to the right place!\nI'm freezing my toes off, but I can't imagine a better place to be for some quiet reflection."),
    page("Madeline", "Yeah, maybe you're right.\nWhat \"far off land\" do you hail from?"),
    page("Theo", "Well, my inquisitive compatriot, I doth hail from the mystical, exotic kingdom of..."),
    page("Theo", "Seattle."),
    page("Madeline", "It sounds like a special place."),
};

const third_dialogue = [_]CutsceneDialoguePage{
    page("Theo", "This place is wild!\nWhy would an entire city be abandoned?"),
    page("Madeline", "I read that some mega-corporation started building it, but then no one wanted to live here.\nI wonder why..."),
    page("Theo", "My money's on a government cover-up."),
    page("Madeline", "What a waste, to build all of this for no reason..."),
    page("Theo", "At least we get to enjoy the leftovers."),
};

const fourth_dialogue = [_]CutsceneDialoguePage{
    page("Madeline", "Are you here to explore this city?"),
    page("Theo", "Yeah, I have a thing for abandoned places.\nAnd I like to think of myself as a budding photographer."),
    page("Madeline", "Oh really? Cool!\nDo you have a blog or something?"),
    page("Theo", "A blog?\nMadeline.\nEveryone uses InstaPix now.\nI'm TheoUnderStars, look me up!"),
};

const fifth_dialogue = [_]CutsceneDialoguePage{
    page("Theo", "This terrain is pretty tricky, are you turning back soon?"),
    page("Madeline", "Nope. I'm heading for the summit."),
    page("Theo", "I can really see the determination in your eyes!\nIt's inspiring."),
    page("Madeline", "If you say so.\nI bet you could make it to the summit too."),
    page("Theo", "Maybe.\nI don't really care about reaching the top, TBH.\nOh! But I heard there are some legit old ruins up beyond the city.\nLike 1800's legit.\nI know it's risky but I have to see them for myself."),
};

const sixth_dialogue = [_]CutsceneDialoguePage{
    page("Theo", "What's that thing you say right before you do something irresponsible?"),
    page("Madeline", "Uh... \"throw caution to the wind?\""),
    page("Theo", "No, that's not it.\nOh right..."),
    page("Theo", "YOLOOOOOOOOO!!"),
};

const conversations = [_]Conversation{
    .{ .pages = &first_dialogue },
    .{ .pages = &second_dialogue },
    .{ .pages = &third_dialogue },
    .{ .pages = &fourth_dialogue },
    .{ .pages = &fifth_dialogue },
    .{ .pages = &sixth_dialogue },
};

const State = struct {
    active: bool = false,
    conversation_index: u8 = 0,
    page_index: u8 = 0,
    dialogue_offset: usize = 0,
    dialogue_reveal_offset: usize = 0,
    dialogue_next_offset: usize = 0,
    dialogue_cache: cutscene_dialogue.Cache = .{},
    near_prompt: bool = false,
};

var state: State = .{};
var bubble_visible: bool = false;

pub fn loadGraphics(room_index: usize) void {
    if (!isTheoRoom(room_index)) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bubble_palette_bank) * 16], @ptrCast(&palette_data), 16);
    loadBubbleTiles();
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
        state.near_prompt = playerNearTheo(player.*);
        if (hasAvailableConversation() and state.near_prompt and input.isJustPressed(.A)) {
            startDialogue();
        }
    }

    if (!state.active) return false;

    lockPlayer(player);
    updateDialogue(input);
    return state.active;
}

pub fn drawOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
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
            cutscene_dialogue.drawObjects(camera, dialogue_first_object, dialogue_box, pages[state.page_index], anim_counter);
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

fn page(speaker: []const u8, text: []const u8) CutsceneDialoguePage {
    return .{ .speaker = speaker, .text = text, .portrait = .none };
}

fn startDialogue() void {
    state.active = true;
    state.page_index = 0;
    state.dialogue_offset = 0;
    state.dialogue_reveal_offset = currentPage().text.len;
    state.dialogue_next_offset = 0;
    state.dialogue_cache.invalidate();
    hideBubble();
    cutscene_dialogue.resetTextboxGraphics();
    ui_sfx.dialogueBoxIn(pageSpeakerIsMadeline(currentPage()));
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
    if (page_end < page_data.text.len) {
        ui_sfx.dialogueAdvance(pageSpeakerIsMadeline(page_data));
        state.dialogue_offset = page_end;
        state.dialogue_reveal_offset = page_data.text.len;
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
        state.dialogue_reveal_offset = pages[next_page].text.len;
        state.dialogue_cache.invalidate();
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
    state.dialogue_next_offset = 0;
    state.dialogue_cache.invalidate();
    cutscene_dialogue.hideObjects(dialogue_first_object);
}

fn abortDialogue() void {
    if (!state.active) return;
    state.active = false;
    state.page_index = 0;
    state.dialogue_offset = 0;
    state.dialogue_reveal_offset = 0;
    state.dialogue_next_offset = 0;
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
    player.dash_cooldown_timer = 0;
}

fn renderDialogueTiles() void {
    const pages = currentPages();
    if (state.page_index >= pages.len) return;
    const page_data = pages[state.page_index];
    state.dialogue_next_offset = cutscene_dialogue.renderPage(
        page_data,
        state.page_index,
        state.dialogue_offset,
        state.dialogue_reveal_offset,
        false,
        &state.dialogue_cache,
    );
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

fn isTheoRoom(room_index: usize) bool {
    return room_index == theo_room_index;
}

fn absI16(value: i16) i16 {
    return if (value < 0) -value else value;
}
