const gba = @import("gba");
const camera_mod = @import("../../world/camera.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const object_slots = @import("../../room/object_slots.zig");
const entities = @import("entities.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const Spawn = room_data.Spawn;
const SceneSlots = object_slots.SceneSlots;

pub fn resetPaletteState() void {}

pub fn loadBeforeObjectSprites(room_index: usize, slots: SceneSlots) void {
    _ = room_index;
    _ = slots;
}

pub fn loadObjectGraphics() void {}

pub fn invalidateObjectTileCaches() void {}

pub fn loadAfterObjectSprites(room_index: usize, reset_cutscenes: bool) void {
    _ = room_index;
    _ = reset_cutscenes;
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    _ = player;
    _ = input;
    _ = room_index;
    return false;
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    _ = room_index;
    _ = camera;
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera, anim_counter: u16) void {
    _ = player;
    _ = room_index;
    _ = camera;
    _ = anim_counter;
}

pub fn updateDynamicHazards(player: *Player, room_index: usize) ?player_mod.DeathCause {
    _ = player;
    _ = room_index;
    return null;
}

pub fn updateDynamicHazardsDuringDeath(room_index: usize) void {
    entities.updateDynamicHazardsDuringDeath(room_index);
}

pub fn actorFloorAt(room_index: usize, player_x: i16, player_y: i16) bool {
    _ = room_index;
    _ = player_x;
    _ = player_y;
    return false;
}

pub fn actorTopForPlayer(room_index: usize, player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    _ = room_index;
    _ = player_x;
    _ = old_bottom;
    _ = next_bottom;
    return null;
}

pub fn releaseActorAtPlayer(room_index: usize, player: Player) void {
    _ = room_index;
    _ = player;
}

pub fn triggerActorBounceAtPlayer(room_index: usize, player: Player) void {
    _ = room_index;
    _ = player;
}

pub fn asphaltFloorAtPlayer(room_index: usize, player: Player) bool {
    _ = room_index;
    _ = player;
    return false;
}

pub fn snowFloorAtPlayer(room_index: usize, player: Player) bool {
    _ = room_index;
    _ = player;
    return false;
}

pub fn dynamicSolidRectAt(room_index: usize, x: i16, y: i16, width: i16, height: i16) bool {
    _ = room_index;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return false;
}

pub fn endingHairOverrideActive(room_index: usize) bool {
    _ = room_index;
    return false;
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    _ = from_room;
    _ = to_room;
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    _ = room_index;
}

pub fn cameraShakeOffset(room_index: usize) ?Spawn {
    _ = room_index;
    return null;
}

pub fn windSnowSuppressed(room_index: usize) bool {
    _ = room_index;
    return false;
}

pub fn windSnowLimited(room_index: usize) bool {
    _ = room_index;
    return false;
}

pub fn resetSceneEffects(room_index: usize, slots: SceneSlots) void {
    _ = room_index;
    _ = slots;
}

pub fn updateSceneEffects(room_index: usize, anim_counter: u16, slots: SceneSlots) void {
    _ = room_index;
    _ = anim_counter;
    _ = slots;
}

pub fn hideSceneEffectObjects(slots: SceneSlots) void {
    _ = slots;
}

pub fn drawPlatformActors(camera: Camera, room_index: usize, slots: SceneSlots) void {
    _ = camera;
    _ = room_index;
    _ = slots;
}

pub fn drawDynamicSolids(camera: Camera, room_index: usize) void {
    _ = camera;
    _ = room_index;
}

pub fn drawSceneEffects(camera: Camera, room_index: usize, slots: SceneSlots) void {
    _ = camera;
    _ = room_index;
    _ = slots;
}

pub fn drawRoomOverlays(camera: Camera, room_index: usize) void {
    _ = camera;
    _ = room_index;
}

pub fn drawTutorialNpc(camera: Camera, room_index: usize) void {
    _ = camera;
    _ = room_index;
}

pub fn drawCutsceneNpc(camera: Camera, room_index: usize, slots: SceneSlots, anim_counter: u16) void {
    _ = camera;
    _ = room_index;
    _ = slots;
    _ = anim_counter;
}

pub fn drawAmbientNpcs(camera: Camera, room_index: usize, anim_counter: u16) void {
    _ = camera;
    _ = room_index;
    _ = anim_counter;
}

pub fn drawCutsceneOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
    _ = camera;
    _ = room_index;
    _ = anim_counter;
}
