const gba = @import("gba");
const camera_mod = @import("../../camera.zig");
const level = @import("../../../generated_rooms.zig");
const player_mod = @import("../../player.zig");

const bird_npc = @import("bird_npc.zig");
const bridge = @import("bridge.zig");
const funny_cars = @import("funny_cars.zig");
const granny_cutscene = @import("granny_cutscene.zig");
const room_wires = @import("room_wires.zig");
const tiny_birds = @import("tiny_birds.zig");

pub const ObjectSlots = struct {
    funny_car_first_object: usize,
};

const Camera = camera_mod.Camera;
const Player = player_mod.State;

const rooms = level.rooms;
const prologue_end_room_index = level.roomIndexFor(level.chapter_index, "3") orelse rooms.len;

pub fn loadBeforeObjectSprites(room_index: usize, slots: ObjectSlots) void {
    funny_cars.load(room_index, slots.funny_car_first_object);
}

pub fn loadAfterObjectSprites(room_index: usize, reset_cutscenes: bool) void {
    bridge.load(room_index, isPrologueEndRoom(room_index));
    bird_npc.load(room_index);
    tiny_birds.load(room_index);
    room_wires.load(room_index, bridge.active());
    if (reset_cutscenes) {
        granny_cutscene.resetOnRoomLoad();
    }
}

pub fn updateCutscenes(player: *Player, input: gba.input.BufferedKeysState, room_index: usize) bool {
    return granny_cutscene.update(player, input, room_index);
}

pub fn updateCutsceneEffects(room_index: usize, camera: Camera) void {
    granny_cutscene.updateEffects(room_index, camera);
}

pub fn updateActors(player: *Player, room_index: usize, camera: Camera, anim_counter: u16) void {
    bridge.update(player, isPrologueEndRoom(room_index));
    bridge.updateCollapseShake(isPrologueEndRoom(room_index), player.grounded);
    funny_cars.update(player.*);
    bird_npc.update(player.*, camera);
    tiny_birds.update(player.*, room_index, anim_counter);
}

pub fn actorFloorAt(player_x: i16, player_y: i16) bool {
    return funny_cars.floorAt(player_x, player_y);
}

pub fn actorTopForPlayer(player_x: i16, old_bottom: i16, next_bottom: i16) ?i16 {
    return funny_cars.topForPlayer(player_x, old_bottom, next_bottom);
}

pub fn releaseActorAtPlayer(player: Player) void {
    funny_cars.releaseAtPlayer(player);
}

pub fn triggerActorBounceAtPlayer(player: Player) void {
    funny_cars.triggerBounceAtPlayer(player);
}

pub fn asphaltFloorAtPlayer(player: Player) bool {
    return bridge.floorAtPlayer(player);
}

pub fn dynamicSolidRectAt(x: i16, y: i16, width: i16, height: i16) bool {
    return bridge.solidRectAt(x, y, width, height);
}

pub fn endingHairOverrideActive() bool {
    return bridge.endingHoldActive();
}

fn isPrologueEndRoom(room_index: usize) bool {
    return room_index == prologue_end_room_index;
}
