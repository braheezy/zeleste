const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);

const prologue_m1_bg_tiles align(4) = @embedFile("prologue_m1_bg_tiles.bin").*;
const prologue_m1_bg_map align(4) = @embedFile("prologue_m1_bg_map.bin").*;
const prologue_m1_bg_palette align(4) = @embedFile("prologue_m1_bg_palette.bin").*;
const prologue_m1_spawn align(4) = @embedFile("prologue_m1_spawn.bin").*;
const prologue_m1_collision align(4) = @embedFile("prologue_m1_collision.bin").*;
const prologue_m1_falling_blocks align(4) = @embedFile("prologue_m1_falling_blocks.bin").*;
const prologue_0_bg_tiles align(4) = @embedFile("prologue_0_bg_tiles.bin").*;
const prologue_0_bg_map align(4) = @embedFile("prologue_0_bg_map.bin").*;
const prologue_0_bg_palette align(4) = @embedFile("prologue_0_bg_palette.bin").*;
const prologue_0_spawn align(4) = @embedFile("prologue_0_spawn.bin").*;
const prologue_0_collision align(4) = @embedFile("prologue_0_collision.bin").*;
const prologue_0_falling_blocks align(4) = @embedFile("prologue_0_falling_blocks.bin").*;
const prologue_0b_bg_tiles align(4) = @embedFile("prologue_0b_bg_tiles.bin").*;
const prologue_0b_bg_map align(4) = @embedFile("prologue_0b_bg_map.bin").*;
const prologue_0b_bg_palette align(4) = @embedFile("prologue_0b_bg_palette.bin").*;
const prologue_0b_spawn align(4) = @embedFile("prologue_0b_spawn.bin").*;
const prologue_0b_collision align(4) = @embedFile("prologue_0b_collision.bin").*;
const prologue_0b_falling_blocks align(4) = @embedFile("prologue_0b_falling_blocks.bin").*;
const player_tiles_data align(4) = @embedFile("player_idle_tiles.bin").*;
const player_palette_data align(4) = @embedFile("player_palette.bin").*;
const player_hair_anchors_data align(4) = @embedFile("player_hair_anchors.bin").*;
const player_sweat_tiles_data align(4) = @embedFile("player_sweat_tiles.bin").*;
const player_sweat_palette_data align(4) = @embedFile("player_sweat_palette.bin").*;
const hair_tiles_data align(4) = @embedFile("hair_tiles.bin").*;
const hair_palette_data align(4) = @embedFile("hair_palette.bin").*;
const falling_block_tiles_data align(4) = @embedFile("falling_block_tiles.bin").*;
const falling_block_palette_data align(4) = @embedFile("falling_block_palette.bin").*;

const bg_screenblock: u5 = 28;
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
const player_gravity: i32 = 0x40;
const player_max_fall: i32 = 0x2A8;
const player_fast_max_fall: i32 = 0x400;
const player_half_grav_threshold: i32 = 0xAA;
const player_jump_speed: i32 = -0x1C0;
const player_wall_jump_h_speed: i32 = 0x230;
const player_wall_slide_start_max: i32 = 0x55;
const player_wall_slide_frames = 72;
const player_room_transition_cooldown_frames = 18;
const player_climb_max_stamina: i16 = 660;
const player_climb_up_speed: i32 = -0xBF;
const player_climb_down_speed: i32 = 0x154;
const player_climb_slip_speed: i32 = 0x80;
const player_climb_accel: i32 = 0x64;
const player_climb_grab_y_mult: i32 = 0x80;
const player_climb_up_cost: i16 = 5;
const player_climb_still_cost: i16 = 1;
const player_climb_ledge_frames = 8;
const player_climb_ledge_hop_pixels = 6;
const player_climb_jump_lockout_frames = 8;
const player_var_jump_frames = 12;
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
const falling_block_shake_frames = 48;
const falling_block_gravity: i32 = 0x20;
const falling_block_max_fall: i32 = 0x300;
const falling_block_base_tile: u10 = 32;
const falling_block_palette_bank: u4 = 1;
const hair_base_tile: u10 = 60;
const hair_root_base_tile: u10 = 64;
const hair_palette_bank: u4 = 2;
const dust_base_tile: u10 = 68;
const dust_palette_bank: u4 = 3;
const max_dust_particles = 4;
const sweat_base_tile: u10 = 72;
const sweat_palette_bank: u4 = 4;
const player_object = 0;
const hair_root_object = 1;
const hair_object = 2;
const dust_first_object = 3;
const sweat_object = 7;
const hair_node_count = 3;
const hair_sprite_size = 16;
const falling_block_first_object = 8;
const falling_block_objects_per_block = 3;
const room_prologue_m1: usize = 0;
const room_prologue_0: usize = 1;
const room_prologue_0b: usize = 2;

const RoomBackground = struct {
    width_tiles: usize,
    height_tiles: usize,
    width_pixels: i16,
    height_pixels: i16,
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
    collision: []align(4) const u8,
    spawn: Spawn,
    falling_blocks: []align(4) const u8,
};

const Spawn = struct {
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

const rooms = [_]RoomBackground{
    .{
        .width_tiles = 40,
        .height_tiles = 23,
        .width_pixels = 320,
        .height_pixels = 184,
        .tiles = &prologue_m1_bg_tiles,
        .map = &prologue_m1_bg_map,
        .palette = &prologue_m1_bg_palette,
        .collision = &prologue_m1_collision,
        .spawn = spawnFromBytes(&prologue_m1_spawn),
        .falling_blocks = &prologue_m1_falling_blocks,
    },
    .{
        .width_tiles = 56,
        .height_tiles = 23,
        .width_pixels = 448,
        .height_pixels = 184,
        .tiles = &prologue_0_bg_tiles,
        .map = &prologue_0_bg_map,
        .palette = &prologue_0_bg_palette,
        .collision = &prologue_0_collision,
        .spawn = spawnFromBytes(&prologue_0_spawn),
        .falling_blocks = &prologue_0_falling_blocks,
    },
    .{
        .width_tiles = 54,
        .height_tiles = 23,
        .width_pixels = 432,
        .height_pixels = 184,
        .tiles = &prologue_0b_bg_tiles,
        .map = &prologue_0b_bg_map,
        .palette = &prologue_0b_bg_palette,
        .collision = &prologue_0b_collision,
        .spawn = spawnFromBytes(&prologue_0b_spawn),
        .falling_blocks = &prologue_0b_falling_blocks,
    },
};

var falling_blocks: [max_falling_blocks]FallingBlock = [_]FallingBlock{.{}} ** max_falling_blocks;
var falling_block_count: usize = 0;
var current_room_index: usize = 0;
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
    room_transition_cooldown: u8 = 0,
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

pub export fn main() void {
    var room_index: usize = room_prologue_0;
    loadRoomBackground(room_index);
    loadFallingBlocks(room_index);
    loadObjectSprites();
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
    var camera = updateCamera(player, room_index);
    applyCamera(camera);
    drawPlayer(player, camera);
    drawFallingBlockObjects(camera);

    while (true) {
        gba.display.naiveVSync();
        input.poll();
        updatePlayer(&player, input, room_index);
        updateFallingBlocks(&player);
        updateHair(&player);
        updateDustParticles();
        if (trySwitchRoom(&player, input, &room_index)) {
            gba.display.bg_palette.colors[0] = .black;
            gba.display.ctrl.bg0 = false;
            gba.display.ctrl.obj = false;
            gba.display.hideAllObjects();
            gba.display.naiveVSync();
            loadRoomBackground(room_index);
            loadFallingBlocks(room_index);
            clearDustParticles();
            player.hair_initialized = false;
            updateHair(&player);
            camera = updateCamera(player, room_index);
            applyCamera(camera);
            drawHair(player, camera);
            drawDust(camera);
            drawPlayer(player, camera);
            drawSweat(&player, camera);
            drawFallingBlockObjects(camera);
            gba.display.naiveVSync();
            gba.display.ctrl.bg0 = true;
            gba.display.ctrl.obj = true;
            continue;
        }
        camera = updateCamera(player, room_index);
        applyCamera(camera);
        drawHair(player, camera);
        drawDust(camera);
        drawPlayer(player, camera);
        drawSweat(&player, camera);
        drawFallingBlockObjects(camera);
    }
}

fn loadRoomBackground(room_index: usize) void {
    current_room_index = room_index;
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
    gba.mem.memcpy16(&gba.display.screenblocks[bg_screenblock], @ptrCast(room.map.ptr), room.map.len / 2);
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

        const block = FallingBlock{
            .active = true,
            .x = x,
            .y = pixelToFixed(y),
            .w = w,
            .h = h,
            .max_y = max_y - @as(i16, @intCast(h)),
        };

        falling_blocks[falling_block_count] = block;
        falling_block_count += 1;
    }
}

fn loadObjectSprites() void {
    gba.mem.memcpy(gba.display.obj_palette, &player_palette_data, player_palette_data.len);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[16], @ptrCast(&falling_block_palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[32], @ptrCast(&hair_palette_data), 16);
    gba.display.obj_palette.colors[48] = .black;
    gba.display.obj_palette.colors[49] = .white;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[64], @ptrCast(&player_sweat_palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(falling_block_base_tile, @ptrCast(&falling_block_tiles_data));
    gba.display.memcpyObjectTiles4Bpp(hair_root_base_tile, @ptrCast(&hair_tiles_data));
    loadPlayerFrame(0);
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

    if (player.climb_ledge_timer > 0) {
        updateClimbLedgeMotion(player);
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

    updateHorizontalSpeed(player, horizontal);

    const wall_jump_dir = wallJumpDirection(player.*, horizontal, room_index);
    var jumped_this_frame = false;

    if (player.jump_buffer_timer > 0 and player.coyote_timer > 0) {
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
    } else if (player.jump_buffer_timer > 0 and wall_jump_dir != 0) {
        spawnJumpDustAtFeet(player.*);
        player.vx = @as(i32, wall_jump_dir) * player_wall_jump_h_speed;
        player.vy = player_jump_speed;
        player.var_jump_speed = player.vy;
        player.var_jump_timer = player_var_jump_frames;
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
        updateVerticalSpeed(player, jump_held, input.isPressed(.down), horizontal, room_index);
    }

    moveHorizontal(player, player.vx, room_index);
    player.grounded = false;
    moveVertical(player, player.vy, room_index);
    if (!player.grounded and player.vy >= 0 and floorContact(player.*, room_index)) {
        player.grounded = true;
    }

    if (player.grounded) {
        if (!was_grounded) {
            spawnLandingDustAtFeet(player.*);
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
        const gravity = if (absI32(player.vy) < player_half_grav_threshold and jump_held)
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

    player.facing_left = climb_dir < 0;
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
    } else {
        player.stamina = @max(0, player.stamina - player_climb_still_cost);
    }
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

    var y_offset: i16 = -18;
    while (y_offset <= 8) : (y_offset += 1) {
        var over: i16 = player_body_width - 2;
        while (over <= player_body_width + 8) : (over += 1) {
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

fn updateClimbLedgeMotion(player: *Player) void {
    const duration: i32 = player_climb_ledge_frames;
    const elapsed: i32 = duration - @as(i32, player.climb_ledge_timer) + 1;
    const remaining = duration - elapsed;
    const denom = duration * duration;
    const eased = denom - remaining * remaining;
    const arc = @divTrunc(4 * player_climb_ledge_hop_pixels * fixed_one * elapsed * remaining, denom);

    player.x = player.climb_ledge_start_x + @divTrunc((player.climb_ledge_target_x - player.climb_ledge_start_x) * eased, denom);
    player.y = player.climb_ledge_start_y + @divTrunc((player.climb_ledge_target_y - player.climb_ledge_start_y) * elapsed, duration) - arc;
    player.vx = 0;
    player.vy = 0;
    player.moving = false;
    player.grounded = false;
    player.climbing = true;
    player.climb_dangling = false;
    player.wall_sliding = false;

    player.climb_ledge_timer -= 1;
    if (player.climb_ledge_timer == 0) {
        player.x = player.climb_ledge_target_x;
        player.y = player.climb_ledge_target_y;
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
    loadPlayerFrame(player.frame);
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
        dust_particles[index].vy += 0x08;
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

fn updateFallingBlocks(player: *Player) void {
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
                    block.state = .falling;
                    block.vy = 0;
                }
            },
            .falling => {
                const old_y = fixedToPixel(block.y);
                block.vy = approach(block.vy, falling_block_max_fall, falling_block_gravity);
                block.y += block.vy;
                if (fixedToPixel(block.y) >= block.max_y) {
                    block.y = pixelToFixed(block.max_y);
                    block.vy = 0;
                    block.state = .landed;
                }

                const dy = fixedToPixel(block.y) - old_y;
                if (dy > 0 and playerStandingOnBlock(player.*, block.*)) {
                    player.y += @as(i32, dy) << fixed_shift;
                }
            },
            .landed => {},
        }
    }
}

fn playerBelowBlock(player: Player, block: FallingBlock) bool {
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const player_center_x = player_x + player_body_width / 2;
    const trigger_left = block.x + @as(i16, @intCast(block.w / 2));
    const trigger_right = block.x + block.w + 8;
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
    return collidesAt(x, y + 1, room_index) or oneWayFloorAt(x, y, room_index);
}

fn trySwitchRoom(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize) bool {
    if (player.room_transition_cooldown > 0) return false;

    const room = rooms[room_index.*];
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    if (input.isPressed(.right) and player_x >= room.width_pixels - player_body_width) {
        if (room_index.* == room_prologue_m1) {
            room_index.* = room_prologue_0;
            enterRoomFromLeft(player);
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    if (input.isPressed(.left) and player_x <= 0) {
        if (room_index.* == room_prologue_0) {
            room_index.* = room_prologue_m1;
            enterRoomFromRight(player, room_index.*);
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    if (player_y <= 0) {
        if (room_index.* == room_prologue_0) {
            room_index.* = room_prologue_0b;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromBottom(player, room_index.*);
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    if (player_y >= room.height_pixels - player_body_height - 1) {
        if (room_index.* == room_prologue_0b) {
            room_index.* = room_prologue_0;
            clampPlayerToRoom(player, room_index.*);
            enterRoomFromTop(player);
            startRoomTransitionCooldown(player);
            return true;
        }
    }
    return false;
}

fn startRoomTransitionCooldown(player: *Player) void {
    player.room_transition_cooldown = player_room_transition_cooldown_frames;
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
    gba.display.bg_scroll[0] = .init(@intCast(camera.x), @intCast(camera.y));
}

fn drawPlayer(player: Player, camera: Camera) void {
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
    if (!player.hair_initialized) {
        var index: usize = 0;
        while (index < hair_node_count) : (index += 1) {
            player.hair_nodes[index] = .{
                .x = anchor.x,
                .y = anchor.y,
            };
        }
        player.hair_initialized = true;
    }

    var target_x = anchor.x + (@as(i32, dir) << fixed_shift);
    var target_y = if (falling_hair) anchor.y else anchor.y - fixed_one;
    var index: usize = 0;
    while (index < hair_node_count) : (index += 1) {
        const spacing_x: i32 = if (falling_hair)
            switch (index) {
                0 => 0,
                1 => 0,
                else => @as(i32, -dir),
            }
        else if (index == 0)
            @as(i32, dir)
        else
            0;
        target_x += spacing_x << fixed_shift;
        const spacing_y: i32 = if (falling_hair)
            switch (index) {
                0 => -2,
                1 => -2,
                else => -1,
            }
        else switch (index) {
            0 => 1,
            1 => 2,
            else => 2,
        };
        target_y += spacing_y << fixed_shift;
        if (index == 0) {
            player.hair_nodes[index].x = target_x;
            player.hair_nodes[index].y = target_y;
        } else {
            player.hair_nodes[index].x += @divTrunc(target_x - player.hair_nodes[index].x, 2);
            const y_ease: i32 = if (falling_hair) 2 else 4;
            player.hair_nodes[index].y += @divTrunc(target_y - player.hair_nodes[index].y, y_ease);
        }
        target_x = player.hair_nodes[index].x;
        target_y = player.hair_nodes[index].y;
    }
}

fn drawHair(player: Player, camera: Camera) void {
    const anchor = hairAnchorWorld(player);
    const dir = anchor.dir;
    const falling_hair = player.animation == .fall;
    const sprite_offset_x: i16 = if (anchor.dir > 0) -4 else -12;
    const sprite_x = fixedToPixel(anchor.x) - camera.x + sprite_offset_x;
    const sprite_offset_y: i16 = if (falling_hair) 9 else 5;
    const sprite_y = fixedToPixel(anchor.y) - camera.y - sprite_offset_y;
    clearHairPixels();

    var index: usize = 0;
    var prev_x = anchor.x + (@as(i32, dir) << fixed_shift);
    const prev_y_offset: i32 = if (falling_hair) fixed_one * 2 else fixed_one * 2;
    var prev_y = anchor.y - prev_y_offset;
    drawHairMaskBlobWorld(prev_x, prev_y, sprite_x + camera.x, sprite_y + camera.y, 1);
    while (index < hair_node_count) : (index += 1) {
        const size: u8 = if (falling_hair and index == 1) 2 else if (!falling_hair and index == 1) 2 else 1;
        const node_x_offset_shift: u5 = if (falling_hair) fixed_shift + 1 else fixed_shift + 1;
        const node_x = player.hair_nodes[index].x + (@as(i32, dir) << node_x_offset_shift);
        const node_y = if (falling_hair) player.hair_nodes[index].y else player.hair_nodes[index].y - fixed_one;
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

fn drawHairRoot(anchor: HairAnchor, camera: Camera) void {
    const anchor_x = fixedToPixel(anchor.x) - camera.x;
    const anchor_y = fixedToPixel(anchor.y) - camera.y;
    const flip_x = anchor.dir > 0;
    const root_offset_x: i16 = if (flip_x) -4 else -3;
    const root_x = anchor_x + root_offset_x;
    const root_y = anchor_y - 7;
    gba.display.objects[hair_root_object] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(root_x),
        .y = objY(root_y),
        .base_tile = hair_root_base_tile,
        .priority = 0,
        .palette = hair_palette_bank,
        .flip = gba.math.Vec2B.init(flip_x, false),
    });
}

fn hairAnchorWorld(player: Player) HairAnchor {
    const anchor_offset = @as(usize, player.frame) * 3;
    var anchor_x: i16 = 18;
    var anchor_y: i16 = 19;
    var dir: i16 = -1;
    if (anchor_offset + 2 < player_hair_anchors_data.len) {
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

fn clearDustTile(tile_index: usize) void {
    var byte_index: usize = 0;
    while (byte_index < 32) : (byte_index += 1) {
        dust_tiles[tile_index].data_8[byte_index] = 0;
    }
}

fn drawDustShape(tile_index: usize, particle: DustParticle) void {
    const age = particle.max_life - particle.life;
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

fn drawFallingBlockObjects(camera: Camera) void {
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = falling_blocks[index];
        if (!block.active) {
            hideFallingBlockObject(index);
            continue;
        }

        const shake: i16 = if (block.state == .shaking and (block.timer & 3) < 2) -1 else 0;
        const draw_x = block.x - camera.x + shake;
        const draw_y = fixedToPixel(block.y) - camera.y;
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

fn hideObject(object_index: usize) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(240),
        .y = objY(160),
        .base_tile = 0,
    });
}

fn spawnPlayer(room_index: usize) Player {
    const spawn = rooms[room_index].spawn;
    return .{
        .x = pixelToFixed(spawn.x),
        .y = pixelToFixed(spawn.y),
    };
}

fn enterRoomFromLeft(player: *Player) void {
    player.x = pixelToFixed(1);
}

fn enterRoomFromRight(player: *Player, room_index: usize) void {
    player.x = pixelToFixed(rooms[room_index].width_pixels - player_body_width - 1);
}

fn enterRoomFromTop(player: *Player) void {
    player.y = pixelToFixed(1);
}

fn enterRoomFromBottom(player: *Player, room_index: usize) void {
    player.y = pixelToFixed(rooms[room_index].height_pixels - player_body_height - 8);
    player.vy = 0;
}

fn clampPlayerToRoom(player: *Player, room_index: usize) void {
    const room = rooms[room_index];
    const x = clampI16(fixedToPixel(player.x), 1, room.width_pixels - player_body_width - 1);
    player.x = pixelToFixed(x);
}

fn spawnFromBytes(bytes: []align(4) const u8) Spawn {
    return .{
        .x = readI16Le(bytes, 0),
        .y = readI16Le(bytes, 2),
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
        if (collidesAt(next, fixedToPixel(player.y), room_index)) {
            player.x = pixelToFixed(pixel);
            player.vx = 0;
            return;
        }
        pixel = next;
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

fn collidesAt(x: i16, y: i16, room_index: usize) bool {
    return solidRectAt(x, y, player_body_width, player_body_height, room_index) or
        dynamicSolidRectAt(x, y, player_body_width, player_body_height);
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
    if (left < 0 or right >= room.width_pixels or bottom >= room.height_pixels) return true;
    if (bottom < 0) return false;

    const tile_left: usize = @intCast(@divTrunc(left, 8));
    const tile_right: usize = @intCast(@divTrunc(right, 8));
    const tile_top: usize = if (top < 0) 0 else @intCast(@divTrunc(top, 8));
    const tile_bottom: usize = @intCast(@divTrunc(bottom, 8));
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
    return oneWayPlatformTopAtBottom(player_x + player_body_width - 1, old_bottom, next_bottom, room_index);
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

fn clampI16(value: i16, min_value: i16, max_value: i16) i16 {
    if (max_value <= min_value) return min_value;
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}
