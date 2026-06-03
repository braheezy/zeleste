const gba = @import("gba");
const chapter_entities = @import("../chapters/entities.zig");
const camera = @import("camera.zig");
const room_data = @import("room_data.zig");
const video = @import("../core/video.zig");

const invalid_room_index = ~@as(usize, 0);
const max_wire_chunks = 48;

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
    if (room.parallax) |parallax| {
        gba.mem.memcpy16(&gba.display.bg_palette.colors[@as(usize, 15) * 16], @ptrCast(parallax.palette.ptr), 16);
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

    if (delta_x < -1 or delta_x > 1 or delta_y < -1 or delta_y > 1) {
        streamRoomBackgroundFull(room_index, room, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        streamRoomBackgroundColumn(room, tile_x + @as(i16, @intCast(video.bg_hardware_width_tiles - 1)), tile_y);
    } else if (delta_x < 0) {
        streamRoomBackgroundColumn(room, tile_x, tile_y);
    }

    if (delta_y > 0) {
        streamRoomBackgroundRow(room, tile_x, tile_y + @as(i16, @intCast(video.bg_hardware_height_tiles - 1)));
    } else if (delta_y < 0) {
        streamRoomBackgroundRow(room, tile_x, tile_y);
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
    if (delta_x < -1 or delta_x > 1 or delta_y < -1 or delta_y > 1) {
        streamParallaxBackgroundFull(room_index, parallax, tile_x, tile_y);
        return;
    }

    if (delta_x > 0) {
        streamParallaxBackgroundColumn(parallax, tile_x + @as(i16, @intCast(video.parallax_hardware_width_tiles - 1)), tile_y);
    } else if (delta_x < 0) {
        streamParallaxBackgroundColumn(parallax, tile_x, tile_y);
    }

    if (delta_y > 0) {
        streamParallaxBackgroundRow(parallax, tile_x, tile_y + @as(i16, @intCast(video.parallax_hardware_height_tiles - 1)));
    } else if (delta_y < 0) {
        streamParallaxBackgroundRow(parallax, tile_x, tile_y);
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
