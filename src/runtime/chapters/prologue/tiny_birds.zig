const gba = @import("gba");
const assets = @import("../../assets.zig");
const camera_mod = @import("../../camera.zig");
const foreground_stamps = @import("../../foreground_stamps.zig");
const level = @import("../../../generated_rooms.zig");
const math = @import("../../math.zig");
const oam = @import("../../oam.zig");
const player_mod = @import("../../player.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const absI16 = math.absI16;
const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const tiles_data align(4) = assets.tiny_bird_tiles_data;
const palette_data align(4) = assets.tiny_bird_palette_data;

pub const first_object = foreground_stamps.behind_first_object + foreground_stamps.max_stamps;
pub const base_tile: u10 = 896;
pub const palette_bank: u4 = 8;

const max_birds = 5;
const frame_count: u8 = 2;
const tiles_per_variant = frame_count;
const trigger_distance_x: i16 = 76;
const trigger_distance_y: i16 = 64;
const rooms = level.rooms;
const flock_room_index = level.roomIndexFor(level.chapter_index, "0b") orelse rooms.len;

const Bird = struct {
    active: bool = false,
    flying: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    variant: u8 = 0,
    phase: u8 = 0,
};

var birds: [max_birds]Bird = [_]Bird{.{}} ** max_birds;
var bird_count: usize = 0;
var flock_triggered: bool = false;
var flown: [rooms.len]bool = [_]bool{false} ** rooms.len;

pub fn load(room_index: usize) void {
    birds = [_]Bird{.{}} ** max_birds;
    bird_count = 0;
    flock_triggered = false;
    hideObjects();

    if (room_index != flock_room_index or flown[room_index]) return;

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

    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));

    var index: usize = 0;
    while (index < starts.len and index < max_birds) : (index += 1) {
        birds[index] = .{
            .active = true,
            .x = pixelToFixed(starts[index].x),
            .y = pixelToFixed(starts[index].y),
            .vx = starts[index].vx,
            .vy = starts[index].vy,
            .variant = starts[index].variant,
            .phase = @intCast(index * 5),
        };
        bird_count += 1;
    }
}

pub fn update(player: Player, room_index: usize, anim_counter: u16) void {
    if (room_index != flock_room_index or bird_count == 0) return;

    if (!flock_triggered and playerNearFlock(player)) {
        flock_triggered = true;
        var trigger_index: usize = 0;
        while (trigger_index < bird_count) : (trigger_index += 1) {
            birds[trigger_index].flying = true;
        }
    }

    var any_active = false;
    var index: usize = 0;
    while (index < bird_count) : (index += 1) {
        var bird = &birds[index];
        if (!bird.active) continue;
        any_active = true;
        if (!bird.flying) continue;

        bird.x += bird.vx;
        bird.y += bird.vy;
        if ((anim_counter & 7) == 0) {
            const drift: i32 = if (((anim_counter >> 3) + bird.phase) & 1 == 0) fixed_one / 4 else -fixed_one / 4;
            bird.x += drift;
        }
        if (fixedToPixel(bird.y) < -12) {
            bird.active = false;
            hideObject(first_object + index);
        }
    }

    if (flock_triggered and !any_active) {
        flown[room_index] = true;
        bird_count = 0;
        hideObjects();
    }
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (bird_count == 0) return;

    var index: usize = 0;
    while (index < max_birds) : (index += 1) {
        if (index >= bird_count or !birds[index].active) {
            hideObject(first_object + index);
            continue;
        }
        const bird = birds[index];
        const frame: u8 = if (bird.flying)
            @intCast((anim_counter / 4 + bird.phase) % frame_count)
        else
            @intCast((anim_counter / 28 + bird.phase) % frame_count);
        gba.display.objects[first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(fixedToPixel(bird.x) - camera.x),
            .y = objY(fixedToPixel(bird.y) - camera.y),
            .base_tile = base_tile + @as(u10, bird.variant) * tiles_per_variant + frame,
            .priority = 1,
            .palette = palette_bank,
        });
    }
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < max_birds) : (index += 1) {
        hideObject(first_object + index);
    }
}

fn playerNearFlock(player: Player) bool {
    const player_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const player_y = fixedToPixel(player.y) + player_mod.body_height / 2;
    var index: usize = 0;
    while (index < bird_count) : (index += 1) {
        const bird = birds[index];
        if (!bird.active) continue;
        const bird_x = fixedToPixel(bird.x) + 4;
        const bird_y = fixedToPixel(bird.y) + 4;
        if (absI16(player_x - bird_x) <= trigger_distance_x and
            absI16(player_y - bird_y) <= trigger_distance_y)
        {
            return true;
        }
    }
    return false;
}
