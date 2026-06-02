const gba = @import("gba");

const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");
const camera_mod = @import("../world/camera.zig");
const collectibles = @import("../core/collectibles.zig");
const collision = @import("../world/collision.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");
const save = @import("../core/save.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const sound_ids = assets.sound_ids;
const screen_width = 240;
const screen_height = 160;

const idle_tiles_data align(4) = assets.strawberry_idle_tiles_data;
const flap_tiles_data align(4) = assets.strawberry_flap_tiles_data;
const collect_tiles_data align(4) = assets.strawberry_collect_tiles_data;
const palette_data align(4) = assets.strawberry_palette_data;
const collect_palette_data align(4) = assets.strawberry_collect_palette_data;

const rooms = level.rooms;

pub const max_loaded = collectibles.max_strawberries_per_room;
pub const max_carried = 8;
pub const first_object = foreground_stamps.behind_first_object;
pub const object_capacity = 16;

const record_bytes = 8;
const collect_ground_frames = 9;
const collect_chain_cooldown_frames = 8;
const flyaway_frames = 72;
const palette_bank: u4 = 8;
const collect_palette_bank: u4 = 9;

const idle_frame_count: u16 = 36;
const idle_frame_ticks: u16 = 4;
const idle_tiles_per_frame = 8;
const idle_base_tile: u10 = 496;
const idle_cell_width: i16 = 32;
const idle_cell_height: i16 = 16;

const flap_frame_count: u16 = 27;
const flap_frame_ticks: u16 = 2;
const flap_tiles_per_frame = 32;
const flap_base_tile: u10 = idle_base_tile + idle_tiles_per_frame;
const flap_cell_width: i16 = 64;
const flap_cell_height: i16 = 32;

const collect_frame_count: u16 = 5;
const collect_frame_ticks: u16 = 3;
const collect_tiles_per_frame = 8;
const collect_base_tile: u10 = flap_base_tile + flap_tiles_per_frame;
const collect_slot_count = 2;
const collect_cell_width: i16 = 32;
const collect_cell_height: i16 = 16;

const invalid_frame: u16 = 0xffff;

const Kind = enum(u8) {
    normal = 0,
    flying = 1,
};

const Animation = enum {
    idle,
    flap,
    collect,
};

const Berry = struct {
    active: bool = false,
    global_id: u16 = 0,
    center_x: i16 = 0,
    center_y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    kind: Kind = .normal,
    phase: u8 = 0,
    flyaway: bool = false,
    flyaway_timer: u8 = 0,
};

const Carried = struct {
    active: bool = false,
    global_id: u16 = 0,
    source_room: usize = 0,
    x: i32 = 0,
    y: i32 = 0,
    phase: u8 = 0,
};

const CollectEffect = struct {
    active: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    timer: u8 = 0,
    slot: u8 = 0,
};

var loaded: [max_loaded]Berry = [_]Berry{.{}} ** max_loaded;
var loaded_count: usize = 0;
var carried: [max_carried]Carried = [_]Carried{.{}} ** max_carried;
var carried_count: usize = 0;
var collect_effects: [max_carried]CollectEffect = [_]CollectEffect{.{}} ** max_carried;
var collect_effect_count: usize = 0;
var safe_ground_streak: u8 = 0;
var collect_cooldown: u8 = collect_chain_cooldown_frames;
var chain_combo_index: u8 = 0;
var wingflap_variant: u8 = 0;
var loaded_idle_frame: u16 = invalid_frame;
var loaded_flap_frame: u16 = invalid_frame;
var loaded_collect_frames: [collect_slot_count]u16 = [_]u16{invalid_frame} ** collect_slot_count;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    loaded = [_]Berry{.{}} ** max_loaded;
    loaded_count = 0;
    collect_effects = [_]CollectEffect{.{}} ** max_carried;
    collect_effect_count = 0;
    safe_ground_streak = 0;
    hideObjects();

    if (carried_count == 0) {
        collect_cooldown = collect_chain_cooldown_frames;
        chain_combo_index = 0;
    }

    const data = rooms[room_index].strawberries;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_loaded);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const global_id = collectibles.strawberryId(room_index, source_index) orelse continue;
        if (collectibles.isStrawberryCollected(global_id) or isCarried(global_id)) continue;

        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;

        loaded[loaded_count] = .{
            .active = true,
            .global_id = global_id,
            .center_x = readI16Le(data, source_offset),
            .center_y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
            .kind = kindFromByte(data[source_offset + 6]),
            .phase = @intCast(source_index & 3),
        };
        loaded_count += 1;
    }
}

pub fn loadGraphics() void {
    if (!hasVisibleSprites()) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, collect_palette_bank) * 16], @ptrCast(&collect_palette_data), 16);
    invalidateFrames();
}

pub fn update(player: *Player, room_index: usize) void {
    const dash_started = dashStartedThisFrame(player.*);
    pickupLoaded(player.*, room_index);
    if (dash_started) {
        startWingedFlyaways();
    }
    updateFlyaways();
    updateCarriedPositions(player.*);
    updateCollection(player.*);
    updateCollectEffects();
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (!hasVisibleSprites() and last_drawn_objects == 0) return;

    var object_offset: usize = 0;

    const idle_frame = loopFrame(anim_counter, idle_frame_count, idle_frame_ticks);
    const flap_frame = loopFrame(anim_counter, flap_frame_count, flap_frame_ticks);

    var index: usize = 0;
    while (index < loaded_count and object_offset < object_capacity) : (index += 1) {
        const berry = loaded[index];
        if (!berry.active) continue;
        const animation: Animation = if (berry.kind == .flying) .flap else .idle;
        const frame = if (animation == .flap) flap_frame else idle_frame;
        if (drawBerryObject(first_object + object_offset, berry.center_x, berry.center_y, animation, frame, camera)) {
            object_offset += 1;
        }
    }

    index = 0;
    while (index < carried_count and object_offset < object_capacity) : (index += 1) {
        const berry = carried[index];
        if (!berry.active) continue;
        if (drawBerryObject(first_object + object_offset, fixedToPixel(berry.x), fixedToPixel(berry.y), .idle, idle_frame, camera)) {
            object_offset += 1;
        }
    }

    index = 0;
    while (index < collect_effect_count and object_offset < object_capacity) : (index += 1) {
        const effect = collect_effects[index];
        if (!effect.active) continue;
        const frame = collectFrame(effect.timer);
        if (drawBerryObjectSlot(first_object + object_offset, fixedToPixel(effect.x), fixedToPixel(effect.y), .collect, frame, effect.slot, camera)) {
            object_offset += 1;
        }
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

pub fn clearCarried() void {
    carried = [_]Carried{.{}} ** max_carried;
    carried_count = 0;
    safe_ground_streak = 0;
    collect_cooldown = collect_chain_cooldown_frames;
    chain_combo_index = 0;
}

fn hasVisibleSprites() bool {
    if (carried_count > 0 or collect_effect_count > 0) return true;
    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        if (loaded[index].active) return true;
    }
    return false;
}

fn pickupLoaded(player: Player, room_index: usize) void {
    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        const berry = &loaded[index];
        if (!berry.active) continue;
        if (!playerTouchesBerry(player, berry.*)) continue;
        if (!addCarried(berry.*, room_index)) continue;

        berry.active = false;
        playTouchSound();
    }
}

fn addCarried(berry: Berry, room_index: usize) bool {
    if (carried_count >= max_carried) return false;
    if (isCarried(berry.global_id)) return false;

    carried[carried_count] = .{
        .active = true,
        .global_id = berry.global_id,
        .source_room = room_index,
        .x = pixelToFixed(berry.center_x),
        .y = pixelToFixed(berry.center_y),
        .phase = berry.phase,
    };
    carried_count += 1;
    return true;
}

fn dashStartedThisFrame(player: Player) bool {
    return player.dash_timer == player_mod.dash_frames - 1 and (player.dash_dir_x != 0 or player.dash_dir_y != 0);
}

fn startWingedFlyaways() void {
    var started = false;
    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        const berry = &loaded[index];
        if (!berry.active or berry.kind != .flying or berry.flyaway) continue;
        berry.flyaway = true;
        berry.flyaway_timer = flyaway_frames;
        started = true;
    }
    if (started) {
        playFlyawaySound();
    }
}

fn updateFlyaways() void {
    var play_flap = false;
    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        const berry = &loaded[index];
        if (!berry.active or !berry.flyaway) continue;

        berry.center_y -= 2;
        if (berry.flyaway_timer != flyaway_frames and berry.flyaway_timer % 12 == 0) {
            play_flap = true;
        }
        if ((berry.flyaway_timer & 7) == 0) {
            berry.center_x += if ((berry.flyaway_timer & 8) == 0) @as(i16, 1) else @as(i16, -1);
        }
        if (berry.flyaway_timer > 0) {
            berry.flyaway_timer -= 1;
        } else {
            berry.active = false;
        }
        if (berry.center_y < -flap_cell_height) {
            berry.active = false;
        }
    }
    if (play_flap) {
        playWingFlapSound();
    }
}

fn updateCarriedPositions(player: Player) void {
    if (carried_count == 0) return;

    const facing_dir: i16 = if (player.facing_left) 1 else -1;
    var target_x = player.x + pixelToFixed(player_mod.body_width / 2);
    var target_y = player.y - pixelToFixed(10);

    var index: usize = 0;
    while (index < carried_count) : (index += 1) {
        const berry = &carried[index];
        berry.x = approachFollow(berry.x, target_x);
        berry.y = approachFollow(berry.y, target_y);
        target_x = berry.x + pixelToFixed(12 * facing_dir);
        target_y = berry.y - pixelToFixed(4);
    }
}

fn updateCollection(player: Player) void {
    if (carried_count == 0) {
        safe_ground_streak = 0;
        collect_cooldown = collect_chain_cooldown_frames;
        chain_combo_index = 0;
        return;
    }

    if (!player.grounded) {
        safe_ground_streak = 0;
        return;
    }

    if (safe_ground_streak < collect_ground_frames) {
        safe_ground_streak += 1;
    }
    if (collect_cooldown < collect_chain_cooldown_frames) {
        collect_cooldown += 1;
    }

    const cooldown_ready = chain_combo_index == 0 or collect_cooldown >= collect_chain_cooldown_frames;
    if (safe_ground_streak >= collect_ground_frames and cooldown_ready) {
        collectFirstCarried();
        safe_ground_streak = 0;
        collect_cooldown = 0;
    }
}

fn updateCollectEffects() void {
    var write_index: usize = 0;
    var index: usize = 0;
    while (index < collect_effect_count) : (index += 1) {
        var effect = collect_effects[index];
        if (!effect.active) continue;
        effect.timer += 1;
        if (effect.timer >= collect_frame_count * collect_frame_ticks) continue;
        collect_effects[write_index] = effect;
        write_index += 1;
    }
    while (write_index < collect_effect_count) : (write_index += 1) {
        collect_effects[write_index] = .{};
    }
    collect_effect_count = write_index;
}

fn collectFirstCarried() void {
    if (carried_count == 0) return;

    const berry = carried[0];
    startCollectEffect(berry.x, berry.y);
    if (collectibles.markStrawberryCollected(berry.global_id, chain_combo_index)) {
        playCollectSound(chain_combo_index);
        save.commitProgress();
    }
    removeCarriedAt(0);
    if (chain_combo_index != 255) chain_combo_index += 1;
    if (carried_count == 0) {
        safe_ground_streak = 0;
        collect_cooldown = collect_chain_cooldown_frames;
        chain_combo_index = 0;
    }
}

fn startCollectEffect(x: i32, y: i32) void {
    if (collect_effect_count >= max_carried) return;
    collect_effects[collect_effect_count] = .{
        .active = true,
        .x = x,
        .y = y,
        .slot = nextCollectSlot(),
    };
    collect_effect_count += 1;
}

fn nextCollectSlot() u8 {
    var used = [_]bool{false} ** collect_slot_count;
    var index: usize = 0;
    while (index < collect_effect_count) : (index += 1) {
        const effect = collect_effects[index];
        if (!effect.active) continue;
        used[collectSlotIndex(effect.slot)] = true;
    }

    index = 0;
    while (index < collect_slot_count) : (index += 1) {
        if (!used[index]) return @intCast(index);
    }
    return 0;
}

fn removeCarriedAt(remove_index: usize) void {
    var index = remove_index;
    while (index + 1 < carried_count) : (index += 1) {
        carried[index] = carried[index + 1];
    }
    carried_count -= 1;
    carried[carried_count] = .{};
}

fn playerTouchesBerry(player: Player, berry: Berry) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;
    const half_w: i16 = @as(i16, @intCast(berry.w / 2));
    const half_h: i16 = @as(i16, @intCast(berry.h / 2));
    return collision.rectsOverlap(
        player_left,
        player_top,
        player_right,
        player_bottom,
        berry.center_x - half_w,
        berry.center_y - half_h,
        berry.center_x + half_w,
        berry.center_y + half_h,
    );
}

fn isCarried(global_id: u16) bool {
    var index: usize = 0;
    while (index < carried_count) : (index += 1) {
        if (carried[index].active and carried[index].global_id == global_id) return true;
    }
    return false;
}

fn approachFollow(value: i32, target: i32) i32 {
    const delta = target - value;
    if (delta > -fixed_one / 2 and delta < fixed_one / 2) return target;
    return value + @divTrunc(delta, 4);
}

fn drawBerryObject(object_index: usize, center_x: i16, center_y: i16, animation: Animation, frame: u16, camera: Camera) bool {
    return drawBerryObjectSlot(object_index, center_x, center_y, animation, frame, 0, camera);
}

fn drawBerryObjectSlot(object_index: usize, center_x: i16, center_y: i16, animation: Animation, frame: u16, collect_slot: u8, camera: Camera) bool {
    const spec = animationSpec(animation, collect_slot);
    const x = center_x - @divTrunc(spec.cell_width, 2) - camera.x;
    const y = center_y - @divTrunc(spec.cell_height, 2) - camera.y;
    if (!visible(x, y, spec.cell_width, spec.cell_height)) return false;

    loadAnimationFrame(animation, frame, collect_slot);
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = spec.size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = spec.base_tile,
        .priority = 1,
        .palette = spec.palette,
    });
    return true;
}

fn loadAnimationFrame(animation: Animation, frame: u16, collect_slot: u8) void {
    switch (animation) {
        .idle => loadTileFrame(&idle_tiles_data, idle_base_tile, frame, idle_tiles_per_frame, &loaded_idle_frame),
        .flap => loadTileFrame(&flap_tiles_data, flap_base_tile, frame, flap_tiles_per_frame, &loaded_flap_frame),
        .collect => {
            const slot = collectSlotIndex(collect_slot);
            loadTileFrame(&collect_tiles_data, collectSlotBase(slot), frame, collect_tiles_per_frame, &loaded_collect_frames[slot]);
        },
    }
}

fn loadTileFrame(tile_data: []align(4) const u8, target_tile: u10, frame: u16, tiles_per_frame: usize, loaded_frame: *u16) void {
    if (loaded_frame.* == frame) return;
    const byte_offset = @as(usize, frame) * tiles_per_frame * 32;
    const byte_len = tiles_per_frame * 32;
    const frame_bytes = tile_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(target_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_frame.* = frame;
}

fn animationSpec(animation: Animation, collect_slot: u8) struct {
    base_tile: u10,
    cell_width: i16,
    cell_height: i16,
    size: gba.display.Object.Size,
    palette: u4,
} {
    return switch (animation) {
        .idle => .{ .base_tile = idle_base_tile, .cell_width = idle_cell_width, .cell_height = idle_cell_height, .size = .size_32x16, .palette = palette_bank },
        .flap => .{ .base_tile = flap_base_tile, .cell_width = flap_cell_width, .cell_height = flap_cell_height, .size = .size_64x32, .palette = palette_bank },
        .collect => .{ .base_tile = collectSlotBase(collectSlotIndex(collect_slot)), .cell_width = collect_cell_width, .cell_height = collect_cell_height, .size = .size_32x16, .palette = collect_palette_bank },
    };
}

fn collectSlotIndex(slot: u8) usize {
    const index = @as(usize, slot);
    return if (index < collect_slot_count) index else collect_slot_count - 1;
}

fn collectSlotBase(slot: usize) u10 {
    return collect_base_tile + @as(u10, @intCast(slot * collect_tiles_per_frame));
}

fn invalidateFrames() void {
    loaded_idle_frame = invalid_frame;
    loaded_flap_frame = invalid_frame;
    loaded_collect_frames = [_]u16{invalid_frame} ** collect_slot_count;
}

fn loopFrame(anim_counter: u16, frame_count: u16, frame_ticks: u16) u16 {
    return (anim_counter / frame_ticks) % frame_count;
}

fn collectFrame(timer: u8) u16 {
    const frame = @as(u16, timer) / collect_frame_ticks;
    return if (frame >= collect_frame_count) collect_frame_count - 1 else frame;
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < screen_width and y < screen_height and x + width > 0 and y + height > 0;
}

fn kindFromByte(value: u8) Kind {
    return switch (value) {
        1 => .flying,
        else => .normal,
    };
}

fn playTouchSound() void {
    _ = audio.playSoundEffect(sound_ids.sfx_strawberry_touch);
}

fn playCollectSound(combo_index: u8) void {
    const sound_id = switch (combo_index) {
        0 => sound_ids.sfx_strawberry_red_get_1000,
        1 => sound_ids.sfx_strawberry_red_get_2000,
        2 => sound_ids.sfx_strawberry_red_get_3000,
        3 => sound_ids.sfx_strawberry_red_get_4000,
        4 => sound_ids.sfx_strawberry_red_get_5000,
        else => sound_ids.sfx_strawberry_red_get_1up,
    };
    _ = audio.playSoundEffect(sound_id);
}

fn playFlyawaySound() void {
    _ = audio.playSoundEffect(sound_ids.sfx_strawberry_flyaway);
}

fn playWingFlapSound() void {
    const samples = [_]u16{
        sound_ids.sfx_strawberry_wingflap_01,
        sound_ids.sfx_strawberry_wingflap_02,
        sound_ids.sfx_strawberry_wingflap_03,
    };
    const index: usize = @intCast(wingflap_variant % @as(u8, @intCast(samples.len)));
    wingflap_variant +%= 1;
    const handle = audio.playSoundEffect(samples[index]);
    if (handle != 0) {
        audio.setSoundEffectVolume(handle, 112);
    }
}
