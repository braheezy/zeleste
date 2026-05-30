const background = @import("../world/background.zig");
const camera_mod = @import("../world/camera.zig");
const chapter_systems = @import("../chapters/systems.zig");
const dash_effects = @import("../player/dash_effects.zig");
const dust = @import("../effects/dust.zig");
const falling_blocks = @import("falling_blocks.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const hair = @import("../player/hair.zig");
const level = @import("../generated_rooms.zig");
const object_slots = @import("object_slots.zig");
const player_death_vfx = @import("../player/death_vfx.zig");
const player_mod = @import("../player/state.zig");
const player_render = @import("../player/render.zig");
const wind_snow = @import("../effects/wind_snow.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const rooms = level.rooms;

pub const scene_slots = object_slots.scene_slots;
pub const cutscene_dialogue_first_object = object_slots.cutscene_dialogue_first_object;
pub const scene_effect_first_object = object_slots.scene_effect_first_object;

pub fn loadWindSnowTiles() void {
    wind_snow.loadTiles();
}

pub fn loadObjectSprites(room_index: usize) void {
    invalidateObjectTileCaches(room_index);
    player_render.loadPalettes();
    falling_blocks.loadGraphics();
    hair.loadPalette();
    dash_effects.loadPalettes();
    dust.loadPalette();
    chapter_systems.loadObjectGraphics(room_index);
    foreground_stamps.loadGraphics();
    player_death_vfx.loadTiles();
    dash_effects.loadTile();
    player_render.loadFrame(0);
}

pub fn hidePlayerObjects() void {
    player_render.hideObjects();
    hair.hideObjects();
}

pub fn resetWindSnow(room_index: usize, camera: Camera) void {
    wind_snow.reset(room_index, camera, windSnowSuppressed(room_index), windSnowLimited(room_index));
}

pub fn updateWindSnow(room_index: usize, camera: Camera, anim_counter: u16) void {
    wind_snow.update(room_index, camera, anim_counter, windSnowSuppressed(room_index), windSnowLimited(room_index));
}

pub fn drawWindSnow(camera: Camera) void {
    wind_snow.draw(camera);
}

pub fn hideWindSnowObjects() void {
    wind_snow.hideObjects();
}

pub fn resetChimneySmoke(room_index: usize) void {
    chapter_systems.resetSceneEffects(room_index, scene_slots);
}

pub fn updateChimneySmoke(room_index: usize, anim_counter: u16) void {
    chapter_systems.updateSceneEffects(room_index, anim_counter, scene_slots);
}

pub fn hideChimneySmokeObjects() void {
    chapter_systems.hideSceneEffectObjects(scene_slots);
}

pub fn drawInitial(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    chapter_systems.drawPlatformActors(camera, room_index, scene_slots);
    chapter_systems.drawDynamicSolids(camera, room_index);
    dash_effects.draw(camera);
    player_render.draw(player.*, camera, anim_counter);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawTutorialNpc(camera, room_index);
    chapter_systems.drawCutsceneNpc(camera, room_index, scene_slots, anim_counter);
    chapter_systems.drawAmbientNpcs(camera, room_index, anim_counter);
    chapter_systems.drawCutsceneOverlay(camera, room_index);
}

pub fn drawGameplay(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    chapter_systems.drawPlatformActors(camera, room_index, scene_slots);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawDynamicSolids(camera, room_index);
    chapter_systems.drawTutorialNpc(camera, room_index);
    chapter_systems.drawCutsceneNpc(camera, room_index, scene_slots, anim_counter);
    chapter_systems.drawAmbientNpcs(camera, room_index, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, chapter_systems.endingHairOverrideActive(room_index));
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    chapter_systems.drawCutsceneOverlay(camera, room_index);
}

pub fn drawLoaded(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    chapter_systems.drawPlatformActors(camera, room_index, scene_slots);
    chapter_systems.drawDynamicSolids(camera, room_index);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, chapter_systems.endingHairOverrideActive(room_index));
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawTutorialNpc(camera, room_index);
    chapter_systems.drawCutsceneNpc(camera, room_index, scene_slots, anim_counter);
    chapter_systems.drawAmbientNpcs(camera, room_index, anim_counter);
    chapter_systems.drawCutsceneOverlay(camera, room_index);
}

pub fn drawRespawnRoom(camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    chapter_systems.drawPlatformActors(camera, room_index, scene_slots);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawDynamicSolids(camera, room_index);
    chapter_systems.drawCutsceneNpc(camera, room_index, scene_slots, anim_counter);
    chapter_systems.drawTutorialNpc(camera, room_index);
    chapter_systems.drawAmbientNpcs(camera, room_index, anim_counter);
}

pub fn drawRespawnBurstEnd(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    chapter_systems.drawPlatformActors(camera, room_index, scene_slots);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawDynamicSolids(camera, room_index);
    chapter_systems.drawCutsceneNpc(camera, room_index, scene_slots, anim_counter);
    chapter_systems.drawTutorialNpc(camera, room_index);
    chapter_systems.drawAmbientNpcs(camera, room_index, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, chapter_systems.endingHairOverrideActive(room_index));
    player_render.draw(player.*, camera, anim_counter);
}

pub fn drawDeathCountdownBase(camera: Camera, room_index: usize) void {
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawDynamicSolids(camera, room_index);
    dash_effects.draw(camera);
}

pub fn drawEndLevelTransition(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    chapter_systems.drawPlatformActors(camera, room_index, scene_slots);
    falling_blocks.draw(camera);
    chapter_systems.drawRoomOverlays(camera, room_index);
    chapter_systems.drawDynamicSolids(camera, room_index);
    chapter_systems.drawTutorialNpc(camera, room_index);
    chapter_systems.drawCutsceneNpc(camera, room_index, scene_slots, anim_counter);
    chapter_systems.drawAmbientNpcs(camera, room_index, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, chapter_systems.endingHairOverrideActive(room_index));
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    chapter_systems.drawCutsceneOverlay(camera, room_index);
}

fn invalidateObjectTileCaches(room_index: usize) void {
    player_render.invalidate();
    chapter_systems.invalidateObjectTileCaches(room_index);
}

fn applyCamera(camera: Camera, room_index: usize) void {
    background.applyCamera(room_index, rooms[room_index], camera);
}

fn updateParallaxBackground(camera: Camera, room_index: usize) void {
    background.updateParallax(room_index, rooms[room_index], camera);
}

fn drawChimneySmoke(camera: Camera, room_index: usize) void {
    chapter_systems.drawSceneEffects(camera, room_index, scene_slots);
}

fn windSnowSuppressed(room_index: usize) bool {
    return chapter_systems.windSnowSuppressed(room_index);
}

fn windSnowLimited(room_index: usize) bool {
    return chapter_systems.windSnowLimited(room_index);
}
