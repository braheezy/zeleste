const camera_mod = @import("../../world/camera.zig");
const breakable_walls = @import("../../room/breakable_walls.zig");
const disappearing_platforms = @import("../../room/disappearing_platforms.zig");
const dust = @import("../../effects/dust.zig");
const falling_blocks = @import("../../room/falling_blocks.zig");
const mech_blocks = @import("../../room/mech_blocks.zig");
const player_mod = @import("../../player/state.zig");
const rhythm_blocks = @import("../../room/rhythm_blocks.zig");
const springs = @import("../../room/springs.zig");
const strawberries = @import("../../room/strawberries.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerDeathCause = player_mod.DeathCause;

pub const FloorSurface = enum {
    asphalt,
    dirt,
};

pub fn load(room_index: usize) void {
    breakable_walls.load(room_index);
    falling_blocks.load(room_index);
    mech_blocks.load(room_index);
    rhythm_blocks.load(room_index);
    disappearing_platforms.load(room_index);
    springs.load(room_index);
    strawberries.load(room_index);
}

pub fn hideInactiveObjects() void {
    falling_blocks.hideObjects();
    mech_blocks.hideObjects();
    rhythm_blocks.hideObjects();
    disappearing_platforms.hideObjects();
    springs.hideObjects();
    strawberries.hideObjects();
    strawberries.clearCarried();
}

pub fn loadObjectGraphics() void {
    falling_blocks.loadGraphics();
    mech_blocks.loadGraphics();
    rhythm_blocks.loadGraphics();
    disappearing_platforms.loadGraphics();
    strawberries.loadGraphics();
}

pub fn updateDynamicHazards(player: *Player, room_index: usize) ?PlayerDeathCause {
    const falling_result = falling_blocks.update(room_index, player);
    spawnFallingBlockDust(falling_result);
    if (falling_result.killed_player) return .normal;

    const mech_result = mech_blocks.update(player, room_index);
    if (mech_result.killed_player) return .normal;
    rhythm_blocks.update(player);
    return null;
}

pub fn updatePlayerEntities(player: *Player, room_index: usize) void {
    disappearing_platforms.update(player.*);
    springs.update(player);
    strawberries.update(player, room_index);
}

pub fn handlePlayerDeathStart() void {
    strawberries.clearCarried();
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

pub fn tryBreakDashCollision(player: *Player, room_index: usize) bool {
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
    falling_blocks.draw(camera);
    mech_blocks.draw(camera);
    rhythm_blocks.draw(camera);
    disappearing_platforms.draw(camera);
}

pub fn drawPlayerEntities(camera: Camera, anim_counter: u16) void {
    springs.draw(camera);
    strawberries.draw(camera, anim_counter);
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
