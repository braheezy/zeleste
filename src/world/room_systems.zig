const gba = @import("gba");
const background = @import("background.zig");
const camera_mod = @import("camera.zig");
const chapter_entities = @import("../chapters/entities.zig");
const chapter_systems = @import("../chapters/systems.zig");
const collision = @import("collision.zig");
const dash_effects = @import("../player/dash_effects.zig");
const dust = @import("../effects/dust.zig");
const foreground_stamps = @import("../room/foreground_stamps.zig");
const gameplay_scene = @import("../room/gameplay_scene.zig");
const hair = @import("../player/hair.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerDeathCause = player_mod.DeathCause;

const fixedToPixel = math.fixedToPixel;
const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;

var foreground_anim_counter: u16 = 0;

pub fn load(room_index: usize, reset_cutscenes: bool) void {
    chapter_entities.load(room_index);
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
    if (chapter_entities.updateDynamicHazards(player, room_index)) |death_cause| return death_cause;
    return chapter_systems.updateDynamicHazards(player, room_index);
}

pub fn updatePlayerEntities(player: *Player, room_index: usize) void {
    chapter_entities.updatePlayerEntities(player, room_index);
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    chapter_entities.handlePlayerDeathStart(room_index);
}

pub fn updateFallingBlocksDuringDeath(room_index: usize) void {
    chapter_systems.updateDynamicHazardsDuringDeath(room_index);
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
    if (touchingSpike(player, room_index)) |hit| return deathCauseForSpike(hit.direction);
    if (inDeathPit(player, room_index)) return .fall_down;
    return null;
}

pub fn animCounter() u16 {
    return foreground_anim_counter;
}

fn inDeathPit(player: Player, room_index: usize) bool {
    const room = rooms[room_index];
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_body_width;
    const player_bottom = player_top + player_body_height;
    for (room.death_lines) |line| {
        if (deathLineKillsPlayer(line, player_left, player_top, player_right, player_bottom)) return true;
    }
    if (room.down != null) return false;
    return player_top > room.height_pixels + 8;
}

fn deathLineKillsPlayer(line: room_data.DeathLine, player_left: i16, player_top: i16, player_right: i16, player_bottom: i16) bool {
    const left = @min(line.x1, line.x2);
    const right = @max(line.x1, line.x2) + 1;
    const top = @min(line.y1, line.y2);
    const bottom = @max(line.y1, line.y2) + 1;

    if (line.y1 == line.y2) {
        return rangesOverlap(player_left, player_right, left, right) and player_bottom >= line.y1;
    }
    return collision.rectsOverlap(player_left, player_top, player_right, player_bottom, left, top, right, bottom);
}

fn rangesOverlap(a_min: i16, a_max: i16, b_min: i16, b_max: i16) bool {
    return a_max > b_min and a_min < b_max;
}

fn touchingSpike(player: Player, room_index: usize) ?collision.SpikeHit {
    return collision.spikeHitAt(
        rooms[room_index],
        fixedToPixel(player.x),
        fixedToPixel(player.y),
        player_body_width,
        player_body_height,
        player.vx,
        player.vy,
    );
}

fn deathCauseForSpike(direction: collision.SpikeDirection) PlayerDeathCause {
    return switch (direction) {
        .up => .spike_up,
        .down => .spike_down,
        .left => .spike_left,
        .right => .spike_right,
    };
}
