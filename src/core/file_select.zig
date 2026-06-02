const gba = @import("gba");

const assets = @import("assets.zig");
const background = @import("../world/background.zig");
const frame = @import("frame.zig");
const save = @import("save.zig");
const text = @import("text.zig");
const video = @import("video.zig");

const tiles_data align(4) = assets.file_select_tiles_data;
const map_data align(4) = assets.file_select_map_data;
const palette_data align(4) = assets.file_select_palette_data;
const scroll_pixels_data align(4) = assets.file_select_scroll_pixels_data;
const scroll_palette_data align(4) = assets.file_select_scroll_palette_data;
const scroll_meta = assets.file_select_scroll_meta;

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
const scroll_x: i16 = 46;
const scroll_y: i16 = 4;
const scroll_y_step: i16 = 52;
const scroll_animation_step: u16 = 2;
const scroll_open_frame: u16 = scroll_meta.frame_count - 1;
const demo_file_select_values = true;

const DemoSlot = struct {
    exists: bool,
    name: []const u8,
    location: []const u8,
    strawberries: u16,
    deaths: u32,
    completed: bool,
};

const demo_slots = [_]DemoSlot{
    .{ .exists = true, .name = "MADELINE", .location = "PROLOGUE", .strawberries = 7, .deaths = 12, .completed = true },
    .{ .exists = true, .name = "MADDY", .location = "CITY 1-3", .strawberries = 18, .deaths = 64, .completed = false },
    .{ .exists = false, .name = "NEW FILE", .location = "START", .strawberries = 0, .deaths = 0, .completed = false },
};

var screen_tiles: [screen_tile_count]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** screen_tile_count;
var base_screen_tiles: [screen_tile_count]gba.display.Tile8Bpp align(4) =
    [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** screen_tile_count;

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
            animateSelectionChange(selected, next);
            selected = next;
        } else if (vertical > 0 and previous_vertical <= 0) {
            const next = if (selected + 1 >= save.slot_count) 0 else selected + 1;
            animateSelectionChange(selected, next);
            selected = next;
        }
        previous_vertical = vertical;

        if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.start))) {
            save.selectSlot(selected);
            return selected;
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
    const scroll_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&scroll_palette_data);
    gba.mem.memcpy16(&gba.display.bg_palette.colors[@as(usize, scroll_meta.palette_base)], scroll_palette, scroll_meta.palette_count);
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
    drawScroll(x, y, 0);
    drawFileLabel(slot, x + 6, y + 20, text_dark);
}

fn drawSelectedScrollContents(slot: u8, x: i16, y: i16) void {
    if (demo_file_select_values) {
        const demo = demo_slots[@min(@as(usize, @intCast(slot)), demo_slots.len - 1)];
        drawSelectedSlotSummary(slot, x, y, demo.exists, demo.name, demo.location, demo.strawberries, demo.deaths, demo.completed);
        return;
    }

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
            summary.completed_chapters != 0,
        );
    } else {
        drawSelectedSlotSummary(slot, x, y, false, "NEW FILE", "START", 0, 0, false);
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
    completed: bool,
) void {
    _ = completed;
    const portrait_x = x + 21;
    const portrait_y = y + 6;
    const text_x = x + 52;
    const stats_x = x + 64;
    const file_y = y + 6;
    const name_y = y + 14;
    const location_y = y + 23;
    const stats_y = y + 31;

    drawPortrait(portrait_x, portrait_y, exists);
    drawFileLabel(slot, text_x, file_y, text_dark);
    text.drawSmallLine(setPixel, video.screen_width, name, text_x, name_y, text_dark);
    text.drawSmallLine(setPixel, video.screen_width, location, text_x, location_y, text_muted);
    drawBerryStat(strawberries, stats_x, stats_y, text_dark);
    drawDeathsStat(deaths, stats_x + 45, stats_y, text_dark);
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
    drawBerryIcon(x, y + 1);
    text.drawSmallLine(setPixel, video.screen_width, "X", x + 8, y, color);
    drawNumberSmall(count, x + 13, y, color);
}

fn drawDeathsStat(count: u32, x: i16, y: i16, color: u8) void {
    text.drawSmallLine(setPixel, video.screen_width, "D", x, y, color);
    drawNumberSmall(count, x + 6, y, color);
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

fn drawPortrait(x: i16, y: i16, exists: bool) void {
    const size: i16 = 28;
    drawRect(x, y, size, size, portrait_shadow);
    drawRect(x + 1, y + 1, size - 2, size - 2, text_muted);
    if (!exists) {
        drawRect(x + 8, y + 7, 12, 12, portrait_shadow);
        drawRect(x + 9, y + 8, 10, 10, text_muted);
        text.drawSmallLineTight(setPixel, video.screen_width, "NEW", x + 9, y + 21, text_dark);
        return;
    }

    drawRect(x + 5, y + 3, 16, 5, portrait_hair);
    drawRect(x + 4, y + 8, 20, 6, portrait_hair);
    drawRect(x + 3, y + 14, 7, 7, portrait_hair);
    drawRect(x + 19, y + 12, 6, 9, portrait_hair);
    drawRect(x + 8, y + 13, 13, 7, portrait_skin);
    drawRect(x + 9, y + 20, 10, 4, portrait_skin);
    drawRect(x + 8, y + 24, 13, 3, portrait_blue);
    drawRect(x + 13, y + 22, 3, 3, portrait_skin);
    drawRect(x + 10, y + 9, 4, 5, portrait_shadow);
    drawRect(x + 21, y + 15, 2, 4, portrait_shadow);
}

fn drawBerryIcon(x: i16, y: i16) void {
    drawRect(x + 2, y, 3, 1, portrait_hair);
    drawRect(x + 1, y + 1, 5, 1, berry_red);
    drawRect(x, y + 2, 7, 3, berry_red);
    drawRect(x + 1, y + 5, 5, 1, berry_red);
    setPixel(x + 3, y + 6, berry_red);
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
