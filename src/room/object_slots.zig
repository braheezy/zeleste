const gba = @import("gba");
const cutscene_dialogue = @import("../cutscene/dialogue.zig");
const obj_oam = @import("../core/obj_oam.zig");
const dynamic_object_slots = @import("dynamic_object_slots.zig");
const foreground_stamps = @import("foreground_stamps.zig");

const ObjectSlotRange = obj_oam.ObjectSlotRange;
const range = ObjectSlotRange.init;

pub const cutscene_dialogue_slots = range("cutscene dialogue", dynamic_object_slots.first_object, cutscene_dialogue.object_count);
pub const scene_effect_slots = range("scene effects", cutscene_dialogue_slots.end(), 3);
pub const cutscene_dialogue_first_object = cutscene_dialogue_slots.baseSlot();
pub const scene_effect_first_object = scene_effect_slots.baseSlot();

pub const ambient_npc_first_object = foreground_stamps.behind_first_object + foreground_stamps.max_stamps;
pub const ambient_npc_object_count = 8;
pub const actor_platform_first_object = ambient_npc_first_object + 2;
pub const cutscene_npc_object = actor_platform_first_object;

pub const SceneSlots = struct {
    actor_platform_first_object: usize,
    cutscene_npc_object: usize,
    scene_effect_slots: ObjectSlotRange,
};

pub const scene_slots: SceneSlots = .{
    .actor_platform_first_object = actor_platform_first_object,
    .cutscene_npc_object = cutscene_npc_object,
    .scene_effect_slots = scene_effect_slots,
};

const cutscene_scene_ranges = [_]ObjectSlotRange{
    cutscene_dialogue_slots,
    scene_effect_slots,
};

// These slots intentionally overlap dynamic gameplay and foreground-behind
// layouts, which are inactive while cutscene scene effects own this layout.
comptime {
    gba.display.checkNoObjectSlotOverlap("cutscene scene", &cutscene_scene_ranges);
}
