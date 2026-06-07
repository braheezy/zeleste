const gba = @import("gba");

const city = @import("../chapters/city.zig");
const file_select = @import("file_select.zig");
const frame = @import("frame.zig");
const level = @import("../generated_rooms.zig");
const overworld_placeholder = @import("../world/overworld_placeholder.zig");
const room_data = @import("../world/room_data.zig");
const save = @import("save.zig");
const title_menu = @import("title_menu.zig");

const RespawnPoint = room_data.RespawnPoint;

pub const StartSelection = struct {
    room_index: usize,
    respawn: RespawnPoint,
};

pub fn run() StartSelection {
    title_menu.showAndWait();
    _ = file_select.chooseSlot();
    overworld_placeholder.loadScreen();
    const chapter_selection = waitForChapterSelection();

    const room_index = switch (chapter_selection) {
        .prologue => level.start_room_index,
        .city => city.flow.firstRoomIndex() orelse level.start_room_index,
        .none => level.start_room_index,
    };
    save.beginChapterRunForRoom(room_index);
    return .{
        .room_index = room_index,
        .respawn = .{
            .room_index = room_index,
            .spawn = level.rooms[room_index].spawn,
        },
    };
}

fn waitForChapterSelection() overworld_placeholder.Selection {
    var input: gba.input.BufferedKeysState = .{};
    while (true) {
        input.poll();
        const selection = overworld_placeholder.update(input);
        if (selection != .none) return selection;

        frame.syncFrontend();
    }
}
