const gba = @import("gba");
const level = @import("generated_rooms.zig");
const build_options = @import("build_options");
const audio = @import("core/audio.zig");
const camera_mod = @import("world/camera.zig");
const chapter_flow = @import("chapters/flow.zig");
const chapter_systems = @import("chapters/systems.zig");
const city = @import("chapters/city.zig");
const debug_fps = @import("core/debug_fps.zig");
const dust = @import("effects/dust.zig");
const frame = @import("core/frame.zig");
const gameplay_scene = @import("room/gameplay_scene.zig");
const hair = @import("player/hair.zig");
const room_data = @import("world/room_data.zig");
const player_controller = @import("player/controller.zig");
const player_death = @import("player/death.zig");
const player_mod = @import("player/state.zig");
const room_loader = @import("world/room_loader.zig");
const room_systems = @import("world/room_systems.zig");
const room_transition = @import("world/room_transition.zig");
const video = @import("core/video.zig");

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

const bg_screenblock = video.bg_screenblock;
const parallax_screenblock = video.parallax_screenblock;
const parallax_charblock = video.parallax_charblock;

const dust_palette_bank: u4 = dust.palette_bank;

const rooms = level.rooms;

pub fn run() void {
    gba.mem.wait_ctrl.* = .default;
    audio.init();

    var room_index: usize = startRoomIndex();
    room_loader.loadGameplayRoom(room_index, .initial);
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
                room_loader.loadGameplayRoom(room_index, .respawn);
                room_systems.clearTransientEffects();
                player = room_transition.spawnPlayerAt(respawn);
                hair.update(&player, chapter_systems.endingHairOverrideActive(room_index));
                camera = updateCamera(player, room_index);
                gameplay_scene.resetWindSnow(room_index, camera);
                gameplay_scene.resetChimneySmoke(room_index);
                gameplay_scene.drawRespawnRoom(camera, room_index, room_systems.animCounter());
                player_death.startRespawnBurst(player);
                respawn_burst_timer = player_death.respawn_burst_frames;
                frame.sync();
                room_loader.showGameplayDisplay(room_index);
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
        } else if (chapter_flow.endingHoldActive(room_index)) {
            chapter_flow.updateBridgeEndingHold(&player, input, room_index);
        } else {
            player_controller.update(&player, input, room_index, chapter_flow.dashUnlocked(room_index));
            if (room_systems.updateDynamicHazards(&player, room_index)) |death_cause| {
                player_death.begin(player, camera, death_cause, room_index);
                death_timer = player_death.death_frames;
                continue;
            }
        }
        room_systems.updateActors(&player, room_index, camera);
        room_systems.updatePlayerEffects(&player, room_index);
        const next_camera = updateCamera(player, room_index);
        room_systems.updateEffects(room_index, next_camera);
        if (!cutscene_locked and !chapter_flow.endingHoldActive(room_index) and chapter_flow.shouldStartEndLevelTransition(player, room_index)) {
            camera = next_camera;
            chapter_flow.startEndLevelTransition(&player, camera, room_index);
            continue;
        }
        if (!cutscene_locked and !chapter_flow.endingHoldActive(room_index) and chapter_flow.shouldStartBridgeEndingHold(player, room_index)) {
            chapter_flow.startBridgeEndingHold(&player, room_index);
        }
        if (!cutscene_locked and !chapter_flow.endingHoldActive(room_index)) {
            if (room_systems.touchHazard(player, room_index)) |death_cause| {
                player_death.begin(player, next_camera, death_cause, room_index);
                death_timer = player_death.death_frames;
                continue;
            }
        }
        const previous_room_index = room_index;
        if (!cutscene_locked and !chapter_flow.endingHoldActive(room_index) and room_transition.trySwitch(&player, input, &room_index, &respawn)) {
            chapter_systems.handleRoomTransition(previous_room_index, room_index);
            room_loader.hideGameplayDisplayForLoad();
            frame.sync();
            room_loader.loadGameplayRoom(room_index, .transition);
            room_systems.clearTransientEffects();
            player.hair_initialized = false;
            hair.update(&player, chapter_systems.endingHairOverrideActive(room_index));
            camera = updateCamera(player, room_index);
            gameplay_scene.resetWindSnow(room_index, camera);
            gameplay_scene.resetChimneySmoke(room_index);
            gameplay_scene.drawLoaded(&player, camera, room_index, room_systems.animCounter());
            frame.sync();
            room_loader.showGameplayDisplay(room_index);
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
        if (city.flow.roomIndexFor(build_options.start_chapter, build_options.start_room)) |city_room_index| {
            break :blk city_room_index;
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
    const shake = chapter_systems.cameraShakeOffset(room_index) orelse return camera;
    const room = rooms[room_index];
    return camera_mod.withOffset(camera, room, shake.x, shake.y);
}
