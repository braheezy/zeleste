const gba = @import("gba");
const mm = @import("maxmod");

const assets = @import("assets.zig");
const sound_ids = assets.sound_ids;

const prologue_soundbank_data align(4) = @embedFile("../generated/assets/prologue_soundbank.bin").*;
const background_music_enabled = false;
const sfx_volume: u32 = 1024;
const no_music: u16 = 0xffff;

var current_music: u16 = no_music;

pub fn init() void {
    gba.interrupt.init();
    gba.interrupt.isr_default_redirect = audioVBlankHandler;
    mm.gba.initDefault(@ptrCast(@constCast(&prologue_soundbank_data[0])), 32) catch unreachable;
    mm.sfx.setEffectsVolume(sfx_volume);
    current_music = no_music;
}

pub fn playPrologueMusic() void {
    playMusic(sound_ids.mod_01_prologue);
}

pub fn playCityMusic() void {
    playMusic(sound_ids.mod_02_first_steps);
}

pub fn stopMusic() void {
    current_music = no_music;
    mm.mas.mmStop();
}

pub fn playSoundEffect(sound_id: u16) mm.Sfxhand {
    if (!hasFreeEffectChannel()) return 0;
    return mm.sfx.effect(sound_id);
}

pub fn setSoundEffectVolume(handle: mm.Sfxhand, volume: u16) void {
    mm.sfx.effectVolume(handle, volume);
}

pub fn cancelSoundEffect(handle: mm.Sfxhand) mm.Word {
    return mm.sfx.effectCancel(handle);
}

pub fn keepMusicLooping() void {
    if (current_music == no_music) return;
    if (mm.mas.mmActive() != 0) return;
    startLooping(current_music);
}

fn audioVBlankHandler(_: gba.interrupt.InterruptFlags) callconv(.c) void {
    mm.mixer.vBlank();
}

fn playMusic(module_id: u16) void {
    if (!background_music_enabled) {
        current_music = no_music;
        mm.mas.mmStop();
        return;
    }
    if (current_music == module_id) return;
    current_music = module_id;
    startLooping(module_id);
}

fn startLooping(module_id: u16) void {
    mm.mas.mmStart(module_id, @intCast(mm.mas.MM_PLAY_LOOP));
}

fn hasFreeEffectChannel() bool {
    if (current_music == no_music or mm.mas.mmActive() == 0) return true;

    // Maxmod steals the quietest music channel when no effect channel is free.
    // Skip non-critical SFX instead so movement cannot corrupt the module.
    var channel: mm.Word = 0;
    while (channel < mm.gba.num_ach) : (channel += 1) {
        if (mm.gba.achannels[channel]._type == mm.mas.ACHN_DISABLED) return true;
    }
    return false;
}
