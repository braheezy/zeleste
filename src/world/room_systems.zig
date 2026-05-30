const gba = @import("gba");
const background = @import("background.zig");
const camera_mod = @import("camera.zig");
const chapter_systems = @import("../chapters/systems.zig");
const collision = @import("collision.zig");
const dash_effects = @import("../player/dash_effects.zig");
const dust = @import("../effects/dust.zig");
const falling_blocks = @import("../room/falling_blocks.zig");
const foreground_stamps = @import("../room/foreground_stamps.zig");
const gameplay_scene = @import("../room/gameplay_scene.zig");
const hair = @import("../player/hair.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const player_mod = @import("../player/state.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerDeathCause = player_mod.DeathCause;

const fixedToPixel = math.fixedToPixel;
const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;

var foreground_anim_counter: u16 = 0;

pub fn load(room_index: usize, reset_cutscenes: bool) void {
    falling_blocks.load(room_index);
    foreground_stamps.load(room_index);
    chapter_systems.loadBeforeObjectSprites(room_index, gameplay_scene.scene_slots);
    gameplay_scene.loadObjectSprites(room_index);
    chapter_systems.loadAfterObjectSprites(room_index, reset_cutscenes);
    background.loadParallax(rooms[room_index]);
}

pub fn clearTransientEffects() void {
    dust.clear();
    dash_effects.clear();
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    return chapter_systems.updateCutscenes(player, input, room_index);
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    chapter_systems.updateCutsceneEffects(room_index, camera);
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
    chapter_systems.updateActors(player, room_index, camera, foreground_anim_counter);
}

pub fn updatePlayerEffects(player: *Player, room_index: usize) void {
    hair.update(player, chapter_systems.endingHairOverrideActive(room_index));
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
