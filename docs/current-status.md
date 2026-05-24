# Current Status

This file is the handoff snapshot for the current prototype. Read it before
changing gameplay, assets, or room tooling.

## Project State

- The project builds a GBA ROM with ZigGBA from `src/main.zig`.
- `zig build` compiles the ROM without regenerating assets.
- `zig build assets` regenerates source-generated assets under
  `src/generated/**` and `src/generated_rooms.zig`.
- `zig build run` builds and opens mGBA.
- Most gameplay is still in one large prototype file, `src/main.zig`. This is
  intentional for now; do not do a broad module split while also changing
  movement behavior.

## Current Playable Slice

The active level is `assets/chapters/prologue_a/room.json`.

Rooms currently in the graph:

- `-1.png`, connected right to `0`.
- `0.png`, connected left to `-1`, right to `1`, up to `0b`.
- `0b.png`, connected down to `0`.
- `1.png`, connected left to `0`.

Each room has a same-named annotation JSON beside the PNG. The annotation file
is source data for collision, one-way platforms, respawn points, foreground
stamps, and lightweight entities. Chapter-specific reference art lives beside
those room sources under `assets/chapters/prologue_a/backgrounds/`.

## Runtime Features Implemented

- BG0 scrolling 8bpp tile background per room.
- Room backgrounds are generated as logical maps and incrementally streamed
  into a wrapped 64x32 hardware BG map, so rooms can exceed 512px in width.
- 4bpp OBJ player sprite from packed Madeline animation PNGs.
- Runtime procedural hair:
  - bald body animation frames are packed as the player sprite;
  - per-frame anchors come from `hair_anchors.json`;
  - `root1` hair tile is drawn as an OBJ;
  - trailing hair is generated into a 16x16 OBJ tile each frame.
- Movement:
  - fixed-point position and velocity;
  - run acceleration and air control;
  - jump, variable jump, coyote time, jump buffering;
  - wall slide and wall jump;
  - wall grab, climb up/down, climb ledge hop, climb jump;
  - stamina, tired threshold, exhaustion, and tired red palette flash.
- Collision:
  - 8x8 solid tiles from annotations;
  - 8x4-style one-way platform annotations, packed as one-way tile data;
  - dynamic collision for falling blocks.
- Room transitions:
  - left/right/up/down graph transitions;
  - black one-frame transition while loading new room data;
  - side transitions preserve visual position and settle onto connected floor;
  - respawn points are used only for deaths, not for transitions.
- Death:
  - current death zones are pits when a room has no downward exit;
  - death removes player, blacks out, reloads room, and respawns at the current
    chosen respawn point.
- Entities and effects:
  - falling ice block in room `0`, with persistent global room state after it
    has fallen;
  - loose snow particles when the block starts falling;
  - jump and landing dust puffs;
  - wind snow particles, per-room configurable in `room.json`;
  - parallax/foreground occlusion image for room `0`;
  - foreground grass stamps for `grass1` and `grass2`.

## Important Current Limitations

- Runtime foreground stamp drawing only supports `grass1` and `grass2`.
  The editor and builder can accept `grass1` through `grass8`, but unsupported
  kinds are skipped in `src/main.zig`.
- The grass sway pipeline exists, but generated sway quality is still a taste
  problem. Do not assume the current script is visually final.
- The climb and ledge movement has been tuned by observation, but is not a
  full port of Celeste `Player.cs`.
- Dash is not implemented yet.
- Debug overlays do not exist yet.
- BG tile graphics still share VRAM with the hardware BG map; with the current
  map base at screenblock 29, each room can use up to 928 unique 8bpp tiles
  before additional tile streaming/compression is needed.
- `PLAN.md` still describes the intended modular architecture. The prototype
  has not been split into those modules.

## Movement Notes

Stamina currently uses Celeste's 110-point max scaled by 60:

- max stamina: `6600`
- tired threshold: `1200`
- holding still while grabbing: `10` per frame
- climbing up: `45` per frame
- climb jump: `1650`
- sliding down while grabbing does not drain stamina

Tired behavior:

- tired starts at or below threshold;
- a tired player cannot begin a new grab;
- a player already grabbing can keep holding and climbing until stamina reaches
  zero;
- at zero stamina, grab is dropped;
- low stamina flashes player palette red, faster as stamina approaches zero.

Collision and movement are sensitive to operation order. Keep changes small:

1. input timers;
2. coyote/stamina refresh;
3. horizontal speed;
4. jump or wall/climb jump;
5. climb update;
6. vertical speed if not climbing;
7. horizontal move;
8. vertical move;
9. embedding guard;
10. grounded/dust/animation updates.

## Known Reference Sources

- `../Celeste/Source/Player/Player.cs`: primary source for movement constants
  and behavior.
- `../Celeste/Source/PICO-8/Classic.cs`: compact Celeste Classic reference.
- `../CelesteNES`: demake reference for visual compromise and level structure.
- `../Celeste-For-GBA`: GBA-specific reference, but do not port its framework.
- `~/personal/gba/ziggba`: SDK and build helper reference.
