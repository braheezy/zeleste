const gba = @import("gba");
const camera_mod = @import("../world/camera.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const obj_oam = @import("../core/obj_oam.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const video = @import("../core/video.zig");

const Camera = camera_mod.Camera;
const fixedToPixel = math.fixedToPixel;
const fixed_one = math.fixed_one;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

pub const base_tile: u10 = @intCast(obj_vram.wind_snow.start);
const object_range = obj_oam.wind_snow;
pub const first_object = object_range.baseSlot();
pub const palette_bank: u4 = 3;

// Slots 64..70 are reserved for springs; keep wind/snow in 43..63.
const max_particles = 21;
const limited_particles = 16;
const tile_count = 8;
const snow_color: u4 = 15;
const rooms = level.rooms;

const Particle = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    speed: i32 = 0,
    drift: i16 = 0,
    tile: u8 = 0,
    life: u8 = 0,
};

var visible: bool = false;
var particle_count: usize = 0;
var particles: [max_particles]Particle = [_]Particle{.{}} ** max_particles;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;

pub fn loadPalette() void {
    const base = @as(usize, palette_bank) * 16;
    gba.display.obj_palette.colors[base + 0] = .black;
    gba.display.obj_palette.colors[base + 1] = .white;
    gba.display.obj_palette.colors[base + snow_color] = .white;
}

pub fn loadTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
    setPixel(0, 3, 3, snow_color);

    setPixel(1, 2, 4, snow_color);

    setPixel(2, 4, 2, snow_color);

    setPixel(3, 2, 2, snow_color);
    setPixel(3, 3, 2, snow_color);

    setPixel(4, 3, 3, snow_color);
    setPixel(4, 4, 3, snow_color);

    setPixel(5, 2, 4, snow_color);
    setPixel(5, 3, 3, snow_color);

    setPixel(6, 4, 2, snow_color);
    setPixel(6, 3, 3, snow_color);

    setPixel(7, 1, 4, snow_color);
    setPixel(7, 3, 4, snow_color);

    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
    loadPalette();
}

pub fn reset(room_index: usize, camera: Camera, suppressed: bool, limited: bool) void {
    particles = [_]Particle{.{}} ** max_particles;
    if (suppressed or rooms[room_index].wind_snow_strength == 0) {
        hideObjects();
        visible = false;
        particle_count = 0;
        return;
    }

    visible = true;
    const limit = particleLimit(limited);
    hideObjectsPastLimit(limit);
    particle_count = limit;
    var index: usize = 0;
    while (index < limit) : (index += 1) {
        particles[index] = newParticle(room_index, camera, index, true, limited);
    }
}

pub fn update(room_index: usize, camera: Camera, anim_counter: u16, suppressed: bool, limited: bool) void {
    const room = rooms[room_index];
    if (suppressed or room.wind_snow_strength == 0) {
        if (visible) {
            hideObjects();
        }
        visible = false;
        particle_count = 0;
        return;
    }

    visible = true;
    const limit = particleLimit(limited);
    hideObjectsPastLimit(limit);
    particle_count = limit;
    var index: usize = 0;
    while (index < limit) : (index += 1) {
        if (!particles[index].active) {
            particles[index] = newParticle(room_index, camera, index, false, limited);
            continue;
        }

        const dir: i16 = if (room.wind_snow_dir_x < 0) -1 else 1;
        particles[index].x += @as(i32, dir) * particles[index].speed;
        if ((anim_counter & 7) == 0) {
            particles[index].y += @as(i32, particles[index].drift) * fixed_one;
        }
        const left_bound = camera.x - 20;
        const right_bound = camera.x + video.screen_width + 20;
        const top_bound = camera.y - 20;
        const bottom_bound = camera.y + video.screen_height + 20;
        const world_x = fixedToPixel(particles[index].x);
        const world_y = fixedToPixel(particles[index].y);
        if (world_x < left_bound or world_x > right_bound or
            world_y < top_bound or world_y > bottom_bound)
        {
            particles[index] = newParticle(room_index, camera, index, false, limited);
        }
    }
}

pub fn draw(camera: Camera) void {
    if (!visible) return;

    loadPalette();
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);

    var index: usize = 0;
    while (index < particle_count) : (index += 1) {
        if (!particles[index].active) {
            object_range.object(index).mode = .hidden;
            continue;
        }
        const screen_x = fixedToPixel(particles[index].x) - camera.x;
        const screen_y = fixedToPixel(particles[index].y) - camera.y;
        object_range.object(index).* = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(screen_x),
            .y = objY(screen_y),
            .base_tile = base_tile + @as(u10, @intCast(particles[index].tile)),
            .priority = 1,
            .palette = palette_bank,
        });
    }
}

pub fn hideObjects() void {
    particle_count = 0;
    object_range.hide();
}

fn hideObjectsPastLimit(limit: usize) void {
    if (limit >= particle_count) return;
    var index = limit;
    while (index < particle_count) : (index += 1) {
        object_range.object(index).mode = .hidden;
    }
}

fn particleLimit(limited: bool) usize {
    return if (limited) limited_particles else max_particles;
}

fn newParticle(room_index: usize, camera: Camera, index: usize, fill_screen: bool, limited: bool) Particle {
    const room = rooms[room_index];
    const strength = @max(@as(u8, 1), room.wind_snow_strength);
    const dir: i16 = if (room.wind_snow_dir_x < 0) -1 else 1;
    const spawn_left = camera.x - 12;
    const spawn_right = camera.x + video.screen_width + 12;
    const x = if (fill_screen)
        camera.x + @as(i16, @intCast(hashIndex(index, 11) % (video.screen_width + 32))) - 16
    else if (dir < 0)
        spawn_right
    else
        spawn_left;
    const y = pickY(room_index, camera, index, x, limited);
    return .{
        .active = true,
        .x = pixelToFixed(x),
        .y = pixelToFixed(y),
        .speed = fixed_one + fixed_one / 2 + @as(i32, @intCast(strength - 1)) * (fixed_one / 2),
        .drift = @as(i16, @intCast((index / 3) % 3)) - 1,
        .tile = @as(u8, @intCast(index % tile_count)),
        .life = 255,
    };
}

fn pickY(room_index: usize, camera: Camera, index: usize, x: i16, limited: bool) i16 {
    _ = room_index;
    _ = x;
    const min_y = camera.y + 4;
    const max_y = camera.y + video.screen_height - 18;
    const span: usize = @intCast(max_y - min_y);
    const lane_count = particleLimit(limited);
    if (span <= 1) return min_y;
    if (index < lane_count and particles[index].active == false) {
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

fn setPixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const pixel_index: u8 = @intCast(y * 8 + x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}
