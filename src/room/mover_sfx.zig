const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");

const sound_ids = assets.sound_ids;

pub fn fallingBlockShake() void {
    play(sound_ids.sfx_fallingblock_prologue_shake);
}

pub fn fallingBlockRelease() void {
    play(sound_ids.sfx_fallingblock_prologue_release);
}

pub fn fallingBlockImpact() void {
    play(sound_ids.sfx_fallingblock_prologue_impact);
}

pub fn zipmoverTouch() void {
    play(sound_ids.sfx_zipmover_a_touch_01_001);
}

pub fn zipmoverImpact() void {
    play(sound_ids.sfx_zipmover_b_impact_01_001);
}

pub fn zipmoverReturn() void {
    play(sound_ids.sfx_zipmover_c_return_01_001);
}

pub fn zipmoverReset() void {
    play(sound_ids.sfx_zipmover_d_reset_01_001);
}

fn play(sound_id: u16) void {
    _ = audio.playSoundEffect(sound_id);
}
