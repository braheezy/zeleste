const gba = @import("gba");
const game = @import("game.zig");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);
export var save_type_sram linksection(".data") = [_:0]u8{ 'S', 'R', 'A', 'M', '_', 'V', '1', '1', '3' };

pub const RoomBackground = game.RoomBackground;
pub const ParallaxLayer = game.ParallaxLayer;
pub const Spawn = game.Spawn;
pub const SceneRect = game.SceneRect;
pub const ExitDirection = game.ExitDirection;
pub const ExitLine = game.ExitLine;
pub const DeathLine = game.DeathLine;
pub const CutsceneAnimCue = game.CutsceneAnimCue;
pub const DialoguePortrait = game.DialoguePortrait;
pub const CutsceneDialoguePage = game.CutsceneDialoguePage;
pub const GrannyCutscene = game.GrannyCutscene;

pub fn spawnFromBytes(bytes: []align(4) const u8) Spawn {
    return game.spawnFromBytes(bytes);
}

pub fn spawnFromBytesAt(bytes: []align(4) const u8, offset: usize) Spawn {
    return game.spawnFromBytesAt(bytes, offset);
}

pub export fn main() void {
    keepSaveTypeMarker();
    game.run();
}

fn keepSaveTypeMarker() void {
    const marker: [*]volatile u8 = @ptrCast(&save_type_sram);
    _ = marker[0];
}
