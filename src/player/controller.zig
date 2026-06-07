const gba = @import("gba");
const chapter_entities = @import("../chapters/entities.zig");
const chapter_systems = @import("../chapters/systems.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("../effects/dust.zig");
const footsteps = @import("footsteps.zig");
const math = @import("../core/math.zig");
const player_collision = @import("collision.zig");
const player_mod = @import("state.zig");
const player_sfx = @import("sfx.zig");
const rng = @import("../core/rng.zig");

const Player = player_mod.State;
const PlayerAnimation = player_mod.Animation;
const fixed_one = math.fixed_one;
const pixelToFixed = math.pixelToFixed;
const fixedToPixel = math.fixedToPixel;
const fixedMul = math.fixedMul;
const approach = math.approach;
const absI32 = math.absI32;
const signI32 = math.signI32;
const nextRandom = rng.next;

const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const player_max_run = player_mod.max_run;
const player_run_accel = player_mod.run_accel;
const player_run_reduce = player_mod.run_reduce;
const player_air_mult = player_mod.air_mult;
const player_gravity = player_mod.gravity;
const player_max_fall = player_mod.max_fall;
const player_fast_max_fall = player_mod.fast_max_fall;
const player_half_grav_threshold = player_mod.half_grav_threshold;
const player_apex_hang_threshold = player_mod.apex_hang_threshold;
const player_jump_speed = player_mod.jump_speed;
const player_wall_jump_speed = player_mod.wall_jump_speed;
const player_wall_jump_h_speed = player_mod.wall_jump_h_speed;
const player_wall_jump_force_frames = player_mod.wall_jump_force_frames;
const player_dash_speed = player_mod.dash_speed;
const player_dash_end_speed = player_mod.dash_end_speed;
const player_dash_frames = player_mod.dash_frames;
const player_dash_cooldown_frames = player_mod.dash_cooldown_frames;
const player_dash_refill_cooldown_frames = player_mod.dash_refill_cooldown_frames;
const player_dash_effect_frames = player_mod.dash_effect_frames;
const player_dash_trail_interval = player_mod.dash_trail_interval;
const player_dash_diagonal_mult = player_mod.dash_diagonal_mult;
const player_dash_end_up_mult = player_mod.dash_end_up_mult;
const player_wall_slide_start_max = player_mod.wall_slide_start_max;
const player_wall_slide_frames = player_mod.wall_slide_frames;
const player_climb_max_stamina = player_mod.climb_max_stamina;
const player_climb_tired_stamina = player_mod.climb_tired_stamina;
const player_climb_up_speed = player_mod.climb_up_speed;
const player_climb_down_speed = player_mod.climb_down_speed;
const player_climb_slip_speed = player_mod.climb_slip_speed;
const player_climb_accel = player_mod.climb_accel;
const player_climb_grab_y_mult = player_mod.climb_grab_y_mult;
const player_climb_up_cost = player_mod.climb_up_cost;
const player_climb_still_cost = player_mod.climb_still_cost;
const player_climb_jump_cost = player_mod.climb_jump_cost;
const player_climb_jump_lockout_frames = player_mod.climb_jump_lockout_frames;
const player_var_jump_frames = player_mod.var_jump_frames;
const player_wall_jump_var_jump_frames = player_mod.wall_jump_var_jump_frames;
const player_coyote_frames = player_mod.coyote_frames;
const player_jump_buffer_frames = player_mod.jump_buffer_frames;
const player_animation_speed = player_mod.animation_speed;
const player_idle_a_first_frame = player_mod.idle_a_first_frame;
const player_idle_a_frame_count = player_mod.idle_a_frame_count;
const player_idle_b_first_frame = player_mod.idle_b_first_frame;
const player_idle_b_frame_count = player_mod.idle_b_frame_count;
const player_idle_c_first_frame = player_mod.idle_c_first_frame;
const player_idle_c_frame_count = player_mod.idle_c_frame_count;
const player_run_first_frame = player_mod.run_first_frame;
const player_run_frame_count = player_mod.run_frame_count;
const player_jump_first_frame = player_mod.jump_first_frame;
const player_jump_frame_count = player_mod.jump_frame_count;
const player_fall_first_frame = player_mod.fall_first_frame;
const player_fall_frame_count = player_mod.fall_frame_count;
const player_wallslide_first_frame = player_mod.wallslide_first_frame;
const player_climbup_first_frame = player_mod.climbup_first_frame;
const player_climbup_frame_count = player_mod.climbup_frame_count;
const player_dangling_first_frame = player_mod.dangling_first_frame;
const player_dangling_frame_count = player_mod.dangling_frame_count;
const player_climb_pull_first_frame = player_mod.climb_pull_first_frame;
const player_climb_pull_frame_count = player_mod.climb_pull_frame_count;
const landing_dust_min_speed = fixed_one / 2;
const landing_dust_air_frame_threshold: u8 = 4;
const breakable_wall_recoil_speed: i32 = 0x180;
const climb_check_dist: i16 = 2;
const climb_up_check_dist: i16 = 2;
const climb_hop_x_speed: i32 = 0x12C;
const climb_hop_y_speed: i32 = -0x15E;
const climb_hop_force_frames: u8 = 7;
const climb_hop_grab_lockout_frames: u8 = 10;
const climb_ledge_pull_frames: u8 = 6;

const LedgeTarget = struct {
    x: i16,
    y: i16,
};

pub fn update(player: *Player, input: gba.input.BufferedKeysState, room_index: usize, dash_unlocked: bool) void {
    const was_grounded = player.grounded;
    const landing_dust_air_frames = player.landing_dust_air_frames;
    const horizontal: i16 = @intCast(input.getAxisHorizontal());
    const vertical: i16 = @intCast(input.getAxisVertical());
    const grab_held = input.isPressed(.L) or input.isPressed(.R);
    const dash_pressed = input.isJustPressed(.B);
    if (player.room_transition_cooldown > 0) {
        player.room_transition_cooldown -= 1;
    }
    if (player.dash_cooldown_timer > 0) {
        player.dash_cooldown_timer -= 1;
    }
    if (player.dash_refill_cooldown_timer > 0) {
        player.dash_refill_cooldown_timer -= 1;
    }
    if (player.dash_effect_timer > 0) {
        player.dash_effect_timer -= 1;
    }
    if (player.dash_trail_timer > 0) {
        player.dash_trail_timer -= 1;
    }
    if (player.climb_grab_lockout_timer > 0) {
        player.climb_grab_lockout_timer -= 1;
    }
    if (player.wall_dust_timer > 0) {
        player.wall_dust_timer -= 1;
    }
    if (player.force_move_x_timer > 0) {
        player.force_move_x_timer -= 1;
    }
    if (player.apex_hang_disabled_timer > 0) {
        player.apex_hang_disabled_timer -= 1;
    }
    if (player.dust_suppress_timer > 0) {
        player.dust_suppress_timer -= 1;
    }
    if (player.lift_boost_timer > 0) {
        player.lift_boost_timer -= 1;
        if (player.lift_boost_timer == 0) {
            player.lift_boost_x = 0;
            player.lift_boost_y = 0;
        }
    }

    if (player.climb_ledge_timer > 0) {
        updateClimbLedgePull(player, room_index);
        updateAnimation(player);
        updateLandingDustAirFrames(player);
        return;
    }

    if (player.grounded and player.dash_timer == 0 and player.dash_refill_cooldown_timer == 0) {
        refillPlayerDash(player);
    }

    if (player.dash_timer > 0) {
        updateDashMovement(player, room_index);
        return;
    }

    if (dash_pressed and tryStartDash(player, horizontal, vertical, dash_unlocked)) {
        updateDashMovement(player, room_index);
        return;
    }

    player.moving = horizontal != 0;
    if (horizontal != 0 and !player.climbing and !player.climb_dangling) {
        player.facing_left = horizontal < 0;
    }

    const jump_pressed = input.isJustPressed(.A);
    const jump_held = input.isPressed(.A);

    if (jump_pressed) {
        player.jump_buffer_timer = player_jump_buffer_frames;
    } else if (player.jump_buffer_timer > 0) {
        player.jump_buffer_timer -= 1;
    }

    if (player.grounded) {
        player.coyote_timer = player_coyote_frames;
        player.stamina = player_climb_max_stamina;
    } else if (player.coyote_timer > 0) {
        player.coyote_timer -= 1;
    }

    const effective_horizontal: i16 = if (player.force_move_x_timer > 0) player.force_move_x else horizontal;
    updateHorizontalSpeed(player, effective_horizontal);

    const climb_wall_dir = climbWallDirection(player.*, room_index);
    const climb_jump_wall_dir: i16 = if (player.climbing and player.climb_dir != 0)
        player.climb_dir
    else if (climb_wall_dir != 0)
        climb_wall_dir
    else
        0;
    const active_climb_wall_dir: i16 = if (climb_jump_wall_dir != 0) climb_jump_wall_dir else climbFacingDir(player.*);
    const can_climb_jump = player.jump_buffer_timer > 0 and !player.grounded and
        (player.climbing or (!player.grounded and grab_held and player.climb_grab_lockout_timer == 0 and player.stamina > 0 and climb_jump_wall_dir != 0));
    const wall_jump_dir = player_collision.wallJumpDirection(player.*, horizontal, room_index);
    var jumped_this_frame = false;

    if (can_climb_jump) {
        const jump_away_from_wall = horizontal == -active_climb_wall_dir or player.stamina <= 0;
        if (jump_away_from_wall) {
            const jump_dir = -active_climb_wall_dir;
            dust.spawnJumpAtFeet(player.*);
            player_sfx.playWallJump(active_climb_wall_dir);
            player.vx = @as(i32, jump_dir) * player_wall_jump_h_speed;
            player.vy = player_wall_jump_speed;
            applyLiftBoostToJump(player);
            player.force_move_x = jump_dir;
            player.force_move_x_timer = player_wall_jump_force_frames;
            player.apex_hang_disabled_timer = player_var_jump_frames + 8;
            player.var_jump_speed = player.vy;
            player.var_jump_timer = player_wall_jump_var_jump_frames;
            player.jump_buffer_timer = 0;
            player.coyote_timer = 0;
            player.grounded = false;
            player.facing_left = jump_dir < 0;
            player.climb_grab_lockout_timer = player_climb_jump_lockout_frames;
            player.climbing = false;
            player.climb_dangling = false;
            player.climb_dir = 0;
            jumped_this_frame = true;
        } else {
            dust.spawnJumpAtFeet(player.*);
            player_sfx.playClimbJump(active_climb_wall_dir);
            player.stamina = @max(0, player.stamina - player_climb_jump_cost);
            player.vx = 0;
            player.vy = player_jump_speed;
            applyLiftBoostToJump(player);
            player.force_move_x_timer = 0;
            player.var_jump_speed = player.vy;
            player.var_jump_timer = player_var_jump_frames;
            player.jump_buffer_timer = 0;
            player.coyote_timer = 0;
            player.grounded = false;
            player.facing_left = active_climb_wall_dir < 0;
            player.climb_grab_lockout_timer = player_climb_jump_lockout_frames;
            player.climbing = false;
            player.climb_dangling = false;
            player.climb_dir = 0;
            jumped_this_frame = true;
        }
    } else if (player.jump_buffer_timer > 0 and player.coyote_timer > 0) {
        if (player.grounded) {
            chapter_systems.releaseActorAtPlayer(room_index, player.*);
        }
        dust.spawnJumpAtFeet(player.*);
        player_sfx.playJump();
        player.vy = player_jump_speed;
        applyLiftBoostToJump(player);
        player.var_jump_speed = player.vy;
        player.var_jump_timer = player_var_jump_frames;
        player.jump_buffer_timer = 0;
        player.coyote_timer = 0;
        player.grounded = false;
        jumped_this_frame = true;
        if (player.climbing) {
            player.climb_grab_lockout_timer = player_climb_jump_lockout_frames;
            player.climbing = false;
            player.climb_dangling = false;
            player.climb_dir = 0;
        }
    } else if (player.jump_buffer_timer > 0 and wall_jump_dir != 0) {
        dust.spawnJumpAtFeet(player.*);
        player_sfx.playWallJump(-wall_jump_dir);
        player.vx = @as(i32, wall_jump_dir) * player_wall_jump_h_speed;
        player.vy = player_wall_jump_speed;
        applyLiftBoostToJump(player);
        player.force_move_x = wall_jump_dir;
        player.force_move_x_timer = player_wall_jump_force_frames;
        player.apex_hang_disabled_timer = player_var_jump_frames + 8;
        player.var_jump_speed = player.vy;
        player.var_jump_timer = player_wall_jump_var_jump_frames;
        player.jump_buffer_timer = 0;
        player.coyote_timer = 0;
        player.grounded = false;
        player.facing_left = wall_jump_dir < 0;
        player.climb_grab_lockout_timer = player_climb_jump_lockout_frames;
        player.climbing = false;
        player.climb_dangling = false;
        player.climb_dir = 0;
        jumped_this_frame = true;
    }

    if (!jumped_this_frame) {
        updateClimb(player, grab_held, vertical, room_index);
    }
    if (!player.climbing) {
        updateVerticalSpeed(player, jump_held, input.isPressed(.down), effective_horizontal, room_index);
    }

    const previous_x = player.x;
    const vertical_speed_before_move = player.vy;
    moveHorizontal(player, player.vx, room_index);
    player.grounded = false;
    moveVertical(player, player.vy, room_index);
    player_collision.resolvePlayerEmbedding(player, room_index);
    if (!player.grounded and player.vy >= 0 and player_collision.floorContact(player.*, room_index)) {
        player.grounded = true;
    }

    if (player.grounded) {
        if (player.dash_timer == 0 and player.dash_refill_cooldown_timer == 0) {
            refillPlayerDash(player);
        }
        if (!was_grounded and player.dust_suppress_timer == 0 and shouldSpawnLandingDust(vertical_speed_before_move, landing_dust_air_frames)) {
            dust.spawnLandingAtFeet(player.*);
        }
        if (!was_grounded) {
            player_sfx.playLand(player, room_index, vertical_speed_before_move);
            chapter_systems.triggerActorBounceAtPlayer(room_index, player.*);
        }
        player.var_jump_timer = 0;
        player.wall_slide_timer = player_wall_slide_frames;
        player.wall_sliding = false;
        if (!grab_held or vertical >= 0) {
            player.climbing = false;
            player.climb_dir = 0;
        }
        player.climb_dangling = false;
    }

    updateAnimation(player);
    updateLandingDustAirFrames(player);
    footsteps.update(player, room_index, previous_x);
}

pub fn tryStartDash(player: *Player, horizontal: i16, vertical: i16, allow_dash: bool) bool {
    if (!allow_dash or player.dashes == 0 or player.dash_cooldown_timer > 0) return false;

    var dash_x = horizontal;
    const dash_y = vertical;
    if (dash_x == 0 and dash_y == 0) {
        dash_x = if (player.facing_left) -1 else 1;
    }

    player.dashes -= 1;
    player.dash_timer = player_dash_frames;
    player.dash_cooldown_timer = player_dash_cooldown_frames;
    player.dash_refill_cooldown_timer = player_dash_refill_cooldown_frames;
    player.dash_effect_timer = player_dash_effect_frames;
    player.dash_trail_timer = player_dash_trail_interval;
    player.dash_dir_x = dash_x;
    player.dash_dir_y = dash_y;
    player.jump_buffer_timer = 0;
    player.coyote_timer = 0;
    player.var_jump_timer = 0;
    player.force_move_x_timer = 0;
    player.climb_grab_lockout_timer = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.wall_sliding = false;
    player.grounded = false;
    if (dash_x != 0) {
        player.facing_left = dash_x < 0;
    }

    var speed = player_dash_speed;
    if (dash_x != 0 and dash_y != 0) {
        speed = fixedMul(speed, player_dash_diagonal_mult);
    }
    player.vx = @as(i32, dash_x) * speed;
    player.vy = @as(i32, dash_y) * speed;
    applyLiftBoostToDash(player);
    dash_effects.spawnAfterimage(player.*);
    dash_effects.spawnBurst(player.*);
    player_sfx.playDash(player.*);
    return true;
}

pub fn updateDashMovement(player: *Player, room_index: usize) void {
    const was_grounded = player.grounded;
    const vertical_speed_before_move = player.vy;
    if (player.dash_trail_timer == 0) {
        dash_effects.spawnAfterimage(player.*);
        player.dash_trail_timer = player_dash_trail_interval;
    }

    if (chapter_entities.tryBreakDashCollision(player, room_index)) |impact| {
        applyBreakableWallImpact(player, room_index, impact);
        updateLandingDustAirFrames(player);
        updateAnimation(player);
        return;
    }
    moveHorizontal(player, player.vx, room_index);
    player.grounded = false;
    moveVertical(player, player.vy, room_index);
    player_collision.resolvePlayerEmbedding(player, room_index);
    if (!player.grounded and player.vy >= 0 and player_collision.floorContact(player.*, room_index)) {
        player.grounded = true;
    }
    if (!was_grounded and player.grounded) {
        player_sfx.playLand(player, room_index, vertical_speed_before_move);
    }
    updateLandingDustAirFrames(player);

    if (player.dash_timer > 0) {
        player.dash_timer -= 1;
    }
    if (player.dash_timer == 0) {
        endDash(player);
    }
    updateAnimation(player);
}

pub fn updateAnimation(player: *Player) void {
    const next_animation: PlayerAnimation = if (player.dash_timer > 0 and player.dash_dir_y < 0)
        .jump
    else if (player.dash_timer > 0 and player.dash_dir_y > 0)
        .fall
    else if (player.dash_timer > 0 and player.dash_dir_x != 0)
        .run
    else if (player.wall_sliding)
        .wallslide
    else if (player.climb_ledge_timer > 0)
        .climb_pull
    else if (player.climb_dangling)
        .dangling
    else if (player.climbing)
        .climb
    else if (!player.grounded and player.vy < 0)
        .jump
    else if (shouldUseAirborneAnimation(player.*))
        .fall
    else if (player.moving)
        .run
    else
        .idle;
    if (player.animation != next_animation) {
        player.animation = next_animation;
        player.animation_timer = 0;
        if (next_animation == .idle) {
            chooseNextIdle(player);
        }
    }

    const first_frame: u16 = switch (player.animation) {
        .idle => player.idle_first_frame,
        .run => player_run_first_frame,
        .jump => player_jump_first_frame,
        .fall => player_fall_first_frame,
        .wallslide => player_wallslide_first_frame,
        .climb => player_climbup_first_frame,
        .dangling => player_dangling_first_frame,
        .climb_pull => player_climb_pull_first_frame,
    };
    const frame_count: u16 = switch (player.animation) {
        .idle => player.idle_frame_count,
        .run => player_run_frame_count,
        .jump => player_jump_frame_count,
        .fall => player_fall_frame_count,
        .wallslide => 1,
        .climb => player_climbup_frame_count,
        .dangling => player_dangling_frame_count,
        .climb_pull => player_climb_pull_frame_count,
    };
    player.animation_timer +%= 1;
    if (player.animation == .idle and player.animation_timer >= frame_count * player_animation_speed) {
        chooseNextIdle(player);
        player.animation_timer = 0;
    }
    const frame_offset = (player.animation_timer / player_animation_speed) % frame_count;
    player.frame = first_frame + frame_offset;
}

pub fn moveHorizontal(player: *Player, amount: i32, room_index: usize) void {
    player_collision.moveHorizontal(player, amount, room_index);
}

pub fn moveVertical(player: *Player, amount: i32, room_index: usize) void {
    player_collision.moveVertical(player, amount, room_index);
}

fn refillPlayerDash(player: *Player) void {
    player.dashes = 1;
}

fn endDash(player: *Player) void {
    var next_vx: i32 = if (player.dash_dir_x == 0) 0 else @as(i32, player.dash_dir_x) * player_dash_end_speed;
    var next_vy: i32 = if (player.dash_dir_y == 0) 0 else @as(i32, player.dash_dir_y) * player_dash_end_speed;
    if (player.dash_dir_x != 0 and player.dash_dir_y != 0) {
        next_vx = fixedMul(next_vx, player_dash_diagonal_mult);
        next_vy = fixedMul(next_vy, player_dash_diagonal_mult);
    }
    if (next_vy < 0) {
        next_vy = fixedMul(next_vy, player_dash_end_up_mult);
    }
    player.vx = next_vx;
    player.vy = next_vy;
    player.dash_dir_x = 0;
    player.dash_dir_y = 0;
}

fn applyBreakableWallImpact(player: *Player, room_index: usize, impact: chapter_entities.BreakableWallImpact) void {
    if (impact.normal_x < 0) {
        player.x = pixelToFixed(impact.wall_x - player_body_width);
    } else if (impact.normal_x > 0) {
        player.x = pixelToFixed(impact.wall_right);
    }
    if (impact.normal_y < 0) {
        player.y = pixelToFixed(impact.wall_y - player_body_height);
    } else if (impact.normal_y > 0) {
        player.y = pixelToFixed(impact.wall_bottom);
    }

    const recoil_x = -impact.dash_dir_x;
    const recoil_y = -impact.dash_dir_y;
    var recoil_speed = breakable_wall_recoil_speed;
    if (recoil_x != 0 and recoil_y != 0) {
        recoil_speed = fixedMul(recoil_speed, player_dash_diagonal_mult);
    }
    player.vx = @as(i32, recoil_x) * recoil_speed;
    player.vy = @as(i32, recoil_y) * recoil_speed;
    player.dash_timer = 0;
    player.dash_dir_x = 0;
    player.dash_dir_y = 0;
    player.dash_effect_timer = 0;
    player.dash_trail_timer = 0;
    player.var_jump_timer = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.wall_sliding = false;
    player.grounded = player_collision.floorContact(player.*, room_index);
    player.moving = player.vx != 0;
    if (player.vx != 0) {
        player.facing_left = player.vx < 0;
    }
}

fn applyLiftBoostToJump(player: *Player) void {
    if (player.lift_boost_timer == 0) return;
    player.vx += player.lift_boost_x;
    player.vy += player.lift_boost_y;
}

fn shouldSpawnLandingDust(vertical_speed_before_move: i32, air_frames: u8) bool {
    return vertical_speed_before_move >= landing_dust_min_speed and air_frames >= landing_dust_air_frame_threshold;
}

fn shouldUseAirborneAnimation(player: Player) bool {
    return !player.grounded and player.landing_dust_air_frames >= landing_dust_air_frame_threshold;
}

fn updateLandingDustAirFrames(player: *Player) void {
    if (player.grounded) {
        player.landing_dust_air_frames = 0;
    } else if (player.landing_dust_air_frames < 0xff) {
        player.landing_dust_air_frames += 1;
    }
}

fn applyLiftBoostToDash(player: *Player) void {
    if (player.lift_boost_timer == 0) return;
    player.vx += player.lift_boost_x;
}

fn updateHorizontalSpeed(player: *Player, horizontal: i16) void {
    const mult = if (player.grounded) fixed_one else player_air_mult;
    const target = @as(i32, horizontal) * player_max_run;
    const accel = if (horizontal != 0 and absI32(player.vx) > player_max_run and signI32(player.vx) == horizontal)
        fixedMul(player_run_reduce, mult)
    else
        fixedMul(player_run_accel, mult);
    player.vx = approach(player.vx, target, accel);
}

fn updateVerticalSpeed(player: *Player, jump_held: bool, fast_fall: bool, horizontal: i16, room_index: usize) void {
    var max_fall = if (fast_fall) player_fast_max_fall else player_max_fall;
    player.wall_sliding = false;
    if (!player.grounded) {
        if (!fast_fall and player.vy >= 0 and player.wall_slide_timer > 0 and player_collision.wallSlideContact(player.*, horizontal, room_index)) {
            max_fall = player_wall_slide_start_max;
            player.wall_sliding = true;
            player.wall_slide_timer -= 1;
        }
        const speed_abs = absI32(player.vy);
        const apex_hang_enabled = player.apex_hang_disabled_timer == 0;
        const gravity = if (apex_hang_enabled and jump_held and speed_abs < player_apex_hang_threshold)
            player_gravity / 4
        else if (jump_held and speed_abs < player_half_grav_threshold)
            player_gravity / 2
        else
            player_gravity;
        player.vy = approach(player.vy, max_fall, gravity);
    }

    if (player.var_jump_timer > 0) {
        player.var_jump_timer -= 1;
        if (jump_held) {
            if (player.vy > player.var_jump_speed) {
                player.vy = player.var_jump_speed;
            }
        } else {
            player.var_jump_timer = 0;
        }
    }
}

fn updateClimb(player: *Player, grab_held: bool, vertical: i16, room_index: usize) void {
    if (!grab_held or player.stamina <= 0 or player.climb_grab_lockout_timer > 0) {
        player.climbing = false;
        player.climb_dangling = false;
        player.climb_dir = 0;
        return;
    }

    const preferred_dir = climbFacingDir(player.*);
    var climb_dir: i16 = if (climbContact(player.*, preferred_dir, room_index))
        preferred_dir
    else if (climbContact(player.*, -preferred_dir, room_index))
        -preferred_dir
    else
        0;
    if (climb_dir == 0 and !player.climbing and player.vy >= 0 and vertical < 1) {
        climb_dir = if (tryClimbStartLift(player, preferred_dir, room_index))
            preferred_dir
        else if (tryClimbStartLift(player, -preferred_dir, room_index))
            -preferred_dir
        else
            0;
    }
    if (climb_dir == 0) {
        if (player.climbing and player.vy < 0 and tryClimbHopAfterLostWall(player, preferred_dir, room_index)) {
            return;
        }
        player.climbing = false;
        player.climb_dangling = false;
        player.climb_dir = 0;
        return;
    }
    if (!player.climbing and player.vy < 0) {
        player.climb_dangling = false;
        player.climb_dir = 0;
        return;
    }
    if (!player.climbing and player.stamina <= player_climb_tired_stamina) {
        player.climb_dangling = false;
        player.climb_dir = 0;
        return;
    }

    player.facing_left = climb_dir < 0;
    if (player.climbing and vertical < 0 and tryClimbHopFromWall(player, climb_dir, room_index)) {
        return;
    }

    if (!player.climbing) {
        player_sfx.playGrab(player, room_index);
        player.vy = fixedMul(player.vy, player_climb_grab_y_mult);
    }

    player.climbing = true;
    player.climb_dangling = false;
    player.climb_dir = climb_dir;
    player.wall_sliding = false;
    player.vx = 0;

    var target_y: i32 = if (vertical < 0)
        player_climb_up_speed
    else if (vertical > 0)
        player_climb_down_speed
    else
        0;
    if (vertical == 0 and !player.grounded and climbAtLedgeTop(player.*, climb_dir, room_index)) {
        target_y = player_climb_slip_speed;
    }
    player.vy = approach(player.vy, target_y, player_climb_accel);
    player.climb_dangling = vertical == 0 and !player.grounded and climbDangleContact(player.*, climb_dir, room_index);

    if (vertical < 0) {
        player.stamina = @max(0, player.stamina - player_climb_up_cost);
    } else if (vertical == 0) {
        player.stamina = @max(0, player.stamina - player_climb_still_cost);
    } else if (!player.grounded and player.wall_dust_timer == 0 and player.vy > fixed_one / 3) {
        dust.spawnWallSlide(player.*, climb_dir);
        player.wall_dust_timer = 5;
    }
}

fn climbWallDirection(player: Player, room_index: usize) i16 {
    if (climbContact(player, -1, room_index)) return -1;
    if (climbContact(player, 1, room_index)) return 1;
    return 0;
}

fn climbFacingDir(player: Player) i16 {
    if ((player.climbing or player.climb_dangling) and player.climb_dir != 0) return player.climb_dir;
    return if (player.facing_left) -1 else 1;
}

fn climbContact(player: Player, dir: i16, room_index: usize) bool {
    return climbContactAt(fixedToPixel(player.x), fixedToPixel(player.y), dir, room_index);
}

fn climbContactAt(x: i16, y: i16, dir: i16, room_index: usize) bool {
    const check_x = x + if (dir < 0) @as(i16, -climb_check_dist) else player_body_width;
    return player_collision.solidRectAt(check_x, y, climb_check_dist, player_body_height, room_index) or
        player_collision.dynamicSolidRectAt(room_index, check_x, y, climb_check_dist, player_body_height);
}

fn tryClimbStartLift(player: *Player, dir: i16, room_index: usize) bool {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    var lift: i16 = 1;
    while (lift <= climb_up_check_dist) : (lift += 1) {
        const lifted_y = start_y - lift;
        if (player_collision.collidesAt(start_x, lifted_y, room_index)) continue;
        if (climbContactAt(start_x, lifted_y, dir, room_index)) {
            player.y = pixelToFixed(lifted_y);
            return true;
        }
    }
    return false;
}

fn climbDangleContact(player: Player, dir: i16, room_index: usize) bool {
    const side_offset: i16 = if (dir < 0) -1 else player_body_width;
    const x = fixedToPixel(player.x) + side_offset;
    const y = fixedToPixel(player.y);
    const hands_caught = player_collision.wallSolidAtPixel(x, y + 1, room_index) or
        player_collision.wallSolidAtPixel(x, y + 2, room_index) or
        player_collision.wallSolidAtPixel(x, y + 3, room_index);
    const body_blocked = player_collision.wallSolidAtPixel(x, y + 6, room_index) or
        player_collision.wallSolidAtPixel(x, y + 9, room_index) or
        player_collision.wallSolidAtPixel(x, y + player_body_height - 3, room_index);
    return hands_caught and !body_blocked;
}

fn tryClimbHopFromWall(player: *Player, dir: i16, room_index: usize) bool {
    if (!climbLowerSideContact(player.*, dir, room_index)) return false;
    return tryClimbHop(player, dir, room_index);
}

fn tryClimbHopAfterLostWall(player: *Player, dir: i16, room_index: usize) bool {
    return tryClimbHop(player, dir, room_index);
}

fn tryClimbHop(player: *Player, dir: i16, room_index: usize) bool {
    if (player.grounded) return false;
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    if (player_collision.collidesAt(start_x, start_y - 1, room_index)) return false;
    if (!climbUpperSideClear(player.*, dir, room_index)) return false;

    if (climbLedgeTarget(player.*, dir, room_index)) |target| {
        startClimbLedgePull(player, dir, target);
        return true;
    }

    startClimbHop(player, dir);
    return true;
}

fn climbAtLedgeTop(player: Player, dir: i16, room_index: usize) bool {
    return !player.grounded and climbUpperSideClear(player, dir, room_index) and climbLowerSideContact(player, dir, room_index);
}

fn climbUpperSideClear(player: Player, dir: i16, room_index: usize) bool {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    const side_x = start_x + if (dir < 0) @as(i16, -1) else player_body_width;
    if (player_collision.wallSolidAtPixel(side_x, start_y, room_index) or
        player_collision.wallSolidAtPixel(side_x, start_y + 4, room_index))
    {
        return false;
    }
    return true;
}

fn climbLowerSideContact(player: Player, dir: i16, room_index: usize) bool {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    const side_x = start_x + if (dir < 0) @as(i16, -1) else player_body_width;
    return player_collision.wallSolidAtPixel(side_x, start_y + 8, room_index) or
        player_collision.wallSolidAtPixel(side_x, start_y + player_body_height - 3, room_index);
}

fn climbLedgeTarget(player: Player, dir: i16, room_index: usize) ?LedgeTarget {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    const side_x = start_x + if (dir < 0) @as(i16, -1) else player_body_width;
    var scan_y = start_y + 5;
    const scan_end = start_y + player_body_height;
    while (scan_y <= scan_end) : (scan_y += 1) {
        if (!isWallTopAt(side_x, scan_y, room_index)) continue;
        const target = LedgeTarget{
            .x = start_x + dir * player_body_width,
            .y = scan_y - player_body_height,
        };
        if (validClimbLedgeTarget(target, room_index)) return target;
    }
    return null;
}

fn validClimbLedgeTarget(target: LedgeTarget, room_index: usize) bool {
    return !player_collision.collidesAt(target.x, target.y, room_index) and
        player_collision.floorContactAt(target.x, target.y, room_index);
}

fn isWallTopAt(x: i16, y: i16, room_index: usize) bool {
    return player_collision.wallSolidAtPixel(x, y, room_index) and
        !player_collision.wallSolidAtPixel(x, y - 1, room_index);
}

fn startClimbLedgePull(player: *Player, dir: i16, target: LedgeTarget) void {
    player_sfx.playClimbLedge(player);
    player.climb_ledge_timer = climb_ledge_pull_frames;
    player.climb_ledge_start_x = player.x;
    player.climb_ledge_start_y = player.y;
    player.climb_ledge_target_x = pixelToFixed(target.x);
    player.climb_ledge_target_y = pixelToFixed(target.y);
    player.vx = 0;
    player.vy = 0;
    player.force_move_x = 0;
    player.force_move_x_timer = 0;
    player.climb_grab_lockout_timer = climb_hop_grab_lockout_frames;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.wall_sliding = false;
    player.grounded = false;
    player.facing_left = dir < 0;
}

fn updateClimbLedgePull(player: *Player, room_index: usize) void {
    const remaining = @min(player.climb_ledge_timer, climb_ledge_pull_frames);
    const elapsed: u8 = climb_ledge_pull_frames - remaining + 1;
    player.x = interpolateFixed(player.climb_ledge_start_x, player.climb_ledge_target_x, elapsed, climb_ledge_pull_frames);
    player.y = interpolateFixed(player.climb_ledge_start_y, player.climb_ledge_target_y, elapsed, climb_ledge_pull_frames);
    player.vx = 0;
    player.vy = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.wall_sliding = false;
    player.grounded = false;
    player.climb_ledge_timer -= 1;
    if (player.climb_ledge_timer == 0) {
        player.x = player.climb_ledge_target_x;
        player.y = player.climb_ledge_target_y;
        player.grounded = player_collision.floorContact(player.*, room_index);
    }
}

fn interpolateFixed(start: i32, target: i32, elapsed: u8, total: u8) i32 {
    return start + @divTrunc((target - start) * @as(i32, elapsed), @as(i32, total));
}

fn startClimbHop(player: *Player, dir: i16) void {
    player_sfx.playClimbLedge(player);
    player.vx = @as(i32, dir) * climb_hop_x_speed;
    if (player.vy > climb_hop_y_speed) {
        player.vy = climb_hop_y_speed;
    }
    player.force_move_x = dir;
    player.force_move_x_timer = climb_hop_force_frames;
    player.climb_grab_lockout_timer = climb_hop_grab_lockout_frames;
    player.climb_ledge_timer = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.wall_sliding = false;
    player.grounded = false;
}

fn chooseNextIdle(player: *Player) void {
    const choice = nextRandom() % 5;
    if (choice == 4) {
        player.idle_first_frame = player_idle_c_first_frame;
        player.idle_frame_count = player_idle_c_frame_count;
    } else if ((choice & 1) == 0) {
        player.idle_first_frame = player_idle_a_first_frame;
        player.idle_frame_count = player_idle_a_frame_count;
    } else {
        player.idle_first_frame = player_idle_b_first_frame;
        player.idle_frame_count = player_idle_b_frame_count;
    }
}
