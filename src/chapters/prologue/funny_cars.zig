const gba = @import("gba");
const assets = @import("../../core/assets.zig");
const camera_mod = @import("../../world/camera.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const oam = @import("../../core/oam.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const tiles_data align(4) = assets.funny_car_tiles_data;
const palette_data align(4) = assets.funny_car_palette_data;

pub const base_tile: u10 = 560;
pub const palette_bank: u4 = 10;
pub const object_count = 2;

const width = 47;
const max_cars = 2;
const top = [_]i8{ 7, 6, 5, 4, 3, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 4, 5, 6, 0, 7, 7, 7, 7, 7, 7, 7, 7, 8 };

const rooms = level.rooms;

const Car = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    pressed: bool = false,
};

var cars: [max_cars]Car = [_]Car{.{}} ** max_cars;
var car_count: usize = 0;

pub fn loadGraphics() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
}

pub fn load(room_index: usize, first_object: usize) void {
    cars = [_]Car{.{}} ** max_cars;
    car_count = 0;
    hideObjects(first_object);

    const data = rooms[room_index].generic_stamps;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_cars);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + 8 <= data.len) : ({
        source_index += 1;
        source_offset += 8;
    }) {
        const kind = data[source_offset + 7];
        if (kind != 0) continue;
        cars[car_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
        };
        car_count += 1;
        if (car_count >= max_cars) break;
    }
}

pub fn update(player: Player) void {
    var index: usize = 0;
    while (index < car_count) : (index += 1) {
        const car = &cars[index];
        if (!car.active or !car.pressed) continue;
        if (!playerFeetTouch(player, car.*)) {
            car.pressed = false;
        }
    }
}

pub fn triggerBounceAtPlayer(player: Player) void {
    var index: usize = 0;
    while (index < car_count) : (index += 1) {
        const car = &cars[index];
        if (!car.active) continue;
        if (playerFeetTouch(player, car.*)) {
            car.pressed = true;
        }
    }
}

pub fn releaseAtPlayer(player: Player) void {
    var index: usize = 0;
    while (index < car_count) : (index += 1) {
        const car = &cars[index];
        if (!car.active) continue;
        if (playerFeetTouch(player, car.*)) {
            car.pressed = false;
        }
    }
}

pub fn draw(camera: Camera, first_object: usize) void {
    var index: usize = 0;
    while (index < max_cars) : (index += 1) {
        if (index >= car_count or !cars[index].active) {
            hideCar(first_object, index);
            continue;
        }
        const car = cars[index];
        const bounce_y: i16 = if (car.pressed) 1 else 0;
        const object_index = first_object + index * object_count;
        drawChunk(object_index, car.x - camera.x, car.y + bounce_y - camera.y, base_tile, .size_32x16);
        drawChunk(object_index + 1, car.x + 32 - camera.x, car.y + bounce_y - camera.y, base_tile + 8, .size_16x16);
    }
}

pub fn hideObjects(first_object: usize) void {
    var index: usize = 0;
    while (index < max_cars) : (index += 1) {
        hideCar(first_object, index);
    }
}

pub fn topForPlayer(player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    const left = topAtBottom(player_x, old_bottom, next_bottom);
    const right = topAtBottom(player_x + player_mod.body_width - 1, old_bottom, next_bottom);
    if (left) |left_top| {
        if (right) |right_top| {
            return @min(left_top, right_top);
        }
        return left_top;
    }
    return right;
}

pub fn floorAt(player_x: i16, player_y: i16) bool {
    const player_bottom = player_y + player_mod.body_height;
    return bottomTouchesAt(player_x, player_bottom, null) or
        bottomTouchesAt(player_x + player_mod.body_width - 1, player_bottom, null);
}

fn playerFeetTouch(player: Player, car: Car) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    return bottomNearBaseAt(player_left, player_bottom, car) or
        bottomNearBaseAt(player_right, player_bottom, car);
}

fn topAtBottom(x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    var index: usize = 0;
    while (index < car_count) : (index += 1) {
        const car = cars[index];
        if (!car.active) continue;
        if (surfaceYAt(car, x)) |surface_y| {
            if (old_bottom <= surface_y and next_bottom >= surface_y and next_bottom < surface_y + 4) {
                return surface_y;
            }
        }
    }
    return null;
}

fn bottomTouchesAt(x: i16, bottom_y: i16, maybe_car: ?Car) bool {
    if (maybe_car) |car| {
        if (surfaceYAt(car, x)) |surface_y| {
            return bottom_y >= surface_y and bottom_y < surface_y + 4;
        }
        return false;
    }
    var index: usize = 0;
    while (index < car_count) : (index += 1) {
        const car = cars[index];
        if (!car.active) continue;
        if (bottomTouchesAt(x, bottom_y, car)) return true;
    }
    return false;
}

fn surfaceYAt(car: Car, x: i16) ?i16 {
    const surface_y = baseSurfaceYAt(car, x) orelse return null;
    const pressed_offset: i16 = if (car.pressed) 1 else 0;
    return surface_y + pressed_offset;
}

fn baseSurfaceYAt(car: Car, x: i16) ?i16 {
    if (x < car.x or x >= car.x + width) return null;
    const local_x: usize = @intCast(x - car.x);
    return car.y + @as(i16, top[local_x]);
}

fn bottomNearBaseAt(x: i16, bottom_y: i16, car: Car) bool {
    if (baseSurfaceYAt(car, x)) |surface_y| {
        return bottom_y >= surface_y - 1 and bottom_y < surface_y + 5;
    }
    return false;
}

fn drawChunk(object_index: usize, x: i16, y: i16, tile: u10, size: gba.display.Object.Size) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = tile,
        .priority = 1,
        .palette = palette_bank,
    });
}

fn hideCar(first_object: usize, index: usize) void {
    var part: usize = 0;
    while (part < object_count) : (part += 1) {
        hideObject(first_object + index * object_count + part);
    }
}
