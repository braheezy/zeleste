const gba = @import("gba");
const camera_mod = @import("../../world/camera.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const object_slots = @import("../../room/object_slots.zig");
const tiny_birds = @import("../../room/tiny_birds.zig");
const s1_tiny_birds = @import("../../generated/assets/city/s1_tiny_birds.zig");
const ending = @import("ending.zig");
const entities = @import("entities.zig");
const theo_dialogue = @import("theo_dialogue.zig");
const flow = @import("flow.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const Spawn = room_data.Spawn;
const SceneSlots = object_slots.SceneSlots;

const city_s1_room_index = flow.roomIndexFor(1, "s1") orelse 0xffff;

pub fn resetPaletteState() void {
    entities.resetPaletteState();
}

pub fn loadBeforeObjectSprites(room_index: usize, slots: SceneSlots) void {
    _ = room_index;
    _ = slots;
}

pub fn loadObjectGraphics(room_index: usize) void {
    _ = room_index;
}

pub fn invalidateObjectTileCaches() void {
    entities.invalidateObjectGraphics();
}

pub fn loadAfterObjectSprites(room_index: usize, reset_cutscenes: bool) void {
    _ = reset_cutscenes;
    ending.resetOnRoomLoad(room_index);
    theo_dialogue.resetOnRoomLoad(room_index);
    entities.loadObjectGraphics(room_index);
    tiny_birds.load(room_index, tinyBirdStartsForRoom(room_index), tinyBirdPuzzleStartsForRoom(room_index), tinyBirdPuzzleAntennaTipForRoom(room_index));
    ending.loadGraphics(room_index);
    theo_dialogue.loadGraphics(room_index);
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    if (ending.update(player, input, room_index)) return true;
    if (theo_dialogue.update(player, input, room_index)) return true;
    return entities.updateCutscenes(player, room_index);
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    _ = room_index;
    _ = camera;
    entities.updateImpactEffects();
}

pub fn applyPlayerFrameOverride(player: *Player, room_index: usize) void {
    ending.applyPlayerFrameOverride(player, room_index);
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera, anim_counter: u16) void {
    tiny_birds.update(player, room_index, anim_counter);
    _ = camera;
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
    return ending.endingHairOverrideActive(room_index);
}

pub fn playerHairSuppressed(room_index: usize) bool {
    return ending.playerHairSuppressed(room_index);
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    entities.handleRoomTransition(from_room, to_room);
    ending.handleRoomTransition(from_room, to_room);
    theo_dialogue.handleRoomTransition(from_room, to_room);
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    ending.handlePlayerDeathStart(room_index);
    theo_dialogue.handlePlayerDeathStart();
}

pub fn cameraShakeOffset(room_index: usize) ?Spawn {
    _ = room_index;
    return entities.cameraShakeOffset();
}

pub fn windSnowSuppressed(room_index: usize) bool {
    _ = room_index;
    return false;
}

pub fn windSnowLimited(room_index: usize) bool {
    return ending.ownsRoom(room_index);
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
    _ = room_index;
    tiny_birds.draw(camera, anim_counter);
}

pub fn drawCutsceneOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
    if (ending.ownsRoom(room_index)) {
        ending.drawOverlay(camera, room_index, anim_counter);
        return;
    }
    theo_dialogue.drawOverlay(camera, room_index, anim_counter);
}

fn tinyBirdStartsForRoom(room_index: usize) []const tiny_birds.Start {
    if (room_index == city_s1_room_index) return s1_tiny_birds.starts;
    return &.{};
}

fn tinyBirdPuzzleStartsForRoom(room_index: usize) []const tiny_birds.PuzzleStart {
    if (room_index == city_s1_room_index) return s1_tiny_birds.puzzle_starts;
    return &.{};
}

fn tinyBirdPuzzleAntennaTipForRoom(room_index: usize) ?tiny_birds.AntennaTipStart {
    if (room_index == city_s1_room_index) return s1_tiny_birds.antenna_tip;
    return null;
}
