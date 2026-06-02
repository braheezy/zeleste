const gba = @import("gba");

const assets = @import("assets.zig");
const background = @import("../world/background.zig");
const frame = @import("frame.zig");
const video = @import("video.zig");

const width_tiles = 30;
const height_tiles = 20;
const display_frames: u16 = 120;

const SplashImage = struct {
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
};

pub fn show() void {
    var input: gba.input.BufferedKeysState = .{};
    showImage(&input, .{
        .tiles = &assets.splash1_tiles_data,
        .map = &assets.splash1_map_data,
        .palette = &assets.splash1_palette_data,
    });
    showImage(&input, .{
        .tiles = &assets.splash3_tiles_data,
        .map = &assets.splash3_map_data,
        .palette = &assets.splash3_palette_data,
    });
}

fn showImage(input: *gba.input.BufferedKeysState, image: SplashImage) void {
    loadScreen(image);

    var frame_count: u16 = 0;
    while (frame_count < display_frames) : (frame_count += 1) {
        input.poll();
        if (input.isJustPressed(.A)) return;
        frame.syncFrontend();
    }
}

fn loadScreen(image: SplashImage) void {
    gba.display.hideAllObjects();
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    background.clearParallaxMap();
    background.resetRoomStream();
    background.resetParallaxStream();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 0,
        .base_screenblock = video.bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });

    gba.mem.memcpy(gba.display.bg_palette, @ptrCast(image.palette), image.palette.len);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(image.tiles));
    drawMap(image.map);
    gba.display.bg_scroll[0] = .init(0, 0);
    gba.display.bg_scroll[1] = .init(0, 0);
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = false,
        .obj = false,
    });
}

fn drawMap(map_data: []align(4) const u8) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    var index: usize = 0;
    while (index < video.bg_hardware_width_tiles * video.bg_hardware_height_tiles) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }

    var y: usize = 0;
    while (y < height_tiles) : (y += 1) {
        var x: usize = 0;
        while (x < width_tiles) : (x += 1) {
            const source_offset = (y * width_tiles + x) * 2;
            const raw_entry = @as(u16, map_data[source_offset]) |
                (@as(u16, map_data[source_offset + 1]) << 8);
            entries[background.normalBgMapIndex(x, y, video.bg_hardware_width_tiles)] = @bitCast(raw_entry);
        }
    }
}
