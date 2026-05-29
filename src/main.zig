const gba = @import("gba");
const level = @import("generated_rooms.zig");
const build_options = @import("build_options");
const mm = @import("maxmod");
const sound_ids = @import("generated/assets/prologue_sound_ids.zig");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);

const player_tiles_data align(4) = @embedFile("generated/assets/player/madeline_tiles.bin").*;
const player_palette_data align(4) = @embedFile("generated/assets/player/madeline_palette.bin").*;
const player_hair_anchors_data align(4) = @embedFile("generated/assets/player/madeline_hair_anchors.bin").*;
const player_sweat_tiles_data align(4) = @embedFile("generated/assets/player_sweat/madeline_tiles.bin").*;
const player_sweat_palette_data align(4) = @embedFile("generated/assets/player_sweat/madeline_palette.bin").*;
const hair_palette_data align(4) = @embedFile("generated/assets/player/hair_palette.bin").*;
const falling_block_tiles_data align(4) = @embedFile("generated/assets/entities/prologue_a/falling_block_tiles.bin").*;
const falling_block_palette_data align(4) = @embedFile("generated/assets/entities/prologue_a/falling_block_palette.bin").*;
const funny_car_tiles_data align(4) = @embedFile("generated/assets/entities/prologue_a/funny_car_tiles.bin").*;
const funny_car_palette_data align(4) = @embedFile("generated/assets/entities/prologue_a/funny_car_palette.bin").*;
const bridge_tiles_data align(4) = @embedFile("generated/assets/entities/prologue_bridge/bridge_tiles.bin").*;
const bridge_palette_data align(4) = @embedFile("generated/assets/entities/prologue_bridge/bridge_palette.bin").*;
const bridge_layout_data align(4) = @embedFile("generated/assets/entities/prologue_bridge/bridge_layout.bin").*;
const bridge_groups_data align(4) = @embedFile("generated/assets/entities/prologue_bridge/bridge_groups.bin").*;
const grass1_tiles_data align(4) = @embedFile("generated/assets/foreground/grass1_tiles.bin").*;
const grass1_palette_data align(4) = @embedFile("generated/assets/foreground/grass1_palette.bin").*;
const grass1_mirror_tiles_data align(4) = @embedFile("generated/assets/foreground/grass1_mirror_tiles.bin").*;
const grass1_mirror_palette_data align(4) = @embedFile("generated/assets/foreground/grass1_mirror_palette.bin").*;
const grass2_tiles_data align(4) = @embedFile("generated/assets/foreground/grass2_tiles.bin").*;
const grass2_palette_data align(4) = @embedFile("generated/assets/foreground/grass2_palette.bin").*;
const grass2_mirror_tiles_data align(4) = @embedFile("generated/assets/foreground/grass2_mirror_tiles.bin").*;
const grass2_mirror_palette_data align(4) = @embedFile("generated/assets/foreground/grass2_mirror_palette.bin").*;
const bird_intro_tiles_data align(4) = @embedFile("generated/assets/bird/bird_intro_tiles.bin").*;
const bird_palette_data align(4) = @embedFile("generated/assets/bird/bird_palette.bin").*;
const bird_hold_hint_tiles_data align(4) = @embedFile("generated/assets/bird/hold_hint_tiles.bin").*;
const bird_climb_hint_tiles_data align(4) = @embedFile("generated/assets/bird/climb_hint_tiles.bin").*;
const bird_dash_hint_tiles_data align(4) = @embedFile("generated/assets/bird/dash_hint_tiles.bin").*;
const bird_hint_palette_data align(4) = @embedFile("generated/assets/bird/hint_palette.bin").*;
const tiny_bird_tiles_data align(4) = @embedFile("generated/assets/tiny_bird/tiny_bird_tiles.bin").*;
const tiny_bird_palette_data align(4) = @embedFile("generated/assets/tiny_bird/tiny_bird_palette.bin").*;
const granny_idle_tiles_data align(4) = @embedFile("generated/assets/granny/granny_idle_tiles.bin").*;
const granny_laugh_tiles_data align(4) = @embedFile("generated/assets/granny/granny_laugh_tiles.bin").*;
const granny_quotes_tiles_data align(4) = @embedFile("generated/assets/granny/granny_quotes_tiles.bin").*;
const granny_haha_tiles_data align(4) = @embedFile("generated/assets/granny/granny_haha_tiles.bin").*;
const granny_palette_data align(4) = @embedFile("generated/assets/granny/granny_palette.bin").*;
const prologue_soundbank_data align(4) = @embedFile("generated/assets/prologue_soundbank.bin").*;
const overworld_bg_tiles_data align(4) = @embedFile("generated/assets/overworld/bg_tiles.bin").*;
const overworld_bg_map_data align(4) = @embedFile("generated/assets/overworld/bg_map.bin").*;
const overworld_bg_palette_data align(4) = @embedFile("generated/assets/overworld/bg_palette.bin").*;

const bg_screenblock: u5 = 29;
const parallax_screenblock: u5 = 28;
const parallax_charblock: u2 = 3;
const bg_hardware_width_tiles: usize = 64;
const bg_hardware_height_tiles: usize = 32;
const parallax_hardware_width_tiles: usize = 32;
const parallax_hardware_height_tiles: usize = 32;
const screen_width = 240;
const screen_height = 160;
const invalid_loaded_frame: u16 = 0xffff;
const debug_fps_enabled = build_options.dev_hud;
const debug_fps_timer_index = 3;
const debug_fps_ticks_per_second = 16_384;
const debug_fps_first_object = 126;
const debug_fps_base_tile: u10 = 1000;
const debug_fps_palette_bank: u4 = dust_palette_bank;
const overworld_width_tiles = 30;
const overworld_height_tiles = 20;

const fixed_shift = 8;
const fixed_one: i32 = 1 << fixed_shift;

const player_body_width = 8;
const player_body_height = 16;
const player_draw_offset_x = -12;
const player_draw_offset_y = -16;
const player_max_run: i32 = 0x180;
const player_run_accel: i32 = 0x41;
const player_run_reduce: i32 = 0x19;
const player_air_mult: i32 = 0xA8;
const player_gravity: i32 = 0x44;
const player_max_fall: i32 = 0x2A8;
const player_fast_max_fall: i32 = 0x400;
const player_half_grav_threshold: i32 = 0xAA;
const player_apex_hang_threshold: i32 = 0x38;
const player_jump_speed: i32 = -0x1B8;
const player_wall_jump_speed: i32 = -0x1B0;
const player_wall_jump_h_speed: i32 = 0x1F8;
const player_wall_jump_force_frames = 10;
const player_dash_speed: i32 = 0x400;
const player_dash_end_speed: i32 = 0x200;
const player_dash_frames = 10;
const player_dash_cooldown_frames = 12;
const player_dash_refill_cooldown_frames = 6;
const player_dash_effect_frames = 16;
const player_dash_trail_interval = 4;
const dash_afterimage_life: u8 = 14;
const player_dash_diagonal_mult: i32 = 0xB5;
const player_dash_end_up_mult: i32 = 0xC0;
const player_wall_slide_start_max: i32 = 0x55;
const player_wall_slide_frames = 72;
const player_room_transition_cooldown_frames = 18;
const player_climb_max_stamina: i16 = 6600;
const player_climb_tired_stamina: i16 = 1200;
const player_climb_up_speed: i32 = -0xBF;
const player_climb_down_speed: i32 = 0x154;
const player_climb_slip_speed: i32 = 0x80;
const player_climb_accel: i32 = 0x64;
const player_climb_grab_y_mult: i32 = 0x80;
const player_climb_up_cost: i16 = 45;
const player_climb_still_cost: i16 = 10;
const player_climb_jump_cost: i16 = 1650;
const player_climb_ledge_frames = 8;
const player_climb_ledge_hop_pixels = 6;
const player_climb_ledge_min_body_above = 10;
const player_climb_jump_lockout_frames = 8;
const player_death_anim_frames = 46;
const player_respawn_burst_frames = 12;
const player_var_jump_frames = 11;
const player_wall_jump_var_jump_frames = 10;
const player_coyote_frames = 6;
const player_jump_buffer_frames = 5;
const player_tiles_per_frame = 16;
const player_animation_speed = 6;
const player_idle_first_frame = 0;
const player_idle_frame_count = 84;
const player_idle_a_first_frame = 0;
const player_idle_a_frame_count = 12;
const player_idle_b_first_frame = 12;
const player_idle_b_frame_count = 24;
const player_idle_c_first_frame = 72;
const player_idle_c_frame_count = 12;
const player_run_first_frame = 84;
const player_run_frame_count = 12;
const player_footstep_min_speed: i32 = fixed_one / 2;
const player_footstep_volume: u16 = 144;
const player_footstep_cadence_frames: u8 = 22;
const player_jump_first_frame = 96;
const player_jump_frame_count = 2;
const player_fall_first_frame = 98;
const player_fall_frame_count = 2;
const player_wallslide_first_frame = 100;
const player_climbup_first_frame = 101;
const player_climbup_frame_count = 6;
const player_dangling_first_frame = 107;
const player_dangling_frame_count = 10;
const player_climb_pull_first_frame = 117;
const player_climb_pull_frame_count = 4;
const player_deadown_first_frame: u16 = build_options.player_deadown_first_frame;
const player_deadown_frame_count: u16 = build_options.player_deadown_frame_count;
const player_deathside_first_frame: u16 = build_options.player_deathside_first_frame;
const player_deathside_frame_count: u16 = build_options.player_deathside_frame_count;
const player_deathup_first_frame: u16 = build_options.player_deathup_first_frame;
const player_deathup_frame_count: u16 = build_options.player_deathup_frame_count;
const player_death_intro_frame_hold: u8 = 2;
const player_death_intro_max_frames: u8 = 28;
const player_death_intro_travel_pixels: i16 = 26;
const sweat_tiles_per_frame = 16;
const sweat_still_first_frame = 0;
const sweat_still_frame_count = 6;
const sweat_climb_first_frame = 6;
const sweat_climb_frame_count = 6;
const sweat_jump_first_frame = 12;
const sweat_jump_frame_count = 4;
const max_falling_blocks = 8;
const falling_block_shake_frames = 18;
const falling_block_gravity: i32 = 0x58;
const falling_block_max_fall: i32 = 0x560;
const falling_block_base_tile: u10 = 32;
const falling_block_palette_bank: u4 = 1;
const bridge_base_tile: u10 = 128;
const bridge_palette_bank: u4 = 5;
const bridge_falling_palette_bank: u4 = 11;
const bridge_chunk_width = 8;
const bridge_chunk_height = 32;
const bridge_visual_height = 25;
const bridge_tiles_per_chunk = 4;
const bridge_empty_chunk = 255;
const bridge_no_group = 255;
const bridge_world_x: i16 = 64;
const bridge_world_y: i16 = 126;
const bridge_ending_early_shake_frames: u8 = 12;
const bridge_ending_gap_chunks = 3;
const end_level_walk_frames: u8 = 28;
const end_level_walk_speed: i32 = fixed_one;
const end_level_camera_frames: u8 = 54;
const end_level_camera_lift: i16 = 48;
const end_level_black_frames: u8 = 18;
const bridge_max_chunks = 128;
const bridge_max_objects = 30;
const bridge_first_object = foreground_behind_stamp_first_object;
const bridge_shake_frames: u8 = 34;
const bridge_fall_gravity: i32 = 0x48;
const bridge_fall_max_speed: i32 = 0x4C0;
const funny_car_base_tile: u10 = 560;
const funny_car_palette_bank: u4 = 10;
const funny_car_width = 47;
const funny_car_height = 16;
const funny_car_tiles_per_car = 12;
const funny_car_object_count = 2;
const max_funny_cars = 2;
const funny_car_top = [_]i8{ 7, 6, 5, 4, 3, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 4, 5, 6, 0, 7, 7, 7, 7, 7, 7, 7, 7, 8 };
const hair_base_tile: u10 = 60;
const hair_bang_base_tile: u10 = hair_base_tile + 4;
const hair_palette_bank: u4 = 2;
const hair_anchor_forward_correction: i16 = 1;
const hair_anchor_vertical_correction: i16 = 2;
const dust_base_tile: u10 = 68;
const dust_palette_bank: u4 = 3;
const max_dust_particles = 8;
const wind_snow_base_tile: u10 = dust_base_tile + max_dust_particles;
const wind_snow_palette_bank: u4 = 3;
const max_wind_snow_particles = 28;
const bridge_room_wind_snow_particles = 16;
const wind_snow_tile_count = 8;
const sweat_base_tile: u10 = wind_snow_base_tile + wind_snow_tile_count;
const sweat_palette_bank: u4 = 4;
const death_burst_base_tile: u10 = sweat_base_tile + sweat_tiles_per_frame;
const death_burst_palette_bank: u4 = 3;
const dash_effect_base_tile: u10 = death_burst_base_tile + 6;
const chimney_smoke_base_tile: u10 = dash_effect_base_tile + 16;
const chimney_smoke_tiles_per_object = 4;
const chimney_smoke_tile_count = 12;
const chimney_smoke_palette_bank: u4 = dust_palette_bank;
const chimney_smoke_soft_color: u4 = 9;
const chimney_smoke_cycle_frames: u8 = 96;
const chimney_smoke_origin_x: i16 = 194;
const chimney_smoke_origin_y: i16 = 49;
const dash_shadow_palette_bank: u4 = 12;
const dash_shadow_palette_count = 3;
const dash_effect_palette_bank: u4 = dash_shadow_palette_bank + dash_shadow_palette_count;
const death_burst_first_object = 0;
const death_burst_spoke_count = 8;
const death_burst_count = death_burst_spoke_count + 1;
const dash_afterimage_first_object = 0;
const dash_afterimage_count = 3;
const dash_burst_object = dash_afterimage_first_object + dash_afterimage_count;
const foreground_occluding_stamp_first_object = 8;
const max_foreground_stamps = 24;
const player_object = 32;
const hair_root_object = 33;
const hair_object = 34;
const dust_first_object = 35;
const wind_snow_first_object = dust_first_object + max_dust_particles;
const sweat_object = wind_snow_first_object + max_wind_snow_particles;
const hair_node_count = 5;
const hair_sprite_size = 16;
const falling_block_first_object = sweat_object + 1;
const falling_block_objects_per_block = 3;
const foreground_behind_stamp_first_object = falling_block_first_object + max_falling_blocks * falling_block_objects_per_block;
const foreground_stamp_base_tile: u10 = 576;
const foreground_stamp_mirror_base_tile: u10 = foreground_stamp_base_tile + grass1_frame_count * grass1_tiles_per_frame;
const foreground_stamp2_base_tile: u10 = foreground_stamp_mirror_base_tile + grass1_frame_count * grass1_tiles_per_frame;
const foreground_stamp2_mirror_base_tile: u10 = foreground_stamp2_base_tile + grass2_frame_count * grass2_tiles_per_frame;
const foreground_stamp_palette_bank: u4 = 6;
const foreground_stamp2_palette_bank: u4 = 7;
// Bird frames are streamed into a high scratch range. Current bird rooms do not
// use grass stamps, so this avoids bridge/wire tile conflicts.
const bird_base_tile: u10 = 896;
const bird_hint_base_tile: u10 = bird_base_tile + bird_tiles_per_frame;
const bird_palette_bank: u4 = 8;
const bird_hint_palette_bank: u4 = 9;
const bird_object = foreground_behind_stamp_first_object + max_foreground_stamps;
const bird_hint_object = bird_object + 1;
const funny_car_first_object = bird_hint_object + 1;
const granny_object = funny_car_first_object;
const tiny_bird_first_object = bird_object;
const tiny_bird_base_tile: u10 = bird_base_tile;
const tiny_bird_palette_bank: u4 = bird_palette_bank;
const max_tiny_birds = 5;
const tiny_bird_frame_count: u8 = 2;
const tiny_bird_tiles_per_variant = tiny_bird_frame_count;
const tiny_bird_trigger_distance_x: i16 = 76;
const tiny_bird_trigger_distance_y: i16 = 64;
const granny_base_tile: u10 = foreground_stamp_base_tile;
const granny_palette_bank: u4 = bird_palette_bank;
const granny_tiles_per_frame = 16;
const granny_idle_frame_count: u16 = @intCast(granny_idle_tiles_data.len / (granny_tiles_per_frame * 32));
const granny_laugh_frame_count: u16 = @intCast(granny_laugh_tiles_data.len / (granny_tiles_per_frame * 32));
const granny_quotes_frame_count: u16 = @intCast(granny_quotes_tiles_data.len / (granny_tiles_per_frame * 32));
const granny_anim_speed = 10;
const granny_origin_offset_x: i16 = 16;
const granny_origin_offset_y: i16 = 32;
const cutscene_dialogue_first_object = falling_block_first_object;
const cutscene_dialogue_cols = 6;
const cutscene_dialogue_rows = 3;
const cutscene_dialogue_object_count = cutscene_dialogue_cols * cutscene_dialogue_rows;
const chimney_smoke_first_object = cutscene_dialogue_first_object + cutscene_dialogue_object_count;
const chimney_smoke_object_count = 3;
const cutscene_dialogue_width = cutscene_dialogue_cols * 32;
const cutscene_dialogue_height = cutscene_dialogue_rows * 16;
const cutscene_dialogue_tiles_per_object = 8;
const cutscene_dialogue_tile_count = cutscene_dialogue_object_count * cutscene_dialogue_tiles_per_object;
const cutscene_dialogue_base_tile: u10 = 848;
const cutscene_dialogue_palette_bank: u4 = dust_palette_bank;
const cutscene_dialogue_madeline_name_color: u8 = 7;
const cutscene_dialogue_granny_name_color: u8 = 8;
const cutscene_dialogue_default_name_color: u8 = 3;
const cutscene_dialogue_text_max_chars = 30;
const cutscene_dialogue_text_max_lines = 3;
const cutscene_ominous_reveal_interval_frames: u8 = 12;
const cutscene_ominous_words_per_tick: u8 = 2;
const cutscene_ominous_shake_frames: u8 = 14;
const cutscene_laugh_first_object = 93;
const cutscene_laugh_object_count = 3;
const cutscene_laugh_base_tile: u10 = 400;
const cutscene_laugh_haha_frame_count: u8 = 9;
const cutscene_laugh_tiles_per_frame: u10 = 4;
const cutscene_laugh_flash_frame_hold_frames: u8 = 8;
const cutscene_laugh_flash_cycles: u8 = 4;
const cutscene_laugh_tail_frame_hold_frames: u8 = 8;
const cutscene_laugh_flash_life_frames: u8 = cutscene_laugh_flash_frame_hold_frames * cutscene_laugh_flash_cycles * 2;
const cutscene_laugh_life_frames: u8 = cutscene_laugh_flash_life_frames + (cutscene_laugh_haha_frame_count - 2) * cutscene_laugh_tail_frame_hold_frames;
const cutscene_laugh_emit_every_frames: u8 = 36;
const cutscene_laugh_pause_frames: u8 = 112;
const cutscene_laugh_vx: i32 = 0x58;
const cutscene_laugh_vy: i32 = -0x12;
const cutscene_laugh_ay: i32 = 0;
const wire_base_tile: u10 = 208;
const wire_palette_bank: u4 = 3;
const static_wire_bg_color_index: u8 = 250;
const static_wire_bg_max_tiles = max_wire_chunks * 4;
const grass1_frame_count = 42;
const grass1_tiles_per_frame = 4;
const grass2_frame_count = 42;
const grass2_tiles_per_frame = 1;
const foreground_stamp_anim_speed = 2;
const bird_tiles_per_frame = 16;
const bird_squawk_first_frame: u16 = 0;
const bird_squawk_frame_count: u16 = 17;
const bird_peck_first_frame: u16 = 17;
const bird_peck_frame_count: u16 = 11;
const bird_liftoff_first_frame: u16 = 28;
const bird_liftoff_frame_count: u16 = 9;
const bird_fly_first_frame: u16 = 49;
const bird_fly_frame_count: u16 = 4;
const bird_anim_speed = 4;
const bird_total_frame_count: u16 = 53;
const bird_fly_speed: i32 = 0x140;
const bird_liftoff_vx: i32 = 0x90;
const bird_liftoff_vy: i32 = -0xB0;
const bird_flyaway_vx: i32 = 0x80;
const bird_flyaway_vy: i32 = -0x170;
const bird_flyaway_frames: u16 = 100;
const bird_hint_show_delay_frames: u16 = 8 * bird_anim_speed;
const bird_hold_hint_frames: u16 = 60;
const bird_hint_hide_frames: u16 = 18;
const bird_peck_cycle_frames: u16 = 180;
const bird_origin_offset_x: i16 = 5;
const bird_origin_offset_y: i16 = 9;
const max_bird_path_points = 32;
const max_bird_triggers = 8;
const max_wire_chunks = 48;
const audio_music_volume: u32 = 640;
const audio_sfx_volume: u32 = 1024;

pub const RoomBackground = struct {
    width_tiles: usize,
    height_tiles: usize,
    width_pixels: i16,
    height_pixels: i16,
    world_x: i16 = 0,
    world_y: i16 = 0,
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
    collision: []align(4) const u8,
    spawn: Spawn,
    spawn_left: Spawn,
    spawn_right: Spawn,
    spawn_top: Spawn,
    spawn_bottom: Spawn,
    falling_blocks: []align(4) const u8,
    foreground_stamps: []align(4) const u8,
    generic_stamps: []align(4) const u8,
    bird_npcs: []align(4) const u8,
    wires: []align(4) const u8,
    wire_tiles: []align(4) const u8,
    bridge_ending: []align(4) const u8,
    granny_cutscene: ?*const GrannyCutscene = null,
    parallax: ?ParallaxLayer = null,
    wind_snow_strength: u8 = 0,
    wind_snow_dir_x: i16 = -1,
    left: ?usize = null,
    right: ?usize = null,
    up: ?usize = null,
    down: ?usize = null,
};

pub const ParallaxLayer = struct {
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
    width: i16,
    height: i16,
    width_tiles: usize,
    height_tiles: usize,
    world_x: i16,
    world_y: i16,
    chunk_count: u8,
    scroll_extra_x_divisor: i16,
    scroll_extra_y_divisor: i16,
};

pub const Spawn = struct {
    x: i16,
    y: i16,
};

pub const CutsceneAnimCue = struct {
    actor: []const u8 = "",
    animation: []const u8 = "",
    mode: []const u8 = "",
};

pub const CutsceneDialoguePage = struct {
    speaker: []const u8,
    text: []const u8,
    cue: CutsceneAnimCue = .{},
    after_cue: CutsceneAnimCue = .{},
};

pub const GrannyCutscene = struct {
    trigger: SceneRect,
    granny: Spawn,
    granny_facing_left: bool,
    madeline_talk: Spawn,
    madeline_edge: Spawn,
    dialogue_box: SceneRect,
    laugh_start: Spawn,
    laugh_end: Spawn,
    laugh_text: []const u8,
    laugh_speed_px: i16,
    laugh_spawn_every_frames: u8,
    dialogue: []const CutsceneDialoguePage,
};

const Camera = struct {
    x: i16,
    y: i16,
};

const WireChunk = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    tile_offset: u16 = 0,
    phase: u8 = 0,
    sag: u8 = 0,
};

const FallingBlockState = enum(u8) {
    idle,
    shaking,
    falling,
    landed,
};

const BirdState = enum(u8) {
    inactive,
    idle,
    squawk,
    hold_hint,
    climb_hint,
    hide_hint,
    liftoff,
    peck,
    fly,
    ending_fly_in,
    ending_idle,
    done,
    gone,
};

const PlayerAnimation = enum(u8) {
    idle,
    run,
    jump,
    fall,
    wallslide,
    climb,
    dangling,
    climb_pull,
};

const PlayerDeathIntro = struct {
    first_frame: u16,
    frame_count: u16,
};

const PlayerDeathCause = enum(u8) {
    normal,
    fall_down,
};

const FootstepSurface = enum(u8) {
    snow,
    dirt,
    wood,
    car,
    asphalt,
};

const FootstepColor = struct {
    r: u5,
    g: u5,
    b: u5,
};

const footstep_asphalt_sfx = [_]u16{
    sound_ids.sfx_foot_00_asphalt_01,
    sound_ids.sfx_foot_00_asphalt_02,
    sound_ids.sfx_foot_00_asphalt_03,
    sound_ids.sfx_foot_00_asphalt_04,
    sound_ids.sfx_foot_00_asphalt_05,
    sound_ids.sfx_foot_00_asphalt_06,
    sound_ids.sfx_foot_00_asphalt_07,
};
const footstep_car_sfx = [_]u16{
    sound_ids.sfx_foot_00_car_01,
    sound_ids.sfx_foot_00_car_02,
    sound_ids.sfx_foot_00_car_03,
    sound_ids.sfx_foot_00_car_04,
    sound_ids.sfx_foot_00_car_05,
    sound_ids.sfx_foot_00_car_06,
};
const footstep_dirt_sfx = [_]u16{
    sound_ids.sfx_foot_00_dirt_01,
    sound_ids.sfx_foot_00_dirt_02,
    sound_ids.sfx_foot_00_dirt_03,
    sound_ids.sfx_foot_00_dirt_04,
    sound_ids.sfx_foot_00_dirt_05,
    sound_ids.sfx_foot_00_dirt_06,
    sound_ids.sfx_foot_00_dirt_07,
};
const footstep_snow_sfx = [_]u16{
    sound_ids.sfx_foot_00_snowsoft_01,
    sound_ids.sfx_foot_00_snowsoft_02,
    sound_ids.sfx_foot_00_snowsoft_03,
    sound_ids.sfx_foot_00_snowsoft_04,
    sound_ids.sfx_foot_00_snowsoft_05,
    sound_ids.sfx_foot_00_snowsoft_06,
    sound_ids.sfx_foot_00_snowsoft_07,
};
const footstep_wood_sfx = [_]u16{
    sound_ids.sfx_foot_00_woodwalkway_01,
    sound_ids.sfx_foot_00_woodwalkway_02,
    sound_ids.sfx_foot_00_woodwalkway_03,
    sound_ids.sfx_foot_00_woodwalkway_04,
    sound_ids.sfx_foot_00_woodwalkway_05,
    sound_ids.sfx_foot_00_woodwalkway_06,
    sound_ids.sfx_foot_00_woodwalkway_07,
};

const FallingBlock = struct {
    active: bool = false,
    state: FallingBlockState = .idle,
    x: i16 = 0,
    y: i32 = 0,
    w: u8 = 0,
    h: u8 = 0,
    max_y: i16 = 0,
    timer: u8 = 0,
    vy: i32 = 0,
};

const BridgeChunkState = enum(u8) {
    inactive,
    solid,
    shaking,
    falling,
    gone,
};

const BridgeChunk = struct {
    state: BridgeChunkState = .inactive,
    variant: u8 = bridge_empty_chunk,
    group: u8 = bridge_no_group,
    x: i16 = 0,
    y: i32 = 0,
    timer: u8 = 0,
    vy: i32 = 0,
};

pub const SceneRect = struct {
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,

    fn right(self: SceneRect) i16 {
        return self.x + self.w;
    }

    fn bottom(self: SceneRect) i16 {
        return self.y + self.h;
    }
};

const BridgeEnding = struct {
    active: bool = false,
    final_triggered: bool = false,
    platform: SceneRect = .{},
    trigger: SceneRect = .{},
    hint: SceneRect = .{},
    start_index: usize = bridge_max_chunks,
    end_index: usize = bridge_max_chunks,
};

const EndLevelTransitionPhase = enum(u8) {
    inactive,
    walk,
    camera_up,
    black,
    overworld,
};

const EndLevelTransition = struct {
    phase: EndLevelTransitionPhase = .inactive,
    timer: u8 = 0,
    start_camera: Camera = .{ .x = 0, .y = 0 },
};

const BirdPathPoint = struct {
    x: i16 = 0,
    y: i16 = 0,
};

const BirdTriggerAction = enum(u8) {
    none = 0,
    squawk_hold_hint = 1,
    show_climb_hint = 2,
    peck_then_fly = 3,
};

const BirdTrigger = struct {
    action: BirdTriggerAction = .none,
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,
};

const BirdNpc = struct {
    active: bool = false,
    state: BirdState = .inactive,
    x: i32 = 0,
    y: i32 = 0,
    home_x: i16 = 0,
    home_y: i16 = 0,
    hint_x: i16 = 0,
    hint_y: i16 = 0,
    path: [max_bird_path_points]BirdPathPoint = [_]BirdPathPoint{.{}} ** max_bird_path_points,
    triggers: [max_bird_triggers]BirdTrigger = [_]BirdTrigger{.{}} ** max_bird_triggers,
    path_count: u8 = 0,
    trigger_count: u8 = 0,
    path_index: u8 = 0,
    timer: u16 = 0,
    frame: u16 = 0,
    facing_left: bool = false,
};

const TinyBird = struct {
    active: bool = false,
    flying: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    variant: u8 = 0,
    phase: u8 = 0,
};

const GrannyCutscenePhase = enum(u8) {
    inactive,
    dialogue,
    walk_talk,
    walk_edge,
    laugh_pause,
};

const GrannyAnimation = enum(u8) {
    none,
    idle,
    laugh,
    quotes,
};

const GrannyCutsceneRuntime = struct {
    active: bool = false,
    room_index: usize = 0,
    phase: GrannyCutscenePhase = .inactive,
    dialogue_index: u8 = 0,
    dialogue_offset: usize = 0,
    dialogue_next_offset: usize = 0,
    dialogue_reveal_offset: usize = 0,
    dialogue_reveal_timer: u8 = 0,
    rendered_dialogue_index: u8 = 255,
    rendered_dialogue_offset: usize = 0xffff,
    rendered_dialogue_reveal_offset: usize = 0xffff,
    see_shake_started: bool = false,
    shake_timer: u8 = 0,
    laugh_pause_timer: u8 = 0,
    madeline_speaker_x: i16 = 0,
    madeline_speaker_y: i16 = 0,
};

const LaughHaParticle = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    ay: i32 = 0,
    age: u8 = 0,
    seed: u8 = 0,
};

const LaughTextRuntime = struct {
    active: bool = false,
    room_index: usize = 0,
    start_x: i16 = 0,
    start_y: i16 = 0,
    end_x: i16 = 0,
    end_y: i16 = 0,
    timer: u16 = 0,
    emitted: u8 = 0,
    emit_total: u8 = 0,
    follow_camera: bool = false,
    continuous: bool = false,
    particles: [cutscene_laugh_object_count]LaughHaParticle = [_]LaughHaParticle{.{}} ** cutscene_laugh_object_count,
};

const RoomState = struct {
    falling_blocks_landed: u8 = 0,
    tiny_birds_flown: bool = false,
};

const ForegroundStamp = struct {
    active: bool = false,
    kind: u8 = 0,
    x: i16 = 0,
    y: i16 = 0,
    phase: u8 = 0,
    flags: u8 = 0,
};

const FunnyCar = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    pressed: bool = false,
};

const DustParticle = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    life: u8 = 0,
    max_life: u8 = 0,
    shape: u8 = 0,
    landing: bool = false,
    snow: bool = false,
    wall: bool = false,
};

const WindSnowParticle = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    speed: i32 = 0,
    drift: i16 = 0,
    tile: u8 = 0,
    life: u8 = 0,
};

const DashAfterimage = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    life: u8 = 0,
    facing_left: bool = false,
    dir_x: i16 = 0,
    dir_y: i16 = 0,
};

const DashBurst = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    life: u8 = 0,
    flip_x: bool = false,
    flip_y: bool = false,
};

const BirdHintKind = enum(u8) {
    none,
    hold,
    climb,
    dash,
};

const HairNode = struct {
    x: i32 = 0,
    y: i32 = 0,
};

const HairAnchor = struct {
    x: i32,
    y: i32,
    dir: i16,
};

const rooms = level.rooms;
const chimney_smoke_room_index = level.roomIndexFor(level.chapter_index, "2") orelse rooms.len;
const granny_scene_room_index = level.roomIndexFor(level.chapter_index, "2") orelse rooms.len;
const granny_laugh_carry_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;
const level_one_room_index = level.roomIndexFor(level.chapter_index, "city_1") orelse rooms.len;
const tiny_bird_room_index = level.roomIndexFor(level.chapter_index, "0b") orelse rooms.len;

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}

var room_states: [rooms.len]RoomState = [_]RoomState{.{}} ** rooms.len;
var falling_blocks: [max_falling_blocks]FallingBlock = [_]FallingBlock{.{}} ** max_falling_blocks;
var falling_block_count: usize = 0;
var bridge_chunks: [bridge_max_chunks]BridgeChunk = [_]BridgeChunk{.{}} ** bridge_max_chunks;
var bridge_chunk_count: usize = 0;
var bridge_drawn_object_count: usize = 0;
var bridge_active: bool = false;
var bridge_sequence_started: bool = false;
var bridge_ending_hold: bool = false;
var bridge_ending_dash_started: bool = false;
var dash_unlocked: bool = false;
var bridge_collapse_shake_tick: u8 = 0;
var bridge_ending_start_index: usize = bridge_max_chunks;
var bridge_ending: BridgeEnding = .{};
var end_level_transition: EndLevelTransition = .{};
var foreground_stamps: [max_foreground_stamps]ForegroundStamp = [_]ForegroundStamp{.{}} ** max_foreground_stamps;
var foreground_stamp_count: usize = 0;
var funny_cars: [max_funny_cars]FunnyCar = [_]FunnyCar{.{}} ** max_funny_cars;
var funny_car_count: usize = 0;
var foreground_anim_counter: u16 = 0;
var bird_npc: BirdNpc = .{};
var tiny_birds: [max_tiny_birds]TinyBird = [_]TinyBird{.{}} ** max_tiny_birds;
var tiny_bird_count: usize = 0;
var tiny_bird_flock_triggered: bool = false;
var granny_intro_done: bool = false;
var granny_cutscene: GrannyCutsceneRuntime = .{};
var laugh_text: LaughTextRuntime = .{};
var cutscene_dialogue_visible: bool = false;
var cutscene_laugh_visible: bool = false;
var cutscene_bg_darkened: bool = false;
var cutscene_laugh_tiles_loaded: bool = false;
var current_room_index: usize = 0;
var bg_stream_room_index: usize = rooms.len;
var bg_stream_tile_x: i16 = -32768;
var bg_stream_tile_y: i16 = -32768;
var parallax_stream_room_index: usize = rooms.len;
var parallax_stream_tile_x: i16 = -32768;
var parallax_stream_tile_y: i16 = -32768;
var parallax_tile_offset: u16 = 0;
var rng_state: u16 = 0xACE1;
var dust_particles: [max_dust_particles]DustParticle = [_]DustParticle{.{}} ** max_dust_particles;
var wind_snow_visible: bool = false;
var wind_snow_particle_count: usize = 0;
var chimney_smoke_counter: u8 = 0;

const Player = struct {
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
    wall_dust_timer: u8 = 0,
    dash_timer: u8 = 0,
    dash_cooldown_timer: u8 = 0,
    dash_refill_cooldown_timer: u8 = 0,
    dash_effect_timer: u8 = 0,
    dash_trail_timer: u8 = 0,
    force_move_x: i16 = 0,
    dashes: u8 = 1,
    dash_dir_x: i16 = 0,
    dash_dir_y: i16 = 0,
    wall_slide_timer: u8 = player_wall_slide_frames,
    var_jump_speed: i32 = 0,
    stamina: i16 = player_climb_max_stamina,
    animation: PlayerAnimation = .idle,
    animation_timer: u16 = 0,
    sweat_timer: u16 = 0,
    sweat_frame: u16 = 0,
    idle_first_frame: u16 = player_idle_a_first_frame,
    idle_frame_count: u16 = player_idle_a_frame_count,
    frame: u16 = 0,
    grounded: bool = false,
    facing_left: bool = false,
    moving: bool = false,
    wall_sliding: bool = false,
    climbing: bool = false,
    climb_dangling: bool = false,
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
    hair_nodes: [hair_node_count]HairNode = [_]HairNode{.{}} ** hair_node_count,
};

var hair_pixels: [hair_sprite_size * hair_sprite_size]u8 = [_]u8{0} ** (hair_sprite_size * hair_sprite_size);
var hair_tiles: [4]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 4;
var hair_bang_pixels: [64]u8 = [_]u8{0} ** 64;
var hair_bang_tiles: [1]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 1;
var dust_tiles: [max_dust_particles]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** max_dust_particles;
var wind_snow_particles: [max_wind_snow_particles]WindSnowParticle = [_]WindSnowParticle{.{}} ** max_wind_snow_particles;
var wind_snow_tiles: [wind_snow_tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** wind_snow_tile_count;
var chimney_smoke_tiles: [chimney_smoke_tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** chimney_smoke_tile_count;
var death_burst_tiles: [6]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 6;
var dash_effect_tiles: [16]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 16;
var cutscene_dialogue_tiles: [cutscene_dialogue_tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** cutscene_dialogue_tile_count;
var dash_afterimages: [dash_afterimage_count]DashAfterimage = [_]DashAfterimage{.{}} ** dash_afterimage_count;
var dash_burst: DashBurst = .{};
var loaded_player_frame: u16 = invalid_loaded_frame;
var loaded_sweat_frame: u16 = invalid_loaded_frame;
var loaded_bird_frame: u16 = invalid_loaded_frame;
var loaded_granny_frame: u16 = invalid_loaded_frame;
var loaded_granny_animation: GrannyAnimation = .none;
var loaded_bird_hint_kind: BirdHintKind = .none;
var granny_visible: bool = false;
var debug_fps_digit_tiles: [10]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 10;
var debug_fps_last_timer: u16 = 0;
var debug_fps_tick_accum: u32 = 0;
var debug_fps_frame_count: u16 = 0;
var debug_fps_value: u8 = 0;
var wire_chunks: [max_wire_chunks]WireChunk = [_]WireChunk{.{}} ** max_wire_chunks;
var wire_chunk_count: usize = 0;
var disable_wire_drawing_for_perf_test: bool = false;
var static_wire_bg_tiles: [static_wire_bg_max_tiles]gba.display.Tile8Bpp align(4) = [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** static_wire_bg_max_tiles;
var death_origin_x: i32 = 0;
var death_origin_y: i32 = 0;
var death_player_x: i32 = 0;
var death_player_y: i32 = 0;
var death_player_facing_left: bool = false;
var death_intro_offset_x: i32 = 0;
var death_intro_offset_y: i32 = 0;
var death_intro_first_frame: u16 = 0;
var death_intro_frame_count: u16 = 0;
var death_intro_total_frames: u8 = 0;

pub export fn main() void {
    gba.mem.wait_ctrl.* = .default;
    initAudio();

    var room_index: usize = startRoomIndex();
    loadRoomBackground(room_index);
    loadFallingBlocks(room_index);
    loadForegroundStamps(room_index);
    loadFunnyCars(room_index);
    loadObjectSprites();
    loadBridge(room_index);
    loadBirdNpc(room_index);
    loadTinyBirds(room_index);
    loadRoomWires(room_index);
    loadWindSnowTiles();
    loadRoomParallax(room_index);
    initDebugFpsOverlay();
    gba.display.hideAllObjects();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 2,
        .base_screenblock = bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });
    _ = gba.display.BackgroundMap.setup(1, .{
        .priority = 0,
        .base_charblock = parallax_charblock,
        .base_screenblock = parallax_screenblock,
        .size = .size_32x32,
        .bpp = .bpp_4,
        .scroll = .init(0, 0),
    });

    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = rooms[room_index].parallax != null,
        .obj = true,
    });

    var input: gba.input.BufferedKeysState = .{};
    var player = spawnPlayer(room_index);
    var respawn = rooms[room_index].spawn;
    var camera = updateCamera(player, room_index);
    var death_timer: u8 = 0;
    var respawn_burst_timer: u8 = 0;
    resetWindSnow(room_index, camera);
    resetChimneySmoke(room_index);
    applyCamera(camera);
    updateParallaxBackground(camera, room_index);
    drawForegroundStampObjects(camera);
    drawFunnyCars(camera);
    drawBridgeObjects(camera);
    drawDashEffects(camera);
    drawPlayer(player, camera);
    drawFallingBlockObjects(camera);
    drawChimneySmoke(camera, room_index);
    drawRoomWires(camera);
    drawBirdNpc(camera);
    drawGrannyNpc(camera, room_index);
    drawTinyBirds(camera);
    drawCutsceneOverlay(camera, room_index);

    while (true) {
        input.poll();
        if (end_level_transition.phase != .inactive) {
            updateEndLevelTransition(&player, &camera, &room_index, &respawn, input);
            continue;
        }
        if (respawn_burst_timer > 0) {
            respawn_burst_timer -= 1;
            frameSync();
            if (respawn_burst_timer == 0) {
                hideDeathBurstObjects();
                updateParallaxBackground(camera, room_index);
                drawForegroundStampObjects(camera);
                drawFunnyCars(camera);
                drawFallingBlockObjects(camera);
                drawChimneySmoke(camera, room_index);
                drawRoomWires(camera);
                drawBridgeObjects(camera);
                drawGrannyNpc(camera, room_index);
                drawBirdNpc(camera);
                drawTinyBirds(camera);
                drawDashEffects(camera);
                drawHair(player, camera);
                drawPlayer(player, camera);
            } else {
                drawRespawnBurst(camera, respawn_burst_timer);
            }
            continue;
        }

        if (death_timer > 0) {
            death_timer -= 1;
            if (death_timer != 0) {
                updateFallingBlocksDuringDeath();
            }
            frameSync();
            if (death_timer == 0) {
                hideDeathBurstObjects();
                loadRoomBackground(room_index);
                loadFallingBlocks(room_index);
                loadForegroundStamps(room_index);
                loadFunnyCars(room_index);
                loadObjectSprites();
                loadBridge(room_index);
                loadBirdNpc(room_index);
                loadTinyBirds(room_index);
                loadRoomWires(room_index);
                loadRoomParallax(room_index);
                clearDustParticles();
                clearDashEffects();
                player = spawnPlayerAt(respawn);
                updateHair(&player);
                camera = updateCamera(player, room_index);
                resetWindSnow(room_index, camera);
                resetChimneySmoke(room_index);
                applyCamera(camera);
                updateParallaxBackground(camera, room_index);
                drawForegroundStampObjects(camera);
                drawFunnyCars(camera);
                drawFallingBlockObjects(camera);
                drawChimneySmoke(camera, room_index);
                drawRoomWires(camera);
                drawBridgeObjects(camera);
                drawGrannyNpc(camera, room_index);
                drawBirdNpc(camera);
                drawTinyBirds(camera);
                death_origin_x = player.x + (player_body_width / 2) * fixed_one;
                death_origin_y = player.y + (player_body_height / 2) * fixed_one;
                hideObject(player_object);
                hideObject(hair_root_object);
                hideObject(hair_object);
                hideObject(sweat_object);
                respawn_burst_timer = player_respawn_burst_frames;
                frameSync();
                gba.display.ctrl.bg0 = true;
                gba.display.ctrl.bg1 = rooms[room_index].parallax != null;
                gba.display.ctrl.obj = true;
            } else {
                drawFallingBlockObjects(camera);
                drawChimneySmoke(camera, room_index);
                drawRoomWires(camera);
                drawBridgeObjects(camera);
                drawDashEffects(camera);
                drawPlayerDeathEffect(camera, death_timer);
            }
            continue;
        }

        const cutscene_locked = updateGrannyCutscene(&player, input, room_index);
        updateLaughText(room_index, camera);

        if (cutscene_locked) {
            player.vx = 0;
            player.vy = 0;
            updatePlayerAnimation(&player);
        } else if (bridge_ending_hold) {
            const horizontal: i16 = @intCast(input.getAxisHorizontal());
            const vertical: i16 = @intCast(input.getAxisVertical());
            if (input.isJustPressed(.B) and tryStartDash(&player, horizontal, vertical, true)) {
                bridge_ending_hold = false;
                bridge_ending_dash_started = true;
                dash_unlocked = true;
                bird_npc.state = .gone;
                hideObject(bird_object);
                hideObject(bird_hint_object);
                updateDashMovement(&player, room_index);
            } else {
                holdPlayerForBridgeEnding(&player);
            }
        } else {
            updatePlayer(&player, input, room_index);
            if (updateFallingBlocks(&player)) {
                beginPlayerDeath(&death_timer, player, room_index, camera, .normal);
                continue;
            }
        }
        updateBridge(&player, room_index);
        updateBridgeCollapseShake(room_index, player.grounded);
        updateFunnyCars(player);
        updateBirdNpc(player, camera);
        updateTinyBirds(player, room_index);
        updateHair(&player);
        updateDustParticles();
        updateDashEffects();
        const next_camera = updateCamera(player, room_index);
        updateWindSnow(room_index, next_camera);
        updateChimneySmoke(room_index);
        foreground_anim_counter +%= 1;
        if (!cutscene_locked and !bridge_ending_hold and shouldStartEndLevelTransition(player, room_index)) {
            camera = next_camera;
            startEndLevelTransition(&player, camera);
            continue;
        }
        if (!cutscene_locked and !bridge_ending_hold and shouldStartBridgeEndingHold(player, room_index)) {
            startBridgeEndingHold(&player);
        }
        if (!cutscene_locked and !bridge_ending_hold and playerTouchingSpike(player, room_index)) {
            beginPlayerDeath(&death_timer, player, room_index, next_camera, .normal);
            continue;
        }
        if (!cutscene_locked and !bridge_ending_hold and playerInDeathPit(player, room_index)) {
            beginPlayerDeath(&death_timer, player, room_index, next_camera, .fall_down);
            continue;
        }
        const previous_room_index = room_index;
        if (!cutscene_locked and !bridge_ending_hold and trySwitchRoom(&player, input, &room_index, &respawn)) {
            handleLaughTextRoomTransition(previous_room_index, room_index);
            gba.display.bg_palette.colors[0] = .black;
            gba.display.ctrl.bg0 = false;
            gba.display.ctrl.bg1 = false;
            gba.display.ctrl.obj = false;
            gba.display.hideAllObjects();
            frameSync();
            loadRoomBackground(room_index);
            loadFallingBlocks(room_index);
            loadForegroundStamps(room_index);
            loadFunnyCars(room_index);
            loadObjectSprites();
            loadBridge(room_index);
            loadBirdNpc(room_index);
            loadTinyBirds(room_index);
            loadRoomWires(room_index);
            loadRoomParallax(room_index);
            resetGrannyCutsceneOnRoomLoad();
            clearDustParticles();
            clearDashEffects();
            player.hair_initialized = false;
            updateHair(&player);
            camera = updateCamera(player, room_index);
            resetWindSnow(room_index, camera);
            resetChimneySmoke(room_index);
            applyCamera(camera);
            updateParallaxBackground(camera, room_index);
            drawForegroundStampObjects(camera);
            drawFunnyCars(camera);
            drawBridgeObjects(camera);
            drawDashEffects(camera);
            drawHair(player, camera);
            drawDust(camera);
            drawWindSnow(camera);
            drawPlayer(player, camera);
            drawSweat(&player, camera);
            drawFallingBlockObjects(camera);
            drawChimneySmoke(camera, room_index);
            drawRoomWires(camera);
            drawBirdNpc(camera);
            drawGrannyNpc(camera, room_index);
            drawTinyBirds(camera);
            drawCutsceneOverlay(camera, room_index);
            frameSync();
            gba.display.ctrl.bg0 = true;
            gba.display.ctrl.bg1 = rooms[room_index].parallax != null;
            gba.display.ctrl.obj = true;
            continue;
        }
        camera = next_camera;
        const render_camera = renderCameraWithCutsceneShake(camera, room_index);
        frameSync();
        applyCamera(render_camera);
        updateParallaxBackground(render_camera, room_index);
        drawForegroundStampObjects(render_camera);
        drawFunnyCars(render_camera);
        drawFallingBlockObjects(render_camera);
        drawChimneySmoke(render_camera, room_index);
        drawRoomWires(render_camera);
        drawBridgeObjects(render_camera);
        drawBirdNpc(render_camera);
        drawGrannyNpc(render_camera, room_index);
        drawTinyBirds(render_camera);
        drawDashEffects(render_camera);
        drawHair(player, render_camera);
        drawDust(render_camera);
        drawWindSnow(render_camera);
        drawPlayer(player, render_camera);
        drawSweat(&player, render_camera);
        drawCutsceneOverlay(render_camera, room_index);
    }
}

fn startRoomIndex() usize {
    return comptime blk: {
        if (build_options.start_room.len == 0) break :blk level.start_room_index;
        if (build_options.start_chapter == 1 and textEquals(build_options.start_room, "1")) {
            break :blk level.roomIndexFor(level.chapter_index, "city_1") orelse
                @compileError("invalid development start override; level 1 room 1 is not generated");
        }
        break :blk level.roomIndexFor(build_options.start_chapter, build_options.start_room) orelse
            @compileError("invalid development start override; expected: <chapter> <room>, for example: 0 -1 or 1 1");
    };
}

fn frameSync() void {
    mm.gba.frame();
    gba.bios.vblankIntrWait();
    updateDebugFpsOverlay();
}

fn initAudio() void {
    gba.interrupt.init();
    gba.interrupt.isr_default_redirect = audioVBlankHandler;
    mm.gba.initDefault(@ptrCast(@constCast(&prologue_soundbank_data[0])), 32) catch unreachable;
    mm.sfx.setEffectsVolume(audio_sfx_volume);
}

fn audioVBlankHandler(_: gba.interrupt.InterruptFlags) callconv(.c) void {
    mm.mixer.vBlank();
}

fn initDebugFpsOverlay() void {
    if (!debug_fps_enabled) return;

    debug_fps_digit_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 10;
    const rows = [_][7]u8{
        .{ 0b11111, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b11111 },
        .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        .{ 0b11110, 0b00001, 0b00001, 0b11110, 0b10000, 0b10000, 0b11111 },
        .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 },
        .{ 0b10010, 0b10010, 0b10010, 0b11111, 0b00010, 0b00010, 0b00010 },
        .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110 },
        .{ 0b01111, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
        .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
        .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
        .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b11110 },
    };
    for (rows, 0..) |digit_rows, digit| {
        for (digit_rows, 0..) |row, y| {
            var x: usize = 0;
            while (x < 5) : (x += 1) {
                if ((row & (@as(u8, 1) << @intCast(4 - x))) != 0) {
                    setDebugFpsDigitPixel(digit, @intCast(x + 1), @intCast(y), 1);
                }
            }
        }
    }
    gba.display.memcpyObjectTiles4Bpp(debug_fps_base_tile, &debug_fps_digit_tiles);
    gba.timers[debug_fps_timer_index] = gba.Timer.init(0, .{});
    gba.timers[debug_fps_timer_index] = gba.Timer.init(0, .{
        .freq = .cycles_1024,
        .enable = true,
    });
    debug_fps_last_timer = gba.timers[debug_fps_timer_index].counter;
}

fn updateDebugFpsOverlay() void {
    if (!debug_fps_enabled) return;

    const current = gba.timers[debug_fps_timer_index].counter;
    const delta = current -% debug_fps_last_timer;
    debug_fps_last_timer = current;
    debug_fps_tick_accum += delta;
    debug_fps_frame_count += 1;
    while (debug_fps_tick_accum >= debug_fps_ticks_per_second) {
        debug_fps_tick_accum -= debug_fps_ticks_per_second;
        debug_fps_value = @intCast(@min(debug_fps_frame_count, 99));
        debug_fps_frame_count = 0;
    }

    drawDebugFpsDigit(0, debug_fps_value / 10);
    drawDebugFpsDigit(1, debug_fps_value % 10);
}

fn drawDebugFpsDigit(slot: usize, digit: u8) void {
    gba.display.objects[debug_fps_first_object + slot] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(screen_width - 16 + @as(i16, @intCast(slot * 8))),
        .y = objY(0),
        .base_tile = debug_fps_base_tile + @as(u10, digit),
        .priority = 0,
        .palette = debug_fps_palette_bank,
    });
}

fn setDebugFpsDigitPixel(digit: usize, x: u8, y: u8, color: u8) void {
    const byte_index = @as(usize, y) * 4 + @as(usize, x) / 2;
    if ((x & 1) == 0) {
        debug_fps_digit_tiles[digit].data_8[byte_index] = (debug_fps_digit_tiles[digit].data_8[byte_index] & 0xf0) | color;
    } else {
        debug_fps_digit_tiles[digit].data_8[byte_index] = (debug_fps_digit_tiles[digit].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn loadRoomBackground(room_index: usize) void {
    current_room_index = room_index;
    bg_stream_room_index = rooms.len;
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.bg_palette.colors[static_wire_bg_color_index] = gba.ColorRgb555.rgb(13, 14, 18);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
    cutscene_bg_darkened = false;
}

fn setGrannyCutsceneDarkened(room_index: usize, enabled: bool) void {
    if (cutscene_bg_darkened == enabled) return;
    cutscene_bg_darkened = enabled;
    applyRoomPaletteWithCutsceneMood(room_index, enabled);
}

fn applyRoomPaletteWithCutsceneMood(room_index: usize, dark: bool) void {
    const room = rooms[room_index];
    const color_count = @min(room.palette.len / 2, @as(usize, 256));
    var index: usize = 0;
    while (index < color_count) : (index += 1) {
        const color: gba.ColorRgb555 = @bitCast(readU16Le(room.palette, index * 2));
        gba.display.bg_palette.colors[index] = if (dark) darkenCutsceneColor(color) else color;
    }
    gba.display.bg_palette.colors[static_wire_bg_color_index] = if (dark)
        darkenCutsceneColor(gba.ColorRgb555.rgb(13, 14, 18))
    else
        gba.ColorRgb555.rgb(13, 14, 18);
}

fn darkenCutsceneColor(color: gba.ColorRgb555) gba.ColorRgb555 {
    const r: u8 = @intCast(color.r);
    const g: u8 = @intCast(color.g);
    const b: u8 = @intCast(color.b);
    return gba.ColorRgb555.rgb(
        @intCast(@divTrunc(r * 2, 3)),
        @intCast(@divTrunc(g * 2, 3)),
        @intCast(@divTrunc(b * 2, 3)),
    );
}

fn loadFallingBlocks(room_index: usize) void {
    falling_blocks = [_]FallingBlock{.{}} ** max_falling_blocks;
    falling_block_count = 0;
    hideFallingBlockObjects();

    const data = rooms[room_index].falling_blocks;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_falling_blocks);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + 10 <= data.len) : ({
        source_index += 1;
        source_offset += 10;
    }) {
        const x = readI16Le(data, source_offset);
        const y = readI16Le(data, source_offset + 2);
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        const max_y = readI16Le(data, source_offset + 6);
        if (w == 0 or h == 0) continue;

        var block = FallingBlock{
            .active = true,
            .x = x,
            .y = pixelToFixed(y),
            .w = w,
            .h = h,
            .max_y = max_y - @as(i16, @intCast(h)),
        };

        if (roomFallingBlockLanded(room_index, falling_block_count)) {
            block.y = pixelToFixed(block.max_y);
            block.vy = 0;
            block.state = .landed;
        }

        falling_blocks[falling_block_count] = block;
        falling_block_count += 1;
    }
}

fn loadBridge(room_index: usize) void {
    bridge_chunks = [_]BridgeChunk{.{}} ** bridge_max_chunks;
    bridge_chunk_count = 0;
    bridge_drawn_object_count = 0;
    bridge_active = isPrologueEndRoom(room_index);
    bridge_sequence_started = false;
    bridge_ending_hold = false;
    bridge_ending_dash_started = false;
    bridge_collapse_shake_tick = 0;
    bridge_ending_start_index = bridge_max_chunks;
    bridge_ending = .{};
    end_level_transition = .{};
    hideBridgeObjects();
    if (!bridge_active) return;

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bridge_palette_bank) * 16], @ptrCast(&bridge_palette_data), 16);
    loadDarkBridgePalette();
    gba.display.memcpyObjectTiles4Bpp(bridge_base_tile, @ptrCast(&bridge_tiles_data));

    if (bridge_layout_data.len < 2) return;
    const count = @min(readU16Le(&bridge_layout_data, 0), bridge_max_chunks);
    var index: usize = 0;
    while (index < count and 2 + index < bridge_layout_data.len) : (index += 1) {
        const variant = bridge_layout_data[2 + index];
        if (variant != bridge_empty_chunk) {
            const group = if (bridge_groups_data.len >= 2 + count and 2 + index < bridge_groups_data.len)
                bridge_groups_data[2 + index]
            else
                bridge_no_group;
            bridge_chunks[index] = .{
                .state = .solid,
                .variant = variant,
                .group = group,
                .x = bridge_world_x + @as(i16, @intCast(index * bridge_chunk_width)),
                .y = pixelToFixed(bridge_world_y),
            };
        }
    }
    bridge_chunk_count = count;
    bridge_ending_start_index = finalBridgePlatformStart();
    loadBridgeEnding(room_index);
}

fn loadBridgeEnding(room_index: usize) void {
    const data = rooms[room_index].bridge_ending;
    if (data.len < 26 or readU16Le(data, 0) == 0) return;

    const platform = readSceneRect(data, 2);
    const trigger = readSceneRect(data, 10);
    const hint = readSceneRect(data, 18);
    if (platform.w <= 0 or platform.h <= 0 or trigger.w <= 0 or trigger.h <= 0) return;

    const start = bridge_ending_start_index;
    if (start >= bridge_chunk_count) return;
    const platform_chunks: usize = @intCast(@max(1, @divTrunc(platform.w + bridge_chunk_width - 1, bridge_chunk_width)));
    const end = @min(bridge_chunk_count - 1, start + platform_chunks - 1);
    const actual_chunks = end - start + 1;
    const platform_width: i16 = @intCast(actual_chunks * bridge_chunk_width);
    const platform_x = platform.right() - platform_width;
    const gap_left = platform_x - bridge_ending_gap_chunks * bridge_chunk_width;
    const platform_right = platform_x + platform_width;

    var index = start;
    while (index <= end) : (index += 1) {
        bridge_chunks[index].x = platform_x + @as(i16, @intCast((index - start) * bridge_chunk_width));
        bridge_chunks[index].y = pixelToFixed(platform.y);
    }

    index = 0;
    while (index < bridge_chunk_count) : (index += 1) {
        if (index >= start and index <= end) continue;
        const chunk_right = bridge_chunks[index].x + bridge_chunk_width;
        if (chunk_right > gap_left and bridge_chunks[index].x < platform_right) {
            bridge_chunks[index].state = .inactive;
            bridge_chunks[index].variant = bridge_empty_chunk;
            bridge_chunks[index].group = bridge_no_group;
        }
    }

    bridge_ending = .{
        .active = true,
        .platform = .{ .x = platform_x, .y = platform.y, .w = platform_width, .h = platform.h },
        .trigger = trigger,
        .hint = hint,
        .start_index = start,
        .end_index = end,
    };
}

fn readSceneRect(data: []align(4) const u8, offset: usize) SceneRect {
    return .{
        .x = readI16Le(data, offset),
        .y = readI16Le(data, offset + 2),
        .w = readI16Le(data, offset + 4),
        .h = readI16Le(data, offset + 6),
    };
}

fn finalBridgePlatformStart() usize {
    var index = bridge_chunk_count;
    while (index > 0) {
        index -= 1;
        const chunk = bridge_chunks[index];
        if (chunk.state == .inactive or chunk.variant == bridge_empty_chunk) continue;
        break;
    }
    while (index > 0) {
        index -= 1;
        const chunk = bridge_chunks[index];
        if (chunk.state == .inactive or chunk.variant == bridge_empty_chunk) return index + 1;
    }
    return 0;
}

fn loadDarkBridgePalette() void {
    const source: [*]align(2) const gba.ColorRgb555 = @ptrCast(&bridge_palette_data);
    var index: usize = 0;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[@as(usize, bridge_falling_palette_bank) * 16 + index] = darkenBridgeColor(source[index]);
    }
}

fn darkenBridgeColor(color: gba.ColorRgb555) gba.ColorRgb555 {
    return gba.ColorRgb555.rgb(
        @intCast(@as(u8, color.r) / 2),
        @intCast(@as(u8, color.g) / 2),
        @intCast(@as(u8, color.b) / 2),
    );
}

fn loadForegroundStamps(room_index: usize) void {
    foreground_stamps = [_]ForegroundStamp{.{}} ** max_foreground_stamps;
    foreground_stamp_count = 0;
    hideForegroundStampObjects();

    const data = rooms[room_index].foreground_stamps;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_foreground_stamps);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + 8 <= data.len) : ({
        source_index += 1;
        source_offset += 8;
    }) {
        foreground_stamps[foreground_stamp_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
            .kind = data[source_offset + 4],
            .phase = data[source_offset + 5],
            .flags = data[source_offset + 6],
        };
        foreground_stamp_count += 1;
    }
}

fn loadFunnyCars(room_index: usize) void {
    funny_cars = [_]FunnyCar{.{}} ** max_funny_cars;
    funny_car_count = 0;
    hideFunnyCars();

    const data = rooms[room_index].generic_stamps;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_funny_cars);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + 8 <= data.len) : ({
        source_index += 1;
        source_offset += 8;
    }) {
        const kind = data[source_offset + 7];
        if (kind != 0) continue;
        funny_cars[funny_car_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
        };
        funny_car_count += 1;
        if (funny_car_count >= max_funny_cars) break;
    }
}

fn loadBirdNpc(room_index: usize) void {
    bird_npc = .{};
    hideObject(bird_object);
    hideObject(bird_hint_object);

    const data = rooms[room_index].bird_npcs;
    if (data.len < 2 or readU16Le(data, 0) == 0) return;
    if (data.len < 12) return;

    bird_npc = .{
        .active = true,
        .state = .idle,
        .home_x = readI16Le(data, 2),
        .home_y = readI16Le(data, 4),
        .hint_x = readI16Le(data, 6),
        .hint_y = readI16Le(data, 8),
        .x = pixelToFixed(readI16Le(data, 2)),
        .y = pixelToFixed(readI16Le(data, 4)),
        .path_count = @min(data[10], max_bird_path_points),
        .trigger_count = @min(data[11], max_bird_triggers),
        .facing_left = true,
    };

    var offset: usize = 12;
    var index: usize = 0;
    while (index < bird_npc.path_count and offset + 4 <= data.len) : ({
        index += 1;
        offset += 4;
    }) {
        bird_npc.path[index] = .{
            .x = readI16Le(data, offset),
            .y = readI16Le(data, offset + 2),
        };
    }
    while (index < data[10] and offset + 4 <= data.len) : ({
        index += 1;
        offset += 4;
    }) {}

    index = 0;
    while (index < bird_npc.trigger_count and offset + 10 <= data.len) : ({
        index += 1;
        offset += 10;
    }) {
        bird_npc.triggers[index] = .{
            .action = birdTriggerActionFromByte(data[offset]),
            .x = readI16Le(data, offset + 2),
            .y = readI16Le(data, offset + 4),
            .w = readI16Le(data, offset + 6),
            .h = readI16Le(data, offset + 8),
        };
    }

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bird_palette_bank) * 16], @ptrCast(&bird_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bird_hint_palette_bank) * 16], @ptrCast(&bird_hint_palette_data), 16);
    loaded_bird_frame = invalid_loaded_frame;
    loaded_bird_hint_kind = .none;
}

fn loadTinyBirds(room_index: usize) void {
    tiny_birds = [_]TinyBird{.{}} ** max_tiny_birds;
    tiny_bird_count = 0;
    tiny_bird_flock_triggered = false;
    hideTinyBirds();

    if (room_index != tiny_bird_room_index or room_states[room_index].tiny_birds_flown) return;

    const starts = [_]struct {
        x: i16,
        y: i16,
        variant: u8,
        vx: i32,
        vy: i32,
    }{
        .{ .x = 267, .y = 112, .variant = 0, .vx = -0x34, .vy = -0x128 },
        .{ .x = 275, .y = 112, .variant = 2, .vx = 0x20, .vy = -0x154 },
        .{ .x = 252, .y = 120, .variant = 1, .vx = -0x58, .vy = -0x118 },
        .{ .x = 307, .y = 144, .variant = 3, .vx = 0x64, .vy = -0x13C },
        .{ .x = 235, .y = 152, .variant = 4, .vx = -0x74, .vy = -0x108 },
    };

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, tiny_bird_palette_bank) * 16], @ptrCast(&tiny_bird_palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(tiny_bird_base_tile, @ptrCast(&tiny_bird_tiles_data));
    loaded_bird_frame = invalid_loaded_frame;

    var index: usize = 0;
    while (index < starts.len and index < max_tiny_birds) : (index += 1) {
        tiny_birds[index] = .{
            .active = true,
            .x = pixelToFixed(starts[index].x),
            .y = pixelToFixed(starts[index].y),
            .vx = starts[index].vx,
            .vy = starts[index].vy,
            .variant = starts[index].variant,
            .phase = @intCast(index * 5),
        };
        tiny_bird_count += 1;
    }
}

fn loadRoomWires(room_index: usize) void {
    wire_chunks = [_]WireChunk{.{}} ** max_wire_chunks;
    wire_chunk_count = 0;
    hideRoomWires();

    const room = rooms[room_index];
    const data = room.wires;
    if (data.len < 2) return;
    if (roomFitsHardwareBackground(room) and canStampStaticRoomWires(room_index)) return;

    if (room.wire_tiles.len != 0) {
        const tile_count = room.wire_tiles.len / 32;
        const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(room.wire_tiles.ptr);
        gba.display.memcpyObjectTiles4Bpp(wire_base_tile, tiles[0..tile_count]);
    }

    const count = @min(readU16Le(data, 0), max_wire_chunks);
    var offset: usize = 2;
    var index: usize = 0;
    while (index < count and offset + 8 <= data.len) : ({
        index += 1;
        offset += 8;
    }) {
        wire_chunks[wire_chunk_count] = .{
            .active = true,
            .x = readI16Le(data, offset),
            .y = readI16Le(data, offset + 2),
            .tile_offset = readU16Le(data, offset + 4),
            .phase = data[offset + 6],
        };
        wire_chunk_count += 1;
    }
}

fn birdTriggerActionFromByte(value: u8) BirdTriggerAction {
    return switch (value) {
        1 => .squawk_hold_hint,
        2 => .show_climb_hint,
        3 => .peck_then_fly,
        else => .none,
    };
}

fn loadRoomParallax(room_index: usize) void {
    clearParallaxMap();
    parallax_stream_room_index = rooms.len;
    gba.display.ctrl.bg1 = false;
    if (rooms[room_index].parallax) |parallax| {
        gba.mem.memcpy16(&gba.display.bg_palette.colors[@as(usize, 15) * 16], @ptrCast(parallax.palette.ptr), 16);
        const tile_count = parallax.tiles.len / 32;
        const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(parallax.tiles.ptr);
        const charblock3_start_bytes: usize = 3 * 16 * 1024;
        const used_bg_bytes = rooms[room_index].tiles.len;
        const tile_offset_bytes = if (used_bg_bytes > charblock3_start_bytes) used_bg_bytes - charblock3_start_bytes else 0;
        parallax_tile_offset = @intCast((tile_offset_bytes + 31) / 32);
        gba.display.memcpyTiles4Bpp(parallax_charblock, parallax_tile_offset, tiles[0..tile_count]);
        gba.display.ctrl.bg1 = true;
    }
}

fn loadObjectSprites() void {
    invalidateObjectTileCaches();
    granny_visible = false;
    cutscene_laugh_tiles_loaded = false;
    gba.mem.memcpy(gba.display.obj_palette, &player_palette_data, player_palette_data.len);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[16], @ptrCast(&falling_block_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[32], @ptrCast(&hair_palette_data), 16);
    loadDashPalettes();
    gba.display.obj_palette.colors[48] = .black;
    gba.display.obj_palette.colors[49] = .white;
    gba.display.obj_palette.colors[50] = gba.ColorRgb555.rgb(17, 27, 31);
    gba.display.obj_palette.colors[51] = gba.ColorRgb555.rgb(29, 4, 4);
    gba.display.obj_palette.colors[52] = gba.ColorRgb555.rgb(17, 2, 3);
    gba.display.obj_palette.colors[53] = .black;
    gba.display.obj_palette.colors[54] = gba.ColorRgb555.rgb(6, 7, 10);
    gba.display.obj_palette.colors[55] = gba.ColorRgb555.rgb(15, 21, 31);
    gba.display.obj_palette.colors[56] = gba.ColorRgb555.rgb(31, 24, 9);
    gba.display.obj_palette.colors[@as(usize, dust_palette_bank) * 16 + @as(usize, chimney_smoke_soft_color)] = gba.ColorRgb555.rgb(25, 28, 29);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[64], @ptrCast(&player_sweat_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, foreground_stamp_palette_bank) * 16], @ptrCast(&grass1_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, foreground_stamp2_palette_bank) * 16], @ptrCast(&grass2_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, funny_car_palette_bank) * 16], @ptrCast(&funny_car_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, granny_palette_bank) * 16], @ptrCast(&granny_palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(falling_block_base_tile, @ptrCast(&falling_block_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(funny_car_base_tile, @ptrCast(&funny_car_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp_base_tile, @ptrCast(&grass1_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp_mirror_base_tile, @ptrCast(&grass1_mirror_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp2_base_tile, @ptrCast(&grass2_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp2_mirror_base_tile, @ptrCast(&grass2_mirror_tiles_data));
    loadDeathBurstTile();
    loadDashEffectTile();
    loadPlayerFrame(0);
}

fn invalidateObjectTileCaches() void {
    loaded_player_frame = invalid_loaded_frame;
    loaded_sweat_frame = invalid_loaded_frame;
    loaded_bird_frame = invalid_loaded_frame;
    loaded_granny_frame = invalid_loaded_frame;
    loaded_granny_animation = .none;
    loaded_bird_hint_kind = .none;
}

fn loadDashPalettes() void {
    fillDashShadowPalette(dash_shadow_palette_bank, gba.ColorRgb555.rgb(2, 8, 15), gba.ColorRgb555.rgb(5, 17, 25), gba.ColorRgb555.rgb(8, 22, 31));
    fillDashShadowPalette(dash_shadow_palette_bank + 1, gba.ColorRgb555.rgb(3, 11, 19), gba.ColorRgb555.rgb(6, 20, 29), gba.ColorRgb555.rgb(10, 25, 31));
    fillDashShadowPalette(dash_shadow_palette_bank + 2, gba.ColorRgb555.rgb(5, 15, 24), gba.ColorRgb555.rgb(9, 24, 31), gba.ColorRgb555.rgb(14, 28, 31));

    const effect_base = @as(usize, dash_effect_palette_bank) * 16;
    gba.display.obj_palette.colors[effect_base] = .black;
    gba.display.obj_palette.colors[effect_base + 1] = gba.ColorRgb555.rgb(2, 10, 18);
    gba.display.obj_palette.colors[effect_base + 2] = gba.ColorRgb555.rgb(5, 20, 30);
    gba.display.obj_palette.colors[effect_base + 3] = .white;
    gba.display.obj_palette.colors[effect_base + 4] = gba.ColorRgb555.rgb(11, 27, 31);
}

fn fillDashShadowPalette(bank: u4, dark: gba.ColorRgb555, mid: gba.ColorRgb555, light: gba.ColorRgb555) void {
    const shadow_base = @as(usize, bank) * 16;
    gba.display.obj_palette.colors[shadow_base] = .black;
    var index: usize = 0;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[shadow_base + index] = if (index == 1)
            dark
        else if (index < 5)
            mid
        else
            light;
    }
}

fn loadDeathBurstTile() void {
    death_burst_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 6;
    drawDeathBurstDisc(0, 3, 3, 3, 5);
    drawDeathBurstDisc(0, 3, 3, 2, 1);
    setDeathBurstTilePixel(0, 1, 2, 1);
    setDeathBurstTilePixel(0, 2, 1, 1);
    setDeathBurstTilePixel(0, 4, 1, 1);
    setDeathBurstTilePixel(0, 5, 2, 1);
    setDeathBurstTilePixel(0, 1, 4, 1);
    setDeathBurstTilePixel(0, 2, 5, 1);
    setDeathBurstTilePixel(0, 4, 5, 1);
    setDeathBurstTilePixel(0, 5, 4, 1);
    setDeathBurstTilePixel(0, 5, 3, 2);

    drawDeathBurstDisc(1, 3, 3, 3, 5);
    drawDeathBurstDisc(1, 3, 3, 2, 3);
    setDeathBurstTilePixel(1, 1, 2, 3);
    setDeathBurstTilePixel(1, 2, 1, 3);
    setDeathBurstTilePixel(1, 4, 1, 3);
    setDeathBurstTilePixel(1, 5, 2, 3);
    setDeathBurstTilePixel(1, 1, 4, 3);
    setDeathBurstTilePixel(1, 2, 5, 3);
    setDeathBurstTilePixel(1, 4, 5, 3);
    setDeathBurstTilePixel(1, 5, 4, 3);
    setDeathBurstTilePixel(1, 4, 4, 4);

    drawDeathBurstBlob16(2, 1);
    drawDeathBurstBlob16(2, 3);
    setDeathBurstPixel16(2, 8, 8, 4);
    setDeathBurstPixel16(2, 9, 8, 4);
    gba.display.memcpyObjectTiles4Bpp(death_burst_base_tile, &death_burst_tiles);
}

fn loadDashEffectTile() void {
    writeDashEffectTile(0, 0);
}

fn writeDashEffectTile(dir_x: i16, dir_y: i16) void {
    dash_effect_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 16;

    const sx: i16 = if (dir_x == 0 and dir_y == 0) 1 else dir_x;
    const sy: i16 = dir_y;
    const back_x = -sx;
    const back_y = -sy;
    const perp_x = -sy;
    const perp_y = sx;
    const center_x: i16 = 16;
    const center_y: i16 = 18;

    drawDashEffectDisc(center_x + back_x * 4, center_y + back_y * 4, 5, 1);
    drawDashEffectDisc(center_x + back_x * 4, center_y + back_y * 4, 4, 2);
    drawDashEffectDisc(center_x + back_x * 8 + perp_x * 2, center_y + back_y * 6 + perp_y * 2, 3, 2);
    drawDashEffectDisc(center_x + back_x + perp_x * 3, center_y + back_y + perp_y * 2, 2, 4);
    drawDashEffectDisc(center_x + back_x * 11 - perp_x * 2, center_y + back_y * 8 - perp_y, 2, 4);
    setDashEffectPixel(center_x + back_x * 13 + perp_x * 4, center_y + back_y * 9 + perp_y * 3, 4);
    setDashEffectPixel(center_x + back_x * 10 - perp_x * 4, center_y + back_y * 7 - perp_y * 3, 2);

    if (dir_x != 0 or dir_y != 0) {
        drawDashEffectStreak(dir_x, dir_y);
    }
    gba.display.memcpyObjectTiles4Bpp(dash_effect_base_tile, &dash_effect_tiles);
}

fn drawDashEffectStreak(dir_x: i16, dir_y: i16) void {
    const center_x: i16 = 16;
    const center_y: i16 = 18;
    const tail: i16 = 18;
    const tip: i16 = 5;
    const perp_x: i16 = -dir_y;
    const perp_y: i16 = dir_x;
    const start_x = center_x - dir_x * tail;
    const start_y = center_y - dir_y * tail;
    const end_x = center_x + dir_x * tip;
    const end_y = center_y + dir_y * tip;
    drawDashEffectLine(start_x, start_y, end_x, end_y, 3);
    drawDashEffectLine(start_x + perp_x, start_y + perp_y, end_x + perp_x, end_y + perp_y, 3);
    setDashEffectPixel(start_x + perp_x * 4, start_y + perp_y * 4, 3);
}

fn drawDashEffectDisc(center_x: i16, center_y: i16, radius: i16, color: u8) void {
    var y: i16 = -radius;
    while (y <= radius) : (y += 1) {
        var x: i16 = -radius;
        while (x <= radius) : (x += 1) {
            if (x * x + y * y <= radius * radius) {
                setDashEffectPixel(center_x + x, center_y + y, color);
            }
        }
    }
}

fn drawDashEffectLine(x0_input: i16, y0_input: i16, x1: i16, y1: i16, color: u8) void {
    var x0 = x0_input;
    var y0 = y0_input;
    const dx = absI16(x1 - x0);
    const sx: i16 = if (x0 < x1) 1 else -1;
    const dy = -absI16(y1 - y0);
    const sy: i16 = if (y0 < y1) 1 else -1;
    var err = dx + dy;
    while (true) {
        setDashEffectPixel(x0, y0, color);
        setDashEffectPixel(x0 + 1, y0, color);
        if (x0 == x1 and y0 == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y0 += sy;
        }
    }
}

fn setDashEffectPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= 32 or y < 0 or y >= 32) return;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    const tile_index = tile_y * 4 + tile_x;
    const local_x: usize = @intCast(x & 7);
    const local_y: usize = @intCast(y & 7);
    const byte_index = local_y * 4 + local_x / 2;
    if ((local_x & 1) == 0) {
        dash_effect_tiles[tile_index].data_8[byte_index] = (dash_effect_tiles[tile_index].data_8[byte_index] & 0xF0) | color;
    } else {
        dash_effect_tiles[tile_index].data_8[byte_index] = (dash_effect_tiles[tile_index].data_8[byte_index] & 0x0F) | (color << 4);
    }
}

fn loadWindSnowTiles() void {
    wind_snow_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** wind_snow_tile_count;
    setWindSnowPixel(0, 3, 3, 1);

    setWindSnowPixel(1, 2, 4, 1);

    setWindSnowPixel(2, 4, 2, 1);

    setWindSnowPixel(3, 2, 2, 1);
    setWindSnowPixel(3, 3, 2, 1);

    setWindSnowPixel(4, 3, 3, 1);
    setWindSnowPixel(4, 4, 3, 1);

    setWindSnowPixel(5, 2, 4, 1);
    setWindSnowPixel(5, 3, 3, 1);

    setWindSnowPixel(6, 4, 2, 1);
    setWindSnowPixel(6, 3, 3, 1);

    setWindSnowPixel(7, 1, 4, 1);
    setWindSnowPixel(7, 3, 4, 1);

    gba.display.memcpyObjectTiles4Bpp(wind_snow_base_tile, &wind_snow_tiles);
}

fn loadPlayerFrame(frame: u16) void {
    if (loaded_player_frame == frame) return;
    const byte_offset = @as(usize, frame) * player_tiles_per_frame * 32;
    const byte_len = player_tiles_per_frame * 32;
    const frame_bytes = player_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(@alignCast(frame_bytes)));
    loaded_player_frame = frame;
}

fn loadSweatFrame(frame: u16) void {
    if (loaded_sweat_frame == frame) return;
    const byte_offset = @as(usize, frame) * sweat_tiles_per_frame * 32;
    const byte_len = sweat_tiles_per_frame * 32;
    const frame_bytes = player_sweat_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(sweat_base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_sweat_frame = frame;
}

fn updatePlayer(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    const was_grounded = player.grounded;
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

    if (player.grounded and player.dash_timer == 0 and player.dash_refill_cooldown_timer == 0) {
        refillPlayerDash(player);
    }

    if (player.climb_ledge_timer > 0) {
        updateClimbLedgeMotion(player, room_index);
        updatePlayerAnimation(player);
        return;
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
    if (horizontal != 0) {
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
    const wall_jump_dir = wallJumpDirection(player.*, horizontal, room_index);
    var jumped_this_frame = false;

    if (player.jump_buffer_timer > 0 and player.coyote_timer > 0) {
        if (player.grounded) {
            releaseFunnyCarAtPlayer(player.*);
        }
        spawnJumpDustAtFeet(player.*);
        player.vy = player_jump_speed;
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
        }
    } else if (player.jump_buffer_timer > 0 and player.climbing and climb_wall_dir != 0 and horizontal != -climb_wall_dir and player.stamina > 0) {
        spawnJumpDustAtFeet(player.*);
        player.stamina = @max(0, player.stamina - player_climb_jump_cost);
        player.vx = @as(i32, -climb_wall_dir) * (player_wall_jump_h_speed / 2);
        player.vy = player_wall_jump_speed;
        player.force_move_x = -climb_wall_dir;
        player.force_move_x_timer = player_wall_jump_force_frames / 2;
        player.apex_hang_disabled_timer = player_var_jump_frames + 8;
        player.var_jump_speed = player.vy;
        player.var_jump_timer = player_wall_jump_var_jump_frames;
        player.jump_buffer_timer = 0;
        player.coyote_timer = 0;
        player.grounded = false;
        player.facing_left = climb_wall_dir > 0;
        player.climb_grab_lockout_timer = player_climb_jump_lockout_frames;
        player.climbing = false;
        player.climb_dangling = false;
        jumped_this_frame = true;
    } else if (player.jump_buffer_timer > 0 and wall_jump_dir != 0) {
        spawnJumpDustAtFeet(player.*);
        player.vx = @as(i32, wall_jump_dir) * player_wall_jump_h_speed;
        player.vy = player_wall_jump_speed;
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
        jumped_this_frame = true;
    }

    if (!jumped_this_frame) {
        updateClimb(player, grab_held, vertical, room_index);
    }
    if (!player.climbing) {
        updateVerticalSpeed(player, jump_held, input.isPressed(.down), effective_horizontal, room_index);
    }

    moveHorizontal(player, player.vx, room_index);
    player.grounded = false;
    moveVertical(player, player.vy, room_index);
    resolvePlayerEmbedding(player, room_index);
    if (!player.grounded and player.vy >= 0 and floorContact(player.*, room_index)) {
        player.grounded = true;
    }

    if (player.grounded) {
        if (player.dash_timer == 0 and player.dash_refill_cooldown_timer == 0) {
            refillPlayerDash(player);
        }
        if (!was_grounded and player.dust_suppress_timer == 0) {
            spawnLandingDustAtFeet(player.*);
        }
        if (!was_grounded) {
            triggerFunnyCarBounceAtPlayer(player.*);
        }
        player.var_jump_timer = 0;
        player.wall_slide_timer = player_wall_slide_frames;
        player.wall_sliding = false;
        if (!grab_held) {
            player.climbing = false;
        }
        player.climb_dangling = false;
    }

    updatePlayerAnimation(player);
    updateFootstepSfx(player, room_index);
}

fn refillPlayerDash(player: *Player) void {
    player.dashes = 1;
}

fn tryStartDash(player: *Player, horizontal: i16, vertical: i16, allow_dash: bool) bool {
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
    spawnDashAfterimage(player.*);
    spawnDashBurst(player.*);
    return true;
}

fn updateDashMovement(player: *Player, room_index: usize) void {
    if (player.dash_trail_timer == 0) {
        spawnDashAfterimage(player.*);
        player.dash_trail_timer = player_dash_trail_interval;
    }

    moveHorizontal(player, player.vx, room_index);
    player.grounded = false;
    moveVertical(player, player.vy, room_index);
    resolvePlayerEmbedding(player, room_index);
    if (!player.grounded and player.vy >= 0 and floorContact(player.*, room_index)) {
        player.grounded = true;
    }

    if (player.dash_timer > 0) {
        player.dash_timer -= 1;
    }
    if (player.dash_timer == 0) {
        endDash(player);
    }
    updatePlayerAnimation(player);
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
        if (!fast_fall and player.vy >= 0 and player.wall_slide_timer > 0 and wallSlideContact(player.*, horizontal, room_index)) {
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
        return;
    }

    const facing_dir: i16 = if (player.facing_left) -1 else 1;
    const climb_dir = if (wallContact(player.*, facing_dir, room_index))
        facing_dir
    else if (wallContact(player.*, -facing_dir, room_index))
        -facing_dir
    else
        0;
    if (climb_dir == 0) {
        if (player.climbing and vertical < 0 and tryClimbLedge(player, facing_dir, room_index)) {
            return;
        }
        player.climbing = false;
        player.climb_dangling = false;
        return;
    }
    if (!player.climbing and player.stamina <= player_climb_tired_stamina) {
        player.climb_dangling = false;
        return;
    }

    player.facing_left = climb_dir < 0;
    if (player.climbing and vertical < 0 and tryClimbLedge(player, climb_dir, room_index)) {
        return;
    }

    if (!player.climbing) {
        player.vy = fixedMul(player.vy, player_climb_grab_y_mult);
    }

    player.climbing = true;
    player.climb_dangling = false;
    player.wall_sliding = false;
    player.vx = 0;

    const target_y: i32 = if (vertical < 0)
        player_climb_up_speed
    else if (vertical > 0)
        player_climb_down_speed
    else
        0;
    player.vy = approach(player.vy, target_y, player_climb_accel);
    player.climb_dangling = vertical == 0 and !player.grounded and climbDangleContact(player.*, climb_dir, room_index);

    if (vertical < 0) {
        player.stamina = @max(0, player.stamina - player_climb_up_cost);
    } else if (vertical == 0) {
        player.stamina = @max(0, player.stamina - player_climb_still_cost);
    } else if (!player.grounded and player.wall_dust_timer == 0 and player.vy > fixed_one / 3) {
        spawnWallSlideDust(player.*, climb_dir);
        player.wall_dust_timer = 5;
    }
}

fn climbWallDirection(player: Player, room_index: usize) i16 {
    if (wallContact(player, -1, room_index)) return -1;
    if (wallContact(player, 1, room_index)) return 1;
    return 0;
}

fn climbDangleContact(player: Player, dir: i16, room_index: usize) bool {
    const side_offset: i16 = if (dir < 0) -1 else player_body_width;
    const x = fixedToPixel(player.x) + side_offset;
    const y = fixedToPixel(player.y);
    const hands_caught = wallSolidAtPixel(x, y + 1, room_index) or
        wallSolidAtPixel(x, y + 2, room_index) or
        wallSolidAtPixel(x, y + 3, room_index);
    const body_blocked = wallSolidAtPixel(x, y + 6, room_index) or
        wallSolidAtPixel(x, y + 9, room_index) or
        wallSolidAtPixel(x, y + player_body_height - 3, room_index);
    return hands_caught and !body_blocked;
}

fn tryClimbLedge(player: *Player, dir: i16, room_index: usize) bool {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);

    const min_y_offset = player_climb_ledge_min_body_above - player_body_height;
    var y_offset: i16 = min_y_offset;
    while (y_offset <= 0) : (y_offset += 1) {
        var over: i16 = player_body_width - 2;
        while (over <= player_body_width + 2) : (over += 1) {
            const candidate_x = start_x + dir * over;
            const candidate_y = start_y + y_offset;
            if (!collidesAt(candidate_x, candidate_y, room_index) and floorContactAt(candidate_x, candidate_y, room_index)) {
                startClimbLedgeMotion(player, candidate_x, candidate_y);
                return true;
            }
        }
    }

    return false;
}

fn startClimbLedgeMotion(player: *Player, target_x: i16, target_y: i16) void {
    player.climb_ledge_timer = player_climb_ledge_frames;
    player.climb_ledge_start_x = player.x;
    player.climb_ledge_start_y = player.y;
    player.climb_ledge_target_x = pixelToFixed(target_x);
    player.climb_ledge_target_y = pixelToFixed(target_y);
    player.vx = 0;
    player.vy = 0;
    player.grounded = false;
    player.climbing = true;
    player.climb_dangling = false;
    player.wall_sliding = false;
}

fn updateClimbLedgeMotion(player: *Player, room_index: usize) void {
    const duration: i32 = player_climb_ledge_frames;
    const elapsed: i32 = duration - @as(i32, player.climb_ledge_timer) + 1;
    const remaining = duration - elapsed;
    const denom = duration * duration;
    const eased = denom - remaining * remaining;
    const arc = @divTrunc(4 * player_climb_ledge_hop_pixels * fixed_one * elapsed * remaining, denom);

    const current_x = fixedToPixel(player.x);
    const current_y = fixedToPixel(player.y);
    const next_x = fixedToPixel(player.climb_ledge_start_x + @divTrunc((player.climb_ledge_target_x - player.climb_ledge_start_x) * eased, denom));
    const next_y = fixedToPixel(player.climb_ledge_start_y + @divTrunc((player.climb_ledge_target_y - player.climb_ledge_start_y) * elapsed, duration) - arc);
    if (!collidesAt(next_x, next_y, room_index)) {
        player.x = pixelToFixed(next_x);
        player.y = pixelToFixed(next_y);
    } else if (!collidesAt(current_x, next_y, room_index)) {
        player.y = pixelToFixed(next_y);
    } else if (!collidesAt(next_x, current_y, room_index)) {
        player.x = pixelToFixed(next_x);
    }
    player.vx = 0;
    player.vy = 0;
    player.moving = false;
    player.grounded = false;
    player.climbing = true;
    player.climb_dangling = false;
    player.wall_sliding = false;

    player.climb_ledge_timer -= 1;
    if (player.climb_ledge_timer == 0) {
        const target_x = fixedToPixel(player.climb_ledge_target_x);
        const target_y = fixedToPixel(player.climb_ledge_target_y);
        if (!collidesAt(target_x, target_y, room_index)) {
            player.x = player.climb_ledge_target_x;
            player.y = player.climb_ledge_target_y;
        }
        resolvePlayerEmbedding(player, room_index);
        player.grounded = true;
        player.climbing = false;
        player.stamina = player_climb_max_stamina;
        player.wall_slide_timer = player_wall_slide_frames;
    }
}

fn updatePlayerAnimation(player: *Player) void {
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
    else if (!player.grounded)
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

fn updateFootstepSfx(player: *Player, room_index: usize) void {
    if (!player.grounded or player.animation != .run or absI32(player.vx) < player_footstep_min_speed) {
        player.footstep_cooldown = 0;
        return;
    }

    if (player.footstep_cooldown != 0) {
        player.footstep_cooldown -= 1;
        return;
    }

    playFootstepSfx(footstepSurfaceAtPlayerFeet(player.*, room_index), player);
    player.footstep_cooldown = player_footstep_cadence_frames;
}

fn playFootstepSfx(surface: FootstepSurface, player: *Player) void {
    const samples = footstepSamplesFor(surface);
    const index: usize = @intCast(player.footstep_variant % @as(u8, @intCast(samples.len)));
    player.footstep_variant +%= 1;
    if (player.footstep_handle != 0) {
        _ = mm.sfx.effectCancel(player.footstep_handle);
    }
    player.footstep_handle = mm.sfx.effect(samples[index]);
    if (player.footstep_handle != 0) {
        mm.sfx.effectVolume(player.footstep_handle, player_footstep_volume);
    }
}

fn footstepSamplesFor(surface: FootstepSurface) []const u16 {
    return switch (surface) {
        .snow => &footstep_snow_sfx,
        .dirt => &footstep_dirt_sfx,
        .wood => &footstep_wood_sfx,
        .car => &footstep_car_sfx,
        .asphalt => &footstep_asphalt_sfx,
    };
}

fn footstepSurfaceAtPlayerFeet(player: Player, room_index: usize) FootstepSurface {
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const bottom = player_y + player_body_height;

    if (funnyCarFloorAt(player_x, player_y)) return .car;
    if (bridgeFloorAtPlayer(player)) return .asphalt;
    if (fallingBlockFloorAtPlayer(player)) return .snow;
    if (oneWayFloorAt(player_x, player_y, room_index)) return .wood;

    return backgroundFootstepSurfaceAt(room_index, player_x, bottom);
}

fn backgroundFootstepSurfaceAt(room_index: usize, player_x: i16, bottom: i16) FootstepSurface {
    var snow_score: u8 = 0;
    var dirt_score: u8 = 0;
    var asphalt_score: u8 = 0;
    const foot_x = [_]i16{ 1, player_body_width / 2, player_body_width - 2 };
    var xi: usize = 0;
    while (xi < foot_x.len) : (xi += 1) {
        var dy: i16 = 0;
        while (dy < 4) : (dy += 1) {
            if (backgroundFootstepPixelSurface(room_index, player_x + foot_x[xi], bottom + dy)) |surface| {
                switch (surface) {
                    .snow => snow_score += 1,
                    .dirt => dirt_score += 1,
                    .asphalt => asphalt_score += 1,
                    else => {},
                }
            }
        }
    }

    if (snow_score != 0) return .snow;
    if (asphalt_score > dirt_score) return .asphalt;
    return .dirt;
}

fn backgroundFootstepPixelSurface(room_index: usize, x: i16, y: i16) ?FootstepSurface {
    const color = backgroundPixelColorAt(rooms[room_index], x, y) orelse return null;
    return classifyFootstepColor(color);
}

fn backgroundPixelColorAt(room: RoomBackground, x: i16, y: i16) ?FootstepColor {
    if (x < 0 or y < 0 or x >= room.width_pixels or y >= room.height_pixels) return null;

    const tile_x = @divTrunc(x, 8);
    const tile_y = @divTrunc(y, 8);
    const entry = logicalRoomMapEntry(room, tile_x, tile_y);
    const tile_id = entry & 0x03ff;
    const hflip = (entry & 0x0400) != 0;
    const vflip = (entry & 0x0800) != 0;

    var source_x: usize = @intCast(x - tile_x * 8);
    var source_y: usize = @intCast(y - tile_y * 8);
    if (hflip) source_x = 7 - source_x;
    if (vflip) source_y = 7 - source_y;

    const tile_offset = @as(usize, tile_id) * 64 + source_y * 8 + source_x;
    if (tile_offset >= room.tiles.len) return null;

    const color_index = room.tiles[tile_offset];
    if (color_index == 0) return null;
    const palette_offset = @as(usize, color_index) * 2;
    if (palette_offset + 1 >= room.palette.len) return null;

    const color = readU16Le(room.palette, palette_offset);
    return .{
        .r = @intCast(color & 0x1f),
        .g = @intCast((color >> 5) & 0x1f),
        .b = @intCast((color >> 10) & 0x1f),
    };
}

fn classifyFootstepColor(color: FootstepColor) ?FootstepSurface {
    if ((color.r >= 24 and color.g >= 24 and color.b >= 24) or
        (color.b >= 22 and color.g >= 18 and color.r >= 14))
    {
        return .snow;
    }

    const rg_delta = absI16(@as(i16, color.r) - @as(i16, color.g));
    const gb_delta = absI16(@as(i16, color.g) - @as(i16, color.b));
    if (rg_delta <= 3 and gb_delta <= 3 and color.r >= 7 and color.r <= 24) {
        return .asphalt;
    }

    if (color.r >= 10 and color.g >= 5 and @as(u8, color.r) > @as(u8, color.b) + 4 and color.g >= color.b) {
        return .dirt;
    }

    return null;
}

fn fallingBlockFloorAtPlayer(player: Player) bool {
    const player_x = fixedToPixel(player.x);
    const bottom = fixedToPixel(player.y) + player_body_height;
    return fallingBlockFloorAt(player_x + 1, bottom) or
        fallingBlockFloorAt(player_x + player_body_width / 2, bottom) or
        fallingBlockFloorAt(player_x + player_body_width - 2, bottom);
}

fn fallingBlockFloorAt(x: i16, bottom_y: i16) bool {
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = falling_blocks[index];
        if (!block.active) continue;
        const block_y = fixedToPixel(block.y);
        if (x >= block.x and x < block.x + block.w and bottom_y >= block_y and bottom_y < block_y + 4) {
            return true;
        }
    }
    return false;
}

fn bridgeFloorAtPlayer(player: Player) bool {
    if (!bridge_active) return false;
    const player_x = fixedToPixel(player.x);
    const bottom = fixedToPixel(player.y) + player_body_height;
    return bridgeFloorAt(player_x + 1, bottom) or
        bridgeFloorAt(player_x + player_body_width / 2, bottom) or
        bridgeFloorAt(player_x + player_body_width - 2, bottom);
}

fn bridgeFloorAt(x: i16, bottom_y: i16) bool {
    if (!bridge_active) return false;
    if (bridge_ending.active and bottom_y >= bridge_ending.platform.y and bottom_y < bridge_ending.platform.y + 4 and x >= bridge_ending.platform.x and x < bridge_ending.platform.right()) {
        return true;
    }

    const chunk_index = bridgeChunkIndexAtX(x) orelse return false;
    if (chunk_index >= bridge_chunk_count) return false;
    const chunk = bridge_chunks[chunk_index];
    if (chunk.state != .solid and chunk.state != .shaking) return false;
    const chunk_y = fixedToPixel(chunk.y);
    return bottom_y >= chunk_y and bottom_y < chunk_y + 4;
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

fn nextRandom() u16 {
    const bit = ((rng_state >> 0) ^ (rng_state >> 2) ^ (rng_state >> 3) ^ (rng_state >> 5)) & 1;
    rng_state = (rng_state >> 1) | (bit << 15);
    return rng_state;
}

fn spawnJumpDustAtFeet(player: Player) void {
    spawnDustAtFeet(player, false);
}

fn spawnLandingDustAtFeet(player: Player) void {
    spawnDustAtFeet(player, true);
}

fn spawnDustAtFeet(player: Player, landing: bool) void {
    const base_x = fixedToPixel(player.x) + player_body_width / 2;
    const base_y = fixedToPixel(player.y) + player_body_height - 2;
    const count: u8 = if (landing) 3 + @as(u8, @intCast(nextRandom() % 2)) else 2 + @as(u8, @intCast(nextRandom() % 3));
    var index: u8 = 0;
    while (index < count) : (index += 1) {
        const slot = nextDustParticleIndex();
        const side: i32 = if (((nextRandom() + index) & 1) == 0) -1 else 1;
        const x_jitter: i16 = if (landing) @intCast(nextRandom() % 9) else @intCast(nextRandom() % 5);
        const speed: i32 = if (landing) 0x40 + @as(i32, @intCast(nextRandom() % 0x48)) else 0x28 + @as(i32, @intCast(nextRandom() % 0x38));
        const rise: i32 = if (landing) 0x08 + @as(i32, @intCast(nextRandom() % 0x18)) else 0x18 + @as(i32, @intCast(nextRandom() % 0x28));
        const life: u8 = if (landing) 16 + @as(u8, @intCast(nextRandom() % 9)) else 12 + @as(u8, @intCast(nextRandom() % 9));
        const x_offset: i16 = if (landing) 4 else 2;
        dust_particles[slot] = .{
            .active = true,
            .x = pixelToFixed(base_x + x_jitter - x_offset),
            .y = pixelToFixed(base_y + @as(i16, @intCast(nextRandom() % 3))),
            .vx = side * speed,
            .vy = -rise,
            .life = life,
            .max_life = life,
            .shape = @intCast(nextRandom() % 4),
            .landing = landing,
        };
    }
}

fn spawnWallSlideDust(player: Player, wall_dir: i16) void {
    const slot = nextDustParticleIndex();
    const body_x = fixedToPixel(player.x);
    const body_y = fixedToPixel(player.y);
    const contact_x = body_x + if (wall_dir < 0) @as(i16, -1) else @as(i16, player_body_width + 1);
    const lag_y = body_y + 4 + @as(i16, @intCast(nextRandom() % 4));
    const push_away = -@as(i32, wall_dir) * (0x10 + @as(i32, @intCast(nextRandom() % 0x18)));
    const life = 14 + @as(u8, @intCast(nextRandom() % 8));
    dust_particles[slot] = .{
        .active = true,
        .x = pixelToFixed(contact_x),
        .y = pixelToFixed(lag_y),
        .vx = push_away,
        .vy = -(0x08 + @as(i32, @intCast(nextRandom() % 0x18))),
        .life = life,
        .max_life = life,
        .shape = @intCast(nextRandom() % 4),
        .wall = true,
    };
}

fn spawnDashAfterimage(player: Player) void {
    var slot: usize = 0;
    var index: usize = 0;
    while (index < dash_afterimage_count) : (index += 1) {
        if (!dash_afterimages[index].active) {
            slot = index;
            break;
        }
        if (dash_afterimages[index].life < dash_afterimages[slot].life) {
            slot = index;
        }
    }

    dash_afterimages[slot] = .{
        .active = true,
        .x = player.x,
        .y = player.y,
        .life = dash_afterimage_life,
        .facing_left = player.facing_left,
        .dir_x = player.dash_dir_x,
        .dir_y = player.dash_dir_y,
    };
}

fn spawnDashBurst(player: Player) void {
    const dir_x: i16 = player.dash_dir_x;
    const dir_y: i16 = player.dash_dir_y;
    const draw_x = fixedToPixel(player.x) + player_draw_offset_x;
    const draw_y = fixedToPixel(player.y) + player_draw_offset_y;
    writeDashEffectTile(dir_x, dir_y);
    dash_burst = .{
        .active = true,
        .x = draw_x,
        .y = draw_y,
        .life = 10,
    };
}

fn updateDashEffects() void {
    var index: usize = 0;
    while (index < dash_afterimage_count) : (index += 1) {
        if (!dash_afterimages[index].active) continue;
        if (dash_afterimages[index].life > 0) {
            dash_afterimages[index].life -= 1;
        }
        if (dash_afterimages[index].life == 0) {
            dash_afterimages[index].active = false;
        }
    }
    if (dash_burst.active) {
        if (dash_burst.life > 0) {
            dash_burst.life -= 1;
        }
        if (dash_burst.life == 0) {
            dash_burst.active = false;
        }
    }
}

fn clearDashEffects() void {
    dash_afterimages = [_]DashAfterimage{.{}} ** dash_afterimage_count;
    dash_burst = .{};
    var index: usize = 0;
    while (index < dash_afterimage_count) : (index += 1) {
        hideObject(dash_afterimage_first_object + index);
    }
    hideObject(dash_burst_object);
}

fn spawnFallingBlockSnow(block: FallingBlock) void {
    const base_y = fixedToPixel(block.y) + 2;
    const count: u8 = 7;
    var index: u8 = 0;
    while (index < count) : (index += 1) {
        const slot = nextDustParticleIndex();
        const x_offset: i16 = @intCast((nextRandom() + index * 9) % @as(u16, block.w));
        const side: i32 = if ((nextRandom() & 1) == 0) -1 else 1;
        const drift: i32 = 0x04 + @as(i32, @intCast(nextRandom() % 0x14));
        const drop: i32 = 0x34 + @as(i32, @intCast(nextRandom() % 0x48));
        const life: u8 = 28 + @as(u8, @intCast(nextRandom() % 17));
        dust_particles[slot] = .{
            .active = true,
            .x = pixelToFixed(block.x + x_offset),
            .y = pixelToFixed(base_y + @as(i16, @intCast(nextRandom() % 4))),
            .vx = side * drift,
            .vy = drop,
            .life = life,
            .max_life = life,
            .shape = @intCast(nextRandom() % 4),
            .snow = true,
        };
    }
}

fn nextDustParticleIndex() usize {
    var index: usize = 0;
    while (index < max_dust_particles) : (index += 1) {
        if (!dust_particles[index].active) return index;
    }

    var weakest: usize = 0;
    index = 0;
    while (index < max_dust_particles) : (index += 1) {
        if (dust_particles[index].life < dust_particles[weakest].life) weakest = index;
    }
    return weakest;
}

fn updateDustParticles() void {
    var index: usize = 0;
    while (index < max_dust_particles) : (index += 1) {
        if (!dust_particles[index].active) continue;
        if (dust_particles[index].life == 0) {
            dust_particles[index].active = false;
            continue;
        }
        dust_particles[index].life -= 1;
        dust_particles[index].x += dust_particles[index].vx;
        dust_particles[index].y += dust_particles[index].vy;
        dust_particles[index].vx = @divTrunc(dust_particles[index].vx * 7, 8);
        dust_particles[index].vy += if (dust_particles[index].snow) 0x03 else 0x08;
        if (dust_particles[index].life == 0) {
            dust_particles[index].active = false;
        }
    }
}

fn clearDustParticles() void {
    dust_particles = [_]DustParticle{.{}} ** max_dust_particles;
    var index: usize = 0;
    while (index < max_dust_particles) : (index += 1) {
        hideObject(dust_first_object + index);
    }
}

fn updateFallingBlocks(player: *Player) bool {
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = &falling_blocks[index];
        if (!block.active) continue;

        switch (block.state) {
            .idle => {
                if (playerBelowBlock(player.*, block.*)) {
                    block.state = .shaking;
                    block.timer = falling_block_shake_frames;
                }
            },
            .shaking => {
                if (block.timer > 0) {
                    block.timer -= 1;
                } else {
                    spawnFallingBlockSnow(block.*);
                    block.state = .falling;
                    block.vy = 0;
                }
            },
            .falling => {
                const old_x = block.x;
                const old_y = fixedToPixel(block.y);
                block.vy = approach(block.vy, falling_block_max_fall, falling_block_gravity);
                block.y += block.vy;
                if (fixedToPixel(block.y) >= block.max_y) {
                    block.y = pixelToFixed(block.max_y);
                    block.vy = 0;
                    block.state = .landed;
                    markRoomFallingBlockLanded(current_room_index, index);
                }

                const dy = fixedToPixel(block.y) - old_y;
                if (dy > 0 and playerStandingOnBlock(player.*, block.*)) {
                    player.y += @as(i32, dy) << fixed_shift;
                } else if (movingBlockCrushesPlayer(player.*, old_x, old_y, block.x, fixedToPixel(block.y), block.w, block.h)) {
                    return true;
                }
            },
            .landed => {},
        }
    }
    return false;
}

fn updateFallingBlocksDuringDeath() void {
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = &falling_blocks[index];
        if (!block.active) continue;

        switch (block.state) {
            .idle => {},
            .shaking => {
                if (block.timer > 0) {
                    block.timer -= 1;
                } else {
                    spawnFallingBlockSnow(block.*);
                    block.state = .falling;
                    block.vy = 0;
                }
            },
            .falling => {
                block.vy = approach(block.vy, falling_block_max_fall, falling_block_gravity);
                block.y += block.vy;
                if (fixedToPixel(block.y) >= block.max_y) {
                    block.y = pixelToFixed(block.max_y);
                    block.vy = 0;
                    block.state = .landed;
                    markRoomFallingBlockLanded(current_room_index, index);
                }
            },
            .landed => {},
        }
    }
}

fn updateBridge(player: *Player, room_index: usize) void {
    if (!bridge_active or !isPrologueEndRoom(room_index)) return;

    var live_chunks: usize = 0;
    const player_center_x = fixedToPixel(player.x) + player_body_width / 2;
    const player_bottom = fixedToPixel(player.y) + player_body_height;
    if (bridgeEndingTriggerActive(player.*)) {
        triggerBridgeEndingPlatformEarly();
    }
    const trigger_y_min = bridge_world_y - 4;
    const trigger_y_max = bridge_world_y + 12;
    if (player_bottom >= trigger_y_min and player_bottom <= trigger_y_max) {
        if (bridgeChunkIndexAtX(player_center_x)) |chunk_index| {
            const chunk = &bridge_chunks[chunk_index];
            if (chunk.state == .solid and player_center_x >= chunk.x - 4 and player_center_x < chunk.x + bridge_chunk_width + 2) {
                triggerBridgeChunkRun(chunk_index);
            }
        }
    }

    var index: usize = 0;
    while (index < bridge_chunk_count) : (index += 1) {
        const chunk = &bridge_chunks[index];
        switch (chunk.state) {
            .inactive, .gone => {},
            .solid => {
                if (bridge_sequence_started and chunk.x + bridge_chunk_width < player_center_x - 56) {
                    chunk.state = .gone;
                } else {
                    live_chunks += 1;
                }
            },
            .shaking => {
                live_chunks += 1;
                if (chunk.timer > 0) {
                    chunk.timer -= 1;
                } else {
                    spawnBridgeSnow(chunk.*);
                    chunk.state = .falling;
                    chunk.vy = 0;
                }
            },
            .falling => {
                live_chunks += 1;
                chunk.vy = approach(chunk.vy, bridge_fall_max_speed, bridge_fall_gravity);
                chunk.y += chunk.vy;
                if (fixedToPixel(chunk.y) > bridge_world_y + screen_height + bridge_chunk_height) {
                    chunk.state = .gone;
                }
            },
        }
    }

    if (bridge_sequence_started and live_chunks == 0) {
        bridge_active = false;
        hideBridgeObjects();
    }
}

fn shouldStartBridgeEndingHold(player: Player, room_index: usize) bool {
    if (!bridge_active or !isPrologueEndRoom(room_index) or !bridge_ending.active or !bridge_ending.final_triggered) return false;
    const player_center_x = fixedToPixel(player.x) + player_body_width / 2;
    const player_bottom = fixedToPixel(player.y) + player_body_height;
    return player_center_x >= bridge_ending.platform.x - 16 and
        player_center_x <= bridge_ending.platform.right() + 56 and
        player_bottom > bridge_ending.platform.y + 10 and
        player.vy > 0;
}

fn startBridgeEndingHold(player: *Player) void {
    bridge_ending_hold = true;
    holdPlayerForBridgeEnding(player);
    clearDustParticles();

    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const hint_x = if (bridge_ending.hint.w > 0) bridge_ending.hint.x else player_x - 32;
    const hint_y = if (bridge_ending.hint.h > 0) bridge_ending.hint.y else player_y - 72;
    bird_npc = .{
        .active = true,
        .state = .ending_fly_in,
        .x = pixelToFixed(player_x + 140),
        .y = pixelToFixed(player_y - 42),
        .home_x = player_x + 34,
        .home_y = player_y - 18,
        .hint_x = hint_x,
        .hint_y = hint_y,
        .frame = bird_fly_first_frame,
        .facing_left = true,
    };
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bird_palette_bank) * 16], @ptrCast(&bird_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bird_hint_palette_bank) * 16], @ptrCast(&bird_hint_palette_data), 16);
}

fn holdPlayerForBridgeEnding(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.grounded = false;
    player.moving = false;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    if (player.animation != .fall) {
        player.animation = .fall;
        player.animation_timer = 0;
    }
}

fn shouldStartEndLevelTransition(player: Player, room_index: usize) bool {
    if (end_level_transition.phase != .inactive) return false;
    if (!isPrologueEndRoom(room_index) or !bridge_ending.active or !bridge_ending.final_triggered) return false;
    if (!bridge_ending_dash_started) return false;

    return playerReachedBridgeEndingExitZone(player);
}

fn playerReachedBridgeEndingExitZone(player: Player) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_bottom = player_top + player_body_height;
    const player_center_x = fixedToPixel(player.x) + player_body_width / 2;
    const platform = bridge_ending.platform;
    const platform_bottom = platform.y + bridge_visual_height;
    const dash_finished = player.dash_timer == 0;
    const crosses_end_zone = player_center_x >= platform.x - 8 and
        player_left <= platform.right() + 24;
    const near_end_height = player_bottom >= platform.y - 64 and
        player_top <= platform_bottom + 56;
    return dash_finished and player.grounded and crosses_end_zone and near_end_height;
}

fn startEndLevelTransition(player: *Player, camera: Camera) void {
    player.vx = 0;
    player.vy = 0;
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.moving = false;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.facing_left = false;
    player.animation = .run;
    player.animation_timer = 0;
    clearDustParticles();
    clearDashEffects();
    bridge_collapse_shake_tick = 0;
    hideObject(bird_object);
    hideObject(bird_hint_object);
    end_level_transition = .{
        .phase = .walk,
        .timer = 0,
        .start_camera = camera,
    };
}

fn updateEndLevelTransition(player: *Player, camera: *Camera, room_index: *usize, respawn: *Spawn, input: gba.input.BufferedKeysState) void {
    const active_room_index = room_index.*;
    switch (end_level_transition.phase) {
        .inactive => {},
        .walk => {
            player.vx = end_level_walk_speed;
            player.vy = 0;
            player.moving = true;
            player.facing_left = false;
            player.grounded = true;
            moveHorizontal(player, player.vx, active_room_index);
            updatePlayerAnimation(player);
            updateHair(player);
            updateDashEffects();
            updateWindSnow(active_room_index, camera.*);
            foreground_anim_counter +%= 1;

            const render_camera = updateCamera(player.*, active_room_index);
            camera.* = render_camera;
            frameSync();
            drawEndLevelTransitionScene(player, render_camera, active_room_index);

            if (end_level_transition.timer >= end_level_walk_frames) {
                player.vx = 0;
                player.moving = false;
                end_level_transition.phase = .camera_up;
                end_level_transition.timer = 0;
                end_level_transition.start_camera = render_camera;
            } else {
                end_level_transition.timer += 1;
            }
        },
        .camera_up => {
            player.vx = 0;
            player.vy = 0;
            player.moving = false;
            player.grounded = true;
            updatePlayerAnimation(player);
            updateHair(player);
            updateDashEffects();
            updateWindSnow(active_room_index, camera.*);
            foreground_anim_counter +%= 1;

            const room = rooms[active_room_index];
            const progress = @min(end_level_transition.timer, end_level_camera_frames);
            const lift: i16 = @intCast(@divTrunc(@as(u16, progress) * @as(u16, @intCast(end_level_camera_lift)), end_level_camera_frames));
            const min_y = -end_level_camera_lift;
            const max_y = room.height_pixels - screen_height;
            const render_camera = Camera{
                .x = end_level_transition.start_camera.x,
                .y = clampI16(end_level_transition.start_camera.y - lift, min_y, max_y),
            };
            camera.* = render_camera;
            frameSync();
            drawEndLevelTransitionScene(player, render_camera, active_room_index);

            if (end_level_transition.timer >= end_level_camera_frames) {
                end_level_transition.phase = .black;
                end_level_transition.timer = 0;
                cutToBlackForOverworldTransition();
            } else {
                end_level_transition.timer += 1;
            }
        },
        .black => {
            frameSync();
            if (end_level_transition.timer >= end_level_black_frames) {
                loadOverworldScreen();
                end_level_transition.phase = .overworld;
                end_level_transition.timer = 0;
            } else {
                end_level_transition.timer += 1;
            }
        },
        .overworld => {
            if (input.isJustPressed(.A)) {
                startLevelOneFromOverworld(player, camera, room_index, respawn);
                return;
            }
            frameSync();
        },
    }
}

fn drawEndLevelTransitionScene(player: *Player, camera: Camera, room_index: usize) void {
    applyCamera(camera);
    updateParallaxBackground(camera, room_index);
    drawForegroundStampObjects(camera);
    drawFunnyCars(camera);
    drawFallingBlockObjects(camera);
    drawRoomWires(camera);
    drawBridgeObjects(camera);
    drawBirdNpc(camera);
    drawGrannyNpc(camera, room_index);
    drawTinyBirds(camera);
    drawDashEffects(camera);
    drawHair(player.*, camera);
    drawDust(camera);
    drawWindSnow(camera);
    drawPlayer(player.*, camera);
    drawSweat(player, camera);
    drawCutsceneOverlay(camera, room_index);
}

fn cutToBlackForOverworldTransition() void {
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    gba.display.hideAllObjects();
    gba.display.bg_palette.colors[0] = .black;
}

fn loadOverworldScreen() void {
    bridge_active = false;
    bridge_ending_hold = false;
    bridge_ending_dash_started = false;
    bridge_ending = .{};
    clearDustParticles();
    clearDashEffects();
    hideWindSnowObjects();
    hideChimneySmokeObjects();
    hideBridgeObjects();
    hideForegroundStampObjects();
    hideRoomWires();
    gba.display.hideAllObjects();
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    clearParallaxMap();
    bg_stream_room_index = rooms.len;
    parallax_stream_room_index = rooms.len;

    gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&overworld_bg_palette_data), overworld_bg_palette_data.len);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(&overworld_bg_tiles_data));
    drawOverworldMap();
    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.bg0 = true;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
}

fn startLevelOneFromOverworld(player: *Player, camera: *Camera, room_index: *usize, respawn: *Spawn) void {
    if (level_one_room_index >= rooms.len) return;

    gba.display.bg_palette.colors[0] = .black;
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    gba.display.hideAllObjects();
    frameSync();

    const target_room = level_one_room_index;
    room_index.* = target_room;
    respawn.* = rooms[target_room].spawn;
    loadRoomBackground(target_room);
    loadFallingBlocks(target_room);
    loadForegroundStamps(target_room);
    loadFunnyCars(target_room);
    loadObjectSprites();
    loadBridge(target_room);
    loadBirdNpc(target_room);
    loadTinyBirds(target_room);
    loadRoomWires(target_room);
    loadRoomParallax(target_room);
    resetGrannyCutsceneOnRoomLoad();
    clearDustParticles();
    clearDashEffects();
    player.* = spawnPlayer(target_room);
    player.hair_initialized = false;
    updateHair(player);
    camera.* = updateCamera(player.*, target_room);
    resetWindSnow(target_room, camera.*);
    resetChimneySmoke(target_room);
    applyCamera(camera.*);
    updateParallaxBackground(camera.*, target_room);
    drawForegroundStampObjects(camera.*);
    drawFunnyCars(camera.*);
    drawBridgeObjects(camera.*);
    drawDashEffects(camera.*);
    drawHair(player.*, camera.*);
    drawDust(camera.*);
    drawWindSnow(camera.*);
    drawPlayer(player.*, camera.*);
    drawSweat(player, camera.*);
    drawFallingBlockObjects(camera.*);
    drawChimneySmoke(camera.*, target_room);
    drawRoomWires(camera.*);
    drawBirdNpc(camera.*);
    drawGrannyNpc(camera.*, target_room);
    drawTinyBirds(camera.*);
    drawCutsceneOverlay(camera.*, target_room);
    end_level_transition = .{};
    frameSync();
    gba.display.ctrl.bg0 = true;
    gba.display.ctrl.bg1 = rooms[target_room].parallax != null;
    gba.display.ctrl.obj = true;
}

fn drawOverworldMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);
    var index: usize = 0;
    while (index < bg_hardware_width_tiles * bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < overworld_height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < overworld_width_tiles) : (x += 1) {
            const source_offset = (y * overworld_width_tiles + x) * 2;
            const raw_entry = @as(u16, overworld_bg_map_data[source_offset]) |
                (@as(u16, overworld_bg_map_data[source_offset + 1]) << 8);
            entries[normalBgMapIndex(x, y, bg_hardware_width_tiles)] = @bitCast(raw_entry);
        }
    }
}

fn triggerBridgeChunkRun(start_index: usize) void {
    const group = bridge_chunks[start_index].group;
    if (group == bridge_no_group) {
        triggerBridgeChunk(start_index, 0);
        return;
    }

    var index: usize = 0;
    while (index < bridge_chunk_count) : (index += 1) {
        if (bridge_chunks[index].group != group) continue;
        triggerBridgeChunk(index, 0);
    }
}

fn triggerBridgeChunk(index: usize, delay: u8) void {
    const chunk = &bridge_chunks[index];
    if (chunk.state != .solid) return;
    beginBridgeSequence();
    chunk.state = .shaking;
    chunk.timer = bridge_shake_frames + delay;
}

fn beginBridgeSequence() void {
    if (bridge_sequence_started) return;
    bridge_sequence_started = true;
}

fn updateBridgeCollapseShake(room_index: usize, player_grounded: bool) void {
    if (player_grounded and bridgeCollapseShakeActive(room_index)) {
        bridge_collapse_shake_tick +%= 1;
    } else {
        bridge_collapse_shake_tick = 0;
    }
}

fn bridgeCollapseShakeActive(room_index: usize) bool {
    if (!bridge_active or !isPrologueEndRoom(room_index) or !bridge_sequence_started) return false;
    if (bridge_ending.final_triggered or bridge_ending_hold or bridge_ending_dash_started) return false;

    var index: usize = 0;
    while (index < bridge_chunk_count) : (index += 1) {
        const state = bridge_chunks[index].state;
        if (state == .shaking or state == .falling) return true;
    }
    return false;
}

fn triggerBridgeEndingPlatformEarly() void {
    if (!bridge_ending.active or bridge_ending.final_triggered) return;
    if (bridge_ending.start_index >= bridge_chunk_count or bridge_ending.end_index >= bridge_chunk_count) return;
    bridge_ending.final_triggered = true;
    var index: usize = bridge_ending.start_index;
    while (index <= bridge_ending.end_index) : (index += 1) {
        const chunk = &bridge_chunks[index];
        if (chunk.state != .solid) continue;
        chunk.state = .shaking;
        chunk.timer = bridge_ending_early_shake_frames;
    }
}

fn bridgeEndingTriggerActive(player: Player) bool {
    if (!bridge_ending.active or bridge_ending.final_triggered) return false;
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_body_width;
    const player_bottom = player_top + player_body_height;
    const trigger = bridge_ending.trigger;
    return rectsOverlap(player_left, player_top, player_right, player_bottom, trigger.x, trigger.y, trigger.right(), trigger.bottom());
}

fn bridgeChunkIndexAtX(x: i16) ?usize {
    if (!bridge_active or x < bridge_world_x) return null;
    const relative = x - bridge_world_x;
    const index: usize = @intCast(@divTrunc(relative, bridge_chunk_width));
    if (index >= bridge_chunk_count) return null;
    return index;
}

fn spawnBridgeSnow(chunk: BridgeChunk) void {
    const block = FallingBlock{
        .active = true,
        .x = chunk.x,
        .y = chunk.y,
        .w = bridge_chunk_width,
        .h = bridge_visual_height,
        .max_y = fixedToPixel(chunk.y) + bridge_visual_height,
    };
    spawnFallingBlockSnow(block);
}

fn roomFallingBlockLanded(room_index: usize, block_index: usize) bool {
    if (block_index >= max_falling_blocks) return false;
    const mask = @as(u8, 1) << @as(u3, @intCast(block_index));
    return (room_states[room_index].falling_blocks_landed & mask) != 0;
}

fn markRoomFallingBlockLanded(room_index: usize, block_index: usize) void {
    if (block_index >= max_falling_blocks) return;
    const mask = @as(u8, 1) << @as(u3, @intCast(block_index));
    room_states[room_index].falling_blocks_landed |= mask;
}

fn playerBelowBlock(player: Player, block: FallingBlock) bool {
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const player_center_x = player_x + player_body_width / 2;
    const trigger_left = block.x + @as(i16, @intCast(@divTrunc(@as(u16, block.w), 2)));
    const trigger_right = block.x + @as(i16, @intCast(block.w)) + 2;
    return player_center_x >= trigger_left and
        player_center_x < trigger_right and
        player_y >= fixedToPixel(block.y) + block.h and
        player_y <= block.max_y + block.h;
}

fn playerStandingOnBlock(player: Player, block: FallingBlock) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_body_height;
    const block_top = fixedToPixel(block.y);
    return player_right >= block.x and
        player_left < block.x + block.w and
        player_bottom >= block_top - 1 and
        player_bottom <= block_top + 2;
}

fn movingBlockCrushesPlayer(player: Player, old_x: i16, old_y: i16, new_x: i16, new_y: i16, w: u8, h: u8) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_body_width;
    const player_bottom = player_top + player_body_height;

    const block_left = new_x;
    const block_top = new_y;
    const block_right = new_x + @as(i16, @intCast(w));
    const block_bottom = new_y + @as(i16, @intCast(h));
    if (!rectsOverlap(player_left, player_top, player_right, player_bottom, block_left, block_top, block_right, block_bottom)) {
        return false;
    }

    const old_right = old_x + @as(i16, @intCast(w));
    const old_bottom = old_y + @as(i16, @intCast(h));
    const dx = new_x - old_x;
    const dy = new_y - old_y;

    if (dy > 0 and old_bottom <= player_top + 1) return true;
    if (dy < 0 and old_y >= player_bottom - 1) return true;
    if (dx > 0 and old_right <= player_left + 1) return true;
    if (dx < 0 and old_x >= player_right - 1) return true;
    return dx != 0 or dy != 0;
}

fn rectsOverlap(a_left: i16, a_top: i16, a_right: i16, a_bottom: i16, b_left: i16, b_top: i16, b_right: i16, b_bottom: i16) bool {
    return a_left < b_right and a_right > b_left and a_top < b_bottom and a_bottom > b_top;
}

fn updateGrannyCutscene(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    const maybe_cutscene = rooms[room_index].granny_cutscene;
    if (!granny_cutscene.active) {
        if (maybe_cutscene) |cutscene| {
            if (!granny_intro_done and playerOverlapsSceneRect(player.*, cutscene.trigger)) {
                startGrannyCutscene(player, room_index);
            }
        }
    }

    if (!granny_cutscene.active) return false;
    const cutscene = rooms[granny_cutscene.room_index].granny_cutscene orelse return false;
    player.vx = 0;
    player.vy = 0;
    player.moving = false;
    player.grounded = true;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.dash_timer = 0;
    player.dash_cooldown_timer = 0;
    granny_cutscene.madeline_speaker_x = fixedToPixel(player.x) + player_body_width / 2;
    granny_cutscene.madeline_speaker_y = fixedToPixel(player.y) + player_body_height / 2;

    switch (granny_cutscene.phase) {
        .inactive => {},
        .dialogue => {
            updateGrannyDialogueReveal(cutscene);
            updateGrannyCutsceneDialogue(input, cutscene);
        },
        .walk_talk => {
            player.facing_left = false;
            if (movePlayerTowardCutscenePoint(player, cutscene.madeline_talk, 1)) {
                startGrannyDialogue(1);
            }
        },
        .walk_edge => {
            player.facing_left = false;
            if (movePlayerTowardCutscenePoint(player, cutscene.madeline_edge, 1)) {
                player.facing_left = true;
                startGrannyDialogue(3);
            }
        },
        .laugh_pause => {
            player.facing_left = true;
            if (granny_cutscene.laugh_pause_timer > 0) {
                granny_cutscene.laugh_pause_timer -= 1;
            } else {
                startGrannyDialogue(4);
            }
        },
    }

    if (granny_cutscene.active) {
        setGrannyCutsceneDarkened(granny_cutscene.room_index, grannyCutsceneOminousPage(cutscene));
        if (granny_cutscene.shake_timer > 0) {
            granny_cutscene.shake_timer -= 1;
        }
    }
    return granny_cutscene.active;
}

fn startGrannyCutscene(player: *Player, room_index: usize) void {
    _ = player;
    granny_cutscene = .{
        .active = true,
        .room_index = room_index,
    };
    startGrannyDialogue(0);
    clearDustParticles();
    clearDashEffects();
    hideCutsceneDialogueObjects();
}

fn resetGrannyCutsceneOnRoomLoad() void {
    if (!granny_cutscene.active) return;
    granny_cutscene = .{};
    cutscene_bg_darkened = false;
    hideCutsceneDialogueObjects();
}

fn updateGrannyCutsceneDialogue(input: gba.input.BufferedKeysState, cutscene: *const GrannyCutscene) void {
    if (granny_cutscene.dialogue_index >= cutscene.dialogue.len) {
        finishGrannyCutscene(cutscene);
        return;
    }
    if (!(input.isJustPressed(.A) or input.isJustPressed(.B))) return;

    const page = cutscene.dialogue[granny_cutscene.dialogue_index];
    const page_end = wrappedTextNextOffset(page.text, granny_cutscene.dialogue_offset, cutscene_dialogue_text_max_chars, cutscene_dialogue_text_max_lines);
    if (grannyDialogueUsesTypewriter(page.text) and granny_cutscene.dialogue_reveal_offset < page_end) {
        revealGrannyDialogueTo(page.text, page_end);
        return;
    }

    if (page_end < page.text.len) {
        granny_cutscene.dialogue_offset = page_end;
        granny_cutscene.rendered_dialogue_index = 255;
        resetGrannyDialogueReveal(cutscene);
        return;
    }

    const completed_page = granny_cutscene.dialogue_index;
    if (completed_page == 0) {
        granny_cutscene.phase = .walk_talk;
        hideCutsceneDialogueObjects();
        return;
    }
    if (completed_page == 2) {
        granny_cutscene.phase = .walk_edge;
        hideCutsceneDialogueObjects();
        return;
    }
    if (completed_page == 3) {
        granny_cutscene.phase = .laugh_pause;
        granny_cutscene.laugh_pause_timer = cutscene_laugh_pause_frames;
        hideCutsceneDialogueObjects();
        startLaughTextBurst(cutscene, granny_cutscene.room_index, 3, false, false);
        return;
    }
    const next_page = completed_page + 1;
    if (next_page >= cutscene.dialogue.len) {
        finishGrannyCutscene(cutscene);
    } else {
        startGrannyDialogue(next_page);
    }
}

fn startGrannyDialogue(index: u8) void {
    granny_cutscene.phase = .dialogue;
    granny_cutscene.dialogue_index = index;
    granny_cutscene.dialogue_offset = 0;
    granny_cutscene.dialogue_next_offset = 0;
    granny_cutscene.rendered_dialogue_index = 255;
    granny_cutscene.rendered_dialogue_reveal_offset = 0xffff;
    if (rooms[granny_cutscene.room_index].granny_cutscene) |cutscene| {
        resetGrannyDialogueReveal(cutscene);
    }
}

fn finishGrannyCutscene(cutscene: *const GrannyCutscene) void {
    const room_index = granny_cutscene.room_index;
    granny_intro_done = true;
    setGrannyCutsceneDarkened(room_index, false);
    granny_cutscene = .{};
    hideCutsceneDialogueObjects();
    startLaughTextBurst(cutscene, room_index, 0, true, true);
}

fn resetGrannyDialogueReveal(cutscene: *const GrannyCutscene) void {
    if (granny_cutscene.dialogue_index >= cutscene.dialogue.len) return;
    const page = cutscene.dialogue[granny_cutscene.dialogue_index];
    const start = skipTextSpaces(page.text, granny_cutscene.dialogue_offset);
    granny_cutscene.dialogue_reveal_offset = if (grannyDialogueUsesTypewriter(page.text)) start else page.text.len;
    granny_cutscene.dialogue_reveal_timer = 0;
    granny_cutscene.rendered_dialogue_index = 255;
    granny_cutscene.rendered_dialogue_reveal_offset = 0xffff;
    granny_cutscene.see_shake_started = false;
}

fn updateGrannyDialogueReveal(cutscene: *const GrannyCutscene) void {
    if (granny_cutscene.dialogue_index >= cutscene.dialogue.len) return;
    const page = cutscene.dialogue[granny_cutscene.dialogue_index];
    if (!grannyDialogueUsesTypewriter(page.text)) {
        granny_cutscene.dialogue_reveal_offset = page.text.len;
        return;
    }

    const target = wrappedTextNextOffset(page.text, granny_cutscene.dialogue_offset, cutscene_dialogue_text_max_chars, cutscene_dialogue_text_max_lines);
    if (granny_cutscene.dialogue_reveal_offset < granny_cutscene.dialogue_offset) {
        granny_cutscene.dialogue_reveal_offset = skipTextSpaces(page.text, granny_cutscene.dialogue_offset);
    }
    if (granny_cutscene.dialogue_reveal_offset >= target) return;

    granny_cutscene.dialogue_reveal_timer +%= 1;
    if (granny_cutscene.dialogue_reveal_timer < cutscene_ominous_reveal_interval_frames) return;
    granny_cutscene.dialogue_reveal_timer = 0;

    const old_offset = granny_cutscene.dialogue_reveal_offset;
    const new_offset = advanceTextRevealByWords(page.text, old_offset, target, cutscene_ominous_words_per_tick);
    revealGrannyDialogueTo(page.text, new_offset);
}

fn revealGrannyDialogueTo(text: []const u8, offset: usize) void {
    const old_offset = granny_cutscene.dialogue_reveal_offset;
    granny_cutscene.dialogue_reveal_offset = offset;
    maybeTriggerSeeShake(text, old_offset, offset);
    granny_cutscene.rendered_dialogue_index = 255;
}

fn maybeTriggerSeeShake(text: []const u8, old_offset: usize, new_offset: usize) void {
    if (granny_cutscene.see_shake_started) return;
    const phrase_start = findSubstring(text, "see things") orelse return;
    const see_end = phrase_start + 3;
    if (old_offset < see_end and new_offset >= see_end) {
        granny_cutscene.shake_timer = cutscene_ominous_shake_frames;
        granny_cutscene.see_shake_started = true;
    }
}

fn grannyCutsceneOminousPage(cutscene: *const GrannyCutscene) bool {
    if (granny_cutscene.phase == .laugh_pause) return true;
    if (granny_cutscene.phase != .dialogue or granny_cutscene.dialogue_index >= cutscene.dialogue.len) return false;
    return granny_cutscene.dialogue_index >= 3 or grannyDialogueUsesTypewriter(cutscene.dialogue[granny_cutscene.dialogue_index].text);
}

fn grannyDialogueUsesTypewriter(text: []const u8) bool {
    return textContains(text, "strange place") or
        textContains(text, "see things") or
        textContains(text, "ready to see");
}

fn playerOverlapsSceneRect(player: Player, rect: SceneRect) bool {
    const left = fixedToPixel(player.x);
    const top = fixedToPixel(player.y);
    return rectsOverlap(left, top, left + player_body_width, top + player_body_height, rect.x, rect.y, rect.right(), rect.bottom());
}

fn movePlayerTowardCutscenePoint(player: *Player, point: Spawn, speed: i16) bool {
    const target = cutscenePlayerTarget(point);
    const x = fixedToPixel(player.x);
    const y = fixedToPixel(player.y);
    const dx = target.x - x;
    const dy = target.y - y;
    if (absI16(dx) <= speed and absI16(dy) <= speed) {
        player.x = pixelToFixed(target.x);
        player.y = pixelToFixed(target.y);
        player.moving = false;
        return true;
    }
    player.x = pixelToFixed(x + signI16(dx) * @min(absI16(dx), speed));
    player.y = pixelToFixed(y + signI16(dy) * @min(absI16(dy), speed));
    player.moving = dx != 0;
    return false;
}

fn cutscenePlayerTarget(point: Spawn) Spawn {
    return .{
        .x = point.x - player_body_width / 2,
        .y = point.y - player_body_height,
    };
}

fn startLaughTextBurst(cutscene: *const GrannyCutscene, source_room_index: usize, emit_total: u8, follow_camera: bool, continuous: bool) void {
    const room = rooms[source_room_index];
    laugh_text = .{
        .active = true,
        .room_index = source_room_index,
        .start_x = room.world_x + cutscene.laugh_start.x,
        .start_y = room.world_y + cutscene.laugh_start.y,
        .end_x = room.world_x + cutscene.laugh_end.x,
        .end_y = room.world_y + cutscene.laugh_end.y,
        .timer = 0,
        .emitted = 0,
        .emit_total = emit_total,
        .follow_camera = follow_camera,
        .continuous = continuous,
        .particles = [_]LaughHaParticle{.{}} ** cutscene_laugh_object_count,
    };
    loadLaughHaTiles();
    spawnInitialLaughHaParticles();
}

fn updateLaughText(room_index: usize, camera: Camera) void {
    if (!laugh_text.active) return;
    if (laugh_text.follow_camera and laugh_text.room_index != room_index) {
        retargetLaughTextToView(room_index, camera);
    }
    laugh_text.timer +%= 1;

    var any_active = false;
    var index: usize = 0;
    while (index < cutscene_laugh_object_count) : (index += 1) {
        var particle = &laugh_text.particles[index];
        if (!particle.active) continue;
        any_active = true;
        particle.age += 1;
        particle.vy += particle.ay;
        particle.x += particle.vx;
        particle.y += particle.vy;
        if (particle.age >= cutscene_laugh_life_frames) {
            particle.active = false;
        }
    }

    if ((laugh_text.continuous or laugh_text.emitted < laugh_text.emit_total) and laugh_text.timer % cutscene_laugh_emit_every_frames == 0) {
        spawnLaughHaParticle();
    }

    if (!laugh_text.continuous and !any_active and laugh_text.emitted >= laugh_text.emit_total) {
        laugh_text.active = false;
        hideCutsceneLaughObjects();
    }
}

fn handleLaughTextRoomTransition(from_room: usize, to_room: usize) void {
    if (!granny_intro_done or !laugh_text.active) return;
    if (from_room == granny_scene_room_index and to_room != granny_laugh_carry_room_index) {
        stopLaughText();
    }
}

fn stopLaughText() void {
    laugh_text = .{};
    hideCutsceneLaughObjects();
}

fn retargetLaughTextToView(room_index: usize, camera: Camera) void {
    const room = rooms[room_index];
    laugh_text.room_index = room_index;
    laugh_text.start_x = room.world_x + camera.x + 4;
    laugh_text.start_y = room.world_y + camera.y + 28;
    laugh_text.end_x = laugh_text.start_x + 96;
    laugh_text.end_y = laugh_text.start_y - 12;
    laugh_text.timer = 0;
    laugh_text.emitted = 0;
    laugh_text.emit_total = 0;
    laugh_text.particles = [_]LaughHaParticle{.{}} ** cutscene_laugh_object_count;
    loadLaughHaTiles();
    spawnInitialLaughHaParticles();
}

fn spawnInitialLaughHaParticles() void {
    if (laugh_text.continuous or laugh_text.emitted < laugh_text.emit_total) {
        spawnLaughHaParticle();
    }
}

fn spawnLaughHaParticle() void {
    const slot = firstFreeLaughHaParticle() orelse return;
    const seed = laugh_text.emitted;
    laugh_text.particles[slot] = .{
        .active = true,
        .x = pixelToFixed(laugh_text.start_x),
        .y = pixelToFixed(laugh_text.start_y),
        .vx = cutscene_laugh_vx + @as(i32, @intCast(seed % 3)) * 0x08,
        .vy = cutscene_laugh_vy - @as(i32, @intCast((seed + 1) % 3)) * 0x04,
        .ay = cutscene_laugh_ay,
        .age = 0,
        .seed = seed,
    };
    laugh_text.emitted += 1;
}

fn firstFreeLaughHaParticle() ?usize {
    var index: usize = 0;
    while (index < cutscene_laugh_object_count) : (index += 1) {
        if (!laugh_text.particles[index].active) return index;
    }
    return null;
}

fn laughBob(tick: u8) i16 {
    const phase = tick & 15;
    if (phase < 4) return -1;
    if (phase < 8) return -3;
    if (phase < 12) return -2;
    return 0;
}

fn loadLaughHaTiles() void {
    if (cutscene_laugh_tiles_loaded) return;
    gba.display.memcpyObjectTiles4Bpp(cutscene_laugh_base_tile, @ptrCast(&granny_haha_tiles_data));
    cutscene_laugh_tiles_loaded = true;
}

fn wallSlideContact(player: Player, horizontal: i16, room_index: usize) bool {
    if (horizontal == 0) return false;
    return wallContact(player, horizontal, room_index);
}

fn wallJumpDirection(player: Player, horizontal: i16, room_index: usize) i16 {
    if (wallContact(player, -1, room_index) and horizontal <= 0) return 1;
    if (wallContact(player, 1, room_index) and horizontal >= 0) return -1;
    if (wallContact(player, -1, room_index)) return 1;
    if (wallContact(player, 1, room_index)) return -1;
    return 0;
}

fn wallContact(player: Player, dir: i16, room_index: usize) bool {
    const side_offset: i16 = if (dir < 0) -1 else player_body_width;
    const x = fixedToPixel(player.x) + side_offset;
    const y = fixedToPixel(player.y);
    return wallSolidAtPixel(x, y + 2, room_index) or
        wallSolidAtPixel(x, y + player_body_height - 3, room_index);
}

fn wallSolidAtPixel(x: i16, y: i16, room_index: usize) bool {
    return solidAtPixel(x, y, room_index) or dynamicSolidAtPixel(x, y);
}

fn floorContact(player: Player, room_index: usize) bool {
    return floorContactAt(fixedToPixel(player.x), fixedToPixel(player.y), room_index);
}

fn floorContactAt(x: i16, y: i16, room_index: usize) bool {
    return collidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index) or funnyCarFloorAt(x, y);
}

fn trySwitchRoom(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize, respawn: *Spawn) bool {
    if (player.room_transition_cooldown > 0) return false;

    const room = rooms[room_index.*];
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    if (input.isPressed(.right) and player_x >= room.width_pixels - player_body_width) {
        if (room.right) |next_room| {
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, room_index.*, next_room);
            room_index.* = next_room;
            enterRoomFromLeft(player);
            fitOrSnapPlayerAfterSideRoomEntry(player, room_index.*, source_floor_world_y);
            respawn.* = rooms[room_index.*].spawn_left;
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    if (input.isPressed(.left) and player_x <= 0) {
        if (room.left) |next_room| {
            const source_floor_world_y = if (player.grounded or floorContact(player.*, room_index.*))
                sideTransitionSourceFloorWorldY(player.*, room_index.*)
            else
                null;
            alignPlayerBetweenRooms(player, room_index.*, next_room);
            room_index.* = next_room;
            enterRoomFromRight(player, room_index.*);
            fitOrSnapPlayerAfterSideRoomEntry(player, room_index.*, source_floor_world_y);
            respawn.* = rooms[room_index.*].spawn_right;
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    if (player_y <= 0) {
        if (room.up) |next_room| {
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromBottom(player, room_index.*);
            fitPlayerAfterRoomEntry(player, room_index.*);
            respawn.* = rooms[room_index.*].spawn_bottom;
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    if (player_y >= room.height_pixels - player_body_height - 1) {
        if (room.down) |next_room| {
            room_index.* = next_room;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromTop(player);
            fitPlayerAfterRoomEntry(player, room_index.*);
            respawn.* = rooms[room_index.*].spawn_top;
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    return false;
}

fn startRoomTransitionCooldown(player: *Player) void {
    player.room_transition_cooldown = player_room_transition_cooldown_frames;
}

fn playerInDeathPit(player: Player, room_index: usize) bool {
    const room = rooms[room_index];
    if (room.down != null) return false;
    return fixedToPixel(player.y) > room.height_pixels + 8;
}

fn playerTouchingSpike(player: Player, room_index: usize) bool {
    return spikeRectAt(
        fixedToPixel(player.x),
        fixedToPixel(player.y),
        player_body_width,
        player_body_height,
        room_index,
    );
}

fn beginPlayerDeath(death_timer: *u8, player: Player, room_index: usize, camera: Camera, cause: PlayerDeathCause) void {
    _ = room_index;
    if (granny_intro_done and laugh_text.active) {
        stopLaughText();
    }
    death_timer.* = player_death_anim_frames;
    death_origin_x = player.x + (player_body_width / 2) * fixed_one;
    death_origin_y = player.y + (player_body_height / 2) * fixed_one;
    death_player_x = player.x;
    death_player_y = player.y;
    death_player_facing_left = player.facing_left;
    death_intro_offset_x = 0;
    death_intro_offset_y = 0;
    if (cause == .fall_down) {
        death_intro_first_frame = 0;
        death_intro_frame_count = 0;
        death_intro_total_frames = 0;
    } else {
        const death_intro = selectPlayerDeathIntro(player, cause);
        death_intro_first_frame = death_intro.first_frame;
        death_intro_frame_count = death_intro.frame_count;
        death_intro_total_frames = playerDeathIntroTotalFrames(death_intro.frame_count);
        if (death_intro.frame_count != 0) {
            const offset = deathIntroScreenCenterOffset(player, camera);
            death_intro_offset_x = @as(i32, offset.x) << fixed_shift;
            death_intro_offset_y = @as(i32, offset.y) << fixed_shift;
            death_origin_x += death_intro_offset_x;
            death_origin_y += death_intro_offset_y;
        }
    }
    hideObject(player_object);
    hideObject(hair_root_object);
    hideObject(hair_object);
    hideObject(sweat_object);
    clearDustParticles();
    clearDashEffects();
}

fn deathIntroScreenCenterOffset(player: Player, camera: Camera) struct { x: i16, y: i16 } {
    const player_center_x = fixedToPixel(player.x) + player_body_width / 2 - camera.x;
    const player_center_y = fixedToPixel(player.y) + player_body_height / 2 - camera.y;
    const to_center_x: i16 = screen_width / 2 - player_center_x;
    const to_center_y: i16 = screen_height / 2 - player_center_y;
    const max_component = maxI16(absI16(to_center_x), absI16(to_center_y));
    if (max_component == 0) return .{ .x = 0, .y = -player_death_intro_travel_pixels };

    const travel = @min(max_component, player_death_intro_travel_pixels);
    return .{
        .x = @intCast(@divTrunc(@as(i32, to_center_x) * travel, max_component)),
        .y = @intCast(@divTrunc(@as(i32, to_center_y) * travel, max_component)),
    };
}

fn selectPlayerDeathIntro(player: Player, cause: PlayerDeathCause) PlayerDeathIntro {
    if (cause == .fall_down and player_deadown_frame_count != 0) {
        return .{ .first_frame = player_deadown_first_frame, .frame_count = player_deadown_frame_count };
    }
    if (player.vy < -fixed_one and player_deathup_frame_count != 0) {
        return .{ .first_frame = player_deathup_first_frame, .frame_count = player_deathup_frame_count };
    }
    if (absI32(player.vx) > fixed_one and player_deathside_frame_count != 0) {
        death_player_facing_left = player.vx < 0;
        return .{ .first_frame = player_deathside_first_frame, .frame_count = player_deathside_frame_count };
    }
    if (player_deadown_frame_count != 0) {
        return .{ .first_frame = player_deadown_first_frame, .frame_count = player_deadown_frame_count };
    }
    if (player_deathside_frame_count != 0) {
        return .{ .first_frame = player_deathside_first_frame, .frame_count = player_deathside_frame_count };
    }
    if (player_deathup_frame_count != 0) {
        return .{ .first_frame = player_deathup_first_frame, .frame_count = player_deathup_frame_count };
    }
    return .{ .first_frame = 0, .frame_count = 0 };
}

fn playerDeathIntroTotalFrames(frame_count: u16) u8 {
    if (frame_count == 0) return 0;
    const total = frame_count * player_death_intro_frame_hold;
    return @intCast(@min(@as(u16, player_death_intro_max_frames), total));
}

fn updateCamera(player: Player, room_index: usize) Camera {
    const room = rooms[room_index];
    const desired_x = fixedToPixel(player.x) - 120;
    const desired_y = fixedToPixel(player.y) - 120;
    return .{
        .x = clampI16(desired_x, 0, room.width_pixels - screen_width),
        .y = clampI16(desired_y, 0, room.height_pixels - screen_height),
    };
}

fn applyCamera(camera: Camera) void {
    streamRoomBackground(current_room_index, camera);
    gba.display.bg_scroll[0] = .init(@intCast(camera.x), @intCast(camera.y));
}

fn renderCameraWithCutsceneShake(camera: Camera, room_index: usize) Camera {
    if ((!granny_cutscene.active or granny_cutscene.shake_timer == 0) and bridge_collapse_shake_tick == 0) return camera;
    const room = rooms[room_index];
    var offset_x: i16 = 0;
    var offset_y: i16 = 0;
    if (granny_cutscene.active and granny_cutscene.shake_timer > 0) {
        const offset = cutsceneShakeOffset(granny_cutscene.shake_timer);
        offset_x += offset.x;
        offset_y += offset.y;
    }
    if (bridge_collapse_shake_tick > 0) {
        const offset = bridgeCollapseShakeOffset(bridge_collapse_shake_tick);
        offset_x += offset.x;
        offset_y += offset.y;
    }
    return .{
        .x = clampI16(camera.x + offset_x, 0, room.width_pixels - screen_width),
        .y = clampI16(camera.y + offset_y, 0, room.height_pixels - screen_height),
    };
}

fn cutsceneShakeOffset(timer: u8) Spawn {
    return switch (timer & 7) {
        0 => .{ .x = 2, .y = 0 },
        1 => .{ .x = -2, .y = 1 },
        2 => .{ .x = 1, .y = -1 },
        3 => .{ .x = -1, .y = 0 },
        4 => .{ .x = 2, .y = 1 },
        5 => .{ .x = -1, .y = -1 },
        6 => .{ .x = 1, .y = 0 },
        else => .{ .x = 0, .y = 0 },
    };
}

fn bridgeCollapseShakeOffset(timer: u8) Spawn {
    return switch (timer & 7) {
        0 => .{ .x = 1, .y = 0 },
        1 => .{ .x = -1, .y = 0 },
        2 => .{ .x = 0, .y = -1 },
        3 => .{ .x = -1, .y = 1 },
        4 => .{ .x = 1, .y = 0 },
        5 => .{ .x = 0, .y = -1 },
        6 => .{ .x = 1, .y = 1 },
        else => .{ .x = 0, .y = 0 },
    };
}

fn streamRoomBackground(room_index: usize, camera: Camera) void {
    const room = rooms[room_index];
    if (roomFitsHardwareBackground(room)) {
        if (bg_stream_room_index != room_index or bg_stream_tile_x != 0 or bg_stream_tile_y != 0) {
            streamRoomBackgroundFull(room_index, 0, 0);
        }
        return;
    }

    const tile_x = @divTrunc(camera.x, 8);
    const tile_y = @divTrunc(camera.y, 8);
    if (bg_stream_room_index != room_index) {
        streamRoomBackgroundFull(room_index, tile_x, tile_y);
        return;
    }

    const delta_x = tile_x - bg_stream_tile_x;
    const delta_y = tile_y - bg_stream_tile_y;
    if (delta_x == 0 and delta_y == 0) return;

    if (delta_x < -1 or delta_x > 1 or delta_y < -1 or delta_y > 1) {
        streamRoomBackgroundFull(room_index, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        streamRoomBackgroundColumn(room_index, tile_x + @as(i16, @intCast(bg_hardware_width_tiles - 1)), tile_y);
    } else if (delta_x < 0) {
        streamRoomBackgroundColumn(room_index, tile_x, tile_y);
    }

    if (delta_y > 0) {
        streamRoomBackgroundRow(room_index, tile_x, tile_y + @as(i16, @intCast(bg_hardware_height_tiles - 1)));
    } else if (delta_y < 0) {
        streamRoomBackgroundRow(room_index, tile_x, tile_y);
    }

    bg_stream_tile_x = tile_x;
    bg_stream_tile_y = tile_y;
}

fn roomFitsHardwareBackground(room: RoomBackground) bool {
    return room.width_tiles <= bg_hardware_width_tiles and room.height_tiles <= bg_hardware_height_tiles;
}

fn streamRoomBackgroundFull(room_index: usize, source_tile_x: i16, source_tile_y: i16) void {
    const room = rooms[room_index];
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);

    var dest_y: usize = 0;
    while (dest_y < bg_hardware_height_tiles) : (dest_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(dest_y));
        var dest_x: usize = 0;
        while (dest_x < bg_hardware_width_tiles) : (dest_x += 1) {
            const src_x = source_tile_x + @as(i16, @intCast(dest_x));
            const raw_entry = logicalRoomMapEntry(room, src_x, src_y);
            const hardware_x = wrapTileIndex(src_x, bg_hardware_width_tiles);
            const hardware_y = wrapTileIndex(src_y, bg_hardware_height_tiles);
            entries[normalBgMapIndex(hardware_x, hardware_y, bg_hardware_width_tiles)] = @bitCast(raw_entry);
        }
    }
    bg_stream_room_index = room_index;
    bg_stream_tile_x = source_tile_x;
    bg_stream_tile_y = source_tile_y;
    if (source_tile_x == 0 and source_tile_y == 0 and roomFitsHardwareBackground(room)) {
        stampStaticRoomWires(room_index);
    }
}

fn streamRoomBackgroundColumn(room_index: usize, src_x: i16, source_tile_y: i16) void {
    const room = rooms[room_index];
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);
    const hardware_x = wrapTileIndex(src_x, bg_hardware_width_tiles);
    var offset_y: usize = 0;
    while (offset_y < bg_hardware_height_tiles) : (offset_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(offset_y));
        const hardware_y = wrapTileIndex(src_y, bg_hardware_height_tiles);
        const raw_entry = logicalRoomMapEntry(room, src_x, src_y);
        entries[normalBgMapIndex(hardware_x, hardware_y, bg_hardware_width_tiles)] = @bitCast(raw_entry);
    }
}

fn streamRoomBackgroundRow(room_index: usize, source_tile_x: i16, src_y: i16) void {
    const room = rooms[room_index];
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);
    const hardware_y = wrapTileIndex(src_y, bg_hardware_height_tiles);
    var offset_x: usize = 0;
    while (offset_x < bg_hardware_width_tiles) : (offset_x += 1) {
        const src_x = source_tile_x + @as(i16, @intCast(offset_x));
        const hardware_x = wrapTileIndex(src_x, bg_hardware_width_tiles);
        const raw_entry = logicalRoomMapEntry(room, src_x, src_y);
        entries[normalBgMapIndex(hardware_x, hardware_y, bg_hardware_width_tiles)] = @bitCast(raw_entry);
    }
}

fn stampStaticRoomWires(room_index: usize) void {
    const room = rooms[room_index];
    const data = room.wires;
    if (data.len < 2 or room.wire_tiles.len == 0) return;
    if (!canStampStaticRoomWires(room_index)) return;

    const room_tile_count = room.tiles.len / 64;
    const tile_capacity = staticWireTileCapacity(room);
    if (room_tile_count >= tile_capacity) return;

    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);
    const count = @min(readU16Le(data, 0), max_wire_chunks);
    var output_tile_count: usize = 0;
    var offset: usize = 2;
    var index: usize = 0;
    while (index < count and offset + 8 <= data.len and output_tile_count + 4 <= static_wire_bg_max_tiles and room_tile_count + output_tile_count + 4 <= tile_capacity) : ({
        index += 1;
        offset += 8;
    }) {
        const wire_x = readI16Le(data, offset);
        const wire_y = readI16Le(data, offset + 2);
        if (wire_x < 0 or wire_y < 0) continue;

        const tile_x: usize = @intCast(@divTrunc(wire_x, 8));
        const tile_y: usize = @intCast(@divTrunc(wire_y, 8));
        if (tile_y >= room.height_tiles or tile_x >= room.width_tiles) continue;

        const wire_tile_offset = readU16Le(data, offset + 4);
        var part: usize = 0;
        while (part < 4 and tile_x + part < room.width_tiles) : (part += 1) {
            const map_x = tile_x + part;
            const raw_entry = logicalRoomMapEntry(room, @intCast(map_x), @intCast(tile_y));
            const source_tile = raw_entry & 0x03ff;
            if (@as(usize, source_tile) * 64 + 63 >= room.tiles.len) continue;

            composeStaticWireTile(room, raw_entry, @as(usize, wire_tile_offset) + part, output_tile_count);
            const new_tile: u16 = @intCast(room_tile_count + output_tile_count);
            entries[normalBgMapIndex(map_x, tile_y, bg_hardware_width_tiles)] = @bitCast((raw_entry & 0xf000) | new_tile);
            output_tile_count += 1;
        }
    }

    if (output_tile_count != 0) {
        gba.display.memcpyTiles8Bpp(0, @intCast(room_tile_count), static_wire_bg_tiles[0..output_tile_count]);
    }
}

fn canStampStaticRoomWires(room_index: usize) bool {
    const room = rooms[room_index];
    if (!roomFitsHardwareBackground(room) or room.wires.len < 2 or room.wire_tiles.len == 0) return false;

    const output_tile_count = staticWireOutputTileCount(room);
    if (output_tile_count == 0 or output_tile_count > static_wire_bg_max_tiles) return false;
    return room.tiles.len / 64 + output_tile_count <= staticWireTileCapacity(room);
}

fn staticWireTileCapacity(room: RoomBackground) usize {
    const first_reserved_screenblock: usize = if (room.parallax != null)
        @min(@as(usize, bg_screenblock), @as(usize, parallax_screenblock))
    else
        @as(usize, bg_screenblock);
    return (first_reserved_screenblock * 2048) / 64;
}

fn staticWireOutputTileCount(room: RoomBackground) usize {
    const data = room.wires;
    const count = @min(readU16Le(data, 0), max_wire_chunks);
    var output_tile_count: usize = 0;
    var offset: usize = 2;
    var index: usize = 0;
    while (index < count and offset + 8 <= data.len) : ({
        index += 1;
        offset += 8;
    }) {
        const wire_x = readI16Le(data, offset);
        const wire_y = readI16Le(data, offset + 2);
        if (wire_x < 0 or wire_y < 0) continue;

        const tile_x: usize = @intCast(@divTrunc(wire_x, 8));
        const tile_y: usize = @intCast(@divTrunc(wire_y, 8));
        if (tile_y >= room.height_tiles or tile_x >= room.width_tiles) continue;

        var part: usize = 0;
        while (part < 4 and tile_x + part < room.width_tiles) : (part += 1) {
            const raw_entry = logicalRoomMapEntry(room, @intCast(tile_x + part), @intCast(tile_y));
            const source_tile = raw_entry & 0x03ff;
            if (@as(usize, source_tile) * 64 + 63 >= room.tiles.len) continue;
            output_tile_count += 1;
        }
    }
    return output_tile_count;
}

fn composeStaticWireTile(room: RoomBackground, raw_entry: u16, wire_tile_index: usize, output_tile_index: usize) void {
    const source_tile = @as(usize, raw_entry & 0x03ff);
    const hflip = (raw_entry & 0x0400) != 0;
    const vflip = (raw_entry & 0x0800) != 0;

    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            const source_x = if (hflip) 7 - x else x;
            const source_y = if (vflip) 7 - y else y;
            var color = room.tiles[source_tile * 64 + source_y * 8 + source_x];
            if (wireTilePixel(wire_tile_index, x, y, room.wire_tiles) != 0) {
                color = static_wire_bg_color_index;
            }
            static_wire_bg_tiles[output_tile_index].pixels[y * 8 + x] = color;
        }
    }
}

fn wireTilePixel(tile_index: usize, x: usize, y: usize, tiles: []align(4) const u8) u8 {
    const byte_offset = tile_index * 32 + y * 4 + x / 2;
    if (byte_offset >= tiles.len) return 0;
    const byte = tiles[byte_offset];
    return if ((x & 1) == 0) byte & 0x0f else byte >> 4;
}

fn logicalRoomMapEntry(room: RoomBackground, x: i16, y: i16) u16 {
    if (x < 0 or y < 0) return 0;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= room.width_tiles or uy >= room.height_tiles) return 0;
    const offset = (uy * room.width_tiles + ux) * 2;
    if (offset + 1 >= room.map.len) return 0;
    return @as(u16, room.map[offset]) | (@as(u16, room.map[offset + 1]) << 8);
}

fn streamParallaxBackground(room_index: usize, parallax: ParallaxLayer, scroll_x: i16, scroll_y: i16) void {
    const tile_x = @divTrunc(scroll_x, 8);
    const tile_y = @divTrunc(scroll_y, 8);
    if (parallax_stream_room_index != room_index) {
        streamParallaxBackgroundFull(room_index, parallax, tile_x, tile_y);
        return;
    }

    const delta_x = tile_x - parallax_stream_tile_x;
    const delta_y = tile_y - parallax_stream_tile_y;
    if (delta_x == 0 and delta_y == 0) return;
    if (delta_x < -1 or delta_x > 1 or delta_y < -1 or delta_y > 1) {
        streamParallaxBackgroundFull(room_index, parallax, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        streamParallaxBackgroundColumn(parallax, tile_x + @as(i16, @intCast(parallax_hardware_width_tiles - 1)), tile_y);
    } else if (delta_x < 0) {
        streamParallaxBackgroundColumn(parallax, tile_x, tile_y);
    }

    if (delta_y > 0) {
        streamParallaxBackgroundRow(parallax, tile_x, tile_y + @as(i16, @intCast(parallax_hardware_height_tiles - 1)));
    } else if (delta_y < 0) {
        streamParallaxBackgroundRow(parallax, tile_x, tile_y);
    }

    parallax_stream_room_index = room_index;
    parallax_stream_tile_x = tile_x;
    parallax_stream_tile_y = tile_y;
}

fn streamParallaxBackgroundFull(room_index: usize, parallax: ParallaxLayer, source_tile_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[parallax_screenblock].entries);
    var dest_y: usize = 0;
    while (dest_y < parallax_hardware_height_tiles) : (dest_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(dest_y));
        var dest_x: usize = 0;
        while (dest_x < parallax_hardware_width_tiles) : (dest_x += 1) {
            const src_x = source_tile_x + @as(i16, @intCast(dest_x));
            const raw_entry = logicalParallaxMapEntry(parallax, src_x, src_y);
            const adjusted_entry = adjustParallaxMapEntry(raw_entry);
            const hardware_x = wrapTileIndex(src_x, parallax_hardware_width_tiles);
            const hardware_y = wrapTileIndex(src_y, parallax_hardware_height_tiles);
            entries[normalBgMapIndex(hardware_x, hardware_y, parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
        }
    }
    parallax_stream_room_index = room_index;
    parallax_stream_tile_x = source_tile_x;
    parallax_stream_tile_y = source_tile_y;
}

fn streamParallaxBackgroundColumn(parallax: ParallaxLayer, src_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[parallax_screenblock].entries);
    const hardware_x = wrapTileIndex(src_x, parallax_hardware_width_tiles);
    var offset_y: usize = 0;
    while (offset_y < parallax_hardware_height_tiles) : (offset_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(offset_y));
        const hardware_y = wrapTileIndex(src_y, parallax_hardware_height_tiles);
        const raw_entry = logicalParallaxMapEntry(parallax, src_x, src_y);
        const adjusted_entry = adjustParallaxMapEntry(raw_entry);
        entries[normalBgMapIndex(hardware_x, hardware_y, parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
    }
}

fn streamParallaxBackgroundRow(parallax: ParallaxLayer, source_tile_x: i16, src_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[parallax_screenblock].entries);
    const hardware_y = wrapTileIndex(src_y, parallax_hardware_height_tiles);
    var offset_x: usize = 0;
    while (offset_x < parallax_hardware_width_tiles) : (offset_x += 1) {
        const src_x = source_tile_x + @as(i16, @intCast(offset_x));
        const hardware_x = wrapTileIndex(src_x, parallax_hardware_width_tiles);
        const raw_entry = logicalParallaxMapEntry(parallax, src_x, src_y);
        const adjusted_entry = adjustParallaxMapEntry(raw_entry);
        entries[normalBgMapIndex(hardware_x, hardware_y, parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
    }
}

fn logicalParallaxMapEntry(parallax: ParallaxLayer, x: i16, y: i16) u16 {
    if (x < 0 or y < 0) return 0;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= parallax.width_tiles or uy >= parallax.height_tiles) return 0;
    const offset = (uy * parallax.width_tiles + ux) * 2;
    if (offset + 1 >= parallax.map.len) return 0;
    return @as(u16, parallax.map[offset]) | (@as(u16, parallax.map[offset + 1]) << 8);
}

fn adjustParallaxMapEntry(entry: u16) u16 {
    return (entry & 0xFC00) | (((entry & 0x03FF) + parallax_tile_offset) & 0x03FF);
}

fn clearParallaxMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[parallax_screenblock].entries);
    var index: usize = 0;
    while (index < 1024) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }
}

fn normalBgMapIndex(x: usize, y: usize, map_width_tiles: usize) usize {
    const screenblock_x = x >> 5;
    const screenblock_y = y >> 5;
    const screenblock_columns = map_width_tiles >> 5;
    const screenblock_index = screenblock_x + (screenblock_y * screenblock_columns);
    return (screenblock_index << 10) + (x & 31) + ((y & 31) << 5);
}

fn wrapTileIndex(value: i16, comptime modulo: usize) usize {
    const wrapped = @mod(value, @as(i16, @intCast(modulo)));
    return @intCast(wrapped);
}

fn drawCutsceneOverlay(camera: Camera, room_index: usize) void {
    if (granny_cutscene.active and granny_cutscene.room_index == room_index and granny_cutscene.phase == .dialogue) {
        if (rooms[room_index].granny_cutscene) |cutscene| {
            renderCutsceneDialogueTiles(cutscene);
            drawCutsceneDialogueObjects(camera, cutscene);
        }
    } else {
        hideCutsceneDialogueObjects();
    }

    drawLaughText(camera, room_index);
}

fn renderCutsceneDialogueTiles(cutscene: *const GrannyCutscene) void {
    if (granny_cutscene.dialogue_index >= cutscene.dialogue.len) return;
    const page = cutscene.dialogue[granny_cutscene.dialogue_index];
    const page_end = wrappedTextNextOffset(page.text, granny_cutscene.dialogue_offset, cutscene_dialogue_text_max_chars, cutscene_dialogue_text_max_lines);
    const reveal_end = if (grannyDialogueUsesTypewriter(page.text))
        @min(granny_cutscene.dialogue_reveal_offset, page_end)
    else
        page_end;
    if (granny_cutscene.rendered_dialogue_index == granny_cutscene.dialogue_index and
        granny_cutscene.rendered_dialogue_offset == granny_cutscene.dialogue_offset and
        granny_cutscene.rendered_dialogue_reveal_offset == reveal_end)
    {
        return;
    }

    clearCutsceneDialogueTiles();
    drawCutsceneBox();
    drawTextLine(page.speaker, 6, 4, speakerNameColor(page.speaker));
    granny_cutscene.dialogue_next_offset = page_end;
    drawWrappedTextUntil(page.text, granny_cutscene.dialogue_offset, reveal_end, 6, 17, cutscene_dialogue_text_max_chars, cutscene_dialogue_text_max_lines, 1);
    gba.display.memcpyObjectTiles4Bpp(cutscene_dialogue_base_tile, &cutscene_dialogue_tiles);
    granny_cutscene.rendered_dialogue_index = granny_cutscene.dialogue_index;
    granny_cutscene.rendered_dialogue_offset = granny_cutscene.dialogue_offset;
    granny_cutscene.rendered_dialogue_reveal_offset = reveal_end;
}

fn drawCutsceneDialogueObjects(camera: Camera, cutscene: *const GrannyCutscene) void {
    const position = Spawn{
        .x = clampI16(cutscene.dialogue_box.x - camera.x, 0, screen_width - cutscene_dialogue_width),
        .y = clampI16(cutscene.dialogue_box.y - camera.y, 0, screen_height - cutscene_dialogue_height),
    };
    var row: usize = 0;
    while (row < cutscene_dialogue_rows) : (row += 1) {
        var col: usize = 0;
        while (col < cutscene_dialogue_cols) : (col += 1) {
            const object_index = cutscene_dialogue_first_object + row * cutscene_dialogue_cols + col;
            const tile_index: u10 = @intCast((row * cutscene_dialogue_cols + col) * cutscene_dialogue_tiles_per_object);
            gba.display.objects[object_index] = gba.display.Object.init(.{
                .size = .size_32x16,
                .x = objX(position.x + @as(i16, @intCast(col * 32))),
                .y = objY(position.y + @as(i16, @intCast(row * 16))),
                .base_tile = cutscene_dialogue_base_tile + tile_index,
                .priority = 0,
                .palette = cutscene_dialogue_palette_bank,
            });
        }
    }
    cutscene_dialogue_visible = true;
}

fn speakerNameColor(speaker: []const u8) u8 {
    if (textStartsWith(speaker, "Madeline")) return cutscene_dialogue_madeline_name_color;
    if (textStartsWith(speaker, "Old") or textStartsWith(speaker, "Granny")) return cutscene_dialogue_granny_name_color;
    return cutscene_dialogue_default_name_color;
}

fn textStartsWith(text: []const u8, prefix: []const u8) bool {
    if (text.len < prefix.len) return false;
    var index: usize = 0;
    while (index < prefix.len) : (index += 1) {
        if (text[index] != prefix[index]) return false;
    }
    return true;
}

fn textEquals(text: []const u8, other: []const u8) bool {
    return text.len == other.len and textStartsWith(text, other);
}

fn textContains(text: []const u8, needle: []const u8) bool {
    return findSubstring(text, needle) != null;
}

fn findSubstring(text: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (text.len < needle.len) return null;
    var index: usize = 0;
    while (index + needle.len <= text.len) : (index += 1) {
        var matched = true;
        var needle_index: usize = 0;
        while (needle_index < needle.len) : (needle_index += 1) {
            if (text[index + needle_index] != needle[needle_index]) {
                matched = false;
                break;
            }
        }
        if (matched) return index;
    }
    return null;
}

fn hideCutsceneDialogueObjects() void {
    if (!cutscene_dialogue_visible) return;
    var index: usize = 0;
    while (index < cutscene_dialogue_object_count) : (index += 1) {
        hideObject(cutscene_dialogue_first_object + index);
    }
    cutscene_dialogue_visible = false;
}

fn drawLaughText(camera: Camera, room_index: usize) void {
    if (!laugh_text.active) {
        hideCutsceneLaughObjects();
        return;
    }
    loadLaughHaTiles();
    const room = rooms[room_index];
    var index: usize = 0;
    while (index < cutscene_laugh_object_count) : (index += 1) {
        const particle = laugh_text.particles[index];
        if (!particle.active) {
            hideObject(cutscene_laugh_first_object + index);
            continue;
        }
        const screen_x = fixedToPixel(particle.x) - (room.world_x + camera.x);
        const screen_y = fixedToPixel(particle.y) + laughWave(particle.age, particle.seed) - (room.world_y + camera.y);
        const frame = laughHaFrame(particle.age);
        gba.display.objects[cutscene_laugh_first_object + index] = gba.display.Object.init(.{
            .size = .size_16x16,
            .x = objX(screen_x),
            .y = objY(screen_y),
            .base_tile = cutscene_laugh_base_tile + @as(u10, @intCast(frame)) * cutscene_laugh_tiles_per_frame,
            .priority = 0,
            .palette = cutscene_dialogue_palette_bank,
        });
    }
    cutscene_laugh_visible = true;
}

fn laughHaFrame(age: u8) u8 {
    if (age < cutscene_laugh_flash_life_frames) {
        return @intCast((age / cutscene_laugh_flash_frame_hold_frames) & 1);
    }
    const tail_age = age - cutscene_laugh_flash_life_frames;
    return @min(@as(u8, cutscene_laugh_haha_frame_count - 1), 2 + tail_age / cutscene_laugh_tail_frame_hold_frames);
}

fn laughWave(age: u8, seed: u8) i16 {
    const wave = [_]i16{
        0,  -1, -2, -3, -4, -4, -3, -2,
        -1, 0,  1,  2,  3,  3,  2,  1,
        0,  -1, -2, -2, -1, 0,  1,  1,
    };
    const phase: usize = @intCast((@divTrunc(@as(u16, age), 3) + @as(u16, seed) * 5) % wave.len);
    return wave[phase];
}

fn hideCutsceneLaughObjects() void {
    if (!cutscene_laugh_visible) return;
    var index: usize = 0;
    while (index < cutscene_laugh_object_count) : (index += 1) {
        hideObject(cutscene_laugh_first_object + index);
    }
    cutscene_laugh_visible = false;
}

fn clearCutsceneDialogueTiles() void {
    cutscene_dialogue_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** cutscene_dialogue_tile_count;
}

fn drawCutsceneBox() void {
    var y: i16 = 0;
    while (y < cutscene_dialogue_height) : (y += 1) {
        var x: i16 = 0;
        while (x < cutscene_dialogue_width) : (x += 1) {
            const border = x == 0 or y == 0 or x == cutscene_dialogue_width - 1 or y == cutscene_dialogue_height - 1;
            setCutsceneDialoguePixel(x, y, if (border) 1 else 6);
        }
    }
    var x: i16 = 4;
    while (x < cutscene_dialogue_width - 4) : (x += 1) {
        setCutsceneDialoguePixel(x, 14, 1);
    }
}

fn drawWrappedSmallText(text: []const u8, start_offset: usize, x: i16, y: i16, max_chars: usize, max_lines: usize, color: u8) usize {
    var offset = skipTextSpaces(text, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < text.len) : (line += 1) {
        const line_start = offset;
        var pos = offset;
        var count: usize = 0;
        var last_space: usize = text.len + 1;
        while (pos < text.len and count < max_chars) : ({
            pos += 1;
            count += 1;
        }) {
            const ch = text[pos];
            if (ch == '\n') break;
            if (ch == ' ') last_space = pos;
        }

        var line_end = pos;
        if (pos < text.len and text[pos] != ' ' and text[pos] != '\n' and count >= max_chars and last_space > line_start and last_space <= text.len) {
            line_end = last_space;
        }
        drawSmallTextLine(text[line_start..line_end], x, y + @as(i16, @intCast(line * 6)), color);

        offset = line_end;
        if (offset < text.len and text[offset] == '\n') {
            offset += 1;
        }
        offset = skipTextSpaces(text, offset);
    }
    return offset;
}

fn wrappedTextNextOffset(text: []const u8, start_offset: usize, max_chars: usize, max_lines: usize) usize {
    var offset = skipTextSpaces(text, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < text.len) : (line += 1) {
        offset = advanceWrappedTextOffset(text, wrappedTextLineEnd(text, offset, max_chars));
    }
    return offset;
}

fn drawWrappedTextUntil(text: []const u8, start_offset: usize, visible_offset: usize, x: i16, y: i16, max_chars: usize, max_lines: usize, color: u8) void {
    var offset = skipTextSpaces(text, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < text.len) : (line += 1) {
        const line_start = offset;
        const line_end = wrappedTextLineEnd(text, offset, max_chars);
        const visible_end = @min(line_end, visible_offset);
        if (visible_end > line_start) {
            drawTextLine(text[line_start..visible_end], x, y + @as(i16, @intCast(line * 9)), color);
        }
        if (visible_offset <= line_end) break;
        offset = advanceWrappedTextOffset(text, line_end);
    }
}

fn drawWrappedText(text: []const u8, start_offset: usize, x: i16, y: i16, max_chars: usize, max_lines: usize, color: u8) usize {
    var offset = skipTextSpaces(text, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < text.len) : (line += 1) {
        const line_end = wrappedTextLineEnd(text, offset, max_chars);
        drawTextLine(text[offset..line_end], x, y + @as(i16, @intCast(line * 9)), color);
        offset = advanceWrappedTextOffset(text, line_end);
    }
    return offset;
}

fn wrappedTextLineEnd(text: []const u8, offset: usize, max_chars: usize) usize {
    const line_start = offset;
    var pos = offset;
    var count: usize = 0;
    var last_space: usize = text.len + 1;
    while (pos < text.len and count < max_chars) : ({
        pos += 1;
        count += 1;
    }) {
        const ch = text[pos];
        if (ch == '\n') break;
        if (ch == ' ') last_space = pos;
    }

    var line_end = pos;
    if (pos < text.len and text[pos] != ' ' and text[pos] != '\n' and count >= max_chars and last_space > line_start and last_space <= text.len) {
        line_end = last_space;
    }
    return line_end;
}

fn advanceWrappedTextOffset(text: []const u8, line_end: usize) usize {
    var offset = line_end;
    if (offset < text.len and text[offset] == '\n') {
        offset += 1;
    }
    return skipTextSpaces(text, offset);
}

fn advanceTextRevealByWords(text: []const u8, start_offset: usize, target_offset: usize, word_count: u8) usize {
    var offset = skipTextSpacesUntil(text, start_offset, target_offset);
    var words: u8 = 0;
    while (offset < target_offset and words < word_count) : (words += 1) {
        while (offset < target_offset and text[offset] != ' ' and text[offset] != '\n') : (offset += 1) {}
        offset = skipTextSpacesUntil(text, offset, target_offset);
    }
    return offset;
}

fn skipTextSpacesUntil(text: []const u8, start: usize, end: usize) usize {
    var offset = start;
    while (offset < end and offset < text.len and text[offset] == ' ') : (offset += 1) {}
    return offset;
}

fn drawSmallTextLine(text: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (text) |ch| {
        if (cursor > cutscene_dialogue_width - 4) break;
        drawSmallGlyph(ch, cursor, y, color);
        cursor += 4;
    }
}

fn drawSmallGlyph(input: u8, x: i16, y: i16, color: u8) void {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    const rows = smallFontRows(ch);
    for (rows, 0..) |row_bits, row| {
        var col: usize = 0;
        while (col < 3) : (col += 1) {
            if ((row_bits & (@as(u3, 1) << @intCast(2 - col))) != 0) {
                setCutsceneDialoguePixel(x + @as(i16, @intCast(col)), y + @as(i16, @intCast(row)), color);
            }
        }
    }
}

fn smallFontRows(ch: u8) [5]u3 {
    return switch (ch) {
        'A' => .{ 0b010, 0b101, 0b111, 0b101, 0b101 },
        'B' => .{ 0b110, 0b101, 0b110, 0b101, 0b110 },
        'C' => .{ 0b011, 0b100, 0b100, 0b100, 0b011 },
        'D' => .{ 0b110, 0b101, 0b101, 0b101, 0b110 },
        'E' => .{ 0b111, 0b100, 0b110, 0b100, 0b111 },
        'F' => .{ 0b111, 0b100, 0b110, 0b100, 0b100 },
        'G' => .{ 0b011, 0b100, 0b101, 0b101, 0b011 },
        'H' => .{ 0b101, 0b101, 0b111, 0b101, 0b101 },
        'I' => .{ 0b111, 0b010, 0b010, 0b010, 0b111 },
        'J' => .{ 0b001, 0b001, 0b001, 0b101, 0b010 },
        'K' => .{ 0b101, 0b101, 0b110, 0b101, 0b101 },
        'L' => .{ 0b100, 0b100, 0b100, 0b100, 0b111 },
        'M' => .{ 0b101, 0b111, 0b111, 0b101, 0b101 },
        'N' => .{ 0b101, 0b111, 0b111, 0b111, 0b101 },
        'O' => .{ 0b010, 0b101, 0b101, 0b101, 0b010 },
        'P' => .{ 0b110, 0b101, 0b110, 0b100, 0b100 },
        'Q' => .{ 0b010, 0b101, 0b101, 0b111, 0b011 },
        'R' => .{ 0b110, 0b101, 0b110, 0b101, 0b101 },
        'S' => .{ 0b011, 0b100, 0b010, 0b001, 0b110 },
        'T' => .{ 0b111, 0b010, 0b010, 0b010, 0b010 },
        'U' => .{ 0b101, 0b101, 0b101, 0b101, 0b111 },
        'V' => .{ 0b101, 0b101, 0b101, 0b101, 0b010 },
        'W' => .{ 0b101, 0b101, 0b111, 0b111, 0b101 },
        'X' => .{ 0b101, 0b101, 0b010, 0b101, 0b101 },
        'Y' => .{ 0b101, 0b101, 0b010, 0b010, 0b010 },
        'Z' => .{ 0b111, 0b001, 0b010, 0b100, 0b111 },
        '0' => .{ 0b111, 0b101, 0b101, 0b101, 0b111 },
        '1' => .{ 0b010, 0b110, 0b010, 0b010, 0b111 },
        '2' => .{ 0b110, 0b001, 0b010, 0b100, 0b111 },
        '3' => .{ 0b110, 0b001, 0b010, 0b001, 0b110 },
        '4' => .{ 0b101, 0b101, 0b111, 0b001, 0b001 },
        '5' => .{ 0b111, 0b100, 0b110, 0b001, 0b110 },
        '6' => .{ 0b011, 0b100, 0b110, 0b101, 0b010 },
        '7' => .{ 0b111, 0b001, 0b010, 0b010, 0b010 },
        '8' => .{ 0b010, 0b101, 0b010, 0b101, 0b010 },
        '9' => .{ 0b010, 0b101, 0b011, 0b001, 0b110 },
        '.' => .{ 0, 0, 0, 0, 0b010 },
        ',' => .{ 0, 0, 0, 0b010, 0b100 },
        '?' => .{ 0b110, 0b001, 0b010, 0, 0b010 },
        '!' => .{ 0b010, 0b010, 0b010, 0, 0b010 },
        '\'' => .{ 0b010, 0b010, 0, 0, 0 },
        '"' => .{ 0b101, 0b101, 0, 0, 0 },
        '-' => .{ 0, 0, 0b111, 0, 0 },
        ':' => .{ 0, 0b010, 0, 0b010, 0 },
        else => .{ 0, 0, 0, 0, 0 },
    };
}

fn skipTextSpaces(text: []const u8, start: usize) usize {
    var offset = start;
    while (offset < text.len and text[offset] == ' ') : (offset += 1) {}
    return offset;
}

fn drawTextLine(text: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (text) |ch| {
        if (cursor > cutscene_dialogue_width - 6) break;
        drawGlyph(ch, cursor, y, color);
        cursor += 6;
    }
}

fn drawGlyph(input: u8, x: i16, y: i16, color: u8) void {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    const rows = fontRows(ch);
    for (rows, 0..) |row_bits, row| {
        var col: usize = 0;
        while (col < 5) : (col += 1) {
            if ((row_bits & (@as(u8, 1) << @intCast(4 - col))) != 0) {
                setCutsceneDialoguePixel(x + @as(i16, @intCast(col)), y + @as(i16, @intCast(row)), color);
            }
        }
    }
}

fn fontRows(ch: u8) [7]u8 {
    return switch (ch) {
        'A' => .{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'B' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 },
        'C' => .{ 0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111 },
        'D' => .{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 },
        'E' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 },
        'F' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 },
        'G' => .{ 0b01111, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110 },
        'H' => .{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'I' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111 },
        'J' => .{ 0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100 },
        'K' => .{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
        'L' => .{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 },
        'M' => .{ 0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001 },
        'N' => .{ 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001 },
        'O' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'P' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 },
        'Q' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 },
        'R' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 },
        'S' => .{ 0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110 },
        'T' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
        'U' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'V' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100 },
        'W' => .{ 0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010 },
        'X' => .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001 },
        'Y' => .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100 },
        'Z' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111 },
        '0' => .{ 0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110 },
        '1' => .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        '2' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b10000, 0b10000, 0b11111 },
        '3' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 },
        '4' => .{ 0b10010, 0b10010, 0b10010, 0b11111, 0b00010, 0b00010, 0b00010 },
        '5' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110 },
        '6' => .{ 0b01111, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
        '7' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
        '8' => .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
        '9' => .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b11110 },
        '.' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01100 },
        ',' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01000 },
        '?' => .{ 0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0, 0b00100 },
        '!' => .{ 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0, 0b00100 },
        '\'' => .{ 0b00100, 0b00100, 0b01000, 0, 0, 0, 0 },
        '"' => .{ 0b01010, 0b01010, 0, 0, 0, 0, 0 },
        '-' => .{ 0, 0, 0, 0b11110, 0, 0, 0 },
        ':' => .{ 0, 0b01100, 0b01100, 0, 0b01100, 0b01100, 0 },
        '/' => .{ 0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000 },
        else => .{ 0, 0, 0, 0, 0, 0, 0 },
    };
}

fn setCutsceneDialoguePixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= cutscene_dialogue_width or y < 0 or y >= cutscene_dialogue_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const chunk_x = ux / 32;
    const chunk_y = uy / 16;
    const chunk_index = chunk_y * cutscene_dialogue_cols + chunk_x;
    const tile_x = (ux & 31) / 8;
    const tile_y = (uy & 15) / 8;
    const local_x = ux & 7;
    const local_y = uy & 7;
    const tile_index = chunk_index * cutscene_dialogue_tiles_per_object + tile_y * 4 + tile_x;
    const byte_index = local_y * 4 + local_x / 2;
    if ((local_x & 1) == 0) {
        cutscene_dialogue_tiles[tile_index].data_8[byte_index] = (cutscene_dialogue_tiles[tile_index].data_8[byte_index] & 0xF0) | color;
    } else {
        cutscene_dialogue_tiles[tile_index].data_8[byte_index] = (cutscene_dialogue_tiles[tile_index].data_8[byte_index] & 0x0F) | (color << 4);
    }
}

fn drawPlayer(player: Player, camera: Camera) void {
    updatePlayerPalette(player);
    loadPlayerFrame(player.frame);
    const draw_x = fixedToPixel(player.x) - camera.x + player_draw_offset_x;
    const draw_y = fixedToPixel(player.y) - camera.y + player_draw_offset_y;
    gba.display.objects[player_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = 0,
        .priority = 1,
        .palette = 0,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn drawDashEffects(camera: Camera) void {
    var index: usize = 0;
    while (index < dash_afterimage_count) : (index += 1) {
        const object_index = dash_afterimage_first_object + index;
        const image = dash_afterimages[index];
        if (!image.active) {
            hideObject(object_index);
            continue;
        }
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = .size_32x32,
            .x = objX(fixedToPixel(image.x) + player_draw_offset_x - camera.x),
            .y = objY(fixedToPixel(image.y) + player_draw_offset_y - camera.y),
            .base_tile = 0,
            .priority = 1,
            .palette = dashAfterimagePalette(image.life),
            .flip = gba.math.Vec2B.init(image.facing_left, false),
        });
    }

    if (dash_burst.active) {
        gba.display.objects[dash_burst_object] = gba.display.Object.init(.{
            .size = .size_32x32,
            .x = objX(dash_burst.x - camera.x),
            .y = objY(dash_burst.y - camera.y),
            .base_tile = dash_effect_base_tile,
            .priority = 2,
            .palette = dash_effect_palette_bank,
            .flip = gba.math.Vec2B.init(dash_burst.flip_x, dash_burst.flip_y),
        });
    } else {
        hideObject(dash_burst_object);
    }
}

fn dashAfterimagePalette(life: u8) u4 {
    if (life > 9) return dash_shadow_palette_bank;
    if (life > 4) return dash_shadow_palette_bank + 1;
    return dash_shadow_palette_bank + 2;
}

fn updatePlayerPalette(player: Player) void {
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&player_palette_data);
    if (!playerFatigueFlashVisible(player)) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[0], base_palette, 16);
        return;
    }

    gba.display.obj_palette.colors[0] = base_palette[0];
    var index: usize = 0;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[index] = redFatigueTint(base_palette[index]);
    }
}

fn playerFatigueFlashVisible(player: Player) bool {
    if (player.stamina > player_climb_tired_stamina) return false;
    const clamped_stamina: u16 = @intCast(@max(0, player.stamina));
    const period: u16 = 4 + @divTrunc(clamped_stamina * 12, player_climb_tired_stamina);
    return (foreground_anim_counter % period) < period / 2;
}

fn redFatigueTint(color: gba.ColorRgb555) gba.ColorRgb555 {
    const r: u8 = @intCast(color.r);
    const g: u8 = @intCast(color.g);
    const b: u8 = @intCast(color.b);
    return gba.ColorRgb555.rgb(
        @intCast(@min(@as(u8, 31), r + 12)),
        @intCast(g / 2),
        @intCast(b / 2),
    );
}

fn drawSweat(player: *Player, camera: Camera) void {
    if (!player.climbing or player.climb_ledge_timer > 0) {
        hideObject(sweat_object);
        return;
    }

    player.sweat_timer +%= 1;
    const moving = absI32(player.vy) > 0x20;
    const first_frame: u16 = if (moving) sweat_climb_first_frame else sweat_still_first_frame;
    const frame_count: u16 = if (moving) sweat_climb_frame_count else sweat_still_frame_count;
    player.sweat_frame = first_frame + (player.sweat_timer / player_animation_speed) % frame_count;
    loadSweatFrame(player.sweat_frame);

    const draw_x = fixedToPixel(player.x) - camera.x + player_draw_offset_x;
    const draw_y = fixedToPixel(player.y) - camera.y + player_draw_offset_y;
    gba.display.objects[sweat_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = sweat_base_tile,
        .priority = 1,
        .palette = sweat_palette_bank,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn updateHair(player: *Player) void {
    const anchor = hairAnchorWorld(player.*);
    const dir = anchor.dir;
    const ending_hair = bridge_ending_hold;
    const falling_hair = player.animation == .fall and !ending_hair;
    const climb_hair = player.animation == .climb or player.animation == .dangling or player.animation == .climb_pull or player.animation == .wallslide;
    const run_hair = player.animation == .run;
    const root = hairRootWorld(anchor, player.animation);
    const root_x = root.x;
    const root_y = root.y;
    if (!player.hair_initialized) {
        var index: usize = 0;
        while (index < hair_node_count) : (index += 1) {
            player.hair_nodes[index] = .{
                .x = root_x + @as(i32, dir) * @as(i32, @intCast(index + 1)) * fixed_one,
                .y = root_y + @as(i32, @intCast(index + 1)) * fixed_one * 2,
            };
        }
        player.hair_initialized = true;
    }

    const speed_x = minI32(absI32(player.vx), fixed_one * 2);
    const speed_y = minI32(absI32(player.vy), fixed_one * 4);
    const rest_x: i32 = if (ending_hair)
        @as(i32, dir) * fixed_one
    else if (falling_hair)
        @as(i32, dir) * (fixed_one + @divTrunc(speed_x, 8))
    else if (climb_hair)
        @as(i32, dir) * fixed_one
    else
        @as(i32, dir) * (fixed_one / 2);
    const rest_y: i32 = if (falling_hair)
        -@divTrunc(speed_y, 8)
    else if (ending_hair)
        fixed_one / 2
    else if (player.animation == .jump)
        fixed_one
    else if (climb_hair)
        fixed_one + fixed_one / 2
    else if (run_hair)
        fixed_one + fixed_one * 3 / 4
    else
        fixed_one * 2;
    const desired_dist: i32 = if (ending_hair)
        fixed_one + fixed_one / 2
    else if (run_hair)
        fixed_one + fixed_one * 3 / 4
    else
        fixed_one * 2;

    var prev_x = root_x;
    var prev_y = root_y;
    var index: usize = 0;
    while (index < hair_node_count) : (index += 1) {
        const segment_lift: i32 = if ((falling_hair or ending_hair) and index > 1) fixed_one / 8 else 0;
        const target_x = prev_x + rest_x;
        const target_y = prev_y + rest_y - segment_lift;
        player.hair_nodes[index].x += @divTrunc(target_x - player.hair_nodes[index].x, 4);
        player.hair_nodes[index].y += @divTrunc(target_y - player.hair_nodes[index].y, 4);

        constrainHairNode(&player.hair_nodes[index], prev_x, prev_y, desired_dist);
        prev_x = player.hair_nodes[index].x;
        prev_y = player.hair_nodes[index].y;
    }
}

fn drawHair(player: Player, camera: Camera) void {
    updateHairPalette(player);
    const anchor = hairAnchorWorld(player);
    const ending_hair = bridge_ending_hold;
    const falling_hair = player.animation == .fall and !ending_hair;
    const climb_hair = player.animation == .climb or player.animation == .dangling or player.animation == .climb_pull or player.animation == .wallslide;
    const run_hair = player.animation == .run;
    const root = hairRootWorld(anchor, player.animation);
    const sprite_x = fixedToPixel(root.x) - camera.x - 8;
    const sprite_offset_y: i16 = if (falling_hair) 5 else 4;
    const sprite_y = fixedToPixel(root.y) - camera.y - sprite_offset_y;
    clearHairPixels();
    clearHairBangPixels();

    var points: [hair_node_count + 1]HairNode = undefined;
    points[0] = root;
    var index: usize = 0;
    while (index < hair_node_count) : (index += 1) {
        points[index + 1] = player.hair_nodes[index];
    }
    drawHairPointChain(&points, sprite_x + camera.x, sprite_y + camera.y, anchor.dir, falling_hair, climb_hair, ending_hair, run_hair);
    packHairTiles();
    gba.display.memcpyObjectTiles4Bpp(hair_base_tile, &hair_tiles);
    gba.display.objects[hair_object] = gba.display.Object.init(.{
        .size = .size_16x16,
        .x = objX(sprite_x),
        .y = objY(sprite_y),
        .base_tile = hair_base_tile,
        .priority = 1,
        .palette = hair_palette_bank,
    });

    drawHairBangs(anchor.dir);
    packHairBangTile();
    gba.display.memcpyObjectTiles4Bpp(hair_bang_base_tile, &hair_bang_tiles);
    gba.display.objects[hair_root_object] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(fixedToPixel(root.x) - camera.x - 4),
        .y = objY(fixedToPixel(root.y) - camera.y - 4),
        .base_tile = hair_bang_base_tile,
        .priority = 0,
        .palette = hair_palette_bank,
    });
}

fn updateHairPalette(player: Player) void {
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&hair_palette_data);
    const palette_base = @as(usize, hair_palette_bank) * 16;
    if (player.dash_timer > 0) {
        gba.display.obj_palette.colors[palette_base] = base_palette[0];
        gba.display.obj_palette.colors[palette_base + 1] = .black;
        gba.display.obj_palette.colors[palette_base + 2] = gba.ColorRgb555.rgb(22, 23, 24);
        gba.display.obj_palette.colors[palette_base + 3] = .white;
        var white_index: usize = 4;
        while (white_index < 16) : (white_index += 1) {
            gba.display.obj_palette.colors[palette_base + white_index] = base_palette[white_index];
        }
        return;
    }
    if (player.dashes > 0) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[palette_base], base_palette, 16);
        return;
    }

    gba.display.obj_palette.colors[palette_base] = base_palette[0];
    gba.display.obj_palette.colors[palette_base + 1] = .black;
    gba.display.obj_palette.colors[palette_base + 2] = gba.ColorRgb555.rgb(3, 12, 22);
    gba.display.obj_palette.colors[palette_base + 3] = gba.ColorRgb555.rgb(8, 22, 31);
    var index: usize = 4;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[palette_base + index] = base_palette[index];
    }
}

fn constrainHairNode(node: *HairNode, prev_x: i32, prev_y: i32, desired_dist: i32) void {
    const diff_x = node.x - prev_x;
    const diff_y = node.y - prev_y;
    const dist_sq = @as(i64, diff_x) * diff_x + @as(i64, diff_y) * diff_y;
    if (dist_sq == 0) {
        node.y = prev_y + desired_dist;
        return;
    }
    const dist: i32 = @intCast(sqrtU64(@intCast(dist_sq)));
    if (dist <= desired_dist) return;

    node.x = prev_x + @as(i32, @intCast(@divTrunc(@as(i64, diff_x) * desired_dist, dist)));
    node.y = prev_y + @as(i32, @intCast(@divTrunc(@as(i64, diff_y) * desired_dist, dist)));
}

fn hairRootWorld(anchor: HairAnchor, animation: PlayerAnimation) HairNode {
    _ = animation;
    return .{
        .x = anchor.x,
        .y = anchor.y,
    };
}

fn hairAnchorWorld(player: Player) HairAnchor {
    const anchor_offset = @as(usize, player.frame) * 5;
    var anchor_x: i16 = 18;
    var anchor_y: i16 = 19;
    var dir: i16 = -1;
    if (anchor_offset + 4 < player_hair_anchors_data.len) {
        anchor_x = player_hair_anchors_data[anchor_offset];
        anchor_y = player_hair_anchors_data[anchor_offset + 1];
        dir = if (player_hair_anchors_data[anchor_offset + 2] == 0) -1 else 1;
    }
    if (player.facing_left) {
        anchor_x = 31 - anchor_x;
        dir = -dir;
    }
    const body_x = fixedToPixel(player.x) + player_draw_offset_x;
    const body_y = fixedToPixel(player.y) + player_draw_offset_y;
    return .{
        .x = pixelToFixed(body_x + anchor_x),
        .y = pixelToFixed(body_y + anchor_y),
        .dir = dir,
    };
}

fn clearHairPixels() void {
    var index: usize = 0;
    while (index < hair_pixels.len) : (index += 1) {
        hair_pixels[index] = 0;
    }
}

fn drawHairPointChain(points: *const [hair_node_count + 1]HairNode, origin_x: i16, origin_y: i16, dir: i16, falling_hair: bool, climb_hair: bool, ending_hair: bool, run_hair: bool) void {
    var index: usize = 0;
    while (index < points.len) : (index += 1) {
        drawHairDiscWorld(hairPointDrawX(points, index, dir), points[index].y + fixed_one / 3, origin_x, origin_y, hairPointShadowRadius(index, falling_hair, climb_hair, ending_hair, run_hair), 2);
    }

    index = 0;
    while (index + 1 < points.len) : (index += 1) {
        const radius = minU8(hairPointRadius(index, falling_hair, climb_hair, ending_hair, run_hair), hairPointRadius(index + 1, falling_hair, climb_hair, ending_hair, run_hair));
        drawHairDiscWorld(@divTrunc(hairPointDrawX(points, index, dir) + hairPointDrawX(points, index + 1, dir), 2), @divTrunc(points[index].y + points[index + 1].y, 2), origin_x, origin_y, radius, 3);
    }

    index = 0;
    while (index < points.len) : (index += 1) {
        drawHairDiscWorld(hairPointDrawX(points, index, dir), points[index].y, origin_x, origin_y, hairPointRadius(index, falling_hair, climb_hair, ending_hair, run_hair), 3);
    }

    index = 0;
    while (index < points.len) : (index += 1) {
        drawHairEdgePixels(hairPointDrawX(points, index, dir), points[index].y, origin_x, origin_y, dir, hairPointRadius(index, falling_hair, climb_hair, ending_hair, run_hair));
    }
}

fn hairPointDrawX(points: *const [hair_node_count + 1]HairNode, index: usize, dir: i16) i32 {
    const forward: i32 = if (dir > 0) -1 else 1;
    const crown_offset = if (index == 0) forward * fixed_one else 0;
    return points[index].x + crown_offset;
}

fn hairPointRadius(index: usize, falling_hair: bool, climb_hair: bool, ending_hair: bool, run_hair: bool) u8 {
    if (ending_hair) return if (index == 0) 4 else if (index <= 2) 3 else if (index <= 4) 2 else 1;
    if (falling_hair) return if (index == 0) 4 else if (index <= 2) 3 else if (index <= 4) 2 else 1;
    if (climb_hair) return if (index == 0) 3 else if (index <= 2) 2 else if (index <= 4) 1 else 0;
    if (run_hair) return if (index == 0) 4 else if (index <= 2) 3 else if (index <= 3) 2 else if (index <= 5) 1 else 0;
    if (index == 0) return 4;
    if (index <= 2) return 3;
    if (index <= 4) return 2;
    if (index <= 5) return 1;
    return 0;
}

fn hairPointShadowRadius(index: usize, falling_hair: bool, climb_hair: bool, ending_hair: bool, run_hair: bool) u8 {
    const radius = hairPointRadius(index, falling_hair, climb_hair, ending_hair, run_hair);
    return if (radius > 0) radius - 1 else 0;
}

fn drawHairDiscWorld(world_x: i32, world_y: i32, origin_x: i16, origin_y: i16, radius: u8, color: u8) void {
    const center_x = fixedToPixel(world_x) - origin_x;
    const center_y = fixedToPixel(world_y) - origin_y;
    drawHairDiscLocal(center_x, center_y, radius, color);
}

fn drawHairEdgePixels(world_x: i32, world_y: i32, origin_x: i16, origin_y: i16, dir: i16, radius: u8) void {
    if (radius < 2) return;
    const center_x = fixedToPixel(world_x) - origin_x;
    const center_y = fixedToPixel(world_y) - origin_y;
    const back: i16 = if (dir > 0) 1 else -1;
    const r: i16 = @intCast(radius);

    setHairPixel(center_x + back * r, center_y, 2);
    setHairPixel(center_x + back * (r - 1), center_y + r - 1, 2);
    if (radius >= 3) {
        setHairPixel(center_x + back * (r - 1), center_y - r + 1, 2);
    }
}

fn drawHairDiscLocal(center_x: i16, center_y: i16, radius: u8, color: u8) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setHairPixel(center_x + x, center_y + y, color);
            }
        }
    }
}

fn drawHairBangs(dir: i16) void {
    const forward: i16 = if (dir > 0) -1 else 1;
    const root_x: i16 = 4;
    const root_y: i16 = 4;

    setHairBangPixel(root_x + forward * 2, root_y - 1, 2);
    setHairBangPixel(root_x + forward, root_y, 2);
    setHairBangPixel(root_x + forward * 2, root_y, 2);
}

fn setHairPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= hair_sprite_size or y < 0 or y >= hair_sprite_size) return;
    const index: usize = @intCast(y * hair_sprite_size + x);
    hair_pixels[index] = color;
}

fn clearHairBangPixels() void {
    var index: usize = 0;
    while (index < hair_bang_pixels.len) : (index += 1) {
        hair_bang_pixels[index] = 0;
    }
}

fn setHairBangPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const index: usize = @intCast(y * 8 + x);
    hair_bang_pixels[index] = color;
}

fn packHairTiles() void {
    var tile_y: usize = 0;
    while (tile_y < 2) : (tile_y += 1) {
        var tile_x: usize = 0;
        while (tile_x < 2) : (tile_x += 1) {
            const tile_index = tile_y * 2 + tile_x;
            var byte_index: usize = 0;
            var y: usize = 0;
            while (y < 8) : (y += 1) {
                var x_pair: usize = 0;
                while (x_pair < 4) : (x_pair += 1) {
                    const px_x = tile_x * 8 + x_pair * 2;
                    const px_y = tile_y * 8 + y;
                    const left = hair_pixels[px_y * hair_sprite_size + px_x] & 0x0f;
                    const right = hair_pixels[px_y * hair_sprite_size + px_x + 1] & 0x0f;
                    hair_tiles[tile_index].data_8[byte_index] = left | (right << 4);
                    byte_index += 1;
                }
            }
        }
    }
}

fn packHairBangTile() void {
    var byte_index: usize = 0;
    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x_pair: usize = 0;
        while (x_pair < 4) : (x_pair += 1) {
            const px_x = x_pair * 2;
            const left = hair_bang_pixels[y * 8 + px_x] & 0x0f;
            const right = hair_bang_pixels[y * 8 + px_x + 1] & 0x0f;
            hair_bang_tiles[0].data_8[byte_index] = left | (right << 4);
            byte_index += 1;
        }
    }
}

fn drawDust(camera: Camera) void {
    var index: usize = 0;
    var any_active = false;
    while (index < max_dust_particles) : (index += 1) {
        if (!dust_particles[index].active) {
            hideObject(dust_first_object + index);
            continue;
        }

        any_active = true;
        clearDustTile(index);
        drawDustShape(index, dust_particles[index]);
        const draw_x = fixedToPixel(dust_particles[index].x) - camera.x - 4;
        const draw_y = fixedToPixel(dust_particles[index].y) - camera.y - 4;
        gba.display.objects[dust_first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(draw_x),
            .y = objY(draw_y),
            .base_tile = dust_base_tile + @as(u10, @intCast(index)),
            .priority = 0,
            .palette = dust_palette_bank,
        });
    }
    if (any_active) {
        gba.display.memcpyObjectTiles4Bpp(dust_base_tile, &dust_tiles);
    }
}

fn drawPlayerDeathEffect(camera: Camera, death_timer: u8) void {
    const elapsed: u8 = player_death_anim_frames - death_timer;
    if (death_intro_frame_count != 0 and elapsed < death_intro_total_frames) {
        drawPlayerDeathIntro(camera, elapsed);
        hideDeathBurstObjects();
        return;
    }

    hideObject(player_object);
    if (death_intro_frame_count != 0) {
        const burst_elapsed = elapsed - death_intro_total_frames;
        drawDeathBalls(camera, burst_elapsed);
        return;
    }

    drawDeathBurst(camera, elapsed);
}

fn drawPlayerDeathIntro(camera: Camera, elapsed: u8) void {
    const frame_offset: u16 = @min(
        death_intro_frame_count - 1,
        @as(u16, elapsed / player_death_intro_frame_hold),
    );
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&player_palette_data);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[0], base_palette, 16);
    loadPlayerFrame(death_intro_first_frame + frame_offset);
    const travel_elapsed = @min(elapsed, death_intro_total_frames);
    const draw_world_x = death_player_x + @divTrunc(death_intro_offset_x * @as(i32, travel_elapsed), @as(i32, death_intro_total_frames));
    const draw_world_y = death_player_y + @divTrunc(death_intro_offset_y * @as(i32, travel_elapsed), @as(i32, death_intro_total_frames));
    const draw_x = clampI16(fixedToPixel(draw_world_x) - camera.x + player_draw_offset_x, -8, screen_width - 24);
    const draw_y = clampI16(fixedToPixel(draw_world_y) - camera.y + player_draw_offset_y, -8, screen_height - 32);
    gba.display.objects[player_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = 0,
        .priority = 0,
        .palette = 0,
        .flip = gba.math.Vec2B.init(death_player_facing_left, false),
    });
}

fn drawDeathBurst(camera: Camera, elapsed: u8) void {
    if (elapsed < 3) {
        drawDeathCore(camera, .size_8x8, death_burst_base_tile, -4, -4);
        return;
    }
    if (elapsed < 6) {
        drawDeathCore(camera, .size_8x8, death_burst_base_tile + 1, -4, -4);
        return;
    }
    if (elapsed < 10) {
        drawDeathCore(camera, .size_16x16, death_burst_base_tile + 2, -8, -8);
        return;
    }

    drawDeathBalls(camera, elapsed - 10);
}

fn drawRespawnBurst(camera: Camera, respawn_timer: u8) void {
    drawDeathBalls(camera, respawn_timer + 6);
}

fn drawDeathCore(camera: Camera, size: gba.display.Object.Size, base_tile: u10, x_offset: i16, y_offset: i16) void {
    const origin_x = clampI16(fixedToPixel(death_origin_x) - camera.x - 4, 4, screen_width - 12);
    const origin_y = clampI16(fixedToPixel(death_origin_y) - camera.y - 4, 4, screen_height - 12);
    gba.display.objects[death_burst_first_object] = gba.display.Object.init(.{
        .size = size,
        .x = objX(origin_x + x_offset + 4),
        .y = objY(origin_y + y_offset + 4),
        .base_tile = base_tile,
        .priority = 0,
        .palette = death_burst_palette_bank,
    });
    var index: usize = 1;
    while (index < death_burst_count) : (index += 1) {
        hideObject(death_burst_first_object + index);
    }
}

fn drawDeathBalls(camera: Camera, progress: u8) void {
    const directions = [_][2]i16{
        .{ 0, -16 },
        .{ 11, -11 },
        .{ 16, 0 },
        .{ 11, 11 },
        .{ 0, 16 },
        .{ -11, 11 },
        .{ -16, 0 },
        .{ -11, -11 },
    };
    const origin_x = clampI16(fixedToPixel(death_origin_x) - camera.x - 4, 4, screen_width - 12);
    const origin_y = clampI16(fixedToPixel(death_origin_y) - camera.y - 4, 4, screen_height - 12);
    const radius: i16 = deathBurstRadius(progress);
    const flash_white = (progress & 0x10) != 0;
    const ball_base_tile: u10 = death_burst_base_tile + if (flash_white) @as(u10, 0) else @as(u10, 1);

    var index: usize = 0;
    while (index < death_burst_spoke_count) : (index += 1) {
        const dx = @divTrunc(directions[index][0] * radius, 16);
        const dy = @divTrunc(directions[index][1] * radius, 16);
        gba.display.objects[death_burst_first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(origin_x + dx),
            .y = objY(origin_y + dy),
            .base_tile = ball_base_tile,
            .priority = 0,
            .palette = death_burst_palette_bank,
        });
    }
    hideObject(death_burst_first_object + death_burst_spoke_count);
}

fn deathBurstRadius(progress: u8) i16 {
    const radii = [_]i16{
        4,  5,  6,  7,  8,  9,  10, 11,
        12, 13, 14, 15, 16, 17, 18, 19,
        20, 20, 21, 21, 22, 22, 23, 23,
        24, 24, 25, 25, 25, 25, 25, 25,
    };
    if (progress < radii.len) return radii[progress];
    return 25;
}

fn hideDeathBurstObjects() void {
    var index: usize = 0;
    while (index < death_burst_count) : (index += 1) {
        hideObject(death_burst_first_object + index);
    }
}

fn clearDustTile(tile_index: usize) void {
    var byte_index: usize = 0;
    while (byte_index < 32) : (byte_index += 1) {
        dust_tiles[tile_index].data_8[byte_index] = 0;
    }
}

fn drawDustShape(tile_index: usize, particle: DustParticle) void {
    const age = particle.max_life - particle.life;
    if (particle.snow) {
        const center_x: i16 = 2 + @as(i16, @intCast((particle.shape & 1) * 3));
        const center_y: i16 = 2 + @as(i16, @intCast((particle.shape >> 1) & 3));
        if (particle.life > particle.max_life / 2) {
            setDustTilePixel(tile_index, center_x, center_y - 1, 1);
            setDustTilePixel(tile_index, center_x - 1, center_y, 1);
            setDustTilePixel(tile_index, center_x, center_y, 1);
            setDustTilePixel(tile_index, center_x + 1, center_y, 1);
        } else {
            setDustTilePixel(tile_index, center_x, center_y, 1);
            setDustTilePixel(tile_index, center_x, center_y + 1, 1);
        }
        if (age > 7 and particle.life > particle.max_life / 3) {
            setDustTilePixel(tile_index, center_x - 1, center_y + 1, 1);
            setDustTilePixel(tile_index, center_x + 1, center_y + 1, 1);
        }
        return;
    }
    if (particle.wall) {
        const center_x: i16 = 3 + @as(i16, @intCast(particle.shape & 1));
        const center_y: i16 = 3 + @as(i16, @intCast((particle.shape >> 1) & 1));
        const shrink = particle.life < particle.max_life / 3;
        drawDustDisc(tile_index, center_x, center_y, if (shrink) 1 else 2);
        if (!shrink and age > 3) {
            drawDustDisc(tile_index, center_x - 1, center_y + 2, 1);
        }
        return;
    }
    const shrink = particle.life < particle.max_life / 3;
    const center_x: i16 = 3 + @as(i16, @intCast(particle.shape & 1));
    const center_y: i16 = if (particle.landing) 5 else 4 - @as(i16, @intCast((particle.shape >> 1) & 1));
    const radius: u8 = if (shrink) 1 else 2;
    drawDustDisc(tile_index, center_x, center_y, radius);
    if (particle.landing and !shrink) {
        drawDustDisc(tile_index, center_x - 2, center_y + 1, 1);
        drawDustDisc(tile_index, center_x + 2, center_y + 1, 1);
        if (age > 5) {
            drawDustDisc(tile_index, center_x, center_y - 2, 1);
        }
        return;
    }
    if (!shrink and age > 4) {
        const side: i16 = if ((particle.shape & 1) == 0) -2 else 2;
        drawDustDisc(tile_index, center_x + side, center_y + 1, 1);
    }
}

fn drawDustDisc(tile_index: usize, center_x: i16, center_y: i16, radius: u8) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setDustTilePixel(tile_index, center_x + x, center_y + y, 1);
            }
        }
    }
}

fn drawDeathBurstDisc(tile_index: usize, center_x: i16, center_y: i16, radius: u8, color: u4) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setDeathBurstTilePixel(tile_index, center_x + x, center_y + y, color);
            }
        }
    }
}

fn drawDeathBurstBlob16(first_tile_index: usize, color: u4) void {
    var y: i16 = 1;
    while (y < 15) : (y += 1) {
        var x: i16 = 1;
        while (x < 15) : (x += 1) {
            const dx = x - 8;
            const dy = y - 8;
            if (dx * dx + dy * dy <= 42) {
                setDeathBurstPixel16(first_tile_index, x, y, color);
            }
        }
    }
    setDeathBurstPixel16(first_tile_index, 8, 1, color);
    setDeathBurstPixel16(first_tile_index, 8, 15, color);
    setDeathBurstPixel16(first_tile_index, 1, 8, color);
    setDeathBurstPixel16(first_tile_index, 15, 8, color);
}

fn setDeathBurstPixel16(first_tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 16 or y < 0 or y >= 16) return;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    const local_x = @mod(x, 8);
    const local_y = @mod(y, 8);
    setDeathBurstTilePixel(first_tile_index + tile_y * 2 + tile_x, local_x, local_y, color);
}

fn setDeathBurstTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const pixel_index: u8 = @intCast(y * 8 + x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        death_burst_tiles[tile_index].data_8[byte_index] = (death_burst_tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        death_burst_tiles[tile_index].data_8[byte_index] = (death_burst_tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn setDustTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const pixel_index: u8 = @intCast(y * 8 + x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        dust_tiles[tile_index].data_8[byte_index] = (dust_tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        dust_tiles[tile_index].data_8[byte_index] = (dust_tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn resetChimneySmoke(room_index: usize) void {
    chimney_smoke_counter = 0;
    _ = room_index;
    hideChimneySmokeObjects();
}

fn updateChimneySmoke(room_index: usize) void {
    if (!chimneySmokeActive(room_index)) {
        hideChimneySmokeObjects();
        return;
    }
    if ((foreground_anim_counter & 1) != 0) return;
    chimney_smoke_counter +%= 1;
}

fn drawChimneySmoke(camera: Camera, room_index: usize) void {
    if (!chimneySmokeActive(room_index)) {
        hideChimneySmokeObjects();
        return;
    }

    var index: usize = 0;
    while (index < chimney_smoke_object_count) : (index += 1) {
        clearChimneySmokeTile(index);
        const age = chimneySmokeAge(index);
        drawChimneySmokeShape(index, age, index);

        const rise: i16 = @intCast(age / 5);
        const draw_x = chimney_smoke_origin_x + chimneySmokeWobble(age, index) - camera.x - 8;
        const draw_y = chimney_smoke_origin_y - rise - camera.y - 8;
        gba.display.objects[chimney_smoke_first_object + index] = gba.display.Object.init(.{
            .size = .size_16x16,
            .x = objX(draw_x),
            .y = objY(draw_y),
            .base_tile = chimney_smoke_base_tile + @as(u10, @intCast(index * chimney_smoke_tiles_per_object)),
            .priority = 1,
            .palette = chimney_smoke_palette_bank,
        });
    }

    gba.display.memcpyObjectTiles4Bpp(chimney_smoke_base_tile, &chimney_smoke_tiles);
}

fn chimneySmokeActive(room_index: usize) bool {
    return room_index == chimney_smoke_room_index;
}

fn chimneySmokeAge(index: usize) u8 {
    const offset = @as(u16, @intCast(index)) * (@as(u16, chimney_smoke_cycle_frames) / chimney_smoke_object_count);
    return @intCast((@as(u16, chimney_smoke_counter) + offset) % chimney_smoke_cycle_frames);
}

fn chimneySmokeWobble(age: u8, index: usize) i16 {
    const phase = ((@as(usize, age) / 16) + index) & 3;
    return switch (phase) {
        0 => 0,
        1 => 1,
        2 => 0,
        else => 0,
    };
}

fn drawChimneySmokeShape(tile_index: usize, age: u8, variant: usize) void {
    const x_shift: i16 = if (((@as(usize, age) / 24) + variant) & 1 == 0) 0 else 1;
    const stage = age / 24;
    switch (stage) {
        0 => {
            const cx: i16 = 7 + x_shift;
            drawChimneySmokeDisc(tile_index, cx, 10, 3, chimney_smoke_soft_color);
            drawChimneySmokePixelBlock(tile_index, cx, 10, 1);
            setChimneySmokeTilePixel(tile_index, cx - 2, 10, 1);
            setChimneySmokeTilePixel(tile_index, cx + 2, 9, chimney_smoke_soft_color);
            setChimneySmokeTilePixel(tile_index, cx - 3, 11, chimney_smoke_soft_color);
        },
        1 => {
            const cx: i16 = 7 + x_shift;
            drawChimneySmokeDisc(tile_index, cx, 8, 4, chimney_smoke_soft_color);
            drawChimneySmokeDisc(tile_index, cx + 2, 9, 2, chimney_smoke_soft_color);
            drawChimneySmokePixelBlock(tile_index, cx, 8, 1);
            setChimneySmokeTilePixel(tile_index, cx - 1, 7, 1);
            setChimneySmokeTilePixel(tile_index, cx + 2, 8, 1);
            setChimneySmokeTilePixel(tile_index, cx - 3, 10, chimney_smoke_soft_color);
            setChimneySmokeTilePixel(tile_index, cx + 4, 10, chimney_smoke_soft_color);
        },
        2 => {
            const cx: i16 = 8 - x_shift;
            drawChimneySmokeDisc(tile_index, cx, 7, 4, chimney_smoke_soft_color);
            drawChimneySmokeDisc(tile_index, cx - 3, 8, 2, chimney_smoke_soft_color);
            setChimneySmokeTilePixel(tile_index, cx, 7, 1);
            setChimneySmokeTilePixel(tile_index, cx - 1, 7, 1);
            setChimneySmokeTilePixel(tile_index, cx + 1, 6, 1);
            setChimneySmokeTilePixel(tile_index, cx + 3, 7, chimney_smoke_soft_color);
            setChimneySmokeTilePixel(tile_index, cx - 4, 9, chimney_smoke_soft_color);
        },
        else => {
            const cx: i16 = 7 + x_shift;
            drawChimneySmokeDisc(tile_index, cx, 6, 2, chimney_smoke_soft_color);
            setChimneySmokeTilePixel(tile_index, cx - 3, 7, chimney_smoke_soft_color);
            setChimneySmokeTilePixel(tile_index, cx + 3, 6, chimney_smoke_soft_color);
            if (age < 64) {
                setChimneySmokeTilePixel(tile_index, cx, 6, 1);
                setChimneySmokeTilePixel(tile_index, cx + 1, 7, chimney_smoke_soft_color);
            }
        },
    }
}

fn drawChimneySmokePixelBlock(tile_index: usize, x: i16, y: i16, color: u4) void {
    setChimneySmokeTilePixel(tile_index, x, y, color);
    setChimneySmokeTilePixel(tile_index, x + 1, y, color);
    setChimneySmokeTilePixel(tile_index, x, y + 1, color);
    setChimneySmokeTilePixel(tile_index, x + 1, y + 1, color);
}

fn drawChimneySmokeDisc(tile_index: usize, center_x: i16, center_y: i16, radius: u8, color: u4) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setChimneySmokeTilePixel(tile_index, center_x + x, center_y + y, color);
            }
        }
    }
}

fn clearChimneySmokeTile(tile_index: usize) void {
    const first_tile = tile_index * chimney_smoke_tiles_per_object;
    var local_tile: usize = 0;
    while (local_tile < chimney_smoke_tiles_per_object) : (local_tile += 1) {
        var byte_index: usize = 0;
        while (byte_index < 32) : (byte_index += 1) {
            chimney_smoke_tiles[first_tile + local_tile].data_8[byte_index] = 0;
        }
    }
}

fn setChimneySmokeTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 16 or y < 0 or y >= 16) return;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    const local_x: i16 = @intCast(@mod(x, 8));
    const local_y: i16 = @intCast(@mod(y, 8));
    const object_tile_index = tile_index * chimney_smoke_tiles_per_object + tile_y * 2 + tile_x;
    const pixel_index: u8 = @intCast(local_y * 8 + local_x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        chimney_smoke_tiles[object_tile_index].data_8[byte_index] = (chimney_smoke_tiles[object_tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        chimney_smoke_tiles[object_tile_index].data_8[byte_index] = (chimney_smoke_tiles[object_tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn hideChimneySmokeObjects() void {
    var index: usize = 0;
    while (index < chimney_smoke_object_count) : (index += 1) {
        hideObject(chimney_smoke_first_object + index);
    }
}

fn setWindSnowPixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const pixel_index: u8 = @intCast(y * 8 + x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        wind_snow_tiles[tile_index].data_8[byte_index] = (wind_snow_tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        wind_snow_tiles[tile_index].data_8[byte_index] = (wind_snow_tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn resetWindSnow(room_index: usize, camera: Camera) void {
    wind_snow_particles = [_]WindSnowParticle{.{}} ** max_wind_snow_particles;
    if (windSnowSuppressed(room_index) or rooms[room_index].wind_snow_strength == 0) {
        hideWindSnowObjects();
        wind_snow_visible = false;
        wind_snow_particle_count = 0;
        return;
    }

    wind_snow_visible = true;
    const particle_limit = windSnowParticleLimit(room_index);
    wind_snow_particle_count = particle_limit;
    var index: usize = 0;
    while (index < particle_limit) : (index += 1) {
        wind_snow_particles[index] = newWindSnowParticle(room_index, camera, index, true);
    }
}

fn updateWindSnow(room_index: usize, camera: Camera) void {
    const room = rooms[room_index];
    if (windSnowSuppressed(room_index) or room.wind_snow_strength == 0) {
        if (wind_snow_visible) {
            hideWindSnowObjects();
        }
        wind_snow_visible = false;
        wind_snow_particle_count = 0;
        return;
    }

    wind_snow_visible = true;
    const particle_limit = windSnowParticleLimit(room_index);
    wind_snow_particle_count = particle_limit;
    var index: usize = 0;
    while (index < particle_limit) : (index += 1) {
        if (!wind_snow_particles[index].active) {
            wind_snow_particles[index] = newWindSnowParticle(room_index, camera, index, false);
            continue;
        }

        const dir: i16 = if (room.wind_snow_dir_x < 0) -1 else 1;
        wind_snow_particles[index].x += @as(i32, dir) * wind_snow_particles[index].speed;
        if ((foreground_anim_counter & 7) == 0) {
            wind_snow_particles[index].y += @as(i32, wind_snow_particles[index].drift) * fixed_one;
        }
        const left_bound = camera.x - 20;
        const right_bound = camera.x + screen_width + 20;
        const top_bound = camera.y - 20;
        const bottom_bound = camera.y + screen_height + 20;
        const world_x = fixedToPixel(wind_snow_particles[index].x);
        const world_y = fixedToPixel(wind_snow_particles[index].y);
        if (world_x < left_bound or world_x > right_bound or
            world_y < top_bound or world_y > bottom_bound)
        {
            wind_snow_particles[index] = newWindSnowParticle(room_index, camera, index, false);
        }
    }
}

fn windSnowSuppressed(room_index: usize) bool {
    return isPrologueEndRoom(room_index) and bridge_sequence_started;
}

fn windSnowParticleLimit(room_index: usize) usize {
    return if (isPrologueEndRoom(room_index)) bridge_room_wind_snow_particles else max_wind_snow_particles;
}

fn newWindSnowParticle(room_index: usize, camera: Camera, index: usize, fill_screen: bool) WindSnowParticle {
    const room = rooms[room_index];
    const strength = @max(@as(u8, 1), room.wind_snow_strength);
    const dir: i16 = if (room.wind_snow_dir_x < 0) -1 else 1;
    const spawn_left = camera.x - 12;
    const spawn_right = camera.x + screen_width + 12;
    const x = if (fill_screen)
        camera.x + @as(i16, @intCast(hashIndex(index, 11) % (screen_width + 32))) - 16
    else if (dir < 0)
        spawn_right
    else
        spawn_left;
    const y = pickWindSnowY(room_index, camera, index, x);
    return .{
        .active = true,
        .x = pixelToFixed(x),
        .y = pixelToFixed(y),
        .speed = fixed_one + fixed_one / 2 + @as(i32, @intCast(strength - 1)) * (fixed_one / 2),
        .drift = @as(i16, @intCast((index / 3) % 3)) - 1,
        .tile = @as(u8, @intCast(index % wind_snow_tile_count)),
        .life = 255,
    };
}

fn pickWindSnowY(room_index: usize, camera: Camera, index: usize, x: i16) i16 {
    _ = x;
    const min_y = camera.y + 4;
    const max_y = camera.y + screen_height - 18;
    const span: usize = @intCast(max_y - min_y);
    const lane_count = windSnowParticleLimit(room_index);
    if (span <= 1) return min_y;
    if (index < lane_count and wind_snow_particles[index].active == false) {
        return min_y + @as(i16, @intCast(hashIndex(index, 29) % span));
    }
    const y_lane = (index * 17 + 5) % lane_count;
    const lane_y: i16 = @intCast((y_lane * span) / lane_count);
    const jitter: i16 = @intCast(hashIndex(index, 7) % 5);
    return min_y + lane_y + jitter;
}

fn hashIndex(index: usize, salt: u16) u16 {
    var value: u16 = @intCast((index + 1) * 197 + @as(usize, salt) * 389);
    value ^= value << 7;
    value ^= value >> 9;
    value ^= value << 8;
    return value;
}

fn drawWindSnow(camera: Camera) void {
    if (!wind_snow_visible) return;

    var index: usize = 0;
    while (index < wind_snow_particle_count) : (index += 1) {
        if (!wind_snow_particles[index].active) {
            hideObject(wind_snow_first_object + index);
            continue;
        }
        const screen_x = fixedToPixel(wind_snow_particles[index].x) - camera.x;
        const screen_y = fixedToPixel(wind_snow_particles[index].y) - camera.y;
        gba.display.objects[wind_snow_first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(screen_x),
            .y = objY(screen_y),
            .base_tile = wind_snow_base_tile + @as(u10, @intCast(wind_snow_particles[index].tile)),
            .priority = 1,
            .palette = wind_snow_palette_bank,
        });
    }
}

fn hideWindSnowObjects() void {
    wind_snow_particle_count = 0;
    var index: usize = 0;
    while (index < max_wind_snow_particles) : (index += 1) {
        hideObject(wind_snow_first_object + index);
    }
}

fn updateParallaxBackground(camera: Camera, room_index: usize) void {
    const maybe_parallax = rooms[room_index].parallax;
    if (maybe_parallax == null) {
        gba.display.ctrl.bg1 = false;
        return;
    }

    const parallax = maybe_parallax.?;
    const extra_x: i16 = if (parallax.scroll_extra_x_divisor == 0) 0 else @divTrunc(camera.x, parallax.scroll_extra_x_divisor);
    const extra_y: i16 = if (parallax.scroll_extra_y_divisor == 0) 0 else @divTrunc(camera.y, parallax.scroll_extra_y_divisor);
    const scroll_x = camera.x + extra_x - parallax.world_x;
    const scroll_y = camera.y + extra_y - parallax.world_y;
    streamParallaxBackground(room_index, parallax, scroll_x, scroll_y);
    gba.display.bg_scroll[1] = .init(@intCast(scroll_x), @intCast(scroll_y));
    gba.display.ctrl.bg1 = true;
}

fn updateBirdNpc(player: Player, camera: Camera) void {
    if (!bird_npc.active) return;

    bird_npc.timer +%= 1;
    if (birdClimbCompleteTriggered(player)) {
        bird_npc.state = .liftoff;
        bird_npc.timer = 0;
        hideObject(bird_hint_object);
    }
    switch (bird_npc.state) {
        .inactive, .gone => {},
        .idle => {
            bird_npc.frame = birdIdlePeckFrame();
            if (birdTriggerActive(player, .squawk_hold_hint) or (bird_npc.trigger_count == 0 and birdPlayerLandedBelow(player))) {
                bird_npc.state = .squawk;
                bird_npc.timer = 0;
            }
        },
        .squawk => {
            const frame_offset = @divTrunc(bird_npc.timer, bird_anim_speed);
            bird_npc.frame = bird_squawk_first_frame + @min(frame_offset, @as(u16, bird_squawk_frame_count - 1));
            if (bird_npc.timer >= bird_hold_hint_frames) {
                bird_npc.state = .hold_hint;
                bird_npc.timer = 0;
            }
        },
        .hold_hint => {
            bird_npc.frame = birdIdlePeckFrame();
            if (bird_npc.timer >= bird_hold_hint_frames) {
                bird_npc.state = .climb_hint;
                bird_npc.timer = 0;
            }
        },
        .climb_hint => {
            bird_npc.frame = birdIdlePeckFrame();
            if (birdClimbCompleteTriggered(player)) {
                bird_npc.state = .liftoff;
                bird_npc.timer = 0;
            }
        },
        .hide_hint => {
            bird_npc.frame = birdIdlePeckFrame();
            if (bird_npc.timer >= bird_hint_hide_frames) {
                bird_npc.state = .done;
                bird_npc.timer = 0;
            }
        },
        .peck => {
            const frame_offset = @divTrunc(bird_npc.timer, bird_anim_speed);
            bird_npc.frame = bird_peck_first_frame + @min(frame_offset, @as(u16, bird_peck_frame_count - 1));
            if (frame_offset >= bird_peck_frame_count) {
                bird_npc.state = .fly;
                bird_npc.timer = 0;
                bird_npc.path_index = 0;
                bird_npc.x = pixelToFixed(bird_npc.home_x);
                bird_npc.y = pixelToFixed(bird_npc.home_y);
            }
        },
        .fly => {
            bird_npc.frame = bird_fly_first_frame + @as(u16, @intCast(@divTrunc(bird_npc.timer, bird_anim_speed) % bird_fly_frame_count));
            bird_npc.x += bird_flyaway_vx;
            bird_npc.y += bird_flyaway_vy;
            bird_npc.facing_left = bird_npc.timer < bird_flyaway_frames / 3;
            const draw_y = fixedToPixel(bird_npc.y) - bird_origin_offset_y - camera.y;
            if (draw_y < -32 or bird_npc.timer >= bird_flyaway_frames) {
                bird_npc.state = .gone;
                hideObject(bird_object);
                hideObject(bird_hint_object);
            }
        },
        .liftoff => {
            const frame_offset = @divTrunc(bird_npc.timer, bird_anim_speed);
            bird_npc.frame = bird_liftoff_first_frame + @min(frame_offset, @as(u16, bird_liftoff_frame_count - 1));
            bird_npc.x += bird_liftoff_vx;
            bird_npc.y += bird_liftoff_vy;
            bird_npc.facing_left = true;
            if (frame_offset >= bird_liftoff_frame_count) {
                bird_npc.state = .fly;
                bird_npc.timer = 0;
            }
        },
        .ending_fly_in => {
            bird_npc.frame = bird_fly_first_frame + @as(u16, @intCast(@divTrunc(bird_npc.timer, bird_anim_speed) % bird_fly_frame_count));
            bird_npc.x = approach(bird_npc.x, pixelToFixed(bird_npc.home_x), 0x1A0);
            bird_npc.y = approach(bird_npc.y, pixelToFixed(bird_npc.home_y), 0x110);
            bird_npc.facing_left = true;
            if (bird_npc.x == pixelToFixed(bird_npc.home_x) and bird_npc.y == pixelToFixed(bird_npc.home_y)) {
                bird_npc.state = .ending_idle;
                bird_npc.timer = 0;
            }
        },
        .ending_idle => {
            bird_npc.frame = birdIdlePeckFrame();
            bird_npc.facing_left = true;
        },
        .done => {
            bird_npc.frame = birdIdlePeckFrame();
        },
    }
}

fn birdClimbCompleteTriggered(player: Player) bool {
    return switch (bird_npc.state) {
        .squawk, .hold_hint, .climb_hint, .hide_hint, .peck, .done =>
            birdTriggerActive(player, .peck_then_fly) or
                (bird_npc.trigger_count == 0 and playerReachedBirdClimbGoal(player)),
        else => false,
    };
}

fn birdIdlePeckFrame() u16 {
    const cycle_frame = bird_npc.timer % bird_peck_cycle_frames;
    const peck_total_frames = bird_peck_frame_count * bird_anim_speed;
    if (cycle_frame < peck_total_frames) {
        return bird_peck_first_frame + @min(@divTrunc(cycle_frame, bird_anim_speed), @as(u16, bird_peck_frame_count - 1));
    }
    return bird_squawk_first_frame;
}

fn birdPlayerLandedBelow(player: Player) bool {
    if (!player.grounded) return false;
    const player_x = fixedToPixel(player.x) + player_body_width / 2;
    const player_y = fixedToPixel(player.y) + player_body_height;
    return player_x >= bird_npc.home_x - 72 and
        player_x <= bird_npc.home_x + 96 and
        player_y >= bird_npc.home_y + 8;
}

fn playerReachedBirdClimbGoal(player: Player) bool {
    const player_x = fixedToPixel(player.x) + player_body_width / 2;
    const player_y = fixedToPixel(player.y);
    return player_y <= bird_npc.home_y - 16 or
        (player.grounded and player_x >= bird_npc.home_x + 64 and player_y <= bird_npc.home_y + 48);
}

fn birdTriggerActive(player: Player, action: BirdTriggerAction) bool {
    if (bird_npc.trigger_count == 0) return false;
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_body_width;
    const player_bottom = player_top + player_body_height;
    var index: usize = 0;
    while (index < bird_npc.trigger_count) : (index += 1) {
        const trigger = bird_npc.triggers[index];
        if (trigger.action != action) continue;
        const trigger_left = trigger.x;
        const trigger_top = trigger.y;
        const trigger_right = trigger.x + trigger.w;
        const trigger_bottom = trigger.y + trigger.h;
        if (rectsOverlap(player_left, player_top, player_right, player_bottom, trigger_left, trigger_top, trigger_right, trigger_bottom)) {
            return true;
        }
    }
    return false;
}

fn advanceBirdAlongPath() bool {
    if (bird_npc.path_count == 0 or bird_npc.path_index >= bird_npc.path_count) return false;
    const target = bird_npc.path[bird_npc.path_index];
    const target_x = pixelToFixed(target.x);
    const target_y = pixelToFixed(target.y);
    const dx = target_x - bird_npc.x;
    const dy = target_y - bird_npc.y;
    const dist_sq = @as(i64, dx) * dx + @as(i64, dy) * dy;
    if (dist_sq <= @as(i64, bird_fly_speed) * bird_fly_speed) {
        bird_npc.x = target_x;
        bird_npc.y = target_y;
        bird_npc.path_index += 1;
        return bird_npc.path_index < bird_npc.path_count;
    }
    const dist: i32 = @intCast(sqrtU64(@intCast(dist_sq)));
    bird_npc.x += @as(i32, @intCast(@divTrunc(@as(i64, dx) * bird_fly_speed, dist)));
    bird_npc.y += @as(i32, @intCast(@divTrunc(@as(i64, dy) * bird_fly_speed, dist)));
    bird_npc.facing_left = dx < 0;
    return true;
}

fn updateTinyBirds(player: Player, room_index: usize) void {
    if (room_index != tiny_bird_room_index or tiny_bird_count == 0) return;

    if (!tiny_bird_flock_triggered and playerNearTinyBirdFlock(player)) {
        tiny_bird_flock_triggered = true;
        var trigger_index: usize = 0;
        while (trigger_index < tiny_bird_count) : (trigger_index += 1) {
            tiny_birds[trigger_index].flying = true;
        }
    }

    var any_active = false;
    var index: usize = 0;
    while (index < tiny_bird_count) : (index += 1) {
        var tiny_bird = &tiny_birds[index];
        if (!tiny_bird.active) continue;
        any_active = true;
        if (!tiny_bird.flying) continue;

        tiny_bird.x += tiny_bird.vx;
        tiny_bird.y += tiny_bird.vy;
        if ((foreground_anim_counter & 7) == 0) {
            const drift: i32 = if (((foreground_anim_counter >> 3) + tiny_bird.phase) & 1 == 0) fixed_one / 4 else -fixed_one / 4;
            tiny_bird.x += drift;
        }
        if (fixedToPixel(tiny_bird.y) < -12) {
            tiny_bird.active = false;
            hideObject(tiny_bird_first_object + index);
        }
    }

    if (tiny_bird_flock_triggered and !any_active) {
        room_states[room_index].tiny_birds_flown = true;
        tiny_bird_count = 0;
        hideTinyBirds();
    }
}

fn playerNearTinyBirdFlock(player: Player) bool {
    const player_x = fixedToPixel(player.x) + player_body_width / 2;
    const player_y = fixedToPixel(player.y) + player_body_height / 2;
    var index: usize = 0;
    while (index < tiny_bird_count) : (index += 1) {
        const tiny_bird = tiny_birds[index];
        if (!tiny_bird.active) continue;
        const bird_x = fixedToPixel(tiny_bird.x) + 4;
        const bird_y = fixedToPixel(tiny_bird.y) + 4;
        if (absI16(player_x - bird_x) <= tiny_bird_trigger_distance_x and
            absI16(player_y - bird_y) <= tiny_bird_trigger_distance_y)
        {
            return true;
        }
    }
    return false;
}

fn drawBirdNpc(camera: Camera) void {
    if (!bird_npc.active or bird_npc.state == .inactive or bird_npc.state == .gone) {
        hideObject(bird_object);
        hideObject(bird_hint_object);
        return;
    }

    loadBirdFrame(bird_npc.frame);
    const draw_x = fixedToPixel(bird_npc.x) - bird_origin_offset_x - camera.x;
    const draw_y = fixedToPixel(bird_npc.y) - bird_origin_offset_y - camera.y;
    gba.display.objects[bird_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = bird_base_tile,
        .priority = 0,
        .palette = bird_palette_bank,
        .flip = gba.math.Vec2B.init(bird_npc.facing_left, false),
    });

    const show_squawk_hint = bird_npc.state == .squawk and bird_npc.timer >= bird_hint_show_delay_frames;
    const show_hide_hint = bird_npc.state == .hide_hint or (bird_npc.state == .liftoff and bird_npc.timer < bird_hint_hide_frames);
    const show_dash_hint = bird_npc.state == .ending_idle;
    if (show_squawk_hint or bird_npc.state == .hold_hint or bird_npc.state == .climb_hint or show_hide_hint or show_dash_hint) {
        const hint_kind: BirdHintKind = if (show_dash_hint)
            .dash
        else if (bird_npc.state == .squawk or bird_npc.state == .hold_hint)
            .hold
        else
            .climb;
        loadBirdHint(hint_kind);
        const hide_lift: i16 = if (bird_npc.state == .hide_hint) @intCast(@divTrunc(bird_npc.timer, 4)) else 0;
        gba.display.objects[bird_hint_object] = gba.display.Object.init(.{
            .size = .size_64x64,
            .x = objX(bird_npc.hint_x - camera.x),
            .y = objY(bird_npc.hint_y - hide_lift - camera.y),
            .base_tile = bird_hint_base_tile,
            .priority = 0,
            .palette = bird_hint_palette_bank,
        });
    } else {
        hideObject(bird_hint_object);
    }
}

fn drawTinyBirds(camera: Camera) void {
    if (tiny_bird_count == 0) return;

    var index: usize = 0;
    while (index < max_tiny_birds) : (index += 1) {
        if (index >= tiny_bird_count or !tiny_birds[index].active) {
            hideObject(tiny_bird_first_object + index);
            continue;
        }
        const tiny_bird = tiny_birds[index];
        const frame: u8 = if (tiny_bird.flying)
            @intCast((foreground_anim_counter / 4 + tiny_bird.phase) % tiny_bird_frame_count)
        else
            @intCast((foreground_anim_counter / 28 + tiny_bird.phase) % tiny_bird_frame_count);
        gba.display.objects[tiny_bird_first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(fixedToPixel(tiny_bird.x) - camera.x),
            .y = objY(fixedToPixel(tiny_bird.y) - camera.y),
            .base_tile = tiny_bird_base_tile + @as(u10, tiny_bird.variant) * tiny_bird_tiles_per_variant + frame,
            .priority = 1,
            .palette = tiny_bird_palette_bank,
        });
    }
}

fn hideTinyBirds() void {
    var index: usize = 0;
    while (index < max_tiny_birds) : (index += 1) {
        hideObject(tiny_bird_first_object + index);
    }
}

fn loadBirdFrame(frame: u16) void {
    const safe_frame = @min(frame, bird_total_frame_count - 1);
    if (loaded_bird_frame == safe_frame) return;
    const byte_offset = @as(usize, safe_frame) * bird_tiles_per_frame * 32;
    const byte_len = bird_tiles_per_frame * 32;
    const frame_bytes = bird_intro_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(bird_base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_bird_frame = safe_frame;
}

fn loadBirdHint(kind: BirdHintKind) void {
    if (loaded_bird_hint_kind == kind) return;
    switch (kind) {
        .hold => gba.display.memcpyObjectTiles4Bpp(bird_hint_base_tile, @ptrCast(&bird_hold_hint_tiles_data)),
        .climb => gba.display.memcpyObjectTiles4Bpp(bird_hint_base_tile, @ptrCast(&bird_climb_hint_tiles_data)),
        .dash => gba.display.memcpyObjectTiles4Bpp(bird_hint_base_tile, @ptrCast(&bird_dash_hint_tiles_data)),
        .none => {},
    }
    loaded_bird_hint_kind = kind;
}

fn drawGrannyNpc(camera: Camera, room_index: usize) void {
    const cutscene = rooms[room_index].granny_cutscene orelse {
        hideGrannyNpc();
        return;
    };

    const animation = grannyAnimationForRoom(room_index);
    const frame_count = grannyAnimationFrameCount(animation);
    const frame: u16 = @intCast((foreground_anim_counter / granny_anim_speed) % frame_count);
    loadGrannyFrame(animation, frame);
    gba.display.objects[granny_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(cutscene.granny.x - granny_origin_offset_x - camera.x),
        .y = objY(cutscene.granny.y - granny_origin_offset_y - camera.y),
        .base_tile = granny_base_tile,
        .priority = 1,
        .palette = granny_palette_bank,
        .flip = gba.math.Vec2B.init(grannyFacingLeftForRoom(cutscene, room_index), false),
    });
    granny_visible = true;
}

fn grannyAnimationForRoom(room_index: usize) GrannyAnimation {
    if (laugh_text.active and laugh_text.room_index == room_index) return .laugh;
    if (granny_cutscene.active and granny_cutscene.room_index == room_index and granny_cutscene.phase == .laugh_pause) return .laugh;
    if (granny_cutscene.active and granny_cutscene.room_index == room_index and granny_cutscene.phase == .dialogue and granny_cutscene.dialogue_index == 4) return .quotes;
    return .idle;
}

fn grannyAnimationFrameCount(animation: GrannyAnimation) u16 {
    return switch (animation) {
        .laugh => granny_laugh_frame_count,
        .quotes => granny_quotes_frame_count,
        else => granny_idle_frame_count,
    };
}

fn grannyFacingLeftForRoom(cutscene: *const GrannyCutscene, room_index: usize) bool {
    if (granny_cutscene.active and granny_cutscene.room_index == room_index) {
        return switch (granny_cutscene.phase) {
            .walk_edge, .laugh_pause => false,
            .dialogue => if (granny_cutscene.dialogue_index >= 3) false else cutscene.granny_facing_left,
            else => cutscene.granny_facing_left,
        };
    }
    if (granny_intro_done) return false;
    return cutscene.granny_facing_left;
}

fn loadGrannyFrame(animation: GrannyAnimation, frame: u16) void {
    const frame_count = grannyAnimationFrameCount(animation);
    const safe_frame = @min(frame, frame_count - 1);
    if (loaded_granny_animation == animation and loaded_granny_frame == safe_frame) return;
    const byte_offset = @as(usize, safe_frame) * granny_tiles_per_frame * 32;
    const byte_len = granny_tiles_per_frame * 32;
    const frame_bytes = switch (animation) {
        .laugh => granny_laugh_tiles_data[byte_offset .. byte_offset + byte_len],
        .quotes => granny_quotes_tiles_data[byte_offset .. byte_offset + byte_len],
        else => granny_idle_tiles_data[byte_offset .. byte_offset + byte_len],
    };
    gba.display.memcpyObjectTiles4Bpp(granny_base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_granny_frame = safe_frame;
    loaded_granny_animation = animation;
}

fn hideGrannyNpc() void {
    if (!granny_visible) return;
    hideObject(granny_object);
    granny_visible = false;
}

fn drawForegroundStampObjects(camera: Camera) void {
    var behind_index: usize = 0;
    var occluding_index: usize = 0;
    var source_index: usize = 0;
    while (source_index < foreground_stamp_count) : (source_index += 1) {
        const stamp = foreground_stamps[source_index];
        if (!stamp.active) continue;

        if (stamp.kind > 1) continue;

        const occludes = (stamp.flags & 4) != 0;
        const object_index = if (occludes)
            foreground_occluding_stamp_first_object + occluding_index
        else
            foreground_behind_stamp_first_object + behind_index;
        if (occludes) {
            occluding_index += 1;
        } else {
            behind_index += 1;
        }
        if (occluding_index > max_foreground_stamps or behind_index > max_foreground_stamps) continue;

        const frame = foregroundStampFrame();
        const flip_x = (stamp.flags & 1) != 0;
        const base_tile: u10 = switch (stamp.kind) {
            1 => if (flip_x) foreground_stamp2_mirror_base_tile else foreground_stamp2_base_tile,
            else => if (flip_x) foreground_stamp_mirror_base_tile else foreground_stamp_base_tile,
        };
        const palette: u4 = switch (stamp.kind) {
            1 => foreground_stamp2_palette_bank,
            else => foreground_stamp_palette_bank,
        };
        const tiles_per_frame: u16 = switch (stamp.kind) {
            1 => grass2_tiles_per_frame,
            else => grass1_tiles_per_frame,
        };
        const object_size = switch (stamp.kind) {
            1 => gba.display.Object.Size.size_8x8,
            else => gba.display.Object.Size.size_16x16,
        };
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = object_size,
            .x = objX(stamp.x - camera.x),
            .y = objY(stamp.y - camera.y),
            .base_tile = base_tile + @as(u10, @intCast(frame * tiles_per_frame)),
            .priority = if (occludes) 0 else 1,
            .palette = palette,
            .flip = gba.math.Vec2B.init(false, (stamp.flags & 2) != 0),
        });
    }

    var index: usize = occluding_index;
    while (index < max_foreground_stamps) : (index += 1) {
        hideObject(foreground_occluding_stamp_first_object + index);
    }
    index = behind_index;
    while (index < max_foreground_stamps) : (index += 1) {
        hideObject(foreground_behind_stamp_first_object + index);
    }
}

fn drawRoomWires(camera: Camera) void {
    if (disable_wire_drawing_for_perf_test) {
        return;
    }

    if (wire_chunk_count == 0) return;
    var index: usize = 0;
    while (index < max_wire_chunks) : (index += 1) {
        const object_index = wireObjectIndex(index) orelse continue;
        if (index >= wire_chunk_count or !wire_chunks[index].active) {
            hideObject(object_index);
            continue;
        }
        const chunk = wire_chunks[index];
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = .size_32x8,
            .x = objX(chunk.x - camera.x),
            .y = objY(chunk.y - camera.y),
            .base_tile = wire_base_tile + @as(u10, @intCast(chunk.tile_offset)),
            .priority = 1,
            .palette = wire_palette_bank,
        });
    }
}

fn wireSag(phase: u8) u8 {
    const gust = wireGustSag(phase);
    if (gust != 0) return gust;

    const tick = (@as(u16, foreground_anim_counter >> 1) + phase) & 127;
    if (tick >= 28 and tick < 72) return 1;
    if (tick >= 72 and tick < 104) return 2;
    if (tick >= 104 and tick < 120) return 1;
    return 0;
}

fn wireGustSag(phase: u8) u8 {
    const gust_period: u16 = 480;
    const gust_tick = (foreground_anim_counter + @as(u16, phase >> 2)) % gust_period;
    if (gust_tick >= 34) return 0;

    if (gust_tick < 8) return 1;
    if (gust_tick < 14) return 2;
    if (gust_tick < 26) return 1;
    return 0;
}

fn hideRoomWires() void {
    const used_falling_objects = falling_block_count * falling_block_objects_per_block;
    var index: usize = used_falling_objects;
    while (index < max_falling_blocks * falling_block_objects_per_block) : (index += 1) {
        hideObject(falling_block_first_object + index);
    }

    if (bridge_active) return;
    index = foregroundBehindObjectCount();
    while (index < max_foreground_stamps) : (index += 1) {
        hideObject(foreground_behind_stamp_first_object + index);
    }
}

fn wireObjectIndex(index: usize) ?usize {
    const used_falling_objects = falling_block_count * falling_block_objects_per_block;
    const falling_object_capacity = max_falling_blocks * falling_block_objects_per_block;
    const free_falling_objects = falling_object_capacity - used_falling_objects;
    if (index < free_falling_objects) return falling_block_first_object + used_falling_objects + index;

    if (bridge_active) return null;
    const behind_count = foregroundBehindObjectCount();
    const behind_index = index - free_falling_objects;
    if (behind_index >= max_foreground_stamps - behind_count) return null;
    return foreground_behind_stamp_first_object + behind_count + behind_index;
}

fn foregroundBehindObjectCount() usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < foreground_stamp_count) : (index += 1) {
        const stamp = foreground_stamps[index];
        if (!stamp.active or stamp.kind > 1 or (stamp.flags & 4) != 0) continue;
        count += 1;
    }
    return count;
}

fn updateFunnyCars(player: Player) void {
    var index: usize = 0;
    while (index < funny_car_count) : (index += 1) {
        const car = &funny_cars[index];
        if (!car.active or !car.pressed) continue;
        if (!playerFeetTouchFunnyCar(player, car.*)) {
            car.pressed = false;
        }
    }
}

fn playerFeetTouchFunnyCar(player: Player, car: FunnyCar) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_body_height;
    return funnyCarBottomNearBaseAt(player_left, player_bottom, car) or
        funnyCarBottomNearBaseAt(player_right, player_bottom, car);
}

fn triggerFunnyCarBounceAtPlayer(player: Player) void {
    var index: usize = 0;
    while (index < funny_car_count) : (index += 1) {
        const car = &funny_cars[index];
        if (!car.active) continue;
        if (playerFeetTouchFunnyCar(player, car.*)) {
            car.pressed = true;
        }
    }
}

fn releaseFunnyCarAtPlayer(player: Player) void {
    var index: usize = 0;
    while (index < funny_car_count) : (index += 1) {
        const car = &funny_cars[index];
        if (!car.active) continue;
        if (playerFeetTouchFunnyCar(player, car.*)) {
            car.pressed = false;
        }
    }
}

fn drawFunnyCars(camera: Camera) void {
    var index: usize = 0;
    while (index < max_funny_cars) : (index += 1) {
        if (index >= funny_car_count or !funny_cars[index].active) {
            hideFunnyCar(index);
            continue;
        }
        const car = funny_cars[index];
        const bounce_y: i16 = if (car.pressed) 1 else 0;
        const object_index = funny_car_first_object + index * funny_car_object_count;
        drawFunnyCarChunk(object_index, car.x - camera.x, car.y + bounce_y - camera.y, funny_car_base_tile, .size_32x16);
        drawFunnyCarChunk(object_index + 1, car.x + 32 - camera.x, car.y + bounce_y - camera.y, funny_car_base_tile + 8, .size_16x16);
    }
}

fn drawFunnyCarChunk(object_index: usize, x: i16, y: i16, base_tile: u10, size: gba.display.Object.Size) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = base_tile,
        .priority = 1,
        .palette = funny_car_palette_bank,
    });
}

fn hideFunnyCars() void {
    var index: usize = 0;
    while (index < max_funny_cars) : (index += 1) {
        hideFunnyCar(index);
    }
}

fn hideFunnyCar(index: usize) void {
    var part: usize = 0;
    while (part < funny_car_object_count) : (part += 1) {
        hideObject(funny_car_first_object + index * funny_car_object_count + part);
    }
}

fn foregroundStampFrame() u16 {
    const forward_frames = grass1_frame_count;
    const cycle = forward_frames * 2 - 2;
    const tick = (foreground_anim_counter / foreground_stamp_anim_speed) % cycle;
    if (tick < forward_frames) return tick;
    return cycle - tick;
}

fn hideForegroundStampObjects() void {
    var index: usize = 0;
    while (index < max_foreground_stamps) : (index += 1) {
        hideObject(foreground_occluding_stamp_first_object + index);
        hideObject(foreground_behind_stamp_first_object + index);
    }
}

fn drawFallingBlockObjects(camera: Camera) void {
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = falling_blocks[index];
        if (!block.active) {
            hideFallingBlockObject(index);
            continue;
        }

        const shake_x: i16 = if (block.state == .shaking and block.timer < 32 and (block.timer & 3) == 0) -1 else 0;
        const shake_y: i16 = if (block.state == .shaking and block.timer < 16 and (block.timer & 7) == 0) 1 else 0;
        const draw_x = block.x - camera.x + shake_x;
        const draw_y = fixedToPixel(block.y) - camera.y + shake_y;
        const object_index = falling_block_first_object + index * falling_block_objects_per_block;
        drawFallingBlockChunk(object_index, draw_x, draw_y, falling_block_base_tile, .size_32x32);
        drawFallingBlockChunk(object_index + 1, draw_x + 32, draw_y, falling_block_base_tile + 16, .size_16x32);
        drawFallingBlockChunk(object_index + 2, draw_x + 48, draw_y, falling_block_base_tile + 24, .size_8x32);
    }
}

fn drawFallingBlockChunk(object_index: usize, x: i16, y: i16, base_tile: u10, size: gba.display.Object.Size) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = base_tile,
        .priority = 1,
        .palette = falling_block_palette_bank,
    });
}

fn hideFallingBlockObject(block_index: usize) void {
    var index: usize = 0;
    while (index < falling_block_objects_per_block) : (index += 1) {
        hideObject(falling_block_first_object + block_index * falling_block_objects_per_block + index);
    }
}

fn hideFallingBlockObjects() void {
    var index: usize = 0;
    while (index < max_falling_blocks * falling_block_objects_per_block) : (index += 1) {
        hideObject(falling_block_first_object + index);
    }
}

fn drawBridgeObjects(camera: Camera) void {
    if (!bridge_active) {
        if (bridge_drawn_object_count != 0) hideBridgeObjects();
        return;
    }

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < bridge_chunk_count and object_offset < bridge_max_objects) : (index += 1) {
        const chunk = bridge_chunks[index];
        if (chunk.state == .inactive or chunk.state == .gone or chunk.variant == bridge_empty_chunk) continue;

        const screen_x = chunk.x - camera.x;
        if (screen_x < -bridge_chunk_width or screen_x >= screen_width) continue;

        const shake_x: i16 = if (chunk.state == .shaking and (chunk.timer & 3) == 0) -1 else 0;
        const shake_y: i16 = if (chunk.state == .shaking and (chunk.timer & 7) == 0) 1 else 0;
        const screen_y = fixedToPixel(chunk.y) - camera.y;
        if (screen_y < -bridge_chunk_height or screen_y >= screen_height) continue;

        const base_tile = bridge_base_tile + @as(u10, @intCast(@as(u16, chunk.variant) * bridge_tiles_per_chunk));
        const palette = if (chunk.state == .falling) bridge_falling_palette_bank else bridge_palette_bank;
        gba.display.objects[bridge_first_object + object_offset] = gba.display.Object.init(.{
            .size = .size_8x32,
            .x = objX(screen_x + shake_x),
            .y = objY(screen_y + shake_y),
            .base_tile = base_tile,
            .priority = 1,
            .palette = palette,
        });
        object_offset += 1;
    }

    var hide_offset = object_offset;
    while (hide_offset < bridge_drawn_object_count) : (hide_offset += 1) {
        hideObject(bridge_first_object + hide_offset);
    }
    bridge_drawn_object_count = object_offset;
}

fn hideBridgeObjects() void {
    var index: usize = 0;
    while (index < bridge_max_objects) : (index += 1) {
        hideObject(bridge_first_object + index);
    }
    bridge_drawn_object_count = 0;
}

fn hideObject(object_index: usize) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(240),
        .y = objY(160),
        .base_tile = 0,
    });
}

fn spawnPlayer(room_index: usize) Player {
    return spawnPlayerAt(rooms[room_index].spawn);
}

fn spawnPlayerAt(spawn: Spawn) Player {
    return .{
        .x = pixelToFixed(spawn.x),
        .y = pixelToFixed(spawn.y),
        .dust_suppress_timer = 2,
    };
}

fn enterRoomFromLeft(player: *Player) void {
    player.x = pixelToFixed(1);
    resetPlayerStateForSideRoomEntry(player);
}

fn enterRoomFromRight(player: *Player, room_index: usize) void {
    player.x = pixelToFixed(rooms[room_index].width_pixels - player_body_width - 1);
    resetPlayerStateForSideRoomEntry(player);
}

fn enterRoomFromTop(player: *Player) void {
    player.y = pixelToFixed(1);
    resetPlayerMotionForRoomEntry(player);
}

fn enterRoomFromBottom(player: *Player, room_index: usize) void {
    player.y = pixelToFixed(rooms[room_index].height_pixels - player_body_height - 8);
    resetPlayerMotionForRoomEntry(player);
}

fn alignPlayerBetweenRooms(player: *Player, from_room: usize, to_room: usize) void {
    const from = rooms[from_room];
    const to = rooms[to_room];
    player.x += @as(i32, from.world_x - to.world_x) << fixed_shift;
    player.y += @as(i32, from.world_y - to.world_y) << fixed_shift;
}

fn resetPlayerMotionForRoomEntry(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    resetPlayerStateForSideRoomEntry(player);
}

fn resetPlayerStateForSideRoomEntry(player: *Player) void {
    player.grounded = false;
    player.dust_suppress_timer = 2;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_ledge_timer = 0;
}

fn fitPlayerAfterRoomEntry(player: *Player, room_index: usize) void {
    const room = rooms[room_index];
    const clamped_y = clampI16(fixedToPixel(player.y), -player_body_height + 1, room.height_pixels - player_body_height - 1);
    player.y = pixelToFixed(clamped_y);
    if (!roomEntryCollidesAt(fixedToPixel(player.x), fixedToPixel(player.y), room_index)) return;

    var offset: i16 = 1;
    while (offset <= 64) : (offset += 1) {
        const up_y = clamped_y - offset;
        if (up_y >= -player_body_height + 1 and !roomEntryCollidesAt(fixedToPixel(player.x), up_y, room_index)) {
            player.y = pixelToFixed(up_y);
            player.vy = 0;
            player.grounded = false;
            return;
        }

        const down_y = clamped_y + offset;
        if (down_y <= room.height_pixels - player_body_height - 1 and !roomEntryCollidesAt(fixedToPixel(player.x), down_y, room_index)) {
            player.y = pixelToFixed(down_y);
            player.vy = 0;
            player.grounded = false;
            return;
        }
    }
}

fn sideTransitionSourceFloorWorldY(player: Player, room_index: usize) ?i16 {
    const room = rooms[room_index];
    const x = clampI16(fixedToPixel(player.x), 1, room.width_pixels - player_body_width - 1);
    const start_y = fixedToPixel(player.y);
    var best_y: i16 = 0;
    var best_distance: i16 = 32767;

    var offset: i16 = 0;
    while (offset <= 32) : (offset += 1) {
        if (sideTransitionFloorCandidate(x, start_y - offset, room_index)) |candidate_y| {
            best_y = candidate_y;
            best_distance = offset;
            break;
        }
        if (offset != 0) {
            if (sideTransitionFloorCandidate(x, start_y + offset, room_index)) |candidate_y| {
                best_y = candidate_y;
                best_distance = offset;
                break;
            }
        }
    }

    if (best_distance == 32767) return null;
    return best_y + room.world_y;
}

fn fitOrSnapPlayerAfterSideRoomEntry(player: *Player, room_index: usize, source_floor_world_y: ?i16) void {
    if (source_floor_world_y) |floor_world_y| {
        if (snapPlayerToMatchingWorldFloorAfterSideEntry(player, room_index, floor_world_y)) return;
    }
    fitPlayerAfterRoomEntry(player, room_index);
}

fn snapPlayerToMatchingWorldFloorAfterSideEntry(player: *Player, room_index: usize, source_floor_world_y: i16) bool {
    const room = rooms[room_index];
    const x = fixedToPixel(player.x);
    var best_y: i16 = 0;
    var best_distance: i16 = 32767;

    var y: i16 = -player_body_height + 1;
    while (y <= room.height_pixels - player_body_height - 1) : (y += 1) {
        if (sideTransitionFloorCandidate(x, y, room_index)) |candidate_y| {
            const candidate_world_y = candidate_y + room.world_y;
            const distance = absI16(candidate_world_y - source_floor_world_y);
            if (distance < best_distance) {
                best_distance = distance;
                best_y = candidate_y;
            }
        }
    }

    if (best_distance == 32767 or best_distance > 24) return false;
    player.y = pixelToFixed(best_y);
    player.vy = 0;
    player.grounded = true;
    return true;
}

fn sideTransitionFloorCandidate(x: i16, y: i16, room_index: usize) ?i16 {
    if (roomEntryCollidesAt(x, y, room_index)) return null;
    if (!roomEntryFloorContactAt(x, y, room_index)) return null;
    return y;
}

fn clampPlayerToRoom(player: *Player, room_index: usize) void {
    const room = rooms[room_index];
    const x = clampI16(fixedToPixel(player.x), 1, room.width_pixels - player_body_width - 1);
    player.x = pixelToFixed(x);
}

pub fn spawnFromBytes(bytes: []align(4) const u8) Spawn {
    return spawnFromBytesAt(bytes, 0);
}

pub fn spawnFromBytesAt(bytes: []align(4) const u8, offset: usize) Spawn {
    return .{
        .x = readI16Le(bytes, offset),
        .y = readI16Le(bytes, offset + 2),
    };
}

fn readI16Le(bytes: []align(4) const u8, offset: usize) i16 {
    const value = @as(u16, bytes[offset]) | (@as(u16, bytes[offset + 1]) << 8);
    return @bitCast(value);
}

fn readU16Le(bytes: []align(4) const u8, offset: usize) u16 {
    return @as(u16, bytes[offset]) | (@as(u16, bytes[offset + 1]) << 8);
}

fn moveHorizontal(player: *Player, amount: i32, room_index: usize) void {
    if (amount == 0) return;
    const target = player.x + amount;
    const step: i16 = if (amount < 0) -1 else 1;
    var pixel = fixedToPixel(player.x);
    const target_pixel = fixedToPixel(target);
    while (pixel != target_pixel) {
        const next = pixel + step;
        const player_y = fixedToPixel(player.y);
        if (collidesAt(next, player_y, room_index)) {
            if (player.grounded) {
                var lift: i16 = 1;
                while (lift <= 2) : (lift += 1) {
                    const lifted_y = player_y - lift;
                    if (!collidesAt(next, lifted_y, room_index)) {
                        player.y = pixelToFixed(lifted_y);
                        pixel = next;
                        break;
                    }
                } else {
                    player.x = pixelToFixed(pixel);
                    player.vx = 0;
                    return;
                }
            } else {
                player.x = pixelToFixed(pixel);
                player.vx = 0;
                return;
            }
        } else {
            pixel = next;
        }
    }
    player.x = target;
}

fn moveVertical(player: *Player, amount: i32, room_index: usize) void {
    if (amount == 0) return;
    const target = player.y + amount;
    const step: i16 = if (amount < 0) -1 else 1;
    var pixel = fixedToPixel(player.y);
    const target_pixel = fixedToPixel(target);
    while (pixel != target_pixel) {
        const next = pixel + step;
        if (collidesAt(fixedToPixel(player.x), next, room_index)) {
            player.y = pixelToFixed(pixel);
            player.vy = 0;
            player.grounded = step > 0;
            return;
        }
        if (step > 0) {
            if (oneWayPlatformTopForPlayer(fixedToPixel(player.x), pixel, next, room_index)) |platform_top| {
                player.y = pixelToFixed(platform_top - player_body_height);
                player.vy = 0;
                player.grounded = true;
                return;
            }
        }
        pixel = next;
    }
    player.y = target;
}

fn resolvePlayerEmbedding(player: *Player, room_index: usize) void {
    const start_x = fixedToPixel(player.x);
    const start_y = fixedToPixel(player.y);
    if (!collidesAt(start_x, start_y, room_index)) return;

    var radius: i16 = 1;
    while (radius <= 10) : (radius += 1) {
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x - radius, start_y)) return;
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x + radius, start_y)) return;
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x, start_y - radius)) return;
        if (tryResolvePlayerEmbeddingAt(player, room_index, start_x, start_y + radius)) return;

        var offset: i16 = 1;
        while (offset <= radius) : (offset += 1) {
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x - radius, start_y - offset)) return;
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x + radius, start_y - offset)) return;
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x - radius, start_y + offset)) return;
            if (tryResolvePlayerEmbeddingAt(player, room_index, start_x + radius, start_y + offset)) return;
        }
    }
}

fn tryResolvePlayerEmbeddingAt(player: *Player, room_index: usize, x: i16, y: i16) bool {
    if (collidesAt(x, y, room_index)) return false;
    player.x = pixelToFixed(x);
    player.y = pixelToFixed(y);
    player.vx = 0;
    player.vy = 0;
    player.climb_ledge_timer = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.wall_sliding = false;
    player.grounded = floorContactAt(x, y, room_index);
    return true;
}

fn collidesAt(x: i16, y: i16, room_index: usize) bool {
    return solidRectAt(x, y, player_body_width, player_body_height, room_index) or
        dynamicSolidRectAt(x, y, player_body_width, player_body_height);
}

fn roomEntryCollidesAt(x: i16, y: i16, room_index: usize) bool {
    return solidRectAt(x, y, player_body_width, player_body_height, room_index);
}

fn roomEntryFloorContactAt(x: i16, y: i16, room_index: usize) bool {
    return roomEntryCollidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index);
}

fn solidAtPixel(x: i16, y: i16, room_index: usize) bool {
    return solidRectAt(x, y, 1, 1, room_index);
}

fn solidRectAt(x: i16, y: i16, width: i16, height: i16, room_index: usize) bool {
    const room = rooms[room_index];
    const left = x;
    const right = x + width - 1;
    const top = y;
    const bottom = y + height - 1;
    if (left < 0 or right >= room.width_pixels) return true;
    if (top >= room.height_pixels) return false;
    if (bottom < 0) return false;

    const tile_left: usize = @intCast(@divTrunc(left, 8));
    const tile_right: usize = @intCast(@divTrunc(right, 8));
    const clipped_top: i16 = if (top < 0) 0 else top;
    const clipped_bottom: i16 = if (bottom >= room.height_pixels) room.height_pixels - 1 else bottom;
    const tile_top: usize = @intCast(@divTrunc(clipped_top, 8));
    const tile_bottom: usize = @intCast(@divTrunc(clipped_bottom, 8));
    var tile_y = tile_top;
    while (tile_y <= tile_bottom) : (tile_y += 1) {
        var tile_x = tile_left;
        while (tile_x <= tile_right) : (tile_x += 1) {
            if (room.collision[tile_y * room.width_tiles + tile_x] == 1) return true;
        }
    }
    return false;
}

fn spikeRectAt(x: i16, y: i16, width: i16, height: i16, room_index: usize) bool {
    const room = rooms[room_index];
    const left = x;
    const right = x + width - 1;
    const top = y;
    const bottom = y + height - 1;
    const rect_left = x;
    const rect_right = x + width;
    const rect_top = y;
    const rect_bottom = y + height;
    if (right < 0 or left >= room.width_pixels) return false;
    if (bottom < 0 or top >= room.height_pixels) return false;

    const clipped_left: i16 = if (left < 0) 0 else left;
    const clipped_right: i16 = if (right >= room.width_pixels) room.width_pixels - 1 else right;
    const clipped_top: i16 = if (top < 0) 0 else top;
    const clipped_bottom: i16 = if (bottom >= room.height_pixels) room.height_pixels - 1 else bottom;
    const tile_left: usize = @intCast(@divTrunc(clipped_left, 8));
    const tile_right: usize = @intCast(@divTrunc(clipped_right, 8));
    const tile_top: usize = @intCast(@divTrunc(clipped_top, 8));
    const tile_bottom: usize = @intCast(@divTrunc(clipped_bottom, 8));
    var tile_y = tile_top;
    while (tile_y <= tile_bottom) : (tile_y += 1) {
        var tile_x = tile_left;
        while (tile_x <= tile_right) : (tile_x += 1) {
            const collision_value = room.collision[tile_y * room.width_tiles + tile_x];
            if (collision_value >= 3 and collision_value <= 6) {
                const spike_left: i16 = @as(i16, @intCast(tile_x)) * 8;
                var hit_left = spike_left;
                var hit_top: i16 = @as(i16, @intCast(tile_y)) * 8;
                var hit_right = spike_left + 8;
                var hit_bottom = hit_top + 8;
                switch (collision_value) {
                    3 => hit_top += 3,
                    4 => hit_bottom = hit_top + 5,
                    5 => hit_left += 3,
                    6 => hit_right = hit_left + 5,
                    else => {},
                }
                if (rectsOverlap(rect_left, rect_top, rect_right, rect_bottom, hit_left, hit_top, hit_right, hit_bottom)) return true;
            }
        }
    }
    return false;
}

fn oneWayFloorAt(x: i16, player_y: i16, room_index: usize) bool {
    const player_bottom = player_y + player_body_height;
    return oneWayPlatformAtBottom(x, player_bottom, room_index) or
        oneWayPlatformAtBottom(x + player_body_width - 1, player_bottom, room_index);
}

fn oneWayPlatformTopForPlayer(player_x: i16, old_y: i16, next_y: i16, room_index: usize) ?i16 {
    const old_bottom = old_y + player_body_height - 1;
    const next_bottom = next_y + player_body_height - 1;
    if (oneWayPlatformTopAtBottom(player_x, old_bottom, next_bottom, room_index)) |platform_top| {
        return platform_top;
    }
    if (oneWayPlatformTopAtBottom(player_x + player_body_width - 1, old_bottom, next_bottom, room_index)) |platform_top| {
        return platform_top;
    }
    return funnyCarTopForPlayer(player_x, old_bottom, next_bottom);
}

fn oneWayPlatformTopAtBottom(x: i16, old_bottom: i16, next_bottom: i16, room_index: usize) ?i16 {
    const room = rooms[room_index];
    if (x < 0 or x >= room.width_pixels or next_bottom < 0 or next_bottom >= room.height_pixels) return null;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(next_bottom, 8));
    if (room.collision[tile_y * room.width_tiles + tile_x] != 2) return null;

    const platform_top = @as(i16, @intCast(tile_y)) * 8;
    if (old_bottom <= platform_top and next_bottom >= platform_top and next_bottom < platform_top + 4) {
        return platform_top;
    }
    return null;
}

fn oneWayPlatformAtBottom(x: i16, bottom_y: i16, room_index: usize) bool {
    const room = rooms[room_index];
    if (x < 0 or x >= room.width_pixels or bottom_y < 0 or bottom_y >= room.height_pixels) return false;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(bottom_y, 8));
    if (room.collision[tile_y * room.width_tiles + tile_x] != 2) return false;
    const platform_top = @as(i16, @intCast(tile_y)) * 8;
    return bottom_y >= platform_top and bottom_y < platform_top + 4;
}

fn funnyCarTopForPlayer(player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    const left = funnyCarTopAtBottom(player_x, old_bottom, next_bottom);
    const right = funnyCarTopAtBottom(player_x + player_body_width - 1, old_bottom, next_bottom);
    if (left) |left_top| {
        if (right) |right_top| {
            return @min(left_top, right_top);
        }
        return left_top;
    }
    return right;
}

fn funnyCarTopAtBottom(x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    var index: usize = 0;
    while (index < funny_car_count) : (index += 1) {
        const car = funny_cars[index];
        if (!car.active) continue;
        if (funnyCarSurfaceYAt(car, x)) |surface_y| {
            if (old_bottom <= surface_y and next_bottom >= surface_y and next_bottom < surface_y + 4) {
                return surface_y;
            }
        }
    }
    return null;
}

fn funnyCarFloorAt(player_x: i16, player_y: i16) bool {
    const player_bottom = player_y + player_body_height;
    return funnyCarBottomTouchesAt(player_x, player_bottom, null) or
        funnyCarBottomTouchesAt(player_x + player_body_width - 1, player_bottom, null);
}

fn funnyCarBottomTouchesAt(x: i16, bottom_y: i16, maybe_car: ?FunnyCar) bool {
    if (maybe_car) |car| {
        if (funnyCarSurfaceYAt(car, x)) |surface_y| {
            return bottom_y >= surface_y and bottom_y < surface_y + 4;
        }
        return false;
    }
    var index: usize = 0;
    while (index < funny_car_count) : (index += 1) {
        const car = funny_cars[index];
        if (!car.active) continue;
        if (funnyCarBottomTouchesAt(x, bottom_y, car)) return true;
    }
    return false;
}

fn funnyCarSurfaceYAt(car: FunnyCar, x: i16) ?i16 {
    const surface_y = funnyCarBaseSurfaceYAt(car, x) orelse return null;
    const pressed_offset: i16 = if (car.pressed) 1 else 0;
    return surface_y + pressed_offset;
}

fn funnyCarBaseSurfaceYAt(car: FunnyCar, x: i16) ?i16 {
    if (x < car.x or x >= car.x + funny_car_width) return null;
    const local_x: usize = @intCast(x - car.x);
    return car.y + @as(i16, funny_car_top[local_x]);
}

fn funnyCarBottomNearBaseAt(x: i16, bottom_y: i16, car: FunnyCar) bool {
    if (funnyCarBaseSurfaceYAt(car, x)) |surface_y| {
        return bottom_y >= surface_y - 1 and bottom_y < surface_y + 5;
    }
    return false;
}

fn dynamicSolidAtPixel(x: i16, y: i16) bool {
    return dynamicSolidRectAt(x, y, 1, 1);
}

fn dynamicSolidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    const right = x + width;
    const bottom = y + height;
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = falling_blocks[index];
        if (!block.active) continue;
        const block_y = fixedToPixel(block.y);
        if (right > block.x and x < block.x + block.w and bottom > block_y and y < block_y + block.h) {
            return true;
        }
    }
    if (bridge_active) {
        if (bridgeEndingSolidRectAt(x, y, right, bottom)) return true;

        const start = bridgeChunkIndexAtX(x) orelse 0;
        const end = bridgeChunkIndexAtX(right - 1) orelse if (right <= bridge_world_x) 0 else bridge_chunk_count - 1;
        index = start;
        while (index <= end and index < bridge_chunk_count) : (index += 1) {
            const chunk = bridge_chunks[index];
            if (chunk.state != .solid and chunk.state != .shaking) continue;
            const chunk_y = fixedToPixel(chunk.y);
            if (right > chunk.x and x < chunk.x + bridge_chunk_width and bottom > chunk_y and y < chunk_y + bridge_visual_height) {
                return true;
            }
        }
    }
    return false;
}

fn bridgeEndingSolidRectAt(x: i16, y: i16, right: i16, bottom: i16) bool {
    if (!bridge_ending.active) return false;
    if (!rectsOverlap(x, y, right, bottom, bridge_ending.platform.x, bridge_ending.platform.y, bridge_ending.platform.right(), bridge_ending.platform.y + bridge_visual_height)) {
        return false;
    }

    var index = bridge_ending.start_index;
    while (index <= bridge_ending.end_index and index < bridge_chunk_count) : (index += 1) {
        const chunk = bridge_chunks[index];
        if (chunk.state != .solid and chunk.state != .shaking) continue;
        const chunk_y = fixedToPixel(chunk.y);
        if (right > chunk.x and x < chunk.x + bridge_chunk_width and bottom > chunk_y and y < chunk_y + bridge_visual_height) {
            return true;
        }
    }
    return false;
}

fn objX(x: i16) u9 {
    if (x < -64) return 240;
    if (x < 0) return @intCast(512 + x);
    if (x > 511) return 511;
    return @intCast(x);
}

fn objY(y: i16) u8 {
    if (y < -64) return 160;
    if (y < 0) return @intCast(256 + y);
    if (y > 255) return 255;
    return @intCast(y);
}

fn pixelToFixed(value: i16) i32 {
    return @as(i32, value) << fixed_shift;
}

fn fixedToPixel(value: i32) i16 {
    return @intCast(value >> fixed_shift);
}

fn fixedMul(value: i32, mult: i32) i32 {
    return (value * mult) >> fixed_shift;
}

fn approach(value: i32, target: i32, amount: i32) i32 {
    if (value < target) {
        const next = value + amount;
        return if (next > target) target else next;
    }
    if (value > target) {
        const next = value - amount;
        return if (next < target) target else next;
    }
    return value;
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

fn minI32(a: i32, b: i32) i32 {
    return if (a < b) a else b;
}

fn minU8(a: u8, b: u8) u8 {
    return if (a < b) a else b;
}

fn absI16(value: i16) i16 {
    return if (value < 0) -value else value;
}

fn maxI16(a: i16, b: i16) i16 {
    return if (a > b) a else b;
}

fn signI32(value: i32) i16 {
    if (value < 0) return -1;
    if (value > 0) return 1;
    return 0;
}

fn signI16(value: i16) i16 {
    if (value < 0) return -1;
    if (value > 0) return 1;
    return 0;
}

fn sqrtU64(value: u64) u64 {
    var result: u64 = 0;
    var bit: u64 = 1 << 62;
    while (bit > value) : (bit >>= 2) {}
    var remainder = value;
    while (bit != 0) : (bit >>= 2) {
        if (remainder >= result + bit) {
            remainder -= result + bit;
            result = (result >> 1) + bit;
        } else {
            result >>= 1;
        }
    }
    return result;
}

fn clampI16(value: i16, min_value: i16, max_value: i16) i16 {
    if (max_value <= min_value) return min_value;
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}
