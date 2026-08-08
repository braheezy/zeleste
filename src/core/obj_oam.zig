const gba = @import("gba");

pub const ObjectSlotRange = gba.display.ObjectSlotRange;
const range = ObjectSlotRange.init;

// Stable shared-gameplay layout. Other phases intentionally reuse some of
// these slots and should be validated in separate overlap groups.
pub const dash_effects = range("dash effects", 0, 4);
pub const save_indicator = range("save indicator", 4, 4);
pub const foreground_occluding = range("foreground occluding stamps", 8, 24);
pub const player_body_hair = range("player body and hair", 32, 3);
pub const dust = range("dust", 35, 8);
pub const wind_snow = range("wind and snow", 43, 21);
pub const springs = range("springs", 64, 7);
pub const player_sweat = range("player sweat", 71, 1);
pub const dynamic_room_actors = range("dynamic room actors", 72, 24);
pub const foreground_behind = range("foreground behind stamps", 96, 24);

const shared_gameplay_ranges = [_]ObjectSlotRange{
    dash_effects,
    save_indicator,
    foreground_occluding,
    player_body_hair,
    dust,
    wind_snow,
    springs,
    player_sweat,
    dynamic_room_actors,
    foreground_behind,
};

comptime {
    gba.display.checkNoObjectSlotOverlap("shared gameplay", &shared_gameplay_ranges);
}
