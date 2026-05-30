const gba = @import("gba");
const background = @import("background.zig");
const chapter_systems = @import("../chapters/systems.zig");
const level = @import("../generated_rooms.zig");
const room_systems = @import("room_systems.zig");

pub const RoomLoadMode = enum {
    initial,
    transition,
    respawn,
};

const rooms = level.rooms;

pub fn loadGameplayRoom(room_index: usize, mode: RoomLoadMode) void {
    loadRoomBackground(room_index);
    room_systems.load(room_index, mode == .transition);
}

pub fn hideGameplayDisplayForLoad() void {
    gba.display.bg_palette.colors[0] = .black;
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    gba.display.hideAllObjects();
}

pub fn showGameplayDisplay(room_index: usize) void {
    gba.display.ctrl.bg0 = true;
    gba.display.ctrl.bg1 = rooms[room_index].parallax != null;
    gba.display.ctrl.obj = true;
}

fn loadRoomBackground(room_index: usize) void {
    background.resetRoomStream();
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.bg_palette.colors[background.static_wire_bg_color_index] = gba.ColorRgb555.rgb(13, 14, 18);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
    chapter_systems.resetPaletteState(room_index);
}
