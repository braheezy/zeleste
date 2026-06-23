const camera_mod = @import("../../world/camera.zig");
const breakable_walls = @import("../../room/breakable_walls.zig");
const cassettes = @import("../../room/cassettes.zig");
const collision = @import("../../world/collision.zig");
const disappearing_platforms = @import("../../room/disappearing_platforms.zig");
const dust = @import("../../effects/dust.zig");
const falling_blocks = @import("../../room/falling_blocks.zig");
const golden_strawberry = @import("golden_strawberry.zig");
const mech_blocks = @import("../../room/mech_blocks.zig");
const player_mod = @import("../../player/state.zig");
const dash_refills = @import("../../room/dash_refills.zig");
const rhythm_blocks = @import("../../room/rhythm_blocks.zig");
const springs = @import("../../room/springs.zig");
const strawberries = @import("../../room/strawberries.zig");
const room_data = @import("../../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerDeathCause = player_mod.DeathCause;
const Spawn = room_data.Spawn;

pub const FloorSurface = enum {
    asphalt,
    dirt,
};

pub const BreakableWallImpact = breakable_walls.DashImpact;

pub fn load(room_index: usize) void {
    breakable_walls.load(room_index);
    falling_blocks.load(room_index);
    mech_blocks.load(room_index);
    rhythm_blocks.load(room_index);
    disappearing_platforms.load(room_index);
    springs.load(room_index);
    strawberries.load(room_index);
    golden_strawberry.load(room_index);
    cassettes.load(room_index);
    dash_refills.load(room_index);
}

pub fn hideInactiveObjects() void {
    breakable_walls.hideObjects();
    falling_blocks.hideObjects();
    mech_blocks.hideObjects();
    rhythm_blocks.hideObjects();
    disappearing_platforms.hideObjects();
    springs.hideObjects();
    strawberries.hideObjects();
    golden_strawberry.hideObjects();
    cassettes.hideObjects();
    dash_refills.hideObjects();
    strawberries.clearCarried();
}

pub fn loadObjectGraphics(room_index: usize) void {
    breakable_walls.loadGraphics();
    falling_blocks.loadGraphics(room_index);
    mech_blocks.loadGraphics();
    rhythm_blocks.loadGraphics();
    disappearing_platforms.loadGraphics();
    springs.loadGraphics();
    strawberries.loadGraphics();
    golden_strawberry.loadGraphics(room_index);
    cassettes.loadGraphics();
    dash_refills.loadGraphics();
}

pub fn invalidateObjectGraphics() void {
    strawberries.invalidateGraphics();
    golden_strawberry.invalidateGraphics();
    cassettes.invalidateGraphics();
}

pub fn resetPaletteState() void {
    cassettes.resetPaletteState();
}

pub fn updateCutscenes(player: *Player, room_index: usize) bool {
    return cassettes.updateCutscene(player, room_index);
}

pub fn updateDynamicHazards(player: *Player, room_index: usize) ?PlayerDeathCause {
    const falling_result = falling_blocks.update(room_index, player);
    spawnFallingBlockDust(falling_result);
    if (falling_result.killed_player) return .normal;

    const mech_result = mech_blocks.update(player, room_index);
    if (mech_result.killed_player) return .normal;
    if (rhythm_blocks.update(player)) return .normal;
    return null;
}

pub fn updatePlayerEntities(player: *Player, room_index: usize) void {
    disappearing_platforms.update(player.*);
    springs.update(player);
    strawberries.update(player, room_index);
    golden_strawberry.update(player, room_index);
    cassettes.update(player, room_index);
    dash_refills.update(player);
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    strawberries.clearCarried();
    golden_strawberry.handlePlayerDeathStart();
    cassettes.abortReturn(room_index);
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    strawberries.handleRoomTransition(from_room, to_room);
}

pub fn updateImpactEffects() void {
    breakable_walls.updateImpactShake();
}

pub fn cameraShakeOffset() ?Spawn {
    const breakable_shake = breakable_walls.impactShakeOffset();
    const refill_shake = dash_refills.cameraShakeOffset();
    if (breakable_shake == null and refill_shake == null) return null;

    var offset: Spawn = .{ .x = 0, .y = 0 };
    if (breakable_shake) |shake| {
        offset.x += shake.x;
        offset.y += shake.y;
    }
    if (refill_shake) |shake| {
        offset.x += shake.x;
        offset.y += shake.y;
    }
    return offset;
}

pub fn updateDynamicHazardsDuringDeath(room_index: usize) void {
    const result = falling_blocks.updateDuringDeath(room_index);
    spawnFallingBlockDust(result);
}

pub fn dynamicSolidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    if (breakable_walls.solidRectAt(x, y, width, height)) return true;
    if (falling_blocks.solidRectAt(x, y, width, height)) return true;
    if (mech_blocks.solidRectAt(x, y, width, height)) return true;
    if (rhythm_blocks.solidRectAt(x, y, width, height)) return true;
    if (disappearing_platforms.solidRectAt(x, y, width, height)) return true;
    return false;
}

pub fn dynamicSpikeHitAt(x: i16, y: i16, width: i16, height: i16, speed_x: i32, speed_y: i32) ?collision.SpikeHit {
    if (falling_blocks.spikeHitAt(x, y, width, height, speed_x, speed_y)) |hit| return hit;
    return mech_blocks.spikeHitAt(x, y, width, height, speed_x, speed_y);
}

pub fn tryBreakDashCollision(player: *Player, room_index: usize) ?BreakableWallImpact {
    return breakable_walls.tryBreakDashCollision(player, room_index);
}

pub fn floorSurfaceAtPlayer(player: Player) ?FloorSurface {
    if (falling_blocks.floorAtPlayer(player)) return .dirt;
    if (mech_blocks.floorAtPlayer(player)) return .asphalt;
    if (rhythm_blocks.floorAtPlayer(player)) return .asphalt;
    if (disappearing_platforms.floorAtPlayer(player)) return .dirt;
    return null;
}

pub fn drawDynamicSolids(camera: Camera) void {
    breakable_walls.draw(camera);
    falling_blocks.draw(camera);
    mech_blocks.draw(camera);
    rhythm_blocks.draw(camera);
    disappearing_platforms.draw(camera);
}

pub fn drawPlayerEntities(camera: Camera, anim_counter: u16) void {
    springs.draw(camera);
    strawberries.draw(camera, anim_counter);
    golden_strawberry.draw(camera, anim_counter);
    cassettes.draw(camera, anim_counter);
    dash_refills.draw(camera, anim_counter);
}

pub fn bgTileBroken(room_index: usize, x: i16, y: i16) bool {
    return breakable_walls.bgTileBroken(room_index, x, y);
}

fn spawnFallingBlockDust(result: falling_blocks.UpdateResult) void {
    var index: usize = 0;
    while (index < result.snow_count) : (index += 1) {
        const block = result.snow_blocks[index];
        dust.spawnSnowFromBlock(block.x, block.y, block.w);
    }
}
