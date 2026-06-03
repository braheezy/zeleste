const camera_mod = @import("../world/camera.zig");
const city = @import("city.zig");
const player_mod = @import("../player/state.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerDeathCause = player_mod.DeathCause;

pub const FloorSurface = city.entities.FloorSurface;

pub fn load(room_index: usize) void {
    if (!isCityRoom(room_index)) {
        city.entities.hideInactiveObjects();
        return;
    }

    city.entities.load(room_index);
}

pub fn loadObjectGraphics(room_index: usize) void {
    if (!isCityRoom(room_index)) return;

    city.entities.loadObjectGraphics();
}

pub fn updateDynamicHazards(player: *Player, room_index: usize) ?PlayerDeathCause {
    if (!isCityRoom(room_index)) return null;

    return city.entities.updateDynamicHazards(player, room_index);
}

pub fn updatePlayerEntities(player: *Player, room_index: usize) void {
    if (!isCityRoom(room_index)) return;

    city.entities.updatePlayerEntities(player, room_index);
}

pub fn handlePlayerDeathStart(room_index: usize) void {
    if (!isCityRoom(room_index)) return;

    city.entities.handlePlayerDeathStart();
}

pub fn dynamicSolidRectAt(room_index: usize, x: i16, y: i16, width: i16, height: i16) bool {
    if (!isCityRoom(room_index)) return false;

    return city.entities.dynamicSolidRectAt(x, y, width, height);
}

pub fn tryBreakDashCollision(player: *Player, room_index: usize) bool {
    if (!isCityRoom(room_index)) return false;

    return city.entities.tryBreakDashCollision(player, room_index);
}

pub fn floorSurfaceAtPlayer(room_index: usize, player: Player) ?FloorSurface {
    if (!isCityRoom(room_index)) return null;

    return city.entities.floorSurfaceAtPlayer(player);
}

pub fn drawDynamicSolids(camera: Camera, room_index: usize) void {
    if (!isCityRoom(room_index)) return;

    city.entities.drawDynamicSolids(camera);
}

pub fn drawPlayerEntities(camera: Camera, room_index: usize, anim_counter: u16) void {
    if (!isCityRoom(room_index)) return;

    city.entities.drawPlayerEntities(camera, anim_counter);
}

pub fn bgTileBroken(room_index: usize, x: i16, y: i16) bool {
    if (!isCityRoom(room_index)) return false;

    return city.entities.bgTileBroken(room_index, x, y);
}

pub fn isCityRoom(room_index: usize) bool {
    return city.flow.ownsGeneratedRoomIndex(room_index);
}
