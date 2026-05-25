const gba = @import("gba");
const level = @import("generated_rooms.zig");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);

const player_tiles_data align(4) = @embedFile("generated/assets/player/madeline_tiles.bin").*;
const player_palette_data align(4) = @embedFile("generated/assets/player/madeline_palette.bin").*;
const player_hair_anchors_data align(4) = @embedFile("generated/assets/player/madeline_hair_anchors.bin").*;
const player_sweat_tiles_data align(4) = @embedFile("generated/assets/player_sweat/madeline_tiles.bin").*;
const player_sweat_palette_data align(4) = @embedFile("generated/assets/player_sweat/madeline_palette.bin").*;
const hair_tiles_data align(4) = @embedFile("generated/assets/player/hair_tiles.bin").*;
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
const bird_hint_palette_data align(4) = @embedFile("generated/assets/bird/hint_palette.bin").*;

const bg_screenblock: u5 = 29;
const bg_hardware_width_tiles: usize = 64;
const bg_hardware_height_tiles: usize = 32;
const screen_width = 240;
const screen_height = 160;

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
const bridge_base_tile: u10 = parallax_base_tile;
const bridge_palette_bank: u4 = parallax_palette_bank;
const bridge_chunk_width = 8;
const bridge_chunk_height = 32;
const bridge_visual_height = 25;
const bridge_tiles_per_chunk = 4;
const bridge_empty_chunk = 255;
const bridge_no_group = 255;
const bridge_world_x: i16 = 64;
const bridge_world_y: i16 = 126;
const bridge_max_chunks = 128;
const bridge_max_objects = 30;
const bridge_first_object = foreground_behind_stamp_first_object;
const bridge_shake_frames: u8 = 14;
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
const hair_root_base_tile: u10 = 64;
const hair_palette_bank: u4 = 2;
const dust_base_tile: u10 = 68;
const dust_palette_bank: u4 = 3;
const max_dust_particles = 8;
const wind_snow_base_tile: u10 = dust_base_tile + max_dust_particles;
const wind_snow_palette_bank: u4 = 3;
const max_wind_snow_particles = 28;
const wind_snow_tile_count = 8;
const sweat_base_tile: u10 = wind_snow_base_tile + wind_snow_tile_count;
const sweat_palette_bank: u4 = 4;
const death_burst_base_tile: u10 = sweat_base_tile + sweat_tiles_per_frame;
const death_burst_palette_bank: u4 = 3;
const death_burst_first_object = 0;
const death_burst_spoke_count = 8;
const death_burst_count = death_burst_spoke_count + 1;
const parallax_first_object = 0;
const parallax_max_objects = 8;
const foreground_occluding_stamp_first_object = 8;
const max_foreground_stamps = 24;
const player_object = 32;
const hair_root_object = 33;
const hair_object = 34;
const dust_first_object = 35;
const wind_snow_first_object = dust_first_object + max_dust_particles;
const sweat_object = wind_snow_first_object + max_wind_snow_particles;
const hair_node_count = 4;
const hair_sprite_size = 16;
const falling_block_first_object = sweat_object + 1;
const falling_block_objects_per_block = 3;
const foreground_behind_stamp_first_object = falling_block_first_object + max_falling_blocks * falling_block_objects_per_block;
const parallax_base_tile: u10 = 128;
const parallax_palette_bank: u4 = 5;
const parallax_chunk_size = 64;
const foreground_stamp_base_tile: u10 = 576;
const foreground_stamp_mirror_base_tile: u10 = foreground_stamp_base_tile + grass1_frame_count * grass1_tiles_per_frame;
const foreground_stamp2_base_tile: u10 = foreground_stamp_mirror_base_tile + grass1_frame_count * grass1_tiles_per_frame;
const foreground_stamp2_mirror_base_tile: u10 = foreground_stamp2_base_tile + grass2_frame_count * grass2_tiles_per_frame;
const foreground_stamp_palette_bank: u4 = 6;
const foreground_stamp2_palette_bank: u4 = 7;
const bird_base_tile: u10 = foreground_stamp_base_tile;
const bird_hint_base_tile: u10 = bird_base_tile + bird_tiles_per_frame;
const bird_palette_bank: u4 = 8;
const bird_hint_palette_bank: u4 = 9;
const bird_object = foreground_behind_stamp_first_object + max_foreground_stamps;
const bird_hint_object = bird_object + 1;
const funny_car_first_object = bird_hint_object + 1;
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
    palette: []align(4) const u8,
    width: i16,
    height: i16,
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

const Camera = struct {
    x: i16,
    y: i16,
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

const RoomState = struct {
    falling_blocks_landed: u8 = 0,
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

const HairNode = struct {
    x: i32 = 0,
    y: i32 = 0,
};

const HairAnchor = struct {
    x: i32,
    y: i32,
    dir: i16,
    tail_bias_x: i16,
    tail_bias_y: i16,
};

const HairRootRect = struct {
    x: i16,
    y: i16,
    flip_x: bool,
};

const rooms = level.rooms;

var room_states: [rooms.len]RoomState = [_]RoomState{.{}} ** rooms.len;
var falling_blocks: [max_falling_blocks]FallingBlock = [_]FallingBlock{.{}} ** max_falling_blocks;
var falling_block_count: usize = 0;
var bridge_chunks: [bridge_max_chunks]BridgeChunk = [_]BridgeChunk{.{}} ** bridge_max_chunks;
var bridge_chunk_count: usize = 0;
var bridge_active: bool = false;
var foreground_stamps: [max_foreground_stamps]ForegroundStamp = [_]ForegroundStamp{.{}} ** max_foreground_stamps;
var foreground_stamp_count: usize = 0;
var funny_cars: [max_funny_cars]FunnyCar = [_]FunnyCar{.{}} ** max_funny_cars;
var funny_car_count: usize = 0;
var foreground_anim_counter: u16 = 0;
var bird_npc: BirdNpc = .{};
var current_room_index: usize = 0;
var bg_stream_room_index: usize = rooms.len;
var bg_stream_tile_x: i16 = -32768;
var bg_stream_tile_y: i16 = -32768;
var rng_state: u16 = 0xACE1;
var dust_particles: [max_dust_particles]DustParticle = [_]DustParticle{.{}} ** max_dust_particles;

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
    force_move_x: i16 = 0,
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
    hair_nodes: [hair_node_count]HairNode = [_]HairNode{.{}} ** hair_node_count,
};

var hair_pixels: [hair_sprite_size * hair_sprite_size]u8 = [_]u8{0} ** (hair_sprite_size * hair_sprite_size);
var hair_mask: [hair_sprite_size * hair_sprite_size]u8 = [_]u8{0} ** (hair_sprite_size * hair_sprite_size);
var hair_tiles: [4]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 4;
var dust_tiles: [max_dust_particles]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** max_dust_particles;
var wind_snow_particles: [max_wind_snow_particles]WindSnowParticle = [_]WindSnowParticle{.{}} ** max_wind_snow_particles;
var wind_snow_tiles: [wind_snow_tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** wind_snow_tile_count;
var death_burst_tiles: [6]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 6;
var death_origin_x: i32 = 0;
var death_origin_y: i32 = 0;

pub export fn main() void {
    var room_index: usize = level.start_room_index;
    loadRoomBackground(room_index);
    loadFallingBlocks(room_index);
    loadForegroundStamps(room_index);
    loadFunnyCars(room_index);
    loadObjectSprites();
    loadBridge(room_index);
    loadBirdNpc(room_index);
    loadWindSnowTiles();
    loadRoomParallax(room_index);
    gba.display.hideAllObjects();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 1,
        .base_screenblock = bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });

    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .obj = true,
    });

    var input: gba.input.BufferedKeysState = .{};
    var player = spawnPlayer(room_index);
    var respawn = rooms[room_index].spawn;
    var camera = updateCamera(player, room_index);
    var death_timer: u8 = 0;
    var respawn_burst_timer: u8 = 0;
    resetWindSnow(room_index, camera);
    applyCamera(camera);
    drawParallaxObjects(camera, room_index);
    drawForegroundStampObjects(camera);
    drawFunnyCars(camera);
    drawBridgeObjects(camera);
    drawPlayer(player, camera);
    drawFallingBlockObjects(camera);
    drawBirdNpc(camera);

    while (true) {
        input.poll();
        if (respawn_burst_timer > 0) {
            respawn_burst_timer -= 1;
            gba.display.naiveVSync();
            if (respawn_burst_timer == 0) {
                hideDeathBurstObjects();
                drawParallaxObjects(camera, room_index);
                drawForegroundStampObjects(camera);
                drawFunnyCars(camera);
                drawFallingBlockObjects(camera);
                drawBridgeObjects(camera);
                drawBirdNpc(camera);
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
            gba.display.naiveVSync();
            if (death_timer == 0) {
                hideDeathBurstObjects();
                loadRoomBackground(room_index);
                loadFallingBlocks(room_index);
                loadForegroundStamps(room_index);
                loadFunnyCars(room_index);
                loadObjectSprites();
                loadBridge(room_index);
                loadBirdNpc(room_index);
                loadRoomParallax(room_index);
                clearDustParticles();
                player = spawnPlayerAt(respawn);
                updateHair(&player);
                camera = updateCamera(player, room_index);
                resetWindSnow(room_index, camera);
                applyCamera(camera);
                drawParallaxObjects(camera, room_index);
                drawForegroundStampObjects(camera);
                drawFunnyCars(camera);
                drawFallingBlockObjects(camera);
                drawBridgeObjects(camera);
                drawBirdNpc(camera);
                death_origin_x = player.x + (player_body_width / 2) * fixed_one;
                death_origin_y = player.y + (player_body_height / 2) * fixed_one;
                hideObject(player_object);
                hideObject(hair_root_object);
                hideObject(hair_object);
                hideObject(sweat_object);
                respawn_burst_timer = player_respawn_burst_frames;
                gba.display.naiveVSync();
                gba.display.ctrl.bg0 = true;
                gba.display.ctrl.obj = true;
            } else {
                drawFallingBlockObjects(camera);
                drawBridgeObjects(camera);
                drawDeathBurst(camera, death_timer);
            }
            continue;
        }

        updatePlayer(&player, input, room_index);
        if (updateFallingBlocks(&player)) {
            beginPlayerDeath(&death_timer, player);
            continue;
        }
        updateBridge(&player, room_index);
        updateFunnyCars(player);
        updateBirdNpc(player, camera);
        updateHair(&player);
        updateDustParticles();
        const next_camera = updateCamera(player, room_index);
        updateWindSnow(room_index, next_camera);
        foreground_anim_counter +%= 1;
        if (playerInDeathPit(player, room_index)) {
            beginPlayerDeath(&death_timer, player);
            continue;
        }
        if (trySwitchRoom(&player, input, &room_index, &respawn)) {
            gba.display.bg_palette.colors[0] = .black;
            gba.display.ctrl.bg0 = false;
            gba.display.ctrl.obj = false;
            gba.display.hideAllObjects();
            gba.display.naiveVSync();
            loadRoomBackground(room_index);
            loadFallingBlocks(room_index);
            loadForegroundStamps(room_index);
            loadFunnyCars(room_index);
            loadObjectSprites();
            loadBridge(room_index);
            loadBirdNpc(room_index);
            loadRoomParallax(room_index);
            clearDustParticles();
            player.hair_initialized = false;
            updateHair(&player);
            camera = updateCamera(player, room_index);
            resetWindSnow(room_index, camera);
            applyCamera(camera);
            drawParallaxObjects(camera, room_index);
            drawForegroundStampObjects(camera);
            drawFunnyCars(camera);
            drawBridgeObjects(camera);
            drawHair(player, camera);
            drawDust(camera);
            drawWindSnow(camera);
            drawPlayer(player, camera);
            drawSweat(&player, camera);
            drawFallingBlockObjects(camera);
            drawBirdNpc(camera);
            gba.display.naiveVSync();
            gba.display.ctrl.bg0 = true;
            gba.display.ctrl.obj = true;
            continue;
        }
        camera = next_camera;
        gba.display.naiveVSync();
        applyCamera(camera);
        drawParallaxObjects(camera, room_index);
        drawForegroundStampObjects(camera);
        drawFunnyCars(camera);
        drawFallingBlockObjects(camera);
        drawBridgeObjects(camera);
        drawBirdNpc(camera);
        drawHair(player, camera);
        drawDust(camera);
        drawWindSnow(camera);
        drawPlayer(player, camera);
        drawSweat(&player, camera);
    }
}

fn loadRoomBackground(room_index: usize) void {
    current_room_index = room_index;
    bg_stream_room_index = rooms.len;
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
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
    bridge_active = room_index + 1 == rooms.len;
    hideBridgeObjects();
    if (!bridge_active) return;

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, bridge_palette_bank) * 16], @ptrCast(&bridge_palette_data), 16);
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
    hideParallaxObjects();
    if (rooms[room_index].parallax) |parallax| {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, parallax_palette_bank) * 16], @ptrCast(parallax.palette.ptr), 16);
        const tile_count = parallax.tiles.len / 32;
        const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(parallax.tiles.ptr);
        gba.display.memcpyObjectTiles4Bpp(parallax_base_tile, tiles[0..tile_count]);
    }
}

fn loadObjectSprites() void {
    gba.mem.memcpy(gba.display.obj_palette, &player_palette_data, player_palette_data.len);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[16], @ptrCast(&falling_block_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[32], @ptrCast(&hair_palette_data), 16);
    gba.display.obj_palette.colors[48] = .black;
    gba.display.obj_palette.colors[49] = .white;
    gba.display.obj_palette.colors[50] = gba.ColorRgb555.rgb(17, 27, 31);
    gba.display.obj_palette.colors[51] = gba.ColorRgb555.rgb(29, 4, 4);
    gba.display.obj_palette.colors[52] = gba.ColorRgb555.rgb(17, 2, 3);
    gba.display.obj_palette.colors[53] = .black;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[64], @ptrCast(&player_sweat_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, foreground_stamp_palette_bank) * 16], @ptrCast(&grass1_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, foreground_stamp2_palette_bank) * 16], @ptrCast(&grass2_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, funny_car_palette_bank) * 16], @ptrCast(&funny_car_palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(falling_block_base_tile, @ptrCast(&falling_block_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(funny_car_base_tile, @ptrCast(&funny_car_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(hair_root_base_tile, @ptrCast(&hair_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp_base_tile, @ptrCast(&grass1_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp_mirror_base_tile, @ptrCast(&grass1_mirror_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp2_base_tile, @ptrCast(&grass2_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(foreground_stamp2_mirror_base_tile, @ptrCast(&grass2_mirror_tiles_data));
    loadDeathBurstTile();
    loadPlayerFrame(0);
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
    const byte_offset = @as(usize, frame) * player_tiles_per_frame * 32;
    const byte_len = player_tiles_per_frame * 32;
    const frame_bytes = player_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(@alignCast(frame_bytes)));
}

fn loadSweatFrame(frame: u16) void {
    const byte_offset = @as(usize, frame) * sweat_tiles_per_frame * 32;
    const byte_len = sweat_tiles_per_frame * 32;
    const frame_bytes = player_sweat_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(sweat_base_tile, @ptrCast(@alignCast(frame_bytes)));
}

fn updatePlayer(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    const was_grounded = player.grounded;
    const horizontal: i16 = @intCast(input.getAxisHorizontal());
    const vertical: i16 = @intCast(input.getAxisVertical());
    const grab_held = input.isPressed(.L) or input.isPressed(.R);
    if (player.room_transition_cooldown > 0) {
        player.room_transition_cooldown -= 1;
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

    if (player.climb_ledge_timer > 0) {
        updateClimbLedgeMotion(player, room_index);
        updatePlayerAnimation(player);
        return;
    }

    player.moving = horizontal != 0;
    if (horizontal != 0) {
        player.facing_left = horizontal < 0;
    }

    const jump_pressed = input.isJustPressed(.A) or input.isJustPressed(.B);
    const jump_held = input.isPressed(.A) or input.isPressed(.B);

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
    const next_animation: PlayerAnimation = if (player.wall_sliding)
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
    index = 1;
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
    if (!bridge_active or room_index + 1 != rooms.len) return;

    const player_center_x = fixedToPixel(player.x) + player_body_width / 2;
    const player_bottom = fixedToPixel(player.y) + player_body_height;
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
            .inactive, .solid, .gone => {},
            .shaking => {
                if (chunk.timer > 0) {
                    chunk.timer -= 1;
                } else {
                    spawnBridgeSnow(chunk.*);
                    chunk.state = .falling;
                    chunk.vy = 0;
                }
            },
            .falling => {
                chunk.vy = approach(chunk.vy, bridge_fall_max_speed, bridge_fall_gravity);
                chunk.y += chunk.vy;
                if (fixedToPixel(chunk.y) > rooms[room_index].height_pixels + 40) {
                    chunk.state = .gone;
                }
            },
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
    chunk.state = .shaking;
    chunk.timer = bridge_shake_frames + delay;
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

fn beginPlayerDeath(death_timer: *u8, player: Player) void {
    death_timer.* = player_death_anim_frames;
    death_origin_x = player.x + (player_body_width / 2) * fixed_one;
    death_origin_y = player.y + (player_body_height / 2) * fixed_one;
    hideObject(player_object);
    hideObject(hair_root_object);
    hideObject(hair_object);
    hideObject(sweat_object);
    clearDustParticles();
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

fn streamRoomBackground(room_index: usize, camera: Camera) void {
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

fn logicalRoomMapEntry(room: RoomBackground, x: i16, y: i16) u16 {
    if (x < 0 or y < 0) return 0;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= room.width_tiles or uy >= room.height_tiles) return 0;
    const offset = (uy * room.width_tiles + ux) * 2;
    if (offset + 1 >= room.map.len) return 0;
    return @as(u16, room.map[offset]) | (@as(u16, room.map[offset + 1]) << 8);
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
        .priority = 0,
        .palette = 0,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn updatePlayerPalette(player: Player) void {
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&player_palette_data);
    if (!playerFatigueFlashVisible(player)) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[0], base_palette, 16);
        return;
    }

    gba.display.obj_palette.colors[0] = base_palette[0];
    var index: usize = 1;
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
        .priority = 0,
        .palette = sweat_palette_bank,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn updateHair(player: *Player) void {
    const anchor = hairAnchorWorld(player.*);
    const dir = anchor.dir;
    const falling_hair = player.animation == .fall;
    const climb_hair = player.animation == .climb or player.animation == .dangling or player.animation == .climb_pull or player.animation == .wallslide;
    const root = hairRootTailAnchorWorld(anchor, player.animation);
    const root_x = root.x;
    const root_y = root.y;
    if (!player.hair_initialized) {
        var index: usize = 0;
        while (index < hair_node_count) : (index += 1) {
            player.hair_nodes[index] = .{
                .x = root_x + @as(i32, dir) * @as(i32, @intCast(index + 1)) * fixed_one * 2,
                .y = root_y + @as(i32, @intCast(index)) * (fixed_one / 2),
            };
        }
        player.hair_initialized = true;
    }

    const speed_x = absI32(player.vx);
    const speed_y = absI32(player.vy);
    const lateral_push = fixed_one / 4 + @divTrunc(minI32(speed_x, fixed_one + fixed_one / 2), 7);
    const vertical_push: i32 = if (falling_hair)
        -(fixed_one / 2 + @divTrunc(minI32(speed_y, fixed_one * 3), 5))
    else if (player.animation == .jump)
        fixed_one / 8
    else if (climb_hair)
        fixed_one / 3
    else
        fixed_one / 2;
    const desired_dist: i32 = if (climb_hair) fixed_one * 2 else fixed_one + fixed_one / 2;

    var prev_x = root_x;
    var prev_y = root_y;
    var index: usize = 0;
    while (index < hair_node_count) : (index += 1) {
        const segment_push = @as(i32, @intCast(hair_node_count - index));
        player.hair_nodes[index].x += @as(i32, dir) * @divTrunc(lateral_push * segment_push, @as(i32, hair_node_count));
        player.hair_nodes[index].y += vertical_push - @as(i32, @intCast(index)) * (fixed_one / 12);

        constrainHairNode(&player.hair_nodes[index], prev_x, prev_y, desired_dist);
        prev_x = player.hair_nodes[index].x;
        prev_y = player.hair_nodes[index].y;
    }
}

fn drawHair(player: Player, camera: Camera) void {
    const anchor = hairAnchorWorld(player);
    const falling_hair = player.animation == .fall;
    const climb_hair = player.animation == .climb or player.animation == .dangling or player.animation == .climb_pull or player.animation == .wallslide;
    const root = hairRootTailAnchorWorld(anchor, player.animation);
    const sprite_x = fixedToPixel(root.x) - camera.x - 8;
    const sprite_offset_y: i16 = if (falling_hair) 11 else 9;
    const sprite_y = fixedToPixel(root.y) - camera.y - sprite_offset_y;
    clearHairPixels();

    var index: usize = 0;
    var prev_x = root.x;
    var prev_y = root.y;
    drawHairMaskBlobWorld(prev_x, prev_y, sprite_x + camera.x, sprite_y + camera.y, 1);
    while (index < hair_node_count) : (index += 1) {
        const size: u8 = if ((falling_hair or climb_hair) and index == 1) 2 else 1;
        const node_x = player.hair_nodes[index].x;
        const node_y = player.hair_nodes[index].y;
        drawHairMaskStrokeWorld(prev_x, prev_y, node_x, node_y, sprite_x + camera.x, sprite_y + camera.y, size);
        prev_x = node_x;
        prev_y = node_y;
    }
    renderHairMask();
    packHairTiles();
    gba.display.memcpyObjectTiles4Bpp(hair_base_tile, &hair_tiles);
    gba.display.objects[hair_object] = gba.display.Object.init(.{
        .size = .size_16x16,
        .x = objX(sprite_x),
        .y = objY(sprite_y),
        .base_tile = hair_base_tile,
        .priority = 0,
        .palette = hair_palette_bank,
    });
    drawHairRoot(anchor, camera);
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

fn drawHairRoot(anchor: HairAnchor, camera: Camera) void {
    const root = hairRootRect(anchor);
    gba.display.objects[hair_root_object] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(root.x - camera.x),
        .y = objY(root.y - camera.y),
        .base_tile = hair_root_base_tile,
        .priority = 0,
        .palette = hair_palette_bank,
        .flip = gba.math.Vec2B.init(root.flip_x, false),
    });
}

fn hairRootRect(anchor: HairAnchor) HairRootRect {
    const anchor_x = fixedToPixel(anchor.x);
    const anchor_y = fixedToPixel(anchor.y);
    const flip_x = anchor.dir > 0;
    const root_offset_x: i16 = if (flip_x) -4 else -3;
    return .{
        .x = anchor_x + root_offset_x,
        .y = anchor_y - 7,
        .flip_x = flip_x,
    };
}

fn hairRootTailAnchorWorld(anchor: HairAnchor, animation: PlayerAnimation) HairNode {
    const root = hairRootRect(anchor);
    const tail_offset_x: i16 = if (anchor.dir > 0) 7 else 0;
    const tail_x: i16 = root.x + tail_offset_x + anchor.tail_bias_x;
    const tail_offset_y: i16 = switch (animation) {
        .idle => 4,
        .jump, .fall, .wallslide, .climb, .dangling, .climb_pull => 5,
        .run => 6,
    };
    const tail_y: i16 = root.y + tail_offset_y + anchor.tail_bias_y;
    return .{
        .x = pixelToFixed(tail_x),
        .y = pixelToFixed(tail_y),
    };
}

fn hairAnchorWorld(player: Player) HairAnchor {
    const anchor_offset = @as(usize, player.frame) * 5;
    var anchor_x: i16 = 18;
    var anchor_y: i16 = 19;
    var dir: i16 = -1;
    var tail_bias_x: i16 = 0;
    var tail_bias_y: i16 = 0;
    if (anchor_offset + 4 < player_hair_anchors_data.len) {
        anchor_x = player_hair_anchors_data[anchor_offset];
        anchor_y = player_hair_anchors_data[anchor_offset + 1];
        dir = if (player_hair_anchors_data[anchor_offset + 2] == 0) -1 else 1;
        tail_bias_x = signedAnchorByte(player_hair_anchors_data[anchor_offset + 3]);
        tail_bias_y = signedAnchorByte(player_hair_anchors_data[anchor_offset + 4]);
    }
    if (player.facing_left) {
        anchor_x = 31 - anchor_x;
        dir = -dir;
        tail_bias_x = -tail_bias_x;
    }
    const body_x = fixedToPixel(player.x) + player_draw_offset_x;
    const body_y = fixedToPixel(player.y) + player_draw_offset_y;
    return .{
        .x = pixelToFixed(body_x + anchor_x),
        .y = pixelToFixed(body_y + anchor_y),
        .dir = dir,
        .tail_bias_x = tail_bias_x,
        .tail_bias_y = tail_bias_y,
    };
}

fn signedAnchorByte(value: u8) i16 {
    return if (value < 128) @intCast(value) else @as(i16, @intCast(value)) - 256;
}

fn clearHairPixels() void {
    var index: usize = 0;
    while (index < hair_pixels.len) : (index += 1) {
        hair_pixels[index] = 0;
        hair_mask[index] = 0;
    }
}

fn drawHairMaskStrokeWorld(world_x0: i32, world_y0: i32, world_x1: i32, world_y1: i32, origin_x: i16, origin_y: i16, size: u8) void {
    const x0 = fixedToPixel(world_x0) - origin_x;
    const y0 = fixedToPixel(world_y0) - origin_y;
    const x1 = fixedToPixel(world_x1) - origin_x;
    const y1 = fixedToPixel(world_y1) - origin_y;
    const steps = maxI16(absI16(x1 - x0), absI16(y1 - y0));
    if (steps == 0) {
        drawHairMaskBlobLocal(x0, y0, size);
        return;
    }

    var step: i16 = 0;
    while (step <= steps) : (step += 1) {
        const x = x0 + @divTrunc((x1 - x0) * step, steps);
        const y = y0 + @divTrunc((y1 - y0) * step, steps);
        drawHairMaskBlobLocal(x, y, size);
    }
}

fn drawHairMaskBlobLocal(local_x: i16, local_y: i16, size: u8) void {
    drawHairMaskDisc(local_x, local_y + 1, size, 2);
    drawHairMaskDisc(local_x, local_y, size, 3);
}

fn drawHairMaskBlobWorld(world_x: i32, world_y: i32, origin_x: i16, origin_y: i16, size: u8) void {
    const local_x = fixedToPixel(world_x) - origin_x;
    const local_y = fixedToPixel(world_y) - origin_y;
    drawHairMaskBlobLocal(local_x, local_y, size);
}

fn drawHairMaskDisc(center_x: i16, center_y: i16, radius: u8, color: u8) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setHairMaskPixel(center_x + x, center_y + y, color);
            }
        }
    }
}

fn renderHairMask() void {
    var y: i16 = 0;
    while (y < hair_sprite_size) : (y += 1) {
        var x: i16 = 0;
        while (x < hair_sprite_size) : (x += 1) {
            if (hairMaskPixel(x, y) == 0) continue;

            var oy: i16 = -1;
            while (oy <= 1) : (oy += 1) {
                var ox: i16 = -1;
                while (ox <= 1) : (ox += 1) {
                    if (ox == 0 and oy == 0) continue;
                    if (hairMaskPixel(x + ox, y + oy) == 0) {
                        setHairPixel(x + ox, y + oy, 1);
                    }
                }
            }
        }
    }

    y = 0;
    while (y < hair_sprite_size) : (y += 1) {
        var x: i16 = 0;
        while (x < hair_sprite_size) : (x += 1) {
            const color = hairMaskPixel(x, y);
            if (color != 0) setHairPixel(x, y, color);
        }
    }
}

fn hairMaskPixel(x: i16, y: i16) u8 {
    if (x < 0 or x >= hair_sprite_size or y < 0 or y >= hair_sprite_size) return 0;
    const index: usize = @intCast(y * hair_sprite_size + x);
    return hair_mask[index];
}

fn setHairMaskPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= hair_sprite_size or y < 0 or y >= hair_sprite_size) return;
    const index: usize = @intCast(y * hair_sprite_size + x);
    hair_mask[index] = color;
}

fn setHairPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= hair_sprite_size or y < 0 or y >= hair_sprite_size) return;
    const index: usize = @intCast(y * hair_sprite_size + x);
    hair_pixels[index] = color;
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

fn drawDust(camera: Camera) void {
    var index: usize = 0;
    while (index < max_dust_particles) : (index += 1) {
        clearDustTile(index);
        if (!dust_particles[index].active) {
            hideObject(dust_first_object + index);
            continue;
        }

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
    gba.display.memcpyObjectTiles4Bpp(dust_base_tile, &dust_tiles);
}

fn drawDeathBurst(camera: Camera, death_timer: u8) void {
    const elapsed: u8 = player_death_anim_frames - death_timer;
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
    if (rooms[room_index].wind_snow_strength == 0) {
        hideWindSnowObjects();
        return;
    }

    var index: usize = 0;
    while (index < max_wind_snow_particles) : (index += 1) {
        wind_snow_particles[index] = newWindSnowParticle(room_index, camera, index, true);
    }
}

fn updateWindSnow(room_index: usize, camera: Camera) void {
    const room = rooms[room_index];
    if (room.wind_snow_strength == 0) {
        hideWindSnowObjects();
        return;
    }

    var index: usize = 0;
    while (index < max_wind_snow_particles) : (index += 1) {
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
    _ = room_index;
    _ = x;
    const min_y = camera.y + 4;
    const max_y = camera.y + screen_height - 18;
    const span: usize = @intCast(max_y - min_y);
    const lane_count = max_wind_snow_particles;
    if (span <= 1) return min_y;
    if (index < max_wind_snow_particles and wind_snow_particles[index].active == false) {
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
    var index: usize = 0;
    while (index < max_wind_snow_particles) : (index += 1) {
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
    var index: usize = 0;
    while (index < max_wind_snow_particles) : (index += 1) {
        hideObject(wind_snow_first_object + index);
    }
}

fn drawParallaxObjects(camera: Camera, room_index: usize) void {
    const maybe_parallax = rooms[room_index].parallax;
    if (maybe_parallax == null) {
        hideParallaxObjects();
        return;
    }

    const parallax = maybe_parallax.?;
    const extra_x: i16 = if (parallax.scroll_extra_x_divisor == 0) 0 else @divTrunc(camera.x, parallax.scroll_extra_x_divisor);
    const extra_y: i16 = if (parallax.scroll_extra_y_divisor == 0) 0 else @divTrunc(camera.y, parallax.scroll_extra_y_divisor);
    const base_x = parallax.world_x - camera.x - extra_x;
    const base_y = parallax.world_y - camera.y - extra_y;
    var index: usize = 0;
    while (index < parallax_max_objects) : (index += 1) {
        if (index >= parallax.chunk_count) {
            hideObject(parallax_first_object + index);
            continue;
        }
        gba.display.objects[parallax_first_object + index] = gba.display.Object.init(.{
            .size = .size_64x64,
            .x = objX(base_x + @as(i16, @intCast(index)) * parallax_chunk_size),
            .y = objY(base_y),
            .base_tile = parallax_base_tile + @as(u10, @intCast(index * 64)),
            .priority = 0,
            .palette = parallax_palette_bank,
        });
    }
}

fn hideParallaxObjects() void {
    var index: usize = 0;
    while (index < parallax_max_objects) : (index += 1) {
        hideObject(parallax_first_object + index);
    }
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
    if (show_squawk_hint or bird_npc.state == .hold_hint or bird_npc.state == .climb_hint or show_hide_hint) {
        if (bird_npc.state == .squawk or bird_npc.state == .hold_hint) {
            gba.display.memcpyObjectTiles4Bpp(bird_hint_base_tile, @ptrCast(&bird_hold_hint_tiles_data));
        } else {
            gba.display.memcpyObjectTiles4Bpp(bird_hint_base_tile, @ptrCast(&bird_climb_hint_tiles_data));
        }
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

fn loadBirdFrame(frame: u16) void {
    const safe_frame = @min(frame, bird_total_frame_count - 1);
    const byte_offset = @as(usize, safe_frame) * bird_tiles_per_frame * 32;
    const byte_len = bird_tiles_per_frame * 32;
    const frame_bytes = bird_intro_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(bird_base_tile, @ptrCast(@alignCast(frame_bytes)));
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
            .priority = 0,
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
        .priority = 0,
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
        const base_tile = bridge_base_tile + @as(u10, @intCast(@as(u16, chunk.variant) * bridge_tiles_per_chunk));
        gba.display.objects[bridge_first_object + object_offset] = gba.display.Object.init(.{
            .size = .size_8x32,
            .x = objX(screen_x + shake_x),
            .y = objY(screen_y + shake_y),
            .base_tile = base_tile,
            .priority = 0,
            .palette = bridge_palette_bank,
        });
        object_offset += 1;
    }

    while (object_offset < bridge_max_objects) : (object_offset += 1) {
        hideObject(bridge_first_object + object_offset);
    }
}

fn hideBridgeObjects() void {
    var index: usize = 0;
    while (index < bridge_max_objects) : (index += 1) {
        hideObject(bridge_first_object + index);
    }
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
        if (bottom <= bridge_world_y or y >= bridge_world_y + bridge_visual_height) return false;
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
