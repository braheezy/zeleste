const gba = @import("gba");
const chapter_entities = @import("../chapters/entities.zig");
const camera = @import("camera.zig");
const room_data = @import("room_data.zig");
const video = @import("../core/video.zig");

const invalid_room_index = ~@as(usize, 0);
const max_wire_chunks = 48;
const max_hidden_cover_groups = 64;

pub const static_wire_bg_color_index: u8 = 250;
const static_wire_bg_max_tiles = max_wire_chunks * 4;

var bg_stream_room_index: usize = invalid_room_index;
var bg_stream_tile_x: i16 = -32768;
var bg_stream_tile_y: i16 = -32768;
var parallax_stream_room_index: usize = invalid_room_index;
var parallax_stream_tile_x: i16 = -32768;
var parallax_stream_tile_y: i16 = -32768;
var parallax_tile_offset: u16 = 0;
var static_wire_bg_tiles: [static_wire_bg_max_tiles]gba.display.Tile8Bpp align(4) = [_]gba.display.Tile8Bpp{gba.display.Tile8Bpp.init([_]u8{0} ** 64)} ** static_wire_bg_max_tiles;
var hidden_cover_group_count: usize = 0;
var hidden_cover_revealed: [max_hidden_cover_groups]bool = [_]bool{false} ** max_hidden_cover_groups;

pub fn resetRoomStream() void {
    bg_stream_room_index = invalid_room_index;
    bg_stream_tile_x = -32768;
    bg_stream_tile_y = -32768;
}

pub fn resetParallaxStream() void {
    parallax_stream_room_index = invalid_room_index;
    parallax_stream_tile_x = -32768;
    parallax_stream_tile_y = -32768;
}

pub fn applyCamera(room_index: usize, room: room_data.RoomBackground, view: camera.Camera) void {
    streamRoomBackground(room_index, room, view);
    gba.display.bg_scroll[0] = .init(@intCast(view.x), @intCast(view.y));
}

pub fn loadParallax(room: room_data.RoomBackground) void {
    clearParallaxMap();
    resetParallaxStream();
    gba.display.ctrl.bg1 = false;
    resetHiddenCoverState(room);
    if (hasHiddenCoverLayer(room)) {
        loadHiddenCoverLayer(room);
        gba.display.ctrl.bg1 = true;
        return;
    }
    if (room.parallax) |parallax| {
        const palette: *align(2) const gba.display.Palette.Bank = @ptrCast(parallax.palette.ptr);
        gba.display.memcpyBackgroundPaletteBank(15, 0, palette);
        const tile_count = parallax.tiles.len / 32;
        const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(parallax.tiles.ptr);
        const charblock3_start_bytes: usize = 3 * 16 * 1024;
        const used_bg_bytes = room.tiles.len;
        const tile_offset_bytes = if (used_bg_bytes > charblock3_start_bytes) used_bg_bytes - charblock3_start_bytes else 0;
        parallax_tile_offset = @intCast((tile_offset_bytes + 31) / 32);
        gba.display.memcpyTiles4Bpp(video.parallax_charblock, parallax_tile_offset, tiles[0..tile_count]);
        gba.display.ctrl.bg1 = true;
    }
}

pub fn updateParallax(room_index: usize, room: room_data.RoomBackground, view: camera.Camera) void {
    if (hasHiddenCoverLayer(room)) {
        streamHiddenCoverBackground(room_index, room, view.x, view.y);
        gba.display.bg_scroll[1] = .init(@intCast(view.x), @intCast(view.y));
        gba.display.ctrl.bg1 = true;
        return;
    }

    const maybe_parallax = room.parallax;
    if (maybe_parallax == null) {
        gba.display.ctrl.bg1 = false;
        return;
    }

    const parallax = maybe_parallax.?;
    const extra_x: i16 = if (parallax.scroll_extra_x_divisor == 0) 0 else @divTrunc(view.x, parallax.scroll_extra_x_divisor);
    const extra_y: i16 = if (parallax.scroll_extra_y_divisor == 0) 0 else @divTrunc(view.y, parallax.scroll_extra_y_divisor);
    const scroll_x = view.x + extra_x - parallax.world_x;
    const scroll_y = view.y + extra_y - parallax.world_y;
    streamParallaxBackground(room_index, parallax, scroll_x, scroll_y);
    gba.display.bg_scroll[1] = .init(@intCast(scroll_x), @intCast(scroll_y));
    gba.display.ctrl.bg1 = true;
}

pub fn hasForegroundLayer(room: room_data.RoomBackground) bool {
    return hasHiddenCoverLayer(room) or room.parallax != null;
}

pub fn updateHiddenCovers(room_index: usize, room: room_data.RoomBackground, player_left: i16, player_top: i16, player_right: i16, player_bottom: i16) void {
    _ = room_index;
    if (!hasHiddenCoverLayer(room) or hidden_cover_group_count == 0) return;
    if (player_right <= 0 or player_bottom <= 0 or player_left >= room.width_pixels or player_top >= room.height_pixels) return;

    const left_px = @max(@as(i16, 0), player_left);
    const top_px = @max(@as(i16, 0), player_top);
    const right_px = @min(room.width_pixels - 1, player_right - 1);
    const bottom_px = @min(room.height_pixels - 1, player_bottom - 1);
    if (right_px < left_px or bottom_px < top_px) return;

    const start_tile_x = @divTrunc(left_px, 8);
    const end_tile_x = @divTrunc(right_px, 8);
    const start_tile_y = @divTrunc(top_px, 8);
    const end_tile_y = @divTrunc(bottom_px, 8);
    var revealed_any = false;
    var tile_y = start_tile_y;
    while (tile_y <= end_tile_y) : (tile_y += 1) {
        var tile_x = start_tile_x;
        while (tile_x <= end_tile_x) : (tile_x += 1) {
            const ux: usize = @intCast(tile_x);
            const uy: usize = @intCast(tile_y);
            const tile_offset = uy * room.width_tiles + ux;
            if (tile_offset >= room.hidden_cover_groups.len) continue;
            const group_byte = room.hidden_cover_groups[tile_offset];
            if (group_byte == 0) continue;
            const group: usize = @intCast(group_byte - 1);
            if (group >= hidden_cover_group_count or hidden_cover_revealed[group]) continue;
            hidden_cover_revealed[group] = true;
            revealed_any = true;
        }
    }
    if (revealed_any) {
        resetParallaxStream();
    }
}

pub fn streamRoomBackground(room_index: usize, room: room_data.RoomBackground, view: camera.Camera) void {
    if (roomFitsHardwareBackground(room)) {
        if (bg_stream_room_index != room_index or bg_stream_tile_x != 0 or bg_stream_tile_y != 0) {
            streamRoomBackgroundFull(room_index, room, 0, 0);
        }
        return;
    }

    const tile_x = @divTrunc(view.x, 8);
    const tile_y = @divTrunc(view.y, 8);
    if (bg_stream_room_index != room_index) {
        streamRoomBackgroundFull(room_index, room, tile_x, tile_y);
        return;
    }

    const delta_x = tile_x - bg_stream_tile_x;
    const delta_y = tile_y - bg_stream_tile_y;
    if (delta_x == 0 and delta_y == 0) return;

    const hardware_width: i16 = @intCast(video.bg_hardware_width_tiles);
    const hardware_height: i16 = @intCast(video.bg_hardware_height_tiles);
    if (delta_x <= -hardware_width or delta_x >= hardware_width or delta_y <= -hardware_height or delta_y >= hardware_height) {
        streamRoomBackgroundFull(room_index, room, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        var stream_x = bg_stream_tile_x + 1;
        while (stream_x <= tile_x) : (stream_x += 1) {
            streamRoomBackgroundColumn(room, stream_x + hardware_width - 1, tile_y);
        }
    } else if (delta_x < 0) {
        var stream_x = bg_stream_tile_x - 1;
        while (stream_x >= tile_x) : (stream_x -= 1) {
            streamRoomBackgroundColumn(room, stream_x, tile_y);
        }
    }

    if (delta_y > 0) {
        var stream_y = bg_stream_tile_y + 1;
        while (stream_y <= tile_y) : (stream_y += 1) {
            streamRoomBackgroundRow(room, tile_x, stream_y + hardware_height - 1);
        }
    } else if (delta_y < 0) {
        var stream_y = bg_stream_tile_y - 1;
        while (stream_y >= tile_y) : (stream_y -= 1) {
            streamRoomBackgroundRow(room, tile_x, stream_y);
        }
    }

    bg_stream_tile_x = tile_x;
    bg_stream_tile_y = tile_y;
}

pub fn roomFitsHardwareBackground(room: room_data.RoomBackground) bool {
    return room.width_tiles <= video.bg_hardware_width_tiles and room.height_tiles <= video.bg_hardware_height_tiles;
}

fn streamRoomBackgroundFull(room_index: usize, room: room_data.RoomBackground, source_tile_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);

    var dest_y: usize = 0;
    while (dest_y < video.bg_hardware_height_tiles) : (dest_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(dest_y));
        var dest_x: usize = 0;
        while (dest_x < video.bg_hardware_width_tiles) : (dest_x += 1) {
            const src_x = source_tile_x + @as(i16, @intCast(dest_x));
            const raw_entry = visibleRoomMapEntry(room_index, room, src_x, src_y);
            const hardware_x = wrapTileIndex(src_x, video.bg_hardware_width_tiles);
            const hardware_y = wrapTileIndex(src_y, video.bg_hardware_height_tiles);
            entries[normalBgMapIndex(hardware_x, hardware_y, video.bg_hardware_width_tiles)] = @bitCast(raw_entry);
        }
    }
    bg_stream_room_index = room_index;
    bg_stream_tile_x = source_tile_x;
    bg_stream_tile_y = source_tile_y;
    if (source_tile_x == 0 and source_tile_y == 0 and roomFitsHardwareBackground(room)) {
        stampStaticRoomWires(room);
    }
}

fn streamRoomBackgroundColumn(room: room_data.RoomBackground, src_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    const hardware_x = wrapTileIndex(src_x, video.bg_hardware_width_tiles);
    var offset_y: usize = 0;
    while (offset_y < video.bg_hardware_height_tiles) : (offset_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(offset_y));
        const hardware_y = wrapTileIndex(src_y, video.bg_hardware_height_tiles);
        const raw_entry = visibleRoomMapEntry(bg_stream_room_index, room, src_x, src_y);
        entries[normalBgMapIndex(hardware_x, hardware_y, video.bg_hardware_width_tiles)] = @bitCast(raw_entry);
    }
}

fn streamRoomBackgroundRow(room: room_data.RoomBackground, source_tile_x: i16, src_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    const hardware_y = wrapTileIndex(src_y, video.bg_hardware_height_tiles);
    var offset_x: usize = 0;
    while (offset_x < video.bg_hardware_width_tiles) : (offset_x += 1) {
        const src_x = source_tile_x + @as(i16, @intCast(offset_x));
        const hardware_x = wrapTileIndex(src_x, video.bg_hardware_width_tiles);
        const raw_entry = visibleRoomMapEntry(bg_stream_room_index, room, src_x, src_y);
        entries[normalBgMapIndex(hardware_x, hardware_y, video.bg_hardware_width_tiles)] = @bitCast(raw_entry);
    }
}

fn stampStaticRoomWires(room: room_data.RoomBackground) void {
    const data = room.wires;
    if (data.len < 2 or room.wire_tiles.len == 0) return;
    if (!canStampStaticRoomWires(room)) return;

    const room_tile_count = room.tiles.len / 64;
    const tile_capacity = staticWireTileCapacity(room);
    if (room_tile_count >= tile_capacity) return;

    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.bg_screenblock].entries);
    const count = @min(room_data.readU16Le(data, 0), max_wire_chunks);
    var output_tile_count: usize = 0;
    var offset: usize = 2;
    var index: usize = 0;
    while (index < count and offset + 8 <= data.len and output_tile_count + 4 <= static_wire_bg_max_tiles and room_tile_count + output_tile_count + 4 <= tile_capacity) : ({
        index += 1;
        offset += 8;
    }) {
        const wire_x = room_data.readI16Le(data, offset);
        const wire_y = room_data.readI16Le(data, offset + 2);
        if (wire_x < 0 or wire_y < 0) continue;

        const tile_x: usize = @intCast(@divTrunc(wire_x, 8));
        const tile_y: usize = @intCast(@divTrunc(wire_y, 8));
        if (tile_y >= room.height_tiles or tile_x >= room.width_tiles) continue;

        const wire_tile_offset = room_data.readU16Le(data, offset + 4);
        var part: usize = 0;
        while (part < 4 and tile_x + part < room.width_tiles) : (part += 1) {
            const map_x = tile_x + part;
            const raw_entry = logicalRoomMapEntry(room, @intCast(map_x), @intCast(tile_y));
            const source_tile = raw_entry & 0x03ff;
            if (@as(usize, source_tile) * 64 + 63 >= room.tiles.len) continue;

            composeStaticWireTile(room, raw_entry, @as(usize, wire_tile_offset) + part, output_tile_count);
            const new_tile: u16 = @intCast(room_tile_count + output_tile_count);
            entries[normalBgMapIndex(map_x, tile_y, video.bg_hardware_width_tiles)] = @bitCast((raw_entry & 0xf000) | new_tile);
            output_tile_count += 1;
        }
    }

    if (output_tile_count != 0) {
        gba.display.memcpyTiles8Bpp(0, @intCast(room_tile_count), static_wire_bg_tiles[0..output_tile_count]);
    }
}

pub fn canStampStaticRoomWires(room: room_data.RoomBackground) bool {
    if (!roomFitsHardwareBackground(room) or room.wires.len < 2 or room.wire_tiles.len == 0) return false;

    const output_tile_count = staticWireOutputTileCount(room);
    if (output_tile_count == 0 or output_tile_count > static_wire_bg_max_tiles) return false;
    return room.tiles.len / 64 + output_tile_count <= staticWireTileCapacity(room);
}

fn staticWireTileCapacity(room: room_data.RoomBackground) usize {
    const first_reserved_screenblock: usize = if (room.parallax != null)
        @min(@as(usize, video.bg_screenblock), @as(usize, video.parallax_screenblock))
    else
        @as(usize, video.bg_screenblock);
    return (first_reserved_screenblock * 2048) / 64;
}

fn staticWireOutputTileCount(room: room_data.RoomBackground) usize {
    const data = room.wires;
    const count = @min(room_data.readU16Le(data, 0), max_wire_chunks);
    var output_tile_count: usize = 0;
    var offset: usize = 2;
    var index: usize = 0;
    while (index < count and offset + 8 <= data.len) : ({
        index += 1;
        offset += 8;
    }) {
        const wire_x = room_data.readI16Le(data, offset);
        const wire_y = room_data.readI16Le(data, offset + 2);
        if (wire_x < 0 or wire_y < 0) continue;

        const tile_x: usize = @intCast(@divTrunc(wire_x, 8));
        const tile_y: usize = @intCast(@divTrunc(wire_y, 8));
        if (tile_y >= room.height_tiles or tile_x >= room.width_tiles) continue;

        var part: usize = 0;
        while (part < 4 and tile_x + part < room.width_tiles) : (part += 1) {
            const raw_entry = logicalRoomMapEntry(room, @intCast(tile_x + part), @intCast(tile_y));
            const source_tile = raw_entry & 0x03ff;
            if (@as(usize, source_tile) * 64 + 63 >= room.tiles.len) continue;
            output_tile_count += 1;
        }
    }
    return output_tile_count;
}

fn composeStaticWireTile(room: room_data.RoomBackground, raw_entry: u16, wire_tile_index: usize, output_tile_index: usize) void {
    const source_tile = @as(usize, raw_entry & 0x03ff);
    const hflip = (raw_entry & 0x0400) != 0;
    const vflip = (raw_entry & 0x0800) != 0;

    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            const source_x = if (hflip) 7 - x else x;
            const source_y = if (vflip) 7 - y else y;
            var color = room.tiles[source_tile * 64 + source_y * 8 + source_x];
            if (wireTilePixel(wire_tile_index, x, y, room.wire_tiles) != 0) {
                color = static_wire_bg_color_index;
            }
            static_wire_bg_tiles[output_tile_index].pixels[y * 8 + x] = color;
        }
    }
}

fn wireTilePixel(tile_index: usize, x: usize, y: usize, tiles: []align(4) const u8) u8 {
    const byte_offset = tile_index * 32 + y * 4 + x / 2;
    if (byte_offset >= tiles.len) return 0;
    const byte = tiles[byte_offset];
    return if ((x & 1) == 0) byte & 0x0f else byte >> 4;
}

pub fn logicalRoomMapEntry(room: room_data.RoomBackground, x: i16, y: i16) u16 {
    if (x < 0 or y < 0) return 0;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= room.width_tiles or uy >= room.height_tiles) return 0;
    const offset = (uy * room.width_tiles + ux) * 2;
    if (offset + 1 >= room.map.len) return 0;
    return @as(u16, room.map[offset]) | (@as(u16, room.map[offset + 1]) << 8);
}

fn visibleRoomMapEntry(room_index: usize, room: room_data.RoomBackground, x: i16, y: i16) u16 {
    if (chapter_entities.bgTileBroken(room_index, x, y)) return 0;
    return logicalRoomMapEntry(room, x, y);
}

fn loadHiddenCoverLayer(room: room_data.RoomBackground) void {
    const palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(room.hidden_cover_palette.ptr);
    gba.display.memcpyBackgroundPaletteBank(15, 0, palette[0..16]);
    const tile_count = room.hidden_cover_tiles.len / 32;
    const tiles: [*]align(2) const gba.display.Tile4Bpp = @ptrCast(room.hidden_cover_tiles.ptr);
    const charblock3_start_bytes: usize = 3 * 16 * 1024;
    const used_bg_bytes = room.tiles.len;
    const tile_offset_bytes = if (used_bg_bytes > charblock3_start_bytes) used_bg_bytes - charblock3_start_bytes else 0;
    parallax_tile_offset = @intCast((tile_offset_bytes + 31) / 32);
    gba.display.memcpyTiles4Bpp(video.parallax_charblock, parallax_tile_offset, tiles[0..tile_count]);
}

fn resetHiddenCoverState(room: room_data.RoomBackground) void {
    hidden_cover_group_count = if (room.hidden_covers.len >= 2)
        @min(@as(usize, room_data.readU16Le(room.hidden_covers, 0)), max_hidden_cover_groups)
    else
        0;
    for (&hidden_cover_revealed) |*revealed| {
        revealed.* = false;
    }
}

fn hasHiddenCoverLayer(room: room_data.RoomBackground) bool {
    return room.hidden_cover_tiles.len != 0 and
        room.hidden_cover_map.len != 0 and
        room.hidden_cover_groups.len != 0 and
        room.hidden_cover_palette.len >= 32;
}

fn streamHiddenCoverBackground(room_index: usize, room: room_data.RoomBackground, scroll_x: i16, scroll_y: i16) void {
    const tile_x = @divTrunc(scroll_x, 8);
    const tile_y = @divTrunc(scroll_y, 8);
    if (parallax_stream_room_index != room_index) {
        streamHiddenCoverBackgroundFull(room_index, room, tile_x, tile_y);
        return;
    }

    const delta_x = tile_x - parallax_stream_tile_x;
    const delta_y = tile_y - parallax_stream_tile_y;
    if (delta_x == 0 and delta_y == 0) return;
    const hardware_width: i16 = @intCast(video.parallax_hardware_width_tiles);
    const hardware_height: i16 = @intCast(video.parallax_hardware_height_tiles);
    if (delta_x <= -hardware_width or delta_x >= hardware_width or delta_y <= -hardware_height or delta_y >= hardware_height) {
        streamHiddenCoverBackgroundFull(room_index, room, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        var stream_x = parallax_stream_tile_x + 1;
        while (stream_x <= tile_x) : (stream_x += 1) {
            streamHiddenCoverBackgroundColumn(room, stream_x + hardware_width - 1, tile_y);
        }
    } else if (delta_x < 0) {
        var stream_x = parallax_stream_tile_x - 1;
        while (stream_x >= tile_x) : (stream_x -= 1) {
            streamHiddenCoverBackgroundColumn(room, stream_x, tile_y);
        }
    }

    if (delta_y > 0) {
        var stream_y = parallax_stream_tile_y + 1;
        while (stream_y <= tile_y) : (stream_y += 1) {
            streamHiddenCoverBackgroundRow(room, tile_x, stream_y + hardware_height - 1);
        }
    } else if (delta_y < 0) {
        var stream_y = parallax_stream_tile_y - 1;
        while (stream_y >= tile_y) : (stream_y -= 1) {
            streamHiddenCoverBackgroundRow(room, tile_x, stream_y);
        }
    }

    parallax_stream_room_index = room_index;
    parallax_stream_tile_x = tile_x;
    parallax_stream_tile_y = tile_y;
}

fn streamHiddenCoverBackgroundFull(room_index: usize, room: room_data.RoomBackground, source_tile_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    var dest_y: usize = 0;
    while (dest_y < video.parallax_hardware_height_tiles) : (dest_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(dest_y));
        var dest_x: usize = 0;
        while (dest_x < video.parallax_hardware_width_tiles) : (dest_x += 1) {
            const src_x = source_tile_x + @as(i16, @intCast(dest_x));
            const raw_entry = logicalHiddenCoverMapEntry(room, src_x, src_y);
            const adjusted_entry = adjustParallaxMapEntry(raw_entry);
            const hardware_x = wrapTileIndex(src_x, video.parallax_hardware_width_tiles);
            const hardware_y = wrapTileIndex(src_y, video.parallax_hardware_height_tiles);
            entries[normalBgMapIndex(hardware_x, hardware_y, video.parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
        }
    }
    parallax_stream_room_index = room_index;
    parallax_stream_tile_x = source_tile_x;
    parallax_stream_tile_y = source_tile_y;
}

fn streamHiddenCoverBackgroundColumn(room: room_data.RoomBackground, src_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    const hardware_x = wrapTileIndex(src_x, video.parallax_hardware_width_tiles);
    var offset_y: usize = 0;
    while (offset_y < video.parallax_hardware_height_tiles) : (offset_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(offset_y));
        const hardware_y = wrapTileIndex(src_y, video.parallax_hardware_height_tiles);
        const raw_entry = logicalHiddenCoverMapEntry(room, src_x, src_y);
        const adjusted_entry = adjustParallaxMapEntry(raw_entry);
        entries[normalBgMapIndex(hardware_x, hardware_y, video.parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
    }
}

fn streamHiddenCoverBackgroundRow(room: room_data.RoomBackground, source_tile_x: i16, src_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    const hardware_y = wrapTileIndex(src_y, video.parallax_hardware_height_tiles);
    var offset_x: usize = 0;
    while (offset_x < video.parallax_hardware_width_tiles) : (offset_x += 1) {
        const src_x = source_tile_x + @as(i16, @intCast(offset_x));
        const hardware_x = wrapTileIndex(src_x, video.parallax_hardware_width_tiles);
        const raw_entry = logicalHiddenCoverMapEntry(room, src_x, src_y);
        const adjusted_entry = adjustParallaxMapEntry(raw_entry);
        entries[normalBgMapIndex(hardware_x, hardware_y, video.parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
    }
}

fn logicalHiddenCoverMapEntry(room: room_data.RoomBackground, x: i16, y: i16) u16 {
    if (x < 0 or y < 0) return 0;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= room.width_tiles or uy >= room.height_tiles) return 0;
    const tile_offset = uy * room.width_tiles + ux;
    if (tile_offset >= room.hidden_cover_groups.len) return 0;
    const group: usize = @intCast(room.hidden_cover_groups[tile_offset]);
    if (group != 0 and group - 1 < hidden_cover_group_count and hidden_cover_revealed[group - 1]) return 0;
    const map_offset = tile_offset * 2;
    if (map_offset + 1 >= room.hidden_cover_map.len) return 0;
    return @as(u16, room.hidden_cover_map[map_offset]) | (@as(u16, room.hidden_cover_map[map_offset + 1]) << 8);
}

fn streamParallaxBackground(room_index: usize, parallax: room_data.ParallaxLayer, scroll_x: i16, scroll_y: i16) void {
    const tile_x = @divTrunc(scroll_x, 8);
    const tile_y = @divTrunc(scroll_y, 8);
    if (parallax_stream_room_index != room_index) {
        streamParallaxBackgroundFull(room_index, parallax, tile_x, tile_y);
        return;
    }

    const delta_x = tile_x - parallax_stream_tile_x;
    const delta_y = tile_y - parallax_stream_tile_y;
    if (delta_x == 0 and delta_y == 0) return;
    const hardware_width: i16 = @intCast(video.parallax_hardware_width_tiles);
    const hardware_height: i16 = @intCast(video.parallax_hardware_height_tiles);
    if (delta_x <= -hardware_width or delta_x >= hardware_width or delta_y <= -hardware_height or delta_y >= hardware_height) {
        streamParallaxBackgroundFull(room_index, parallax, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        var stream_x = parallax_stream_tile_x + 1;
        while (stream_x <= tile_x) : (stream_x += 1) {
            streamParallaxBackgroundColumn(parallax, stream_x + hardware_width - 1, tile_y);
        }
    } else if (delta_x < 0) {
        var stream_x = parallax_stream_tile_x - 1;
        while (stream_x >= tile_x) : (stream_x -= 1) {
            streamParallaxBackgroundColumn(parallax, stream_x, tile_y);
        }
    }

    if (delta_y > 0) {
        var stream_y = parallax_stream_tile_y + 1;
        while (stream_y <= tile_y) : (stream_y += 1) {
            streamParallaxBackgroundRow(parallax, tile_x, stream_y + hardware_height - 1);
        }
    } else if (delta_y < 0) {
        var stream_y = parallax_stream_tile_y - 1;
        while (stream_y >= tile_y) : (stream_y -= 1) {
            streamParallaxBackgroundRow(parallax, tile_x, stream_y);
        }
    }

    parallax_stream_room_index = room_index;
    parallax_stream_tile_x = tile_x;
    parallax_stream_tile_y = tile_y;
}

fn streamParallaxBackgroundFull(room_index: usize, parallax: room_data.ParallaxLayer, source_tile_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    var dest_y: usize = 0;
    while (dest_y < video.parallax_hardware_height_tiles) : (dest_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(dest_y));
        var dest_x: usize = 0;
        while (dest_x < video.parallax_hardware_width_tiles) : (dest_x += 1) {
            const src_x = source_tile_x + @as(i16, @intCast(dest_x));
            const raw_entry = logicalParallaxMapEntry(parallax, src_x, src_y);
            const adjusted_entry = adjustParallaxMapEntry(raw_entry);
            const hardware_x = wrapTileIndex(src_x, video.parallax_hardware_width_tiles);
            const hardware_y = wrapTileIndex(src_y, video.parallax_hardware_height_tiles);
            entries[normalBgMapIndex(hardware_x, hardware_y, video.parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
        }
    }
    parallax_stream_room_index = room_index;
    parallax_stream_tile_x = source_tile_x;
    parallax_stream_tile_y = source_tile_y;
}

fn streamParallaxBackgroundColumn(parallax: room_data.ParallaxLayer, src_x: i16, source_tile_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    const hardware_x = wrapTileIndex(src_x, video.parallax_hardware_width_tiles);
    var offset_y: usize = 0;
    while (offset_y < video.parallax_hardware_height_tiles) : (offset_y += 1) {
        const src_y = source_tile_y + @as(i16, @intCast(offset_y));
        const hardware_y = wrapTileIndex(src_y, video.parallax_hardware_height_tiles);
        const raw_entry = logicalParallaxMapEntry(parallax, src_x, src_y);
        const adjusted_entry = adjustParallaxMapEntry(raw_entry);
        entries[normalBgMapIndex(hardware_x, hardware_y, video.parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
    }
}

fn streamParallaxBackgroundRow(parallax: room_data.ParallaxLayer, source_tile_x: i16, src_y: i16) void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    const hardware_y = wrapTileIndex(src_y, video.parallax_hardware_height_tiles);
    var offset_x: usize = 0;
    while (offset_x < video.parallax_hardware_width_tiles) : (offset_x += 1) {
        const src_x = source_tile_x + @as(i16, @intCast(offset_x));
        const hardware_x = wrapTileIndex(src_x, video.parallax_hardware_width_tiles);
        const raw_entry = logicalParallaxMapEntry(parallax, src_x, src_y);
        const adjusted_entry = adjustParallaxMapEntry(raw_entry);
        entries[normalBgMapIndex(hardware_x, hardware_y, video.parallax_hardware_width_tiles)] = @bitCast(adjusted_entry);
    }
}

fn logicalParallaxMapEntry(parallax: room_data.ParallaxLayer, x: i16, y: i16) u16 {
    if (x < 0 or y < 0) return 0;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= parallax.width_tiles or uy >= parallax.height_tiles) return 0;
    const offset = (uy * parallax.width_tiles + ux) * 2;
    if (offset + 1 >= parallax.map.len) return 0;
    return @as(u16, parallax.map[offset]) | (@as(u16, parallax.map[offset + 1]) << 8);
}

fn adjustParallaxMapEntry(entry: u16) u16 {
    return (entry & 0xFC00) | (((entry & 0x03FF) + parallax_tile_offset) & 0x03FF);
}

fn rectsOverlap(a_left: i16, a_top: i16, a_right: i16, a_bottom: i16, b_left: i16, b_top: i16, b_right: i16, b_bottom: i16) bool {
    return a_right > b_left and a_left < b_right and a_bottom > b_top and a_top < b_bottom;
}

pub fn clearParallaxMap() void {
    const entries: [*]volatile gba.display.Screenblock.Entry = @ptrCast(&gba.display.screenblocks[video.parallax_screenblock].entries);
    var index: usize = 0;
    while (index < 1024) : (index += 1) {
        entries[index] = @bitCast(@as(u16, 0));
    }
}

pub fn normalBgMapIndex(x: usize, y: usize, map_width_tiles: usize) usize {
    const screenblock_x = x >> 5;
    const screenblock_y = y >> 5;
    const screenblock_columns = map_width_tiles >> 5;
    const screenblock_index = screenblock_x + (screenblock_y * screenblock_columns);
    return (screenblock_index << 10) + (x & 31) + ((y & 31) << 5);
}

fn wrapTileIndex(value: i16, comptime modulo: usize) usize {
    const wrapped = @mod(value, @as(i16, @intCast(modulo)));
    return @intCast(wrapped);
}
