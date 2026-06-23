const gba = @import("gba");

const audio = @import("audio.zig");
const assets = @import("assets.zig");
const obj_vram = @import("obj_vram.zig");
const oam = @import("oam.zig");
const save = @import("save.zig");

const sound_ids = assets.sound_ids;

const first_object: usize = 126;
const object_count: usize = 2;
const tiles_per_object: usize = 4;
const tile_count: usize = object_count * tiles_per_object;
const base_tile: u10 = @intCast(obj_vram.audio_debug.start);
const line_len: usize = 16;
const line_width: usize = 64;
const glyph_width: usize = 3;
const glyph_height: usize = 5;
const glyph_advance: usize = 4;
const hold_frames: u8 = 90;

var palette_bank: u4 = 0;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var initialized = false;
var visible = false;
var suppressed = false;
var held_sound_id: u16 = 0;
var held_timer: u8 = 0;

pub fn init(object_palette_bank: u4) void {
    palette_bank = object_palette_bank;
    initialized = true;
    visible = false;
    suppressed = false;
    held_sound_id = 0;
    held_timer = 0;
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 0] = .black;
    gba.display.obj_palette.colors[@as(usize, palette_bank) * 16 + 1] = .white;
    clearTiles();
    uploadTiles();
}

pub fn setSuppressed(should_suppress: bool) void {
    suppressed = should_suppress;
    if (suppressed) hideIfVisible();
}

pub fn clearHold() void {
    held_sound_id = 0;
    held_timer = 0;
    hideIfVisible();
}

pub fn update() void {
    if (!initialized) return;
    if (suppressed or !save.audioDebugEnabled()) {
        hideIfVisible();
        return;
    }

    renderLine();
    uploadTiles();
    drawObjects();
    visible = true;
}

fn renderLine() void {
    clearTiles();
    var line = [_]u8{' '} ** line_len;

    if (audio.activeSoundEffectId(0)) |sound_id| {
        held_sound_id = sound_id;
        held_timer = hold_frames;
    } else if (held_timer > 0) {
        held_timer -= 1;
    } else {
        hideIfVisible();
        return;
    }

    writeText(&line, debugName(held_sound_id));
    drawText(&line);
}

fn writeText(line: *[line_len]u8, source: []const u8) void {
    const limit = @min(line.len, source.len);
    var index: usize = 0;
    while (index < limit) : (index += 1) {
        line[index] = normalizedChar(source[index]);
    }
}

fn drawText(line: *const [line_len]u8) void {
    for (line.*, 0..) |ch, index| {
        const x = index * glyph_advance;
        if (x + glyph_width > line_width) break;
        drawGlyph(ch, x, 1);
    }
}

fn drawGlyph(ch: u8, x: usize, y: usize) void {
    if (ch == ' ') return;
    const rows = glyphRows(ch);
    for (rows, 0..) |bits, row| {
        var col: usize = 0;
        while (col < glyph_width) : (col += 1) {
            if ((bits & (@as(u8, 1) << @intCast(glyph_width - 1 - col))) != 0) {
                setPixel(x + col, y + row, 1);
            }
        }
    }
}

fn glyphRows(ch: u8) [glyph_height]u8 {
    return switch (ch) {
        '0' => .{ 0b111, 0b101, 0b101, 0b101, 0b111 },
        '1' => .{ 0b010, 0b110, 0b010, 0b010, 0b111 },
        '2' => .{ 0b111, 0b001, 0b111, 0b100, 0b111 },
        '3' => .{ 0b111, 0b001, 0b111, 0b001, 0b111 },
        '4' => .{ 0b101, 0b101, 0b111, 0b001, 0b001 },
        '5' => .{ 0b111, 0b100, 0b111, 0b001, 0b111 },
        '6' => .{ 0b111, 0b100, 0b111, 0b101, 0b111 },
        '7' => .{ 0b111, 0b001, 0b010, 0b010, 0b010 },
        '8' => .{ 0b111, 0b101, 0b111, 0b101, 0b111 },
        '9' => .{ 0b111, 0b101, 0b111, 0b001, 0b111 },
        'A' => .{ 0b010, 0b101, 0b111, 0b101, 0b101 },
        'B' => .{ 0b110, 0b101, 0b110, 0b101, 0b110 },
        'C' => .{ 0b111, 0b100, 0b100, 0b100, 0b111 },
        'D' => .{ 0b110, 0b101, 0b101, 0b101, 0b110 },
        'E' => .{ 0b111, 0b100, 0b110, 0b100, 0b111 },
        'F' => .{ 0b111, 0b100, 0b110, 0b100, 0b100 },
        'G' => .{ 0b111, 0b100, 0b101, 0b101, 0b111 },
        'H' => .{ 0b101, 0b101, 0b111, 0b101, 0b101 },
        'I' => .{ 0b111, 0b010, 0b010, 0b010, 0b111 },
        'J' => .{ 0b001, 0b001, 0b001, 0b101, 0b111 },
        'K' => .{ 0b101, 0b101, 0b110, 0b101, 0b101 },
        'L' => .{ 0b100, 0b100, 0b100, 0b100, 0b111 },
        'M' => .{ 0b101, 0b111, 0b111, 0b101, 0b101 },
        'N' => .{ 0b101, 0b111, 0b111, 0b111, 0b101 },
        'O' => .{ 0b111, 0b101, 0b101, 0b101, 0b111 },
        'P' => .{ 0b111, 0b101, 0b111, 0b100, 0b100 },
        'Q' => .{ 0b111, 0b101, 0b101, 0b111, 0b001 },
        'R' => .{ 0b110, 0b101, 0b110, 0b101, 0b101 },
        'S' => .{ 0b111, 0b100, 0b111, 0b001, 0b111 },
        'T' => .{ 0b111, 0b010, 0b010, 0b010, 0b010 },
        'U' => .{ 0b101, 0b101, 0b101, 0b101, 0b111 },
        'V' => .{ 0b101, 0b101, 0b101, 0b101, 0b010 },
        'W' => .{ 0b101, 0b101, 0b111, 0b111, 0b101 },
        'X' => .{ 0b101, 0b101, 0b010, 0b101, 0b101 },
        'Y' => .{ 0b101, 0b101, 0b010, 0b010, 0b010 },
        'Z' => .{ 0b111, 0b001, 0b010, 0b100, 0b111 },
        '_' => .{ 0b000, 0b000, 0b000, 0b000, 0b111 },
        else => .{ 0, 0, 0, 0, 0 },
    };
}

fn clearTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
}

fn setPixel(x: usize, y: usize, color: u8) void {
    if (x >= line_width or y >= 8) return;
    const tile_index = x / 8;
    const local_x = x & 7;
    const byte_index = y * 4 + local_x / 2;
    if ((local_x & 1) == 0) {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        tiles[tile_index].data_8[byte_index] = (tiles[tile_index].data_8[byte_index] & 0x0f) | (color << 4);
    }
}

fn uploadTiles() void {
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
}

fn drawObjects() void {
    gba.display.ctrl.obj = true;
    var slot: usize = 0;
    while (slot < object_count) : (slot += 1) {
        gba.display.objects[first_object + slot] = gba.display.Object.init(.{
            .size = .size_32x8,
            .x = oam.objX(@intCast(slot * 32)),
            .y = oam.objY(0),
            .base_tile = base_tile + @as(u10, @intCast(slot * tiles_per_object)),
            .priority = 0,
            .palette = palette_bank,
        });
    }
}

fn hideIfVisible() void {
    if (!visible) return;
    var slot: usize = 0;
    while (slot < object_count) : (slot += 1) {
        oam.hideObject(first_object + slot);
    }
    visible = false;
}

fn normalizedChar(ch: u8) u8 {
    if (ch >= 'a' and ch <= 'z') return ch - 32;
    if ((ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_') return ch;
    return ' ';
}

fn debugName(sound_id: u16) []const u8 {
    return switch (sound_id) {
        sound_ids.sfx_ui_main_title_firstinput => "TITLE_FIRST_IN",
        sound_ids.sfx_ui_main_button_select => "BUTTON_SELECT",
        sound_ids.sfx_ui_main_button_back => "BUTTON_BACK",
        sound_ids.sfx_ui_main_button_invalid => "BUTTON_INVALID",
        sound_ids.sfx_ui_main_roll_up => "ROLL_UP",
        sound_ids.sfx_ui_main_roll_down => "ROLL_DOWN",
        sound_ids.sfx_ui_main_whoosh_savefile_in => "SAVEFILE_OPEN",
        sound_ids.sfx_ui_main_whoosh_savefile_out => "SAVEFILE_CLOSE",
        sound_ids.sfx_ui_main_savefile_roll_01 => "SAVEFILE_ROLL_01",
        sound_ids.sfx_ui_main_savefile_roll_02 => "SAVEFILE_ROLL_02",
        sound_ids.sfx_ui_main_savefile_roll_03 => "SAVEFILE_ROLL_03",
        sound_ids.sfx_ui_main_savefile_delete => "SAVEFILE_DELETE",
        sound_ids.sfx_ui_world_icon_roll_left => "WORLD_ROLL_LEFT",
        sound_ids.sfx_ui_world_icon_roll_right => "WORLD_ROLL_RIGHT",
        sound_ids.sfx_ui_world_icon_flip_left => "WORLD_FLIP_LEFT",
        sound_ids.sfx_ui_world_icon_flip_right => "WORLD_FLIP_RIGHT",
        sound_ids.sfx_ui_world_chapter_level_select => "WORLD_SELECT",
        sound_ids.sfx_ui_game_textbox_madeline_in => "TEXTBOX_MAD_IN",
        sound_ids.sfx_ui_game_textbox_madeline_out => "TEXTBOX_MAD_OUT",
        sound_ids.sfx_ui_game_textbox_other_in => "TEXTBOX_OTH_IN",
        sound_ids.sfx_ui_game_textbox_other_out => "TEXTBOX_OTH_OUT",
        sound_ids.sfx_ui_game_textadvance_madeline => "TEXTADV_MAD",
        sound_ids.sfx_ui_game_textadvance_other => "TEXTADV_OTH",
        sound_ids.sfx_ui_game_text_general => "TEXT_GENERAL",
        sound_ids.sfx_jump => "SFX_JUMP",
        sound_ids.sfx_jump_wall_left => "SFX_JUMP_WALL_LEFT",
        sound_ids.sfx_jump_wall_right => "SFX_JUMP_WALL_RIGHT",
        sound_ids.sfx_dash_red_left => "SFX_DASH_RED_LEFT",
        sound_ids.sfx_dash_red_right => "SFX_DASH_RED_RIGHT",
        sound_ids.sfx_death => "SFX_DEATH",
        else => "SFX_UNKNOWN",
    };
}
