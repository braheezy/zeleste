const gba = @import("gba");

const assets = @import("../../core/assets.zig");
const audio = @import("../../core/audio.zig");
const camera_mod = @import("../../world/camera.zig");
const collectibles = @import("../../core/collectibles.zig");
const collision = @import("../../world/collision.zig");
const ending_data = @import("../../generated/assets/city/end_cutscene.zig");
const level = @import("../../generated_rooms.zig");
const math = @import("../../core/math.zig");
const oam = @import("../../core/oam.zig");
const obj_vram = @import("../../core/obj_vram.zig");
const player_mod = @import("../../player/state.zig");
const save = @import("../../core/save.zig");
const strawberries = @import("../../room/strawberries.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const sound_ids = assets.sound_ids;

const gold_idle_tiles_data align(4) = assets.goldberry_idle_tiles_data;
const gold_collect_tiles_data align(4) = assets.goldberry_collect_tiles_data;
const ghost_idle_tiles_data align(4) = assets.goldghostberry_idle_tiles_data;
const ghost_collect_tiles_data align(4) = assets.goldghostberry_collect_tiles_data;
const gold_palette_data align(4) = assets.goldberry_palette_data;
const gold_collect_palette_data align(4) = assets.goldberry_collect_palette_data;
const ghost_palette_data align(4) = assets.goldghostberry_palette_data;
const ghost_collect_palette_data align(4) = assets.goldghostberry_collect_palette_data;

const city_chapter: u8 = 1;
const end_room_index = level.roomIndexFor(level.chapter_index, "city_end") orelse level.rooms.len;
const object = strawberries.first_object + strawberries.object_capacity - 1;
const palette_bank: u4 = 8;
const collect_palette_bank: u4 = 9;
const normal_tile_range = obj_vram.strawberry_normal;
const ghost_tile_range = obj_vram.strawberry_ghost;
const idle_base_tile = normal_tile_range.baseTile();
const collect_base_tile = normal_tile_range.tile(idle_tiles_per_frame);
const ghost_idle_base_tile = ghost_tile_range.baseTile();
const ghost_collect_base_tile = ghost_tile_range.tile(idle_tiles_per_frame);
const idle_tiles_per_frame: u10 = 8;
const collect_tiles_per_frame: u10 = 8;
const gold_idle_frame_count: u16 = 32;
const ghost_idle_frame_count: u16 = 36;
const idle_frame_ticks: u16 = 4;
const collect_frame_count: u16 = 5;
const collect_frame_ticks: u16 = 3;
const cell_width: i16 = 32;
const cell_height: i16 = 16;
const collision_half_w: i16 = 9;
const collision_half_h: i16 = 8;

const PaletteVariant = enum {
    invalid,
    gold,
    ghost,
};

var active: bool = false;
var ghost: bool = false;
var collecting: bool = false;
var collect_timer: u8 = 0;
var center_x: i16 = 0;
var center_y: i16 = 0;
var golden_id: u16 = 0;
var gold_idle_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var ghost_idle_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var gold_collect_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var ghost_collect_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var loaded_main_palette: PaletteVariant = .invalid;
var loaded_collect_palette: PaletteVariant = .invalid;

pub fn load(room_index: usize) void {
    active = false;
    ghost = false;
    collecting = false;
    collect_timer = 0;
    hideObjects();

    if (room_index != end_room_index) return;
    if (!save.currentRunDeathlessForChapter(city_chapter)) return;

    const id = collectibles.goldenStrawberryId(city_chapter) orelse return;
    const collected_before_run = collectibles.wasGoldenStrawberryCollectedBeforeRun(id);
    if (!collected_before_run and collectibles.isGoldenStrawberryCollected(id)) return;

    golden_id = id;
    ghost = collected_before_run;
    center_x = ending_data.outro.trigger.x - 18;
    center_y = ending_data.outro.trigger.y + @divTrunc(ending_data.outro.trigger.h, 2);
    active = true;
}

pub fn loadGraphics(room_index: usize) void {
    if (room_index != end_room_index or !visibleState()) return;
    loadMainPalette();
    loadCollectPalette();
    invalidateFrames();
}

pub fn invalidateGraphics() void {
    loaded_main_palette = .invalid;
    loaded_collect_palette = .invalid;
    invalidateFrames();
}

pub fn update(player: *Player, room_index: usize) void {
    if (room_index != end_room_index) {
        hideObjects();
        return;
    }

    if (active and playerTouches(player.*)) {
        startCollect();
    }
    if (collecting) {
        if (collect_timer < collect_frame_count * collect_frame_ticks) {
            collect_timer += 1;
        } else {
            collecting = false;
            hideObjects();
        }
    }
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (!visibleState()) {
        hideObjects();
        return;
    }

    loadMainPalette();
    loadCollectPalette();

    const frame = if (collecting)
        collectFrame(collect_timer)
    else
        loopFrame(anim_counter, if (ghost) ghost_idle_frame_count else gold_idle_frame_count, idle_frame_ticks);
    drawObject(camera, if (collecting) .collect else .idle, frame);
}

pub fn handlePlayerDeathStart() void {
    active = false;
    collecting = false;
    hideObjects();
}

pub fn hideObjects() void {
    hideObject(object);
}

fn visibleState() bool {
    return active or collecting;
}

fn startCollect() void {
    active = false;
    collecting = true;
    collect_timer = 0;
    if (!ghost and collectibles.markGoldenStrawberryCollected(golden_id)) {
        save.commitProgress();
    }
    _ = audio.playSoundEffect(sound_ids.sfx_strawberry_red_get_1000);
}

fn playerTouches(player: Player) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;
    return collision.rectsOverlap(
        player_left,
        player_top,
        player_right,
        player_bottom,
        center_x - collision_half_w,
        center_y - collision_half_h,
        center_x + collision_half_w,
        center_y + collision_half_h,
    );
}

const Animation = enum {
    idle,
    collect,
};

fn drawObject(camera: Camera, animation: Animation, frame: u16) void {
    const x = center_x - @divTrunc(cell_width, 2) - camera.x;
    const y = center_y - @divTrunc(cell_height, 2) - camera.y;
    if (!visible(x, y, cell_width, cell_height)) {
        hideObjects();
        return;
    }

    loadAnimationFrame(animation, frame);
    gba.display.objects[object] = gba.display.Object.init(.{
        .size = .size_32x16,
        .x = objX(x),
        .y = objY(y),
        .base_tile = switch (animation) {
            .idle => if (ghost) ghost_idle_base_tile else idle_base_tile,
            .collect => if (ghost) ghost_collect_base_tile else collect_base_tile,
        },
        .priority = 1,
        .palette = if (animation == .collect) collect_palette_bank else palette_bank,
    });
}

fn loadAnimationFrame(animation: Animation, frame: u16) void {
    switch (animation) {
        .idle => {
            if (ghost) {
                ghost_idle_frame_cache.upload4Bpp(ghost_tile_range, &ghost_idle_tiles_data, frame, idle_tiles_per_frame);
            } else {
                gold_idle_frame_cache.upload4Bpp(normal_tile_range, &gold_idle_tiles_data, frame, idle_tiles_per_frame);
            }
        },
        .collect => {
            if (ghost) {
                ghost_collect_frame_cache.upload4BppAt(ghost_tile_range, idle_tiles_per_frame, &ghost_collect_tiles_data, frame, collect_tiles_per_frame);
            } else {
                gold_collect_frame_cache.upload4BppAt(normal_tile_range, idle_tiles_per_frame, &gold_collect_tiles_data, frame, collect_tiles_per_frame);
            }
        },
    }
}

fn loadMainPalette() void {
    const desired: PaletteVariant = if (ghost) .ghost else .gold;
    if (loaded_main_palette == desired) return;
    const data = if (ghost) &ghost_palette_data else &gold_palette_data;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(data), 16);
    loaded_main_palette = desired;
}

fn loadCollectPalette() void {
    const desired: PaletteVariant = if (ghost) .ghost else .gold;
    if (loaded_collect_palette == desired) return;
    const data = if (ghost) &ghost_collect_palette_data else &gold_collect_palette_data;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, collect_palette_bank) * 16], @ptrCast(data), 16);
    loaded_collect_palette = desired;
}

fn invalidateFrames() void {
    gold_idle_frame_cache.invalidate();
    ghost_idle_frame_cache.invalidate();
    gold_collect_frame_cache.invalidate();
    ghost_collect_frame_cache.invalidate();
}

fn loopFrame(anim_counter: u16, frame_count: u16, frame_ticks: u16) u16 {
    return (anim_counter / frame_ticks) % frame_count;
}

fn collectFrame(timer: u8) u16 {
    const frame = @as(u16, timer) / collect_frame_ticks;
    return if (frame >= collect_frame_count) collect_frame_count - 1 else frame;
}

fn visible(x: i16, y: i16, width: i16, height: i16) bool {
    return x < 240 and y < 160 and x + width > 0 and y + height > 0;
}
