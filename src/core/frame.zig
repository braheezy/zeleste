const gba = @import("gba");
const mm = @import("maxmod");
const debug_fps = @import("debug_fps.zig");

pub fn sync() void {
    mm.gba.frame();
    gba.bios.vblankIntrWait();
    debug_fps.update();
}
