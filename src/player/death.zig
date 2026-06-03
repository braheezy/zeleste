const camera_mod = @import("../world/camera.zig");
const chapter_systems = @import("../chapters/systems.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("../effects/dust.zig");
const gameplay_scene = @import("../room/gameplay_scene.zig");
const math = @import("../core/math.zig");
const player_death_vfx = @import("death_vfx.zig");
const player_mod = @import("state.zig");
const player_sfx = @import("sfx.zig");
const video = @import("../core/video.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const Cause = player_mod.DeathCause;
const Intro = player_mod.DeathIntro;

const fixed_shift = math.fixed_shift;
const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const absI32 = math.absI32;
const absI16 = math.absI16;
const maxI16 = math.maxI16;

const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const deadown_first_frame = player_mod.deadown_first_frame;
const deadown_frame_count = player_mod.deadown_frame_count;
const deathside_first_frame = player_mod.deathside_first_frame;
const deathside_frame_count = player_mod.deathside_frame_count;
const deathup_first_frame = player_mod.deathup_first_frame;
const deathup_frame_count = player_mod.deathup_frame_count;
const death_intro_frame_hold = player_mod.death_intro_frame_hold;
const death_intro_max_frames = player_mod.death_intro_max_frames;
const death_intro_travel_pixels = player_mod.death_intro_travel_pixels;
const spike_death_intro_travel_pixels: i16 = 18;

pub const death_frames = player_mod.death_anim_frames;
pub const respawn_burst_frames = player_mod.respawn_burst_frames;

const IntroMotion = struct {
    x: i16,
    y: i16,
};

var origin_x: i32 = 0;
var origin_y: i32 = 0;
var player_x: i32 = 0;
var player_y: i32 = 0;
var player_facing_left: bool = false;
var intro_offset_x: i32 = 0;
var intro_offset_y: i32 = 0;
var intro_first_frame: u16 = 0;
var intro_frame_count: u16 = 0;
var intro_total_frames: u8 = 0;
var burst_palette: player_death_vfx.BurstPalette = .red;

pub fn begin(player: Player, camera: Camera, cause: Cause, room_index: usize) void {
    chapter_systems.handlePlayerDeathStart(room_index);
    player_sfx.playDeath();
    origin_x = player.x + (player_body_width / 2) * fixed_one;
    origin_y = player.y + (player_body_height / 2) * fixed_one;
    player_x = player.x;
    player_y = player.y;
    player_facing_left = player.facing_left;
    intro_offset_x = 0;
    intro_offset_y = 0;
    burst_palette = burstPaletteForPlayer(player);
    if (cause == .fall_down) {
        intro_first_frame = 0;
        intro_frame_count = 0;
        intro_total_frames = 0;
    } else {
        const preferred_motion = spikeIntroMotion(player, cause);
        const intro = selectIntro(player, cause, preferred_motion);
        intro_first_frame = intro.first_frame;
        intro_frame_count = intro.frame_count;
        intro_total_frames = introTotalFrames(intro.frame_count);
        if (intro.frame_count != 0) {
            const offset = if (preferred_motion) |motion| motion else introScreenCenterOffset(player, camera);
            intro_offset_x = @as(i32, offset.x) << fixed_shift;
            intro_offset_y = @as(i32, offset.y) << fixed_shift;
            origin_x += intro_offset_x;
            origin_y += intro_offset_y;
        }
    }
    gameplay_scene.hidePlayerObjects();
    dust.clear();
    dash_effects.clear();
}

pub fn startRespawnBurst(player: Player) void {
    origin_x = player.x + (player_body_width / 2) * fixed_one;
    origin_y = player.y + (player_body_height / 2) * fixed_one;
    burst_palette = burstPaletteForPlayer(player);
    gameplay_scene.hidePlayerObjects();
}

pub fn drawDeath(camera: Camera, death_timer: u8) void {
    const elapsed: u8 = death_frames - death_timer;
    player_death_vfx.drawDeath(camera, elapsed, origin_x, origin_y, burst_palette, .{
        .first_frame = intro_first_frame,
        .frame_count = intro_frame_count,
        .total_frames = intro_total_frames,
        .player_x = player_x,
        .player_y = player_y,
        .offset_x = intro_offset_x,
        .offset_y = intro_offset_y,
        .facing_left = player_facing_left,
    });
}

pub fn drawRespawn(camera: Camera, respawn_burst_timer: u8) void {
    player_death_vfx.drawRespawn(camera, origin_x, origin_y, respawn_burst_timer, burst_palette);
}

pub fn hideObjects() void {
    player_death_vfx.hideObjects();
}

fn introScreenCenterOffset(player: Player, camera: Camera) IntroMotion {
    const player_center_x = fixedToPixel(player.x) + player_body_width / 2 - camera.x;
    const player_center_y = fixedToPixel(player.y) + player_body_height / 2 - camera.y;
    const to_center_x: i16 = video.screen_width / 2 - player_center_x;
    const to_center_y: i16 = video.screen_height / 2 - player_center_y;
    const max_component = maxI16(absI16(to_center_x), absI16(to_center_y));
    if (max_component == 0) return .{ .x = 0, .y = -death_intro_travel_pixels };

    const travel = @min(max_component, death_intro_travel_pixels);
    return .{
        .x = @intCast(@divTrunc(@as(i32, to_center_x) * travel, max_component)),
        .y = @intCast(@divTrunc(@as(i32, to_center_y) * travel, max_component)),
    };
}

fn burstPaletteForPlayer(player: Player) player_death_vfx.BurstPalette {
    return if (player.dashes == 0) .blue else .red;
}

fn selectIntro(player: Player, cause: Cause, preferred_motion: ?IntroMotion) Intro {
    if (cause == .fall_down and deadown_frame_count != 0) {
        return .{ .first_frame = deadown_first_frame, .frame_count = deadown_frame_count };
    }
    if (selectSpikeIntro(cause, preferred_motion)) |intro| {
        return intro;
    }
    if (player.vy < -fixed_one and deathup_frame_count != 0) {
        return .{ .first_frame = deathup_first_frame, .frame_count = deathup_frame_count };
    }
    if (absI32(player.vx) > fixed_one and deathside_frame_count != 0) {
        player_facing_left = player.vx < 0;
        return .{ .first_frame = deathside_first_frame, .frame_count = deathside_frame_count };
    }
    if (deadown_frame_count != 0) {
        return .{ .first_frame = deadown_first_frame, .frame_count = deadown_frame_count };
    }
    if (deathside_frame_count != 0) {
        return .{ .first_frame = deathside_first_frame, .frame_count = deathside_frame_count };
    }
    if (deathup_frame_count != 0) {
        return .{ .first_frame = deathup_first_frame, .frame_count = deathup_frame_count };
    }
    return .{ .first_frame = 0, .frame_count = 0 };
}

fn selectSpikeIntro(cause: Cause, preferred_motion: ?IntroMotion) ?Intro {
    switch (cause) {
        .spike_up => {
            if (deathup_frame_count != 0) return .{ .first_frame = deathup_first_frame, .frame_count = deathup_frame_count };
        },
        .spike_down => {
            if (deadown_frame_count != 0) return .{ .first_frame = deadown_first_frame, .frame_count = deadown_frame_count };
        },
        .spike_left, .spike_right => {
            if (deathside_frame_count != 0) {
                player_facing_left = if (preferred_motion) |motion| motion.x < 0 else cause == .spike_left;
                return .{ .first_frame = deathside_first_frame, .frame_count = deathside_frame_count };
            }
        },
        else => return null,
    }

    if (preferred_motion) |motion| {
        if (motion.y < 0 and deathup_frame_count != 0) return .{ .first_frame = deathup_first_frame, .frame_count = deathup_frame_count };
        if (motion.y > 0 and deadown_frame_count != 0) return .{ .first_frame = deadown_first_frame, .frame_count = deadown_frame_count };
        if (motion.x != 0 and deathside_frame_count != 0) {
            player_facing_left = motion.x < 0;
            return .{ .first_frame = deathside_first_frame, .frame_count = deathside_frame_count };
        }
    }
    return null;
}

fn spikeIntroMotion(player: Player, cause: Cause) ?IntroMotion {
    const normal = spikeNormal(cause) orelse return null;
    var away_x = -player.vx;
    var away_y = -player.vy;
    if (away_x == 0 and away_y == 0) {
        away_x = @as(i32, normal.x) * fixed_one;
        away_y = @as(i32, normal.y) * fixed_one;
    }

    if (normal.x != 0) {
        const required = @max(@divTrunc(absI32(away_y), 2), fixed_one);
        if (away_x * @as(i32, normal.x) < required) {
            away_x = @as(i32, normal.x) * required;
        }
    }
    if (normal.y != 0) {
        const required = @max(@divTrunc(absI32(away_x), 2), fixed_one);
        if (away_y * @as(i32, normal.y) < required) {
            away_y = @as(i32, normal.y) * required;
        }
    }

    const max_component = @max(absI32(away_x), absI32(away_y));
    if (max_component == 0) {
        return .{
            .x = normal.x * spike_death_intro_travel_pixels,
            .y = normal.y * spike_death_intro_travel_pixels,
        };
    }

    return .{
        .x = @intCast(@divTrunc(away_x * spike_death_intro_travel_pixels, max_component)),
        .y = @intCast(@divTrunc(away_y * spike_death_intro_travel_pixels, max_component)),
    };
}

fn spikeNormal(cause: Cause) ?IntroMotion {
    return switch (cause) {
        .spike_up => .{ .x = 0, .y = -1 },
        .spike_down => .{ .x = 0, .y = 1 },
        .spike_left => .{ .x = -1, .y = 0 },
        .spike_right => .{ .x = 1, .y = 0 },
        else => null,
    };
}

fn introTotalFrames(frame_count: u16) u8 {
    if (frame_count == 0) return 0;
    const total = frame_count * death_intro_frame_hold;
    return @intCast(@min(@as(u16, death_intro_max_frames), total));
}
