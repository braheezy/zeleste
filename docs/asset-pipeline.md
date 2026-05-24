# Asset Pipeline Notes

This project uses source PNGs and editor annotations, then generates runtime
binary blobs for the ROM. Do not hand-edit generated binaries.

## Common Commands

- `zig build`: compile ROM only.
- `zig build assets`: regenerate `src/generated/**` and
  `src/generated_rooms.zig`.
- `zig build run`: compile and open the ROM in mGBA.
- `task collision`: open the collision/entity/foreground stamp editor.
- `task hair`: open the player hair anchor editor.
- `task grass-sway -- <path>`: generate grass sway frames and GIF previews.
- `task grass-edit`: open generated grass frame editor.

## Source Asset Layout

Room source:

- `assets/rooms/prologue_a/room.json`: room graph and per-room metadata.
- `assets/rooms/prologue_a/*.png`: source room images.
- `assets/rooms/prologue_a/*_annotations.json`: source annotation data saved
  by the collision editor.
- `assets/rooms/prologue_a/0-plx.png`: room `0` parallax/foreground occlusion.
- `assets/rooms/prologue_a/prologue-a-block1.png`: falling ice block entity
  source art.

Player source:

- `assets/Animations/player/<animation>/`: individual player animation frames.
- `hair_anchors.json` beside animation frames: per-frame hair root anchor and
  facing metadata.
- Current annotated player animations include `idle`, `idleA`, `idleB`,
  `idleC`, `runSlow`, and `jumpSlow`.

Hair source:

- `assets/Animations/hair/`: small hair root/tile pieces.
- Runtime currently uses `root1` for the scalp/front root and generates the
  rest procedurally.

Foreground source:

- `assets/Animations/foreground/grassN.png`: authored base grass stamps.
- `assets/Animations/foreground/grassN_generated/`: generated sway frames.
- `assets/Animations/foreground/grassN_generated_mirror/`: generated mirrored
  sway frames.

## Level Build Flow

`zig build assets` calls `tools/build_level_assets.py` with
`assets/rooms/prologue_a/room.json`.

For each room, it calls `tools/build_room_bundle.py`, which:

- converts the room PNG through `convert_room_tilemap_8bpp.py`;
- validates reconstructed tilemap output against the indexed source image;
- reads annotation JSON beside the room image;
- writes collision and one-way platform data;
- writes spawn/respawn data;
- writes falling block data;
- writes foreground stamp data;
- writes a room summary.

Then `build_level_assets.py` writes `src/generated_rooms.zig`, which embeds all
room output paths and graph metadata.

## Collision Editor UX

Use `task collision`. The editor discovers room PNGs and annotations from the
room source folders.

Author these in the editor:

- solid collision tiles;
- one-way platforms;
- respawn points;
- falling block rectangle and target;
- foreground grass stamps, including flip and occlusion flags.

Saved annotation JSON should live beside the room image. Avoid saving through
browser downloads.

Current annotation model:

- collision tiles are gameplay collision, not necessarily foreground art;
- respawn points are candidates used after death;
- transition placement is calculated from room exits and current player
  position, not from respawn points.

## Foreground Grass Pipeline

The project experimented with PixiEditor animations and generated sway. The
runtime currently only loads and draws `grass1` and `grass2`.

Generated grass assumptions:

- 42 frames per sway half-cycle source set;
- runtime ping-pongs those frames through `foregroundStampFrame`;
- mirrored folders are generated as separate frame sequences;
- `sway.json` may include crop offsets used by the room builder.

Adding a new grass family requires all of these:

1. source `grassN.png`;
2. generated frames with `task grass-sway`;
3. packed OBJ output from `zig build assets`;
4. room bundle stamp-kind mapping;
5. runtime tile/palette embed, load, and draw logic in `src/main.zig`.

Do not assume accepting `grass3` in annotation JSON means the runtime will draw
it. It currently skips unsupported kinds.

## Player Animation Pipeline

Player animation packing is handled by `tools/pack_player_animations.py`.

Important behavior:

- it packs selected animation folders into one frame order;
- it emits player OBJ tiles and palette;
- it emits `madeline_hair_anchors.bin` in the same packed-frame order;
- runtime animation constants in `src/main.zig` must match the packed order.

Hair anchor workflow:

1. run `task hair`;
2. choose an animation directory;
3. place the hair root anchor and direction per frame;
4. save `hair_anchors.json`;
5. run `zig build assets`;
6. compile/run.

## Room Art Strategy

Current room PNGs are full captured/reduced room images. The pipeline dedupes
8x8 tiles for BG0, so a direct full-room tilemap can work for the prototype.

Interactive or animated foreground elements should be removed from the room PNG
and represented separately when they need to move, occlude, or collide:

- falling ice block is separate entity art;
- parallax/foreground occlusion uses `0-plx.png`;
- swaying grass should become foreground stamp OBJs.

If an object is baked into the background and later moves, it will leave a
visual hole unless the background has been painted clean behind it.

