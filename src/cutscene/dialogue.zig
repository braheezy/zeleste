const gba = @import("gba");
const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const dust = @import("../effects/dust.zig");
const math = @import("../core/math.zig");
const oam = @import("../core/oam.zig");
const room_data = @import("../world/room_data.zig");
const save_indicator = @import("../core/save_indicator.zig");
const text_mod = @import("../core/text.zig");
const video = @import("../core/video.zig");

const Camera = camera_mod.Camera;
const CutsceneDialoguePage = room_data.CutsceneDialoguePage;
const DialoguePortrait = room_data.DialoguePortrait;
const SceneRect = room_data.SceneRect;
const clampI16 = math.clampI16;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const portrait_meta = assets.granny_portrait_meta;
const textbox_meta = assets.textbox_meta;

const portrait_tiles_data align(4) = assets.granny_portrait_tiles_data;
const portrait_palette_data align(4) = assets.granny_portrait_palette_data;
const textbox_tiles_data align(4) = assets.textbox_tiles_data;
const textbox_palette_data align(4) = assets.textbox_palette_data;

pub const Cache = struct {
    rendered_index: u8 = 255,
    rendered_offset: usize = 0xffff,
    rendered_reveal_offset: usize = 0xffff,
    rendered_portrait: DialoguePortrait = .none,

    pub fn invalidate(self: *Cache) void {
        self.* = .{};
    }
};

pub const cols = textbox_meta.cols;
pub const rows = textbox_meta.rows;
pub const portrait_object_count = 1;
pub const box_object_count = cols * rows;
pub const object_count = portrait_object_count + box_object_count;
pub const width = textbox_meta.width;
pub const height = textbox_meta.height;
pub const tiles_per_object = textbox_meta.tiles_per_object;
pub const tile_count = textbox_meta.tile_count;
pub const base_tile: u10 = 800;
pub const portrait_tile_count: u10 = 16;
pub const portrait_base_tile: u10 = base_tile - portrait_tile_count;
pub const palette_bank: u4 = dust.palette_bank;
pub const portrait_palette_bank: u4 = 13;
pub const text_max_chars = 34;
pub const text_max_lines = 3;

const madeline_name_color: u8 = textbox_meta.madeline_name_color;
const granny_name_color: u8 = textbox_meta.granny_name_color;
const default_name_color: u8 = textbox_meta.default_name_color;
const body_text_color: u8 = textbox_meta.body_text_color;
const portrait_text_max_chars = 26;
const text_x: i16 = 16;
const portrait_text_x: i16 = 56;
const name_y: i16 = 13;
const body_y: i16 = 28;
const portrait_x: i16 = 10;
const portrait_y: i16 = 16;
const portrait_frame_ticks: u16 = 8;

var visible: bool = false;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var text_tiles_dirty: [tile_count]bool = [_]bool{false} ** tile_count;
var upload_tiles_dirty: [tile_count]bool = [_]bool{false} ** tile_count;
var textbox_tiles_loaded: bool = false;
var loaded_portrait_frame: u16 = 0xffff;
var portrait_palette_loaded: bool = false;

pub fn invalidateGraphics() void {
    textbox_tiles_loaded = false;
    loaded_portrait_frame = 0xffff;
    portrait_palette_loaded = false;
}

pub fn renderPage(page: CutsceneDialoguePage, dialogue_index: u8, dialogue_offset: usize, dialogue_reveal_offset: usize, typewriter: bool, cache: *Cache) usize {
    const layout = layoutFor(page);
    const page_end = wrappedNextOffset(page, dialogue_offset);
    const reveal_end = if (typewriter)
        @min(dialogue_reveal_offset, page_end)
    else
        page_end;
    if (cache.rendered_index == dialogue_index and
        cache.rendered_offset == dialogue_offset and
        cache.rendered_reveal_offset == reveal_end and
        cache.rendered_portrait == effectivePortrait(page))
    {
        return page_end;
    }

    preloadTextbox();
    beginTextTileUpdate();
    text_mod.drawLine(setPixel, width, page.speaker, layout.text_start_x, name_y, speakerNameColor(page.speaker));
    text_mod.drawWrappedUntil(setPixel, width, page.text, dialogue_offset, reveal_end, layout.text_start_x, body_y, layout.max_chars, text_max_lines, body_text_color);
    uploadDirtyTextTiles();
    cache.* = .{
        .rendered_index = dialogue_index,
        .rendered_offset = dialogue_offset,
        .rendered_reveal_offset = reveal_end,
        .rendered_portrait = effectivePortrait(page),
    };
    return page_end;
}

pub fn wrappedNextOffset(page: CutsceneDialoguePage, dialogue_offset: usize) usize {
    return text_mod.wrappedNextOffset(page.text, dialogue_offset, layoutFor(page).max_chars, text_max_lines);
}

pub fn preloadTextbox() void {
    if (textbox_tiles_loaded) return;
    resetTextboxGraphics();
}

pub fn resetTextboxGraphics() void {
    loadTextboxPalette();
    loadStaticTextboxTiles();
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
    text_tiles_dirty = [_]bool{false} ** tile_count;
    upload_tiles_dirty = [_]bool{false} ** tile_count;
    textbox_tiles_loaded = true;
}

pub fn preloadPortrait(page: CutsceneDialoguePage, anim_counter: u16) void {
    const portrait = effectivePortrait(page);
    if (portraitRange(portrait) == null) return;
    loadPortraitPalette();
    loadPortraitFrame(portrait, anim_counter, false);
}

pub fn drawObjects(camera: Camera, first_object: usize, dialogue_box: SceneRect, page: CutsceneDialoguePage, anim_counter: u16) void {
    const portrait = effectivePortrait(page);
    const has_portrait = portraitRange(portrait) != null;
    const position = room_data.Spawn{
        .x = clampI16(dialogue_box.x - camera.x, 0, video.screen_width - width),
        .y = clampI16(dialogue_box.y - camera.y, 0, video.screen_height - height),
    };
    if (has_portrait) {
        drawPortrait(portraitObject(first_object), position, portrait, anim_counter);
    } else {
        hideObject(portraitObject(first_object));
    }

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const object_index = boxObject(first_object, row, col);
            const tile_index: u10 = @intCast((row * cols + col) * tiles_per_object);
            gba.display.objects[object_index] = gba.display.Object.init(.{
                .size = .size_32x16,
                .x = objX(position.x + @as(i16, @intCast(col * 32))),
                .y = objY(position.y + @as(i16, @intCast(row * 16))),
                .base_tile = base_tile + tile_index,
                .priority = 0,
                .palette = palette_bank,
            });
        }
    }
    visible = true;
}

pub fn hideObjects(first_object: usize) void {
    if (!visible) return;
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        hideObject(first_object + index);
    }
    visible = false;
    dust.loadPalette();
    save_indicator.invalidateGraphics();
}

fn speakerNameColor(speaker: []const u8) u8 {
    if (text_mod.startsWith(speaker, "Madeline")) return madeline_name_color;
    if (text_mod.startsWith(speaker, "Old") or text_mod.startsWith(speaker, "Granny")) return granny_name_color;
    return default_name_color;
}

fn clearTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
}

fn loadTextboxPalette() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&textbox_palette_data), 16);
}

fn loadStaticTextboxTiles() void {
    const source: [*]align(4) const gba.display.Tile4Bpp = @ptrCast(&textbox_tiles_data);
    var index: usize = 0;
    while (index < tile_count) : (index += 1) {
        tiles[index] = source[index];
    }
}

fn restoreStaticTextboxTile(index: usize) void {
    const source: [*]align(4) const gba.display.Tile4Bpp = @ptrCast(&textbox_tiles_data);
    tiles[index] = source[index];
}

fn beginTextTileUpdate() void {
    upload_tiles_dirty = [_]bool{false} ** tile_count;
    var index: usize = 0;
    while (index < tile_count) : (index += 1) {
        if (!text_tiles_dirty[index]) continue;
        restoreStaticTextboxTile(index);
        upload_tiles_dirty[index] = true;
        text_tiles_dirty[index] = false;
    }
}

fn uploadDirtyTextTiles() void {
    var index: usize = 0;
    while (index < tile_count) {
        if (!upload_tiles_dirty[index]) {
            index += 1;
            continue;
        }

        const start = index;
        while (index < tile_count and upload_tiles_dirty[index]) : (index += 1) {}
        gba.display.memcpyObjectTiles4Bpp(
            base_tile + @as(u10, @intCast(start)),
            tiles[start..index],
        );
    }
}

const Layout = struct {
    has_portrait: bool,
    text_start_x: i16,
    max_chars: usize,
};

fn layoutFor(page: CutsceneDialoguePage) Layout {
    const has_portrait = portraitRange(effectivePortrait(page)) != null;
    return .{
        .has_portrait = has_portrait,
        .text_start_x = if (has_portrait) portrait_text_x else text_x,
        .max_chars = if (has_portrait) portrait_text_max_chars else text_max_chars,
    };
}

fn effectivePortrait(page: CutsceneDialoguePage) DialoguePortrait {
    if (page.portrait != .none) return page.portrait;
    return .madeline_idle;
}

const PortraitRange = struct {
    first_frame: u16,
    frame_count: u16,
};

fn portraitRange(portrait: DialoguePortrait) ?PortraitRange {
    return switch (portrait) {
        .madeline_idle => .{
            .first_frame = portrait_meta.madeline_idle_first_frame,
            .frame_count = portrait_meta.madeline_idle_frame_count,
        },
        .granny_normal => .{
            .first_frame = portrait_meta.normal_first_frame,
            .frame_count = portrait_meta.normal_frame_count,
        },
        .granny_mock => .{
            .first_frame = portrait_meta.mock_first_frame,
            .frame_count = portrait_meta.mock_frame_count,
        },
        .granny_laugh => .{
            .first_frame = portrait_meta.laugh_first_frame,
            .frame_count = portrait_meta.laugh_frame_count,
        },
        else => null,
    };
}

fn drawPortrait(first_object: usize, position: room_data.Spawn, portrait: DialoguePortrait, anim_counter: u16) void {
    loadPortraitPalette();
    loadPortraitFrame(portrait, anim_counter, false);
    gba.display.objects[first_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(position.x + portrait_x),
        .y = objY(position.y + portrait_y),
        .base_tile = portrait_base_tile,
        .priority = 0,
        .palette = portrait_palette_bank,
    });
}

fn portraitObject(first_object: usize) usize {
    return first_object;
}

fn boxObject(first_object: usize, row: usize, col: usize) usize {
    return first_object + portrait_object_count + row * cols + col;
}

fn loadPortraitPalette() void {
    if (portrait_palette_loaded) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, portrait_palette_bank) * 16], @ptrCast(&portrait_palette_data), 16);
    portrait_palette_loaded = true;
}

fn loadPortraitFrame(portrait: DialoguePortrait, anim_counter: u16, force: bool) void {
    const range = portraitRange(portrait) orelse return;
    if (range.frame_count == 0) return;

    const local_frame: u16 = @intCast((anim_counter / portrait_frame_ticks) % range.frame_count);
    const frame = range.first_frame + local_frame;
    if (!force and loaded_portrait_frame == frame) return;

    const bytes_per_frame = @as(usize, portrait_tile_count) * @sizeOf(gba.display.Tile4Bpp);
    const start = @as(usize, frame) * bytes_per_frame;
    const frame_bytes = portrait_tiles_data[start .. start + bytes_per_frame];
    gba.display.memcpyObjectTiles4Bpp(portrait_base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_portrait_frame = frame;
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= width or y < 0 or y >= height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const chunk_x = ux / 32;
    const chunk_y = uy / 16;
    const chunk_index = chunk_y * cols + chunk_x;
    const tile_x = (ux & 31) / 8;
    const tile_y = (uy & 15) / 8;
    const local_x = ux & 7;
    const local_y = uy & 7;
    const tile_index = chunk_index * tiles_per_object + tile_y * 4 + tile_x;
    const byte_index = local_y * 4 + local_x / 2;
    text_tiles_dirty[tile_index] = true;
    upload_tiles_dirty[tile_index] = true;
    if ((local_x & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xF0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0F) | (color << 4);
    }
}
