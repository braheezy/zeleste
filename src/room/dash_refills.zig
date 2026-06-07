const gba = @import("gba");

const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");
const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");
const strawberries = @import("strawberries.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const rooms = level.rooms;
const sound_ids = assets.sound_ids;
const tiles_data align(4) = assets.dash_refill_tiles_data;
const palette_data align(4) = assets.dash_refill_palette_data;
const meta = assets.dash_refill_meta;

const max_refills = 16;
const record_bytes = 8;
const respawn_frames: u8 = 150;
const sprite_size: i16 = 16;
const idle_frame_ticks: u16 = 6;
const flash_frame_ticks: u16 = 3;
const bob_frame_ticks: u16 = 8;
const base_tile: u10 = 720;
const palette_bank: u4 = 11;
const object_capacity = 8;
const first_object = strawberries.first_object + strawberries.object_capacity;
const screen_width = 240;
const screen_height = 160;
const shake_frames: u8 = 8;
const touch_volume: u16 = 768;
const return_volume: u16 = 576;

const Refill = struct {
    active: bool = false,
    center_x: i16 = 0,
    center_y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    cooldown: u8 = 0,
    sound_index: u8 = 0,
};

var refills: [max_refills]Refill = [_]Refill{.{}} ** max_refills;
var refill_count: usize = 0;
var last_drawn_objects: usize = 0;
var room_collect_count: u8 = 0;
var shake_timer: u8 = 0;

pub fn load(room_index: usize) void {
    refills = [_]Refill{.{}} ** max_refills;
    refill_count = 0;
    room_collect_count = 0;
    shake_timer = 0;
    hideObjects();

    const data = rooms[room_index].dash_refills;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_refills);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;
        refills[refill_count] = .{
            .active = true,
            .center_x = readI16Le(data, source_offset),
            .center_y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
        };
        refill_count += 1;
    }
}

pub fn loadGraphics() void {
    if (refill_count == 0) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
}

pub fn update(player: *Player) void {
    if (shake_timer > 0) {
        shake_timer -= 1;
    }

    var index: usize = 0;
    while (index < refill_count) : (index += 1) {
        const refill = &refills[index];
        if (!refill.active) continue;

        if (refill.cooldown > 0) {
            refill.cooldown -= 1;
            if (refill.cooldown == 0) {
                playReturnSound(refill.sound_index);
            }
            continue;
        }

        if (!playerTouchesRefill(player.*, refill.*)) continue;
        refillPlayer(player);
        refill.sound_index = nextSoundIndex();
        refill.cooldown = respawn_frames;
        shake_timer = shake_frames;
        playTouchSound(refill.sound_index);
        return;
    }
}

pub fn cameraShakeOffset() ?room_data.Spawn {
    if (shake_timer == 0) return null;
    return switch (shake_timer & 3) {
        0 => .{ .x = 1, .y = 0 },
        1 => .{ .x = -1, .y = 0 },
        2 => .{ .x = 0, .y = 1 },
        else => .{ .x = 0, .y = -1 },
    };
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (refill_count == 0 and last_drawn_objects == 0) return;

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < refill_count and object_offset < object_capacity) : (index += 1) {
        const refill = refills[index];
        if (!refill.active) continue;

        const x = refill.center_x - sprite_size / 2 - camera.x;
        const y = refill.center_y - sprite_size / 2 - camera.y + bobOffset(refill.cooldown, anim_counter);
        if (!visible(x, y, sprite_size, sprite_size)) continue;

        gba.display.objects[first_object + object_offset] = gba.display.Object.init(.{
            .size = .size_16x16,
            .x = objX(x),
            .y = objY(y),
            .base_tile = frameTile(frameIndex(refill.cooldown, anim_counter)),
            .priority = 1,
            .palette = palette_bank,
        });
        object_offset += 1;
    }

    const drawn_objects = object_offset;
    const hide_until = @min(last_drawn_objects, object_capacity);
    while (object_offset < hide_until) : (object_offset += 1) {
        hideObject(first_object + object_offset);
    }
    last_drawn_objects = drawn_objects;
}

pub fn hideObjects() void {
    var index: usize = 0;
    while (index < object_capacity) : (index += 1) {
        hideObject(first_object + index);
    }
    last_drawn_objects = 0;
}

fn playerTouchesRefill(player: Player, refill: Refill) bool {
    const half_w: i16 = @divTrunc(@as(i16, @intCast(refill.w)), 2);
    const half_h: i16 = @divTrunc(@as(i16, @intCast(refill.h)), 2);
    return collision.rectsOverlap(
        fixedToPixel(player.x),
        fixedToPixel(player.y),
        fixedToPixel(player.x) + player_mod.body_width,
        fixedToPixel(player.y) + player_mod.body_height,
        refill.center_x - half_w,
        refill.center_y - half_h,
        refill.center_x + half_w,
        refill.center_y + half_h,
    );
}

fn refillPlayer(player: *Player) void {
    player.dashes = 1;
    player.dash_refill_cooldown_timer = 0;
    player.stamina = player_mod.climb_max_stamina;
}

fn nextSoundIndex() u8 {
    const index = @min(room_collect_count, 2);
    if (room_collect_count < 255) {
        room_collect_count += 1;
    }
    return index;
}

fn playTouchSound(index: u8) void {
    const samples = [_]u16{
        sound_ids.sfx_diamond_touch_01,
        sound_ids.sfx_diamond_touch_02,
        sound_ids.sfx_diamond_touch_03,
    };
    playSound(samples[@min(index, 2)], touch_volume);
}

fn playReturnSound(index: u8) void {
    const samples = [_]u16{
        sound_ids.sfx_diamond_return_01,
        sound_ids.sfx_diamond_return_02,
        sound_ids.sfx_diamond_return_03,
    };
    playSound(samples[@min(index, 2)], return_volume);
}

fn playSound(sound_id: u16, volume: u16) void {
    const handle = audio.playImportantSoundEffect(sound_id);
    if (handle != 0) {
        audio.setSoundEffectVolume(handle, volume);
    }
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < screen_width and y < screen_height and x + width > 0 and y + height > 0;
}

fn frameIndex(cooldown: u8, anim_counter: u16) u16 {
    if (cooldown == 0) {
        return loopFrame(anim_counter, meta.idle_frame_count, idle_frame_ticks);
    }

    const flash_frames = meta.flash_frame_count * flash_frame_ticks;
    if (@as(u16, cooldown) <= flash_frames) {
        const elapsed = flash_frames - @as(u16, cooldown);
        const frame = @min(@divTrunc(elapsed, flash_frame_ticks), meta.flash_frame_count - 1);
        return meta.idle_frame_count + frame;
    }

    return meta.outline_frame_index;
}

fn loopFrame(counter: u16, frame_count: u16, frame_ticks: u16) u16 {
    if (frame_count == 0 or frame_ticks == 0) return 0;
    return @mod(@divTrunc(counter, frame_ticks), frame_count);
}

fn frameTile(frame: u16) u10 {
    return base_tile + @as(u10, @intCast(frame * meta.tiles_per_frame));
}

fn bobOffset(cooldown: u8, anim_counter: u16) i16 {
    if (cooldown > meta.flash_frame_count * flash_frame_ticks) return 0;
    return switch (@mod(@divTrunc(anim_counter, bob_frame_ticks), 8)) {
        1 => -1,
        2 => -2,
        3 => -1,
        5 => 1,
        6 => 2,
        7 => 1,
        else => 0,
    };
}
