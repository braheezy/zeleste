const camera_mod = @import("../camera.zig");
const level = @import("../../generated_rooms.zig");
const player_mod = @import("../player.zig");
const prologue = @import("prologue/systems.zig");

pub const ObjectSlots = struct {
    funny_car_first_object: usize,
};

const ActiveChapter = enum {
    prologue,
};

const active_chapter: ActiveChapter = switch (level.chapter_index) {
    0 => .prologue,
    else => @compileError("unsupported generated chapter runtime"),
};

const Camera = camera_mod.Camera;
const Player = player_mod.State;

pub fn loadBeforeObjectSprites(room_index: usize, slots: ObjectSlots) void {
    switch (active_chapter) {
        .prologue => prologue.loadBeforeObjectSprites(room_index, .{
            .funny_car_first_object = slots.funny_car_first_object,
        }),
    }
}

pub fn loadAfterObjectSprites(room_index: usize, reset_cutscenes: bool) void {
    switch (active_chapter) {
        .prologue => prologue.loadAfterObjectSprites(room_index, reset_cutscenes),
    }
}

pub fn updateCutscenes(player: *Player, input: @import("gba").input.BufferedKeysState, room_index: usize) bool {
    return switch (active_chapter) {
        .prologue => prologue.updateCutscenes(player, input, room_index),
    };
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    switch (active_chapter) {
        .prologue => prologue.updateCutsceneEffects(room_index, camera),
    }
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera, anim_counter: u16) void {
    switch (active_chapter) {
        .prologue => prologue.updateActors(player, room_index, camera, anim_counter),
    }
}

pub fn actorFloorAt(player_x: i16, player_y: i16) bool {
    return switch (active_chapter) {
        .prologue => prologue.actorFloorAt(player_x, player_y),
    };
}

pub fn actorTopForPlayer(player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    return switch (active_chapter) {
        .prologue => prologue.actorTopForPlayer(player_x, old_bottom, next_bottom),
    };
}

pub fn releaseActorAtPlayer(player: Player) void {
    switch (active_chapter) {
        .prologue => prologue.releaseActorAtPlayer(player),
    }
}

pub fn triggerActorBounceAtPlayer(player: Player) void {
    switch (active_chapter) {
        .prologue => prologue.triggerActorBounceAtPlayer(player),
    }
}

pub fn asphaltFloorAtPlayer(player: Player) bool {
    return switch (active_chapter) {
        .prologue => prologue.asphaltFloorAtPlayer(player),
    };
}

pub fn dynamicSolidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    return switch (active_chapter) {
        .prologue => prologue.dynamicSolidRectAt(x, y, width, height),
    };
}

pub fn endingHairOverrideActive() bool {
    return switch (active_chapter) {
        .prologue => prologue.endingHairOverrideActive(),
    };
}
