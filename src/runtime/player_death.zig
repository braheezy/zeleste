const camera_mod = @import("camera.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("dust.zig");
const gameplay_scene = @import("gameplay_scene.zig");
const math = @import("math.zig");
const player_death_vfx = @import("player_death_vfx.zig");
const player_mod = @import("player.zig");
const prologue_granny_cutscene = @import("prologue_granny_cutscene.zig");
const video = @import("video.zig");

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

pub const death_frames = player_mod.death_anim_frames;
pub const respawn_burst_frames = player_mod.respawn_burst_frames;

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

pub fn begin(player: Player, camera: Camera, cause: Cause) void {
    prologue_granny_cutscene.handlePlayerDeathStart();
    origin_x = player.x + (player_body_width / 2) * fixed_one;
    origin_y = player.y + (player_body_height / 2) * fixed_one;
    player_x = player.x;
    player_y = player.y;
    player_facing_left = player.facing_left;
    intro_offset_x = 0;
    intro_offset_y = 0;
    if (cause == .fall_down) {
        intro_first_frame = 0;
        intro_frame_count = 0;
        intro_total_frames = 0;
    } else {
        const intro = selectIntro(player, cause);
        intro_first_frame = intro.first_frame;
        intro_frame_count = intro.frame_count;
        intro_total_frames = introTotalFrames(intro.frame_count);
        if (intro.frame_count != 0) {
            const offset = introScreenCenterOffset(player, camera);
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
    gameplay_scene.hidePlayerObjects();
}

pub fn drawDeath(camera: Camera, death_timer: u8) void {
    const elapsed: u8 = death_frames - death_timer;
    player_death_vfx.drawDeath(camera, elapsed, origin_x, origin_y, .{
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
    player_death_vfx.drawRespawn(camera, origin_x, origin_y, respawn_burst_timer);
}

pub fn hideObjects() void {
    player_death_vfx.hideObjects();
}

fn introScreenCenterOffset(player: Player, camera: Camera) struct { x: i16, y: i16 } {
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

fn selectIntro(player: Player, cause: Cause) Intro {
    if (cause == .fall_down and deadown_frame_count != 0) {
        return .{ .first_frame = deadown_first_frame, .frame_count = deadown_frame_count };
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

fn introTotalFrames(frame_count: u16) u8 {
    if (frame_count == 0) return 0;
    const total = frame_count * death_intro_frame_hold;
    return @intCast(@min(@as(u16, death_intro_max_frames), total));
}
