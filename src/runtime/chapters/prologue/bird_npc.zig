const gba = @import("gba");
const assets = @import("../../assets.zig");
const camera_mod = @import("../../camera.zig");
const collision = @import("../../collision.zig");
const level = @import("../../../generated_rooms.zig");
const math = @import("../../math.zig");
const oam = @import("../../oam.zig");
const player_mod = @import("../../player.zig");
const room_data = @import("../../room_data.zig");
const tiny_birds = @import("tiny_birds.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const approach = math.approach;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const sqrtU64 = math.sqrtU64;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const rectsOverlap = collision.rectsOverlap;

const intro_tiles_data align(4) = assets.bird_intro_tiles_data;
const palette_data align(4) = assets.bird_palette_data;
const hold_hint_tiles_data align(4) = assets.bird_hold_hint_tiles_data;
const climb_hint_tiles_data align(4) = assets.bird_climb_hint_tiles_data;
const dash_hint_tiles_data align(4) = assets.bird_dash_hint_tiles_data;
const hint_palette_data align(4) = assets.bird_hint_palette_data;

pub const object = tiny_birds.first_object;
pub const hint_object = object + 1;
pub const base_tile: u10 = tiny_birds.base_tile;
pub const palette_bank: u4 = tiny_birds.palette_bank;
pub const tiles_per_frame = 16;
pub const hint_base_tile: u10 = base_tile + tiles_per_frame;
pub const hint_palette_bank: u4 = 9;

const squawk_first_frame: u16 = 0;
const squawk_frame_count: u16 = 17;
const peck_first_frame: u16 = 17;
const peck_frame_count: u16 = 11;
const liftoff_first_frame: u16 = 28;
const liftoff_frame_count: u16 = 9;
const fly_first_frame: u16 = 49;
const fly_frame_count: u16 = 4;
const anim_speed = 4;
const total_frame_count: u16 = 53;
const fly_speed: i32 = 0x140;
const liftoff_vx: i32 = 0x90;
const liftoff_vy: i32 = -0xB0;
const flyaway_vx: i32 = 0x80;
const flyaway_vy: i32 = -0x170;
const flyaway_frames: u16 = 100;
const hint_show_delay_frames: u16 = 8 * anim_speed;
const hold_hint_frames: u16 = 60;
const hint_hide_frames: u16 = 18;
const peck_cycle_frames: u16 = 180;
const origin_offset_x: i16 = 5;
const origin_offset_y: i16 = 9;
const max_path_points = 32;
const max_triggers = 8;
const invalid_loaded_frame: u16 = 0xffff;
const rooms = level.rooms;

const State = enum(u8) {
    inactive,
    idle,
    squawk,
    hold_hint,
    climb_hint,
    hide_hint,
    liftoff,
    peck,
    fly,
    ending_fly_in,
    ending_idle,
    done,
    gone,
};

const PathPoint = struct {
    x: i16 = 0,
    y: i16 = 0,
};

const TriggerAction = enum(u8) {
    none = 0,
    squawk_hold_hint = 1,
    show_climb_hint = 2,
    peck_then_fly = 3,
};

const Trigger = struct {
    action: TriggerAction = .none,
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,
};

const Npc = struct {
    active: bool = false,
    state: State = .inactive,
    x: i32 = 0,
    y: i32 = 0,
    home_x: i16 = 0,
    home_y: i16 = 0,
    hint_x: i16 = 0,
    hint_y: i16 = 0,
    path: [max_path_points]PathPoint = [_]PathPoint{.{}} ** max_path_points,
    triggers: [max_triggers]Trigger = [_]Trigger{.{}} ** max_triggers,
    path_count: u8 = 0,
    trigger_count: u8 = 0,
    path_index: u8 = 0,
    timer: u16 = 0,
    frame: u16 = 0,
    facing_left: bool = false,
};

const HintKind = enum(u8) {
    none,
    hold,
    climb,
    dash,
};

var npc: Npc = .{};
var loaded_frame: u16 = invalid_loaded_frame;
var loaded_hint_kind: HintKind = .none;

pub fn load(room_index: usize) void {
    npc = .{};
    hideObjects();

    const data = rooms[room_index].bird_npcs;
    if (data.len < 2 or readU16Le(data, 0) == 0) return;
    if (data.len < 12) return;

    npc = .{
        .active = true,
        .state = .idle,
        .home_x = readI16Le(data, 2),
        .home_y = readI16Le(data, 4),
        .hint_x = readI16Le(data, 6),
        .hint_y = readI16Le(data, 8),
        .x = pixelToFixed(readI16Le(data, 2)),
        .y = pixelToFixed(readI16Le(data, 4)),
        .path_count = @min(data[10], max_path_points),
        .trigger_count = @min(data[11], max_triggers),
        .facing_left = true,
    };

    var offset: usize = 12;
    var index: usize = 0;
    while (index < npc.path_count and offset + 4 <= data.len) : ({
        index += 1;
        offset += 4;
    }) {
        npc.path[index] = .{
            .x = readI16Le(data, offset),
            .y = readI16Le(data, offset + 2),
        };
    }
    while (index < data[10] and offset + 4 <= data.len) : ({
        index += 1;
        offset += 4;
    }) {}

    index = 0;
    while (index < npc.trigger_count and offset + 10 <= data.len) : ({
        index += 1;
        offset += 10;
    }) {
        npc.triggers[index] = .{
            .action = triggerActionFromByte(data[offset]),
            .x = readI16Le(data, offset + 2),
            .y = readI16Le(data, offset + 4),
            .w = readI16Le(data, offset + 6),
            .h = readI16Le(data, offset + 8),
        };
    }

    loadPalettes();
}

pub fn startEndingFlyIn(player_x: i16, player_y: i16, hint_x: i16, hint_y: i16) void {
    npc = .{
        .active = true,
        .state = .ending_fly_in,
        .x = pixelToFixed(player_x + 140),
        .y = pixelToFixed(player_y - 42),
        .home_x = player_x + 34,
        .home_y = player_y - 18,
        .hint_x = hint_x,
        .hint_y = hint_y,
        .frame = fly_first_frame,
        .facing_left = true,
    };
    loadPalettes();
}

pub fn update(player: Player, camera: Camera) void {
    if (!npc.active) return;

    npc.timer +%= 1;
    if (climbCompleteTriggered(player)) {
        npc.state = .liftoff;
        npc.timer = 0;
        hideObject(hint_object);
    }
    switch (npc.state) {
        .inactive, .gone => {},
        .idle => {
            npc.frame = idlePeckFrame();
            if (triggerActive(player, .squawk_hold_hint) or (npc.trigger_count == 0 and playerLandedBelow(player))) {
                npc.state = .squawk;
                npc.timer = 0;
            }
        },
        .squawk => {
            const frame_offset = @divTrunc(npc.timer, anim_speed);
            npc.frame = squawk_first_frame + @min(frame_offset, @as(u16, squawk_frame_count - 1));
            if (npc.timer >= hold_hint_frames) {
                npc.state = .hold_hint;
                npc.timer = 0;
            }
        },
        .hold_hint => {
            npc.frame = idlePeckFrame();
            if (npc.timer >= hold_hint_frames) {
                npc.state = .climb_hint;
                npc.timer = 0;
            }
        },
        .climb_hint => {
            npc.frame = idlePeckFrame();
            if (climbCompleteTriggered(player)) {
                npc.state = .liftoff;
                npc.timer = 0;
            }
        },
        .hide_hint => {
            npc.frame = idlePeckFrame();
            if (npc.timer >= hint_hide_frames) {
                npc.state = .done;
                npc.timer = 0;
            }
        },
        .peck => {
            const frame_offset = @divTrunc(npc.timer, anim_speed);
            npc.frame = peck_first_frame + @min(frame_offset, @as(u16, peck_frame_count - 1));
            if (frame_offset >= peck_frame_count) {
                npc.state = .fly;
                npc.timer = 0;
                npc.path_index = 0;
                npc.x = pixelToFixed(npc.home_x);
                npc.y = pixelToFixed(npc.home_y);
            }
        },
        .fly => {
            npc.frame = fly_first_frame + @as(u16, @intCast(@divTrunc(npc.timer, anim_speed) % fly_frame_count));
            npc.x += flyaway_vx;
            npc.y += flyaway_vy;
            npc.facing_left = npc.timer < flyaway_frames / 3;
            const draw_y = fixedToPixel(npc.y) - origin_offset_y - camera.y;
            if (draw_y < -32 or npc.timer >= flyaway_frames) {
                npc.state = .gone;
                hideObjects();
            }
        },
        .liftoff => {
            const frame_offset = @divTrunc(npc.timer, anim_speed);
            npc.frame = liftoff_first_frame + @min(frame_offset, @as(u16, liftoff_frame_count - 1));
            npc.x += liftoff_vx;
            npc.y += liftoff_vy;
            npc.facing_left = true;
            if (frame_offset >= liftoff_frame_count) {
                npc.state = .fly;
                npc.timer = 0;
            }
        },
        .ending_fly_in => {
            npc.frame = fly_first_frame + @as(u16, @intCast(@divTrunc(npc.timer, anim_speed) % fly_frame_count));
            npc.x = approach(npc.x, pixelToFixed(npc.home_x), 0x1A0);
            npc.y = approach(npc.y, pixelToFixed(npc.home_y), 0x110);
            npc.facing_left = true;
            if (npc.x == pixelToFixed(npc.home_x) and npc.y == pixelToFixed(npc.home_y)) {
                npc.state = .ending_idle;
                npc.timer = 0;
            }
        },
        .ending_idle => {
            npc.frame = idlePeckFrame();
            npc.facing_left = true;
        },
        .done => {
            npc.frame = idlePeckFrame();
        },
    }
}

pub fn draw(camera: Camera) void {
    if (!npc.active or npc.state == .inactive or npc.state == .gone) {
        hideObjects();
        return;
    }

    loadFrame(npc.frame);
    const draw_x = fixedToPixel(npc.x) - origin_offset_x - camera.x;
    const draw_y = fixedToPixel(npc.y) - origin_offset_y - camera.y;
    gba.display.objects[object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(draw_x),
        .y = objY(draw_y),
        .base_tile = base_tile,
        .priority = 0,
        .palette = palette_bank,
        .flip = gba.math.Vec2B.init(npc.facing_left, false),
    });

    const show_squawk_hint = npc.state == .squawk and npc.timer >= hint_show_delay_frames;
    const show_hide_hint = npc.state == .hide_hint or (npc.state == .liftoff and npc.timer < hint_hide_frames);
    const show_dash_hint = npc.state == .ending_idle;
    if (show_squawk_hint or npc.state == .hold_hint or npc.state == .climb_hint or show_hide_hint or show_dash_hint) {
        const hint_kind: HintKind = if (show_dash_hint)
            .dash
        else if (npc.state == .squawk or npc.state == .hold_hint)
            .hold
        else
            .climb;
        loadHint(hint_kind);
        const hide_lift: i16 = if (npc.state == .hide_hint) @intCast(@divTrunc(npc.timer, 4)) else 0;
        gba.display.objects[hint_object] = gba.display.Object.init(.{
            .size = .size_64x64,
            .x = objX(npc.hint_x - camera.x),
            .y = objY(npc.hint_y - hide_lift - camera.y),
            .base_tile = hint_base_tile,
            .priority = 0,
            .palette = hint_palette_bank,
        });
    } else {
        hideObject(hint_object);
    }
}

pub fn dismiss() void {
    npc.state = .gone;
    hideObjects();
}

pub fn hideObjects() void {
    hideObject(object);
    hideObject(hint_object);
}

pub fn invalidate() void {
    loaded_frame = invalid_loaded_frame;
    loaded_hint_kind = .none;
}

fn loadPalettes() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, hint_palette_bank) * 16], @ptrCast(&hint_palette_data), 16);
    invalidate();
}

fn triggerActionFromByte(value: u8) TriggerAction {
    return switch (value) {
        1 => .squawk_hold_hint,
        2 => .show_climb_hint,
        3 => .peck_then_fly,
        else => .none,
    };
}

fn climbCompleteTriggered(player: Player) bool {
    return switch (npc.state) {
        .squawk, .hold_hint, .climb_hint, .hide_hint, .peck, .done => triggerActive(player, .peck_then_fly) or
            (npc.trigger_count == 0 and playerReachedClimbGoal(player)),
        else => false,
    };
}

fn idlePeckFrame() u16 {
    const cycle_frame = npc.timer % peck_cycle_frames;
    const peck_total_frames = peck_frame_count * anim_speed;
    if (cycle_frame < peck_total_frames) {
        return peck_first_frame + @min(@divTrunc(cycle_frame, anim_speed), @as(u16, peck_frame_count - 1));
    }
    return squawk_first_frame;
}

fn playerLandedBelow(player: Player) bool {
    if (!player.grounded) return false;
    const player_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const player_y = fixedToPixel(player.y) + player_mod.body_height;
    return player_x >= npc.home_x - 72 and
        player_x <= npc.home_x + 96 and
        player_y >= npc.home_y + 8;
}

fn playerReachedClimbGoal(player: Player) bool {
    const player_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const player_y = fixedToPixel(player.y);
    return player_y <= npc.home_y - 16 or
        (player.grounded and player_x >= npc.home_x + 64 and player_y <= npc.home_y + 48);
}

fn triggerActive(player: Player, action: TriggerAction) bool {
    if (npc.trigger_count == 0) return false;
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;
    var index: usize = 0;
    while (index < npc.trigger_count) : (index += 1) {
        const trigger = npc.triggers[index];
        if (trigger.action != action) continue;
        const trigger_left = trigger.x;
        const trigger_top = trigger.y;
        const trigger_right = trigger.x + trigger.w;
        const trigger_bottom = trigger.y + trigger.h;
        if (rectsOverlap(player_left, player_top, player_right, player_bottom, trigger_left, trigger_top, trigger_right, trigger_bottom)) {
            return true;
        }
    }
    return false;
}

fn advanceAlongPath() bool {
    if (npc.path_count == 0 or npc.path_index >= npc.path_count) return false;
    const target = npc.path[npc.path_index];
    const target_x = pixelToFixed(target.x);
    const target_y = pixelToFixed(target.y);
    const dx = target_x - npc.x;
    const dy = target_y - npc.y;
    const dist_sq = @as(i64, dx) * dx + @as(i64, dy) * dy;
    if (dist_sq <= @as(i64, fly_speed) * fly_speed) {
        npc.x = target_x;
        npc.y = target_y;
        npc.path_index += 1;
        return npc.path_index < npc.path_count;
    }
    const dist: i32 = @intCast(sqrtU64(@intCast(dist_sq)));
    npc.x += @as(i32, @intCast(@divTrunc(@as(i64, dx) * fly_speed, dist)));
    npc.y += @as(i32, @intCast(@divTrunc(@as(i64, dy) * fly_speed, dist)));
    npc.facing_left = dx < 0;
    return true;
}

fn loadFrame(frame: u16) void {
    const safe_frame = @min(frame, total_frame_count - 1);
    if (loaded_frame == safe_frame) return;
    const byte_offset = @as(usize, safe_frame) * tiles_per_frame * 32;
    const byte_len = tiles_per_frame * 32;
    const frame_bytes = intro_tiles_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_frame = safe_frame;
}

fn loadHint(kind: HintKind) void {
    if (loaded_hint_kind == kind) return;
    switch (kind) {
        .hold => gba.display.memcpyObjectTiles4Bpp(hint_base_tile, @ptrCast(&hold_hint_tiles_data)),
        .climb => gba.display.memcpyObjectTiles4Bpp(hint_base_tile, @ptrCast(&climb_hint_tiles_data)),
        .dash => gba.display.memcpyObjectTiles4Bpp(hint_base_tile, @ptrCast(&dash_hint_tiles_data)),
        .none => {},
    }
    loaded_hint_kind = kind;
}
