const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");
const footsteps = @import("footsteps.zig");
const math = @import("../core/math.zig");
const player_mod = @import("state.zig");

const Player = player_mod.State;
const Surface = footsteps.Surface;

const sound_ids = assets.sound_ids;
const absI32 = math.absI32;
const fixed_one = math.fixed_one;

const jump_volume: u16 = 176;
const wall_jump_volume: u16 = 176;
const dash_volume: u16 = 192;
const death_volume: u16 = 224;
const grab_volume: u16 = 136;
const land_volume: u16 = 160;
const climb_ledge_volume: u16 = 144;
const min_land_speed = fixed_one / 2;

const grab_dirt_sfx = [_]u16{
    sound_ids.sfx_grab_00_dirt_01,
    sound_ids.sfx_grab_00_dirt_02,
    sound_ids.sfx_grab_00_dirt_03,
    sound_ids.sfx_grab_00_dirt_04,
    sound_ids.sfx_grab_00_dirt_05,
};
const grab_snow_sfx = [_]u16{
    sound_ids.sfx_grab_00_snowsoft_01,
    sound_ids.sfx_grab_00_snowsoft_02,
    sound_ids.sfx_grab_00_snowsoft_03,
    sound_ids.sfx_grab_00_snowsoft_04,
    sound_ids.sfx_grab_00_snowsoft_05,
};
const land_asphalt_sfx = [_]u16{
    sound_ids.sfx_land_00_asphalt_01,
    sound_ids.sfx_land_00_asphalt_02,
    sound_ids.sfx_land_00_asphalt_03,
    sound_ids.sfx_land_00_asphalt_04,
    sound_ids.sfx_land_00_asphalt_05,
};
const land_dirt_sfx = [_]u16{
    sound_ids.sfx_land_00_dirt_01,
    sound_ids.sfx_land_00_dirt_02,
    sound_ids.sfx_land_00_dirt_03,
    sound_ids.sfx_land_00_dirt_04,
    sound_ids.sfx_land_00_dirt_05,
};
const land_snow_sfx = [_]u16{
    sound_ids.sfx_land_00_snowsoft_01,
    sound_ids.sfx_land_00_snowsoft_02,
    sound_ids.sfx_land_00_snowsoft_03,
    sound_ids.sfx_land_00_snowsoft_04,
    sound_ids.sfx_land_00_snowsoft_05,
};
const land_wood_sfx = [_]u16{
    sound_ids.sfx_land_00_woodwalk_01,
    sound_ids.sfx_land_00_woodwalk_02,
    sound_ids.sfx_land_00_woodwalk_03,
    sound_ids.sfx_land_00_woodwalk_04,
    sound_ids.sfx_land_00_woodwalk_05,
};
const climb_ledge_sfx = [_]u16{
    sound_ids.sfx_climb_ledge_01,
    sound_ids.sfx_climb_ledge_02,
    sound_ids.sfx_climb_ledge_03,
    sound_ids.sfx_climb_ledge_04,
    sound_ids.sfx_climb_ledge_05,
};

pub fn playJump() void {
    play(sound_ids.sfx_jump, jump_volume);
}

pub fn playWallJump(dir: i16) void {
    const sound_id = if (dir < 0) sound_ids.sfx_jump_wall_left else sound_ids.sfx_jump_wall_right;
    play(sound_id, wall_jump_volume);
}

pub fn playClimbJump(dir: i16) void {
    const sound_id = if (dir < 0) sound_ids.sfx_jump_wall_climblayer_left else sound_ids.sfx_jump_wall_climblayer_right;
    play(sound_id, wall_jump_volume);
}

pub fn playDash(player: Player) void {
    const sound_id = if (player.dash_dir_x < 0 or (player.dash_dir_x == 0 and player.facing_left))
        sound_ids.sfx_dash_red_left
    else
        sound_ids.sfx_dash_red_right;
    play(sound_id, dash_volume);
}

pub fn playDeath() void {
    play(sound_ids.sfx_death, death_volume);
}

pub fn playGrab(player: *Player, room_index: usize) void {
    const surface = footsteps.surfaceAtPlayerWall(player.*, room_index);
    const samples = switch (surface) {
        .snow => &grab_snow_sfx,
        else => &grab_dirt_sfx,
    };
    playVariant(player, samples, grab_volume);
}

pub fn playClimbLedge(player: *Player) void {
    playVariant(player, &climb_ledge_sfx, climb_ledge_volume);
}

pub fn playLand(player: *Player, room_index: usize, vertical_speed: i32) void {
    if (vertical_speed < min_land_speed) return;
    const samples = landSamplesFor(footsteps.surfaceAtPlayerFeet(player.*, room_index));
    playVariant(player, samples, land_volumeFor(vertical_speed));
}

fn landSamplesFor(surface: Surface) []const u16 {
    return switch (surface) {
        .snow => &land_snow_sfx,
        .wood => &land_wood_sfx,
        .car, .asphalt => &land_asphalt_sfx,
        .dirt => &land_dirt_sfx,
    };
}

fn land_volumeFor(vertical_speed: i32) u16 {
    const speed = absI32(vertical_speed);
    if (speed > fixed_one * 4) return land_volume + 32;
    if (speed > fixed_one * 2) return land_volume + 16;
    return land_volume;
}

fn playVariant(player: *Player, samples: []const u16, volume: u16) void {
    if (samples.len == 0) return;
    const index: usize = @intCast(player.sfx_variant % @as(u8, @intCast(samples.len)));
    player.sfx_variant +%= 1;
    play(samples[index], volume);
}

fn play(sound_id: u16, volume: u16) void {
    _ = audio.playSoundEffectAtVolume(sound_id, volume);
}
