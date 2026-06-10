const gba = @import("gba");
const background = @import("background.zig");
const chapter_systems = @import("../chapters/systems.zig");
const frame = @import("../core/frame.zig");
const graphics_reset = @import("../core/graphics_reset.zig");
const video = @import("../core/video.zig");
const level = @import("../generated_rooms.zig");
const room_systems = @import("room_systems.zig");

pub const RoomLoadMode = enum {
    initial,
    transition,
    respawn,
};

const rooms = level.rooms;

pub fn loadGameplayRoom(room_index: usize, mode: RoomLoadMode) void {
    loadGameplayRoomBackground(room_index);
    loadGameplayRoomStaticState(room_index);
    loadGameplayRoomObjectSprites(room_index);
    loadGameplayRoomAfterObjectSprites(room_index, mode);
    loadGameplayRoomParallax(room_index);
}

pub fn loadGameplayRoomPhased(room_index: usize, mode: RoomLoadMode) void {
    loadGameplayRoomBackground(room_index);
    frame.sync();
    loadGameplayRoomStaticState(room_index);
    frame.sync();
    loadGameplayRoomObjectSprites(room_index);
    frame.sync();
    loadGameplayRoomAfterObjectSprites(room_index, mode);
    loadGameplayRoomParallax(room_index);
    frame.sync();
}

pub fn loadGameplayRoomBackground(room_index: usize) void {
    gba.display.hideAllObjects();
    loadRoomBackground(room_index);
}

pub fn loadGameplayRoomStaticState(room_index: usize) void {
    room_systems.loadStaticState(room_index);
}

pub fn loadGameplayRoomObjectSprites(room_index: usize) void {
    graphics_reset.clearObjectGraphics();
    room_systems.loadObjectSprites(room_index);
}

pub fn loadGameplayRoomAfterObjectSprites(room_index: usize, mode: RoomLoadMode) void {
    room_systems.loadAfterObjectSprites(room_index, mode == .transition);
}

pub fn loadGameplayRoomParallax(room_index: usize) void {
    room_systems.loadParallax(room_index);
}

pub fn hideGameplayDisplayForLoad() void {
    gba.display.bg_palette.colors[0] = .black;
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    gba.display.hideAllObjects();
}

pub fn showGameplayDisplay(room_index: usize) void {
    // Menus and overworld use different BG priorities. Restore gameplay
    // priorities here so low-priority room sprites do not end up behind BG0.
    gba.display.bg_ctrl[0] = .init(.{
        .priority = 2,
        .base_screenblock = video.bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
    });
    gba.display.bg_ctrl[1] = .init(.{
        .priority = 0,
        .base_charblock = video.parallax_charblock,
        .base_screenblock = video.parallax_screenblock,
        .size = .size_32x32,
        .bpp = .bpp_4,
    });
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = background.hasForegroundLayer(rooms[room_index]),
        .obj = true,
    });
}

fn loadRoomBackground(room_index: usize) void {
    background.resetRoomStream();
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.bg_palette.colors[background.static_wire_bg_color_index] = gba.ColorRgb555.rgb(13, 14, 18);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
    chapter_systems.resetPaletteState(room_index);
}
