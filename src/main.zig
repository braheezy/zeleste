const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("ZELESTE", "AZLE", "00", 0);

const prologue_a_1_bg_tiles align(4) = @embedFile("prologue_a_1_bg_tiles.bin").*;
const prologue_a_1_bg_map align(4) = @embedFile("prologue_a_1_bg_map.bin").*;
const prologue_a_1_bg_palette align(4) = @embedFile("prologue_a_1_bg_palette.bin").*;
const prologue_a_2_bg_tiles align(4) = @embedFile("prologue_a_2_bg_tiles.bin").*;
const prologue_a_2_bg_map align(4) = @embedFile("prologue_a_2_bg_map.bin").*;
const prologue_a_2_bg_palette align(4) = @embedFile("prologue_a_2_bg_palette.bin").*;
const prologue_a_1_collision align(4) = @embedFile("prologue_a_1_collision.bin").*;
const prologue_a_2_collision align(4) = @embedFile("prologue_a_2_collision.bin").*;
const player_tiles_data align(4) = @embedFile("player_idle_tiles.bin").*;
const player_palette_data align(4) = @embedFile("player_palette.bin").*;

const bg_screenblock: u5 = 28;
const room_width_tiles = 30;
const room_height_tiles = 20;
const room_width_pixels = room_width_tiles * 8;
const room_height_pixels = room_height_tiles * 8;
const room_scroll_y = 0;

const player_body_width = 8;
const player_body_height = 16;
const player_draw_offset_x = -4;
const player_start_x = 24;
const player_start_y = 128;
const player_speed = 1;
const player_gravity = 1;
const player_max_fall = 4;
const player_jump_speed = -7;

const RoomBackground = struct {
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
    collision: []align(4) const u8,
};

const rooms = [_]RoomBackground{
    .{
        .tiles = &prologue_a_1_bg_tiles,
        .map = &prologue_a_1_bg_map,
        .palette = &prologue_a_1_bg_palette,
        .collision = &prologue_a_1_collision,
    },
    .{
        .tiles = &prologue_a_2_bg_tiles,
        .map = &prologue_a_2_bg_map,
        .palette = &prologue_a_2_bg_palette,
        .collision = &prologue_a_2_collision,
    },
};

const Player = struct {
    x: i16,
    y: i16,
    vy: i16 = 0,
    grounded: bool = false,
    facing_left: bool = false,
};

pub export fn main() void {
    var room_index: usize = 0;
    loadRoomBackground(room_index);
    loadPlayerSprite();
    gba.display.hideAllObjects();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 1,
        .base_screenblock = bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, room_scroll_y),
    });

    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .obj = true,
    });

    var input: gba.input.BufferedKeysState = .{};
    var player = Player{
        .x = player_start_x,
        .y = player_start_y,
    };
    drawPlayer(player);

    while (true) {
        gba.display.naiveVSync();
        input.poll();
        updatePlayer(&player, input, room_index);
        if (trySwitchRoom(&player, input, &room_index)) {
            loadRoomBackground(room_index);
        }
        drawPlayer(player);
    }
}

fn loadRoomBackground(room_index: usize) void {
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
    gba.mem.memcpy16(&gba.display.screenblocks[bg_screenblock], @ptrCast(room.map.ptr), room.map.len / 2);
    gba.display.bg_scroll[0] = .init(0, room_scroll_y);
}

fn loadPlayerSprite() void {
    gba.mem.memcpy(gba.display.obj_palette, &player_palette_data, player_palette_data.len);
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(&player_tiles_data));
}

fn updatePlayer(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    const horizontal: i16 = @intCast(input.getAxisHorizontal());
    if (horizontal != 0) {
        player.facing_left = horizontal < 0;
    }
    moveHorizontal(player, horizontal * player_speed, room_index);

    if ((input.isJustPressed(.A) or input.isJustPressed(.B)) and player.grounded) {
        player.vy = player_jump_speed;
        player.grounded = false;
    }

    player.vy += player_gravity;
    if (player.vy > player_max_fall) {
        player.vy = player_max_fall;
    }

    player.grounded = false;
    moveVertical(player, player.vy, room_index);
}

fn trySwitchRoom(player: *Player, input: gba.input.BufferedKeysState, room_index: *usize) bool {
    if (input.isPressed(.right) and player.x >= room_width_pixels - player_body_width) {
        if (room_index.* + 1 < rooms.len) {
            room_index.* += 1;
            player.x = 1;
            player.y = player_start_y;
            player.vy = 0;
            player.grounded = false;
            return true;
        }
    }
    if (input.isPressed(.left) and player.x <= 0) {
        if (room_index.* > 0) {
            room_index.* -= 1;
            player.x = room_width_pixels - player_body_width - 1;
            player.y = player_start_y;
            player.vy = 0;
            player.grounded = false;
            return true;
        }
    }
    return false;
}

fn drawPlayer(player: Player) void {
    const draw_x = player.x + player_draw_offset_x;
    const draw_y = player.y - room_scroll_y;
    gba.display.objects[0] = gba.display.Object.init(.{
        .size = .size_16x16,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = 0,
        .priority = 0,
        .palette = 0,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn moveHorizontal(player: *Player, amount: i16, room_index: usize) void {
    if (amount == 0) return;
    const step: i16 = if (amount < 0) -1 else 1;
    var remaining: i16 = if (amount < 0) -amount else amount;
    while (remaining > 0) : (remaining -= 1) {
        if (collidesAt(player.x + step, player.y, room_index)) break;
        player.x += step;
    }
}

fn moveVertical(player: *Player, amount: i16, room_index: usize) void {
    if (amount == 0) return;
    const step: i16 = if (amount < 0) -1 else 1;
    var remaining: i16 = if (amount < 0) -amount else amount;
    while (remaining > 0) : (remaining -= 1) {
        if (collidesAt(player.x, player.y + step, room_index)) {
            player.vy = 0;
            player.grounded = step > 0;
            break;
        }
        player.y += step;
    }
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
    if (x < 0 or x >= room_width_pixels or y >= room_height_pixels) return true;
    if (y < 0) return false;
    const tile_x: usize = @intCast(@divTrunc(x, 8));
    const tile_y: usize = @intCast(@divTrunc(y, 8));
    return rooms[room_index].collision[tile_y * room_width_tiles + tile_x] != 0;
}

fn objX(x: i16) u9 {
    if (x < 0) return 0;
    if (x > 511) return 511;
    return @intCast(x);
}

fn objY(y: i16) u8 {
    if (y < 0) return 0;
    if (y > 255) return 255;
    return @intCast(y);
}
