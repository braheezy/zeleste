const gba = @import("gba");

const assets = @import("../core/assets.zig");
const background = @import("../world/background.zig");
const camera_mod = @import("../world/camera.zig");
const collectibles = @import("../core/collectibles.zig");
const collision = @import("../world/collision.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");
const save = @import("../core/save.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const rooms = level.rooms;

const uncollected_tiles_data align(4) = assets.cassette_uncollected_tiles_data;
const collected_tiles_data align(4) = assets.cassette_collected_tiles_data;
const bubble_tiles_data align(4) = assets.cassette_bubble_tiles_data;
const palette_data align(4) = assets.cassette_palette_data;
const bubble_palette_data align(4) = assets.cassette_bubble_palette_data;
const meta = assets.cassette_meta;

const max_cassettes = 4;
const record_bytes = 8;
const frame_ticks: u16 = 4;
const base_tile: u10 = @intCast(obj_vram.cassette.start);
const bubble_base_tile: u10 = @intCast(obj_vram.cassette_bubble.start);
const palette_bank: u4 = 11;
const object_capacity = 2;
const first_object = 123;
const screen_width: i16 = 240;
const screen_height: i16 = 160;
const invalid_frame: u16 = 0xffff;
const return_frames: u8 = 72;

const PaletteMode = enum {
    invalid,
    cassette,
    bubble,
};

const Cassette = struct {
    active: bool = false,
    collected: bool = false,
    global_id: u16 = 0,
    center_x: i16 = 0,
    center_y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
};

const ReturnState = struct {
    active: bool = false,
    room_index: usize = 0,
    timer: u8 = 0,
    start_x: i32 = 0,
    start_y: i32 = 0,
    target_x: i32 = 0,
    target_y: i32 = 0,
    draw_x: i16 = 0,
    draw_y: i16 = 0,
};

var cassettes: [max_cassettes]Cassette = [_]Cassette{.{}} ** max_cassettes;
var cassette_count: usize = 0;
var last_drawn_objects: usize = 0;
var loaded_frame: u16 = invalid_frame;
var loaded_collected: bool = false;
var loaded_palette: PaletteMode = .invalid;
var bubble_tiles_loaded: bool = false;
var return_state: ReturnState = .{};
var bg_darkened = false;

pub fn load(room_index: usize) void {
    cassettes = [_]Cassette{.{}} ** max_cassettes;
    cassette_count = 0;
    return_state = .{};
    invalidateFrame();
    hideObjects();

    const data = rooms[room_index].cassettes;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_cassettes);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;
        const global_id = collectibles.cassetteId(room_index, source_index) orelse continue;
        const collected_before_run = collectibles.wasCassetteCollectedBeforeRun(global_id);
        if (!collected_before_run and collectibles.isCassetteCollected(global_id)) continue;
        cassettes[cassette_count] = .{
            .active = true,
            .collected = collected_before_run,
            .global_id = global_id,
            .center_x = readI16Le(data, source_offset),
            .center_y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
        };
        cassette_count += 1;
    }
}

pub fn loadGraphics() void {
    if (!hasVisibleSprites()) return;
    loaded_palette = .invalid;
    bubble_tiles_loaded = false;
    loadCassettePalette();
    invalidateFrame();
}

pub fn invalidateGraphics() void {
    loaded_palette = .invalid;
    bubble_tiles_loaded = false;
    invalidateFrame();
}

pub fn update(player: *Player, room_index: usize) void {
    if (return_state.active) return;

    var index: usize = 0;
    while (index < cassette_count) : (index += 1) {
        const cassette = &cassettes[index];
        if (!cassette.active or cassette.collected) continue;
        if (!playerTouchesCassette(player.*, cassette.*)) continue;
        startReturn(player, room_index, cassette, cassette.global_id);
        return;
    }
}

pub fn updateCutscene(player: *Player, room_index: usize) bool {
    if (!return_state.active or return_state.room_index != room_index) return false;

    lockPlayer(player);
    const progress = easeProgress(return_state.timer, return_frames);
    player.x = lerpFixed(return_state.start_x, return_state.target_x, progress);
    player.y = lerpFixed(return_state.start_y, return_state.target_y, progress);
    return_state.draw_x = fixedToPixel(player.x);
    return_state.draw_y = fixedToPixel(player.y);

    if (return_state.timer < return_frames) {
        return_state.timer += 1;
        return true;
    }

    player.x = return_state.target_x;
    player.y = return_state.target_y;
    return_state.draw_x = fixedToPixel(player.x);
    return_state.draw_y = fixedToPixel(player.y);
    return_state = .{};
    setDarkened(room_index, false);
    return true;
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (!hasVisibleSprites() and last_drawn_objects == 0) return;

    if (return_state.active) {
        loadBubbleGraphics();
        drawBubble(first_object, camera);
        var object_offset: usize = 1;
        const hide_until = @min(last_drawn_objects, object_capacity);
        while (object_offset < hide_until) : (object_offset += 1) {
            hideObject(first_object + object_offset);
        }
        last_drawn_objects = 1;
        return;
    }

    loadCassettePalette();

    var object_offset: usize = 0;
    var index: usize = 0;
    while (index < cassette_count and object_offset < object_capacity) : (index += 1) {
        const cassette = cassettes[index];
        if (!cassette.active) continue;

        const frame_count = if (cassette.collected) meta.collected_frame_count else meta.uncollected_frame_count;
        const frame = loopFrame(anim_counter, frame_count, frame_ticks);
        const x = cassette.center_x - @divTrunc(meta.cell_width, 2) - camera.x;
        const y = cassette.center_y - @divTrunc(meta.cell_height, 2) - camera.y;
        if (!visible(x, y, meta.cell_width, meta.cell_height)) continue;

        loadFrame(frame, cassette.collected);
        gba.display.objects[first_object + object_offset] = gba.display.Object.init(.{
            .size = .size_32x16,
            .x = objX(x),
            .y = objY(y),
            .base_tile = base_tile,
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

pub fn resetPaletteState() void {
    bg_darkened = false;
}

pub fn abortReturn(room_index: usize) void {
    if (bg_darkened) {
        setDarkened(room_index, false);
    }
    return_state = .{};
}

fn hasVisibleSprites() bool {
    if (return_state.active) return true;
    var index: usize = 0;
    while (index < cassette_count) : (index += 1) {
        if (cassettes[index].active) return true;
    }
    return false;
}

fn startReturn(player: *Player, room_index: usize, cassette: *Cassette, global_id: u16) void {
    cassette.active = false;
    if (collectibles.markCassetteCollected(global_id)) {
        save.commitProgress();
    }

    player.dashes = 1;
    player.dash_refill_cooldown_timer = 0;
    player.stamina = player_mod.climb_max_stamina;
    player.hair_initialized = false;

    const target = rooms[room_index].spawn;
    return_state = .{
        .active = true,
        .room_index = room_index,
        .start_x = player.x,
        .start_y = player.y,
        .target_x = pixelToFixed(target.x),
        .target_y = pixelToFixed(target.y),
        .draw_x = fixedToPixel(player.x),
        .draw_y = fixedToPixel(player.y),
    };
    setDarkened(return_state.room_index, true);
}

fn lockPlayer(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    player.moving = false;
    player.grounded = true;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_effect_timer = 0;
    player.dash_trail_timer = 0;
    player.force_move_x_timer = 0;
    player.lift_boost_timer = 0;
}

fn playerTouchesCassette(player: Player, cassette: Cassette) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const half_w: i16 = @as(i16, @intCast(cassette.w / 2));
    const half_h: i16 = @as(i16, @intCast(cassette.h / 2));
    return collision.rectsOverlap(
        player_left,
        player_top,
        player_left + player_mod.body_width,
        player_top + player_mod.body_height,
        cassette.center_x - half_w,
        cassette.center_y - half_h,
        cassette.center_x + half_w,
        cassette.center_y + half_h,
    );
}

fn loadFrame(frame: u16, collected: bool) void {
    if (loaded_frame == frame and loaded_collected == collected) return;
    const tile_data = if (collected) &collected_tiles_data else &uncollected_tiles_data;
    const byte_offset = @as(usize, frame) * @as(usize, meta.tiles_per_frame) * 32;
    const byte_len = @as(usize, meta.tiles_per_frame) * 32;
    const frame_bytes = tile_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_frame = frame;
    loaded_collected = collected;
}

fn loadCassettePalette() void {
    if (loaded_palette == .cassette) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    loaded_palette = .cassette;
}

fn loadBubbleGraphics() void {
    if (loaded_palette != .bubble) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&bubble_palette_data), 16);
        loaded_palette = .bubble;
    }
    if (!bubble_tiles_loaded) {
        gba.display.memcpyObjectTiles4Bpp(bubble_base_tile, @ptrCast(&bubble_tiles_data));
        bubble_tiles_loaded = true;
    }
}

fn drawBubble(object_index: usize, camera: Camera) void {
    const x = return_state.draw_x + player_mod.body_width / 2 - @divTrunc(meta.bubble_cell_width, 2) - camera.x;
    const y = return_state.draw_y + player_mod.body_height / 2 - @divTrunc(meta.bubble_cell_height, 2) - camera.y;
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(x),
        .y = objY(y),
        .base_tile = bubble_base_tile,
        .priority = 0,
        .palette = palette_bank,
    });
}

fn invalidateFrame() void {
    loaded_frame = invalid_frame;
    loaded_collected = false;
}

fn easeProgress(timer: u8, duration: u8) i32 {
    const clamped = @min(timer, duration);
    const t = @divTrunc(@as(i32, clamped) * math.fixed_one, @as(i32, duration));
    const t2 = @divTrunc(t * t, math.fixed_one);
    const t3 = @divTrunc(t2 * t, math.fixed_one);
    return 3 * t2 - 2 * t3;
}

fn lerpFixed(start: i32, end: i32, progress: i32) i32 {
    return start + @as(i32, @intCast(@divTrunc(@as(i64, end - start) * progress, math.fixed_one)));
}

fn loopFrame(anim_counter: u16, frame_count: u16, ticks: u16) u16 {
    if (frame_count == 0 or ticks == 0) return 0;
    return @mod(@divTrunc(anim_counter, ticks), frame_count);
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < screen_width and y < screen_height and x + width > 0 and y + height > 0;
}

fn setDarkened(room_index: usize, enabled: bool) void {
    if (bg_darkened == enabled) return;
    bg_darkened = enabled;
    applyRoomPaletteWithMood(room_index, enabled);
}

fn applyRoomPaletteWithMood(room_index: usize, dark: bool) void {
    const room = rooms[room_index];
    const color_count = @min(room.palette.len / 2, @as(usize, 256));
    var index: usize = 0;
    while (index < color_count) : (index += 1) {
        const color: gba.ColorRgb555 = @bitCast(readU16Le(room.palette, index * 2));
        gba.display.bg_palette.colors[index] = if (dark) darkenColor(color) else color;
    }
    gba.display.bg_palette.colors[background.static_wire_bg_color_index] = if (dark)
        darkenColor(gba.ColorRgb555.rgb(13, 14, 18))
    else
        gba.ColorRgb555.rgb(13, 14, 18);
}

fn darkenColor(color: gba.ColorRgb555) gba.ColorRgb555 {
    const r: u8 = @intCast(color.r);
    const g: u8 = @intCast(color.g);
    const b: u8 = @intCast(color.b);
    return gba.ColorRgb555.rgb(
        @intCast(@divTrunc(r * 2, 3)),
        @intCast(@divTrunc(g * 2, 3)),
        @intCast(@divTrunc(b * 2, 3)),
    );
}
