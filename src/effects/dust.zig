const gba = @import("gba");
const camera_mod = @import("../world/camera.zig");
const math = @import("../core/math.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const rng = @import("../core/rng.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const nextRandom = rng.next;

pub const base_tile: u10 = 68;
pub const palette_bank: u4 = 3;
pub const first_object = 35;
pub const max_particles = 8;

const Particle = struct {
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
    break_smoke: bool = false,
};

var particles: [max_particles]Particle = [_]Particle{.{}} ** max_particles;
var tiles: [max_particles]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** max_particles;
var last_drawn_slots: usize = 0;

pub fn loadPalette() void {
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 0] = .black;
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 1] = .white;
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 2] = gba.ColorRgb555.rgb(17, 27, 31);
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 3] = gba.ColorRgb555.rgb(29, 4, 4);
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 4] = gba.ColorRgb555.rgb(17, 2, 3);
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 5] = .black;
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 6] = gba.ColorRgb555.rgb(6, 7, 10);
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 7] = gba.ColorRgb555.rgb(15, 21, 31);
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 8] = gba.ColorRgb555.rgb(31, 24, 9);
}

pub fn spawnJumpAtFeet(player: Player) void {
    spawnAtFeet(player, false);
}

pub fn spawnLandingAtFeet(player: Player) void {
    spawnAtFeet(player, true);
}

pub fn spawnWallSlide(player: Player, wall_dir: i16) void {
    const slot = nextParticleIndex();
    const body_x = fixedToPixel(player.x);
    const body_y = fixedToPixel(player.y);
    const contact_x = body_x + if (wall_dir < 0) @as(i16, -1) else @as(i16, player_mod.body_width + 1);
    const lag_y = body_y + 4 + @as(i16, @intCast(nextRandom() % 4));
    const push_away = -@as(i32, wall_dir) * (0x10 + @as(i32, @intCast(nextRandom() % 0x18)));
    const life = 14 + @as(u8, @intCast(nextRandom() % 8));
    particles[slot] = .{
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

pub fn spawnSnowFromBlock(x: i16, y: i32, w: u8) void {
    const base_y = fixedToPixel(y) + 2;
    const width: u16 = @max(@as(u16, w), 1);
    const count: u8 = 7;
    var index: u8 = 0;
    while (index < count) : (index += 1) {
        const slot = nextParticleIndex();
        const x_offset: i16 = @intCast((nextRandom() + @as(u16, index) * 9) % width);
        const side: i32 = if ((nextRandom() & 1) == 0) -1 else 1;
        const drift: i32 = 0x04 + @as(i32, @intCast(nextRandom() % 0x14));
        const drop: i32 = 0x34 + @as(i32, @intCast(nextRandom() % 0x48));
        const life: u8 = 28 + @as(u8, @intCast(nextRandom() % 17));
        particles[slot] = .{
            .active = true,
            .x = pixelToFixed(x + x_offset),
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

pub fn spawnBreakableWallSmoke(x: i16, y: i16, w: u8, h: u8) void {
    const center_x = x + @as(i16, @intCast(@divTrunc(@as(u16, w), 2)));
    const center_y = y + @as(i16, @intCast(@divTrunc(@as(u16, h), 2)));
    const count: u8 = max_particles;
    var index: u8 = 0;
    while (index < count) : (index += 1) {
        const slot = nextParticleIndex();
        const rx: i16 = @intCast(nextRandom() % @as(u16, @max(w, 1)));
        const ry: i16 = @intCast(nextRandom() % @as(u16, @max(h, 1)));
        const spawn_x = x + rx;
        const spawn_y = y + ry;
        const drift_x = @as(i32, spawn_x - center_x) * 0x08 + (@as(i32, @intCast(nextRandom() % 0x21)) - 0x10);
        const drift_y = @as(i32, spawn_y - center_y) * 0x06 - (0x18 + @as(i32, @intCast(nextRandom() % 0x18)));
        const life: u8 = 18 + @as(u8, @intCast(nextRandom() % 9));
        particles[slot] = .{
            .active = true,
            .x = pixelToFixed(spawn_x),
            .y = pixelToFixed(spawn_y),
            .vx = drift_x,
            .vy = drift_y,
            .life = life,
            .max_life = life,
            .shape = @intCast((nextRandom() + index) % 4),
            .break_smoke = true,
        };
    }
}

pub fn update() void {
    var index: usize = 0;
    while (index < max_particles) : (index += 1) {
        if (!particles[index].active) continue;
        if (particles[index].life == 0) {
            particles[index].active = false;
            continue;
        }
        particles[index].life -= 1;
        particles[index].x += particles[index].vx;
        particles[index].y += particles[index].vy;
        particles[index].vx = @divTrunc(particles[index].vx * 7, 8);
        particles[index].vy += if (particles[index].break_smoke) 0x01 else if (particles[index].snow) 0x03 else 0x08;
        if (particles[index].life == 0) {
            particles[index].active = false;
        }
    }
}

pub fn clear() void {
    particles = [_]Particle{.{}} ** max_particles;
    var index: usize = 0;
    while (index < max_particles) : (index += 1) {
        hideObject(first_object + index);
    }
    last_drawn_slots = 0;
}

pub fn draw(camera: Camera) void {
    if (!hasActiveParticles() and last_drawn_slots == 0) return;

    var index: usize = 0;
    var highest_active: usize = 0;
    while (index < max_particles) : (index += 1) {
        if (!particles[index].active) {
            if (index < last_drawn_slots) hideObject(first_object + index);
            continue;
        }

        highest_active = index + 1;
        clearTile(index);
        drawShape(index, particles[index]);
        const draw_x = fixedToPixel(particles[index].x) - camera.x - 4;
        const draw_y = fixedToPixel(particles[index].y) - camera.y - 4;
        gba.display.objects[first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(draw_x),
            .y = objY(draw_y),
            .base_tile = base_tile + @as(u10, @intCast(index)),
            .priority = 0,
            .palette = palette_bank,
        });
    }
    if (highest_active != 0) {
        gba.display.memcpyObjectTiles4Bpp(base_tile, tiles[0..highest_active]);
    }
    last_drawn_slots = highest_active;
}

fn hasActiveParticles() bool {
    var index: usize = 0;
    while (index < max_particles) : (index += 1) {
        if (particles[index].active) return true;
    }
    return false;
}

fn spawnAtFeet(player: Player, landing: bool) void {
    const base_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const base_y = fixedToPixel(player.y) + player_mod.body_height - 2;
    const count: u8 = if (landing) 3 + @as(u8, @intCast(nextRandom() % 2)) else 2 + @as(u8, @intCast(nextRandom() % 3));
    var index: u8 = 0;
    while (index < count) : (index += 1) {
        const slot = nextParticleIndex();
        const side: i32 = if (((nextRandom() + index) & 1) == 0) -1 else 1;
        const x_jitter: i16 = if (landing) @intCast(nextRandom() % 9) else @intCast(nextRandom() % 5);
        const speed: i32 = if (landing) 0x40 + @as(i32, @intCast(nextRandom() % 0x48)) else 0x28 + @as(i32, @intCast(nextRandom() % 0x38));
        const rise: i32 = if (landing) 0x08 + @as(i32, @intCast(nextRandom() % 0x18)) else 0x18 + @as(i32, @intCast(nextRandom() % 0x28));
        const life: u8 = if (landing) 16 + @as(u8, @intCast(nextRandom() % 9)) else 12 + @as(u8, @intCast(nextRandom() % 9));
        const x_offset: i16 = if (landing) 4 else 2;
        particles[slot] = .{
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

fn nextParticleIndex() usize {
    var index: usize = 0;
    while (index < max_particles) : (index += 1) {
        if (!particles[index].active) return index;
    }

    var weakest: usize = 0;
    index = 0;
    while (index < max_particles) : (index += 1) {
        if (particles[index].life < particles[weakest].life) weakest = index;
    }
    return weakest;
}

fn clearTile(tile_index: usize) void {
    var byte_index: usize = 0;
    while (byte_index < 32) : (byte_index += 1) {
        tiles[tile_index].data_8[byte_index] = 0;
    }
}

fn drawShape(tile_index: usize, particle: Particle) void {
    const age = particle.max_life - particle.life;
    if (particle.break_smoke) {
        const center_x: i16 = 3 + @as(i16, @intCast(particle.shape & 1));
        const center_y: i16 = 3 + @as(i16, @intCast((particle.shape >> 1) & 1));
        const shrink = particle.life < particle.max_life / 3;
        const color: u4 = if (particle.life > particle.max_life / 2) 6 else 7;
        drawDiscColor(tile_index, center_x, center_y, if (shrink) 2 else 3, color);
        if (!shrink and age > 2) {
            drawDiscColor(tile_index, center_x - 2, center_y + 1, 2, color);
            drawDiscColor(tile_index, center_x + 2, center_y - 1, 1, color);
        }
        return;
    }
    if (particle.snow) {
        const center_x: i16 = 2 + @as(i16, @intCast((particle.shape & 1) * 3));
        const center_y: i16 = 2 + @as(i16, @intCast((particle.shape >> 1) & 3));
        if (particle.life > particle.max_life / 2) {
            setTilePixel(tile_index, center_x, center_y - 1, 1);
            setTilePixel(tile_index, center_x - 1, center_y, 1);
            setTilePixel(tile_index, center_x, center_y, 1);
            setTilePixel(tile_index, center_x + 1, center_y, 1);
        } else {
            setTilePixel(tile_index, center_x, center_y, 1);
            setTilePixel(tile_index, center_x, center_y + 1, 1);
        }
        if (age > 7 and particle.life > particle.max_life / 3) {
            setTilePixel(tile_index, center_x - 1, center_y + 1, 1);
            setTilePixel(tile_index, center_x + 1, center_y + 1, 1);
        }
        return;
    }
    if (particle.wall) {
        const center_x: i16 = 3 + @as(i16, @intCast(particle.shape & 1));
        const center_y: i16 = 3 + @as(i16, @intCast((particle.shape >> 1) & 1));
        const shrink = particle.life < particle.max_life / 3;
        drawDisc(tile_index, center_x, center_y, if (shrink) 1 else 2);
        if (!shrink and age > 3) {
            drawDisc(tile_index, center_x - 1, center_y + 2, 1);
        }
        return;
    }
    const shrink = particle.life < particle.max_life / 3;
    const center_x: i16 = 3 + @as(i16, @intCast(particle.shape & 1));
    const center_y: i16 = if (particle.landing) 5 else 4 - @as(i16, @intCast((particle.shape >> 1) & 1));
    const radius: u8 = if (shrink) 1 else 2;
    drawDisc(tile_index, center_x, center_y, radius);
    if (particle.landing and !shrink) {
        drawDisc(tile_index, center_x - 2, center_y + 1, 1);
        drawDisc(tile_index, center_x + 2, center_y + 1, 1);
        if (age > 5) {
            drawDisc(tile_index, center_x, center_y - 2, 1);
        }
        return;
    }
    if (!shrink and age > 4) {
        const side: i16 = if ((particle.shape & 1) == 0) -2 else 2;
        drawDisc(tile_index, center_x + side, center_y + 1, 1);
    }
}

fn drawDisc(tile_index: usize, center_x: i16, center_y: i16, radius: u8) void {
    drawDiscColor(tile_index, center_x, center_y, radius, 1);
}

fn drawDiscColor(tile_index: usize, center_x: i16, center_y: i16, radius: u8, color: u4) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setTilePixel(tile_index, center_x + x, center_y + y, color);
            }
        }
    }
}

fn setTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const pixel_index: u8 = @intCast(y * 8 + x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}
