const gba = @import("gba");
const runtime = @import("runtime.zig");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);

pub const RoomBackground = runtime.RoomBackground;
pub const ParallaxLayer = runtime.ParallaxLayer;
pub const Spawn = runtime.Spawn;
pub const SceneRect = runtime.SceneRect;
pub const CutsceneAnimCue = runtime.CutsceneAnimCue;
pub const CutsceneDialoguePage = runtime.CutsceneDialoguePage;
pub const GrannyCutscene = runtime.GrannyCutscene;

pub fn spawnFromBytes(bytes: []align(4) const u8) Spawn {
    return runtime.spawnFromBytes(bytes);
}

pub fn spawnFromBytesAt(bytes: []align(4) const u8, offset: usize) Spawn {
    return runtime.spawnFromBytesAt(bytes, offset);
}

pub export fn main() void {
    runtime.run();
}
