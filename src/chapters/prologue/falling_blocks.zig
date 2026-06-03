const impl = @import("../../room/falling_blocks.zig");

pub const max_blocks = impl.max_blocks;
pub const first_object = impl.first_object;
pub const objects_per_block = impl.objects_per_block;
pub const object_capacity = impl.object_capacity;
pub const Block = impl.Block;
pub const UpdateResult = impl.UpdateResult;

pub const loadGraphics = impl.loadGraphics;
pub const load = impl.load;
pub const update = impl.update;
pub const updateDuringDeath = impl.updateDuringDeath;
pub const floorAtPlayer = impl.floorAtPlayer;
pub const floorAt = impl.floorAt;
pub const solidRectAt = impl.solidRectAt;
pub const draw = impl.draw;
pub const hideObjects = impl.hideObjects;
pub const usedObjectCount = impl.usedObjectCount;
