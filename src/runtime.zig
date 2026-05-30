const gba = @import("gba");
const level = @import("generated_rooms.zig");
const build_options = @import("build_options");
const audio = @import("runtime/audio.zig");
const camera_mod = @import("runtime/camera.zig");
const chapter_flow = @import("runtime/chapter_flow.zig");
const debug_fps = @import("runtime/debug_fps.zig");
const dust = @import("runtime/dust.zig");
const frame = @import("runtime/frame.zig");
const gameplay_scene = @import("runtime/gameplay_scene.zig");
const hair = @import("runtime/hair.zig");
const room_data = @import("runtime/room_data.zig");
const player_controller = @import("runtime/player_controller.zig");
const player_death = @import("runtime/player_death.zig");
const player_mod = @import("runtime/player.zig");
const prologue_bridge = @import("runtime/prologue_bridge.zig");
const prologue_granny_cutscene = @import("runtime/prologue_granny_cutscene.zig");
const room_systems = @import("runtime/room_systems.zig");
const room_transition = @import("runtime/room_transition.zig");
const text_mod = @import("runtime/text.zig");
const video = @import("runtime/video.zig");

pub const RoomBackground = room_data.RoomBackground;
pub const ParallaxLayer = room_data.ParallaxLayer;
pub const Spawn = room_data.Spawn;
pub const SceneRect = room_data.SceneRect;
pub const CutsceneAnimCue = room_data.CutsceneAnimCue;
pub const CutsceneDialoguePage = room_data.CutsceneDialoguePage;
pub const GrannyCutscene = room_data.GrannyCutscene;
pub const spawnFromBytes = room_data.spawnFromBytes;
pub const spawnFromBytesAt = room_data.spawnFromBytesAt;
const Camera = camera_mod.Camera;
const Player = player_mod.State;
const textEquals = text_mod.equals;

const bg_screenblock = video.bg_screenblock;
const parallax_screenblock = video.parallax_screenblock;
const parallax_charblock = video.parallax_charblock;

const dust_palette_bank: u4 = dust.palette_bank;

const rooms = level.rooms;

pub fn run() void {
    gba.mem.wait_ctrl.* = .default;
    audio.init();

    var room_index: usize = startRoomIndex();
    chapter_flow.loadGameplayRoom(room_index, .initial);
    gameplay_scene.loadWindSnowTiles();
    debug_fps.init(dust_palette_bank);
    gba.display.hideAllObjects();

    _ = gba.display.BackgroundMap.setup(0, .{
        .priority = 2,
        .base_screenblock = bg_screenblock,
        .size = .size_64x32,
        .bpp = .bpp_8,
        .scroll = .init(0, 0),
    });
    _ = gba.display.BackgroundMap.setup(1, .{
        .priority = 0,
        .base_charblock = parallax_charblock,
        .base_screenblock = parallax_screenblock,
        .size = .size_32x32,
        .bpp = .bpp_4,
        .scroll = .init(0, 0),
    });

    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .bg1 = rooms[room_index].parallax != null,
        .obj = true,
    });

    var input: gba.input.BufferedKeysState = .{};
    var player = room_transition.spawnPlayer(room_index);
    var respawn = rooms[room_index].spawn;
    var camera = updateCamera(player, room_index);
    var death_timer: u8 = 0;
    var respawn_burst_timer: u8 = 0;
    gameplay_scene.resetWindSnow(room_index, camera);
    gameplay_scene.resetChimneySmoke(room_index);
    gameplay_scene.drawInitial(&player, camera, room_index, room_systems.animCounter());

    while (true) {
        input.poll();
        if (chapter_flow.updateTransitionIfActive(&player, &camera, &room_index, &respawn, input)) {
            continue;
        }
        if (respawn_burst_timer > 0) {
            respawn_burst_timer -= 1;
            frame.sync();
            if (respawn_burst_timer == 0) {
                player_death.hideObjects();
                gameplay_scene.drawRespawnBurstEnd(&player, camera, room_index, room_systems.animCounter());
            } else {
                player_death.drawRespawn(camera, respawn_burst_timer);
            }
            continue;
        }

        if (death_timer > 0) {
            death_timer -= 1;
            if (death_timer != 0) {
                room_systems.updateFallingBlocksDuringDeath(room_index);
            }
            frame.sync();
            if (death_timer == 0) {
                player_death.hideObjects();
                chapter_flow.loadGameplayRoom(room_index, .respawn);
                room_systems.clearTransientEffects();
                player = room_transition.spawnPlayerAt(respawn);
                hair.update(&player, chapter_flow.endingHoldActive());
                camera = updateCamera(player, room_index);
                gameplay_scene.resetWindSnow(room_index, camera);
                gameplay_scene.resetChimneySmoke(room_index);
                gameplay_scene.drawRespawnRoom(camera, room_index, room_systems.animCounter());
                player_death.startRespawnBurst(player);
                respawn_burst_timer = player_death.respawn_burst_frames;
                frame.sync();
                chapter_flow.showGameplayDisplay(room_index);
            } else {
                drawDeathCountdownScene(camera, room_index, death_timer);
            }
            continue;
        }

        const cutscene_locked = room_systems.updateCutscenes(&player, input, room_index);
        room_systems.updateCutsceneEffects(room_index, camera);

        if (cutscene_locked) {
            player.vx = 0;
            player.vy = 0;
            player_controller.updateAnimation(&player);
        } else if (chapter_flow.endingHoldActive()) {
            chapter_flow.updateBridgeEndingHold(&player, input, room_index);
        } else {
            player_controller.update(&player, input, room_index, chapter_flow.dashUnlocked());
            if (room_systems.updateDynamicHazards(&player, room_index)) |death_cause| {
                player_death.begin(player, camera, death_cause);
                death_timer = player_death.death_frames;
                continue;
            }
        }
        room_systems.updateActors(&player, room_index, camera);
        room_systems.updatePlayerEffects(&player);
        const next_camera = updateCamera(player, room_index);
        room_systems.updateEffects(room_index, next_camera);
        if (!cutscene_locked and !chapter_flow.endingHoldActive() and chapter_flow.shouldStartEndLevelTransition(player, room_index)) {
            camera = next_camera;
            chapter_flow.startEndLevelTransition(&player, camera);
            continue;
        }
        if (!cutscene_locked and !chapter_flow.endingHoldActive() and chapter_flow.shouldStartBridgeEndingHold(player, room_index)) {
            chapter_flow.startBridgeEndingHold(&player);
        }
        if (!cutscene_locked and !chapter_flow.endingHoldActive()) {
            if (room_systems.touchHazard(player, room_index)) |death_cause| {
                player_death.begin(player, next_camera, death_cause);
                death_timer = player_death.death_frames;
                continue;
            }
        }
        const previous_room_index = room_index;
        if (!cutscene_locked and !chapter_flow.endingHoldActive() and room_transition.trySwitch(&player, input, &room_index, &respawn)) {
            prologue_granny_cutscene.handleRoomTransition(previous_room_index, room_index);
            chapter_flow.hideGameplayDisplayForLoad();
            frame.sync();
            chapter_flow.loadGameplayRoom(room_index, .transition);
            room_systems.clearTransientEffects();
            player.hair_initialized = false;
            hair.update(&player, chapter_flow.endingHoldActive());
            camera = updateCamera(player, room_index);
            gameplay_scene.resetWindSnow(room_index, camera);
            gameplay_scene.resetChimneySmoke(room_index);
            gameplay_scene.drawLoaded(&player, camera, room_index, room_systems.animCounter());
            frame.sync();
            chapter_flow.showGameplayDisplay(room_index);
            continue;
        }
        camera = next_camera;
        const render_camera = renderCameraWithCutsceneShake(camera, room_index);
        frame.sync();
        gameplay_scene.drawGameplay(&player, render_camera, room_index, room_systems.animCounter());
    }
}

fn startRoomIndex() usize {
    return comptime blk: {
        if (build_options.start_room.len == 0) break :blk level.start_room_index;
        if (build_options.start_chapter == 1 and textEquals(build_options.start_room, "1")) {
            break :blk level.roomIndexFor(level.chapter_index, "city_1") orelse
                @compileError("invalid development start override; level 1 room 1 is not generated");
        }
        break :blk level.roomIndexFor(build_options.start_chapter, build_options.start_room) orelse
            @compileError("invalid development start override; expected: <chapter> <room>, for example: 0 -1 or 1 1");
    };
}

fn drawDeathCountdownScene(camera: Camera, room_index: usize, death_timer: u8) void {
    gameplay_scene.drawDeathCountdownBase(camera, room_index);
    player_death.drawDeath(camera, death_timer);
}

fn updateCamera(player: Player, room_index: usize) Camera {
    return camera_mod.forPlayer(player.x, player.y, rooms[room_index]);
}

fn renderCameraWithCutsceneShake(camera: Camera, room_index: usize) Camera {
    const bridge_shake = prologue_bridge.collapseShakeOffset();
    const granny_shake = prologue_granny_cutscene.shakeOffset();
    if (granny_shake == null and bridge_shake == null) return camera;
    const room = rooms[room_index];
    var offset_x: i16 = 0;
    var offset_y: i16 = 0;
    if (granny_shake) |offset| {
        offset_x += offset.x;
        offset_y += offset.y;
    }
    if (bridge_shake) |offset| {
        offset_x += offset.x;
        offset_y += offset.y;
    }
    return camera_mod.withOffset(camera, room, offset_x, offset_y);
}
