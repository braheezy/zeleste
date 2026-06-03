const gba = @import("gba");
const mm = @import("maxmod");

const assets = @import("assets.zig");
const sound_ids = assets.sound_ids;

const prologue_soundbank_data align(4) = @embedFile("../generated/assets/prologue_soundbank.bin").*;
const background_music_enabled = true;
const audio_channel_count: mm.Word = 32;
const audio_mix_mode_13khz = 2;
const wave_memory_len_13khz = 896;
const audio_mix_mode = audio_mix_mode_13khz;
const wave_memory_len = wave_memory_len_13khz;
const sfx_volume: u32 = 1024;
const no_music: u16 = 0xffff;
const prologue_bridge_order: mm.Word = 4;
const prologue_bridge_row: mm.Word = 36;
const prologue_calm_last_order: mm.Word = prologue_bridge_order - 1;
const prologue_calm_last_row: mm.Word = 63;
const prologue_calm_last_tick: mm.Word = 5;

const PrologueMusicMode = enum(u8) {
    none,
    calm,
    bridge,
};

var module_channels: [audio_channel_count]mm.ModuleChannel align(4) = [_]mm.ModuleChannel{.{}} ** audio_channel_count;
var active_channels: [audio_channel_count]mm.ActiveChannel align(4) = [_]mm.ActiveChannel{.{}} ** audio_channel_count;
var mixing_channels: [audio_channel_count]mm.MixerChannel align(4) = [_]mm.MixerChannel{.{}} ** audio_channel_count;
var mixing_memory: [wave_memory_len / @sizeOf(u32)]u32 align(4) = [_]u32{0} ** (wave_memory_len / @sizeOf(u32));
var wave_memory: [wave_memory_len]u8 align(4) = [_]u8{0} ** wave_memory_len;

var current_music: u16 = no_music;
var prologue_music_mode: PrologueMusicMode = .none;

pub fn init() void {
    gba.interrupt.init();
    gba.interrupt.isr_default_redirect = audioVBlankHandler;
    var setup = mm.gba.GBASystem{
        // Maxmod MixMode enum: 0=8k, 1=10k, 2=13k, 3=16k.
        // Keep wave_memory_len matched to this mode's MixLen.
        .mixing_mode = @enumFromInt(audio_mix_mode),
        .mod_channel_count = audio_channel_count,
        .mix_channel_count = audio_channel_count,
        .module_channels = @ptrCast(&module_channels[0]),
        .active_channels = @ptrCast(&active_channels[0]),
        .mixing_channels = @ptrCast(&mixing_channels[0]),
        .mixing_memory = @ptrCast(&mixing_memory[0]),
        .wave_memory = @ptrCast(&wave_memory[0]),
        .soundbank = @ptrCast(@constCast(&prologue_soundbank_data[0])),
    };
    if (!mm.gba.init(&setup)) unreachable;
    mm.sfx.setEffectsVolume(sfx_volume);
    current_music = no_music;
    prologue_music_mode = .none;
}

pub fn playPrologueMusic() void {
    playPrologue(.calm);
}

pub fn playPrologueBridgeMusic() void {
    playPrologue(.bridge);
}

pub fn playCityMusic() void {
    playMusic(sound_ids.mod_02_first_steps);
}

pub fn stopMusic() void {
    current_music = no_music;
    prologue_music_mode = .none;
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
    if (mm.mas.mmActive() == 0) {
        startLooping(current_music);
        if (current_music == sound_ids.mod_01_prologue and prologue_music_mode == .bridge) {
            setPrologueBridgePosition();
        }
    }
    keepPrologueSectionLooping();
}

fn audioVBlankHandler(_: gba.interrupt.InterruptFlags) callconv(.c) void {
    mm.mixer.vBlank();
}

fn playMusic(module_id: u16) void {
    if (!background_music_enabled) {
        current_music = no_music;
        prologue_music_mode = .none;
        mm.mas.mmStop();
        return;
    }
    if (module_id != sound_ids.mod_01_prologue) {
        prologue_music_mode = .none;
    }
    if (current_music == module_id) return;
    current_music = module_id;
    startLooping(module_id);
}

fn playPrologue(mode: PrologueMusicMode) void {
    if (!background_music_enabled) {
        current_music = no_music;
        prologue_music_mode = .none;
        mm.mas.mmStop();
        return;
    }

    const module_id = sound_ids.mod_01_prologue;
    const was_playing = current_music == module_id and mm.mas.mmActive() != 0;
    if (!was_playing) {
        current_music = module_id;
        startLooping(module_id);
    }

    prologue_music_mode = mode;
    switch (mode) {
        .calm => {
            if (was_playing and mm.mas.mmGetPosition() >= prologue_bridge_order) {
                mm.mas.mmSetPosition(0);
            }
        },
        .bridge => setPrologueBridgePosition(),
        .none => {},
    }
}

fn startLooping(module_id: u16) void {
    mm.mas.mmStart(module_id, @intCast(mm.mas.MM_PLAY_LOOP));
}

fn keepPrologueSectionLooping() void {
    if (current_music != sound_ids.mod_01_prologue or prologue_music_mode != .calm) return;

    const position = mm.mas.mmGetPosition();
    if (position > prologue_calm_last_order or
        (position == prologue_calm_last_order and
            mm.mas.mmGetPositionRow() >= prologue_calm_last_row and
            mm.mas.mmGetPositionTick() >= prologue_calm_last_tick))
    {
        mm.mas.mmSetPosition(0);
    }
}

fn setPrologueBridgePosition() void {
    mm.mas.mmSetPosition(prologue_bridge_order);
    mm.mas.mpph_FastForward(&mm.gba.layer_main, prologue_bridge_row);
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
