const gba = @import("gba");
const mm = @import("maxmod");
const audio = @import("audio.zig");
const debug_fps = @import("debug_fps.zig");

pub fn sync() void {
    audio.keepMusicLooping();
    mm.gba.frame();
    waitVBlank();
    debug_fps.update();
}

pub fn syncFrontend() void {
    audio.keepMusicLooping();
    mm.gba.frame();
    waitVBlank();
}

fn waitVBlank() void {
    gba.display.naiveVSync();
}
