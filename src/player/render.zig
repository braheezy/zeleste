const gba = @import("gba");
const assets = @import("../core/assets.zig");
const camera_mod = @import("../world/camera.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("state.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const fixedToPixel = math.fixedToPixel;
const absI32 = math.absI32;
const objX = oam.objX;
const objY = oam.objY;
const hideObject = oam.hideObject;

const player_tiles_data align(4) = assets.player_tiles_data;
const player_palette_data align(4) = assets.player_palette_data;
const sweat_tiles_data align(4) = assets.player_sweat_tiles_data;
const sweat_palette_data align(4) = assets.player_sweat_palette_data;

pub const object = 32;
pub const sweat_tiles_per_frame = 16;
const player_tile_range = obj_vram.player_body;
const sweat_tile_range = obj_vram.player_sweat;
const player_base_tile = player_tile_range.baseTile();
pub const sweat_base_tile = sweat_tile_range.baseTile();
pub const sweat_palette_bank: u4 = 4;
pub const sweat_object = 71;

const sweat_still_first_frame = 0;
const sweat_still_frame_count = 6;
const sweat_climb_first_frame = 6;
const sweat_climb_frame_count = 6;

var frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var sweat_frame_cache: gba.display.ObjectTileFrameCache4Bpp = .{};
var loaded_palette_mode: PaletteMode = .invalid;

const PaletteMode = enum {
    invalid,
    normal,
    fatigue,
};

pub fn invalidate() void {
    frame_cache.invalidate();
    sweat_frame_cache.invalidate();
    loaded_palette_mode = .invalid;
}

pub fn loadPalettes() void {
    gba.mem.memcpy(gba.display.obj_palette, &player_palette_data, player_palette_data.len);
    const sweat_palette: *align(2) const gba.display.Palette.Bank = @ptrCast(&sweat_palette_data);
    gba.display.memcpyObjectPaletteBank(sweat_palette_bank, 0, sweat_palette);
    loaded_palette_mode = .normal;
}

pub fn loadNormalPalette() void {
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&player_palette_data);
    gba.display.memcpyObjectPaletteBank(0, 0, base_palette[0..16]);
    loaded_palette_mode = .normal;
}

pub fn hideObjects() void {
    hideObject(object);
    hideObject(sweat_object);
}

pub fn loadFrame(frame: u16) void {
    frame_cache.upload4Bpp(player_tile_range, &player_tiles_data, frame, player_mod.tiles_per_frame);
}

pub fn draw(player: Player, camera: Camera, foreground_anim_counter: u16) void {
    updatePalette(player, foreground_anim_counter);
    loadFrame(player.frame);
    const draw_x = fixedToPixel(player.x) - camera.x + player_mod.draw_offset_x;
    const draw_y = fixedToPixel(player.y) - camera.y + player_mod.draw_offset_y;
    gba.display.objects[object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = player_base_tile,
        .priority = 1,
        .palette = 0,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

pub fn drawSweat(player: *Player, camera: Camera) void {
    if (!player.climbing or player.climb_ledge_timer > 0) {
        hideObject(sweat_object);
        return;
    }

    player.sweat_timer +%= 1;
    const moving = absI32(player.vy) > 0x20;
    const first_frame: u16 = if (moving) sweat_climb_first_frame else sweat_still_first_frame;
    const frame_count: u16 = if (moving) sweat_climb_frame_count else sweat_still_frame_count;
    player.sweat_frame = first_frame + (player.sweat_timer / player_mod.animation_speed) % frame_count;
    loadSweatFrame(player.sweat_frame);

    const draw_x = fixedToPixel(player.x) - camera.x + player_mod.draw_offset_x;
    const draw_y = fixedToPixel(player.y) - camera.y + player_mod.draw_offset_y;
    gba.display.objects[sweat_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = sweat_base_tile,
        .priority = 1,
        .palette = sweat_palette_bank,
        .flip = gba.math.Vec2B.init(player.facing_left, false),
    });
}

fn loadSweatFrame(frame: u16) void {
    sweat_frame_cache.upload4Bpp(sweat_tile_range, &sweat_tiles_data, frame, sweat_tiles_per_frame);
}

fn updatePalette(player: Player, foreground_anim_counter: u16) void {
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&player_palette_data);
    const desired_mode: PaletteMode = if (fatigueFlashVisible(player, foreground_anim_counter)) .fatigue else .normal;
    if (loaded_palette_mode == desired_mode) return;

    if (desired_mode == .normal) {
        gba.display.memcpyObjectPaletteBank(0, 0, base_palette[0..16]);
        loaded_palette_mode = .normal;
        return;
    }

    const player_palette = gba.display.objectPaletteBank(0);
    player_palette[0] = base_palette[0];
    var index: usize = 0;
    while (index < 16) : (index += 1) {
        player_palette[index] = redFatigueTint(base_palette[index]);
    }
    loaded_palette_mode = .fatigue;
}

fn fatigueFlashVisible(player: Player, foreground_anim_counter: u16) bool {
    if (player.stamina > player_mod.climb_tired_stamina) return false;
    const clamped_stamina: u16 = @intCast(@max(0, player.stamina));
    const period: u16 = 4 + @divTrunc(clamped_stamina * 12, player_mod.climb_tired_stamina);
    return (foreground_anim_counter % period) < period / 2;
}

fn redFatigueTint(color: gba.ColorRgb555) gba.ColorRgb555 {
    const r: u8 = @intCast(color.r);
    const g: u8 = @intCast(color.g);
    const b: u8 = @intCast(color.b);
    return gba.ColorRgb555.rgb(
        @intCast(@min(@as(u8, 31), r + 12)),
        @intCast(g / 2),
        @intCast(b / 2),
    );
}
