const background = @import("background.zig");
const bird_npc = @import("bird_npc.zig");
const camera_mod = @import("camera.zig");
const chimney_smoke = @import("chimney_smoke.zig");
const cutscene_dialogue = @import("cutscene_dialogue.zig");
const cutscene_laugh_text = @import("cutscene_laugh_text.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("dust.zig");
const falling_blocks = @import("falling_blocks.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const funny_cars = @import("funny_cars.zig");
const granny_npc = @import("granny_npc.zig");
const hair = @import("hair.zig");
const level = @import("../generated_rooms.zig");
const player_death_vfx = @import("player_death_vfx.zig");
const player_mod = @import("player.zig");
const player_render = @import("player_render.zig");
const prologue_bridge = @import("prologue_bridge.zig");
const prologue_granny_cutscene = @import("prologue_granny_cutscene.zig");
const room_wires = @import("room_wires.zig");
const tiny_birds = @import("tiny_birds.zig");
const wind_snow = @import("wind_snow.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const rooms = level.rooms;
const chimney_smoke_room_index = level.roomIndexFor(level.chapter_index, "2") orelse rooms.len;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;

const chimney_smoke_origin = chimney_smoke.Origin{
    .x = 194,
    .y = 49,
};

pub const funny_car_first_object = bird_npc.hint_object + 1;
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
    chimney_smoke.loadPalette();
    granny_npc.loadPalette();
    funny_cars.loadGraphics();
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
    chimney_smoke.reset(chimney_smoke_first_object);
}

pub fn updateChimneySmoke(room_index: usize, anim_counter: u16) void {
    chimney_smoke.update(chimneySmokeActive(room_index), anim_counter, chimney_smoke_first_object);
}

pub fn hideChimneySmokeObjects() void {
    chimney_smoke.hideObjects(chimney_smoke_first_object);
}

pub fn drawInitial(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    funny_cars.draw(camera, funny_car_first_object);
    prologue_bridge.draw(camera);
    dash_effects.draw(camera);
    player_render.draw(player.*, camera, anim_counter);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    room_wires.draw(camera, prologue_bridge.active());
    bird_npc.draw(camera);
    prologue_granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    tiny_birds.draw(camera, anim_counter);
    prologue_granny_cutscene.drawOverlay(camera, room_index);
}

pub fn drawGameplay(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    room_wires.draw(camera, prologue_bridge.active());
    prologue_bridge.draw(camera);
    bird_npc.draw(camera);
    prologue_granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    tiny_birds.draw(camera, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue_bridge.endingHoldActive());
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    prologue_granny_cutscene.drawOverlay(camera, room_index);
}

pub fn drawLoaded(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    funny_cars.draw(camera, funny_car_first_object);
    prologue_bridge.draw(camera);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue_bridge.endingHoldActive());
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    room_wires.draw(camera, prologue_bridge.active());
    bird_npc.draw(camera);
    prologue_granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    tiny_birds.draw(camera, anim_counter);
    prologue_granny_cutscene.drawOverlay(camera, room_index);
}

pub fn drawRespawnRoom(camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    room_wires.draw(camera, prologue_bridge.active());
    prologue_bridge.draw(camera);
    prologue_granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    bird_npc.draw(camera);
    tiny_birds.draw(camera, anim_counter);
}

pub fn drawRespawnBurstEnd(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    room_wires.draw(camera, prologue_bridge.active());
    prologue_bridge.draw(camera);
    prologue_granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    bird_npc.draw(camera);
    tiny_birds.draw(camera, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue_bridge.endingHoldActive());
    player_render.draw(player.*, camera, anim_counter);
}

pub fn drawDeathCountdownBase(camera: Camera, room_index: usize) void {
    falling_blocks.draw(camera);
    drawChimneySmoke(camera, room_index);
    room_wires.draw(camera, prologue_bridge.active());
    prologue_bridge.draw(camera);
    dash_effects.draw(camera);
}

pub fn drawEndLevelTransition(player: *Player, camera: Camera, room_index: usize, anim_counter: u16) void {
    applyCamera(camera, room_index);
    updateParallaxBackground(camera, room_index);
    foreground_stamps.draw(camera, anim_counter);
    funny_cars.draw(camera, funny_car_first_object);
    falling_blocks.draw(camera);
    room_wires.draw(camera, prologue_bridge.active());
    prologue_bridge.draw(camera);
    bird_npc.draw(camera);
    prologue_granny_cutscene.drawNpc(camera, room_index, granny_object, anim_counter);
    tiny_birds.draw(camera, anim_counter);
    dash_effects.draw(camera);
    hair.draw(player.*, camera, prologue_bridge.endingHoldActive());
    dust.draw(camera);
    drawWindSnow(camera);
    player_render.draw(player.*, camera, anim_counter);
    player_render.drawSweat(player, camera);
    prologue_granny_cutscene.drawOverlay(camera, room_index);
}

fn invalidateObjectTileCaches() void {
    player_render.invalidate();
    bird_npc.invalidate();
    granny_npc.invalidate();
    cutscene_laugh_text.invalidateTiles();
}

fn applyCamera(camera: Camera, room_index: usize) void {
    background.applyCamera(room_index, rooms[room_index], camera);
}

fn updateParallaxBackground(camera: Camera, room_index: usize) void {
    background.updateParallax(room_index, rooms[room_index], camera);
}

fn drawChimneySmoke(camera: Camera, room_index: usize) void {
    chimney_smoke.draw(camera, chimneySmokeActive(room_index), chimney_smoke_first_object, chimney_smoke_origin);
}

fn chimneySmokeActive(room_index: usize) bool {
    return room_index == chimney_smoke_room_index;
}

fn windSnowSuppressed(room_index: usize) bool {
    return isPrologueEndRoom(room_index) and prologue_bridge.sequenceStarted();
}

fn windSnowLimited(room_index: usize) bool {
    return isPrologueEndRoom(room_index);
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}
