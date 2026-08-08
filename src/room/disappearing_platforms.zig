const gba = @import("gba");

const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const collision = @import("../world/collision.zig");
const dynamic_object_slots = @import("dynamic_object_slots.zig");
const falling_blocks = @import("falling_blocks.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mech_blocks = @import("mech_blocks.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const rhythm_blocks = @import("rhythm_blocks.zig");
const room_data = @import("../world/room_data.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;

const tiles_data align(4) = assets.disappearing_platform_tiles_data;
const palette_data align(4) = assets.disappearing_platform_palette_data;
const rooms = level.rooms;

pub const max_platforms = 16;

const record_bytes = 8;
const tile_size: i16 = 8;
const tile_size_usize: usize = 8;
const shake_frames: u8 = 20;
const fall_frames: u8 = 24;
const fall_gravity: i16 = 5;
const fall_max_speed: i16 = 64;
const respawn_frames: u8 = 120;
const base_tile: u10 = 552;
const variant_count: u10 = 4;
const outline_base_tile: u10 = base_tile + variant_count;
const outline_tile_count = 16;
const outline_color: u4 = 15;
const palette_bank: u4 = 10;

const State = enum(u8) {
    active,
    shaking,
    falling,
    hidden,
};

const Platform = struct {
    active: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    w: u8 = 0,
    h: u8 = 0,
    state: State = .active,
    timer: u8 = 0,
    fall_y: i16 = 0,
    fall_vy: i16 = 0,
    standing_last_frame: bool = false,
    triggered_by_hold: bool = false,
};

const Contact = struct {
    standing: bool = false,
    holding: bool = false,
};

var platforms: [max_platforms]Platform = [_]Platform{.{}} ** max_platforms;
var platform_count: usize = 0;
var outline_tiles: [outline_tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** outline_tile_count;
var last_drawn_objects: usize = 0;

pub fn load(room_index: usize) void {
    platforms = [_]Platform{.{}} ** max_platforms;
    platform_count = 0;
    hideObjects();

    const data = rooms[room_index].disappearing_platforms;
    if (data.len < 2) return;

    const count = @min(readU16Le(data, 0), max_platforms);
    var source_offset: usize = 2;
    var source_index: usize = 0;
    while (source_index < count and source_offset + record_bytes <= data.len) : ({
        source_index += 1;
        source_offset += record_bytes;
    }) {
        const w = data[source_offset + 4];
        const h = data[source_offset + 5];
        if (w == 0 or h == 0) continue;
        platforms[platform_count] = .{
            .active = true,
            .x = readI16Le(data, source_offset),
            .y = readI16Le(data, source_offset + 2),
            .w = w,
            .h = h,
        };
        platform_count += 1;
    }
}

pub fn loadGraphics() void {
    if (platform_count == 0) return;
    gba.display.memcpyObjectPaletteBank(palette_bank, 0, @ptrCast(&palette_data));
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
    loadOutlineTiles();
}

pub fn update(player: Player) void {
    var index: usize = 0;
    while (index < platform_count) : (index += 1) {
        const platform = &platforms[index];
        if (!platform.active) continue;

        switch (platform.state) {
            .active => {
                const contact = playerContact(player, platform.*);
                if (contact.standing or contact.holding) {
                    platform.state = .shaking;
                    platform.timer = shake_frames;
                    platform.triggered_by_hold = contact.holding and !contact.standing;
                }
                platform.standing_last_frame = contact.standing;
            },
            .shaking => {
                const contact = playerContact(player, platform.*);
                if (!platform.triggered_by_hold and platform.standing_last_frame and !contact.standing and player.vy < 0) {
                    startFalling(platform);
                    continue;
                }
                if (platform.timer > 0) {
                    platform.timer -= 1;
                } else {
                    startFalling(platform);
                    continue;
                }
                platform.standing_last_frame = contact.standing;
            },
            .falling => {
                if (platform.timer > 0) {
                    platform.timer -= 1;
                    platform.fall_vy = @min(platform.fall_vy + fall_gravity, fall_max_speed);
                    platform.fall_y += platform.fall_vy;
                } else {
                    hidePlatform(platform);
                }
            },
            .hidden => {
                platform.standing_last_frame = false;
                if (platform.timer > 0) {
                    platform.timer -= 1;
                } else if (!playerOverlapsPlatform(player, platform.*)) {
                    platform.state = .active;
                    platform.fall_y = 0;
                    platform.fall_vy = 0;
                    platform.triggered_by_hold = false;
                }
            },
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
    while (index < platform_count) : (index += 1) {
        const platform = platforms[index];
        if (!solid(platform)) continue;
        if (x >= platform.x and x < platform.x + @as(i16, @intCast(platform.w)) and bottom_y >= platform.y and bottom_y < platform.y + 4) {
            return true;
        }
    }
    return false;
}

pub fn solidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    const right = x + width;
    const bottom = y + height;
    var index: usize = 0;
    while (index < platform_count) : (index += 1) {
        const platform = platforms[index];
        if (!solid(platform)) continue;
        if (right > platform.x and x < platform.x + @as(i16, @intCast(platform.w)) and bottom > platform.y and y < platform.y + @as(i16, @intCast(platform.h))) {
            return true;
        }
    }
    return false;
}

pub fn draw(camera: Camera) void {
    if (platform_count == 0 and last_drawn_objects == 0) return;

    const first_object = firstObject();
    const capacity = objectCapacity();
    var object_offset: usize = 0;

    var index: usize = 0;
    while (index < platform_count and object_offset < capacity) : (index += 1) {
        const platform = platforms[index];
        if (!platform.active) continue;
        switch (platform.state) {
            .active, .shaking, .falling => drawActive(platform, camera, first_object, &object_offset, capacity),
            .hidden => drawOutline(platform, camera, first_object, &object_offset, capacity),
        }
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
    while (index < platform_count) : (index += 1) {
        const platform = platforms[index];
        if (!platform.active) continue;
        count += objectCountFor(platform);
        if (count >= capacity) return capacity;
    }
    return count;
}

fn firstObject() usize {
    return dynamic_object_slots.first_object + falling_blocks.usedObjectCount() + mech_blocks.usedObjectCount() + rhythm_blocks.usedObjectCount();
}

fn objectCapacity() usize {
    const used = falling_blocks.usedObjectCount() + mech_blocks.usedObjectCount() + rhythm_blocks.usedObjectCount();
    if (used >= dynamic_object_slots.object_capacity) return 0;
    return dynamic_object_slots.object_capacity - used;
}

fn hidePlatform(platform: *Platform) void {
    platform.state = .hidden;
    platform.timer = respawn_frames;
    platform.fall_y = 0;
    platform.fall_vy = 0;
    platform.standing_last_frame = false;
}

fn startFalling(platform: *Platform) void {
    platform.state = .falling;
    platform.timer = fall_frames;
    platform.fall_y = 0;
    platform.fall_vy = 0;
    platform.standing_last_frame = false;
}

fn solid(platform: Platform) bool {
    return platform.active and (platform.state == .active or platform.state == .shaking);
}

fn playerContact(player: Player, platform: Platform) Contact {
    return .{
        .standing = playerStandingOnPlatform(player, platform),
        .holding = playerHoldingPlatform(player, platform),
    };
}

fn playerStandingOnPlatform(player: Player, platform: Platform) bool {
    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width - 1;
    const player_bottom = fixedToPixel(player.y) + player_mod.body_height;
    return player_right >= platform.x and
        player_left < platform.x + @as(i16, @intCast(platform.w)) and
        player_bottom >= platform.y - 1 and
        player_bottom <= platform.y + 2;
}

fn playerHoldingPlatform(player: Player, platform: Platform) bool {
    if (!player.climbing and !player.climb_dangling) return false;

    const player_left = fixedToPixel(player.x);
    const player_right = player_left + player_mod.body_width;
    const player_top = fixedToPixel(player.y);
    const player_bottom = player_top + player_mod.body_height;
    const platform_right = platform.x + @as(i16, @intCast(platform.w));
    const platform_bottom = platform.y + @as(i16, @intCast(platform.h));
    const vertical_overlap = player_bottom > platform.y + 1 and player_top < platform_bottom - 1;
    const left_contact = player_right >= platform.x - 1 and player_right <= platform.x + 2;
    const right_contact = player_left <= platform_right + 1 and player_left >= platform_right - 2;
    return vertical_overlap and (left_contact or right_contact);
}

fn playerOverlapsPlatform(player: Player, platform: Platform) bool {
    return collision.rectsOverlap(
        fixedToPixel(player.x),
        fixedToPixel(player.y),
        fixedToPixel(player.x) + player_mod.body_width,
        fixedToPixel(player.y) + player_mod.body_height,
        platform.x,
        platform.y,
        platform.x + @as(i16, @intCast(platform.w)),
        platform.y + @as(i16, @intCast(platform.h)),
    );
}

fn objectCountFor(platform: Platform) usize {
    const columns: usize = @intCast(platform.w / 8);
    const rows: usize = @intCast(platform.h / 8);
    if (columns == 0 or rows == 0) return 0;
    return switch (platform.state) {
        .active, .shaking, .falling => columns * rows,
        .hidden => outlineObjectCount(columns, rows),
    };
}

fn outlineObjectCount(columns: usize, rows: usize) usize {
    if (columns == 1) return rows;
    if (rows == 1) return columns;
    return columns * 2 + (rows - 2) * 2;
}

fn drawActive(platform: Platform, camera: Camera, first_object: usize, object_offset: *usize, capacity: usize) void {
    const shake_x: i16 = if (platform.state == .shaking and (platform.timer & 3) == 0) if ((platform.timer & 4) == 0) -1 else 1 else 0;
    const shake_y: i16 = if (platform.state == .shaking and (platform.timer & 7) == 0) 1 else 0;
    const fall_y = if (platform.state == .falling) @divTrunc(platform.fall_y, 16) else 0;
    const columns: usize = @intCast(platform.w / 8);
    const rows: usize = @intCast(platform.h / 8);

    var row: usize = 0;
    while (row < rows and object_offset.* < capacity) : (row += 1) {
        var col: usize = 0;
        while (col < columns and object_offset.* < capacity) : (col += 1) {
            const x = platform.x + @as(i16, @intCast(col * tile_size_usize)) + shake_x;
            const y = platform.y + @as(i16, @intCast(row * tile_size_usize)) + shake_y + fall_y;
            drawTile(first_object + object_offset.*, x - camera.x, y - camera.y, base_tile + variantFor(platform, col, row));
            object_offset.* += 1;
        }
    }
}

fn drawOutline(platform: Platform, camera: Camera, first_object: usize, object_offset: *usize, capacity: usize) void {
    const columns: usize = @intCast(platform.w / 8);
    const rows: usize = @intCast(platform.h / 8);
    if (columns == 0 or rows == 0) return;

    var row: usize = 0;
    while (row < rows and object_offset.* < capacity) : (row += 1) {
        var col: usize = 0;
        while (col < columns and object_offset.* < capacity) : (col += 1) {
            var mask: u4 = 0;
            if (row == 0) mask |= 1;
            if (row + 1 == rows) mask |= 2;
            if (col == 0) mask |= 4;
            if (col + 1 == columns) mask |= 8;
            if (mask == 0) continue;
            const x = platform.x + @as(i16, @intCast(col * tile_size_usize));
            const y = platform.y + @as(i16, @intCast(row * tile_size_usize));
            drawTile(first_object + object_offset.*, x - camera.x, y - camera.y, outline_base_tile + @as(u10, mask));
            object_offset.* += 1;
        }
    }
}

fn drawTile(object_index: usize, x: i16, y: i16, tile: u10) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(x),
        .y = objY(y),
        .base_tile = tile,
        .priority = 1,
        .palette = palette_bank,
    });
}

fn variantFor(platform: Platform, col: usize, row: usize) u10 {
    const x: u16 = @bitCast(platform.x);
    const y: u16 = @bitCast(platform.y);
    const hash = x *% 17 +% y *% 31 +% @as(u16, @intCast(col * 7 + row * 13));
    return @intCast(hash % @as(u16, variant_count));
}

fn loadOutlineTiles() void {
    outline_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** outline_tile_count;
    var mask: usize = 0;
    while (mask < outline_tile_count) : (mask += 1) {
        drawOutlineTile(@intCast(mask));
    }
    gba.display.memcpyObjectTiles4Bpp(outline_base_tile, &outline_tiles);
}

fn drawOutlineTile(mask: u4) void {
    var p: i16 = 0;
    while (p < tile_size) : (p += 1) {
        if ((p & 1) == 0) {
            if ((mask & 1) != 0) setOutlinePixel(mask, p, 0);
            if ((mask & 2) != 0) setOutlinePixel(mask, p, tile_size - 1);
            if ((mask & 4) != 0) setOutlinePixel(mask, 0, p);
            if ((mask & 8) != 0) setOutlinePixel(mask, tile_size - 1, p);
        }
    }
}

fn setOutlinePixel(tile_index: usize, x: i16, y: i16) void {
    if (x < 0 or x >= tile_size or y < 0 or y >= tile_size) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const byte_index = uy * 4 + ux / 2;
    if ((ux & 1) == 0) {
        outline_tiles[tile_index].data_8[byte_index] = (outline_tiles[tile_index].data_8[byte_index] & 0xf0) | outline_color;
    } else {
        outline_tiles[tile_index].data_8[byte_index] = (outline_tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, outline_color) << 4);
    }
}
