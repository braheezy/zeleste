const gba = @import("gba");
const assets = @import("../../core/assets.zig");
const camera_mod = @import("../../world/camera.zig");
const cutscene_dialogue = @import("../../cutscene/dialogue.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const oam = @import("../../core/oam.zig");
const room_data = @import("../../world/room_data.zig");

const Camera = camera_mod.Camera;
const GrannyCutscene = room_data.GrannyCutscene;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const tiles_data align(4) = assets.granny_haha_tiles_data;

pub const first_object = 93;
pub const object_count = 3;
pub const base_tile: u10 = 400;
pub const pause_frames: u8 = 112;

const haha_frame_count: u8 = 9;
const tiles_per_frame: u10 = 4;
const flash_frame_hold_frames: u8 = 8;
const flash_cycles: u8 = 4;
const tail_frame_hold_frames: u8 = 8;
const flash_life_frames: u8 = flash_frame_hold_frames * flash_cycles * 2;
const life_frames: u8 = flash_life_frames + (haha_frame_count - 2) * tail_frame_hold_frames;
const emit_every_frames: u8 = 36;
const vx: i32 = 0x58;
const vy: i32 = -0x12;
const ay: i32 = 0;
const rooms = level.rooms;

const Particle = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    ay: i32 = 0,
    age: u8 = 0,
    seed: u8 = 0,
};

const State = struct {
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
    particles: [object_count]Particle = [_]Particle{.{}} ** object_count,
};

var state: State = .{};
var visible: bool = false;
var tiles_loaded: bool = false;

pub fn startFromCutscene(cutscene: *const GrannyCutscene, source_room_index: usize, emit_total: u8, follow_camera: bool, continuous: bool) void {
    const room = rooms[source_room_index];
    state = .{
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
        .particles = [_]Particle{.{}} ** object_count,
    };
    loadTiles();
    spawnInitialParticles();
}

pub fn update(room_index: usize, camera: Camera) void {
    if (!state.active) return;
    if (state.follow_camera and state.room_index != room_index) {
        retargetToView(room_index, camera);
    }
    state.timer +%= 1;

    var any_active = false;
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        var particle = &state.particles[index];
        if (!particle.active) continue;
        any_active = true;
        particle.age += 1;
        particle.vy += particle.ay;
        particle.x += particle.vx;
        particle.y += particle.vy;
        if (particle.age >= life_frames) {
            particle.active = false;
        }
    }

    if ((state.continuous or state.emitted < state.emit_total) and state.timer % emit_every_frames == 0) {
        spawnParticle();
    }

    if (!state.continuous and !any_active and state.emitted >= state.emit_total) {
        state.active = false;
        hideObjects();
    }
}

pub fn draw(camera: Camera, room_index: usize) void {
    if (!state.active) {
        hideObjects();
        return;
    }
    loadTiles();
    const room = rooms[room_index];
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        const particle = state.particles[index];
        if (!particle.active) {
            hideObject(first_object + index);
            continue;
        }
        const screen_x = fixedToPixel(particle.x) - (room.world_x + camera.x);
        const screen_y = fixedToPixel(particle.y) + wave(particle.age, particle.seed) - (room.world_y + camera.y);
        const frame = frameForAge(particle.age);
        gba.display.objects[first_object + index] = gba.display.Object.init(.{
            .size = .size_16x16,
            .x = objX(screen_x),
            .y = objY(screen_y),
            .base_tile = base_tile + @as(u10, @intCast(frame)) * tiles_per_frame,
            .priority = 0,
            .palette = cutscene_dialogue.palette_bank,
        });
    }
    visible = true;
}

pub fn stop() void {
    state = .{};
    hideObjects();
}

pub fn active() bool {
    return state.active;
}

pub fn activeInRoom(room_index: usize) bool {
    return state.active and state.room_index == room_index;
}

pub fn invalidateTiles() void {
    tiles_loaded = false;
}

fn retargetToView(room_index: usize, camera: Camera) void {
    const room = rooms[room_index];
    state.room_index = room_index;
    state.start_x = room.world_x + camera.x + 4;
    state.start_y = room.world_y + camera.y + 28;
    state.end_x = state.start_x + 96;
    state.end_y = state.start_y - 12;
    state.timer = 0;
    state.emitted = 0;
    state.emit_total = 0;
    state.particles = [_]Particle{.{}} ** object_count;
    loadTiles();
    spawnInitialParticles();
}

fn spawnInitialParticles() void {
    if (state.continuous or state.emitted < state.emit_total) {
        spawnParticle();
    }
}

fn spawnParticle() void {
    const slot = firstFreeParticle() orelse return;
    const seed = state.emitted;
    state.particles[slot] = .{
        .active = true,
        .x = pixelToFixed(state.start_x),
        .y = pixelToFixed(state.start_y),
        .vx = vx + @as(i32, @intCast(seed % 3)) * 0x08,
        .vy = vy - @as(i32, @intCast((seed + 1) % 3)) * 0x04,
        .ay = ay,
        .age = 0,
        .seed = seed,
    };
    state.emitted += 1;
}

fn firstFreeParticle() ?usize {
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        if (!state.particles[index].active) return index;
    }
    return null;
}

fn loadTiles() void {
    if (tiles_loaded) return;
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
    tiles_loaded = true;
}

fn frameForAge(age: u8) u8 {
    if (age < flash_life_frames) {
        return @intCast((age / flash_frame_hold_frames) & 1);
    }
    const tail_age = age - flash_life_frames;
    return @min(@as(u8, haha_frame_count - 1), 2 + tail_age / tail_frame_hold_frames);
}

fn wave(age: u8, seed: u8) i16 {
    const values = [_]i16{
        0,  -1, -2, -3, -4, -4, -3, -2,
        -1, 0,  1,  2,  3,  3,  2,  1,
        0,  -1, -2, -2, -1, 0,  1,  1,
    };
    const phase: usize = @intCast((@divTrunc(@as(u16, age), 3) + @as(u16, seed) * 5) % values.len);
    return values[phase];
}

fn hideObjects() void {
    if (!visible) return;
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        hideObject(first_object + index);
    }
    visible = false;
}
