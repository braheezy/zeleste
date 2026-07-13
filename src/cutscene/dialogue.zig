const gba = @import("gba");
const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
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
const ch1_textbox_tiles_data align(4) = assets.ch1_textbox_tiles_data;
const ch1_textbox_palette_data align(4) = assets.ch1_textbox_palette_data;

pub const TextboxSkin = enum {
    prologue,
    chapter1,
};

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
const textbox_tile_range = obj_vram.dialogue_textbox;
const portrait_tile_range = obj_vram.dialogue_portrait;
pub const base_tile = textbox_tile_range.baseTile();
pub const portrait_tile_count = portrait_tile_range.count;
pub const portrait_base_tile = portrait_tile_range.baseTile();
pub const palette_bank: u4 = 15;
pub const portrait_palette_bank: u4 = 13;
pub const text_max_chars = 34;
pub const text_max_lines = 3;

const madeline_name_color: u8 = textbox_meta.madeline_name_color;
const granny_name_color: u8 = textbox_meta.granny_name_color;
const theo_name_color: u8 = textbox_meta.theo_name_color;
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
const box_offset_x: i16 = -24;
const box_offset_y: i16 = 2;
const advance_indicator_x: i16 = 207;
const advance_indicator_y: i16 = 55;
const advance_indicator_width: i16 = 5;
const advance_indicator_height: i16 = 3;
const advance_indicator_bob_ticks: u16 = 32;

var visible: bool = false;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var text_tiles_dirty: [tile_count]bool = [_]bool{false} ** tile_count;
var upload_tiles_dirty: [tile_count]bool = [_]bool{false} ** tile_count;
var textbox_tiles_loaded: bool = false;
var active_textbox_skin: TextboxSkin = .prologue;
var loaded_textbox_skin: TextboxSkin = .prologue;
var portrait_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var portrait_palette_loaded: bool = false;
var advance_indicator_visible: bool = false;
var advance_indicator_frame: u8 = 0xff;

pub fn invalidateGraphics() void {
    textbox_tiles_loaded = false;
    portrait_frame_cache.invalidate();
    portrait_palette_loaded = false;
    advance_indicator_visible = false;
    advance_indicator_frame = 0xff;
}

pub fn setTextboxSkin(skin: TextboxSkin) void {
    if (active_textbox_skin == skin) return;
    active_textbox_skin = skin;
    textbox_tiles_loaded = false;
    advance_indicator_visible = false;
    advance_indicator_frame = 0xff;
}

pub fn renderPage(page: CutsceneDialoguePage, dialogue_index: u8, dialogue_offset: usize, dialogue_reveal_offset: usize, typewriter: bool, cache: *Cache) usize {
    _ = typewriter;
    const layout = layoutFor(page);
    const page_end = wrappedNextOffset(page, dialogue_offset);
    const reveal_end = @min(dialogue_reveal_offset, page_end);
    if (cache.rendered_index == dialogue_index and
        cache.rendered_offset == dialogue_offset and
        cache.rendered_reveal_offset == reveal_end and
        cache.rendered_portrait == effectivePortrait(page))
    {
        return page_end;
    }

    preloadTextbox();
    const same_page = cache.rendered_index == dialogue_index and
        cache.rendered_offset == dialogue_offset and
        cache.rendered_portrait == effectivePortrait(page);
    if (same_page and cache.rendered_reveal_offset <= reveal_end) {
        upload_tiles_dirty = [_]bool{false} ** tile_count;
        text_mod.drawWrappedBetween(setPixel, width, page.text, dialogue_offset, cache.rendered_reveal_offset, reveal_end, layout.text_start_x, body_y, layout.max_chars, text_max_lines, body_text_color);
        uploadDirtyTextTiles();
        cache.rendered_reveal_offset = reveal_end;
        return page_end;
    }

    beginTextTileUpdate();
    advance_indicator_visible = false;
    advance_indicator_frame = 0xff;
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
    if (textbox_tiles_loaded and loaded_textbox_skin == active_textbox_skin) return;
    resetTextboxGraphics();
}

pub fn resetTextboxGraphics() void {
    loadTextboxPalette();
    loadStaticTextboxTiles();
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
    text_tiles_dirty = [_]bool{false} ** tile_count;
    upload_tiles_dirty = [_]bool{false} ** tile_count;
    textbox_tiles_loaded = true;
    loaded_textbox_skin = active_textbox_skin;
    advance_indicator_visible = false;
    advance_indicator_frame = 0xff;
}

pub fn preloadPortrait(page: CutsceneDialoguePage, portrait_timer: u16, text_revealing: bool) void {
    const portrait = effectivePortrait(page);
    if (portraitRange(portrait) == null) return;
    loadPortraitPalette();
    loadPortraitFrame(portrait, portrait_timer, text_revealing);
}

pub fn drawObjects(camera: Camera, first_object: usize, dialogue_box: SceneRect, page: CutsceneDialoguePage, portrait_timer: u16, text_revealing: bool) void {
    loadTextboxPalette();
    const portrait = effectivePortrait(page);
    const has_portrait = portraitRange(portrait) != null;
    const position = room_data.Spawn{
        .x = clampI16(dialogue_box.x - camera.x + box_offset_x, 0, video.screen_width - width),
        .y = clampI16(dialogue_box.y - camera.y + box_offset_y, 0, video.screen_height - height),
    };
    updateAdvanceIndicator(!text_revealing, portrait_timer);
    if (has_portrait) {
        drawPortrait(portraitObject(first_object), position, portrait, portrait_timer, text_revealing);
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
    advance_indicator_visible = false;
    advance_indicator_frame = 0xff;
    save_indicator.invalidateGraphics();
}

fn speakerNameColor(speaker: []const u8) u8 {
    if (text_mod.startsWith(speaker, "Madeline")) return madeline_name_color;
    if (text_mod.startsWith(speaker, "Old") or text_mod.startsWith(speaker, "Granny")) return granny_name_color;
    if (text_mod.startsWith(speaker, "Theo")) return theo_name_color;
    return default_name_color;
}

fn clearTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
}

fn loadTextboxPalette() void {
    const palette_data = switch (active_textbox_skin) {
        .prologue => &textbox_palette_data,
        .chapter1 => &ch1_textbox_palette_data,
    };
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(palette_data), 16);
}

fn loadStaticTextboxTiles() void {
    const source: [*]align(4) const gba.display.Tile4Bpp = @ptrCast(textboxTileData());
    var index: usize = 0;
    while (index < tile_count) : (index += 1) {
        tiles[index] = source[index];
    }
}

fn restoreStaticTextboxTile(index: usize) void {
    const source: [*]align(4) const gba.display.Tile4Bpp = @ptrCast(textboxTileData());
    tiles[index] = source[index];
}

fn textboxTileData() *const [tile_count]gba.display.Tile4Bpp {
    return switch (active_textbox_skin) {
        .prologue => @ptrCast(&textbox_tiles_data),
        .chapter1 => @ptrCast(&ch1_textbox_tiles_data),
    };
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
        var clear_index = start;
        while (clear_index < index) : (clear_index += 1) {
            upload_tiles_dirty[clear_index] = false;
        }
    }
}

fn updateAdvanceIndicator(show: bool, anim_timer: u16) void {
    const next_frame: u8 = if (show) @intCast((anim_timer / advance_indicator_bob_ticks) & 1) else 0xff;
    if (advance_indicator_visible == show and advance_indicator_frame == next_frame) return;

    if (advance_indicator_visible) {
        restoreAdvanceIndicatorTiles();
    }
    advance_indicator_visible = false;
    advance_indicator_frame = 0xff;

    if (show) {
        drawAdvanceIndicator(next_frame);
        advance_indicator_visible = true;
        advance_indicator_frame = next_frame;
    }
    uploadDirtyTextTiles();
}

fn restoreAdvanceIndicatorTiles() void {
    const min_x = advance_indicator_x;
    const max_x = advance_indicator_x + advance_indicator_width - 1;
    const min_y = advance_indicator_y;
    const max_y = advance_indicator_y + advance_indicator_height;
    const start_tile_x: usize = @intCast(@divTrunc(min_x, 8));
    const end_tile_x: usize = @intCast(@divTrunc(max_x, 8));
    const start_tile_y: usize = @intCast(@divTrunc(min_y, 8));
    const end_tile_y: usize = @intCast(@divTrunc(max_y, 8));

    var tile_y = start_tile_y;
    while (tile_y <= end_tile_y) : (tile_y += 1) {
        var tile_x = start_tile_x;
        while (tile_x <= end_tile_x) : (tile_x += 1) {
            const chunk_x = tile_x / 4;
            const chunk_y = tile_y / 2;
            const tile_index = (chunk_y * cols + chunk_x) * tiles_per_object + (tile_y & 1) * 4 + (tile_x & 3);
            restoreStaticTextboxTile(tile_index);
            upload_tiles_dirty[tile_index] = true;
            text_tiles_dirty[tile_index] = false;
        }
    }
}

fn drawAdvanceIndicator(frame: u8) void {
    const y = advance_indicator_y + @as(i16, frame);
    drawHorizontalLine(advance_indicator_x, y, advance_indicator_width, body_text_color);
    drawHorizontalLine(advance_indicator_x + 1, y + 1, advance_indicator_width - 2, body_text_color);
    setPixel(advance_indicator_x + 2, y + 2, body_text_color);
}

fn drawHorizontalLine(x: i16, y: i16, len: i16, color: u8) void {
    var offset: i16 = 0;
    while (offset < len) : (offset += 1) {
        setPixel(x + offset, y, color);
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
    if (text_mod.startsWith(page.speaker, "Madeline")) return .madeline_idle;
    if (text_mod.startsWith(page.speaker, "Theo")) return .theo_normal;
    return .none;
}

const PortraitRange = struct {
    first_frame: u16,
    frame_count: u16,
    intro_frame_count: u16 = 0,
    talk_first_frame: u16 = 0,
    talk_frame_count: u16 = 0,
    loop: bool = false,
};

fn portraitRange(portrait: DialoguePortrait) ?PortraitRange {
    return switch (portrait) {
        .madeline_idle => .{
            .first_frame = portrait_meta.madeline_idle_first_frame,
            .frame_count = portrait_meta.madeline_idle_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .madeline_angry => .{
            .first_frame = portrait_meta.madeline_angry_first_frame,
            .frame_count = portrait_meta.madeline_angry_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .madeline_sad => .{
            .first_frame = portrait_meta.madeline_sad_first_frame,
            .frame_count = portrait_meta.madeline_sad_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .madeline_upset => .{
            .first_frame = portrait_meta.madeline_upset_first_frame,
            .frame_count = portrait_meta.madeline_upset_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .madeline_distracted_short => .{
            .first_frame = portrait_meta.madeline_distracted_short_first_frame,
            .frame_count = portrait_meta.madeline_distracted_short_frame_count,
        },
        .madeline_deadpan_noblink => .{
            .first_frame = portrait_meta.madeline_deadpan_noblink_first_frame,
            .frame_count = portrait_meta.madeline_deadpan_noblink_frame_count,
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
            .loop = true,
        },
        .granny_creep_a => .{
            .first_frame = portrait_meta.creep_a_first_frame,
            .frame_count = portrait_meta.creep_a_frame_count,
        },
        .granny_creep_b => .{
            .first_frame = portrait_meta.creep_b_first_frame,
            .frame_count = portrait_meta.creep_b_frame_count,
        },
        .theo_normal => .{
            .first_frame = portrait_meta.theo_normal_first_frame,
            .frame_count = portrait_meta.theo_normal_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 4,
        },
        .theo_excited => .{
            .first_frame = portrait_meta.theo_excited_first_frame,
            .frame_count = portrait_meta.theo_excited_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .theo_serious => .{
            .first_frame = portrait_meta.theo_serious_first_frame,
            .frame_count = portrait_meta.theo_serious_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .theo_thinking => .{
            .first_frame = portrait_meta.theo_thinking_first_frame,
            .frame_count = portrait_meta.theo_thinking_frame_count,
            .talk_first_frame = 4,
            .talk_frame_count = 3,
        },
        .theo_nailed_it => .{
            .first_frame = portrait_meta.theo_nailed_it_first_frame,
            .frame_count = portrait_meta.theo_nailed_it_frame_count,
        },
        .theo_yolo => .{
            .first_frame = portrait_meta.theo_yolo_first_frame,
            .frame_count = portrait_meta.theo_yolo_frame_count,
            .talk_first_frame = 1,
            .talk_frame_count = 3,
        },
        else => null,
    };
}

fn drawPortrait(first_object: usize, position: room_data.Spawn, portrait: DialoguePortrait, portrait_timer: u16, text_revealing: bool) void {
    loadPortraitPalette();
    loadPortraitFrame(portrait, portrait_timer, text_revealing);
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

fn loadPortraitFrame(portrait: DialoguePortrait, portrait_timer: u16, text_revealing: bool) void {
    const range = portraitRange(portrait) orelse return;
    if (range.frame_count == 0) return;

    const local_frame = portraitLocalFrame(range, portrait_timer, text_revealing);
    const frame = range.first_frame + local_frame;
    portrait_frame_cache.upload4Bpp(portrait_tile_range, &portrait_tiles_data, frame, portrait_tile_count);
}

fn portraitLocalFrame(range: PortraitRange, portrait_timer: u16, text_revealing: bool) u16 {
    const timed_frame = portrait_timer / portrait_frame_ticks;
    if (range.loop) return timed_frame % range.frame_count;
    const intro_frame_count = if (range.intro_frame_count == 0) range.frame_count else @min(range.intro_frame_count, range.frame_count);
    if (timed_frame < intro_frame_count) return timed_frame;
    if (text_revealing and range.talk_frame_count > 0 and range.talk_first_frame + range.talk_frame_count <= range.frame_count) {
        return range.talk_first_frame + ((timed_frame - intro_frame_count) % range.talk_frame_count);
    }
    return intro_frame_count - 1;
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
