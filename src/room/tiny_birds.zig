const gba = @import("gba");
const assets = @import("../core/assets.zig");
const audio = @import("../core/audio.zig");
const camera_mod = @import("../world/camera.zig");
const collectibles = @import("../core/collectibles.zig");
const collision = @import("../world/collision.zig");
const level = @import("../generated_rooms.zig");
const math = @import("../core/math.zig");
const obj_vram = @import("../core/obj_vram.zig");
const object_slots = @import("object_slots.zig");
const oam = @import("../core/oam.zig");
const player_mod = @import("../player/state.zig");
const room_data = @import("../world/room_data.zig");
const save = @import("../core/save.zig");
const text_mod = @import("../core/text.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const absI16 = math.absI16;
const fixed_one = math.fixed_one;
const fixedToPixel = math.fixedToPixel;
const pixelToFixed = math.pixelToFixed;
const hideObject = oam.hideObject;
const objX = oam.objX;
const objY = oam.objY;
const readI16Le = room_data.readI16Le;
const readU16Le = room_data.readU16Le;
const sound_ids = assets.sound_ids;

const tiles_data align(4) = assets.tiny_bird_tiles_data;
const palette_data align(4) = assets.tiny_bird_palette_data;
const crystal_heart_normal_tiles_data align(4) = assets.crystal_heart_normal_tiles_data;
const crystal_heart_normal_palette_data align(4) = assets.crystal_heart_normal_palette_data;
const crystal_heart_ghost_tiles_data align(4) = assets.crystal_heart_ghost_tiles_data;
const crystal_heart_ghost_palette_data align(4) = assets.crystal_heart_ghost_palette_data;

pub const Variant = enum(u8) {
    cyan = 0,
    red = 1,
    blue = 2,
    green = 3,
    gold = 4,
};

pub const PuzzleColor = enum(u8) {
    white,
    purple,
    blue,
    red,
    yellow,
};

const AntennaLight = enum(u8) {
    off,
    white,
    purple,
    blue,
    red,
    yellow,
};

pub const Start = struct {
    x: i16,
    y: i16,
    variant: Variant,
    group: u4 = 0,
    vx: i32,
    vy: i32,
    phase: u8 = 0,
};

pub const PuzzleStart = struct {
    x: i16,
    y: i16,
    color: PuzzleColor,
    dx: i16,
    dy: i16,
    phase: u8 = 0,
};

pub const AntennaTipStart = struct {
    x: i16,
    y: i16,
};

pub const base_tile: u10 = @intCast(obj_vram.bird_actor.start);
pub const palette_bank: u4 = 6;
const puzzle_palette_bank: u4 = 7;
const crystal_heart_base_tile: u10 = @intCast(obj_vram.crystal_heart.start);
const crystal_heart_palette_bank: u4 = 10;
const heart_title_base_tile: u10 = @intCast(obj_vram.crystal_heart_title.start);
const heart_title_palette_bank: u4 = 11;

const first_object = object_slots.ambient_npc_first_object;
pub const max_birds = 8;
pub const max_puzzle_birds = 6;
const variant_count: u10 = 5;
const frame_count: u8 = 2;
const tiles_per_variant = frame_count;
const antenna_tip_tile_count: usize = 6;
const antenna_tip_tile_offset: u10 = variant_count * @as(u10, tiles_per_variant);
const trigger_distance_x: i16 = 76;
const trigger_distance_y: i16 = 64;
const rooms = level.rooms;
const puzzle_clump_frames: u16 = 84;
const puzzle_extend_frames: u16 = 18;
const puzzle_hold_frames: u16 = 44;
const puzzle_return_frames: u16 = 24;
const puzzle_cycle_frames: u16 = puzzle_clump_frames + puzzle_extend_frames + puzzle_hold_frames + puzzle_return_frames;
const puzzle_first_object = first_object - max_puzzle_birds;
const antenna_tip_object = puzzle_first_object - 1;
const heart_object = antenna_tip_object - 1;
const heart_title_object_first = object_slots.cutscene_dialogue_first_object;
const heart_title_object_count: usize = 7;
const heart_title_tiles_per_object: usize = 8;
const heart_title_tile_count: usize = heart_title_object_count * heart_title_tiles_per_object;
const heart_title_width: i16 = @intCast(heart_title_object_count * 32);
const heart_title_height: i16 = 16;
const heart_title_y: i16 = 48;
const oam_object_count = 128;
const antenna_tip_lights = [_]AntennaLight{ .off, .white, .purple, .blue, .red, .yellow };
const antenna_tip_sequence = [_]AntennaLight{ .white, .purple, .blue, .red, .purple, .yellow };
const antenna_tip_off_frames: u16 = 72;
const antenna_tip_color_frames: u16 = 54;
const antenna_tip_cycle_frames: u16 = antenna_tip_off_frames + antenna_tip_color_frames * 6;
const crystal_heart_tiles_per_frame: usize = assets.crystal_heart_meta.tiles_per_frame;
const crystal_heart_cell_width: i16 = assets.crystal_heart_meta.cell_width;
const crystal_heart_cell_height: i16 = assets.crystal_heart_meta.cell_height;
const heart_collision_half_w: i16 = 10;
const heart_collision_half_h: i16 = 10;
const heart_form_frames: u16 = 48;
const heart_pop_frames: u16 = 26;
const heart_fly_frames: u16 = 64;
const heart_collect_frames: u16 = 150;
const heart_title_start_frame: u16 = 36;
const heart_title_end_frame: u16 = 138;
const heart_spin_ticks: u16 = 3;
const heart_fastspin_ticks: u16 = 2;

comptime {
    if (object_slots.ambient_npc_object_count < max_birds) {
        @compileError("ambient NPC object slots do not cover tiny bird ambient slots");
    }
    if (first_object + max_birds > oam_object_count) {
        @compileError("tiny bird ambient object slots exceed OAM");
    }
    if (puzzle_first_object + max_puzzle_birds > first_object) {
        @compileError("tiny bird puzzle object slots overlap ambient slots");
    }
    if (puzzle_first_object + max_puzzle_birds > oam_object_count) {
        @compileError("tiny bird puzzle object slots exceed OAM");
    }
    if (antenna_tip_object + 1 > puzzle_first_object) {
        @compileError("tiny bird antenna tip object slot overlaps puzzle slots");
    }
    if (heart_object + 1 > antenna_tip_object) {
        @compileError("crystal heart object slot overlaps tiny bird antenna tip slot");
    }
    if (heart_title_object_first + heart_title_object_count > heart_object) {
        @compileError("crystal heart title slots overlap tiny bird reward slots");
    }
    if (@as(usize, antenna_tip_tile_offset) + antenna_tip_tile_count > obj_vram.bird_actor.count) {
        @compileError("tiny bird antenna tip tiles exceed bird actor tile range");
    }
}

const Bird = struct {
    active: bool = false,
    flying: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    variant: u8 = 0,
    group: u4 = 0,
    phase: u8 = 0,
};

const PuzzleBird = struct {
    active: bool = false,
    center_x: i16 = 0,
    center_y: i16 = 0,
    dx: i16 = 0,
    dy: i16 = 0,
    color: PuzzleColor = .white,
    phase: u8 = 0,
};

const PixelPoint = struct {
    x: i16,
    y: i16,
};

const DashStep = struct {
    x: i16,
    y: i16,
};

const HeartPhase = enum(u8) {
    unavailable,
    waiting_for_solution,
    forming,
    pop,
    fly_to_target,
    available,
    bounce,
    collect,
};

const heart_solution = [_]DashStep{
    .{ .x = 0, .y = -1 },
    .{ .x = -1, .y = 0 },
    .{ .x = 1, .y = 1 },
    .{ .x = 1, .y = -1 },
    .{ .x = -1, .y = 0 },
    .{ .x = -1, .y = -1 },
};

var birds: [max_birds]Bird = [_]Bird{.{}} ** max_birds;
var puzzle_birds: [max_puzzle_birds]PuzzleBird = [_]PuzzleBird{.{}} ** max_puzzle_birds;
var formation_start_positions: [max_puzzle_birds]PixelPoint = [_]PixelPoint{.{ .x = 0, .y = 0 }} ** max_puzzle_birds;
var antenna_tip: ?AntennaTipStart = null;
var antenna_tip_tiles: [antenna_tip_tile_count]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** antenna_tip_tile_count;
var bird_count: usize = 0;
var puzzle_bird_count: usize = 0;
var puzzle_timer: u16 = 0;
var active_room_index: usize = rooms.len;
var triggered_group_mask: u16 = 0;
var flown_group_masks: [rooms.len]u16 = [_]u16{0} ** rooms.len;
var puzzle_center: PixelPoint = .{ .x = 0, .y = 0 };
var heart_phase: HeartPhase = .unavailable;
var heart_timer: u16 = 0;
var heart_solution_index: u8 = 0;
var heart_id: u16 = 0;
var heart_ghost: bool = false;
var heart_target: PixelPoint = .{ .x = 0, .y = 0 };
var heart_start: PixelPoint = .{ .x = 0, .y = 0 };
var heart_x: i32 = 0;
var heart_y: i32 = 0;
var heart_vx: i32 = 0;
var heart_vy: i32 = 0;
var heart_collect_player_x: i16 = 0;
var heart_collect_player_y: i16 = 0;
var loaded_heart_frame: u16 = 0xffff;
var loaded_heart_tiles_valid: bool = false;
var loaded_heart_tiles_ghost: bool = false;
var loaded_heart_palette_valid: bool = false;
var loaded_heart_palette_ghost: bool = false;
var heart_title_loaded: bool = false;
var heart_title_visible: bool = false;
var heart_blend_active: bool = false;

pub fn load(room_index: usize, starts: []const Start, puzzle_starts: []const PuzzleStart, maybe_antenna_tip: ?AntennaTipStart) void {
    birds = [_]Bird{.{}} ** max_birds;
    puzzle_birds = [_]PuzzleBird{.{}} ** max_puzzle_birds;
    antenna_tip = null;
    bird_count = 0;
    puzzle_bird_count = 0;
    puzzle_timer = 0;
    active_room_index = room_index;
    triggered_group_mask = 0;
    puzzle_center = .{ .x = 0, .y = 0 };
    resetHeartState();
    hideObjects();

    if ((starts.len == 0 and puzzle_starts.len == 0 and maybe_antenna_tip == null) or room_index >= rooms.len) return;
    antenna_tip = maybe_antenna_tip;

    const flown_group_mask = flown_group_masks[room_index];
    var source_index: usize = 0;
    while (source_index < starts.len and bird_count < max_birds) : (source_index += 1) {
        const start = starts[source_index];
        if ((flown_group_mask & groupBit(start.group)) != 0) continue;
        birds[bird_count] = .{
            .active = true,
            .x = pixelToFixed(start.x),
            .y = pixelToFixed(start.y),
            .vx = start.vx,
            .vy = start.vy,
            .variant = @intFromEnum(start.variant),
            .group = start.group,
            .phase = start.phase,
        };
        bird_count += 1;
    }

    source_index = 0;
    while (source_index < puzzle_starts.len and puzzle_bird_count < max_puzzle_birds) : (source_index += 1) {
        const start = puzzle_starts[source_index];
        puzzle_birds[puzzle_bird_count] = .{
            .active = true,
            .center_x = start.x,
            .center_y = start.y,
            .dx = start.dx,
            .dy = start.dy,
            .color = start.color,
            .phase = start.phase,
        };
        puzzle_bird_count += 1;
    }
    configurePuzzleHeart(room_index);
    if (heart_phase == .unavailable and puzzle_bird_count != 0) {
        puzzle_bird_count = 0;
        antenna_tip = null;
    }
    if (bird_count == 0 and puzzle_bird_count == 0 and antenna_tip == null and heart_phase == .unavailable) return;

    loadGraphics(puzzle_bird_count > 0 or antenna_tip != null);
}

pub fn update(player: *Player, room_index: usize, anim_counter: u16) void {
    if (room_index != active_room_index or (bird_count == 0 and puzzle_bird_count == 0 and antenna_tip == null and heart_phase == .unavailable)) return;
    if (puzzle_bird_count != 0 or antenna_tip != null or heart_phase != .unavailable) puzzle_timer +%= 1;
    updatePuzzleHeart(player);
    if (bird_count == 0) return;

    var index: usize = 0;
    while (index < bird_count) : (index += 1) {
        const bird = &birds[index];
        if (!bird.active or bird.flying) continue;
        if (playerNearBird(player.*, bird.*)) {
            startGroupFlying(bird.group);
        }
    }

    var active_group_mask: u16 = 0;
    index = 0;
    while (index < bird_count) : (index += 1) {
        var bird = &birds[index];
        if (!bird.active) continue;

        if (bird.flying) {
            bird.x += bird.vx;
            bird.y += bird.vy;
            if ((anim_counter & 7) == 0) {
                const drift: i32 = if (((anim_counter >> 3) + bird.phase) & 1 == 0) fixed_one / 4 else -fixed_one / 4;
                bird.x += drift;
            }
            if (fixedToPixel(bird.y) < -12 or fixedToPixel(bird.x) < -16 or fixedToPixel(bird.x) > roomWidth(room_index) + 16) {
                bird.active = false;
                hideObject(first_object + index);
                continue;
            }
        }

        active_group_mask |= groupBit(bird.group);
    }

    if (triggered_group_mask != 0) {
        const finished_groups = triggered_group_mask & ~active_group_mask;
        if (finished_groups != 0) {
            flown_group_masks[room_index] |= finished_groups;
            triggered_group_mask &= active_group_mask;
        }
    }

    if (active_group_mask == 0) {
        bird_count = 0;
        hideAmbientObjects();
    }
}

pub fn draw(camera: Camera, anim_counter: u16) void {
    if (bird_count == 0 and puzzle_bird_count == 0 and antenna_tip == null and heart_phase == .unavailable and !heart_title_visible) return;

    var index: usize = 0;
    while (index < max_birds) : (index += 1) {
        if (index >= bird_count or !birds[index].active) {
            hideObject(first_object + index);
            continue;
        }
        const bird = birds[index];
        const frame: u8 = if (bird.flying)
            @intCast((anim_counter / 4 + bird.phase) % frame_count)
        else
            0;
        const screen_x = fixedToPixel(bird.x) - camera.x;
        const screen_y = fixedToPixel(bird.y) - camera.y;
        if (!visible8x8(screen_x, screen_y)) {
            hideObject(first_object + index);
            continue;
        }
        gba.display.objects[first_object + index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(screen_x),
            .y = objY(screen_y),
            .base_tile = base_tile + @as(u10, bird.variant) * tiles_per_variant + frame,
            .priority = 1,
            .palette = palette_bank,
        });
    }

    index = 0;
    while (index < max_puzzle_birds) : (index += 1) {
        const object_index = firstPuzzleObject() + index;
        if (index >= puzzle_bird_count or !puzzle_birds[index].active or !drawsPuzzleBirds()) {
            hideObject(object_index);
            continue;
        }

        const bird = puzzle_birds[index];
        const position = puzzleDrawPosition(bird, index);
        const frame: u8 = @intCast((puzzle_timer / 5 + bird.phase) % frame_count);
        const screen_x = position.x - camera.x;
        const screen_y = position.y - camera.y;
        if (!visible8x8(screen_x, screen_y)) {
            hideObject(object_index);
            continue;
        }
        const color = puzzleDrawColor(bird.color);
        gba.display.objects[object_index] = gba.display.Object.init(.{
            .size = .size_8x8,
            .x = objX(screen_x),
            .y = objY(screen_y),
            .base_tile = base_tile + @as(u10, puzzleVariantIndex(color)) * tiles_per_variant + frame,
            .priority = 0,
            .palette = puzzlePaletteBank(color),
        });
    }

    drawAntennaTip(camera);
    drawCrystalHeart(camera, anim_counter);
    drawHeartWhiteBlend();
    drawHeartTitle();
}

pub fn hideObjects() void {
    hideAmbientObjects();
    hidePuzzleObjects();
    hideObject(antenna_tip_object);
    hideObject(heart_object);
    hideHeartTitleObjects();
}

fn hideAmbientObjects() void {
    var index: usize = 0;
    while (index < max_birds) : (index += 1) {
        hideObject(first_object + index);
    }
}

fn hidePuzzleObjects() void {
    var index: usize = 0;
    while (index < max_puzzle_birds) : (index += 1) {
        hideObject(firstPuzzleObject() + index);
    }
}

fn loadGraphics(include_puzzle_palette: bool) void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&palette_data), 16);
    if (include_puzzle_palette) loadPuzzlePalette();
    gba.display.memcpyObjectTiles4Bpp(base_tile, @ptrCast(&tiles_data));
    if (include_puzzle_palette) loadAntennaTipTiles();
}

fn resetHeartState() void {
    formation_start_positions = [_]PixelPoint{.{ .x = 0, .y = 0 }} ** max_puzzle_birds;
    heart_phase = .unavailable;
    heart_timer = 0;
    heart_solution_index = 0;
    heart_id = 0;
    heart_ghost = false;
    heart_target = .{ .x = 0, .y = 0 };
    heart_start = .{ .x = 0, .y = 0 };
    heart_x = 0;
    heart_y = 0;
    heart_vx = 0;
    heart_vy = 0;
    heart_collect_player_x = 0;
    heart_collect_player_y = 0;
    loaded_heart_frame = 0xffff;
    loaded_heart_tiles_valid = false;
    loaded_heart_tiles_ghost = false;
    loaded_heart_palette_valid = false;
    loaded_heart_palette_ghost = false;
    heart_title_loaded = false;
    heart_title_visible = false;
    if (heart_blend_active) clearHeartWhiteBlend();
    heart_blend_active = false;
}

fn configurePuzzleHeart(room_index: usize) void {
    if (puzzle_bird_count == 0) return;
    puzzle_center = averagePuzzleCenter();
    heart_start = puzzle_center;
    heart_target = heartTargetForRoom(room_index, puzzle_center);
    heart_x = pixelToFixed(puzzle_center.x);
    heart_y = pixelToFixed(puzzle_center.y);

    const id = collectibles.crystalHeartId(room_index) orelse return;
    heart_id = id;
    const collected_before_run = collectibles.wasCrystalHeartCollectedBeforeRun(id);
    heart_ghost = collected_before_run;
    if (!collected_before_run and collectibles.isCrystalHeartCollected(id)) {
        heart_phase = .unavailable;
        return;
    }
    heart_phase = .waiting_for_solution;
}

fn averagePuzzleCenter() PixelPoint {
    var sum_x: i32 = 0;
    var sum_y: i32 = 0;
    var index: usize = 0;
    while (index < puzzle_bird_count) : (index += 1) {
        sum_x += puzzle_birds[index].center_x;
        sum_y += puzzle_birds[index].center_y;
    }
    const count: i32 = @intCast(@max(@as(usize, 1), puzzle_bird_count));
    return .{
        .x = @intCast(@divTrunc(sum_x, count)),
        .y = @intCast(@divTrunc(sum_y, count)),
    };
}

fn heartTargetForRoom(room_index: usize, fallback: PixelPoint) PixelPoint {
    if (room_index < rooms.len) {
        const data = rooms[room_index].strawberries;
        if (data.len >= 10 and readU16Le(data, 0) != 0) {
            const berry_x = readI16Le(data, 2);
            const berry_y = readI16Le(data, 4);
            return .{
                .x = math.clampI16(berry_x - 18, 16, roomWidth(room_index) - 16),
                .y = math.clampI16(berry_y + 52, 16, roomHeight(room_index) - 16),
            };
        }
    }
    return .{
        .x = math.clampI16(fallback.x + 108, 16, roomWidth(room_index) - 16),
        .y = math.clampI16(fallback.y + 16, 16, roomHeight(room_index) - 16),
    };
}

fn updatePuzzleHeart(player: *Player) void {
    switch (heart_phase) {
        .unavailable => {},
        .waiting_for_solution => updateHeartSolution(player.*),
        .forming => updateHeartForming(),
        .pop => updateHeartPop(),
        .fly_to_target => updateHeartFlight(),
        .available => updateAvailableHeart(player),
        .bounce => updateBouncedHeart(player),
        .collect => updateHeartCollect(player.*),
    }
}

fn updateHeartSolution(player: Player) void {
    if (puzzle_bird_count == 0 or !dashStartedThisFrame(player)) return;
    const step = heart_solution[@as(usize, heart_solution_index)];
    if (dashMatches(player, step)) {
        heart_solution_index += 1;
        if (@as(usize, heart_solution_index) >= heart_solution.len) {
            startHeartFormation();
        }
        return;
    }

    heart_solution_index = if (dashMatches(player, heart_solution[0])) 1 else 0;
}

fn startHeartFormation() void {
    var index: usize = 0;
    while (index < puzzle_bird_count) : (index += 1) {
        formation_start_positions[index] = puzzlePosition(puzzle_birds[index], puzzle_timer);
    }
    heart_solution_index = 0;
    heart_timer = 0;
    heart_phase = .forming;
    heart_start = puzzle_center;
    heart_x = pixelToFixed(puzzle_center.x);
    heart_y = pixelToFixed(puzzle_center.y);
    _ = audio.playSoundEffect(sound_ids.sfx_diamond_touch_01);
}

fn updateHeartForming() void {
    if (heart_timer < heart_form_frames) {
        heart_timer += 1;
        return;
    }
    heart_timer = 0;
    heart_phase = .pop;
    _ = audio.playSoundEffect(sound_ids.sfx_diamond_touch_02);
}

fn updateHeartPop() void {
    if (heart_timer < heart_pop_frames) {
        heart_timer += 1;
        return;
    }
    heart_timer = 0;
    heart_phase = .fly_to_target;
    heart_start = puzzle_center;
    heart_x = pixelToFixed(heart_start.x);
    heart_y = pixelToFixed(heart_start.y);
    _ = audio.playSoundEffect(sound_ids.sfx_diamond_touch_03);
}

fn updateHeartFlight() void {
    const step = @min(heart_timer, heart_fly_frames);
    const position = heartFlightPosition(step);
    heart_x = pixelToFixed(position.x);
    heart_y = pixelToFixed(position.y);
    if (heart_timer < heart_fly_frames) {
        heart_timer += 1;
        return;
    }
    heart_timer = 0;
    heart_phase = .available;
    heart_x = pixelToFixed(heart_target.x);
    heart_y = pixelToFixed(heart_target.y);
}

fn updateAvailableHeart(player: *Player) void {
    if (!playerTouchesHeart(player.*, fixedToPixel(heart_x), fixedToPixel(heart_y))) return;
    if (dashActive(player.*)) {
        startHeartCollect(player);
    } else {
        startHeartBounce(player.*);
    }
}

fn startHeartBounce(player: Player) void {
    const player_x = playerCenterX(player);
    const heart_center_x = fixedToPixel(heart_x);
    heart_vx = if (player_x < heart_center_x) fixed_one * 2 else -fixed_one * 2;
    heart_vy = -fixed_one * 2;
    heart_timer = 0;
    heart_phase = .bounce;
    _ = audio.playSoundEffect(sound_ids.sfx_diamond_return_01);
}

fn updateBouncedHeart(player: *Player) void {
    if (playerTouchesHeart(player.*, fixedToPixel(heart_x), fixedToPixel(heart_y)) and dashActive(player.*)) {
        startHeartCollect(player);
        return;
    }

    heart_x += heart_vx;
    heart_y += heart_vy;
    heart_vx = @divTrunc(heart_vx * 7, 8);
    heart_vy += fixed_one / 8;

    if (heart_timer > 12) {
        heart_x += @divTrunc(pixelToFixed(heart_target.x) - heart_x, 8);
        heart_y += @divTrunc(pixelToFixed(heart_target.y) - heart_y, 8);
    }

    if (heart_timer < 46) {
        heart_timer += 1;
        return;
    }
    heart_phase = .available;
    heart_timer = 0;
    heart_x = pixelToFixed(heart_target.x);
    heart_y = pixelToFixed(heart_target.y);
}

fn startHeartCollect(player: *Player) void {
    heart_collect_player_x = playerCenterX(player.*);
    heart_collect_player_y = playerCenterY(player.*);
    heart_timer = 0;
    heart_phase = .collect;
    player.dashes = 1;
    player.stamina = player_mod.climb_max_stamina;
    player.dash_refill_cooldown_timer = 0;
    if (heart_ghost) {
        _ = audio.playSoundEffect(sound_ids.sfx_strawberry_red_get_1000);
        return;
    }
    if (collectibles.markCrystalHeartCollected(heart_id)) {
        save.commitProgress();
    }
    _ = audio.playSoundEffect(sound_ids.sfx_strawberry_red_get_1000);
}

fn updateHeartCollect(player: Player) void {
    heart_collect_player_x = playerCenterX(player);
    heart_collect_player_y = playerCenterY(player);
    if (heart_timer < heart_collect_frames) {
        heart_timer += 1;
        return;
    }
    heart_phase = .unavailable;
    puzzle_bird_count = 0;
    antenna_tip = null;
    hideObject(heart_object);
    hidePuzzleObjects();
}

fn dashStartedThisFrame(player: Player) bool {
    return player.dash_timer == player_mod.dash_frames - 1 and (player.dash_dir_x != 0 or player.dash_dir_y != 0);
}

fn dashActive(player: Player) bool {
    return player.dash_timer > 0 and (player.dash_dir_x != 0 or player.dash_dir_y != 0);
}

fn dashMatches(player: Player, step: DashStep) bool {
    return player.dash_dir_x == step.x and player.dash_dir_y == step.y;
}

fn playerTouchesHeart(player: Player, center_x: i16, center_y: i16) bool {
    const player_left = fixedToPixel(player.x);
    const player_top = fixedToPixel(player.y);
    const player_right = player_left + player_mod.body_width;
    const player_bottom = player_top + player_mod.body_height;
    return collision.rectsOverlap(
        player_left,
        player_top,
        player_right,
        player_bottom,
        center_x - heart_collision_half_w,
        center_y - heart_collision_half_h,
        center_x + heart_collision_half_w,
        center_y + heart_collision_half_h,
    );
}

fn playerCenterX(player: Player) i16 {
    return fixedToPixel(player.x) + player_mod.body_width / 2;
}

fn playerCenterY(player: Player) i16 {
    return fixedToPixel(player.y) + player_mod.body_height / 2;
}

fn loadPuzzlePalette() void {
    const base = @as(usize, puzzle_palette_bank) * 16;
    gba.mem.memcpy16(&gba.display.obj_palette.colors[base], @ptrCast(&palette_data), 16);

    gba.display.obj_palette.colors[base + 1] = gba.ColorRgb555.rgb(18, 21, 23);
    gba.display.obj_palette.colors[base + 2] = gba.ColorRgb555.rgb(26, 28, 29);
    gba.display.obj_palette.colors[base + 3] = gba.ColorRgb555.rgb(31, 31, 31);
    gba.display.obj_palette.colors[base + 4] = gba.ColorRgb555.rgb(10, 4, 18);
    gba.display.obj_palette.colors[base + 5] = gba.ColorRgb555.rgb(18, 8, 28);
    gba.display.obj_palette.colors[base + 6] = gba.ColorRgb555.rgb(27, 15, 31);
}

fn loadAntennaTipTiles() void {
    antenna_tip_tiles = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** antenna_tip_tile_count;
    for (antenna_tip_lights, 0..) |light, index| {
        drawAntennaTipTile(index, antennaTipPaletteIndex(light));
    }
    gba.display.memcpyObjectTiles4Bpp(base_tile + antenna_tip_tile_offset, &antenna_tip_tiles);
}

fn drawAntennaTipTile(tile_index: usize, color: u4) void {
    drawAntennaTipRow(tile_index, 1, 3, 2, color);
    drawAntennaTipRow(tile_index, 2, 1, 6, color);
    drawAntennaTipRow(tile_index, 3, 0, 8, color);
    drawAntennaTipRow(tile_index, 4, 0, 8, color);
    drawAntennaTipRow(tile_index, 5, 1, 6, color);
    drawAntennaTipRow(tile_index, 6, 3, 2, color);
}

fn drawAntennaTipRow(tile_index: usize, y: i16, start_x: i16, width: i16, color: u4) void {
    var x: i16 = 0;
    while (x < width) : (x += 1) {
        setAntennaTipTilePixel(tile_index, start_x + x, y, color);
    }
}

fn setAntennaTipTilePixel(tile_index: usize, x: i16, y: i16, color: u4) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const pixel_index: u8 = @intCast(y * 8 + x);
    const byte_index = pixel_index >> 1;
    if ((pixel_index & 1) == 0) {
        antenna_tip_tiles[tile_index].data_8[byte_index] = (antenna_tip_tiles[tile_index].data_8[byte_index] & 0xf0) | color;
    } else {
        antenna_tip_tiles[tile_index].data_8[byte_index] = (antenna_tip_tiles[tile_index].data_8[byte_index] & 0x0f) | (@as(u8, color) << 4);
    }
}

fn startGroupFlying(group: u4) void {
    triggered_group_mask |= groupBit(group);
    var index: usize = 0;
    while (index < bird_count) : (index += 1) {
        if (birds[index].active and birds[index].group == group) {
            birds[index].flying = true;
        }
    }
}

fn playerNearBird(player: Player, bird: Bird) bool {
    const player_x = fixedToPixel(player.x) + player_mod.body_width / 2;
    const player_y = fixedToPixel(player.y) + player_mod.body_height / 2;
    const bird_x = fixedToPixel(bird.x) + 4;
    const bird_y = fixedToPixel(bird.y) + 4;
    return absI16(player_x - bird_x) <= trigger_distance_x and
        absI16(player_y - bird_y) <= trigger_distance_y;
}

fn groupBit(group: u4) u16 {
    return @as(u16, 1) << group;
}

fn roomWidth(room_index: usize) i16 {
    if (room_index >= rooms.len) return 0;
    return rooms[room_index].width_pixels;
}

fn roomHeight(room_index: usize) i16 {
    if (room_index >= rooms.len) return 0;
    return rooms[room_index].height_pixels;
}

fn visible8x8(x: i16, y: i16) bool {
    return x > -8 and x < 240 and y > -8 and y < 160;
}

fn visible32x32(x: i16, y: i16) bool {
    return x > -32 and x < 240 and y > -32 and y < 160;
}

fn firstPuzzleObject() usize {
    return puzzle_first_object;
}

fn drawsPuzzleBirds() bool {
    return switch (heart_phase) {
        .waiting_for_solution, .forming => true,
        .pop => heart_timer < 12,
        .collect => heart_timer < heart_collect_frames,
        else => false,
    };
}

fn puzzleDrawPosition(bird: PuzzleBird, index: usize) PixelPoint {
    return switch (heart_phase) {
        .forming => lerpPoint(formation_start_positions[index], heartBlobPosition(index, heart_timer), heart_timer, heart_form_frames),
        .pop => heartBlobPosition(index, heart_timer),
        .collect => heartCollectParticlePosition(index, heart_timer),
        else => puzzlePosition(bird, puzzle_timer),
    };
}

fn puzzleDrawColor(color: PuzzleColor) PuzzleColor {
    return switch (heart_phase) {
        .forming, .pop, .collect => .white,
        else => color,
    };
}

fn heartBlobPosition(index: usize, timer: u16) PixelPoint {
    const offset = heartBlobOffset(index);
    const pulse: i16 = if (((timer / 6) + @as(u16, @intCast(index))) & 1 == 0) 1 else 0;
    return .{
        .x = puzzle_center.x + offset.x + pulse,
        .y = puzzle_center.y + offset.y - pulse,
    };
}

fn heartBlobOffset(index: usize) PixelPoint {
    return switch (index % max_puzzle_birds) {
        0 => .{ .x = -4, .y = -4 },
        1 => .{ .x = 3, .y = -3 },
        2 => .{ .x = -5, .y = 1 },
        3 => .{ .x = 4, .y = 1 },
        4 => .{ .x = -2, .y = 4 },
        else => .{ .x = 2, .y = 4 },
    };
}

fn heartCollectParticlePosition(index: usize, timer: u16) PixelPoint {
    const offset = heartCollectParticleOffset(index);
    const burst_frames: u16 = 30;
    const suck_frames: u16 = 54;
    const heart_center: PixelPoint = .{ .x = fixedToPixel(heart_x), .y = fixedToPixel(heart_y) };
    const burst_end = addScaledOffset(heart_center, offset, 1, 1);

    if (timer < burst_frames) {
        return addScaledOffset(heart_center, offset, timer, burst_frames);
    }

    const suck_timer = @min(timer - burst_frames, suck_frames);
    return lerpPoint(
        burst_end,
        .{ .x = heart_collect_player_x, .y = heart_collect_player_y },
        suck_timer,
        suck_frames,
    );
}

fn heartCollectParticleOffset(index: usize) PixelPoint {
    return switch (index % max_puzzle_birds) {
        0 => .{ .x = -42, .y = -24 },
        1 => .{ .x = 36, .y = -20 },
        2 => .{ .x = -34, .y = 18 },
        3 => .{ .x = 42, .y = 22 },
        4 => .{ .x = -12, .y = -38 },
        else => .{ .x = 10, .y = 36 },
    };
}

fn addScaledOffset(point: PixelPoint, offset: PixelPoint, step: u16, total: u16) PixelPoint {
    const bounded_total = @max(@as(u16, 1), total);
    return .{
        .x = @intCast(@as(i32, point.x) + @divTrunc(@as(i32, offset.x) * @as(i32, step), @as(i32, bounded_total))),
        .y = @intCast(@as(i32, point.y) + @divTrunc(@as(i32, offset.y) * @as(i32, step), @as(i32, bounded_total))),
    };
}

fn heartFlightPosition(step: u16) PixelPoint {
    const base = lerpPoint(heart_start, heart_target, step, heart_fly_frames);
    const half = @max(@as(u16, 1), heart_fly_frames / 2);
    const distance_from_mid = if (step <= half) step else heart_fly_frames - step;
    const arc: i16 = @intCast(@divTrunc(@as(i32, distance_from_mid) * -12, @as(i32, half)));
    return .{ .x = base.x, .y = base.y + arc };
}

fn drawCrystalHeart(camera: Camera, anim_counter: u16) void {
    if (!heartObjectVisible()) {
        hideObject(heart_object);
        return;
    }

    const center = heartDrawCenter(anim_counter);
    const screen_x = center.x - @divTrunc(crystal_heart_cell_width, 2) - camera.x;
    const screen_y = center.y - @divTrunc(crystal_heart_cell_height, 2) - camera.y;
    if (!visible32x32(screen_x, screen_y)) {
        hideObject(heart_object);
        return;
    }

    loadCrystalHeartFrame(heartFrame(anim_counter), heart_ghost);
    gba.display.objects[heart_object] = gba.display.Object.init(.{
        .size = .size_32x32,
        .x = objX(screen_x),
        .y = objY(screen_y),
        .base_tile = crystal_heart_base_tile,
        .priority = 0,
        .palette = crystal_heart_palette_bank,
    });
}

fn heartObjectVisible() bool {
    return switch (heart_phase) {
        .pop => heart_timer >= 10,
        .fly_to_target, .available, .bounce => true,
        .collect => heart_timer < 22,
        else => false,
    };
}

fn heartDrawCenter(anim_counter: u16) PixelPoint {
    if (heart_phase == .available) {
        return .{
            .x = heart_target.x,
            .y = heart_target.y + heartBob(anim_counter),
        };
    }
    return .{
        .x = fixedToPixel(heart_x),
        .y = fixedToPixel(heart_y),
    };
}

fn heartBob(anim_counter: u16) i16 {
    return switch ((anim_counter / 12) & 3) {
        0 => 0,
        1 => -1,
        2 => -2,
        else => -1,
    };
}

fn heartFrame(anim_counter: u16) u16 {
    if (heart_phase == .available) {
        return assets.crystal_heart_meta.spin_first_frame +
            (anim_counter / heart_spin_ticks) % assets.crystal_heart_meta.spin_frame_count;
    }
    return assets.crystal_heart_meta.fastspin_first_frame +
        (anim_counter / heart_fastspin_ticks) % assets.crystal_heart_meta.fastspin_frame_count;
}

fn loadCrystalHeartFrame(frame: u16, ghost: bool) void {
    loadCrystalHeartPalette(ghost);
    if (loaded_heart_tiles_valid and loaded_heart_frame == frame and loaded_heart_tiles_ghost == ghost) return;
    const tile_data = if (ghost) &crystal_heart_ghost_tiles_data else &crystal_heart_normal_tiles_data;
    const byte_offset = @as(usize, frame) * crystal_heart_tiles_per_frame * 32;
    const byte_len = crystal_heart_tiles_per_frame * 32;
    const frame_bytes = tile_data[byte_offset .. byte_offset + byte_len];
    gba.display.memcpyObjectTiles4Bpp(crystal_heart_base_tile, @ptrCast(@alignCast(frame_bytes)));
    loaded_heart_frame = frame;
    loaded_heart_tiles_valid = true;
    loaded_heart_tiles_ghost = ghost;
}

fn loadCrystalHeartPalette(ghost: bool) void {
    if (loaded_heart_palette_valid and loaded_heart_palette_ghost == ghost) return;
    if (ghost) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, crystal_heart_palette_bank) * 16], @ptrCast(&crystal_heart_ghost_palette_data), 16);
    } else {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, crystal_heart_palette_bank) * 16], @ptrCast(&crystal_heart_normal_palette_data), 16);
    }
    loaded_heart_palette_valid = true;
    loaded_heart_palette_ghost = ghost;
}

fn drawHeartWhiteBlend() void {
    const luma = heartWhiteLuma();
    if (luma == 0) {
        if (heart_blend_active) clearHeartWhiteBlend();
        return;
    }
    gba.mem.io.reg_bldcnt.* = 0x00bf;
    gba.mem.io.reg_bldalpha.* = 0;
    gba.mem.io.reg_bldy.* = luma;
    heart_blend_active = true;
}

fn heartWhiteLuma() u5 {
    if (heart_phase != .collect) return 0;
    if (heart_timer < 10) return 16;
    if (heart_timer >= 42) return 0;
    const fade: u16 = @divTrunc((heart_timer - 10) * 16, 32);
    return @intCast(16 - @min(fade, 16));
}

fn clearHeartWhiteBlend() void {
    gba.mem.io.reg_bldcnt.* = 0;
    gba.mem.io.reg_bldalpha.* = 0;
    gba.mem.io.reg_bldy.* = 0;
}

fn drawHeartTitle() void {
    const visible = heart_phase == .collect and heart_timer >= heart_title_start_frame and heart_timer < heart_title_end_frame;
    if (!visible) {
        if (heart_title_visible) hideHeartTitleObjects();
        heart_title_visible = false;
        return;
    }

    loadHeartTitleGraphics();
    const x: i16 = @divTrunc(240 - heart_title_width, 2);
    var index: usize = 0;
    while (index < heart_title_object_count) : (index += 1) {
        gba.display.objects[heart_title_object_first + index] = gba.display.Object.init(.{
            .size = .size_32x16,
            .x = objX(x + @as(i16, @intCast(index * 32))),
            .y = objY(heart_title_y),
            .base_tile = heart_title_base_tile + @as(u10, @intCast(index * heart_title_tiles_per_object)),
            .priority = 0,
            .palette = heart_title_palette_bank,
        });
    }
    heart_title_visible = true;
}

fn loadHeartTitleGraphics() void {
    if (heart_title_loaded) return;
    const base = @as(usize, heart_title_palette_bank) * 16;
    gba.display.obj_palette.colors[base + 0] = .black;
    gba.display.obj_palette.colors[base + 1] = gba.ColorRgb555.rgb(18, 27, 31);
    gba.display.obj_palette.colors[base + 2] = gba.ColorRgb555.rgb(3, 6, 12);
    gba.display.obj_palette.colors[base + 3] = .white;

    clearHeartTitleTiles();
    const title = ". POINTLESS MACHINES .";
    const title_width: i16 = @intCast(title.len * 6);
    const x = @divTrunc(heart_title_width - title_width, 2);
    text_mod.drawLine(setHeartTitlePixel, heart_title_width, title, x + 1, 5, 2);
    text_mod.drawLine(setHeartTitlePixel, heart_title_width, title, x, 4, 1);
    heart_title_loaded = true;
}

fn clearHeartTitleTiles() void {
    var index: usize = 0;
    while (index < heart_title_tile_count) : (index += 1) {
        gba.display.obj_blocks.tiles_4bpp[@as(usize, heart_title_base_tile) + index].fill(0);
    }
}

fn setHeartTitlePixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or y < 0 or x >= heart_title_width or y >= heart_title_height) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const object_x = ux / 32;
    const tile_x = (ux & 31) / 8;
    const tile_y = uy / 8;
    const local_x = ux & 7;
    const local_y = uy & 7;
    const tile_index = object_x * heart_title_tiles_per_object + tile_y * 4 + tile_x;
    if (tile_index >= heart_title_tile_count) return;
    gba.display.obj_blocks.tiles_4bpp[@as(usize, heart_title_base_tile) + tile_index].setPixel16(
        @intCast(local_x),
        @intCast(local_y),
        @intCast(color),
    );
}

fn hideHeartTitleObjects() void {
    var index: usize = 0;
    while (index < heart_title_object_count) : (index += 1) {
        hideObject(heart_title_object_first + index);
    }
}

fn drawAntennaTip(camera: Camera) void {
    if (heart_phase != .waiting_for_solution) {
        hideObject(antenna_tip_object);
        return;
    }
    const tip = antenna_tip orelse {
        hideObject(antenna_tip_object);
        return;
    };
    const light = antennaTipLight();
    const screen_x = tip.x - camera.x - 4;
    const screen_y = tip.y - camera.y - 4;
    if (!visible8x8(screen_x, screen_y)) {
        hideObject(antenna_tip_object);
        return;
    }
    gba.display.objects[antenna_tip_object] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(screen_x),
        .y = objY(screen_y),
        .base_tile = base_tile + antenna_tip_tile_offset + antennaTipTileIndex(light),
        .priority = 0,
        .palette = antennaTipPaletteBank(light),
    });
}

fn antennaTipLight() AntennaLight {
    const frame = puzzle_timer % antenna_tip_cycle_frames;
    if (frame < antenna_tip_off_frames) return .off;

    const sequence_frame = frame - antenna_tip_off_frames;
    const index: usize = @intCast(sequence_frame / antenna_tip_color_frames);
    return antenna_tip_sequence[index];
}

fn antennaTipTileIndex(light: AntennaLight) u10 {
    return switch (light) {
        .off => 0,
        .white => 1,
        .purple => 2,
        .blue => 3,
        .red => 4,
        .yellow => 5,
    };
}

fn puzzlePosition(bird: PuzzleBird, timer: u16) PixelPoint {
    const frame = timer % puzzle_cycle_frames;
    const clump = clumpPosition(bird, timer);
    const spoke: PixelPoint = .{
        .x = bird.center_x + bird.dx,
        .y = bird.center_y + bird.dy,
    };

    if (frame < puzzle_clump_frames) return clump;
    if (frame < puzzle_clump_frames + puzzle_extend_frames) {
        return variedPathPoint(bird, clump, spoke, frame - puzzle_clump_frames, puzzle_extend_frames, false);
    }
    if (frame < puzzle_clump_frames + puzzle_extend_frames + puzzle_hold_frames) return spoke;
    return variedPathPoint(bird, spoke, clump, frame - puzzle_clump_frames - puzzle_extend_frames - puzzle_hold_frames, puzzle_return_frames, true);
}

fn clumpPosition(bird: PuzzleBird, timer: u16) PixelPoint {
    const tick: u8 = @intCast((timer / 7 + bird.phase) & 3);
    const wobble_x: i16 = switch (tick) {
        0 => 0,
        1 => 1,
        2 => 0,
        else => -1,
    };
    const wobble_y: i16 = switch ((tick + (bird.phase & 3)) & 3) {
        0 => 1,
        1 => 0,
        2 => -1,
        else => 0,
    };
    const base = clumpBaseOffset(bird.color);
    return .{
        .x = bird.center_x + base.x + wobble_x,
        .y = bird.center_y + base.y + wobble_y,
    };
}

fn clumpBaseOffset(color: PuzzleColor) PixelPoint {
    return switch (color) {
        .white => .{ .x = -1, .y = -2 },
        .purple => .{ .x = 2, .y = -1 },
        .blue => .{ .x = -2, .y = 1 },
        .red => .{ .x = 1, .y = 2 },
        .yellow => .{ .x = 0, .y = 0 },
    };
}

fn lerpPoint(start: PixelPoint, end: PixelPoint, step: u16, total: u16) PixelPoint {
    return .{
        .x = lerpI16(start.x, end.x, step, total),
        .y = lerpI16(start.y, end.y, step, total),
    };
}

fn variedPathPoint(bird: PuzzleBird, start: PixelPoint, end: PixelPoint, step: u16, total: u16, returning: bool) PixelPoint {
    const base = lerpPoint(start, end, step, total);
    const bend = pathBend(bird, step, total, returning);
    return addPerpendicularOffset(base, bird, bend);
}

fn pathBend(bird: PuzzleBird, step: u16, total: u16, returning: bool) i16 {
    const half = @max(@as(u16, 1), total / 2);
    const distance = if (step <= half) step else total - step;
    const amount: i16 = @intCast(@divTrunc(@as(i32, distance) * @as(i32, pathBendAmplitude(bird.color)), @as(i32, half)));
    return if (returning) -amount else amount;
}

fn pathBendAmplitude(color: PuzzleColor) i16 {
    return switch (color) {
        .white => 2,
        .purple => -2,
        .blue => 3,
        .red => -3,
        .yellow => 2,
    };
}

fn addPerpendicularOffset(point: PixelPoint, bird: PuzzleBird, bend: i16) PixelPoint {
    if (bend == 0) return point;

    if (absI16(bird.dx) > absI16(bird.dy)) {
        return .{ .x = point.x, .y = point.y + bend };
    }
    if (absI16(bird.dy) > absI16(bird.dx)) {
        return .{ .x = point.x + bend, .y = point.y };
    }

    return .{
        .x = point.x + if (bird.dy >= 0) -bend else bend,
        .y = point.y + if (bird.dx >= 0) bend else -bend,
    };
}

fn lerpI16(start: i16, end: i16, step: u16, total: u16) i16 {
    const delta = @as(i32, end) - @as(i32, start);
    const offset = @divTrunc(delta * @as(i32, step), @as(i32, total));
    return @intCast(@as(i32, start) + offset);
}

fn puzzleVariantIndex(color: PuzzleColor) u8 {
    return @intFromEnum(switch (color) {
        .white => Variant.cyan,
        .purple => Variant.red,
        .blue => Variant.blue,
        .red => Variant.red,
        .yellow => Variant.gold,
    });
}

fn antennaTipPaletteIndex(light: AntennaLight) u4 {
    return switch (light) {
        .off => 2,
        .white => 3,
        .purple => 6,
        .blue => 9,
        .red => 6,
        .yellow => 15,
    };
}

fn puzzlePaletteBank(color: PuzzleColor) u4 {
    return switch (color) {
        .white, .purple => puzzle_palette_bank,
        .blue, .red, .yellow => palette_bank,
    };
}

fn antennaTipPaletteBank(light: AntennaLight) u4 {
    return switch (light) {
        .off, .white, .purple => puzzle_palette_bank,
        .blue, .red, .yellow => palette_bank,
    };
}
