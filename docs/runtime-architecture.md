# Runtime Architecture Notes

The runtime is currently a single-file prototype in `src/main.zig`. This file
summarizes the boundaries that already exist inside that file so future module
splits do not accidentally change gameplay.

## Main Loop Shape

Startup:

1. load current room background;
2. load room falling blocks and foreground stamps;
3. load object sprite tiles and palettes;
4. load wind snow tiles;
5. load room parallax;
6. create player from the room spawn;
7. initialize camera and wind snow for that camera;
8. draw initial frame.

Per-frame normal gameplay:

1. poll input;
2. update player;
3. update falling blocks;
4. update hair;
5. update dust;
6. compute next camera;
7. update wind snow against that camera;
8. advance global foreground animation counter;
9. check death;
10. check room transition;
11. VBlank;
12. apply camera and draw objects.

Death and room transitions temporarily disable BG0/OBJ, load the next room or
respawn state, redraw, then re-enable display. This avoids showing the player
over stale room art.

## Data Sources

`generated_rooms.zig` is produced by `tools/build_level_assets.py` and exposes
the room graph and per-room binary blobs. Runtime room fields include:

- dimensions and tile counts;
- authored world origin (`world_x`, `world_y`) for transition alignment;
- background tiles/map/palette;
- collision bytes;
- one-way platform bytes;
- spawn and directional respawn points;
- exits;
- falling block data;
- foreground stamp data;
- optional parallax object data;
- wind snow config.

## Collision Model

Player body is currently `8x16` pixels. Player art is a `32x32` sprite with
draw offsets:

- `player_draw_offset_x = -12`
- `player_draw_offset_y = -16`

Static collision:

- `solidRectAt` checks 8x8 collision tiles.
- Horizontal room bounds are solid.
- Below the room is empty so death pits work.
- Above the room is empty so upward transitions can work.

Dynamic collision:

- Falling blocks participate through `dynamicSolidRectAt`.
- Player can stand on and wall-grab dynamic blocks once they are active.

One-way collision:

- One-way platforms are checked on downward movement through
  `oneWayPlatformTopForPlayer`.
- They are authored in the collision editor separately from full solid tiles.

## Player Movement Guardrails

Avoid large movement refactors without focused testing. Fragile areas:

- `tryClimbLedge` must not search far enough to land inside hollow/concave
  annotated shapes. It currently searches only just over the wall face.
- `updateClimbLedgeMotion` is collision-aware because raw interpolation can
  tunnel into solids.
- `resolvePlayerEmbedding` is a last-resort guard, not a replacement for
  correct sweep/collision logic.
- Room side transitions call `settlePlayerOnFloorAfterSideEntry` to avoid
  falling through a connected floor after a screen swap.
- Side transitions preserve player world-space Y by converting through room
  `world_y` origins from `room.json`. Use this for vertically staggered rooms
  like prologue `1 -> 2`; do not special-case individual room IDs in runtime.
- Respawn points are only for death. Screen transitions preserve continuity.

## Rendering Layers

Background:

- BG0 is the current room tilemap.
- Room backgrounds are packed as 8bpp tiles plus logical maps.
- `applyCamera` keeps full BG scroll and streams logical map entries into the
  wrapped 64x32 hardware BG map only when the camera crosses tile boundaries.
  This supports rooms wider than the hardware map, such as the 992px-wide
  prologue room `3`, without rewriting the full map every frame.

Objects:

- Player body, hair, falling blocks, grass, parallax chunks, dust, sweat, and
  wind snow are OBJs.
- Parallax/foreground occlusion chunks are drawn with high visual priority and
  can appear in front of the player.
- Foreground grass stamps can be behind or occluding based on annotation flags.

Palettes:

- Player uses OBJ palette bank 0.
- Falling block bank 1.
- Hair bank 2.
- Dust and wind snow share bank 3.
- Sweat bank 4.
- Parallax bank 5.
- Grass banks 6 and 7 for `grass1` and `grass2`.

BG tile graphics must not overlap the BG screenblocks. The current BG map base
is screenblock 29, leaving room for 928 unique 8bpp BG tiles.

Player tired flashing is palette-based. `drawPlayer` rewrites OBJ palette bank
0 to either the normal player palette or a red-tinted version.

## Room State

Some entity state is global across room visits within the current level. The
falling ice block in room `0` stays down after it falls, even after room
transitions and deaths. Keep this distinction clear:

- room asset data is reloaded from generated blobs;
- persistent entity state records gameplay consequences that should survive
  room reloads.

This will eventually need a cleaner session/level state module.
