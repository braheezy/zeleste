const gba = @import("gba");
const assets = @import("../core/assets.zig");
const background = @import("background.zig");
const oam = @import("../core/oam.zig");
const save = @import("../core/save.zig");
const video = @import("../core/video.zig");

const page0_tiles_data align(4) = assets.overworld_page0_tiles_data;
const page0_map_data align(4) = assets.overworld_page0_map_data;
const page0_palette_data align(4) = assets.overworld_page0_palette_data;
const page1_tiles_data align(4) = assets.overworld_page1_tiles_data;
const page1_map_data align(4) = assets.overworld_page1_map_data;
const page1_palette_data align(4) = assets.overworld_page1_palette_data;
const icon_tiles_data align(4) = assets.overworld_icon_tiles_data;
const icon_palette_data align(4) = assets.overworld_icon_palette_data;
const icon_meta = assets.overworld_icon_meta;

const bg_screenblock = video.bg_screenblock;
const bg_hardware_width_tiles = video.bg_hardware_width_tiles;
const bg_hardware_height_tiles = video.bg_hardware_height_tiles;
const width_tiles = 30;
const height_tiles = 20;

pub const Selection = enum(u8) {
    none,
    prologue,
    city,
};

const page_count: u8 = 2;
const prologue_chapter: u8 = 0;
const city_chapter: u8 = 1;
const icon_base_tile: u10 = 0;
const icon_first_object: usize = 0;
const cursor_object: usize = icon_first_object + icon_meta.max_icons_per_page;
const cursor_base_tile: u10 = 1000;
const cursor_palette_bank: u4 = 15;

var cursor_tiles: [4]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 4;
var selected_page: u8 = 0;
var selected_chapter: ?u8 = null;
var previous_horizontal: i16 = 0;
var previous_vertical: i16 = 0;
var confirm_released: bool = false;

pub fn cutToBlack() void {
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    gba.display.hideAllObjects();
    gba.display.bg_palette.colors[0] = .black;
}

pub fn loadScreen() void {
    gba.display.hideAllObjects();
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    background.clearParallaxMap();
    background.resetRoomStream();
    background.resetParallaxStream();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 1,
        .base_screenblock = bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });

    previous_horizontal = 0;
    previous_vertical = 0;
    confirm_released = false;
    selected_chapter = defaultChapter();
    selected_page = if (selected_chapter) |chapter| chapterInfo(chapter).page else 0;

    loadPage(selected_page);
    loadIcons();
    loadCursor();
    drawObjects();

    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = false,
        .obj = true,
    });
}

pub fn update(input: gba.input.BufferedKeysState) Selection {
    var changed = false;

    const horizontal: i16 = @intCast(input.getAxisHorizontal());
    if (horizontal < 0 and previous_horizontal >= 0) {
        changed = moveAlongPath(-1) or changed;
    } else if (horizontal > 0 and previous_horizontal <= 0) {
        changed = moveAlongPath(1) or changed;
    }
    previous_horizontal = horizontal;

    const vertical: i16 = @intCast(input.getAxisVertical());
    if (vertical < 0 and previous_vertical >= 0) {
        changed = moveAlongPath(1) or changed;
    } else if (vertical > 0 and previous_vertical <= 0) {
        changed = moveAlongPath(-1) or changed;
    }
    previous_vertical = vertical;

    if (input.isJustPressed(.L)) changed = previousPage() or changed;
    if (input.isJustPressed(.R)) changed = nextPage() or changed;

    if (changed) drawObjects();

    const confirm_down = input.isPressed(.A) or input.isPressed(.start);
    if (!confirm_down) confirm_released = true;
    if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.start))) {
        return currentSelection();
    }

    return .none;
}

fn loadPage(page: u8) void {
    if (page == 0) {
        gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&page0_palette_data), page0_palette_data.len);
        gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(&page0_tiles_data));
        drawMap(page0_map_data[0..]);
    } else {
        gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&page1_palette_data), page1_palette_data.len);
        gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(&page1_tiles_data));
        drawMap(page1_map_data[0..]);
    }
}

fn loadIcons() void {
    gba.mem.memcpy(gba.display.obj_palette, @ptrCast(&icon_palette_data), icon_palette_data.len);
    gba.display.memcpyObjectTiles4Bpp(icon_base_tile, @ptrCast(&icon_tiles_data));
}

fn defaultChapter() ?u8 {
    var fallback: ?u8 = null;
    var index: usize = 0;
    while (index < icon_meta.chapter_count) : (index += 1) {
        const chapter = icon_meta.chapters[index];
        if (!isChapterVisible(chapter)) continue;
        if (fallback == null) fallback = chapter.chapter;
        if (!save.isChapterCompleted(chapter.chapter)) return chapter.chapter;
    }
    return fallback;
}

fn currentSelection() Selection {
    const chapter = selected_chapter orelse return .none;
    const info = chapterInfo(chapter);
    if (!isChapterVisible(info)) return .none;
    return switch (chapter) {
        prologue_chapter => .prologue,
        city_chapter => .city,
        else => .none,
    };
}

fn moveAlongPath(direction: i8) bool {
    if (selected_chapter == null) {
        if (firstVisibleOnPage(selected_page)) |chapter| {
            selected_chapter = chapter;
            return true;
        }
        if (defaultChapter()) |chapter| {
            return selectChapter(chapter);
        }
        return false;
    }

    const start_index = chapterArrayIndex(selected_chapter.?) orelse return false;
    const step: isize = if (direction > 0) 1 else -1;
    var index: isize = @intCast(start_index);
    while (true) {
        index += step;
        if (index < 0 or index >= icon_meta.chapter_count) return false;
        const candidate = icon_meta.chapters[@as(usize, @intCast(index))];
        if (isChapterVisible(candidate)) return selectChapter(candidate.chapter);
    }
}

fn previousPage() bool {
    if (selected_page == 0) return false;
    selected_page -= 1;
    selected_chapter = firstVisibleOnPage(selected_page);
    loadPage(selected_page);
    return true;
}

fn nextPage() bool {
    if (selected_page + 1 >= page_count) return false;
    selected_page += 1;
    selected_chapter = firstVisibleOnPage(selected_page);
    loadPage(selected_page);
    return true;
}

fn selectChapter(chapter: u8) bool {
    const info = chapterInfo(chapter);
    if (!isChapterVisible(info)) return false;
    selected_chapter = chapter;
    if (selected_page == info.page) return true;
    selected_page = info.page;
    loadPage(selected_page);
    return true;
}

fn firstVisibleOnPage(page: u8) ?u8 {
    var index: usize = 0;
    while (index < icon_meta.chapter_count) : (index += 1) {
        const chapter = icon_meta.chapters[index];
        if (chapter.page == page and isChapterVisible(chapter)) return chapter.chapter;
    }
    return null;
}

fn isChapterVisible(chapter: icon_meta.Chapter) bool {
    if (!chapter.implemented) return false;
    if (chapter.chapter == 0) return true;
    return save.isChapterCompleted(chapter.chapter - 1) or
        save.isChapterCompleted(chapter.chapter) or
        save.isChapterUnlocked(chapter.chapter);
}

fn chapterInfo(chapter: u8) icon_meta.Chapter {
    var index: usize = 0;
    while (index < icon_meta.chapter_count) : (index += 1) {
        if (icon_meta.chapters[index].chapter == chapter) return icon_meta.chapters[index];
    }
    return icon_meta.chapters[0];
}

fn chapterArrayIndex(chapter: u8) ?usize {
    var index: usize = 0;
    while (index < icon_meta.chapter_count) : (index += 1) {
        if (icon_meta.chapters[index].chapter == chapter) return index;
    }
    return null;
}

fn drawObjects() void {
    var object_index: usize = 0;
    while (object_index < icon_meta.max_icons_per_page) : (object_index += 1) {
        oam.hideObject(icon_first_object + object_index);
    }
    oam.hideObject(cursor_object);

    object_index = 0;
    var index: usize = 0;
    while (index < icon_meta.chapter_count) : (index += 1) {
        const chapter = icon_meta.chapters[index];
        if (chapter.page != selected_page or !isChapterVisible(chapter)) continue;
        drawChapterIcon(icon_first_object + object_index, chapter);
        object_index += 1;
    }

    if (selected_chapter) |chapter| {
        const info = chapterInfo(chapter);
        if (info.page == selected_page and isChapterVisible(info)) drawCursor(info);
    }
}

fn drawChapterIcon(object_index: usize, chapter: icon_meta.Chapter) void {
    const tile: u10 = @intCast(@as(u16, icon_base_tile) + chapter.tile_offset);
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = oam.objX(chapter.x),
        .y = oam.objY(chapter.y),
        .base_tile = tile,
        .priority = 0,
        .palette = chapter.palette_bank,
    });
}

fn drawMap(map_data: []const u8) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);
    var index: usize = 0;
    while (index < bg_hardware_width_tiles * bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < width_tiles) : (x += 1) {
            const source_offset = (y * width_tiles + x) * 2;
            const raw_entry = @as(u16, map_data[source_offset]) |
                (@as(u16, map_data[source_offset + 1]) << 8);
            entries[background.normalBgMapIndex(x, y, bg_hardware_width_tiles)] = @bitCast(raw_entry);
        }
    }
}

fn loadCursor() void {
    buildCursorTiles();
    gba.display.obj_palette.colors[@as(usize, cursor_palette_bank) * 16 + 0] = .black;
    gba.display.obj_palette.colors[@as(usize, cursor_palette_bank) * 16 + 1] = gba.ColorRgb555.rgb(3, 4, 7);
    gba.display.obj_palette.colors[@as(usize, cursor_palette_bank) * 16 + 2] = gba.ColorRgb555.rgb(31, 29, 19);
    gba.display.obj_palette.colors[@as(usize, cursor_palette_bank) * 16 + 3] = .white;
    gba.display.memcpyObjectTiles4Bpp(cursor_base_tile, &cursor_tiles);
}

fn buildCursorTiles() void {
    cursor_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 4;

    var y: i16 = 1;
    while (y < 15) : (y += 1) {
        const dy = abs(y - 7);
        const half_width = 7 - dy;
        if (half_width < 0) continue;

        drawCursorSpan(8 - half_width, y, 8 + half_width, 1);
        if (half_width > 1) drawCursorSpan(9 - half_width, y, 7 + half_width, 2);
        if (half_width > 4) drawCursorSpan(11 - half_width, y, 5 + half_width, 3);
    }
}

fn drawCursorSpan(start_x: i16, y: i16, end_x: i16, color: u8) void {
    var x = start_x;
    while (x <= end_x) : (x += 1) {
        setCursorPixel(x, y, color);
    }
}

fn setCursorPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= 16 or y >= 16) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const tile_index = (uy / 8) * 2 + (ux / 8);
    const pixel_index = (uy & 7) * 8 + (ux & 7);
    const byte_index = pixel_index / 2;
    if ((pixel_index & 1) == 0) {
        cursor_tiles[tile_index].data_8[byte_index] = (cursor_tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        cursor_tiles[tile_index].data_8[byte_index] = (cursor_tiles[tile_index].data_8[byte_index] & 0x0f) | (color << 4);
    }
}

fn drawCursor(chapter: icon_meta.Chapter) void {
    const cursor_x = chapter.x + 8;
    const cursor_y = @max(@as(i16, 0), chapter.y - 18);
    gba.display.objects[cursor_object] = gba.display.Object.init(.{
        .size = .size_16x16,
        .x = oam.objX(cursor_x),
        .y = oam.objY(cursor_y),
        .base_tile = cursor_base_tile,
        .priority = 0,
        .palette = cursor_palette_bank,
    });
}

fn abs(value: i16) i16 {
    return if (value < 0) -value else value;
}
