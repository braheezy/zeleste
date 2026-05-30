const gba = @import("gba");
const camera_mod = @import("../world/camera.zig");
const city = @import("city.zig");
const object_slots = @import("../room/object_slots.zig");
const player_mod = @import("../player/state.zig");
const prologue = @import("prologue/systems.zig");
const room_data = @import("../world/room_data.zig");

pub const SceneSlots = object_slots.SceneSlots;

const ActiveChapter = enum {
    prologue,
    city,
};

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const Spawn = room_data.Spawn;

pub fn resetPaletteState(room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.resetPaletteState(),
        .city => city.systems.resetPaletteState(),
    }
}

pub fn loadBeforeObjectSprites(room_index: usize, slots: SceneSlots) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.loadBeforeObjectSprites(room_index, slots),
        .city => city.systems.loadBeforeObjectSprites(room_index, slots),
    }
}

pub fn loadObjectGraphics(room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.loadObjectGraphics(),
        .city => city.systems.loadObjectGraphics(),
    }
}

pub fn invalidateObjectTileCaches(room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.invalidateObjectTileCaches(),
        .city => city.systems.invalidateObjectTileCaches(),
    }
}

pub fn loadAfterObjectSprites(room_index: usize, reset_cutscenes: bool) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.loadAfterObjectSprites(room_index, reset_cutscenes),
        .city => city.systems.loadAfterObjectSprites(room_index, reset_cutscenes),
    }
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.updateCutscenes(player, input, room_index),
        .city => city.systems.updateCutscenes(player, input, room_index),
    };
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.updateCutsceneEffects(room_index, camera),
        .city => city.systems.updateCutsceneEffects(room_index, camera),
    }
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera, anim_counter: u16) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.updateActors(player, room_index, camera, anim_counter),
        .city => city.systems.updateActors(player, room_index, camera, anim_counter),
    }
}

pub fn actorFloorAt(room_index: usize, player_x: i16, player_y: i16) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.actorFloorAt(room_index, player_x, player_y),
        .city => city.systems.actorFloorAt(room_index, player_x, player_y),
    };
}

pub fn actorTopForPlayer(room_index: usize, player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.actorTopForPlayer(room_index, player_x, old_bottom, next_bottom),
        .city => city.systems.actorTopForPlayer(room_index, player_x, old_bottom, next_bottom),
    };
}

pub fn releaseActorAtPlayer(room_index: usize, player: Player) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.releaseActorAtPlayer(room_index, player),
        .city => city.systems.releaseActorAtPlayer(room_index, player),
    }
}

pub fn triggerActorBounceAtPlayer(room_index: usize, player: Player) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.triggerActorBounceAtPlayer(room_index, player),
        .city => city.systems.triggerActorBounceAtPlayer(room_index, player),
    }
}

pub fn asphaltFloorAtPlayer(room_index: usize, player: Player) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.asphaltFloorAtPlayer(room_index, player),
        .city => city.systems.asphaltFloorAtPlayer(room_index, player),
    };
}

pub fn dynamicSolidRectAt(room_index: usize, x: i16, y: i16, width: i16, height: i16) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.dynamicSolidRectAt(room_index, x, y, width, height),
        .city => city.systems.dynamicSolidRectAt(room_index, x, y, width, height),
    };
}

pub fn endingHairOverrideActive(room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.endingHairOverrideActive(room_index),
        .city => city.systems.endingHairOverrideActive(room_index),
    };
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    switch (activeChapterForRoom(from_room)) {
        .prologue => prologue.handleRoomTransition(from_room, to_room),
        .city => city.systems.handleRoomTransition(from_room, to_room),
    }
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.handlePlayerDeathStart(room_index),
        .city => city.systems.handlePlayerDeathStart(room_index),
    }
}

pub fn cameraShakeOffset(room_index: usize) ?Spawn {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.cameraShakeOffset(room_index),
        .city => city.systems.cameraShakeOffset(room_index),
    };
}

pub fn windSnowSuppressed(room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.windSnowSuppressed(room_index),
        .city => city.systems.windSnowSuppressed(room_index),
    };
}

pub fn windSnowLimited(room_index: usize) bool {
    return switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.windSnowLimited(room_index),
        .city => city.systems.windSnowLimited(room_index),
    };
}

pub fn resetSceneEffects(room_index: usize, slots: SceneSlots) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.resetSceneEffects(room_index, slots),
        .city => city.systems.resetSceneEffects(room_index, slots),
    }
}

pub fn updateSceneEffects(room_index: usize, anim_counter: u16, slots: SceneSlots) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.updateSceneEffects(room_index, anim_counter, slots),
        .city => city.systems.updateSceneEffects(room_index, anim_counter, slots),
    }
}

pub fn hideSceneEffectObjects(slots: SceneSlots) void {
    prologue.hideSceneEffectObjects(slots);
    city.systems.hideSceneEffectObjects(slots);
}

pub fn drawPlatformActors(camera: Camera, room_index: usize, slots: SceneSlots) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawPlatformActors(camera, room_index, slots),
        .city => city.systems.drawPlatformActors(camera, room_index, slots),
    }
}

pub fn drawDynamicSolids(camera: Camera, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawDynamicSolids(camera, room_index),
        .city => city.systems.drawDynamicSolids(camera, room_index),
    }
}

pub fn drawSceneEffects(camera: Camera, room_index: usize, slots: SceneSlots) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawSceneEffects(camera, room_index, slots),
        .city => city.systems.drawSceneEffects(camera, room_index, slots),
    }
}

pub fn drawRoomOverlays(camera: Camera, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawRoomOverlays(camera, room_index),
        .city => city.systems.drawRoomOverlays(camera, room_index),
    }
}

pub fn drawTutorialNpc(camera: Camera, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawTutorialNpc(camera, room_index),
        .city => city.systems.drawTutorialNpc(camera, room_index),
    }
}

pub fn drawCutsceneNpc(camera: Camera, room_index: usize, slots: SceneSlots, anim_counter: u16) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawCutsceneNpc(camera, room_index, slots, anim_counter),
        .city => city.systems.drawCutsceneNpc(camera, room_index, slots, anim_counter),
    }
}

pub fn drawAmbientNpcs(camera: Camera, room_index: usize, anim_counter: u16) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawAmbientNpcs(camera, room_index, anim_counter),
        .city => city.systems.drawAmbientNpcs(camera, room_index, anim_counter),
    }
}

pub fn drawCutsceneOverlay(camera: Camera, room_index: usize) void {
    switch (activeChapterForRoom(room_index)) {
        .prologue => prologue.drawCutsceneOverlay(camera, room_index),
        .city => city.systems.drawCutsceneOverlay(camera, room_index),
    }
}

fn activeChapterForRoom(room_index: usize) ActiveChapter {
    if (city.flow.ownsGeneratedRoomIndex(room_index)) return .city;
    return .prologue;
}
