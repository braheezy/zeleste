const background = @import("background.zig");
const camera_mod = @import("camera.zig");
const cutscene_dialogue = @import("cutscene_dialogue.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("dust.zig");
const falling_blocks = @import("falling_blocks.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const hair = @import("hair.zig");
const level = @import("../generated_rooms.zig");
const player_death_vfx = @import("player_death_vfx.zig");
const player_mod = @import("player.zig");
const player_render = @import("player_render.zig");
const prologue = @import("chapters/prologue.zig");
const wind_snow = @import("wind_snow.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const rooms = level.rooms;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;

pub const funny_car_first_object = prologue.bird_npc.hint_object + 1;
pub const granny_object = funny_car_first_object;
pub const cutscene_dialogue_first_object = falling_blocks.first_object;
pub const chimney_smoke_first_object = cutscene_dialogue_first_object + cutscene_dialogue.object_count;

pub fn loadWindSnowTiles() void {
    wind_snow.loadTiles();
}

pub fn loadObjectSprites() void {
    invalidateObjectTileCaches();
    player_render.loadPalettes();
    falling_blocks.loadGraphics();
    hair.loadPalette();
    dash_effects.loadPalettes();
    dust.loadPalette();
    prologue.chimney_smoke.loadPalette();
    prologue.granny_npc.loadPalette();
    prologue.funny_cars.loadGraphics();
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
    _ = room_index;
    prologue.chimney_smoke.reset(chimney_smoke_first_object);
}

pub fn updateChimneySmoke(room_index: usize, anim_counter: u16) void {
    prologue.chimney_smoke.update(room_index, anim_counter, chimney_smoke_first_object);
}

pub fn hideChimneySmokeObjects() void {
    prologue.chimney_smoke.hideObjects(chimney_smoke_first_object);
}

pub fn drawInitial(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    prologue.funny_cars.draw(camera, funny_car_first_object);
    prologue.bridge.draw(camera);
    dash_effects.draw(camera);
    player_render.draw(player.*, camera, anim_counter);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bird_npc.draw(camera);
    prologue.granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    prologue.tiny_birds.draw(camera, anim_counter);
    prologue.granny_cutscene.drawOverlay(camera, room_index);
}

pub fn drawGameplay(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    prologue.funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bridge.draw(camera);
    prologue.bird_npc.draw(camera);
    prologue.granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    prologue.tiny_birds.draw(camera, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue.bridge.endingHoldActive());
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    prologue.granny_cutscene.drawOverlay(camera, room_index);
}

pub fn drawLoaded(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    prologue.funny_cars.draw(camera, funny_car_first_object);
    prologue.bridge.draw(camera);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue.bridge.endingHoldActive());
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bird_npc.draw(camera);
    prologue.granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    prologue.tiny_birds.draw(camera, anim_counter);
    prologue.granny_cutscene.drawOverlay(camera, room_index);
}

pub fn drawRespawnRoom(camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    prologue.funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bridge.draw(camera);
    prologue.granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    prologue.bird_npc.draw(camera);
    prologue.tiny_birds.draw(camera, anim_counter);
}

pub fn drawRespawnBurstEnd(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    prologue.funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bridge.draw(camera);
    prologue.granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    prologue.bird_npc.draw(camera);
    prologue.tiny_birds.draw(camera, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue.bridge.endingHoldActive());
    player_render.draw(player.*, camera, anim_counter);
}

pub fn drawDeathCountdownBase(camera: Camera, room_index: usize) void {
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bridge.draw(camera);
    dash_effects.draw(camera);
}

pub fn drawEndLevelTransition(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    prologue.funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    prologue.room_wires.draw(camera, prologue.bridge.active());
    prologue.bridge.draw(camera);
    prologue.bird_npc.draw(camera);
    prologue.granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    prologue.tiny_birds.draw(camera, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue.bridge.endingHoldActive());
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    prologue.granny_cutscene.drawOverlay(camera, room_index);
}

fn invalidateObjectTileCaches() void {
    player_render.invalidate();
    prologue.bird_npc.invalidate();
    prologue.granny_npc.invalidate();
    prologue.laugh_text.invalidateTiles();
}

fn applyCamera(camera: Camera, room_index: usize) void {
    background.applyCamera(room_index, rooms[room_index], camera);
}

fn updateParallaxBackground(camera: Camera, room_index: usize) void {
    background.updateParallax(room_index, rooms[room_index], camera);
}

fn drawChimneySmoke(camera: Camera, room_index: usize) void {
    prologue.chimney_smoke.draw(camera, room_index, chimney_smoke_first_object);
}

fn windSnowSuppressed(room_index: usize) bool {
    return isPrologueEndRoom(room_index) and prologue.bridge.sequenceStarted();
}

fn windSnowLimited(room_index: usize) bool {
    return isPrologueEndRoom(room_index);
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}
