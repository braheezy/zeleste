const gba = @import("gba");

const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dynamic_object_slots = @import("dynamic_object_slots.zig");
const falling_blocks = @import("falling_blocks.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mech_blocks = @import("mech_blocks.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const rooms = level.rooms;

pub const max_blocks = 16;

const record_bytes = 8;
const base_tile: u10 = 536;
const tiles_per_variant: u10 = 4;
const tile_count = tiles_per_variant * 4;
const palette_bank: u4 = 1;
const color_frames: u16 = 60;

const Color = enum(u8) {
    blue = 0,
    pink = 1,
};

const Block = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    color: Color = .blue,
    suppressed: bool = false,
};

var blocks: [max_blocks]Block = [_]Block{.{}} ** max_blocks;
var block_count: usize = 0;
var timer: u16 = 0;
var tiles: [tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    blocks = [_]Block{.{}} ** max_blocks;
    block_count = 0;
    timer = 0;
    hideObjects();

    const data = rooms[room_index].rhythm_blocks;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_blocks);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;

        blocks[block_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
            .color = if (data[source_offset + 6] == 1) .pink else .blue,
        };
        block_count += 1;
    }
}

pub fn loadGraphics() void {
    if (block_count == 0) return;
    loadPalette();
    buildTiles();
    gba.display.memcpyObjectTiles4Bpp(base_tile, &tiles);
}

pub fn update(player: *Player) void {
    if (block_count == 0) return;
    timer = (timer + 1) % (color_frames * 2);

    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = &blocks[index];
        if (!block.active) continue;

        if (!colorIsActive(block.color)) {
            block.suppressed = false;
            continue;
        }

        const overlaps_player = playerOverlapsBlock(player.*, block.*);
        if (block.suppressed) {
            if (!overlaps_player) block.suppressed = false;
        } else if (overlaps_player) {
            block.suppressed = true;
        }
    }
}

pub fn floorAtPlayer(player: Player) bool {
    const player_x = fixedToPixel(player.x);
    const bottom = fixedToPixel(player.y) + player_mod.body_height;
    return floorAt(player_x + 1, bottom) or
        floorAt(player_x + player_mod.body_width / 2, bottom) or
        floorAt(player_x + player_mod.body_width - 2, bottom);
}

pub fn floorAt(x: i16, bottom_y: i16) bool {
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!solid(block)) continue;
        if (x >= block.x and x < block.x + @as(i16, @intCast(block.w)) and bottom_y >= block.y and bottom_y < block.y + 4) {
            return true;
        }
    }
    return false;
}

pub fn solidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    const right = x + width;
    const bottom = y + height;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!solid(block)) continue;
        if (right > block.x and x < block.x + @as(i16, @intCast(block.w)) and bottom > block.y and y < block.y + @as(i16, @intCast(block.h))) {
            return true;
        }
    }
    return false;
}

pub fn draw(camera: Camera) void {
    if (block_count == 0 and last_drawn_objects == 0) return;

    const first_object = firstObject();
    const capacity = objectCapacity();
    var object_offset: usize = 0;

    var index: usize = 0;
    while (index < block_count and object_offset < capacity) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        drawBlock(block, camera, first_object, &object_offset, capacity);
    }

    const drawn_objects = object_offset;
    const hide_until = @min(last_drawn_objects, capacity);
    while (object_offset < hide_until) : (object_offset += 1) {
        hideObject(first_object + object_offset);
    }
    last_drawn_objects = drawn_objects;
}

pub fn hideObjects() void {
    const first_object = firstObject();
    const capacity = objectCapacity();
    var index: usize = 0;
    while (index < capacity) : (index += 1) {
        hideObject(first_object + index);
    }
    last_drawn_objects = 0;
}

pub fn usedObjectCount() usize {
    const capacity = objectCapacity();
    var count: usize = 0;
    var index: usize = 0;
    while (index < block_count) : (index += 1) {
        const block = blocks[index];
        if (!block.active) continue;
        count += objectCountFor(block);
        if (count >= capacity) return capacity;
    }
    return count;
}

fn firstObject() usize {
    return dynamic_object_slots.first_object + falling_blocks.usedObjectCount() + mech_blocks.usedObjectCount();
}

fn objectCapacity() usize {
    const used = falling_blocks.usedObjectCount() + mech_blocks.usedObjectCount();
    if (used >= dynamic_object_slots.object_capacity) return 0;
    return dynamic_object_slots.object_capacity - used;
}

fn solid(block: Block) bool {
    return block.active and colorIsActive(block.color) and !block.suppressed;
}

fn visualActive(block: Block) bool {
    return solid(block);
}

fn colorIsActive(color: Color) bool {
    const phase = @divTrunc(timer, color_frames) & 1;
    return switch (color) {
        .blue => phase == 0,
        .pink => phase == 1,
    };
}

fn playerOverlapsBlock(player: Player, block: Block) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    return collision.rectsOverlap(
        player_left,
        player_top,
        player_left + player_mod.body_width,
        player_top + player_mod.body_height,
        block.x,
        block.y,
        block.x + @as(i16, @intCast(block.w)),
        block.y + @as(i16, @intCast(block.h)),
    );
}

fn objectCountFor(block: Block) usize {
    var count: usize = 0;
    var y: usize = 0;
    while (y < block.h) {
        const chunk_h: usize = if (@as(usize, block.h) - y >= 16) 16 else 8;
        var x: usize = 0;
        while (x < block.w) {
            const chunk_w: usize = if (@as(usize, block.w) - x >= 16) 16 else 8;
            count += 1;
            x += chunk_w;
        }
        y += chunk_h;
    }
    return count;
}

fn drawBlock(block: Block, camera: Camera, first_object: usize, object_offset: *usize, capacity: usize) void {
    var y: usize = 0;
    while (y < block.h and object_offset.* < capacity) {
        const chunk_h: usize = if (@as(usize, block.h) - y >= 16) 16 else 8;
        var x: usize = 0;
        while (x < block.w and object_offset.* < capacity) {
            const chunk_w: usize = if (@as(usize, block.w) - x >= 16) 16 else 8;
            drawObject(
                first_object + object_offset.*,
                block.x + @as(i16, @intCast(x)) - camera.x,
                block.y + @as(i16, @intCast(y)) - camera.y,
                variantTile(block.color, visualActive(block)),
                objectSize(chunk_w, chunk_h),
            );
            object_offset.* += 1;
            x += chunk_w;
        }
        y += chunk_h;
    }
}

fn objectSize(width: usize, height: usize) gba.display.Object.Size {
    if (width == 16 and height == 16) return .size_16x16;
    if (width == 16) return .size_16x8;
    if (height == 16) return .size_8x16;
    return .size_8x8;
}

fn variantTile(color: Color, active: bool) u10 {
    const color_offset: u10 = switch (color) {
        .blue => 0,
        .pink => 2,
    };
    const active_offset: u10 = if (active) 0 else 1;
    return base_tile + (color_offset + active_offset) * tiles_per_variant;
}

fn drawObject(object_index: usize, x: i16, y: i16, tile: u10, size: gba.display.Object.Size) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = size,
        .x = objX(x),
        .y = objY(y),
        .base_tile = tile,
        .priority = 1,
        .palette = palette_bank,
    });
}

fn loadPalette() void {
    const base = @as(usize, palette_bank) * 16;
    gba.display.obj_palette.colors[base + 0] = .black;
    gba.display.obj_palette.colors[base + 1] = gba.ColorRgb555.rgb(2, 6, 14);
    gba.display.obj_palette.colors[base + 2] = gba.ColorRgb555.rgb(4, 14, 29);
    gba.display.obj_palette.colors[base + 3] = gba.ColorRgb555.rgb(6, 20, 31);
    gba.display.obj_palette.colors[base + 4] = gba.ColorRgb555.rgb(16, 27, 31);
    gba.display.obj_palette.colors[base + 5] = gba.ColorRgb555.rgb(1, 5, 10);
    gba.display.obj_palette.colors[base + 6] = gba.ColorRgb555.rgb(6, 10, 18);
    gba.display.obj_palette.colors[base + 7] = gba.ColorRgb555.rgb(11, 17, 25);
    gba.display.obj_palette.colors[base + 8] = gba.ColorRgb555.rgb(13, 4, 11);
    gba.display.obj_palette.colors[base + 9] = gba.ColorRgb555.rgb(24, 7, 20);
    gba.display.obj_palette.colors[base + 10] = gba.ColorRgb555.rgb(31, 10, 25);
    gba.display.obj_palette.colors[base + 11] = gba.ColorRgb555.rgb(31, 18, 29);
    gba.display.obj_palette.colors[base + 12] = gba.ColorRgb555.rgb(10, 2, 8);
    gba.display.obj_palette.colors[base + 13] = gba.ColorRgb555.rgb(16, 8, 16);
    gba.display.obj_palette.colors[base + 14] = gba.ColorRgb555.rgb(23, 13, 23);
    gba.display.obj_palette.colors[base + 15] = .white;
}

fn buildTiles() void {
    tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** tile_count;
    buildVariant(0, .blue, true);
    buildVariant(tiles_per_variant, .blue, false);
    buildVariant(tiles_per_variant * 2, .pink, true);
    buildVariant(tiles_per_variant * 3, .pink, false);
}

fn buildVariant(start_tile: u10, color: Color, active: bool) void {
    var copy: u10 = 0;
    while (copy < tiles_per_variant) : (copy += 1) {
        drawTile(start_tile + copy, color, active);
    }
}

fn drawTile(tile_index: u10, color: Color, active: bool) void {
    const colors = tileColors(color, active);
    var y: i16 = 0;
    while (y < 8) : (y += 1) {
        var x: i16 = 0;
        while (x < 8) : (x += 1) {
            const border = x == 0 or y == 0 or x == 7 or y == 7;
            var index = if (border) colors.edge else colors.fill;
            if (!border and active and ((x + y) & 7) == 0) index = colors.light;
            if (!border and !active and inactivePattern(color, x, y)) index = colors.line;
            setTilePixel(tile_index, x, y, index);
        }
    }
}

const TileColors = struct {
    edge: u8,
    fill: u8,
    light: u8,
    line: u8,
};

fn tileColors(color: Color, active: bool) TileColors {
    return switch (color) {
        .blue => if (active)
            .{ .edge = 2, .fill = 3, .light = 4, .line = 4 }
        else
            .{ .edge = 5, .fill = 6, .light = 7, .line = 7 },
        .pink => if (active)
            .{ .edge = 9, .fill = 10, .light = 11, .line = 11 }
        else
            .{ .edge = 12, .fill = 13, .light = 14, .line = 14 },
    };
}

fn inactivePattern(color: Color, x: i16, y: i16) bool {
    return switch (color) {
        .blue => (x & 3) == 1,
        .pink => ((x + y) & 3) == 0,
    };
}

fn setTilePixel(tile_index: u10, x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const byte_index = uy * 4 + ux / 2;
    const index: usize = @intCast(tile_index);
    if ((ux & 1) == 0) {
        tiles[index].data_8[byte_index] = (tiles[index].data_8[byte_index] & 0xF0) | color;
    } else {
        tiles[index].data_8[byte_index] = (tiles[index].data_8[byte_index] & 0x0F) | (color << 4);
    }
}
