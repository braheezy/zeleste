const gba = @import("gba");
const camera_mod = @import("camera.zig");
const dust = @import("dust.zig");
const math = @import("math.zig");
const oam = @import("oam.zig");
const room_data = @import("room_data.zig");
const text_mod = @import("text.zig");
const video = @import("video.zig");

const Camera = camera_mod.Camera;
const CutsceneDialoguePage = room_data.CutsceneDialoguePage;
const SceneRect = room_data.SceneRect;
const clampI16 = math.clampI16;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

pub const Cache = struct {
    rendered_index: u8 = 255,
    rendered_offset: usize = 0xffff,
    rendered_reveal_offset: usize = 0xffff,

    pub fn invalidate(self: *Cache) void {
        self.* = .{};
    }
};

pub const cols = 6;
pub const rows = 3;
pub const object_count = cols * rows;
pub const width = cols * 32;
pub const height = rows * 16;
pub const tiles_per_object = 8;
pub const tile_count = object_count * tiles_per_object;
pub const base_tile: u10 = 848;
pub const palette_bank: u4 = dust.palette_bank;
pub const text_max_chars = 30;
pub const text_max_lines = 3;

const madeline_name_color: u8 = 7;
const granny_name_color: u8 = 8;
const default_name_color: u8 = 3;

var visible: bool = false;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;

pub fn renderPage(page: CutsceneDialoguePage, dialogue_index: u8, dialogue_offset: usize, dialogue_reveal_offset: usize, typewriter: bool, cache: *Cache) usize {
    const page_end = text_mod.wrappedNextOffset(page.text, dialogue_offset, text_max_chars, text_max_lines);
    const reveal_end = if (typewriter)
        @min(dialogue_reveal_offset, page_end)
    else
        page_end;
    if (cache.rendered_index == dialogue_index and
        cache.rendered_offset == dialogue_offset and
        cache.rendered_reveal_offset == reveal_end)
    {
        return page_end;
    }

    clearTiles();
    drawBox();
    text_mod.drawLine(setPixel, width, page.speaker, 6, 4, speakerNameColor(page.speaker));
    text_mod.drawWrappedUntil(setPixel, width, page.text, dialogue_offset, reveal_end, 6, 17, text_max_chars, text_max_lines, 1);
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
    cache.* = .{
        .rendered_index = dialogue_index,
        .rendered_offset = dialogue_offset,
        .rendered_reveal_offset = reveal_end,
    };
    return page_end;
}

pub fn drawObjects(camera: Camera, first_object: usize, dialogue_box: SceneRect) void {
    const position = room_data.Spawn{
        .x = clampI16(dialogue_box.x - camera.x, 0, video.screen_width - width),
        .y = clampI16(dialogue_box.y - camera.y, 0, video.screen_height - height),
    };
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const object_index = first_object + row * cols + col;
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

fn drawBox() void {
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
