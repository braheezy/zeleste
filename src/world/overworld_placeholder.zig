const gba = @import("gba");
const assets = @import("../core/assets.zig");
const background = @import("background.zig");
const video = @import("../core/video.zig");

const bg_tiles_data align(4) = assets.overworld_bg_tiles_data;
const bg_map_data align(4) = assets.overworld_bg_map_data;
const bg_palette_data align(4) = assets.overworld_bg_palette_data;

const bg_screenblock = video.bg_screenblock;
const bg_hardware_width_tiles = video.bg_hardware_width_tiles;
const bg_hardware_height_tiles = video.bg_hardware_height_tiles;
const width_tiles = 30;
const height_tiles = 20;

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

    gba.mem.memcpy(gba.display.bg_palette, @ptrCast(&bg_palette_data), bg_palette_data.len);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(&bg_tiles_data));
    drawMap();
    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.bg0 = true;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
}

fn drawMap() void {
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
            const raw_entry = @as(u16, bg_map_data[source_offset]) |
                (@as(u16, bg_map_data[source_offset + 1]) << 8);
            entries[background.normalBgMapIndex(x, y, bg_hardware_width_tiles)] = @bitCast(raw_entry);
        }
    }
}
