const gba = @import("gba");
const camera_mod = @import("../world/camera.zig");
const city = @import("city.zig");
const player_mod = @import("../player/state.zig");
const prologue = @import("prologue.zig");
const room_data = @import("../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const Spawn = room_data.Spawn;

pub fn updateTransitionIfActive(player: *Player, camera: *Camera, room_index: *usize, respawn: *Spawn, input: gba.input.BufferedKeysState) bool {
    return switch (activeChapterForRoom(room_index.*)) {
        .prologue => prologue.flow.updateTransitionIfActive(player, camera, room_index, respawn, input),
        .city => false,
    };
}

pub fn dashUnlocked(room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.dashUnlocked(),
        .city => true,
    };
}

pub fn endingHoldActive(room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.endingHoldActive(),
        .city => false,
    };
}

pub fn shouldStartBridgeEndingHold(player: Player, room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.shouldStartBridgeEndingHold(player, room_index),
        .city => false,
    };
}

pub fn startBridgeEndingHold(player: *Player, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.startBridgeEndingHold(player),
        .city => {},
    }
}

pub fn updateBridgeEndingHold(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.updateBridgeEndingHold(player, input, room_index),
        .city => {},
    }
}

pub fn shouldStartEndLevelTransition(player: Player, room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.shouldStartEndLevelTransition(player, room_index),
        .city => false,
    };
}

pub fn startEndLevelTransition(player: *Player, camera: Camera, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.flow.startEndLevelTransition(player, camera),
        .city => {},
    }
}

const ActiveChapter = enum {
    prologue,
    city,
};

fn activeChapterForRoom(room_index: usize) ActiveChapter {
    if (city.flow.ownsGeneratedRoomIndex(room_index)) return .city;
    return .prologue;
}
