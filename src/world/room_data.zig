pub const Spawn = struct {
    x: i16,
    y: i16,
};

pub const RespawnPoint = struct {
    room_index: usize,
    spawn: Spawn,
};

pub const SceneRect = struct {
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,

    pub fn right(self: SceneRect) i16 {
        return self.x + self.w;
    }

    pub fn bottom(self: SceneRect) i16 {
        return self.y + self.h;
    }
};

pub const ExitDirection = enum(u8) {
    left,
    right,
    up,
    down,
};

pub const ExitLine = struct {
    direction: ExitDirection,
    x1: i16,
    y1: i16,
    x2: i16,
    y2: i16,
    target: usize,
};

pub const DeathLine = struct {
    x1: i16,
    y1: i16,
    x2: i16,
    y2: i16,
};

pub const CutsceneAnimCue = struct {
    actor: []const u8 = "",
    animation: []const u8 = "",
    mode: []const u8 = "",
};

pub const DialoguePortrait = enum(u8) {
    none,
    madeline_idle,
    granny_normal,
    granny_mock,
    granny_laugh,
};

pub const CutsceneDialoguePage = struct {
    speaker: []const u8,
    text: []const u8,
    portrait: DialoguePortrait = .none,
    cue: CutsceneAnimCue = .{},
    after_cue: CutsceneAnimCue = .{},
};

pub const GrannyCutscene = struct {
    trigger: SceneRect,
    granny: Spawn,
    granny_facing_left: bool,
    madeline_talk: Spawn,
    madeline_edge: Spawn,
    dialogue_box: SceneRect,
    laugh_start: Spawn,
    laugh_end: Spawn,
    laugh_text: []const u8,
    laugh_speed_px: i16,
    laugh_spawn_every_frames: u8,
    dialogue: []const CutsceneDialoguePage,
};

pub const ParallaxLayer = struct {
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
    width: i16,
    height: i16,
    width_tiles: usize,
    height_tiles: usize,
    world_x: i16,
    world_y: i16,
    chunk_count: u8,
    scroll_extra_x_divisor: i16,
    scroll_extra_y_divisor: i16,
};

pub const RoomBackground = struct {
    width_tiles: usize,
    height_tiles: usize,
    width_pixels: i16,
    height_pixels: i16,
    world_x: i16 = 0,
    world_y: i16 = 0,
    tiles: []align(4) const u8,
    map: []align(4) const u8,
    palette: []align(4) const u8,
    collision: []align(4) const u8,
    spawn: Spawn,
    spawn_left: Spawn,
    spawn_right: Spawn,
    spawn_top: Spawn,
    spawn_bottom: Spawn,
    respawn_points: []align(4) const u8,
    falling_blocks: []align(4) const u8,
    falling_block_tiles: []align(4) const u8,
    falling_block_palette: []align(4) const u8,
    breakable_walls: []align(4) const u8,
    disappearing_platforms: []align(4) const u8,
    mech_blocks: []align(4) const u8,
    traffic_block_tiles: []align(4) const u8,
    traffic_block_palette: []align(4) const u8,
    rhythm_blocks: []align(4) const u8,
    springs: []align(4) const u8,
    strawberries: []align(4) const u8,
    cassettes: []align(4) const u8,
    dash_refills: []align(4) const u8,
    hidden_covers: []align(4) const u8,
    hidden_cover_tiles: []align(4) const u8,
    hidden_cover_map: []align(4) const u8,
    hidden_cover_groups: []align(4) const u8,
    hidden_cover_palette: []align(4) const u8,
    foreground_stamps: []align(4) const u8,
    generic_stamps: []align(4) const u8,
    bird_npcs: []align(4) const u8,
    wires: []align(4) const u8,
    wire_tiles: []align(4) const u8,
    bridge_ending: []align(4) const u8,
    exit_lines: []const ExitLine = &.{},
    death_lines: []const DeathLine = &.{},
    granny_cutscene: ?*const GrannyCutscene = null,
    parallax: ?ParallaxLayer = null,
    wind_snow_strength: u8 = 0,
    wind_snow_dir_x: i16 = -1,
    left: ?usize = null,
    right: ?usize = null,
    up: ?usize = null,
    down: ?usize = null,
};

pub fn spawnFromBytes(bytes: []align(4) const u8) Spawn {
    return spawnFromBytesAt(bytes, 0);
}

pub fn spawnFromBytesAt(bytes: []align(4) const u8, offset: usize) Spawn {
    return .{
        .x = readI16Le(bytes, offset),
        .y = readI16Le(bytes, offset + 2),
    };
}

pub fn readI16Le(bytes: []align(4) const u8, offset: usize) i16 {
    const value = @as(u16, bytes[offset]) | (@as(u16, bytes[offset + 1]) << 8);
    return @bitCast(value);
}

pub fn readU16Le(bytes: []align(4) const u8, offset: usize) u16 {
    return @as(u16, bytes[offset]) | (@as(u16, bytes[offset + 1]) << 8);
}
