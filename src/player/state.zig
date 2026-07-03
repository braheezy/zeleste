const build_options = @import("build_options");
const mm = @import("maxmod");
const math = @import("../core/math.zig");

const fixed_one = math.fixed_one;

pub const body_width = 8;
pub const body_height = 16;
pub const draw_offset_x = -12;
pub const draw_offset_y = -16;
pub const max_run: i32 = 0x180;
pub const run_accel: i32 = 0x41;
pub const run_reduce: i32 = 0x19;
pub const air_mult: i32 = 0xA8;
pub const gravity: i32 = 0x44;
pub const max_fall: i32 = 0x2A8;
pub const fast_max_fall: i32 = 0x400;
pub const half_grav_threshold: i32 = 0xAA;
pub const apex_hang_threshold: i32 = 0x38;
pub const jump_speed: i32 = -0x1B8;
pub const wall_jump_speed: i32 = -0x1B0;
pub const wall_jump_h_speed: i32 = 0x1F8;
pub const wall_jump_force_frames = 10;
pub const super_dash_speed: i32 = @divTrunc(fixed_one * 260, 60);
pub const dash_speed: i32 = 0x400;
pub const dash_end_speed: i32 = 0x200;
pub const dash_frames = 10;
pub const dash_buffer_frames = 5;
pub const dash_cooldown_frames = 12;
pub const dash_refill_cooldown_frames = 6;
pub const dash_effect_frames = 16;
pub const dash_trail_interval = 4;
pub const dash_diagonal_mult: i32 = 0xB5;
pub const dash_end_up_mult: i32 = 0xC0;
pub const bounce_speed: i32 = -0x3C0;
pub const super_bounce_speed: i32 = -0x4A0;
pub const side_bounce_speed: i32 = 0x400;
pub const spring_momentum_bonus_divisor = 2;
pub const spring_momentum_bonus_cap: i32 = 0x180;
pub const side_bounce_force_move_frames = 18;
pub const wall_slide_start_max: i32 = 0x55;
pub const wall_slide_frames = 72;
pub const room_transition_cooldown_frames = 18;
pub const climb_max_stamina: i16 = 6600;
pub const climb_tired_stamina: i16 = 1200;
pub const climb_up_speed: i32 = -0xBF;
pub const climb_down_speed: i32 = 0x154;
pub const climb_slip_speed: i32 = 0x80;
pub const climb_accel: i32 = 0x64;
pub const climb_grab_y_mult: i32 = 0x80;
pub const climb_up_cost: i16 = 45;
pub const climb_still_cost: i16 = 10;
pub const climb_jump_cost: i16 = 1650;
pub const climb_ledge_frames = 28;
pub const climb_jump_lockout_frames = 8;
pub const death_anim_frames = 46;
pub const respawn_burst_frames = 12;
pub const var_jump_frames = 11;
pub const wall_jump_var_jump_frames = 10;
pub const coyote_frames = 6;
pub const jump_buffer_frames = 5;
pub const lift_boost_frames = 10;
pub const lift_boost_x_cap: i32 = @divTrunc(fixed_one * 250, 60);
pub const lift_boost_y_cap: i32 = -@divTrunc(fixed_one * 130, 60);
pub const tiles_per_frame = 16;
pub const animation_speed = 6;
pub const idle_neutral_first_frame = 0;
pub const idle_neutral_frame_count = 6;
pub const idle_first_frame = idle_neutral_first_frame;
pub const idle_frame_count = idle_neutral_frame_count;
pub const idle_a_first_frame = 6;
pub const idle_a_frame_count = 12;
pub const idle_b_first_frame = 18;
pub const idle_b_frame_count = 24;
pub const idle_c_first_frame = 42;
pub const idle_c_frame_count = 12;
pub const run_first_frame = 54;
pub const run_frame_count = 12;
pub const footstep_min_speed: i32 = fixed_one / 2;
pub const footstep_volume: u16 = 144;
pub const footstep_cadence_frames: u8 = 22;
pub const jump_first_frame = 66;
pub const jump_frame_count = 2;
pub const fall_first_frame = 68;
pub const fall_frame_count = 2;
pub const wallslide_first_frame = 70;
pub const climbup_first_frame = 71;
pub const climbup_frame_count = 6;
pub const dangling_first_frame = 77;
pub const dangling_frame_count = 10;
pub const climb_pull_first_frame = 87;
pub const climb_pull_frame_count = 4;
pub const sit_down_first_frame = climb_pull_first_frame + climb_pull_frame_count;
pub const sit_down_frame_count = 16;
pub const asleep_first_frame = sit_down_first_frame + sit_down_frame_count;
pub const asleep_frame_count = 1;
pub const idle_initial_neutral_loops: u8 = 3;
pub const deadown_first_frame: u16 = build_options.player_deadown_first_frame;
pub const deadown_frame_count: u16 = build_options.player_deadown_frame_count;
pub const deathside_first_frame: u16 = build_options.player_deathside_first_frame;
pub const deathside_frame_count: u16 = build_options.player_deathside_frame_count;
pub const deathup_first_frame: u16 = build_options.player_deathup_first_frame;
pub const deathup_frame_count: u16 = build_options.player_deathup_frame_count;
pub const death_intro_frame_hold: u8 = 2;
pub const death_intro_max_frames: u8 = 28;
pub const death_intro_travel_pixels: i16 = 26;
pub const hair_node_count = 5;
pub const hair_sprite_size = 16;

pub const Animation = enum(u8) {
    idle,
    run,
    jump,
    fall,
    wallslide,
    climb,
    dangling,
    climb_pull,
};

pub const DeathIntro = struct {
    first_frame: u16,
    frame_count: u16,
};

pub const DeathCause = enum(u8) {
    normal,
    fall_down,
    spike_up,
    spike_down,
    spike_left,
    spike_right,
};

pub const HairNode = struct {
    x: i32 = 0,
    y: i32 = 0,
};

pub const HairAnchor = struct {
    x: i32,
    y: i32,
    dir: i16,
};

pub const State = struct {
    x: i32,
    y: i32,
    vx: i32 = 0,
    vy: i32 = 0,
    coyote_timer: u8 = 0,
    jump_buffer_timer: u8 = 0,
    var_jump_timer: u8 = 0,
    apex_hang_disabled_timer: u8 = 0,
    room_transition_cooldown: u8 = 0,
    force_move_x_timer: u8 = 0,
    dust_suppress_timer: u8 = 0,
    landing_dust_air_frames: u8 = 0,
    wall_dust_timer: u8 = 0,
    dash_timer: u8 = 0,
    dash_buffer_timer: u8 = 0,
    dash_cooldown_timer: u8 = 0,
    dash_refill_cooldown_timer: u8 = 0,
    dash_effect_timer: u8 = 0,
    dash_trail_timer: u8 = 0,
    force_move_x: i16 = 0,
    lift_boost_x: i32 = 0,
    lift_boost_y: i32 = 0,
    lift_boost_timer: u8 = 0,
    dashes: u8 = 1,
    dash_dir_x: i16 = 0,
    dash_dir_y: i16 = 0,
    wall_slide_timer: u8 = wall_slide_frames,
    var_jump_speed: i32 = 0,
    stamina: i16 = climb_max_stamina,
    animation: Animation = .idle,
    animation_timer: u16 = 0,
    sweat_timer: u16 = 0,
    sweat_frame: u16 = 0,
    idle_first_frame: u16 = idle_neutral_first_frame,
    idle_frame_count: u16 = idle_neutral_frame_count,
    idle_variant_index: u8 = 0,
    idle_neutral_loops_remaining: u8 = idle_initial_neutral_loops,
    frame: u16 = 0,
    grounded: bool = false,
    facing_left: bool = false,
    moving: bool = false,
    wall_sliding: bool = false,
    climbing: bool = false,
    climb_dangling: bool = false,
    climb_dir: i16 = 0,
    climb_ledge_timer: u8 = 0,
    climb_ledge_start_x: i32 = 0,
    climb_ledge_start_y: i32 = 0,
    climb_ledge_target_x: i32 = 0,
    climb_ledge_target_y: i32 = 0,
    climb_grab_lockout_timer: u8 = 0,
    hair_initialized: bool = false,
    footstep_cooldown: u8 = 0,
    footstep_variant: u8 = 0,
    footstep_handle: mm.Sfxhand = 0,
    sfx_variant: u8 = 0,
    hair_nodes: [hair_node_count]HairNode = [_]HairNode{.{}} ** hair_node_count,
};

pub fn canStartInteraction(player: State) bool {
    return player.grounded and
        player.dash_timer == 0 and
        player.climb_ledge_timer == 0 and
        !player.climbing and
        !player.climb_dangling and
        !player.wall_sliding;
}
