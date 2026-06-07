const gba = @import("gba");

const assets = @import("assets.zig");
const oam = @import("oam.zig");
const save = @import("save.zig");
const video = @import("video.zig");

const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const tiles_data align(4) = assets.save_icon_tiles_data;
const palette_data align(4) = assets.save_icon_palette_data;
const meta = assets.save_icon_meta;

const first_object_index = 4;
const object_count = 4;
const base_tile: u10 = 784;
const palette_bank: u4 = 14;
const frame_ticks: u8 = 8;
const hold_frames: u8 = 30;
const screen_margin: i16 = 3;
const visible_frames: u8 = @intCast(meta.frame_count * frame_ticks + hold_frames);

var observed_commit_serial: u32 = 0;
var timer: u8 = 0;
var palette_loaded = false;
var loaded_frame: u16 = 0xffff;

pub fn reset() void {
    observed_commit_serial = save.commitSerial();
    timer = 0;
    invalidateGraphics();
    hideObjects();
}

pub fn invalidateGraphics() void {
    palette_loaded = false;
    loaded_frame = 0xffff;
}

pub fn update() void {
    const current_serial = save.commitSerial();
    if (current_serial != observed_commit_serial) {
        observed_commit_serial = current_serial;
        timer = visible_frames;
    } else if (timer != 0) {
        timer -= 1;
    }
}

pub fn draw() void {
    if (timer == 0) {
        hideObjects();
        return;
    }

    loadPalette();
    loadFrame(currentFrame());

    const x = video.screen_width - meta.cell_width - screen_margin;
    const y = screen_margin;
    drawChunk(0, x, y, .size_32x32, 0);
    drawChunk(1, x + 32, y, .size_16x32, 16);
    drawChunk(2, x, y + 32, .size_32x16, 24);
    drawChunk(3, x + 32, y + 32, .size_16x16, 32);
}

fn currentFrame() u16 {
    const elapsed = visible_frames - timer;
    const frame = @divTrunc(@as(u16, elapsed), frame_ticks);
    return @min(meta.frame_count - 1, frame);
}

fn loadPalette() void {
    if (palette_loaded) return;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    palette_loaded = true;
}

fn loadFrame(frame: u16) void {
    if (loaded_frame == frame) return;
    const byte_offset = @as(usize, frame) * @as(usize, meta.tiles_per_frame) * 32;
    const byte_len = @as(usize, meta.tiles_per_frame) * 32;
    const frame_bytes = tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_frame = frame;
}

fn drawChunk(chunk: usize, x: i16, y: i16, size: gba.display.Object.Size, tile_offset: u10) void {
    gba.display.objects[first_object_index + chunk] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = base_tile + tile_offset,
        .priority = 1,
        .palette = palette_bank,
    });
}

fn hideObjects() void {
    var index: usize = 0;
    while (index < object_count) : (index += 1) {
        hideObject(first_object_index + index);
    }
}
