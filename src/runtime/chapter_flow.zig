const gba = @import("gba");
const level = @import("../generated_rooms.zig");
const background = @import("background.zig");
const bird_npc = @import("bird_npc.zig");
const camera_mod = @import("camera.zig");
const dash_effects = @import("dash_effects.zig");
const dust = @import("dust.zig");
const foreground_stamps = @import("foreground_stamps.zig");
const frame = @import("frame.zig");
const gameplay_scene = @import("gameplay_scene.zig");
const hair = @import("hair.zig");
const math = @import("math.zig");
const overworld_placeholder = @import("overworld_placeholder.zig");
const player_controller = @import("player_controller.zig");
const player_mod = @import("player.zig");
const prologue_bridge = @import("prologue_bridge.zig");
const prologue_granny_cutscene = @import("prologue_granny_cutscene.zig");
const room_data = @import("room_data.zig");
const room_systems = @import("room_systems.zig");
const room_transition = @import("room_transition.zig");
const room_wires = @import("room_wires.zig");
const video = @import("video.zig");

pub const RoomLoadMode = enum {
    initial,
    transition,
    respawn,
};

const EndLevelTransitionPhase = enum(u8) {
    inactive,
    walk,
    camera_up,
    black,
    overworld,
};

const EndLevelTransition = struct {
    phase: EndLevelTransitionPhase = .inactive,
    timer: u8 = 0,
    start_camera: Camera = .{ .x = 0, .y = 0 },
};

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const Spawn = room_data.Spawn;

const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const clampI16 = math.clampI16;
const screen_height = video.screen_height;

const end_level_walk_frames: u8 = 28;
const end_level_walk_speed: i32 = fixed_one;
const end_level_camera_frames: u8 = 54;
const end_level_camera_lift: i16 = 48;
const end_level_black_frames: u8 = 18;

const rooms = level.rooms;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;
const level_one_room_index = level.roomIndexFor(level.chapter_index, "city_1") orelse rooms.len;

var dash_unlocked: bool = false;
var end_level_transition: EndLevelTransition = .{};

pub fn loadGameplayRoom(room_index: usize, mode: RoomLoadMode) void {
    loadRoomBackground(room_index);
    room_systems.load(room_index, mode == .transition);
    end_level_transition = .{};
}

pub fn hideGameplayDisplayForLoad() void {
    gba.display.bg_palette.colors[0] = .black;
    gba.display.ctrl.bg0 = false;
    gba.display.ctrl.bg1 = false;
    gba.display.ctrl.obj = false;
    gba.display.hideAllObjects();
}

pub fn showGameplayDisplay(room_index: usize) void {
    gba.display.ctrl.bg0 = true;
    gba.display.ctrl.bg1 = rooms[room_index].parallax != null;
    gba.display.ctrl.obj = true;
}

pub fn dashUnlocked() bool {
    return dash_unlocked;
}

pub fn endingHoldActive() bool {
    return prologue_bridge.endingHoldActive();
}

pub fn shouldStartBridgeEndingHold(player: Player, room_index: usize) bool {
    return prologue_bridge.shouldStartEndingHold(player, isPrologueEndRoom(room_index));
}

pub fn startBridgeEndingHold(player: *Player) void {
    prologue_bridge.startEndingHold();
    holdPlayerForBridgeEnding(player);
    dust.clear();

    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const hint = prologue_bridge.endingHintOrDefault(player_x, player_y);
    bird_npc.startEndingFlyIn(player_x, player_y, hint.x, hint.y);
}

pub fn updateBridgeEndingHold(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    const horizontal: i16 = @intCast(input.getAxisHorizontal());
    const vertical: i16 = @intCast(input.getAxisVertical());
    if (input.isJustPressed(.B) and player_controller.tryStartDash(player, horizontal, vertical, true)) {
        prologue_bridge.markEndingDashStarted();
        dash_unlocked = true;
        bird_npc.dismiss();
        player_controller.updateDashMovement(player, room_index);
    } else {
        holdPlayerForBridgeEnding(player);
    }
}

pub fn shouldStartEndLevelTransition(player: Player, room_index: usize) bool {
    return prologue_bridge.shouldStartEndLevelTransition(player, isPrologueEndRoom(room_index), end_level_transition.phase != .inactive);
}

pub fn startEndLevelTransition(player: *Player, camera: Camera) void {
    player.vx = 0;
    player.vy = 0;
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.moving = false;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.facing_left = false;
    player.animation = .run;
    player.animation_timer = 0;
    dust.clear();
    dash_effects.clear();
    prologue_bridge.clearCollapseShake();
    bird_npc.hideObjects();
    end_level_transition = .{
        .phase = .walk,
        .timer = 0,
        .start_camera = camera,
    };
}

pub fn updateTransitionIfActive(player: *Player, camera: *Camera, room_index: *usize, respawn: *Spawn, input: gba.input.BufferedKeysState) bool {
    if (end_level_transition.phase == .inactive) return false;
    updateEndLevelTransition(player, camera, room_index, respawn, input);
    return true;
}

fn loadRoomBackground(room_index: usize) void {
    background.resetRoomStream();
    const room = rooms[room_index];
    gba.mem.memcpy(gba.display.bg_palette, room.palette.ptr, room.palette.len);
    gba.display.bg_palette.colors[background.static_wire_bg_color_index] = gba.ColorRgb555.rgb(13, 14, 18);
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(room.tiles));
    prologue_granny_cutscene.resetPaletteState();
}

fn holdPlayerForBridgeEnding(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.grounded = false;
    player.moving = false;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    if (player.animation != .fall) {
        player.animation = .fall;
        player.animation_timer = 0;
    }
}

fn updateEndLevelTransition(player: *Player, camera: *Camera, room_index: *usize, respawn: *Spawn, input: gba.input.BufferedKeysState) void {
    const active_room_index = room_index.*;
    switch (end_level_transition.phase) {
        .inactive => {},
        .walk => {
            player.vx = end_level_walk_speed;
            player.vy = 0;
            player.moving = true;
            player.facing_left = false;
            player.grounded = true;
            player_controller.moveHorizontal(player, player.vx, active_room_index);
            player_controller.updateAnimation(player);
            hair.update(player, endingHoldActive());
            dash_effects.update();
            room_systems.updateEndLevelEffects(active_room_index, camera.*);

            const render_camera = updateCamera(player.*, active_room_index);
            camera.* = render_camera;
            frame.sync();
            gameplay_scene.drawEndLevelTransition(player, render_camera, active_room_index, room_systems.animCounter());

            if (end_level_transition.timer >= end_level_walk_frames) {
                player.vx = 0;
                player.moving = false;
                end_level_transition.phase = .camera_up;
                end_level_transition.timer = 0;
                end_level_transition.start_camera = render_camera;
            } else {
                end_level_transition.timer += 1;
            }
        },
        .camera_up => {
            player.vx = 0;
            player.vy = 0;
            player.moving = false;
            player.grounded = true;
            player_controller.updateAnimation(player);
            hair.update(player, endingHoldActive());
            dash_effects.update();
            room_systems.updateEndLevelEffects(active_room_index, camera.*);

            const room = rooms[active_room_index];
            const progress = @min(end_level_transition.timer, end_level_camera_frames);
            const lift: i16 = @intCast(@divTrunc(@as(u16, progress) * @as(u16, @intCast(end_level_camera_lift)), end_level_camera_frames));
            const min_y = -end_level_camera_lift;
            const max_y = room.height_pixels - screen_height;
            const render_camera = Camera{
                .x = end_level_transition.start_camera.x,
                .y = clampI16(end_level_transition.start_camera.y - lift, min_y, max_y),
            };
            camera.* = render_camera;
            frame.sync();
            gameplay_scene.drawEndLevelTransition(player, render_camera, active_room_index, room_systems.animCounter());

            if (end_level_transition.timer >= end_level_camera_frames) {
                end_level_transition.phase = .black;
                end_level_transition.timer = 0;
                overworld_placeholder.cutToBlack();
            } else {
                end_level_transition.timer += 1;
            }
        },
        .black => {
            frame.sync();
            if (end_level_transition.timer >= end_level_black_frames) {
                loadOverworldScreen();
                end_level_transition.phase = .overworld;
                end_level_transition.timer = 0;
            } else {
                end_level_transition.timer += 1;
            }
        },
        .overworld => {
            if (input.isJustPressed(.A)) {
                startLevelOneFromOverworld(player, camera, room_index, respawn);
                return;
            }
            frame.sync();
        },
    }
}

fn loadOverworldScreen() void {
    prologue_bridge.deactivateForOverworld();
    dust.clear();
    dash_effects.clear();
    gameplay_scene.hideWindSnowObjects();
    gameplay_scene.hideChimneySmokeObjects();
    prologue_bridge.hideObjects();
    foreground_stamps.hideObjects();
    room_wires.hideObjects(prologue_bridge.active());
    overworld_placeholder.loadScreen();
}

fn startLevelOneFromOverworld(player: *Player, camera: *Camera, room_index: *usize, respawn: *Spawn) void {
    if (level_one_room_index >= rooms.len) return;

    hideGameplayDisplayForLoad();
    frame.sync();

    const target_room = level_one_room_index;
    room_index.* = target_room;
    respawn.* = rooms[target_room].spawn;
    loadGameplayRoom(target_room, .transition);
    room_systems.clearTransientEffects();
    player.* = room_transition.spawnPlayer(target_room);
    player.hair_initialized = false;
    hair.update(player, endingHoldActive());
    camera.* = updateCamera(player.*, target_room);
    gameplay_scene.resetWindSnow(target_room, camera.*);
    gameplay_scene.resetChimneySmoke(target_room);
    gameplay_scene.drawLoaded(player, camera.*, target_room, room_systems.animCounter());
    end_level_transition = .{};
    frame.sync();
    showGameplayDisplay(target_room);
}

fn updateCamera(player: Player, room_index: usize) Camera {
    return camera_mod.forPlayer(player.x, player.y, rooms[room_index]);
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}
