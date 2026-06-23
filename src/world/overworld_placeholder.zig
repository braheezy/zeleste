const gba = @import("gba");
const assets = @import("../core/assets.zig");
const background = @import("background.zig");
const level = @import("../generated_rooms.zig");
const oam = @import("../core/oam.zig");
const room_data = @import("room_data.zig");
const save = @import("../core/save.zig");
const text = @import("../core/text.zig");
const ui_sfx = @import("../core/ui_sfx.zig");
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
const screen_tile_count = width_tiles * height_tiles;

pub const Selection = enum(u8) {
    none,
    back,
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
const panel_text: u8 = 250;
const panel_muted: u8 = 251;
const panel_fill: u8 = 252;
const panel_border: u8 = 253;
const panel_shadow: u8 = 254;
const panel_accent: u8 = 255;
const panel_gold_leaf: u8 = 244;
const panel_gold_berry: u8 = 245;
const panel_heart_blue: u8 = 246;
const panel_heart_light: u8 = 247;
const panel_berry_leaf: u8 = 248;
const panel_berry_red: u8 = 249;

const RespawnPoint = room_data.RespawnPoint;

var screen_tiles: [screen_tile_count]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** screen_tile_count;
var cursor_tiles: [4]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 4;
var selected_page: u8 = 0;
var selected_chapter: ?u8 = null;
var selected_area_index: u8 = 0;
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
    selected_area_index = defaultAreaForChapter(selected_chapter);

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
        if (moveAlongPath(-1)) {
            ui_sfx.worldIconRoll(-1);
            changed = true;
        }
    } else if (horizontal > 0 and previous_horizontal <= 0) {
        if (moveAlongPath(1)) {
            ui_sfx.worldIconRoll(1);
            changed = true;
        }
    }
    previous_horizontal = horizontal;

    const vertical: i16 = @intCast(input.getAxisVertical());
    if (vertical < 0 and previous_vertical >= 0) {
        if (moveCheckpointSelection(-1)) {
            ui_sfx.worldIconRoll(-1);
            changed = true;
        } else if (!selectedChapterHasCheckpointList() and moveAlongPath(1)) {
            ui_sfx.worldIconRoll(1);
            changed = true;
        }
    } else if (vertical > 0 and previous_vertical <= 0) {
        if (moveCheckpointSelection(1)) {
            ui_sfx.worldIconRoll(1);
            changed = true;
        } else if (!selectedChapterHasCheckpointList() and moveAlongPath(-1)) {
            ui_sfx.worldIconRoll(-1);
            changed = true;
        }
    }
    previous_vertical = vertical;

    if (input.isJustPressed(.L)) {
        if (previousPage()) {
            ui_sfx.worldPageFlip(-1);
            changed = true;
        }
    }
    if (input.isJustPressed(.R)) {
        if (nextPage()) {
            ui_sfx.worldPageFlip(1);
            changed = true;
        }
    }

    if (input.isJustPressed(.B)) {
        ui_sfx.buttonBack();
        return .back;
    }

    if (changed) drawObjects();

    const confirm_down = input.isPressed(.A) or input.isPressed(.start);
    if (!confirm_down) confirm_released = true;
    if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.start))) {
        const selection = currentSelection();
        if (selection == .none) {
            ui_sfx.buttonInvalid();
            return .none;
        }
        ui_sfx.worldChapterSelect();
        return selection;
    }

    return .none;
}

fn loadPage(page: u8) void {
    if (page == 0) {
        gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&page0_palette_data), page0_palette_data.len);
    } else {
        gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&page1_palette_data), page1_palette_data.len);
    }
    loadPanelPaletteColors();
}

fn loadPanelPaletteColors() void {
    gba.display.bg_palette.colors[panel_text] = gba.ColorRgb555.rgb(29, 30, 31);
    gba.display.bg_palette.colors[panel_muted] = gba.ColorRgb555.rgb(17, 21, 26);
    gba.display.bg_palette.colors[panel_fill] = gba.ColorRgb555.rgb(2, 5, 10);
    gba.display.bg_palette.colors[panel_border] = gba.ColorRgb555.rgb(14, 19, 26);
    gba.display.bg_palette.colors[panel_shadow] = gba.ColorRgb555.rgb(0, 1, 4);
    gba.display.bg_palette.colors[panel_accent] = gba.ColorRgb555.rgb(31, 24, 12);
    gba.display.bg_palette.colors[panel_gold_leaf] = gba.ColorRgb555.rgb(13, 18, 5);
    gba.display.bg_palette.colors[panel_gold_berry] = gba.ColorRgb555.rgb(31, 23, 4);
    gba.display.bg_palette.colors[panel_heart_blue] = gba.ColorRgb555.rgb(3, 18, 31);
    gba.display.bg_palette.colors[panel_heart_light] = gba.ColorRgb555.rgb(18, 29, 31);
    gba.display.bg_palette.colors[panel_berry_leaf] = gba.ColorRgb555.rgb(7, 23, 8);
    gba.display.bg_palette.colors[panel_berry_red] = gba.ColorRgb555.rgb(31, 4, 9);
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

pub fn selectedRespawn() ?RespawnPoint {
    const chapter = selected_chapter orelse return null;
    const info = chapterInfo(chapter);
    if (!isChapterVisible(info)) return null;
    const area = selectedAreaSummary(chapter) orelse return null;
    if (area.checkpoint_room_index >= level.rooms.len) return null;
    return .{
        .room_index = area.checkpoint_room_index,
        .spawn = level.rooms[area.checkpoint_room_index].spawn,
    };
}

fn moveAlongPath(direction: i8) bool {
    if (selected_chapter == null) {
        if (firstVisibleOnPage(selected_page)) |chapter| {
            return selectChapter(chapter);
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

fn moveCheckpointSelection(direction: i8) bool {
    const chapter = selected_chapter orelse return false;
    if (chapter == prologue_chapter) return false;

    const count = chapterAreaCount(chapter);
    if (count <= 1) return false;

    const step: isize = if (direction > 0) 1 else -1;
    var index: isize = @intCast(selected_area_index);
    while (true) {
        index += step;
        if (index < 0 or index >= count) return false;
        const candidate_index: usize = @intCast(index);
        const area = save.activeChapterAreaSummary(chapter, candidate_index);
        if (area.unlocked) {
            selected_area_index = @intCast(candidate_index);
            return true;
        }
    }
}

fn selectedChapterHasCheckpointList() bool {
    const chapter = selected_chapter orelse return false;
    return chapter != prologue_chapter and chapterAreaCount(chapter) > 1;
}

fn previousPage() bool {
    if (selected_page == 0) return false;
    selected_page -= 1;
    selected_chapter = firstVisibleOnPage(selected_page);
    selected_area_index = defaultAreaForChapter(selected_chapter);
    loadPage(selected_page);
    return true;
}

fn nextPage() bool {
    if (selected_page + 1 >= page_count) return false;
    selected_page += 1;
    selected_chapter = firstVisibleOnPage(selected_page);
    selected_area_index = defaultAreaForChapter(selected_chapter);
    loadPage(selected_page);
    return true;
}

fn selectChapter(chapter: u8) bool {
    const info = chapterInfo(chapter);
    if (!isChapterVisible(info)) return false;
    selected_chapter = chapter;
    selected_area_index = defaultAreaForChapter(selected_chapter);
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

fn chapterAreaCount(chapter: u8) usize {
    return @min(save.activeChapterAreaCount(chapter), save.max_chapter_area_count);
}

fn defaultAreaForChapter(chapter: ?u8) u8 {
    const selected = chapter orelse return 0;
    const count = chapterAreaCount(selected);
    if (count == 0) return 0;

    var index = count;
    while (index > 0) {
        index -= 1;
        const area = save.activeChapterAreaSummary(selected, index);
        if (area.unlocked) return @intCast(index);
    }
    return 0;
}

fn selectedAreaSummary(chapter: u8) ?save.ChapterAreaSummary {
    const count = chapterAreaCount(chapter);
    if (count == 0) return null;

    const preferred_index = @min(@as(usize, selected_area_index), count - 1);
    const preferred = save.activeChapterAreaSummary(chapter, preferred_index);
    if (preferred.unlocked) return preferred;

    var index = count;
    while (index > 0) {
        index -= 1;
        const area = save.activeChapterAreaSummary(chapter, index);
        if (area.unlocked) return area;
    }
    return null;
}

fn drawObjects() void {
    renderPageWithPanel();

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

fn renderPageWithPanel() void {
    if (selected_page == 0) {
        buildScreenTiles(page0_tiles_data[0..], page0_map_data[0..]);
    } else {
        buildScreenTiles(page1_tiles_data[0..], page1_map_data[0..]);
    }
    drawChapterPanel();
    drawSequentialMap();
    gba.display.memcpyBackgroundTiles8Bpp(0, &screen_tiles);
}

fn buildScreenTiles(tiles_data: []const u8, map_data: []const u8) void {
    var tile_y: usize = 0;
    while (tile_y < height_tiles) : (tile_y += 1) {
        var tile_x: usize = 0;
        while (tile_x < width_tiles) : (tile_x += 1) {
            const map_offset = (tile_y * width_tiles + tile_x) * 2;
            const raw_entry = @as(u16, map_data[map_offset]) |
                (@as(u16, map_data[map_offset + 1]) << 8);
            copySourceTile(tile_y * width_tiles + tile_x, raw_entry, tiles_data);
        }
    }
}

fn copySourceTile(destination_tile: usize, raw_entry: u16, tiles_data: []const u8) void {
    const source_tile = @as(usize, raw_entry & 0x03ff);
    const flip_x = (raw_entry & 0x0400) != 0;
    const flip_y = (raw_entry & 0x0800) != 0;
    const source_offset = source_tile * 64;

    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            const source_x = if (flip_x) 7 - x else x;
            const source_y = if (flip_y) 7 - y else y;
            screen_tiles[destination_tile].data_8[y * 8 + x] =
                tiles_data[source_offset + source_y * 8 + source_x];
        }
    }
}

fn drawSequentialMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[bg_screenblock].entries);
    var index: usize = 0;
    while (index < bg_hardware_width_tiles * bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < width_tiles) : (x += 1) {
            const tile_index: u16 = @intCast(y * width_tiles + x);
            entries[background.normalBgMapIndex(x, y, bg_hardware_width_tiles)] = @bitCast(tile_index);
        }
    }
}

fn drawChapterPanel() void {
    const chapter = selected_chapter orelse return;
    const stats = save.activeChapterStats(chapter);
    const summary = save.slotSummary(save.activeSlotIndex());

    const x: i16 = 8;
    const y: i16 = 8;
    const is_prologue = chapter == prologue_chapter;
    const panel_height: i16 = if (is_prologue) 40 else 64;
    drawPanelBox(x, y, 224, panel_height);

    text.drawSmallLine(setPixel, video.screen_width, chapterTitle(chapter), x + 8, y + 6, panel_text);
    text.drawSmallLine(setPixel, video.screen_width, "TIME", x + 8, y + 16, panel_muted);
    drawTimeValue(stats.playtime_frames, x + 28, y + 16, panel_text);
    text.drawSmallLine(setPixel, video.screen_width, "DEATHS", x + 78, y + 16, panel_muted);
    drawNumber(summary.total_deaths, x + 104, y + 16, panel_text);

    text.drawSmallLine(setPixel, video.screen_width, "BERRIES", x + 8, y + 27, panel_muted);
    drawRatio(stats.strawberries, x + 40, y + 27, panel_text);
    if (!is_prologue) {
        if (stats.cassettes.collected > 0) drawTapeIcon(x + 88, y + 25);
        if (chapter == city_chapter and stats.crystal_heart_collected) drawBlueHeartIcon(x + 108, y + 25);
        if (chapter == city_chapter and stats.golden_strawberry_collected) drawGoldBerryIcon(x + 124, y + 25);

        text.drawSmallLine(setPixel, video.screen_width, "CHECKPOINTS", x + 8, y + 38, panel_accent);
        const area_count = chapterAreaCount(chapter);
        var area_index: usize = 0;
        while (area_index < area_count) : (area_index += 1) {
            const area = save.activeChapterAreaSummary(chapter, area_index);
            drawCheckpointRow(
                area,
                area_index == selected_area_index and area.unlocked,
                x + 8 + @as(i16, @intCast(area_index)) * 70,
                y + 50,
            );
        }
    }
}

fn drawCheckpointRow(area: save.ChapterAreaSummary, selected: bool, x: i16, y: i16) void {
    const color = if (area.unlocked) panel_text else panel_muted;
    if (selected) drawCheckpointCursor(x - 6, y + 1);
    text.drawSmallLine(setPixel, video.screen_width, if (area.unlocked) area.label else "????", x, y, color);
    if (area.unlocked) {
        drawBerryIcon(x, y + 8);
        drawRatio(area.strawberries, x + 8, y + 7, color);
    }
}

fn drawCheckpointCursor(x: i16, y: i16) void {
    setPixel(x, y + 2, panel_accent);
    drawRect(x + 1, y + 1, 1, 3, panel_accent);
    drawRect(x + 2, y, 1, 5, panel_accent);
}

fn drawBerryIcon(x: i16, y: i16) void {
    setPixel(x + 2, y, panel_berry_leaf);
    drawRect(x + 1, y + 1, 3, 1, panel_berry_red);
    drawRect(x, y + 2, 5, 2, panel_berry_red);
    drawRect(x + 1, y + 4, 3, 1, panel_berry_red);
    setPixel(x + 1, y + 2, panel_text);
    setPixel(x + 3, y + 3, panel_text);
}

fn drawGoldBerryIcon(x: i16, y: i16) void {
    setPixel(x + 2, y, panel_gold_leaf);
    drawRect(x + 1, y + 1, 3, 1, panel_gold_berry);
    drawRect(x, y + 2, 5, 2, panel_gold_berry);
    drawRect(x + 1, y + 4, 3, 1, panel_gold_berry);
    setPixel(x + 1, y + 2, panel_text);
    setPixel(x + 3, y + 3, panel_text);
}

fn drawTapeIcon(x: i16, y: i16) void {
    drawRect(x, y + 1, 12, 7, panel_border);
    drawRect(x + 1, y + 2, 10, 5, panel_accent);
    drawRect(x + 2, y + 3, 8, 3, panel_fill);
    drawRect(x + 3, y + 4, 2, 1, panel_text);
    drawRect(x + 7, y + 4, 2, 1, panel_text);
    setPixel(x + 1, y + 1, panel_fill);
    setPixel(x + 10, y + 1, panel_fill);
    setPixel(x + 1, y + 7, panel_fill);
    setPixel(x + 10, y + 7, panel_fill);
}

fn drawBlueHeartIcon(x: i16, y: i16) void {
    drawRect(x + 1, y, 2, 1, panel_heart_blue);
    drawRect(x + 5, y, 2, 1, panel_heart_blue);
    drawRect(x, y + 1, 8, 3, panel_heart_blue);
    drawRect(x + 1, y + 4, 6, 1, panel_heart_blue);
    drawRect(x + 2, y + 5, 4, 1, panel_heart_blue);
    drawRect(x + 3, y + 6, 2, 1, panel_heart_blue);
    setPixel(x + 2, y + 1, panel_heart_light);
    setPixel(x + 1, y + 2, panel_heart_light);
    setPixel(x + 3, y + 2, panel_heart_light);
}

fn chapterTitle(chapter: u8) []const u8 {
    return switch (chapter) {
        0 => "PROLOGUE",
        1 => "CHAPTER 1: FORSAKEN CITY",
        else => "CHAPTER",
    };
}

fn drawPanelBox(x: i16, y: i16, w: i16, h: i16) void {
    drawRect(x + 2, y + 2, w, h, panel_shadow);
    drawRect(x, y, w, h, panel_border);
    drawRect(x + 1, y + 1, w - 2, h - 2, panel_fill);
    drawRect(x + 1, y + 1, w - 2, 1, panel_accent);
}

fn drawRatio(value: save.CollectibleCount, x: i16, y: i16, color: u8) void {
    var buffer: [10]u8 = undefined;
    var len = appendDecimal(value.collected, &buffer, 0);
    buffer[len] = '/';
    len += 1;
    len += appendDecimal(value.total, &buffer, len);
    text.drawSmallLine(setPixel, video.screen_width, buffer[0..len], x, y, color);
}

fn drawNumber(value: u32, x: i16, y: i16, color: u8) void {
    var buffer: [10]u8 = undefined;
    const len = appendDecimal(value, &buffer, 0);
    text.drawSmallLine(setPixel, video.screen_width, buffer[0..len], x, y, color);
}

fn drawTimeValue(playtime_frames: u32, x: i16, y: i16, color: u8) void {
    var buffer: [10]u8 = undefined;
    const len = timeLabel(playtime_frames, &buffer);
    text.drawSmallLine(setPixel, video.screen_width, buffer[0..len], x, y, color);
}

fn timeLabel(playtime_frames: u32, out: *[10]u8) usize {
    const total_seconds = playtime_frames / 60;
    const tenths: u8 = @intCast((playtime_frames % 60) / 6);
    const seconds: u8 = @intCast(total_seconds % 60);
    const total_minutes = total_seconds / 60;
    const minutes: u8 = @intCast(total_minutes % 60);
    var hours = total_minutes / 60;
    if (hours > 99) hours = 99;

    var len: usize = 0;
    if (hours != 0) {
        len += appendDecimal(@intCast(hours), out, len);
        out[len] = ':';
        len += 1;
        appendTwoDigits(minutes, out, &len);
        out[len] = ':';
        len += 1;
        appendTwoDigits(seconds, out, &len);
    } else {
        len += appendDecimal(minutes, out, len);
        out[len] = ':';
        len += 1;
        appendTwoDigits(seconds, out, &len);
    }
    out[len] = '.';
    len += 1;
    out[len] = '0' + tenths;
    len += 1;
    return len;
}

fn appendDecimal(value: u32, out: []u8, start: usize) usize {
    var temp = value;
    if (temp == 0) {
        out[start] = '0';
        return 1;
    }

    var reversed: [10]u8 = undefined;
    var len: usize = 0;
    while (temp != 0 and len < reversed.len) : (len += 1) {
        reversed[len] = '0' + @as(u8, @intCast(temp % 10));
        temp /= 10;
    }

    var index: usize = 0;
    while (index < len and start + index < out.len) : (index += 1) {
        out[start + index] = reversed[len - 1 - index];
    }
    return index;
}

fn appendTwoDigits(value: u8, out: *[10]u8, len: *usize) void {
    out[len.*] = '0' + value / 10;
    len.* += 1;
    out[len.*] = '0' + value % 10;
    len.* += 1;
}

fn drawRect(x: i16, y: i16, w: i16, h: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < h) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < w) : (xx += 1) {
            setPixel(x + xx, y + yy, color);
        }
    }
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= video.screen_width or y >= video.screen_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const tile_x = ux / 8;
    const tile_y = uy / 8;
    const tile_index = tile_y * width_tiles + tile_x;
    const pixel_index = (uy & 7) * 8 + (ux & 7);
    screen_tiles[tile_index].data_8[pixel_index] = color;
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
