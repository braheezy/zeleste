const gba = @import("gba");
const mm = @import("maxmod");

const prologue_soundbank_data align(4) = @embedFile("../generated/assets/prologue_soundbank.bin").*;
const sfx_volume: u32 = 1024;

pub fn init() void {
    gba.interrupt.init();
    gba.interrupt.isr_default_redirect = audioVBlankHandler;
    mm.gba.initDefault(@ptrCast(@constCast(&prologue_soundbank_data[0])), 32) catch unreachable;
    mm.sfx.setEffectsVolume(sfx_volume);
}

fn audioVBlankHandler(_: gba.interrupt.InterruptFlags) callconv(.c) void {
    mm.mixer.vBlank();
}
