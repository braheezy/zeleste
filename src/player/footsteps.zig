const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");
const sound_ids = assets.sound_ids;
const background = @import("../world/background.zig");
const chapter_systems = @import("../chapters/systems.zig");
const collision = @import("../world/collision.zig");
const disappearing_platforms = @import("../room/disappearing_platforms.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const mech_blocks = @import("../room/mech_blocks.zig");
const player_mod = @import("state.zig");
const rhythm_blocks = @import("../room/rhythm_blocks.zig");
const room_data = @import("../world/room_data.zig");

const Player = player_mod.State;
const RoomBackground = room_data.RoomBackground;

const fixedToPixel = math.fixedToPixel;
const absI32 = math.absI32;
const absI16 = math.absI16;
const readU16Le = room_data.readU16Le;

const rooms = level.rooms;
const player_body_width = player_mod.body_width;
const player_body_height = player_mod.body_height;
const min_speed = player_mod.footstep_min_speed;
const volume = player_mod.footstep_volume;
const cadence_frames = player_mod.footstep_cadence_frames;

pub const Surface = enum(u8) {
    snow,
    dirt,
    wood,
    car,
    asphalt,
};

const Color = struct {
    r: u5,
    g: u5,
    b: u5,
};

const asphalt_sfx = [_]u16{
    sound_ids.sfx_foot_00_asphalt_01,
    sound_ids.sfx_foot_00_asphalt_02,
    sound_ids.sfx_foot_00_asphalt_03,
    sound_ids.sfx_foot_00_asphalt_04,
    sound_ids.sfx_foot_00_asphalt_05,
    sound_ids.sfx_foot_00_asphalt_06,
    sound_ids.sfx_foot_00_asphalt_07,
};
const car_sfx = [_]u16{
    sound_ids.sfx_foot_00_car_01,
    sound_ids.sfx_foot_00_car_02,
    sound_ids.sfx_foot_00_car_03,
    sound_ids.sfx_foot_00_car_04,
    sound_ids.sfx_foot_00_car_05,
    sound_ids.sfx_foot_00_car_06,
};
const dirt_sfx = [_]u16{
    sound_ids.sfx_foot_00_dirt_01,
    sound_ids.sfx_foot_00_dirt_02,
    sound_ids.sfx_foot_00_dirt_03,
    sound_ids.sfx_foot_00_dirt_04,
    sound_ids.sfx_foot_00_dirt_05,
    sound_ids.sfx_foot_00_dirt_06,
    sound_ids.sfx_foot_00_dirt_07,
};
const snow_sfx = [_]u16{
    sound_ids.sfx_foot_00_snowsoft_01,
    sound_ids.sfx_foot_00_snowsoft_02,
    sound_ids.sfx_foot_00_snowsoft_03,
    sound_ids.sfx_foot_00_snowsoft_04,
    sound_ids.sfx_foot_00_snowsoft_05,
    sound_ids.sfx_foot_00_snowsoft_06,
    sound_ids.sfx_foot_00_snowsoft_07,
};
const wood_sfx = [_]u16{
    sound_ids.sfx_foot_00_woodwalkway_01,
    sound_ids.sfx_foot_00_woodwalkway_02,
    sound_ids.sfx_foot_00_woodwalkway_03,
    sound_ids.sfx_foot_00_woodwalkway_04,
    sound_ids.sfx_foot_00_woodwalkway_05,
    sound_ids.sfx_foot_00_woodwalkway_06,
    sound_ids.sfx_foot_00_woodwalkway_07,
};

pub fn update(player: *Player, room_index: usize, previous_x: i32) void {
    if (!player.grounded or player.animation != .run or absI32(player.vx) < min_speed) {
        player.footstep_cooldown = 0;
        return;
    }

    if (player.footstep_cooldown != 0) {
        player.footstep_cooldown -= 1;
        return;
    }

    if (fixedToPixel(player.x) == fixedToPixel(previous_x)) return;

    play(surfaceAtPlayerFeet(player.*, room_index), player);
    player.footstep_cooldown = cadence_frames;
}

fn play(surface: Surface, player: *Player) void {
    const samples = samplesFor(surface);
    const index: usize = @intCast(player.footstep_variant % @as(u8, @intCast(samples.len)));
    player.footstep_variant +%= 1;
    if (player.footstep_handle != 0) {
        _ = audio.cancelSoundEffect(player.footstep_handle);
    }
    player.footstep_handle = audio.playSoundEffect(samples[index]);
    if (player.footstep_handle != 0) {
        audio.setSoundEffectVolume(player.footstep_handle, volume);
    }
}

fn samplesFor(surface: Surface) []const u16 {
    return switch (surface) {
        .snow => &snow_sfx,
        .dirt => &dirt_sfx,
        .wood => &wood_sfx,
        .car => &car_sfx,
        .asphalt => &asphalt_sfx,
    };
}

pub fn surfaceAtPlayerFeet(player: Player, room_index: usize) Surface {
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const bottom = player_y + player_body_height;

    if (chapter_systems.actorFloorAt(room_index, player_x, player_y)) return .car;
    if (chapter_systems.asphaltFloorAtPlayer(room_index, player)) return .asphalt;
    if (chapter_systems.snowFloorAtPlayer(room_index, player)) return .snow;
    if (mech_blocks.floorAtPlayer(player)) return .asphalt;
    if (rhythm_blocks.floorAtPlayer(player)) return .asphalt;
    if (disappearing_platforms.floorAtPlayer(player)) return .dirt;
    if (oneWayFloorAt(player_x, player_y, room_index)) return .wood;

    return backgroundSurfaceAt(room_index, player_x, bottom);
}

pub fn surfaceAtPlayerWall(player: Player, room_index: usize) Surface {
    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const side_x = if (player.facing_left) player_x - 1 else player_x + player_body_width;

    var snow_score: u8 = 0;
    var dirt_score: u8 = 0;
    var asphalt_score: u8 = 0;
    const offsets = [_]i16{ 3, 7, player_body_height - 4 };
    for (offsets) |offset| {
        if (backgroundPixelSurface(room_index, side_x, player_y + offset)) |surface| {
            switch (surface) {
                .snow => snow_score += 1,
                .dirt => dirt_score += 1,
                .asphalt => asphalt_score += 1,
                else => {},
            }
        }
    }

    if (snow_score != 0) return .snow;
    if (asphalt_score > dirt_score) return .asphalt;
    return .dirt;
}

fn oneWayFloorAt(x: i16, player_y: i16, room_index: usize) bool {
    const player_bottom = player_y + player_body_height;
    return collision.oneWayPlatformAtBottom(rooms[room_index], x, player_bottom) or
        collision.oneWayPlatformAtBottom(rooms[room_index], x + player_body_width - 1, player_bottom);
}

fn backgroundSurfaceAt(room_index: usize, player_x: i16, bottom: i16) Surface {
    var snow_score: u8 = 0;
    var dirt_score: u8 = 0;
    var asphalt_score: u8 = 0;
    const foot_x = [_]i16{ 1, player_body_width / 2, player_body_width - 2 };
    var xi: usize = 0;
    while (xi < foot_x.len) : (xi += 1) {
        var dy: i16 = 0;
        while (dy < 4) : (dy += 1) {
            if (backgroundPixelSurface(room_index, player_x + foot_x[xi], bottom + dy)) |surface| {
                switch (surface) {
                    .snow => snow_score += 1,
                    .dirt => dirt_score += 1,
                    .asphalt => asphalt_score += 1,
                    else => {},
                }
            }
        }
    }

    if (snow_score != 0) return .snow;
    if (asphalt_score > dirt_score) return .asphalt;
    return .dirt;
}

fn backgroundPixelSurface(room_index: usize, x: i16, y: i16) ?Surface {
    const color = backgroundPixelColorAt(rooms[room_index], x, y) orelse return null;
    return classifyColor(color);
}

fn backgroundPixelColorAt(room: RoomBackground, x: i16, y: i16) ?Color {
    if (x < 0 or y < 0 or x >= room.width_pixels or y >= room.height_pixels) return null;

    const tile_x = @divTrunc(x, 8);
    const tile_y = @divTrunc(y, 8);
    const entry = background.logicalRoomMapEntry(room, tile_x, tile_y);
    const tile_id = entry & 0x03ff;
    const hflip = (entry & 0x0400) != 0;
    const vflip = (entry & 0x0800) != 0;

    var source_x: usize = @intCast(x - tile_x * 8);
    var source_y: usize = @intCast(y - tile_y * 8);
    if (hflip) source_x = 7 - source_x;
    if (vflip) source_y = 7 - source_y;

    const tile_offset = @as(usize, tile_id) * 64 + source_y * 8 + source_x;
    if (tile_offset >= room.tiles.len) return null;

    const color_index = room.tiles[tile_offset];
    if (color_index == 0) return null;
    const palette_offset = @as(usize, color_index) * 2;
    if (palette_offset + 1 >= room.palette.len) return null;

    const color = readU16Le(room.palette, palette_offset);
    return .{
        .r = @intCast(color & 0x1f),
        .g = @intCast((color >> 5) & 0x1f),
        .b = @intCast((color >> 10) & 0x1f),
    };
}

fn classifyColor(color: Color) ?Surface {
    if ((color.r >= 24 and color.g >= 24 and color.b >= 24) or
        (color.b >= 22 and color.g >= 18 and color.r >= 14))
    {
        return .snow;
    }

    const rg_delta = absI16(@as(i16, color.r) - @as(i16, color.g));
    const gb_delta = absI16(@as(i16, color.g) - @as(i16, color.b));
    if (rg_delta <= 3 and gb_delta <= 3 and color.r >= 7 and color.r <= 24) {
        return .asphalt;
    }

    if (color.r >= 10 and color.g >= 5 and @as(u8, color.r) > @as(u8, color.b) + 4 and color.g >= color.b) {
        return .dirt;
    }

    return null;
}
