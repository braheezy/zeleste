const gba = @import("gba");
const mm = @import("maxmod");

const assets = @import("assets.zig");
const sound_ids = assets.sound_ids;

pub const SoundEffectHandle = mm.Sfxhand;

const prologue_soundbank_data align(4) = @embedFile("../generated/assets/prologue_soundbank.bin").*;
const background_music_enabled = true;
const audio_channel_count: mm.Word = 32;
const audio_mix_mode_13khz = 2;
const audio_mix_mode = audio_mix_mode_13khz;
pub const volume_step_count: u8 = 10;
const max_volume: mm.Word = 1024;
const sfx_volume_numerator: mm.Word = 4;
const sfx_volume_denominator: mm.Word = 5;
const default_effect_volume: mm.Word = 255;
const tracked_sfx_count: usize = 16;
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

const TrackedSoundEffect = struct {
    handle: mm.Sfxhand = 0,
    sound_id: u16 = 0,
    volume: mm.Word = default_effect_volume,
};

var runtime = mm.gba.Runtime(.{
    .mixing_mode = @enumFromInt(audio_mix_mode),
    .module_channels = audio_channel_count,
    .mix_channels = audio_channel_count,
}){};

var current_music: u16 = no_music;
var prologue_music_mode: PrologueMusicMode = .none;
var music_volume_step: u8 = volume_step_count;
var sfx_volume_step: u8 = volume_step_count;
var tracked_sfx: [tracked_sfx_count]TrackedSoundEffect = [_]TrackedSoundEffect{.{}} ** tracked_sfx_count;

pub fn init() void {
    gba.interrupt.init();
    gba.interrupt.isr_default_redirect = audioVBlankHandler;
    runtime.init(&prologue_soundbank_data) catch unreachable;
    current_music = no_music;
    prologue_music_mode = .none;
    music_volume_step = volume_step_count;
    sfx_volume_step = volume_step_count;
    clearTrackedSoundEffects();
    applyMusicVolume();
    applySfxVolume();
}

pub fn setMusicVolumeStep(step: u8) void {
    music_volume_step = clampVolumeStep(step);
    applyMusicVolume();
}

pub fn setSfxVolumeStep(step: u8) void {
    sfx_volume_step = clampVolumeStep(step);
    applySfxVolume();
}

pub fn musicVolumeStep() u8 {
    return music_volume_step;
}

pub fn sfxVolumeStep() u8 {
    return sfx_volume_step;
}

pub fn activeSoundEffectCount() usize {
    pruneTrackedSoundEffects();
    var count: usize = 0;
    for (tracked_sfx) |tracked| {
        if (tracked.handle != 0) count += 1;
    }
    return count;
}

pub fn activeSoundEffectId(index: usize) ?u16 {
    pruneTrackedSoundEffects();
    var active_index: usize = 0;
    for (tracked_sfx) |tracked| {
        if (tracked.handle == 0) continue;
        if (active_index == index) return tracked.sound_id;
        active_index += 1;
    }
    return null;
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

pub fn playCityCassetteMusic() void {
    playMusic(sound_ids.mod_02_first_steps_8bit);
}

pub fn stopMusic() void {
    current_music = no_music;
    prologue_music_mode = .none;
    mm.mas.mmStop();
}

pub fn stopSoundEffects() void {
    mm.sfx.effectCancelAll();
    clearTrackedSoundEffects();
}

pub fn playSoundEffect(sound_id: u16) mm.Sfxhand {
    if (sfx_volume_step == 0) return 0;
    if (!hasFreeEffectChannel()) return 0;
    return playTrackedSoundEffect(sound_id);
}

pub fn playSoundEffectAtVolume(sound_id: u16, volume: u16) mm.Sfxhand {
    if (sfx_volume_step == 0) return 0;
    if (!hasFreeEffectChannel()) return 0;
    return playTrackedSoundEffectAtVolume(sound_id, volume);
}

pub fn playImportantSoundEffect(sound_id: u16) mm.Sfxhand {
    if (sfx_volume_step == 0) return 0;
    return playTrackedSoundEffect(sound_id);
}

pub fn playImportantSoundEffectAtVolume(sound_id: u16, volume: u16) mm.Sfxhand {
    if (sfx_volume_step == 0) return 0;
    return playTrackedSoundEffectAtVolume(sound_id, volume);
}

pub fn setSoundEffectVolume(handle: mm.Sfxhand, volume: u16) void {
    rememberTrackedSoundEffectVolume(handle, volume);
    mm.sfx.effectVolume(handle, volume);
}

pub fn cancelSoundEffect(handle: mm.Sfxhand) mm.Word {
    const result = mm.sfx.effectCancel(handle);
    if (result != 0) forgetTrackedSoundEffect(handle);
    return result;
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
    if (was_playing and prologue_music_mode == mode) return;
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
    applyMusicVolume();
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

fn playTrackedSoundEffect(sound_id: u16) mm.Sfxhand {
    return playTrackedSoundEffectAtVolume(sound_id, default_effect_volume);
}

fn playTrackedSoundEffectAtVolume(sound_id: u16, volume: mm.Word) mm.Sfxhand {
    const handle = mm.sfx.playAtVolume(sound_id, volume);
    if (handle != 0) trackSoundEffect(handle, sound_id, volume);
    return handle;
}

fn trackSoundEffect(handle: mm.Sfxhand, sound_id: u16, volume: mm.Word) void {
    if (trackedSoundEffectSlot(handle)) |slot| {
        tracked_sfx[slot] = .{
            .handle = handle,
            .sound_id = sound_id,
            .volume = volume,
        };
    }
}

fn rememberTrackedSoundEffectVolume(handle: mm.Sfxhand, volume: mm.Word) void {
    if (trackedSoundEffectSlot(handle)) |slot| {
        if (tracked_sfx[slot].handle == handle) {
            tracked_sfx[slot].volume = volume;
        }
    }
}

fn forgetTrackedSoundEffect(handle: mm.Sfxhand) void {
    if (trackedSoundEffectSlot(handle)) |slot| {
        if (tracked_sfx[slot].handle == handle) tracked_sfx[slot] = .{};
    }
}

fn pruneTrackedSoundEffects() void {
    for (&tracked_sfx) |*tracked| {
        if (tracked.handle != 0 and !mm.sfx.effectActive(tracked.handle)) {
            tracked.* = .{};
        }
    }
}

fn clearTrackedSoundEffects() void {
    tracked_sfx = [_]TrackedSoundEffect{.{}} ** tracked_sfx_count;
}

fn trackedSoundEffectSlot(handle: mm.Sfxhand) ?usize {
    const channel = handle & 0xff;
    if (channel == 0) return null;
    const slot: usize = @intCast(channel - 1);
    if (slot >= tracked_sfx.len) return null;
    return slot;
}

fn applyMusicVolume() void {
    const volume = volumeForStep(music_volume_step);
    mm.mas.mmSetModuleVolume(volume);
    mm.mas.mmSetJingleVolume(volume);
}

fn applySfxVolume() void {
    mm.sfx.setEffectsVolume(sfxVolumeForStep(sfx_volume_step));
    applyTrackedSoundEffectVolumes();
}

fn applyTrackedSoundEffectVolumes() void {
    pruneTrackedSoundEffects();
    for (tracked_sfx) |tracked| {
        if (tracked.handle != 0) {
            mm.sfx.effectVolume(tracked.handle, tracked.volume);
        }
    }
}

fn volumeForStep(step: u8) mm.Word {
    return (@as(mm.Word, clampVolumeStep(step)) * max_volume) / @as(mm.Word, volume_step_count);
}

fn sfxVolumeForStep(step: u8) mm.Word {
    return (volumeForStep(step) * sfx_volume_numerator) / sfx_volume_denominator;
}

fn clampVolumeStep(step: u8) u8 {
    return if (step > volume_step_count) volume_step_count else step;
}
