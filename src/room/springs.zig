const gba = @import("gba");
const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dust = @import("../effects/dust.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const clampI16 = math.clampI16;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const screen_width = 240;
const screen_height = 160;

const tiles_data align(4) = assets.spring_tiles_data;
const palette_data align(4) = assets.spring_palette_data;
const rooms = level.rooms;

pub const max_springs = 32;

const record_bytes = 8;
const trigger_cooldown_frames = spring_frame_count - 1;
const visible_spring_capacity = 7;
const first_object = 64;
const base_tile: u10 = @intCast(obj_vram.springs.start);
const palette_bank: u4 = 5;
const spring_frame_count = 23;
const tiles_per_sprite = 8;
const spring_source_width: i16 = 14;
const spring_cell_width: i16 = 16;
const spring_horizontal_pad: i16 = (spring_cell_width - spring_source_width) / 2;
const spring_idle_top: i16 = 14;

const Direction = enum(u8) {
    up = 0,
    down = 1,
    left = 2,
    right = 3,
};

const Spring = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    direction: Direction = .up,
    cooldown: u8 = 0,
};

var springs: [max_springs]Spring = [_]Spring{.{}} ** max_springs;
var spring_count: usize = 0;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    springs = [_]Spring{.{}} ** max_springs;
    spring_count = 0;
    hideObjects();

    const data = rooms[room_index].springs;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_springs);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;
        springs[spring_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
            .direction = directionFromByte(data[source_offset + 6]),
        };
        spring_count += 1;
    }
    if (spring_count > 0) {
        loadGraphics();
    }
}

pub fn update(player: *Player) void {
    var index: usize = 0;
    while (index < spring_count) : (index += 1) {
        const spring = &springs[index];
        if (!spring.active) continue;
        if (spring.cooldown > 0) {
            spring.cooldown -= 1;
            continue;
        }
        if (!playerTouchesSpring(player.*, spring.*)) continue;

        bouncePlayer(player, spring.*);
        spring.cooldown = trigger_cooldown_frames;
        return;
    }
}

pub fn draw(camera: Camera) void {
    if (spring_count == 0 and last_drawn_objects == 0) return;

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < spring_count and object_offset < visible_spring_capacity) : (index += 1) {
        if (!springs[index].active) {
            continue;
        }
        const spring = springs[index];
        const pos = objectPosition(spring);
        const x = pos.x - camera.x;
        const y = pos.y - camera.y;
        if (!visible(x, y, spring_cell_width, 32)) continue;

        gba.display.objects[first_object + object_offset] = gba.display.Object.init(.{
            .size = .size_16x32,
            .x = objX(x),
            .y = objY(y),
            .base_tile = base_tile + tileOffset(visualFrame(spring.cooldown)),
            .priority = 2,
            .palette = palette_bank,
        });
        object_offset += 1;
    }

    const drawn_objects = object_offset;
    const hide_until = @min(last_drawn_objects, visible_spring_capacity);
    while (object_offset < hide_until) : (object_offset += 1) {
        hideObject(first_object + object_offset);
    }
    last_drawn_objects = drawn_objects;
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < visible_spring_capacity) : (index += 1) {
        hideObject(first_object + index);
    }
    last_drawn_objects = 0;
}

pub fn loadGraphics() void {
    if (spring_count == 0) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
}

fn directionFromByte(value: u8) Direction {
    return switch (value) {
        1 => .down,
        2 => .left,
        3 => .right,
        else => .up,
    };
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < screen_width and y < screen_height and x + width > 0 and y + height > 0;
}

fn playerTouchesSpring(player: Player, spring: Spring) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;
    const spring_left = spring.x - 1;
    const spring_top = spring.y - 1;
    const spring_right = spring.x + @as(i16, @intCast(spring.w)) + 1;
    const spring_bottom = spring.y + @as(i16, @intCast(spring.h)) + 1;
    return collision.rectsOverlap(
        player_left,
        player_top,
        player_right,
        player_bottom,
        spring_left,
        spring_top,
        spring_right,
        spring_bottom,
    );
}

fn bouncePlayer(player: *Player, spring: Spring) void {
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.dash_effect_timer = 0;
    player.dash_trail_timer = 0;
    player.dash_dir_x = 0;
    player.dash_dir_y = 0;
    player.jump_buffer_timer = 0;
    player.coyote_timer = 0;
    player.var_jump_timer = 0;
    player.force_move_x_timer = 0;
    player.climb_ledge_timer = 0;
    player.climb_grab_lockout_timer = 0;
    player.climbing = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.wall_sliding = false;
    player.grounded = false;
    player.dust_suppress_timer = 4;

    switch (spring.direction) {
        .up => {
            player.y = pixelToFixed(spring.y - player_mod.body_height);
            player.vx = 0;
            player.vy = upwardBounceSpeed(player_mod.super_bounce_speed, player.vy);
        },
        .down => {
            player.y = pixelToFixed(spring.y + @as(i16, @intCast(spring.h)));
            player.vx = 0;
            player.vy = downwardBounceSpeed(-player_mod.super_bounce_speed, player.vy);
        },
        .left => {
            alignPlayerForSideBounce(player, spring);
            player.x = pixelToFixed(spring.x - player_mod.body_width);
            player.vx = leftwardBounceSpeed(player.vx);
            player.vy = player_mod.bounce_speed;
            player.force_move_x = -1;
            player.force_move_x_timer = player_mod.side_bounce_force_move_frames;
            player.facing_left = true;
        },
        .right => {
            alignPlayerForSideBounce(player, spring);
            player.x = pixelToFixed(spring.x + @as(i16, @intCast(spring.w)));
            player.vx = rightwardBounceSpeed(player.vx);
            player.vy = player_mod.bounce_speed;
            player.force_move_x = 1;
            player.force_move_x_timer = player_mod.side_bounce_force_move_frames;
            player.facing_left = false;
        },
    }
    dust.spawnJumpAtFeet(player.*);
}

fn upwardBounceSpeed(base: i32, incoming_vy: i32) i32 {
    return base - springMomentumBonus(if (incoming_vy > 0) incoming_vy else 0);
}

fn downwardBounceSpeed(base: i32, incoming_vy: i32) i32 {
    return base + springMomentumBonus(if (incoming_vy < 0) -incoming_vy else 0);
}

fn leftwardBounceSpeed(incoming_vx: i32) i32 {
    return -player_mod.side_bounce_speed - springMomentumBonus(if (incoming_vx > 0) incoming_vx else 0);
}

fn rightwardBounceSpeed(incoming_vx: i32) i32 {
    return player_mod.side_bounce_speed + springMomentumBonus(if (incoming_vx < 0) -incoming_vx else 0);
}

fn springMomentumBonus(speed: i32) i32 {
    const bonus = @divTrunc(speed, player_mod.spring_momentum_bonus_divisor);
    return if (bonus > player_mod.spring_momentum_bonus_cap) player_mod.spring_momentum_bonus_cap else bonus;
}

fn alignPlayerForSideBounce(player: *Player, spring: Spring) void {
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    const spring_center_y = spring.y + @as(i16, @intCast(spring.h / 2));
    const delta_y = clampI16(spring_center_y - player_bottom, -4, 4);
    player.y += pixelToFixed(delta_y);
}

fn visualFrame(cooldown: u8) u8 {
    if (cooldown == 0) return 0;
    return @intCast(spring_frame_count - cooldown);
}

fn tileOffset(frame: u8) u10 {
    return @intCast(@as(usize, frame) * tiles_per_sprite);
}

fn objectPosition(spring: Spring) struct { x: i16, y: i16 } {
    const width: i16 = @intCast(spring.w);
    return .{
        .x = spring.x + @divTrunc(width, 2) - @divTrunc(spring_source_width, 2) - spring_horizontal_pad,
        .y = spring.y - spring_idle_top,
    };
}
