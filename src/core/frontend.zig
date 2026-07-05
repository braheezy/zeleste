const gba = @import("gba");

const city = @import("../chapters/city.zig");
const file_select = @import("file_select.zig");
const frame = @import("frame.zig");
const inner_monologue = @import("inner_monologue.zig");
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
    return runMapOnly();
}

pub fn runMapOnly() StartSelection {
    while (true) {
        overworld_placeholder.loadScreen();
        const chapter_selection = waitForChapterSelection();
        if (chapter_selection == .back) {
            _ = file_select.chooseSlot();
            continue;
        }

        const selected_respawn = overworld_placeholder.selectedRespawn();
        const room_index = if (selected_respawn) |respawn| respawn.room_index else switch (chapter_selection) {
            .prologue => level.start_room_index,
            .city => city.flow.firstRoomIndex() orelse level.start_room_index,
            .none, .back => level.start_room_index,
        };
        if (chapter_selection == .prologue) {
            inner_monologue.showPrologueIntro();
        }
        save.beginChapterRunForRoom(room_index);
        return .{
            .room_index = room_index,
            .respawn = selected_respawn orelse .{
                .room_index = room_index,
                .spawn = level.rooms[room_index].spawn,
            },
        };
    }
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
