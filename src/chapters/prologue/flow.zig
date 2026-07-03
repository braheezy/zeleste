const gba = @import("gba");
const level = @import("../../generated_rooms.zig");
const camera_mod = @import("../../world/camera.zig");
const audio = @import("../../core/audio.zig");
const dash_effects = @import("../../player/dash_effects.zig");
const dust = @import("../../effects/dust.zig");
const foreground_stamps = @import("../../room/foreground_stamps.zig");
const file_select = @import("../../core/file_select.zig");
const frame = @import("../../core/frame.zig");
const gameplay_scene = @import("../../room/gameplay_scene.zig");
const hair = @import("../../player/hair.zig");
const math = @import("../../core/math.zig");
const overworld_placeholder = @import("../../world/overworld_placeholder.zig");
const player_controller = @import("../../player/controller.zig");
const player_mod = @import("../../player/state.zig");
const room_data = @import("../../world/room_data.zig");
const room_loader = @import("../../world/room_loader.zig");
const room_systems = @import("../../world/room_systems.zig");
const room_transition = @import("../../world/room_transition.zig");
const save = @import("../../core/save.zig");
const video = @import("../../core/video.zig");

const bird_npc = @import("bird_npc.zig");
const bridge = @import("bridge.zig");
const city = @import("../city.zig");
const room_wires = @import("room_wires.zig");

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
const RespawnPoint = room_data.RespawnPoint;

const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const clampI16 = math.clampI16;
const absI16 = math.absI16;
const screen_width = video.screen_width;
const screen_height = video.screen_height;

const end_level_walk_frames: u8 = 28;
const end_level_walk_speed: i32 = fixed_one;
const end_level_camera_frames: u8 = 54;
const end_level_black_frames: u8 = 18;

const rooms = level.rooms;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;

var dash_unlocked: bool = false;
var end_level_transition: EndLevelTransition = .{};

pub fn dashUnlocked() bool {
    return dash_unlocked;
}

pub fn endingHoldActive() bool {
    return bridge.endingHoldActive();
}

pub fn shouldStartBridgeEndingHold(player: Player, room_index: usize) bool {
    return bridge.shouldStartEndingHold(player, isPrologueEndRoom(room_index));
}

pub fn startBridgeEndingHold(player: *Player) void {
    bridge.startEndingHold(player);
    holdPlayerForBridgeEnding(player);
    dust.clear();

    const player_x = fixedToPixel(player.x);
    const player_y = fixedToPixel(player.y);
    const hint = bridge.endingHintOrDefault(player_x, player_y);
    const bird_start = bridge.endingBirdStartOrDefault(player_x, player_y);
    const bird_idle = bridge.endingBirdIdleOrDefault(player_x, player_y);
    bird_npc.startEndingFlyInAt(bird_start, bird_idle, hint);
}

pub fn updateBridgeEndingHold(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) void {
    const horizontal: i16 = @intCast(input.getAxisHorizontal());
    const vertical: i16 = @intCast(input.getAxisVertical());
    if (bird_npc.endingDashReady() and input.isJustPressed(.B) and player_controller.tryStartDash(player, horizontal, vertical, true)) {
        bridge.markEndingDashStarted();
        dash_unlocked = true;
        bird_npc.dismiss();
        player_controller.updateDashMovement(player, room_index);
    } else {
        holdPlayerForBridgeEnding(player);
    }
}

pub fn shouldStartEndLevelTransition(player: Player, room_index: usize) bool {
    return bridge.shouldStartEndLevelTransition(player, isPrologueEndRoom(room_index), end_level_transition.phase != .inactive);
}

pub fn startEndLevelTransition(player: *Player, camera: Camera) void {
    player.vx = 0;
    player.vy = 0;
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.moving = false;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    player.facing_left = false;
    player.animation = .run;
    player.animation_timer = 0;
    dust.clear();
    dash_effects.clear();
    bridge.clearCollapseShake();
    bird_npc.hideObjects();
    end_level_transition = .{
        .phase = .walk,
        .timer = 0,
        .start_camera = camera,
    };
}

pub fn updateTransitionIfActive(player: *Player, camera: *Camera, room_index: *usize, respawn: *RespawnPoint, input: gba.input.BufferedKeysState) bool {
    if (end_level_transition.phase == .inactive) return false;
    updateEndLevelTransition(player, camera, room_index, respawn, input);
    return true;
}

fn holdPlayerForBridgeEnding(player: *Player) void {
    player.vx = 0;
    player.vy = 0;
    player.dashes = 1;
    player.dash_timer = 0;
    player.dash_buffer_timer = 0;
    player.dash_cooldown_timer = 0;
    player.dash_refill_cooldown_timer = 0;
    player.grounded = false;
    player.moving = false;
    player.facing_left = false;
    player.climbing = false;
    player.wall_sliding = false;
    player.climb_dangling = false;
    player.climb_dir = 0;
    if (player.animation != .fall) {
        player.animation = .fall;
        player.animation_timer = 0;
    }
}

fn updateEndLevelTransition(player: *Player, camera: *Camera, room_index: *usize, respawn: *RespawnPoint, input: gba.input.BufferedKeysState) void {
    const active_room_index = room_index.*;
    switch (end_level_transition.phase) {
        .inactive => {},
        .walk => {
            const walk_target = bridge.endingWalkTargetOrDefault(player.*);
            const target_left = walk_target.x - player_mod.body_width / 2;
            const player_left = fixedToPixel(player.x);
            const dx = target_left - player_left;
            const reached_target = absI16(dx) <= 1 or end_level_transition.timer >= end_level_walk_frames * 2;

            player.vx = if (dx < 0) -end_level_walk_speed else end_level_walk_speed;
            player.vy = 0;
            player.moving = !reached_target;
            player.facing_left = dx < 0;
            player.grounded = true;
            if (!reached_target) {
                player_controller.moveHorizontal(player, player.vx, active_room_index);
            } else {
                player.vx = 0;
            }
            player_controller.updateAnimation(player);
            hair.update(player, endingHoldActive());
            dash_effects.update();
            room_systems.updateEndLevelEffects(active_room_index, camera.*);

            const render_camera = updateCamera(player.*, active_room_index);
            camera.* = render_camera;
            frame.sync();
            gameplay_scene.drawEndLevelTransition(player, render_camera, active_room_index, room_systems.animCounter());

            if (reached_target) {
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

            const progress = @min(end_level_transition.timer, end_level_camera_frames);
            const target_camera = endingTargetCamera(active_room_index, end_level_transition.start_camera);
            const render_camera = Camera{
                .x = lerpI16(end_level_transition.start_camera.x, target_camera.x, progress, end_level_camera_frames),
                .y = lerpI16(end_level_transition.start_camera.y, target_camera.y, progress, end_level_camera_frames),
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
            switch (overworld_placeholder.update(input)) {
                .none => {},
                .back => {
                    _ = file_select.chooseSlot();
                    overworld_placeholder.loadScreen();
                },
                .prologue => {
                    startGameplayFromOverworld(level.start_room_index, player, camera, room_index, respawn);
                    return;
                },
                .city => {
                    const target_room = city.flow.firstRoomIndex() orelse level.start_room_index;
                    startGameplayFromOverworld(target_room, player, camera, room_index, respawn);
                    return;
                },
            }
            frame.sync();
        },
    }
}

fn loadOverworldScreen() void {
    audio.stopSoundEffects();
    audio.stopMusic();
    save.finishChapter(0);
    bridge.deactivateForOverworld();
    dust.clear();
    dash_effects.clear();
    gameplay_scene.hideWindSnowObjects();
    gameplay_scene.hideChimneySmokeObjects();
    bridge.hideObjects();
    foreground_stamps.hideObjects();
    room_wires.hideObjects(bridge.active());
    overworld_placeholder.loadScreen();
}

fn startGameplayFromOverworld(target_room: usize, player: *Player, camera: *Camera, room_index: *usize, respawn: *RespawnPoint) void {
    audio.stopSoundEffects();
    room_loader.hideGameplayDisplayForLoad();
    frame.sync();

    room_index.* = target_room;
    save.beginChapterRunForRoom(target_room);
    if (city.flow.ownsGeneratedRoomIndex(target_room)) {
        audio.playCityMusic();
    } else {
        audio.playPrologueMusic();
    }
    respawn.* = .{
        .room_index = target_room,
        .spawn = rooms[target_room].spawn,
    };
    _ = save.commitSessionCheckpoint(respawn.room_index, respawn.spawn);
    room_loader.loadGameplayRoomPhased(target_room, .transition);
    room_systems.clearTransientEffects();
    player.* = room_transition.spawnPlayerAt(respawn.spawn);
    player.hair_initialized = false;
    hair.update(player, endingHoldActive());
    camera.* = updateCamera(player.*, target_room);
    gameplay_scene.resetWindSnow(target_room, camera.*);
    gameplay_scene.resetChimneySmoke(target_room);
    gameplay_scene.drawLoaded(player, camera.*, target_room, room_systems.animCounter());
    end_level_transition = .{};
    frame.sync();
    room_loader.showGameplayDisplay(target_room);
}

fn updateCamera(player: Player, room_index: usize) Camera {
    return camera_mod.forPlayer(player.x, player.y, rooms[room_index]);
}

fn endingTargetCamera(room_index: usize, start_camera: Camera) Camera {
    const room = rooms[room_index];
    const target = bridge.endingCameraTargetOrDefault(start_camera);
    const min_y: i16 = -@as(i16, @intCast(screen_height / 2));
    return .{
        .x = clampI16(target.x - screen_width / 2, 0, room.width_pixels - screen_width),
        .y = clampI16(target.y - screen_height / 2, min_y, room.height_pixels - screen_height),
    };
}

fn lerpI16(start: i16, target: i16, step: u8, total: u8) i16 {
    const delta = @as(i32, target) - @as(i32, start);
    const offset = @divTrunc(delta * @as(i32, step), @as(i32, total));
    return @intCast(@as(i32, start) + offset);
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}
