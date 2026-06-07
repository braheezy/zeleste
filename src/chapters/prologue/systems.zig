const gba = @import("gba");
const camera_mod = @import("../../world/camera.zig");
const level = @import("../../generated_rooms.zig");
const object_slots = @import("../../room/object_slots.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");

const bird_npc = @import("bird_npc.zig");
const bridge = @import("bridge.zig");
const chimney_smoke = @import("chimney_smoke.zig");
const dust = @import("../../effects/dust.zig");
const falling_blocks = @import("falling_blocks.zig");
const funny_cars = @import("funny_cars.zig");
const granny_cutscene = @import("granny_cutscene.zig");
const granny_npc = @import("granny_npc.zig");
const laugh_text = @import("laugh_text.zig");
const room_wires = @import("room_wires.zig");
const tiny_birds = @import("tiny_birds.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const SceneSlots = object_slots.SceneSlots;
const Spawn = room_data.Spawn;

const rooms = level.rooms;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;
var room_wires_hidden_for_collapse: bool = false;

pub fn resetPaletteState() void {
    granny_cutscene.resetPaletteState();
}

pub fn loadBeforeObjectSprites(room_index: usize, slots: SceneSlots) void {
    falling_blocks.load(room_index);
    funny_cars.load(room_index, slots.actor_platform_first_object);
}

pub fn loadObjectGraphics(room_index: usize) void {
    falling_blocks.loadGraphics(room_index);
    chimney_smoke.loadPalette();
    granny_npc.loadPalette();
    funny_cars.loadGraphics();
}

pub fn invalidateObjectTileCaches() void {
    bird_npc.invalidate();
    granny_npc.invalidate();
    laugh_text.invalidateTiles();
}

pub fn loadAfterObjectSprites(room_index: usize, reset_cutscenes: bool) void {
    bridge.load(room_index, isPrologueEndRoom(room_index));
    bird_npc.load(room_index);
    tiny_birds.load(room_index);
    room_wires.load(room_index, bridge.active());
    room_wires_hidden_for_collapse = false;
    if (reset_cutscenes) {
        granny_cutscene.resetOnRoomLoad(room_index);
    }
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    return granny_cutscene.update(player, input, room_index);
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    granny_cutscene.updateEffects(room_index, camera);
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera, anim_counter: u16) void {
    bridge.update(player, isPrologueEndRoom(room_index));
    bridge.updateCollapseShake(isPrologueEndRoom(room_index), player.grounded);
    funny_cars.update(player.*);
    bird_npc.update(player.*, camera);
    tiny_birds.update(player.*, room_index, anim_counter);
}

pub fn updateDynamicHazards(player: *Player, room_index: usize) ?player_mod.DeathCause {
    const result = falling_blocks.update(room_index, player);
    spawnFallingBlockSnowEvents(result);
    if (result.killed_player) return .normal;
    return null;
}

pub fn updateDynamicHazardsDuringDeath(room_index: usize) void {
    const result = falling_blocks.updateDuringDeath(room_index);
    spawnFallingBlockSnowEvents(result);
}

pub fn actorFloorAt(room_index: usize, player_x: i16, player_y: i16) bool {
    _ = room_index;
    return funny_cars.floorAt(player_x, player_y);
}

pub fn actorTopForPlayer(room_index: usize, player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    _ = room_index;
    return funny_cars.topForPlayer(player_x, old_bottom, next_bottom);
}

pub fn releaseActorAtPlayer(room_index: usize, player: Player) void {
    _ = room_index;
    funny_cars.releaseAtPlayer(player);
}

pub fn triggerActorBounceAtPlayer(room_index: usize, player: Player) void {
    _ = room_index;
    funny_cars.triggerBounceAtPlayer(player);
}

pub fn asphaltFloorAtPlayer(room_index: usize, player: Player) bool {
    _ = room_index;
    return bridge.floorAtPlayer(player);
}

pub fn snowFloorAtPlayer(room_index: usize, player: Player) bool {
    _ = room_index;
    return falling_blocks.floorAtPlayer(player);
}

pub fn dynamicSolidRectAt(room_index: usize, x: i16, y: i16, width: i16, height: i16) bool {
    _ = room_index;
    return falling_blocks.solidRectAt(x, y, width, height) or bridge.solidRectAt(x, y, width, height);
}

pub fn endingHairOverrideActive(room_index: usize) bool {
    _ = room_index;
    return bridge.endingHoldActive();
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    granny_cutscene.handleRoomTransition(from_room, to_room);
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    _ = room_index;
    granny_cutscene.handlePlayerDeathStart();
}

pub fn cameraShakeOffset(room_index: usize) ?Spawn {
    _ = room_index;
    const bridge_shake = bridge.collapseShakeOffset();
    const granny_shake = granny_cutscene.shakeOffset();
    if (granny_shake == null and bridge_shake == null) return null;

    var offset: Spawn = .{ .x = 0, .y = 0 };
    if (granny_shake) |shake| {
        offset.x += shake.x;
        offset.y += shake.y;
    }
    if (bridge_shake) |shake| {
        offset.x += shake.x;
        offset.y += shake.y;
    }
    return offset;
}

pub fn windSnowSuppressed(room_index: usize) bool {
    return isPrologueEndRoom(room_index) and bridge.sequenceStarted();
}

pub fn windSnowLimited(room_index: usize) bool {
    return isPrologueEndRoom(room_index);
}

pub fn resetSceneEffects(room_index: usize, slots: SceneSlots) void {
    _ = room_index;
    chimney_smoke.reset(slots.scene_effect_first_object);
}

pub fn updateSceneEffects(room_index: usize, anim_counter: u16, slots: SceneSlots) void {
    chimney_smoke.update(room_index, anim_counter, slots.scene_effect_first_object);
}

pub fn hideSceneEffectObjects(slots: SceneSlots) void {
    chimney_smoke.hideObjects(slots.scene_effect_first_object);
}

pub fn drawPlatformActors(camera: Camera, room_index: usize, slots: SceneSlots) void {
    _ = room_index;
    funny_cars.draw(camera, slots.actor_platform_first_object);
}

pub fn drawDynamicSolids(camera: Camera, room_index: usize) void {
    _ = room_index;
    falling_blocks.draw(camera);
    bridge.draw(camera);
}

pub fn drawSceneEffects(camera: Camera, room_index: usize, slots: SceneSlots) void {
    chimney_smoke.draw(camera, room_index, slots.scene_effect_first_object);
}

pub fn drawRoomOverlays(camera: Camera, room_index: usize) void {
    _ = room_index;
    if (bridge.sequenceStarted()) {
        if (!room_wires_hidden_for_collapse) {
            room_wires.hideObjects(bridge.active());
            room_wires_hidden_for_collapse = true;
        }
        return;
    }
    room_wires_hidden_for_collapse = false;
    room_wires.draw(camera, bridge.active());
}

pub fn drawTutorialNpc(camera: Camera, room_index: usize) void {
    _ = room_index;
    bird_npc.draw(camera);
}

pub fn drawCutsceneNpc(camera: Camera, room_index: usize, slots: SceneSlots, anim_counter: u16) void {
    granny_cutscene.drawNpc(camera, room_index, slots.cutscene_npc_object, anim_counter);
}

pub fn drawAmbientNpcs(camera: Camera, room_index: usize, anim_counter: u16) void {
    tiny_birds.draw(camera, anim_counter);
    _ = room_index;
}

pub fn drawCutsceneOverlay(camera: Camera, room_index: usize, anim_counter: u16) void {
    granny_cutscene.drawOverlay(camera, room_index, anim_counter);
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}

fn spawnFallingBlockSnowEvents(result: falling_blocks.UpdateResult) void {
    var index: usize = 0;
    while (index < result.snow_count) : (index += 1) {
        const block = result.snow_blocks[index];
        dust.spawnSnowFromBlock(block.x, block.y, block.w);
    }
}
