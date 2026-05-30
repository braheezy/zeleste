const gba = @import("gba");
const background = @import("background.zig");
const bird_npc = @import("bird_npc.zig");
const camera_mod = @import("camera.zig");
const collision = @import("collision.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("dust.zig");
const falling_blocks = @import("falling_blocks.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const funny_cars = @import("funny_cars.zig");
const gameplay_scene = @import("gameplay_scene.zig");
const hair = @import("hair.zig");
const level = @import("../generated_rooms.zig");
const math = @import("math.zig");
const player_mod = @import("player.zig");
const prologue_bridge = @import("prologue_bridge.zig");
const prologue_granny_cutscene = @import("prologue_granny_cutscene.zig");
const room_wires = @import("room_wires.zig");
const tiny_birds = @import("tiny_birds.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerDeathCause = player_mod.DeathCause;

const fixedToPixel = math.fixedToPixel;
const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;

var foreground_anim_counter: u16 = 0;

pub fn load(room_index: usize, reset_cutscenes: bool) void {
    falling_blocks.load(room_index);
    foreground_stamps.load(room_index);
    funny_cars.load(room_index, gameplay_scene.funny_car_first_object);
    gameplay_scene.loadObjectSprites();
    prologue_bridge.load(room_index, isPrologueEndRoom(room_index));
    bird_npc.load(room_index);
    tiny_birds.load(room_index);
    room_wires.load(room_index, prologue_bridge.active());
    background.loadParallax(rooms[room_index]);
    if (reset_cutscenes) {
        prologue_granny_cutscene.resetOnRoomLoad();
    }
}

pub fn clearTransientEffects() void {
    dust.clear();
    dash_effects.clear();
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    return prologue_granny_cutscene.update(player, input, room_index);
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    prologue_granny_cutscene.updateEffects(room_index, camera);
}

pub fn updateDynamicHazards(player: *Player, room_index: usize) ?PlayerDeathCause {
    const result = falling_blocks.update(room_index, player);
    spawnFallingBlockSnowEvents(result);
    if (result.killed_player) return .normal;
    return null;
}

pub fn updateFallingBlocksDuringDeath(room_index: usize) void {
    const result = falling_blocks.updateDuringDeath(room_index);
    spawnFallingBlockSnowEvents(result);
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera) void {
    prologue_bridge.update(player, isPrologueEndRoom(room_index));
    prologue_bridge.updateCollapseShake(isPrologueEndRoom(room_index), player.grounded);
    funny_cars.update(player.*);
    bird_npc.update(player.*, camera);
    tiny_birds.update(player.*, room_index, foreground_anim_counter);
}

pub fn updatePlayerEffects(player: *Player) void {
    hair.update(player, prologue_bridge.endingHoldActive());
    dust.update();
    dash_effects.update();
}

pub fn updateEffects(room_index: usize, camera: Camera) void {
    gameplay_scene.updateWindSnow(room_index, camera, foreground_anim_counter);
    gameplay_scene.updateChimneySmoke(room_index, foreground_anim_counter);
    foreground_anim_counter +%= 1;
}

pub fn updateEndLevelEffects(room_index: usize, camera: Camera) void {
    gameplay_scene.updateWindSnow(room_index, camera, foreground_anim_counter);
    foreground_anim_counter +%= 1;
}

pub fn touchHazard(player: Player, room_index: usize) ?PlayerDeathCause {
    if (touchingSpike(player, room_index)) return .normal;
    if (inDeathPit(player, room_index)) return .fall_down;
    return null;
}

pub fn animCounter() u16 {
    return foreground_anim_counter;
}

fn spawnFallingBlockSnowEvents(result: falling_blocks.UpdateResult) void {
    var index: usize = 0;
    while (index < result.snow_count) : (index += 1) {
        dust.spawnSnowFromBlock(result.snow_blocks[index]);
    }
}

fn inDeathPit(player: Player, room_index: usize) bool {
    const room = rooms[room_index];
    if (room.down != null) return false;
    return fixedToPixel(player.y) > room.height_pixels + 8;
}

fn touchingSpike(player: Player, room_index: usize) bool {
    return collision.spikeRectAt(
        rooms[room_index],
        fixedToPixel(player.x),
        fixedToPixel(player.y),
        player_body_width,
        player_body_height,
    );
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}
