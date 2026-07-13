const gba = @import("gba");
const assets = @import("../../core/assets.zig");
const bird_npc = @import("bird_npc.zig");
const camera_mod = @import("../../world/camera.zig");
const foreground_stamps = @import("../../room/foreground_stamps.zig");
const oam = @import("../../core/oam.zig");
const room_data = @import("../../world/room_data.zig");

const Camera = camera_mod.Camera;
const Spawn = room_data.Spawn;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;

const idle_tiles_data align(4) = assets.granny_idle_tiles_data;
const laugh_tiles_data align(4) = assets.granny_laugh_tiles_data;
const quotes_tiles_data align(4) = assets.granny_quotes_tiles_data;
const palette_data align(4) = assets.granny_palette_data;

pub const Animation = enum(u8) {
    none,
    idle,
    laugh,
    quotes,
};

pub const base_tile: u10 = foreground_stamps.base_tile;
pub const palette_bank: u4 = bird_npc.palette_bank;

const tiles_per_frame = 16;
const tile_range = gba.display.ObjectTileRange.init("granny npc", foreground_stamps.base_tile, tiles_per_frame);
const idle_frame_count: u16 = @intCast(idle_tiles_data.len / (tiles_per_frame * 32));
const laugh_frame_count: u16 = @intCast(laugh_tiles_data.len / (tiles_per_frame * 32));
const quotes_frame_count: u16 = @intCast(quotes_tiles_data.len / (tiles_per_frame * 32));
const anim_speed = 10;
const origin_offset_x: i16 = 16;
const origin_offset_y: i16 = 32;

var frame_cache: gba.display.ObjectTileVariantFrameCache4Bpp = .{};
var visible: bool = false;

pub fn loadPalette() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
}

pub fn invalidate() void {
    frame_cache.invalidate();
}

pub fn draw(camera: Camera, object: usize, position: Spawn, animation: Animation, anim_counter: u16, facing_left: bool) void {
    const frame_count = frameCount(animation);
    const frame: u16 = @intCast((anim_counter / anim_speed) % frame_count);
    loadFrame(animation, frame);
    gba.display.objects[object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(position.x - origin_offset_x - camera.x),
        .y = objY(position.y - origin_offset_y - camera.y),
        .base_tile = base_tile,
        .priority = 1,
        .palette = palette_bank,
        .flip = gba.math.Vec2B.init(facing_left, false),
    });
    visible = true;
}

pub fn hide(object: usize) void {
    if (!visible) return;
    hideObject(object);
    visible = false;
}

fn frameCount(animation: Animation) u16 {
    return switch (animation) {
        .laugh => laugh_frame_count,
        .quotes => quotes_frame_count,
        else => idle_frame_count,
    };
}

fn loadFrame(animation: Animation, frame: u16) void {
    const frame_count = frameCount(animation);
    const safe_frame = @min(frame, frame_count - 1);
    const tile_data = switch (animation) {
        .laugh => &laugh_tiles_data,
        .quotes => &quotes_tiles_data,
        else => &idle_tiles_data,
    };
    frame_cache.upload4Bpp(tile_range, @intFromEnum(animation), tile_data, safe_frame, tiles_per_frame);
}
