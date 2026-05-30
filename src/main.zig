const gba = @import("gba");
const game = @import("game.zig");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);

pub const RoomBackground = game.RoomBackground;
pub const ParallaxLayer = game.ParallaxLayer;
pub const Spawn = game.Spawn;
pub const SceneRect = game.SceneRect;
pub const CutsceneAnimCue = game.CutsceneAnimCue;
pub const CutsceneDialoguePage = game.CutsceneDialoguePage;
pub const GrannyCutscene = game.GrannyCutscene;

pub fn spawnFromBytes(bytes: []align(4) const u8) Spawn {
    return game.spawnFromBytes(bytes);
}

pub fn spawnFromBytesAt(bytes: []align(4) const u8, offset: usize) Spawn {
    return game.spawnFromBytesAt(bytes, offset);
}

pub export fn main() void {
    game.run();
}
