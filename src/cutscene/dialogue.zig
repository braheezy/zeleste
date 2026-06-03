const gba = @import("gba");
const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const dust = @import("../effects/dust.zig");
const math = @import("../core/math.zig");
const oam = @import("../core/oam.zig");
const room_data = @import("../world/room_data.zig");
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

const portrait_tiles_data align(4) = assets.granny_portrait_tiles_data;
const portrait_palette_data align(4) = assets.granny_portrait_palette_data;

pub const Cache = struct {
    rendered_index: u8 = 255,
    rendered_offset: usize = 0xffff,
    rendered_reveal_offset: usize = 0xffff,
    rendered_portrait: DialoguePortrait = .none,

    pub fn invalidate(self: *Cache) void {
        self.* = .{};
    }
};

pub const cols = 6;
pub const rows = 3;
pub const portrait_object_count = 1;
pub const box_object_count = cols * rows;
pub const object_count = portrait_object_count + box_object_count;
pub const width = cols * 32;
pub const height = rows * 16;
pub const tiles_per_object = 8;
pub const tile_count = box_object_count * tiles_per_object;
pub const base_tile: u10 = 848;
pub const portrait_tile_count: u10 = 16;
pub const portrait_base_tile: u10 = base_tile - portrait_tile_count;
pub const palette_bank: u4 = dust.palette_bank;
pub const portrait_palette_bank: u4 = 13;
pub const text_max_chars = 30;
pub const text_max_lines = 3;

const madeline_name_color: u8 = 7;
const granny_name_color: u8 = 8;
const default_name_color: u8 = 3;
const portrait_text_max_chars = 23;
const text_x: i16 = 6;
const portrait_text_x: i16 = 48;
const name_y: i16 = 4;
const body_y: i16 = 17;
const portrait_x: i16 = 4;
const portrait_y: i16 = 8;
const portrait_frame_ticks: u16 = 8;

var visible: bool = false;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var loaded_portrait_frame: u16 = 0xffff;
var portrait_palette_loaded: bool = false;

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
        cache.rendered_portrait == page.portrait)
    {
        return page_end;
    }

    clearTiles();
    drawBox(layout.has_portrait);
    text_mod.drawLine(setPixel, width, page.speaker, layout.text_start_x, name_y, speakerNameColor(page.speaker));
    text_mod.drawWrappedUntil(setPixel, width, page.text, dialogue_offset, reveal_end, layout.text_start_x, body_y, layout.max_chars, text_max_lines, 1);
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
    cache.* = .{
        .rendered_index = dialogue_index,
        .rendered_offset = dialogue_offset,
        .rendered_reveal_offset = reveal_end,
        .rendered_portrait = page.portrait,
    };
    return page_end;
}

pub fn wrappedNextOffset(page: CutsceneDialoguePage, dialogue_offset: usize) usize {
    return text_mod.wrappedNextOffset(page.text, dialogue_offset, layoutFor(page).max_chars, text_max_lines);
}

pub fn drawObjects(camera: Camera, first_object: usize, dialogue_box: SceneRect, page: CutsceneDialoguePage, anim_counter: u16) void {
    const has_portrait = portraitRange(page.portrait) != null;
    const position = room_data.Spawn{
        .x = clampI16(dialogue_box.x - camera.x, 0, video.screen_width - width),
        .y = clampI16(dialogue_box.y - camera.y, 0, video.screen_height - height),
    };
    if (has_portrait) {
        drawPortrait(portraitObject(first_object), position, page.portrait, anim_counter);
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
}

fn speakerNameColor(speaker: []const u8) u8 {
    if (text_mod.startsWith(speaker, "Madeline")) return madeline_name_color;
    if (text_mod.startsWith(speaker, "Old") or text_mod.startsWith(speaker, "Granny")) return granny_name_color;
    return default_name_color;
}

fn clearTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
}

fn drawBox(has_portrait: bool) void {
    var y: i16 = 0;
    while (y < height) : (y += 1) {
        var x: i16 = 0;
        while (x < width) : (x += 1) {
            const border = x == 0 or y == 0 or x == width - 1 or y == height - 1;
            setPixel(x, y, if (border) 1 else 6);
        }
    }
    var x: i16 = 4;
    while (x < width - 4) : (x += 1) {
        setPixel(x, 14, 1);
    }
    if (has_portrait) {
        y = 4;
        while (y < height - 4) : (y += 1) {
            setPixel(42, y, 1);
        }
    }
}

const Layout = struct {
    has_portrait: bool,
    text_start_x: i16,
    max_chars: usize,
};

fn layoutFor(page: CutsceneDialoguePage) Layout {
    const has_portrait = portraitRange(page.portrait) != null;
    return .{
        .has_portrait = has_portrait,
        .text_start_x = if (has_portrait) portrait_text_x else text_x,
        .max_chars = if (has_portrait) portrait_text_max_chars else text_max_chars,
    };
}

const PortraitRange = struct {
    first_frame: u16,
    frame_count: u16,
};

fn portraitRange(portrait: DialoguePortrait) ?PortraitRange {
    return switch (portrait) {
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
    if ((local_x & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xF0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0F) | (color << 4);
    }
}
