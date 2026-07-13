const gba = @import("gba");

const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");
const camera_mod = @import("../world/camera.zig");
const collectibles = @import("../core/collectibles.zig");
const collision = @import("../world/collision.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");
const save = @import("../core/save.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixed_shift = math.fixed_shift;
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
const score_tiles_data align(4) = assets.strawberry_score_tiles_data;
const palette_data align(4) = assets.strawberry_palette_data;
const collect_palette_data align(4) = assets.strawberry_collect_palette_data;
const ghost_idle_tiles_data align(4) = assets.ghostberry_idle_tiles_data;
const ghost_flap_tiles_data align(4) = assets.ghostberry_flap_tiles_data;
const ghost_collect_tiles_data align(4) = assets.ghostberry_collect_tiles_data;
const ghost_palette_data align(4) = assets.ghostberry_palette_data;
const ghost_collect_palette_data align(4) = assets.ghostberry_collect_palette_data;

const rooms = level.rooms;

pub const max_loaded = collectibles.max_strawberries_per_room;
pub const max_carried = 8;
pub const first_object = foreground_stamps.behind_first_object;
pub const object_capacity = 16;

const record_bytes = 8;
const collect_ground_frames = 9;
const collect_chain_cooldown_frames = 8;
const flyaway_frames = 72;
const carry_trail_capacity = 32;
const carry_trail_spacing_frames = 4;
const carry_anchor_y_offset_px = -10;
const palette_bank: u4 = 8;
const collect_palette_bank: u4 = 9;

const idle_frame_count: u16 = 36;
const idle_frame_ticks: u16 = 4;
const idle_tiles_per_frame = 8;
const normal_tile_range = obj_vram.strawberry_normal;
const ghost_tile_range = obj_vram.strawberry_ghost;
const idle_base_tile = normal_tile_range.baseTile();
const idle_cell_width: i16 = 32;
const idle_cell_height: i16 = 16;

const flap_frame_count: u16 = 27;
const flap_frame_ticks: u16 = 2;
const flap_tiles_per_frame = 32;
const flap_base_tile = normal_tile_range.tile(idle_tiles_per_frame);
const flap_cell_width: i16 = 64;
const flap_cell_height: i16 = 32;

const collect_frame_count: u16 = 5;
const collect_frame_ticks: u16 = 3;
const collect_tiles_per_frame = 8;
const collect_slot_count = 2;
const collect_effect_capacity = collect_slot_count;
const collect_cell_width: i16 = 32;
const collect_cell_height: i16 = 16;

const score_variant_count: u16 = assets.strawberry_score_meta.variant_count;
const score_frame_count: u16 = assets.strawberry_score_meta.frame_count;
const score_frame_ticks: u16 = 1;
const score_tiles_per_frame: usize = assets.strawberry_score_meta.tiles_per_frame;
const score_tile_range = obj_vram.strawberry_score;
const score_slot_count = 3;
const score_effect_capacity = score_slot_count;
const score_cell_width: i16 = assets.strawberry_score_meta.cell_width;
const score_cell_height: i16 = assets.strawberry_score_meta.cell_height;

const ghost_idle_base_tile = ghost_tile_range.baseTile();
const ghost_flap_base_tile = ghost_tile_range.tile(idle_tiles_per_frame);

const Kind = enum(u8) {
    normal = 0,
    flying = 1,
};

const Animation = enum {
    idle,
    flap,
    collect,
};

const PaletteVariant = enum {
    invalid,
    normal,
    ghost,
};

const Berry = struct {
    active: bool = false,
    ghost: bool = false,
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
    ghost: bool = false,
    global_id: u16 = 0,
    x: i32 = 0,
    y: i32 = 0,
    phase: u8 = 0,
};

const CollectEffect = struct {
    active: bool = false,
    ghost: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    timer: u8 = 0,
    slot: u8 = 0,
};

const ScoreEffect = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    timer: u8 = 0,
    variant: u8 = 0,
    slot: u8 = 0,
};

const TrailPoint = struct {
    x: i16 = 0,
    y: i16 = 0,
};

var loaded: [max_loaded]Berry = [_]Berry{.{}} ** max_loaded;
var loaded_count: usize = 0;
var carried: [max_carried]Carried = [_]Carried{.{}} ** max_carried;
var carried_count: usize = 0;
var collect_effects: [collect_effect_capacity]CollectEffect = [_]CollectEffect{.{}} ** collect_effect_capacity;
var collect_effect_count: usize = 0;
var score_effects: [score_effect_capacity]ScoreEffect = [_]ScoreEffect{.{}} ** score_effect_capacity;
var score_effect_count: usize = 0;
var carried_trail: [carry_trail_capacity]TrailPoint = [_]TrailPoint{.{}} ** carry_trail_capacity;
var carried_trail_head: usize = 0;
var carried_trail_count: usize = 0;
var safe_ground_streak: u8 = 0;
var collect_cooldown: u8 = collect_chain_cooldown_frames;
var chain_combo_index: u8 = 0;
var previous_player_grounded: bool = false;
var wingflap_variant: u8 = 0;
var idle_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var flap_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var collect_frame_caches: [collect_slot_count]gba.display.ObjectTileFrameCache4Bpp = [_]gba.display.ObjectTileFrameCache4Bpp{.{}} ** collect_slot_count;
var ghost_idle_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var ghost_flap_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var ghost_collect_frame_caches: [collect_slot_count]gba.display.ObjectTileFrameCache4Bpp = [_]gba.display.ObjectTileFrameCache4Bpp{.{}} ** collect_slot_count;
var score_frame_caches: [score_slot_count]gba.display.ObjectTileFrameCache4Bpp = [_]gba.display.ObjectTileFrameCache4Bpp{.{}} ** score_slot_count;
var loaded_main_palette: PaletteVariant = .invalid;
var loaded_collect_palette: PaletteVariant = .invalid;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    loaded = [_]Berry{.{}} ** max_loaded;
    loaded_count = 0;
    collect_effects = [_]CollectEffect{.{}} ** collect_effect_capacity;
    collect_effect_count = 0;
    score_effects = [_]ScoreEffect{.{}} ** score_effect_capacity;
    score_effect_count = 0;
    safe_ground_streak = 0;
    hideObjects();

    if (carried_count == 0) {
        collect_cooldown = collect_chain_cooldown_frames;
        chain_combo_index = 0;
        clearCarriedTrail();
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
        if (isCarried(global_id)) continue;
        const collected_before_run = collectibles.wasStrawberryCollectedBeforeRun(global_id);
        if (!collected_before_run and collectibles.isStrawberryCollected(global_id)) continue;

        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;

        loaded[loaded_count] = .{
            .active = true,
            .ghost = collected_before_run,
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
    loaded_main_palette = .invalid;
    loaded_collect_palette = .invalid;
    loadMainPalette(mainPaletteVariant());
    loadCollectPalette(collectPaletteVariant());
    invalidateFrames();
}

pub fn invalidateGraphics() void {
    loaded_main_palette = .invalid;
    loaded_collect_palette = .invalid;
    invalidateFrames();
}

pub fn update(player: *Player, room_index: usize) void {
    _ = room_index;
    const dash_started = dashStartedThisFrame(player.*);
    pickupLoaded(player.*);
    if (dash_started) {
        startWingedFlyaways();
    }
    updateFlyaways();
    pushCarriedTrailPoint(player.*);
    updateCarriedPositions();
    updateCollection(player.*, dash_started);
    updateCollectEffects();
    updateScoreEffects();
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (!hasVisibleSprites() and last_drawn_objects == 0) return;
    loadMainPalette(mainPaletteVariant());
    loadCollectPalette(collectPaletteVariant());

    var object_offset: usize = 0;

    const idle_frame = loopFrame(anim_counter, idle_frame_count, idle_frame_ticks);
    const flap_frame = loopFrame(anim_counter, flap_frame_count, flap_frame_ticks);

    var index: usize = 0;
    while (index < loaded_count and object_offset < object_capacity) : (index += 1) {
        const berry = loaded[index];
        if (!berry.active) continue;
        const animation: Animation = if (berry.kind == .flying) .flap else .idle;
        const frame = if (animation == .flap) flap_frame else idle_frame;
        if (drawBerryObject(first_object + object_offset, berry.center_x, berry.center_y, animation, frame, berry.ghost, camera)) {
            object_offset += 1;
        }
    }

    index = 0;
    while (index < carried_count and object_offset < object_capacity) : (index += 1) {
        const berry = carried[index];
        if (!berry.active) continue;
        if (drawBerryObject(first_object + object_offset, fixedToPixel(berry.x), fixedToPixel(berry.y), .idle, idle_frame, berry.ghost, camera)) {
            object_offset += 1;
        }
    }

    index = 0;
    while (index < collect_effect_count and object_offset < object_capacity) : (index += 1) {
        const effect = collect_effects[index];
        if (!effect.active) continue;
        const frame = collectFrame(effect.timer);
        if (drawBerryObjectSlot(first_object + object_offset, fixedToPixel(effect.x), fixedToPixel(effect.y), .collect, frame, effect.slot, effect.ghost, camera)) {
            object_offset += 1;
        }
    }

    index = 0;
    while (index < score_effect_count and object_offset < object_capacity) : (index += 1) {
        const effect = score_effects[index];
        if (!effect.active) continue;
        const frame = scoreFrame(effect.timer);
        if (drawScoreObject(first_object + object_offset, effect.x, effect.y, effect.variant, frame, effect.slot, camera)) {
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
    clearCarriedTrail();
    safe_ground_streak = 0;
    collect_cooldown = collect_chain_cooldown_frames;
    chain_combo_index = 0;
    previous_player_grounded = false;
}

pub fn handleRoomTransition(from_room: usize, to_room: usize) void {
    const from = rooms[from_room];
    const to = rooms[to_room];
    const dx_pixels = from.world_x - to.world_x;
    const dy_pixels = from.world_y - to.world_y;
    const dx = @as(i32, from.world_x - to.world_x) << fixed_shift;
    const dy = @as(i32, from.world_y - to.world_y) << fixed_shift;
    if (dx_pixels == 0 and dy_pixels == 0) return;

    var index: usize = 0;
    while (index < carried_count) : (index += 1) {
        carried[index].x += dx;
        carried[index].y += dy;
    }

    index = 0;
    while (index < collect_effect_count) : (index += 1) {
        collect_effects[index].x += dx;
        collect_effects[index].y += dy;
    }

    index = 0;
    while (index < score_effect_count) : (index += 1) {
        score_effects[index].x += dx_pixels;
        score_effects[index].y += dy_pixels;
    }

    index = 0;
    while (index < carried_trail_count) : (index += 1) {
        const trail_index = (carried_trail_head + carry_trail_capacity - index) % carry_trail_capacity;
        carried_trail[trail_index].x += dx_pixels;
        carried_trail[trail_index].y += dy_pixels;
    }
}

fn hasVisibleSprites() bool {
    if (carried_count > 0 or collect_effect_count > 0 or score_effect_count > 0) return true;
    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        if (loaded[index].active) return true;
    }
    return false;
}

fn mainPaletteVariant() PaletteVariant {
    var has_ghost = false;
    var has_normal = false;

    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        const berry = loaded[index];
        if (!berry.active) continue;
        if (berry.ghost) {
            has_ghost = true;
        } else {
            has_normal = true;
        }
    }

    index = 0;
    while (index < carried_count) : (index += 1) {
        const berry = carried[index];
        if (!berry.active) continue;
        if (berry.ghost) {
            has_ghost = true;
        } else {
            has_normal = true;
        }
    }

    return if (has_ghost and !has_normal) .ghost else .normal;
}

fn collectPaletteVariant() PaletteVariant {
    var has_ghost = false;
    var has_normal = false;

    var index: usize = 0;
    while (index < collect_effect_count) : (index += 1) {
        const effect = collect_effects[index];
        if (!effect.active) continue;
        if (effect.ghost) {
            has_ghost = true;
        } else {
            has_normal = true;
        }
    }

    return if (has_ghost and !has_normal) .ghost else .normal;
}

fn loadMainPalette(variant: PaletteVariant) void {
    const desired: PaletteVariant = if (variant == .ghost) .ghost else .normal;
    if (loaded_main_palette == desired) return;
    if (desired == .ghost) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&ghost_palette_data), 16);
    } else {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    }
    loaded_main_palette = desired;
}

fn loadCollectPalette(variant: PaletteVariant) void {
    const desired: PaletteVariant = if (variant == .ghost) .ghost else .normal;
    if (loaded_collect_palette == desired) return;
    if (desired == .ghost) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, collect_palette_bank) * 16], @ptrCast(&ghost_collect_palette_data), 16);
    } else {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, collect_palette_bank) * 16], @ptrCast(&collect_palette_data), 16);
    }
    loaded_collect_palette = desired;
}

fn pickupLoaded(player: Player) void {
    var index: usize = 0;
    while (index < loaded_count) : (index += 1) {
        const berry = &loaded[index];
        if (!berry.active) continue;
        if (!playerTouchesBerry(player, berry.*)) continue;
        if (!addCarried(berry.*)) continue;

        berry.active = false;
        playTouchSound();
    }
}

fn addCarried(berry: Berry) bool {
    if (carried_count >= max_carried) return false;
    if (isCarried(berry.global_id)) return false;

    carried[carried_count] = .{
        .active = true,
        .ghost = berry.ghost,
        .global_id = berry.global_id,
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

fn updateCarriedPositions() void {
    if (carried_count == 0) return;

    var index: usize = 0;
    while (index < carried_count) : (index += 1) {
        const berry = &carried[index];
        const point = sampleCarriedTrail((index + 1) * carry_trail_spacing_frames);
        berry.x = pixelToFixed(point.x);
        berry.y = pixelToFixed(point.y);
    }
}

fn updateCollection(player: Player, dash_started: bool) void {
    const broke_chain = groundActionBreaksChain(player, dash_started);
    if (broke_chain) {
        resetCollectionChain();
    }

    if (carried_count == 0) {
        safe_ground_streak = 0;
        collect_cooldown = collect_chain_cooldown_frames;
        chain_combo_index = 0;
        previous_player_grounded = player.grounded;
        return;
    }

    if (collect_cooldown < collect_chain_cooldown_frames) {
        collect_cooldown += 1;
    }

    if (!player.grounded) {
        safe_ground_streak = 0;
        previous_player_grounded = false;
        return;
    }

    if (safe_ground_streak < collect_ground_frames) {
        safe_ground_streak += 1;
    }

    const cooldown_ready = chain_combo_index == 0 or collect_cooldown >= collect_chain_cooldown_frames;
    if (safe_ground_streak >= collect_ground_frames and cooldown_ready) {
        collectFirstCarried();
        safe_ground_streak = 0;
        collect_cooldown = 0;
    }
    previous_player_grounded = player.grounded;
}

fn pushCarriedTrailPoint(player: Player) void {
    if (carried_count == 0) {
        clearCarriedTrail();
        return;
    }

    const point = carriedTrailAnchor(player);
    if (carried_trail_count == 0) {
        carried_trail[0] = point;
        carried_trail_head = 0;
        carried_trail_count = 1;
        return;
    }

    carried_trail_head = (carried_trail_head + 1) % carry_trail_capacity;
    carried_trail[carried_trail_head] = point;
    if (carried_trail_count < carry_trail_capacity) {
        carried_trail_count += 1;
    }
}

fn carriedTrailAnchor(player: Player) TrailPoint {
    return .{
        .x = fixedToPixel(player.x) + player_mod.body_width / 2,
        .y = fixedToPixel(player.y) + carry_anchor_y_offset_px,
    };
}

fn sampleCarriedTrail(age_frames: usize) TrailPoint {
    if (carried_trail_count == 0) return .{};

    var age = age_frames;
    if (age >= carried_trail_count) {
        age = carried_trail_count - 1;
    }

    var index = carried_trail_head;
    var remaining = age;
    while (remaining > 0) : (remaining -= 1) {
        index = if (index == 0) carry_trail_capacity - 1 else index - 1;
    }
    return carried_trail[index];
}

fn clearCarriedTrail() void {
    carried_trail_count = 0;
    carried_trail_head = 0;
}

fn groundActionBreaksChain(player: Player, dash_started: bool) bool {
    if (chain_combo_index == 0) return false;
    if (dash_started and previous_player_grounded) return true;
    return previous_player_grounded and !player.grounded and player.vy < 0 and player.var_jump_timer > 0;
}

fn resetCollectionChain() void {
    safe_ground_streak = 0;
    collect_cooldown = collect_chain_cooldown_frames;
    chain_combo_index = 0;
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

fn updateScoreEffects() void {
    var write_index: usize = 0;
    var index: usize = 0;
    while (index < score_effect_count) : (index += 1) {
        var effect = score_effects[index];
        if (!effect.active) continue;
        effect.timer += 1;
        if ((effect.timer & 1) == 0) {
            effect.y -= 1;
        }
        if (@as(u16, effect.timer) >= score_frame_count * score_frame_ticks) continue;
        score_effects[write_index] = effect;
        write_index += 1;
    }
    while (write_index < score_effect_count) : (write_index += 1) {
        score_effects[write_index] = .{};
    }
    score_effect_count = write_index;
}

fn collectFirstCarried() void {
    if (carried_count == 0) return;

    const berry = carried[0];
    startCollectEffect(berry.x, berry.y, berry.ghost);
    startScoreEffect(berry.x, berry.y - pixelToFixed(14), chain_combo_index);
    const newly_collected = collectibles.markStrawberryCollected(berry.global_id, chain_combo_index);
    if (newly_collected or berry.ghost) {
        playCollectSound(chain_combo_index);
    }
    if (newly_collected) {
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

fn startScoreEffect(x: i32, y: i32, combo_index: u8) void {
    if (score_effect_count >= score_effect_capacity) return;
    score_effects[score_effect_count] = .{
        .active = true,
        .x = fixedToPixel(x),
        .y = fixedToPixel(y),
        .variant = scoreVariant(combo_index),
        .slot = nextScoreSlot(),
    };
    score_effect_count += 1;
}

fn startCollectEffect(x: i32, y: i32, ghost: bool) void {
    if (collect_effect_count >= collect_effect_capacity) return;
    collect_effects[collect_effect_count] = .{
        .active = true,
        .ghost = ghost,
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

fn nextScoreSlot() u8 {
    var used = [_]bool{false} ** score_slot_count;
    var index: usize = 0;
    while (index < score_effect_count) : (index += 1) {
        const effect = score_effects[index];
        if (!effect.active) continue;
        used[scoreSlotIndex(effect.slot)] = true;
    }

    index = 0;
    while (index < score_slot_count) : (index += 1) {
        if (!used[index]) return @intCast(index);
    }
    return 0;
}

fn scoreVariant(combo_index: u8) u8 {
    const max_variant: u8 = @intCast(score_variant_count - 1);
    return if (combo_index > max_variant) max_variant else combo_index;
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

fn drawBerryObject(object_index: usize, center_x: i16, center_y: i16, animation: Animation, frame: u16, ghost: bool, camera: Camera) bool {
    return drawBerryObjectSlot(object_index, center_x, center_y, animation, frame, 0, ghost, camera);
}

fn drawBerryObjectSlot(object_index: usize, center_x: i16, center_y: i16, animation: Animation, frame: u16, collect_slot: u8, ghost: bool, camera: Camera) bool {
    const spec = animationSpec(animation, collect_slot, ghost);
    const x = center_x - @divTrunc(spec.cell_width, 2) - camera.x;
    const y = center_y - @divTrunc(spec.cell_height, 2) - camera.y;
    if (!visible(x, y, spec.cell_width, spec.cell_height)) return false;

    loadAnimationFrame(animation, frame, collect_slot, ghost);
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

fn drawScoreObject(object_index: usize, center_x: i16, center_y: i16, variant: u8, frame: u16, slot: u8, camera: Camera) bool {
    const x = center_x - @divTrunc(score_cell_width, 2) - camera.x;
    const y = center_y - @divTrunc(score_cell_height, 2) - camera.y;
    if (!visible(x, y, score_cell_width, score_cell_height)) return false;

    const slot_index = scoreSlotIndex(slot);
    loadScoreFrame(variant, frame, slot_index);
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_32x16,
        .x = objX(x),
        .y = objY(y),
        .base_tile = scoreSlotBase(slot_index),
        .priority = 1,
        .palette = collect_palette_bank,
    });
    return true;
}

fn loadAnimationFrame(animation: Animation, frame: u16, collect_slot: u8, ghost: bool) void {
    switch (animation) {
        .idle => {
            if (ghost) {
                ghost_idle_frame_cache.upload4Bpp(ghost_tile_range, &ghost_idle_tiles_data, frame, idle_tiles_per_frame);
            } else {
                idle_frame_cache.upload4Bpp(normal_tile_range, &idle_tiles_data, frame, idle_tiles_per_frame);
            }
        },
        .flap => {
            if (ghost) {
                ghost_flap_frame_cache.upload4BppAt(ghost_tile_range, idle_tiles_per_frame, &ghost_flap_tiles_data, frame, flap_tiles_per_frame);
            } else {
                flap_frame_cache.upload4BppAt(normal_tile_range, idle_tiles_per_frame, &flap_tiles_data, frame, flap_tiles_per_frame);
            }
        },
        .collect => {
            const slot = collectSlotIndex(collect_slot);
            if (ghost) {
                ghost_collect_frame_caches[slot].upload4BppAt(ghost_tile_range, collectSlotOffset(slot), &ghost_collect_tiles_data, frame, collect_tiles_per_frame);
            } else {
                collect_frame_caches[slot].upload4BppAt(normal_tile_range, collectSlotOffset(slot), &collect_tiles_data, frame, collect_tiles_per_frame);
            }
        },
    }
}

fn loadScoreFrame(variant: u8, frame: u16, slot: usize) void {
    const variant_index = @as(u16, scoreVariant(variant));
    const frame_index = variant_index * score_frame_count + frame;
    score_frame_caches[slot].upload4BppAt(score_tile_range, scoreSlotOffset(slot), &score_tiles_data, frame_index, score_tiles_per_frame);
}

fn animationSpec(animation: Animation, collect_slot: u8, ghost: bool) struct {
    base_tile: u10,
    cell_width: i16,
    cell_height: i16,
    size: gba.display.Object.Size,
    palette: u4,
} {
    return switch (animation) {
        .idle => .{ .base_tile = if (ghost) ghost_idle_base_tile else idle_base_tile, .cell_width = idle_cell_width, .cell_height = idle_cell_height, .size = .size_32x16, .palette = palette_bank },
        .flap => .{ .base_tile = if (ghost) ghost_flap_base_tile else flap_base_tile, .cell_width = flap_cell_width, .cell_height = flap_cell_height, .size = .size_64x32, .palette = palette_bank },
        .collect => .{ .base_tile = if (ghost) ghostCollectSlotBase(collectSlotIndex(collect_slot)) else collectSlotBase(collectSlotIndex(collect_slot)), .cell_width = collect_cell_width, .cell_height = collect_cell_height, .size = .size_32x16, .palette = collect_palette_bank },
    };
}

fn collectSlotIndex(slot: u8) usize {
    const index = @as(usize, slot);
    return if (index < collect_slot_count) index else collect_slot_count - 1;
}

fn scoreSlotIndex(slot: u8) usize {
    const index = @as(usize, slot);
    return if (index < score_slot_count) index else score_slot_count - 1;
}

fn collectSlotBase(slot: usize) u10 {
    return normal_tile_range.tile(collectSlotOffset(slot));
}

fn ghostCollectSlotBase(slot: usize) u10 {
    return ghost_tile_range.tile(collectSlotOffset(slot));
}

fn scoreSlotBase(slot: usize) u10 {
    return score_tile_range.tile(scoreSlotOffset(slot));
}

fn collectSlotOffset(slot: usize) u16 {
    return @intCast(idle_tiles_per_frame + flap_tiles_per_frame + slot * collect_tiles_per_frame);
}

fn scoreSlotOffset(slot: usize) u16 {
    return @intCast(slot * score_tiles_per_frame);
}

fn invalidateFrames() void {
    idle_frame_cache.invalidate();
    flap_frame_cache.invalidate();
    collect_frame_caches = [_]gba.display.ObjectTileFrameCache4Bpp{.{}} ** collect_slot_count;
    ghost_idle_frame_cache.invalidate();
    ghost_flap_frame_cache.invalidate();
    ghost_collect_frame_caches = [_]gba.display.ObjectTileFrameCache4Bpp{.{}} ** collect_slot_count;
    score_frame_caches = [_]gba.display.ObjectTileFrameCache4Bpp{.{}} ** score_slot_count;
}

fn loopFrame(anim_counter: u16, frame_count: u16, frame_ticks: u16) u16 {
    return (anim_counter / frame_ticks) % frame_count;
}

fn collectFrame(timer: u8) u16 {
    const frame = @as(u16, timer) / collect_frame_ticks;
    return if (frame >= collect_frame_count) collect_frame_count - 1 else frame;
}

fn scoreFrame(timer: u8) u16 {
    const frame = @as(u16, timer) / score_frame_ticks;
    return if (frame >= score_frame_count) score_frame_count - 1 else frame;
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
