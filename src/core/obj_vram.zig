const assets = @import("assets.zig");

pub const max_tiles: u16 = 1024;

pub const Range = struct {
    name: []const u8,
    start: u16,
    count: u16,

    pub fn end(self: Range) u16 {
        return self.start + self.count;
    }
};

pub const player_body = range("player body", 0, 16);
pub const falling_block_fixed = range("falling block fixed", 32, 28);
pub const player_hair = range("player hair", 60, 4);
pub const player_bang = range("player bang", 64, 4);
pub const dust = range("dust", 68, 8);
pub const falling_block_generic = range("falling block generic", 78, 6);
pub const wind_snow = range("wind snow", 272, 8);
pub const player_sweat = range("player sweat", 84, 16);
pub const player_death_vfx = range("player death vfx", 100, 6);
pub const dash_effects = range("dash effects", 106, 16);
pub const springs = range("springs", 122, 8);
pub const bridge = range("bridge", 128, 80);
pub const room_wires = range("room wires", 208, 32);
pub const theo_prompt_bubble = range("theo prompt bubble", 240, 32);
pub const falling_block_room_visuals = range("falling block room visuals", 320, 80);
pub const laugh_text = range("laugh text", 400, 32);
pub const strawberry_score = range("strawberry score", 400, 24);
pub const mech_blocks = range("mech blocks", 432, 104);
pub const rhythm_blocks = range("rhythm blocks", 536, 16);
pub const disappearing_platforms = range("disappearing platforms", 552, 32);
pub const foreground_stamps = range("foreground stamps", 576, 88);
pub const strawberry_normal = range("strawberry normal", 496, 80);
pub const strawberry_ghost = range("strawberry ghost", 664, 56);
pub const dash_refill = range("dash refill", 720, 44);
pub const breakable_ice = range("breakable ice", 764, 8);
pub const breakable_dirt = range("breakable dirt", 772, 8);
pub const breakable_ice_6c = range("breakable ice 6c", 780, 8);
pub const breakable_ice_7z = range("breakable ice 7z", 788, 8);
pub const cassette = range("cassette", 820, assets.cassette_meta.tiles_per_frame);
pub const cassette_bubble = range("cassette bubble", 828, assets.cassette_meta.bubble_tiles_per_frame);
pub const save_indicator = range("save indicator", 856, assets.save_icon_meta.tiles_per_frame);
pub const bird_actor = range("bird actor", 896, 32);
pub const crystal_heart = range("crystal heart", 928, assets.crystal_heart_meta.tiles_per_frame);
pub const crystal_heart_title = range("crystal heart title", 944, 56);
pub const city_end_actor = range("city end actor", 496, 32);
pub const city_end_memorial_text = range("city end memorial text", 928, 68);
pub const debug_fps = range("debug fps", 1000, 10);
pub const audio_debug = range("audio debug", 1010, 8);

pub const dialogue_portrait = range("dialogue portrait", 784, assets.granny_portrait_meta.tiles_per_frame);
pub const dialogue_textbox = range("dialogue textbox", 800, assets.textbox_meta.tile_count);
pub const pause_menu = range("pause menu", 800, 224);

const shared_gameplay_ranges = [_]Range{
    player_body,
    falling_block_fixed,
    player_hair,
    player_bang,
    dust,
    falling_block_generic,
    wind_snow,
    player_sweat,
    player_death_vfx,
    dash_effects,
    springs,
    falling_block_room_visuals,
    save_indicator,
    debug_fps,
    audio_debug,
};

const prologue_room_ranges = [_]Range{
    bridge,
    room_wires,
    laugh_text,
    foreground_stamps,
    bird_actor,
};

const city_collectible_ranges = [_]Range{
    strawberry_score,
    strawberry_normal,
    strawberry_ghost,
    dash_refill,
    cassette,
    cassette_bubble,
    crystal_heart,
    crystal_heart_title,
};

const city_breakable_ranges = [_]Range{
    breakable_ice,
    breakable_dirt,
    breakable_ice_6c,
    breakable_ice_7z,
};

const theo_dialogue_prompt_ranges = [_]Range{
    theo_prompt_bubble,
};

const city_end_cutscene_ranges = [_]Range{
    city_end_actor,
    city_end_memorial_text,
};

const dialogue_modal_ranges = [_]Range{
    dialogue_portrait,
    dialogue_textbox,
};

const pause_modal_ranges = [_]Range{
    pause_menu,
};

comptime {
    @setEvalBranchQuota(10_000);
    checkNoOverlap("shared gameplay", &shared_gameplay_ranges);
    checkNoOverlap("prologue room", &prologue_room_ranges);
    checkNoOverlap("city collectibles", &city_collectible_ranges);
    checkNoOverlap("city breakables", &city_breakable_ranges);
    checkNoOverlap("theo dialogue prompt", &theo_dialogue_prompt_ranges);
    checkNoOverlap("city end cutscene", &city_end_cutscene_ranges);
    checkNoOverlap("dialogue modal", &dialogue_modal_ranges);
    checkNoOverlap("pause modal", &pause_modal_ranges);
}

fn range(name: []const u8, start: u16, count: u16) Range {
    if (start + count > max_tiles) {
        @compileError(name ++ " OBJ tile range exceeds OBJ VRAM");
    }
    return .{
        .name = name,
        .start = start,
        .count = count,
    };
}

fn checkNoOverlap(group_name: []const u8, ranges: []const Range) void {
    for (ranges, 0..) |left, left_index| {
        for (ranges[left_index + 1 ..]) |right| {
            if (overlaps(left, right)) {
                @compileError(group_name ++ " OBJ tile overlap: " ++ left.name ++ " overlaps " ++ right.name);
            }
        }
    }
}

fn overlaps(left: Range, right: Range) bool {
    return left.start < right.end() and right.start < left.end();
}
