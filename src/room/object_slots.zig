const cutscene_dialogue = @import("../cutscene/dialogue.zig");
const falling_blocks = @import("falling_blocks.zig");
const foreground_stamps = @import("foreground_stamps.zig");

pub const cutscene_dialogue_first_object = falling_blocks.first_object;
pub const scene_effect_first_object = cutscene_dialogue_first_object + cutscene_dialogue.object_count;

pub const ambient_npc_first_object = foreground_stamps.behind_first_object + foreground_stamps.max_stamps;
pub const actor_platform_first_object = ambient_npc_first_object + 2;
pub const cutscene_npc_object = actor_platform_first_object;

pub const SceneSlots = struct {
    actor_platform_first_object: usize,
    cutscene_npc_object: usize,
    scene_effect_first_object: usize,
};

pub const scene_slots: SceneSlots = .{
    .actor_platform_first_object = actor_platform_first_object,
    .cutscene_npc_object = cutscene_npc_object,
    .scene_effect_first_object = scene_effect_first_object,
};
