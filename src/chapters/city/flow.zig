const gba = @import("gba");

const audio = @import("../../core/audio.zig");
const camera_mod = @import("../../world/camera.zig");
const chapter_complete = @import("../../world/chapter_complete.zig");
const ending = @import("ending.zig");
const file_select = @import("../../core/file_select.zig");
const frame = @import("../../core/frame.zig");
const gameplay_scene = @import("../../room/gameplay_scene.zig");
const hair = @import("../../player/hair.zig");
const inner_monologue = @import("../../core/inner_monologue.zig");
const level = @import("../../generated_rooms.zig");
const overworld_placeholder = @import("../../world/overworld_placeholder.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const room_loader = @import("../../world/room_loader.zig");
const room_systems = @import("../../world/room_systems.zig");
const room_transition = @import("../../world/room_transition.zig");
const save = @import("../../core/save.zig");

pub const chapter_index: i32 = 1;
pub const first_room_id = "1";

const generated_first_room_id = "city_1";
const generated_room_prefix = "city_";
const rooms = level.rooms;

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const RespawnPoint = room_data.RespawnPoint;

const ChapterCompletePhase = enum(u8) {
    inactive,
    black,
    chapter_art,
    overworld,
};

const ChapterCompleteTransition = struct {
    phase: ChapterCompletePhase = .inactive,
    timer: u16 = 0,
};

var chapter_complete_transition: ChapterCompleteTransition = .{};

pub fn firstRoomIndex() ?usize {
    return generatedRoomIndexFor(first_room_id);
}

pub fn ownsGeneratedRoomIndex(room_index: usize) bool {
    if (room_index >= level.room_ids.len) return false;
    return startsWith(level.room_ids[room_index], generated_room_prefix);
}

pub fn updateTransitionIfActive(player: *Player, camera: *Camera, room_index: *usize, respawn: *RespawnPoint, input: gba.input.BufferedKeysState) bool {
    if (ending.consumeCompletionRequest()) {
        startChapterCompleteTransition();
    }
    if (chapter_complete_transition.phase == .inactive) return false;
    updateChapterCompleteTransition(player, camera, room_index, respawn, input);
    return true;
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

fn startChapterCompleteTransition() void {
    chapter_complete_transition = .{
        .phase = .black,
        .timer = 0,
    };
    overworld_placeholder.cutToBlack();
}

fn updateChapterCompleteTransition(player: *Player, camera: *Camera, room_index: *usize, respawn: *RespawnPoint, input: gba.input.BufferedKeysState) void {
    switch (chapter_complete_transition.phase) {
        .inactive => {},
        .black => {
            frame.sync();
            if (chapter_complete_transition.timer >= ending.wipeFrames()) {
                loadChapterCompleteArt();
                chapter_complete_transition.phase = .chapter_art;
                chapter_complete_transition.timer = 0;
            } else {
                chapter_complete_transition.timer += 1;
            }
        },
        .chapter_art => {
            if (input.isAnyJustPressed()) {
                loadOverworldScreen();
                chapter_complete_transition.phase = .overworld;
                chapter_complete_transition.timer = 0;
            }
            frame.sync();
        },
        .overworld => {
            switch (overworld_placeholder.update(input)) {
                .none => {},
                .back => {
                    _ = file_select.chooseSlot();
                    overworld_placeholder.loadScreen();
                },
                .prologue => {
                    inner_monologue.showPrologueIntro();
                    startGameplayFromOverworld(level.start_room_index, player, camera, room_index, respawn);
                    return;
                },
                .city => {
                    const target_room = firstRoomIndex() orelse level.start_room_index;
                    startGameplayFromOverworld(target_room, player, camera, room_index, respawn);
                    return;
                },
            }
            frame.sync();
        },
    }
}

fn loadChapterCompleteArt() void {
    audio.stopSoundEffects();
    audio.stopMusic();
    save.finishChapter(1);
    ending.deactivateAfterChapterComplete();
    room_systems.clearTransientEffects();
    gameplay_scene.hideWindSnowObjects();
    gameplay_scene.hideChimneySmokeObjects();
    chapter_complete.loadCityNap();
}

fn loadOverworldScreen() void {
    audio.stopSoundEffects();
    audio.stopMusic();
    overworld_placeholder.loadScreen();
}

fn startGameplayFromOverworld(target_room: usize, player: *Player, camera: *Camera, room_index: *usize, respawn: *RespawnPoint) void {
    audio.stopSoundEffects();
    room_loader.hideGameplayDisplayForLoad();
    frame.sync();

    room_index.* = target_room;
    save.beginChapterRunForRoom(target_room);
    if (ownsGeneratedRoomIndex(target_room)) {
        audio.playCityMusic();
    } else {
        audio.playPrologueMusic();
    }
    respawn.* = .{
        .room_index = target_room,
        .spawn = rooms[target_room].spawn,
    };
    _ = save.commitSessionCheckpoint(respawn.room_index, respawn.spawn);
    room_loader.loadGameplayRoomPhased(target_room, .transition);
    room_systems.clearTransientEffects();
    player.* = room_transition.spawnPlayerAt(respawn.spawn);
    player.hair_initialized = false;
    hair.update(player, ending.endingHairOverrideActive(target_room));
    camera.* = camera_mod.forPlayer(player.x, player.y, rooms[target_room]);
    gameplay_scene.resetWindSnow(target_room, camera.*);
    gameplay_scene.resetChimneySmoke(target_room);
    gameplay_scene.drawLoaded(player, camera.*, target_room, room_systems.animCounter());
    chapter_complete_transition = .{};
    frame.sync();
    room_loader.showGameplayDisplay(target_room);
}
