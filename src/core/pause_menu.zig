const gba = @import("gba");

const audio = @import("audio.zig");
const assets = @import("assets.zig");
const frame = @import("frame.zig");
const obj_vram = @import("obj_vram.zig");
const oam = @import("oam.zig");
const save = @import("save.zig");
const ui_sfx = @import("ui_sfx.zig");

const font_masks_data align(4) = assets.bitmap_font_masks_data;
const font_meta = assets.bitmap_font_meta;

pub const Action = enum {
    resume_game,
    retry,
    save_and_quit,
    restart_chapter,
    exit_to_map,
};

const MenuItem = struct {
    label: []const u8,
    kind: Kind,
    action: Action = .resume_game,

    const Kind = enum {
        action,
        options_menu,
        music_volume,
        sfx_volume,
        audio_debug,
    };
};

const Screen = enum {
    main,
    options,
};

const main_items = [_]MenuItem{
    .{ .label = "RESUME", .kind = .action, .action = .resume_game },
    .{ .label = "RETRY", .kind = .action, .action = .retry },
    .{ .label = "OPTIONS", .kind = .options_menu },
    .{ .label = "SAVE AND QUIT", .kind = .action, .action = .save_and_quit },
    .{ .label = "RESTART CHAPTER", .kind = .action, .action = .restart_chapter },
    .{ .label = "EXIT TO MAP", .kind = .action, .action = .exit_to_map },
};

const option_items = [_]MenuItem{
    .{ .label = "MUSIC", .kind = .music_volume },
    .{ .label = "SFX", .kind = .sfx_volume },
    .{ .label = "SFX WATCH", .kind = .audio_debug },
};
const options_menu_index: usize = 2;

const first_object: usize = 72;
const base_tile: u10 = @intCast(obj_vram.pause_menu.start);
const palette_bank: u4 = 15;
const title_objects: usize = 4;
const title_tiles_per_object: usize = 16;
const menu_objects_per_line: usize = 4;
const menu_tiles_per_object: usize = 8;
const menu_line_count: usize = 5;
const total_tiles: usize = title_objects * title_tiles_per_object + menu_line_count * menu_objects_per_line * menu_tiles_per_object;
const object_count: usize = title_objects + menu_line_count * menu_objects_per_line;

const title_width: i16 = title_objects * 32;
const title_height: i16 = 32;
const menu_width: i16 = menu_objects_per_line * 32;
const menu_height: i16 = 16;
const title_scale: i16 = 5;
const menu_scale: i16 = 2;
const title_y: i16 = 28;
const menu_y: i16 = 70;
const menu_spacing: i16 = 18;
const bounce_ticks: u8 = 16;

const color_transparent: u8 = 0;
const color_white: u8 = 1;
const color_selected: u8 = 2;
const color_title: u8 = 3;
const color_blue_shadow: u8 = 4;
const color_shadow: u8 = 5;

var tiles: [total_tiles]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** total_tiles;
var saved_bg_palette: [256]gba.ColorRgb555 = undefined;
var saved_obj_palette: [256]gba.ColorRgb555 = undefined;

pub fn run() Action {
    var screen: Screen = .main;
    var selected: usize = 0;
    var previous_vertical: i16 = 0;
    var previous_horizontal: i16 = 0;
    var confirm_released = false;
    var tick: u8 = 0;

    saveAndDimPalettes();
    loadPausePalette();
    render(screen, selected, tick);

    var input: gba.input.BufferedKeysState = .{};
    while (true) {
        input.poll();
        if (!input.isPressed(.A) and !input.isPressed(.start)) confirm_released = true;

        const vertical: i16 = @intCast(input.getAxisVertical());
        const items = menuItems(screen);
        if (vertical < 0 and previous_vertical >= 0) {
            selected = if (selected == 0) items.len - 1 else selected - 1;
            ui_sfx.menuRollUp();
            render(screen, selected, tick);
        } else if (vertical > 0 and previous_vertical <= 0) {
            selected = if (selected + 1 >= items.len) 0 else selected + 1;
            ui_sfx.menuRollDown();
            render(screen, selected, tick);
        }
        previous_vertical = vertical;

        const horizontal: i16 = @intCast(input.getAxisHorizontal());
        if (horizontal < 0 and previous_horizontal >= 0) {
            if (adjustSelected(screen, selected, -1)) {
                ui_sfx.menuRollUp();
                render(screen, selected, tick);
            }
        } else if (horizontal > 0 and previous_horizontal <= 0) {
            if (adjustSelected(screen, selected, 1)) {
                ui_sfx.menuRollDown();
                render(screen, selected, tick);
            }
        }
        previous_horizontal = horizontal;

        if (input.isJustPressed(.B)) {
            ui_sfx.buttonBack();
            if (screen == .options) {
                screen = .main;
                selected = options_menu_index;
                render(screen, selected, tick);
                continue;
            }
            cleanup();
            return .resume_game;
        }
        if (confirm_released and (input.isJustPressed(.A) or input.isJustPressed(.start))) {
            const item = menuItems(screen)[selected];
            if (item.kind == .action) {
                ui_sfx.buttonSelect();
                cleanup();
                return item.action;
            }
            if (item.kind == .options_menu) {
                ui_sfx.buttonSelect();
                screen = .options;
                selected = 0;
                render(screen, selected, tick);
            } else if (confirmSetting(screen, selected)) {
                ui_sfx.buttonSelect();
                render(screen, selected, tick);
            } else {
                ui_sfx.buttonInvalid();
            }
        }

        tick +%= 1;
        if (tick % bounce_ticks == 0) render(screen, selected, tick);
        frame.syncFrontend();
    }
}

fn cleanup() void {
    restorePalettes();
    hideObjects();
}

fn saveAndDimPalettes() void {
    var index: usize = 0;
    while (index < saved_bg_palette.len) : (index += 1) {
        saved_bg_palette[index] = gba.display.bg_palette.colors[index];
        saved_obj_palette[index] = gba.display.obj_palette.colors[index];
        gba.display.bg_palette.colors[index] = dimColor(saved_bg_palette[index]);
        gba.display.obj_palette.colors[index] = dimColor(saved_obj_palette[index]);
    }
}

fn restorePalettes() void {
    var index: usize = 0;
    while (index < saved_bg_palette.len) : (index += 1) {
        gba.display.bg_palette.colors[index] = saved_bg_palette[index];
        gba.display.obj_palette.colors[index] = saved_obj_palette[index];
    }
}

fn dimColor(color: gba.ColorRgb555) gba.ColorRgb555 {
    return gba.ColorRgb555.rgb(
        @intCast(color.r / 2),
        @intCast(color.g / 2),
        @intCast(color.b / 2),
    );
}

fn loadPausePalette() void {
    const base = @as(usize, palette_bank) * 16;
    gba.display.obj_palette.colors[base + color_transparent] = .black;
    gba.display.obj_palette.colors[base + color_white] = .white;
    gba.display.obj_palette.colors[base + color_selected] = gba.ColorRgb555.rgb(31, 31, 6);
    gba.display.obj_palette.colors[base + color_title] = gba.ColorRgb555.rgb(23, 23, 24);
    gba.display.obj_palette.colors[base + color_blue_shadow] = gba.ColorRgb555.rgb(7, 7, 20);
    gba.display.obj_palette.colors[base + color_shadow] = gba.ColorRgb555.rgb(1, 1, 4);
}

fn render(screen: Screen, selected: usize, tick: u8) void {
    clearTiles();
    const title = titleForScreen(screen);
    const title_text_scale = titleScaleForScreen(screen);
    drawCenteredText(title, 0, title_width, title_height, title_text_scale, color_blue_shadow, 2, 3);
    drawCenteredText(title, 0, title_width, title_height, title_text_scale, color_title, 0, 0);

    const items = menuItems(screen);
    const first_visible = firstVisibleIndex(selected, items.len);
    var row: usize = 0;
    while (row < menu_line_count) : (row += 1) {
        const index = first_visible + row;
        if (index >= items.len) break;
        const item = items[index];
        const tile_offset = title_objects * title_tiles_per_object + row * menu_objects_per_line * menu_tiles_per_object;
        const selected_item = index == selected;
        const color = if (selected_item) color_selected else color_white;
        const bounce_y: i16 = if (selected_item and ((tick / bounce_ticks) & 1) != 0) -1 else 0;
        switch (item.kind) {
            .action => {
                drawCenteredText(item.label, tile_offset, menu_width, menu_height, menu_scale, color_shadow, 1, 1 + bounce_y);
                drawCenteredText(item.label, tile_offset, menu_width, menu_height, menu_scale, color, 0, bounce_y);
            },
            .options_menu => {
                drawCenteredText(item.label, tile_offset, menu_width, menu_height, menu_scale, color_shadow, 1, 1 + bounce_y);
                drawCenteredText(item.label, tile_offset, menu_width, menu_height, menu_scale, color, 0, bounce_y);
            },
            .music_volume => drawVolumeRow(item.label, save.musicVolumeStep(), tile_offset, selected_item, bounce_y),
            .sfx_volume => drawVolumeRow(item.label, save.sfxVolumeStep(), tile_offset, selected_item, bounce_y),
            .audio_debug => drawToggleRow(save.audioDebugEnabled(), tile_offset, selected_item, bounce_y),
        }
    }

    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
    drawObjects();
}

fn menuItems(screen: Screen) []const MenuItem {
    return switch (screen) {
        .main => main_items[0..],
        .options => option_items[0..],
    };
}

fn titleForScreen(screen: Screen) []const u8 {
    return switch (screen) {
        .main => "PAUSED",
        .options => "OPTIONS",
    };
}

fn titleScaleForScreen(screen: Screen) i16 {
    return switch (screen) {
        .main => title_scale,
        .options => 4,
    };
}

fn firstVisibleIndex(selected: usize, item_count: usize) usize {
    if (item_count <= menu_line_count) return 0;
    const center_offset = menu_line_count / 2;
    var first = if (selected > center_offset) selected - center_offset else 0;
    const max_first = item_count - menu_line_count;
    if (first > max_first) first = max_first;
    return first;
}

fn adjustSelected(screen: Screen, selected: usize, delta: i16) bool {
    return switch (menuItems(screen)[selected].kind) {
        .music_volume => adjustMusicVolume(delta),
        .sfx_volume => adjustSfxVolume(delta),
        .audio_debug => blk: {
            if (delta == 0) break :blk false;
            toggleAudioDebug();
            break :blk true;
        },
        .action, .options_menu => false,
    };
}

fn confirmSetting(screen: Screen, selected: usize) bool {
    return switch (menuItems(screen)[selected].kind) {
        .music_volume => adjustMusicVolume(1),
        .sfx_volume => adjustSfxVolume(1),
        .audio_debug => blk: {
            toggleAudioDebug();
            break :blk true;
        },
        .action, .options_menu => false,
    };
}

fn adjustMusicVolume(delta: i16) bool {
    const next = adjustedVolumeStep(save.musicVolumeStep(), delta);
    if (next == save.musicVolumeStep()) return false;
    save.setMusicVolumeStep(next);
    audio.setMusicVolumeStep(next);
    return true;
}

fn adjustSfxVolume(delta: i16) bool {
    const next = adjustedVolumeStep(save.sfxVolumeStep(), delta);
    if (next == save.sfxVolumeStep()) return false;
    save.setSfxVolumeStep(next);
    audio.setSfxVolumeStep(next);
    return true;
}

fn adjustedVolumeStep(current: u8, delta: i16) u8 {
    const value = @as(i16, current) + delta;
    if (value < 0) return 0;
    if (value > @as(i16, audio.volume_step_count)) return audio.volume_step_count;
    return @intCast(value);
}

fn toggleAudioDebug() void {
    save.setAudioDebugEnabled(!save.audioDebugEnabled());
}

fn clearTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** total_tiles;
}

fn drawVolumeRow(label: []const u8, step: u8, tile_offset: usize, selected: bool, bounce_y: i16) void {
    const color = if (selected) color_selected else color_white;
    const text_y: i16 = 5 + bounce_y;
    drawText(label, tile_offset, menu_width, 1, 8, text_y, color_shadow);
    drawText(label, tile_offset, menu_width, 1, 7, text_y - 1, color);
    drawSlider(tile_offset, step, selected, bounce_y);
}

fn drawSlider(tile_offset: usize, step: u8, selected: bool, bounce_y: i16) void {
    const segment_width: i16 = 5;
    const segment_height: i16 = 6;
    const segment_gap: i16 = 1;
    const x: i16 = 58;
    const y: i16 = 5 + bounce_y;
    var segment: u8 = 0;
    while (segment < audio.volume_step_count) : (segment += 1) {
        const segment_x = x + @as(i16, segment) * (segment_width + segment_gap);
        const filled = segment < step;
        const color = if (filled)
            (if (selected) color_selected else color_white)
        else
            color_shadow;
        drawRect(tile_offset, menu_width, segment_x, y, segment_width, segment_height, color);
    }
}

fn drawToggleRow(enabled: bool, tile_offset: usize, selected: bool, bounce_y: i16) void {
    const color = if (selected) color_selected else color_white;
    const text = if (enabled) "SFX WATCH ON" else "SFX WATCH OFF";
    drawCenteredText(text, tile_offset, menu_width, menu_height, 1, color_shadow, 1, 1 + bounce_y);
    drawCenteredText(text, tile_offset, menu_width, menu_height, 1, color, 0, bounce_y);
}

fn drawRect(tile_offset: usize, area_width: i16, x: i16, y: i16, width: i16, height: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < height) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < width) : (xx += 1) {
            setPixel(tile_offset, area_width, x + xx, y + yy, color);
        }
    }
}

fn drawCenteredText(text: []const u8, tile_offset: usize, width: i16, height: i16, scale: i16, color: u8, dx: i16, dy: i16) void {
    const text_width = textPixelWidth(text, scale);
    const text_height = @as(i16, font_meta.glyph_height) * scale;
    const x = @divTrunc(width - text_width, 2) + dx;
    const y = @divTrunc(height - text_height, 2) + dy;
    drawText(text, tile_offset, width, scale, x, y, color);
}

fn textPixelWidth(text: []const u8, scale: i16) i16 {
    var width: i16 = 0;
    for (text) |ch| {
        width += if (ch == ' ') scale * 2 else (@as(i16, font_meta.glyph_width) + 1) * scale;
    }
    if (width > 0) width -= scale;
    return width;
}

fn drawText(text: []const u8, tile_offset: usize, area_width: i16, scale: i16, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (text) |ch| {
        if (ch == ' ') {
            cursor += scale * 2;
            continue;
        }
        drawGlyph(ch, tile_offset, area_width, cursor, y, scale, color);
        cursor += (@as(i16, font_meta.glyph_width) + 1) * scale;
    }
}

fn drawGlyph(input: u8, tile_offset: usize, area_width: i16, x: i16, y: i16, scale: i16, color: u8) void {
    const glyph = glyphIndex(input) orelse return;
    const glyph_offset = glyph * font_meta.glyph_height;
    var row: usize = 0;
    while (row < font_meta.glyph_height) : (row += 1) {
        const bits = font_masks_data[glyph_offset + row];
        var col: usize = 0;
        while (col < font_meta.glyph_width) : (col += 1) {
            if ((bits & (@as(u8, 1) << @intCast(font_meta.glyph_width - 1 - col))) == 0) continue;
            drawScaledPixel(tile_offset, area_width, x + @as(i16, @intCast(col)) * scale, y + @as(i16, @intCast(row)) * scale, scale, color);
        }
    }
}

fn drawScaledPixel(tile_offset: usize, area_width: i16, x: i16, y: i16, scale: i16, color: u8) void {
    var yy: i16 = 0;
    while (yy < scale) : (yy += 1) {
        var xx: i16 = 0;
        while (xx < scale) : (xx += 1) {
            setPixel(tile_offset, area_width, x + xx, y + yy, color);
        }
    }
}

fn setPixel(tile_offset: usize, area_width: i16, x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= area_width) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const object_x = ux / 32;
    const tile_x = (ux & 31) / 8;
    const tile_y = uy / 8;
    const local_x = ux & 7;
    const local_y = uy & 7;
    const tiles_per_object: usize = if (tile_offset == 0) title_tiles_per_object else menu_tiles_per_object;
    if (tile_y >= tiles_per_object / 4) return;
    const tile_index = tile_offset + object_x * tiles_per_object + tile_y * 4 + tile_x;
    if (tile_index >= tiles.len) return;
    const byte_index = local_y * 4 + local_x / 2;
    if ((local_x & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0f) | (color << 4);
    }
}

fn drawObjects() void {
    const title_x: i16 = @divTrunc(240 - title_width, 2);
    var object_offset: usize = 0;
    var col: usize = 0;
    while (col < title_objects) : (col += 1) {
        drawObject(object_offset, title_x + @as(i16, @intCast(col * 32)), title_y, .size_32x32, @intCast(col * title_tiles_per_object));
        object_offset += 1;
    }

    const menu_x: i16 = @divTrunc(240 - menu_width, 2);
    var row: usize = 0;
    while (row < menu_line_count) : (row += 1) {
        col = 0;
        while (col < menu_objects_per_line) : (col += 1) {
            const tile = title_objects * title_tiles_per_object + row * menu_objects_per_line * menu_tiles_per_object + col * menu_tiles_per_object;
            drawObject(object_offset, menu_x + @as(i16, @intCast(col * 32)), menu_y + @as(i16, @intCast(row)) * menu_spacing, .size_32x16, @intCast(tile));
            object_offset += 1;
        }
    }
}

fn drawObject(index: usize, x: i16, y: i16, size: gba.display.Object.Size, tile_offset: u10) void {
    gba.display.objects[first_object + index] = gba.display.Object.init(.{
        .size = size,
        .x = oam.objX(x),
        .y = oam.objY(y),
        .base_tile = base_tile + tile_offset,
        .priority = 0,
        .palette = palette_bank,
    });
}

fn hideObjects() void {
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        oam.hideObject(first_object + index);
    }
}

fn glyphIndex(input: u8) ?usize {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    for (font_meta.chars, 0..) |candidate, index| {
        if (candidate == ch) return index;
    }
    return null;
}
