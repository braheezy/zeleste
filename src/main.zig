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
const player_tiles_data align(4) = @embedFile("player_idle_tiles.bin").*;
const player_palette_data align(4) = @embedFile("player_palette.bin").*;
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
const player_var_jump_frames = 12;
const player_coyote_frames = 6;
const player_jump_buffer_frames = 5;
const player_tiles_per_frame = 16;
const player_animation_speed = 6;
const player_idle_first_frame = 0;
const player_idle_frame_count = 66;
const player_run_first_frame = 66;
const player_run_frame_count = 12;
const player_wallslide_first_frame = 78;
const max_falling_blocks = 8;
const falling_block_shake_frames = 48;
const falling_block_gravity: i32 = 0x20;
const falling_block_max_fall: i32 = 0x300;
const falling_block_base_tile: u10 = 32;
const falling_block_palette_bank: u4 = 1;
const falling_block_first_object = 1;
const falling_block_objects_per_block = 3;

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
};

var falling_blocks: [max_falling_blocks]FallingBlock = [_]FallingBlock{.{}} ** max_falling_blocks;
var falling_block_count: usize = 0;
var current_room_index: usize = 0;

const Player = struct {
    x: i32,
    y: i32,
    vx: i32 = 0,
    vy: i32 = 0,
    coyote_timer: u8 = 0,
    jump_buffer_timer: u8 = 0,
    var_jump_timer: u8 = 0,
    wall_slide_timer: u8 = player_wall_slide_frames,
    var_jump_speed: i32 = 0,
    animation_timer: u16 = 0,
    frame: u16 = 0,
    grounded: bool = false,
    facing_left: bool = false,
    moving: bool = false,
    wall_sliding: bool = false,
};

pub export fn main() void {
    var room_index: usize = 0;
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
        if (trySwitchRoom(&player, input, &room_index)) {
            loadRoomBackground(room_index);
            loadFallingBlocks(room_index);
        }
        camera = updateCamera(player, room_index);
        applyCamera(camera);
        drawPlayer(player, camera);
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
    gba.display.memcpyObjectTiles4Bpp(falling_block_base_tile, @ptrCast(&falling_block_tiles_data));
    loadPlayerFrame(0);
}

fn loadPlayerFrame(frame: u16) void {
    const byte_offset = @as(usize, frame) * player_tiles_per_frame * 32;
    const byte_len = player_tiles_per_frame * 32;
    const frame_bytes = player_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(@alignCast(frame_bytes)));
}

fn updatePlayer(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    const horizontal: i16 = @intCast(input.getAxisHorizontal());
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
    } else if (player.coyote_timer > 0) {
        player.coyote_timer -= 1;
    }

    updateHorizontalSpeed(player, horizontal);

    const wall_jump_dir = wallJumpDirection(player.*, horizontal, room_index);

    if (player.jump_buffer_timer > 0 and player.coyote_timer > 0) {
        player.vy = player_jump_speed;
        player.var_jump_speed = player.vy;
        player.var_jump_timer = player_var_jump_frames;
        player.jump_buffer_timer = 0;
        player.coyote_timer = 0;
        player.grounded = false;
    } else if (player.jump_buffer_timer > 0 and wall_jump_dir != 0) {
        player.vx = @as(i32, wall_jump_dir) * player_wall_jump_h_speed;
        player.vy = player_jump_speed;
        player.var_jump_speed = player.vy;
        player.var_jump_timer = player_var_jump_frames;
        player.jump_buffer_timer = 0;
        player.coyote_timer = 0;
        player.grounded = false;
        player.facing_left = wall_jump_dir < 0;
    }

    updateVerticalSpeed(player, jump_held, input.isPressed(.down), horizontal, room_index);

    moveHorizontal(player, player.vx, room_index);
    player.grounded = false;
    moveVertical(player, player.vy, room_index);

    if (player.grounded) {
        player.var_jump_timer = 0;
        player.wall_slide_timer = player_wall_slide_frames;
        player.wall_sliding = false;
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

fn updatePlayerAnimation(player: *Player) void {
    const first_frame: u16 = if (player.wall_sliding)
        player_wallslide_first_frame
    else if (player.moving)
        player_run_first_frame
    else
        player_idle_first_frame;
    const frame_count: u16 = if (player.wall_sliding)
        1
    else if (player.moving)
        player_run_frame_count
    else
        player_idle_frame_count;
    player.animation_timer +%= 1;
    const frame_offset = (player.animation_timer / player_animation_speed) % frame_count;
    player.frame = first_frame + frame_offset;
    loadPlayerFrame(player.frame);
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
    return player_center_x >= block.x and
        player_center_x < block.x + block.w and
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
    return solidAtPixel(x, y + 2, room_index) or
        solidAtPixel(x, y + player_body_height - 3, room_index);
}

fn trySwitchRoom(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize) bool {
    const room = rooms[room_index.*];
    const player_x = fixedToPixel(player.x);
    if (input.isPressed(.right) and player_x >= room.width_pixels - player_body_width) {
        if (room_index.* + 1 < rooms.len) {
            room_index.* += 1;
            enterRoomFromLeft(player);
            return true;
        }
    }
    if (input.isPressed(.left) and player_x <= 0) {
        if (room_index.* > 0) {
            room_index.* -= 1;
            enterRoomFromRight(player, room_index.*);
            return true;
        }
    }
    return false;
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
    gba.display.objects[0] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = 0,
        .priority = 0,
        .palette = 0,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn drawFallingBlockObjects(camera: Camera) void {
    hideFallingBlockObjects();

    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = falling_blocks[index];
        if (!block.active) continue;

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

fn hideFallingBlockObjects() void {
    var index: usize = 0;
    while (index < max_falling_blocks * falling_block_objects_per_block) : (index += 1) {
        gba.display.objects[falling_block_first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(240),
            .y = objY(160),
            .base_tile = 0,
        });
    }
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
        pixel = next;
    }
    player.y = target;
}

fn collidesAt(x: i16, y: i16, room_index: usize) bool {
    const right = x + player_body_width - 1;
    const bottom = y + player_body_height - 1;
    return solidAtPixel(x, y, room_index) or
        solidAtPixel(right, y, room_index) or
        solidAtPixel(x, bottom, room_index) or
        solidAtPixel(right, bottom, room_index);
}

fn solidAtPixel(x: i16, y: i16, room_index: usize) bool {
    const room = rooms[room_index];
    if (x < 0 or x >= room.width_pixels or y >= room.height_pixels) return true;
    if (y < 0) return false;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    return room.collision[tile_y * room.width_tiles + tile_x] != 0 or dynamicSolidAtPixel(x, y);
}

fn dynamicSolidAtPixel(x: i16, y: i16) bool {
    var index: usize = 0;
    while (index < falling_block_count) : (index += 1) {
        const block = falling_blocks[index];
        if (!block.active) continue;
        const block_y = fixedToPixel(block.y);
        if (x >= block.x and x < block.x + block.w and y >= block_y and y < block_y + block.h) {
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
