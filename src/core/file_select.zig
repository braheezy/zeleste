const gba = @import("gba");

const assets = @import("assets.zig");
const background = @import("../world/background.zig");
const frame = @import("frame.zig");
const save = @import("save.zig");
const text = @import("text.zig");
const ui_sfx = @import("ui_sfx.zig");
const video = @import("video.zig");

const tiles_data align(4) = assets.file_select_tiles_data;
const map_data align(4) = assets.file_select_map_data;
const palette_data align(4) = assets.file_select_palette_data;
const scroll_pixels_data align(4) = assets.file_select_scroll_pixels_data;
const scroll_palette_data align(4) = assets.file_select_scroll_palette_data;
const scroll_meta = assets.file_select_scroll_meta;
const portrait_pixels_data align(4) = assets.file_select_portraits_pixels_data;
const portrait_palette_data align(4) = assets.file_select_portraits_palette_data;
const portrait_meta = assets.file_select_portraits_meta;

const width_tiles = 30;
const height_tiles = 20;
const screen_tile_count = width_tiles * height_tiles;

const text_dark: u8 = 250;
const text_muted: u8 = 251;
const portrait_shadow: u8 = 252;
const portrait_skin: u8 = 253;
const portrait_hair: u8 = 254;
const berry_red: u8 = 255;
const portrait_blue: u8 = 247;
const berry_seed: u8 = 248;
const berry_green: u8 = 249;
const skull_fill: u8 = 225;
const scroll_x: i16 = 46;
const scroll_y: i16 = 4;
const scroll_y_step: i16 = 52;
const scroll_animation_step: u16 = 2;
const focused_scroll_step: i16 = 4;
const scroll_open_frame: u16 = scroll_meta.frame_count - 1;
const menu_action_play: u8 = 0;
const menu_action_delete: u8 = 1;

var screen_tiles: [screen_tile_count]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** screen_tile_count;
var base_screen_tiles: [screen_tile_count]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** screen_tile_count;

const FileAction = enum {
    play,
    delete,
    cancel,
};

pub fn chooseSlot() u8 {
    loadScreen();

    var selected: u8 = 0;
    var input: gba.input.BufferedKeysState = .{};
    var previous_vertical: i16 = 0;
    var confirm_released = false;
    render(selected, scroll_open_frame);

    while (true) {
        input.poll();

        const confirm_down = input.isPressed(.A) or input.isPressed(.start);
        if (!confirm_down) confirm_released = true;

        const vertical: i16 = @intCast(input.getAxisVertical());
        if (vertical < 0 and previous_vertical >= 0) {
            const next = if (selected == 0) @as(u8, @intCast(save.slot_count - 1)) else selected - 1;
            ui_sfx.saveFileRoll();
            animateSelectionChange(selected, next);
            selected = next;
        } else if (vertical > 0 and previous_vertical <= 0) {
            const next = if (selected + 1 >= save.slot_count) 0 else selected + 1;
            ui_sfx.saveFileRoll();
            animateSelectionChange(selected, next);
            selected = next;
        }
        previous_vertical = vertical;

        if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.start))) {
            ui_sfx.saveFileOpen();
            animateFocusedScrollToTop(selected);
            switch (chooseFileAction(selected)) {
                .play => {
                    save.selectSlot(selected);
                    return selected;
                },
                .delete => {
                    deleteSelectedSlot(selected);
                    render(selected, scroll_open_frame);
                    confirm_released = false;
                    previous_vertical = 0;
                },
                .cancel => {
                    render(selected, scroll_open_frame);
                    confirm_released = false;
                    previous_vertical = 0;
                },
            }
        }

        frame.syncFrontend();
    }
}

fn loadScreen() void {
    gba.display.hideAllObjects();
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    background.clearParallaxMap();
    background.resetRoomStream();
    background.resetParallaxStream();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 1,
        .base_screenblock = video.bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });

    loadPalette();
    buildBaseScreenTiles();
    drawMap();

    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = false,
        .obj = false,
    });
}

fn loadPalette() void {
    gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&palette_data), palette_data.len);
    gba.display.bg_palette.colors[text_dark] = gba.ColorRgb555.rgb(3, 4, 9);
    gba.display.bg_palette.colors[text_muted] = gba.ColorRgb555.rgb(10, 15, 22);
    gba.display.bg_palette.colors[portrait_shadow] = gba.ColorRgb555.rgb(6, 6, 12);
    gba.display.bg_palette.colors[portrait_skin] = gba.ColorRgb555.rgb(31, 23, 14);
    gba.display.bg_palette.colors[portrait_hair] = gba.ColorRgb555.rgb(24, 5, 7);
    gba.display.bg_palette.colors[berry_red] = gba.ColorRgb555.rgb(31, 4, 9);
    gba.display.bg_palette.colors[portrait_blue] = gba.ColorRgb555.rgb(8, 13, 31);
    gba.display.bg_palette.colors[berry_seed] = gba.ColorRgb555.rgb(31, 24, 15);
    gba.display.bg_palette.colors[berry_green] = gba.ColorRgb555.rgb(7, 23, 8);
    gba.display.bg_palette.colors[skull_fill] = gba.ColorRgb555.rgb(31, 31, 30);
    const scroll_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&scroll_palette_data);
    gba.mem.memcpy16(&gba.display.bg_palette.colors[@as(usize, scroll_meta.palette_base)], scroll_palette, scroll_meta.palette_count);
    const file_portrait_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&portrait_palette_data);
    gba.mem.memcpy16(&gba.display.bg_palette.colors[@as(usize, portrait_meta.palette_base)], file_portrait_palette, portrait_meta.palette_count);
}

fn render(selected: u8, scroll_frame: u16) void {
    rebuildScreenTiles();

    var slot: u8 = 0;
    while (slot < save.slot_count) : (slot += 1) {
        const y = scrollYForSlot(slot);
        if (slot == selected) {
            drawScroll(scroll_x, y, scroll_frame);
            if (scroll_frame == scroll_open_frame) {
                drawSelectedScrollContents(slot, scroll_x, y);
            }
        } else {
            drawClosedScroll(slot, scroll_x, y);
        }
    }

    gba.display.memcpyBackgroundTiles8Bpp(0, &screen_tiles);
}

fn renderFocused(slot: u8, y: i16) void {
    rebuildScreenTiles();
    drawScroll(scroll_x, y, scroll_open_frame);
    drawSelectedScrollContents(slot, scroll_x, y);
    gba.display.memcpyBackgroundTiles8Bpp(0, &screen_tiles);
}

fn renderFocusedAction(slot: u8, selected_action: u8) void {
    rebuildScreenTiles();
    drawScroll(scroll_x, scroll_y, scroll_open_frame);
    drawActionScrollContents(slot, scroll_x, scroll_y, selected_action);
    gba.display.memcpyBackgroundTiles8Bpp(0, &screen_tiles);
}

fn animateSelectionChange(previous: u8, next: u8) void {
    var closing = scroll_open_frame;
    while (true) {
        render(previous, closing);
        frame.syncFrontend();
        if (closing == 0) break;
        closing = if (closing <= scroll_animation_step) 0 else closing - scroll_animation_step;
    }

    var opening: u16 = 0;
    while (true) {
        render(next, opening);
        frame.syncFrontend();
        if (opening == scroll_open_frame) break;
        opening = @min(opening + scroll_animation_step, scroll_open_frame);
    }
}

fn animateFocusedScrollToTop(slot: u8) void {
    var y = scrollYForSlot(slot);
    while (true) {
        renderFocused(slot, y);
        frame.syncFrontend();
        if (y == scroll_y) break;

        if (y > scroll_y) {
            const delta = @min(focused_scroll_step, y - scroll_y);
            y -= delta;
        } else {
            const delta = @min(focused_scroll_step, scroll_y - y);
            y += delta;
        }
    }
    renderFocusedAction(slot, menu_action_play);
}

fn chooseFileAction(slot: u8) FileAction {
    var selected_action = menu_action_play;
    var input: gba.input.BufferedKeysState = .{};
    var previous_vertical: i16 = 0;
    var confirm_released = false;

    while (true) {
        input.poll();
        const confirm_down = input.isPressed(.A) or input.isPressed(.start);
        if (!confirm_down) confirm_released = true;

        const vertical: i16 = @intCast(input.getAxisVertical());
        if ((vertical < 0 and previous_vertical >= 0) or (vertical > 0 and previous_vertical <= 0)) {
            selected_action = if (selected_action == menu_action_play) menu_action_delete else menu_action_play;
            if (vertical < 0) {
                ui_sfx.menuRollUp();
            } else {
                ui_sfx.menuRollDown();
            }
            renderFocusedAction(slot, selected_action);
        }
        previous_vertical = vertical;

        if (input.isJustPressed(.B)) {
            ui_sfx.saveFileClose();
            return .cancel;
        }
        if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.start))) {
            if (selected_action == menu_action_play) {
                ui_sfx.buttonSelect();
                return .play;
            }
            if (!slotHasSave(slot)) {
                ui_sfx.buttonInvalid();
                confirm_released = false;
            } else {
                ui_sfx.saveFileDelete();
                return .delete;
            }
        }

        frame.syncFrontend();
    }
}

fn drawScroll(x: i16, y: i16, frame_index: u16) void {
    const scroll_frame = @min(frame_index, scroll_open_frame);
    const scroll_frame_index: usize = @intCast(scroll_frame);
    const frame_size = @as(usize, scroll_meta.frame_width) * @as(usize, scroll_meta.frame_height);
    const frame_offset = @as(usize, scroll_frame) * frame_size;

    const min_x: i16 = @intCast(scroll_meta.frame_min_x[scroll_frame_index]);
    const min_y: i16 = @intCast(scroll_meta.frame_min_y[scroll_frame_index]);
    const max_x: i16 = @intCast(scroll_meta.frame_max_x[scroll_frame_index]);
    const max_y: i16 = @intCast(scroll_meta.frame_max_y[scroll_frame_index]);

    var yy = min_y;
    while (yy < max_y) : (yy += 1) {
        const dest_y = y + yy;
        if (dest_y < 0 or dest_y >= video.screen_height) continue;

        var start_x = min_x;
        var end_x = max_x;
        if (x + start_x < 0) start_x = -x;
        if (x + end_x > video.screen_width) end_x = video.screen_width - x;
        if (start_x >= end_x) continue;

        const source_row = frame_offset + @as(usize, @intCast(yy)) * @as(usize, scroll_meta.frame_width);
        var xx = start_x;
        while (xx < end_x) : (xx += 1) {
            const color = scroll_pixels_data[source_row + @as(usize, @intCast(xx))];
            if (color == 0) continue;
            setPixel(x + xx, dest_y, color);
        }
    }
}

fn drawClosedScroll(slot: u8, x: i16, y: i16) void {
    _ = slot;
    drawScroll(x, y, 0);
}

fn drawSelectedScrollContents(slot: u8, x: i16, y: i16) void {
    const summary = save.slotSummary(slot);
    if (summary.exists) {
        drawSelectedSlotSummary(
            slot,
            x,
            y,
            true,
            slotNameSlice(&summary),
            progressLabel(summary),
            summary.strawberry_count,
            summary.total_deaths,
            summary.completed_chapters,
            summary.playtime_frames,
        );
    } else {
        drawSelectedSlotSummary(slot, x, y, false, "NEW FILE", "START", 0, 0, 0, 0);
    }
}

fn drawActionScrollContents(slot: u8, x: i16, y: i16, selected_action: u8) void {
    const summary = save.slotSummary(slot);
    if (summary.exists) {
        drawActionSlotSummary(
            slot,
            x,
            y,
            true,
            slotNameSlice(&summary),
            progressLabel(summary),
            summary.strawberry_count,
            summary.total_deaths,
            selected_action,
        );
    } else {
        drawActionSlotSummary(slot, x, y, false, "NEW FILE", "START", 0, 0, selected_action);
    }
}

fn drawSelectedSlotSummary(
    slot: u8,
    x: i16,
    y: i16,
    exists: bool,
    name: []const u8,
    location: []const u8,
    strawberries: u16,
    deaths: u32,
    completed_chapters: u32,
    playtime_frames: u32,
) void {
    const portrait_x = x + 21;
    const portrait_y = y + 6;
    const text_x = x + 52;
    const stats_x = x + 64;
    const chapters_x = x + 92;
    const time_x = x + 92;
    const deaths_x = x + 100;
    const file_y = y + 7;
    const name_y = y + 14;
    const location_y = y + 23;
    const stats_y = y + 31;
    const time_y = y + 22;

    drawPortrait(portrait_x, portrait_y, exists, portraitIndexForSlot(slot, name, location, strawberries, deaths));
    drawFileLabel(slot, text_x, file_y, text_dark);
    text.drawSmallLine(setPixel, video.screen_width, name, text_x, name_y, text_dark);
    text.drawSmallLine(setPixel, video.screen_width, location, text_x, location_y, text_muted);
    if (!exists) return;
    drawChapterBadges(completed_chapters, chapters_x, file_y - 1);
    drawBerryStat(strawberries, stats_x, stats_y, text_dark);
    drawTimeStat(playtime_frames, time_x, time_y, text_dark);
    drawDeathsStat(deaths, deaths_x, stats_y, text_dark);
}

fn drawActionSlotSummary(
    slot: u8,
    x: i16,
    y: i16,
    exists: bool,
    name: []const u8,
    location: []const u8,
    strawberries: u16,
    deaths: u32,
    selected_action: u8,
) void {
    const portrait_x = x + 21;
    const portrait_y = y + 6;
    const text_x = x + 52;
    const menu_x = x + 95;
    const file_y = y + 7;
    const name_y = y + 14;
    const location_y = y + 23;

    drawPortrait(portrait_x, portrait_y, exists, portraitIndexForSlot(slot, name, location, strawberries, deaths));
    drawFileLabel(slot, text_x, file_y, text_dark);
    text.drawSmallLine(setPixel, video.screen_width, name, text_x, name_y, text_dark);
    text.drawSmallLine(setPixel, video.screen_width, location, text_x, location_y, text_muted);
    drawActionMenu(menu_x, y + 14, selected_action, exists);
}

fn drawActionMenu(x: i16, y: i16, selected_action: u8, can_delete: bool) void {
    drawActionMenuItem("PLAY", x, y, selected_action == menu_action_play, text_dark);
    drawActionMenuItem("DELETE", x, y + 10, selected_action == menu_action_delete, if (can_delete) text_dark else text_muted);
}

fn drawActionMenuItem(label: []const u8, x: i16, y: i16, selected: bool, color: u8) void {
    if (selected) drawMenuCursor(x - 6, y + 1, berry_red);
    text.drawSmallLine(setPixel, video.screen_width, label, x, y, color);
}

fn drawMenuCursor(x: i16, y: i16, color: u8) void {
    setPixel(x, y + 2, color);
    drawRect(x + 1, y + 1, 1, 3, color);
    setPixel(x + 2, y + 2, color);
}

fn deleteSelectedSlot(slot: u8) void {
    const slot_index: usize = @intCast(slot);
    if (slot_index >= save.slot_count) return;
    save.deleteSlot(slot_index);
}

fn slotHasSave(slot: u8) bool {
    const slot_index: usize = @intCast(slot);
    if (slot_index >= save.slot_count) return false;
    return save.slotSummary(slot).exists;
}

fn scrollYForSlot(slot: u8) i16 {
    return scroll_y + @as(i16, @intCast(slot)) * scroll_y_step;
}

fn rebuildScreenTiles() void {
    screen_tiles = base_screen_tiles;
}

fn buildBaseScreenTiles() void {
    var tile_y: usize = 0;
    while (tile_y < height_tiles) : (tile_y += 1) {
        var tile_x: usize = 0;
        while (tile_x < width_tiles) : (tile_x += 1) {
            const map_offset = (tile_y * width_tiles + tile_x) * 2;
            const raw_entry = @as(u16, map_data[map_offset]) |
                (@as(u16, map_data[map_offset + 1]) << 8);
            copySourceTile(tile_y * width_tiles + tile_x, raw_entry);
        }
    }
}

fn copySourceTile(destination_tile: usize, raw_entry: u16) void {
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
            base_screen_tiles[destination_tile].data_8[y * 8 + x] =
                tiles_data[source_offset + source_y * 8 + source_x];
        }
    }
}

fn drawMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    var index: usize = 0;
    while (index < video.bg_hardware_width_tiles * video.bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < width_tiles) : (x += 1) {
            const tile_index: u16 = @intCast(y * width_tiles + x);
            entries[background.normalBgMapIndex(x, y, video.bg_hardware_width_tiles)] = @bitCast(tile_index);
        }
    }
}

fn slotNameSlice(summary: *const save.SlotSummary) []const u8 {
    var end: usize = 0;
    while (end < summary.player_name.len and summary.player_name[end] != 0) : (end += 1) {}
    if (end == 0) {
        return "MADELINE";
    }
    return summary.player_name[0..end];
}

fn progressLabel(summary: save.SlotSummary) []const u8 {
    if (summary.current_chapter == 0) return "PROLOGUE";
    if (summary.current_chapter == 1) return "CITY";
    return "MOUNTAIN";
}

fn drawFileLabel(slot: u8, x: i16, y: i16, color: u8) void {
    var label = [_]u8{ 'F', 'I', 'L', 'E', ' ', '1' };
    label[5] = '1' + slot;
    text.drawSmallLine(setPixel, video.screen_width, &label, x, y, color);
}

fn drawBerryStat(count: u16, x: i16, y: i16, color: u8) void {
    drawBerryIcon(x, y - 2);
    text.drawSmallLine(setPixel, video.screen_width, "X", x + 8, y, color);
    drawNumberSmall(count, x + 13, y, color);
}

fn drawDeathsStat(count: u32, x: i16, y: i16, color: u8) void {
    drawSkullIcon(x, y - 1);
    drawNumberSmall(count, x + 12, y, color);
}

fn drawChapterBadges(completed_chapters: u32, x: i16, y: i16) void {
    drawChapterBadge('P', (completed_chapters & 0b01) != 0, x, y);
    drawChapterBadge('1', (completed_chapters & 0b10) != 0, x + 9, y);
}

fn drawChapterBadge(label: u8, completed: bool, x: i16, y: i16) void {
    const edge = if (completed) text_dark else text_muted;
    drawBadgeFrame(x, y, edge);
    if (completed) drawRect(x + 1, y + 1, 5, 5, berry_green);
    const glyph = [_]u8{label};
    text.drawSmallLineTight(setPixel, video.screen_width, &glyph, x + 2, y + 1, if (completed) berry_seed else text_muted);
}

fn drawBadgeFrame(x: i16, y: i16, color: u8) void {
    drawRect(x, y, 7, 1, color);
    drawRect(x, y + 6, 7, 1, color);
    drawRect(x, y + 1, 1, 5, color);
    drawRect(x + 6, y + 1, 1, 5, color);
}

fn drawTimeStat(playtime_frames: u32, x: i16, y: i16, color: u8) void {
    drawClockIcon(x, y - 1);
    var buffer: [8]u8 = undefined;
    const len = timeLabel(playtime_frames, &buffer);
    text.drawSmallLine(setPixel, video.screen_width, buffer[0..len], x + 9, y, color);
}

fn timeLabel(playtime_frames: u32, out: *[8]u8) usize {
    const total_seconds = playtime_frames / 60;
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
    return len;
}

fn appendDecimal(value: u32, out: *[8]u8, start: usize) usize {
    var digits: [10]u8 = undefined;
    const len = decimalDigits(value, &digits);
    var index: usize = 0;
    while (index < len and start + index < out.len) : (index += 1) {
        out[start + index] = digits[index];
    }
    return index;
}

fn appendTwoDigits(value: u8, out: *[8]u8, len: *usize) void {
    out[len.*] = '0' + value / 10;
    len.* += 1;
    out[len.*] = '0' + value % 10;
    len.* += 1;
}

fn drawNumberSmall(value: anytype, x: i16, y: i16, color: u8) void {
    var digits: [10]u8 = undefined;
    const len = decimalDigits(value, &digits);
    text.drawSmallLine(setPixel, video.screen_width, digits[0..len], x, y, color);
}

fn decimalDigits(value: anytype, out: *[10]u8) usize {
    var temp: u32 = @intCast(value);
    if (temp == 0) {
        out[0] = '0';
        return 1;
    }

    var reversed: [10]u8 = undefined;
    var len: usize = 0;
    while (temp != 0 and len < reversed.len) : (len += 1) {
        reversed[len] = '0' + @as(u8, @intCast(temp % 10));
        temp /= 10;
    }

    var index: usize = 0;
    while (index < len) : (index += 1) {
        out[index] = reversed[len - 1 - index];
    }
    return len;
}

fn drawPortrait(x: i16, y: i16, exists: bool, frame_index: u16) void {
    const size: i16 = @intCast(portrait_meta.frame_width);
    drawRect(x, y, size, size, portrait_shadow);
    drawRect(x + 1, y + 1, size - 2, size - 2, text_muted);
    if (!exists) {
        drawRect(x + 8, y + 7, 12, 12, portrait_shadow);
        drawRect(x + 9, y + 8, 10, 10, text_muted);
        text.drawLine(setPixel, video.screen_width, "NEW", x + 5, y + 20, text_dark);
        return;
    }

    drawPortraitImage(x, y, frame_index);
}

fn drawPortraitImage(x: i16, y: i16, frame_index: u16) void {
    const width: usize = @intCast(portrait_meta.frame_width);
    const height: usize = @intCast(portrait_meta.frame_height);
    const portrait_frame = @min(frame_index, portrait_meta.frame_count - 1);
    const frame_offset = @as(usize, @intCast(portrait_frame)) * width * height;
    var yy: usize = 0;
    while (yy < height) : (yy += 1) {
        var xx: usize = 0;
        while (xx < width) : (xx += 1) {
            const color = portrait_pixels_data[frame_offset + yy * width + xx];
            if (color == 0) continue;
            setPixel(x + @as(i16, @intCast(xx)), y + @as(i16, @intCast(yy)), color);
        }
    }
}

fn portraitIndexForSlot(slot: u8, name: []const u8, location: []const u8, strawberries: u16, deaths: u32) u16 {
    var hash: u32 = 2166136261;
    hash = mixPortraitHash(hash, slot);
    hash = mixPortraitHash(hash, @intCast(strawberries & 0xff));
    hash = mixPortraitHash(hash, @intCast(strawberries >> 8));
    hash = mixPortraitHash(hash, @intCast(deaths & 0xff));
    hash = mixPortraitHash(hash, @intCast((deaths >> 8) & 0xff));
    for (name) |ch| hash = mixPortraitHash(hash, ch);
    for (location) |ch| hash = mixPortraitHash(hash, ch);
    return @intCast(hash % @as(u32, portrait_meta.frame_count));
}

fn mixPortraitHash(hash: u32, value: u8) u32 {
    return (hash ^ @as(u32, value)) *% 16777619;
}

fn drawBerryIcon(x: i16, y: i16) void {
    setPixel(x + 3, y, berry_green);
    setPixel(x + 2, y + 1, berry_green);
    setPixel(x + 3, y + 1, berry_green);
    setPixel(x + 4, y + 1, berry_green);
    drawRect(x + 1, y + 2, 5, 1, berry_red);
    drawRect(x, y + 3, 7, 2, berry_red);
    drawRect(x + 1, y + 5, 5, 1, berry_red);
    drawRect(x + 2, y + 6, 3, 1, berry_red);
    setPixel(x + 2, y + 3, berry_seed);
    setPixel(x + 5, y + 4, berry_seed);
    setPixel(x + 3, y + 5, berry_seed);
}

fn drawSkullIcon(x: i16, y: i16) void {
    drawRect(x + 2, y, 5, 1, text_dark);
    drawRect(x + 1, y + 1, 7, 1, text_dark);
    drawRect(x, y + 2, 9, 3, text_dark);
    drawRect(x + 1, y + 5, 7, 2, text_dark);
    setPixel(x + 2, y + 7, text_dark);
    setPixel(x + 4, y + 7, text_dark);
    setPixel(x + 6, y + 7, text_dark);

    drawRect(x + 2, y + 1, 5, 1, skull_fill);
    drawRect(x + 1, y + 2, 7, 3, skull_fill);
    drawRect(x + 2, y + 5, 5, 1, skull_fill);
    setPixel(x + 2, y + 6, skull_fill);
    setPixel(x + 4, y + 6, skull_fill);
    setPixel(x + 6, y + 6, skull_fill);
    setPixel(x + 3, y + 3, text_dark);
    setPixel(x + 5, y + 3, text_dark);
    setPixel(x + 4, y + 5, text_dark);
}

fn drawClockIcon(x: i16, y: i16) void {
    drawRect(x + 2, y, 3, 1, text_muted);
    setPixel(x + 1, y + 1, text_muted);
    setPixel(x + 5, y + 1, text_muted);
    setPixel(x, y + 2, text_muted);
    setPixel(x + 6, y + 2, text_muted);
    setPixel(x, y + 3, text_muted);
    setPixel(x + 6, y + 3, text_muted);
    setPixel(x, y + 4, text_muted);
    setPixel(x + 6, y + 4, text_muted);
    setPixel(x + 1, y + 5, text_muted);
    setPixel(x + 5, y + 5, text_muted);
    drawRect(x + 2, y + 6, 3, 1, text_muted);
    drawRect(x + 3, y + 2, 1, 3, text_dark);
    drawRect(x + 3, y + 4, 2, 1, text_dark);
}

fn drawRect(x: i16, y: i16, width: i16, height: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < height) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < width) : (xx += 1) {
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
    const byte_index = (uy & 7) * 8 + (ux & 7);
    screen_tiles[tile_index].data_8[byte_index] = color;
}

fn previousSlot(selected: u8) u8 {
    return if (selected == 0) @as(u8, @intCast(save.slot_count - 1)) else selected - 1;
}

fn nextSlot(selected: u8) u8 {
    return if (selected + 1 >= save.slot_count) 0 else selected + 1;
}
