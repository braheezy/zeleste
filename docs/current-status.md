# Current Status

This file is the handoff snapshot for the current prototype. Read it before
changing gameplay, assets, or room tooling.

## Project State

- The project builds a GBA ROM with ZigGBA from `src/main.zig`.
- `src/main.zig` is now a thin root wrapper. `src/runtime.zig` is now a thin
  runtime loop for startup, death/respawn timers, normal per-frame ordering,
  and camera-shake composition; shared room-data contracts, fixed-point/math
  helpers, asset embeds, audio init, debug FPS overlay, frame sync, OBJ
  helpers, runtime RNG, camera helpers, collision helpers, player movement,
  player collision context, chapter/end-level flow, player state/constants,
  video constants, and BG/parallax streaming have been split into
  `src/runtime/`.
- `src/runtime/chapter_flow.zig` owns current chapter/session flow: gameplay
  room load/display hiding helpers, bridge-ending hold and dash unlock state,
  prologue end-level transition timing, dummy overworld handoff, and chapter 1
  city entry from the placeholder overworld.
- `src/runtime/frame.zig` owns shared frame sync: maxmod frame hook, VBlank
  wait, and optional debug FPS update.
- `src/runtime/player_controller.zig` owns the player movement controller:
  input timers, run/jump/wall/climb/dash update order, dash start/end movement,
  climb ledge motion, animation selection, and the post-collision footstep
  update call.
- `src/runtime/player_collision.zig` owns player-sized collision context:
  static-plus-dynamic solid probes, one-way platform top checks, wall/floor
  probes, horizontal/vertical sweeps, and embedding resolution.
- `src/runtime/hair.zig` owns player hair simulation/rendering, including
  palette changes, runtime-generated hair tiles, bang tiles, and hair OBJ
  drawing.
- `src/runtime/player_render.zig` owns player body sprite frame loading,
  normal/tired palette updates, sweat frame loading, sweat animation, and
  player/sweat OBJ drawing.
- `src/runtime/player_death_vfx.zig` owns player death and respawn VFX:
  generated burst tiles, fixed OAM slots, death-intro sprite drawing,
  burst/ring drawing, and hide behavior.
- `src/runtime/player_death.zig` owns player death/respawn flow state:
  death-origin tracking, death-intro animation selection, centered death-intro
  offset calculation, respawn-burst origin, player/cutscene cleanup hooks, and
  calls into `src/runtime/player_death_vfx.zig` for drawing.
- `src/runtime/dash_effects.zig` owns dash afterimage/burst state, generated
  dash burst tiles, dash VFX palettes, and dash VFX OBJ drawing.
- `src/runtime/dust.zig` owns jump, landing, wall-slide, and snow puff
  particles, including palette colors, generated tiles, update, clear, and draw
  behavior.
- `src/runtime/falling_blocks.zig` owns the falling ice block system: per-room
  block loading, persistent landed state, dynamic solid/crush collision,
  graphics loading, OBJ drawing, and snow-impact events returned to the
  particle owner.
- `src/runtime/footsteps.zig` owns footstep SFX and terrain surface
  classification: sample rotation, active footstep handle management, dynamic
  floor-provider priority, one-way wood checks, background-pixel surface
  classification, cadence, and volume.
- `src/runtime/foreground_stamps.zig` owns foreground grass stamp loading,
  graphics loading, behind/occluding OBJ drawing, and the object-slot count used
  by room wires when they share spare slots.
- `src/runtime/funny_cars.zig` owns the funny car platform actor: generic-stamp
  loading, bounce state, graphics loading, OBJ drawing, car footstep/floor
  probes, and one-way platform top queries.
- `src/runtime/gameplay_scene.zig` owns gameplay scene draw ordering and shared
  scene-effect hooks: per-lifecycle draw order, shared OBJ sprite loading/cache
  invalidation, wind/snow scene hooks, chimney-smoke scene hooks, player object
  hiding, and object-slot constants shared by room systems.
- `src/runtime/bird_npc.zig` owns the prologue bird NPC/tutorial prompt actor:
  room data loading, state updates, hint tile/palette streaming, OBJ drawing,
  cache invalidation, and the bridge-ending dash prompt fly-in.
- `src/runtime/granny_npc.zig` owns Granny NPC sprite rendering: animation
  frame caches, palette loading, fixed draw offsets, OBJ drawing, and hide
  behavior.
- `src/runtime/prologue_granny_cutscene.zig` owns the prologue Granny authored
  cutscene: trigger/progress state, player cutscene locking, dialogue
  page/reveal state, dialogue overlay calls, laugh-text lifetime, Granny NPC
  pose/facing selection, room palette mood, cutscene camera shake, and
  death/room-transition cleanup hooks.
- `src/runtime/prologue_bridge.zig` owns the prologue bridge/end-platform room
  system: bridge asset loading, chunk collapse state, bridge OBJ drawing,
  ending-hold trigger state, dynamic bridge solids, bridge floor probes, dark
  bridge palette writes, collapse camera shake, and bridge snow side effects.
- `src/runtime/overworld_placeholder.zig` owns the dummy overworld screen
  loader: placeholder asset embeds, map copy, display cut-to-black, BG scroll
  reset, and placeholder BG0 enable path before entering the chapter 1 city
  stub.
- `src/runtime/room_systems.zig` owns the room lifecycle/update facade: room
  system loading, transient effect clearing, cutscene updates, dynamic hazard
  updates and snow side effects, room actor/effect updates, static room hazard
  checks, and the shared foreground animation counter.
- `src/runtime/room_transition.zig` owns room transition and spawn helpers:
  player spawn construction, left/right/up/down room switching, directional
  respawn selection, room-entry cooldown, cross-room world alignment, side-entry
  floor matching, and room-entry fit/snap logic.
- `src/runtime/room_wires.zig` owns the OBJ fallback path for room wires,
  including per-room wire tile uploads and shared object-slot allocation.
- `src/runtime/wind_snow.zig` owns room wind/snow environmental particles,
  generated snowflake OBJ tiles, drawing, and the fixed OAM/tile budget. The
  runtime passes prologue-specific suppression and particle-limit flags.
- `src/runtime/chimney_smoke.zig` owns the procedural smoke OBJ effect used by
  the prologue Granny room: generated tiles, palette color, update cadence,
  drawing, reset, and hide behavior.
- `src/runtime/cutscene_dialogue.zig` owns the reusable cutscene dialogue box
  renderer: 6x3 OBJ layout, generated tile buffer, render cache, name-color
  rules, box/text pixel drawing, palette bank, and show/hide behavior.
- `src/runtime/cutscene_laugh_text.zig` owns the floating `HAHA` cutscene VFX:
  tile upload/cache, fixed object budget, particle state, update cadence,
  camera-follow retargeting, OBJ drawing, and hide/stop behavior.
- `src/runtime/tiny_birds.zig` owns the tiny bird flock actor in room `0b`,
  including persistent flown state, trigger/update behavior, palette/tile
  uploads, OBJ drawing, and hide behavior.
- `src/runtime/text.zig` owns reusable cutscene text helpers: string matching,
  word wrapping, typewriter reveal advancement, and bitmap font drawing through
  a caller-supplied pixel writer.
- `zig build` compiles the ROM without regenerating assets.
- `zig build assets` regenerates source-generated assets under
  `src/generated/**` and `src/generated_rooms.zig`.
- `zig build run` builds and opens mGBA.
- Remaining code in `src/runtime.zig` is primarily the top-level frame order,
  death/respawn timers, and camera-shake composition. Further splits should be
  tactical and should not combine movement/collision tuning with module
  extraction.

## Current Playable Slice

The active level is `assets/chapters/prologue_a/room.json`.

Rooms currently in the graph:

- `-1.png`, connected right to `0`.
- `0.png`, connected left to `-1`, right to `1`, up to `0b`.
- `0b.png`, connected down to `0`.
- `1.png`, connected left to `0`, right to `2`.
- `2.png`, connected left to `1`, right to `3`, with Granny cutscene data.
- `3.png`, connected left to `2`, with the bridge/end-level transition.
- `../1_city/1.png` is generated as `city_1` for the current chapter 1 stub
  and is reachable from the placeholder overworld flow or `zig build -- 1 1`.

Each room has a same-named annotation JSON beside the PNG. The annotation file
is source data for collision, one-way platforms, respawn points, foreground
stamps, and lightweight entities. Chapter-specific reference art lives beside
those room sources under `assets/chapters/prologue_a/backgrounds/`.

## Runtime Features Implemented

- BG0 scrolling 8bpp tile background per room.
- Room backgrounds are generated as logical maps and incrementally streamed
  into a wrapped 64x32 hardware BG map, so rooms can exceed 512px in width.
  That streaming code now lives in `src/runtime/background.zig`.
- 4bpp OBJ player sprite from packed Madeline animation PNGs.
- Runtime procedural hair:
  - bald body animation frames are packed as the player sprite;
  - per-frame anchors come from `hair_anchors.json`;
  - `root1` hair tile is drawn as an OBJ;
  - trailing hair is generated into a 16x16 OBJ tile each frame.
- Movement:
  - implemented in `src/runtime/player_controller.zig`;
  - fixed-point position and velocity;
  - run acceleration and air control;
  - jump, variable jump, coyote time, jump buffering;
  - wall slide and wall jump;
  - wall grab, climb up/down, climb ledge hop, climb jump;
  - gated dash movement used by the bridge-ending handoff;
  - stamina, tired threshold, exhaustion, and tired red palette flash.
- Audio:
  - footstep SFX are selected from dynamic floor providers, one-way platforms,
    and background-pixel terrain classification in `src/runtime/footsteps.zig`.
- Collision:
  - 8x8 solid tiles from annotations;
  - 8x4-style one-way platform annotations, packed as one-way tile data;
  - oriented spike tiles from annotations that kill the player on touch;
  - reusable static collision helpers in `src/runtime/collision.zig`;
  - player-sized collision probes/sweeps in
    `src/runtime/player_collision.zig`;
  - reusable dynamic collision for falling blocks in
    `src/runtime/falling_blocks.zig`.
- Room transitions:
  - left/right/up/down graph transitions;
  - black one-frame transition while loading new room data;
  - side transitions preserve visual position and settle onto connected floor;
  - respawn points are used only for deaths, not for transitions.
- Chapter/end-level flow:
  - bridge-ending hold and dash unlock state live in
    `src/runtime/chapter_flow.zig`;
  - the prologue end-level walk/camera/black/overworld phases live in
    `src/runtime/chapter_flow.zig`;
  - the placeholder overworld can enter the generated chapter 1 city stub.
- Death:
  - current death zones are pits when a room has no downward exit;
  - death removes player, blacks out, reloads room, and respawns at the current
    chosen respawn point.
- Entities and effects:
  - falling ice block in room `0`, with persistent per-system room state after
    it has fallen;
  - funny car platform actors loaded from generic stamps;
  - bird NPC tutorial prompts and bridge-ending dash prompt fly-in;
  - tiny bird flock in room `0b`, with persistent per-system flown state;
  - Granny cutscene/dialogue/laugh text in room `2`, scripted by
    `src/runtime/prologue_granny_cutscene.zig`;
  - collapsing prologue bridge and dummy overworld transition from room `3`,
    with bridge runtime state in `src/runtime/prologue_bridge.zig`;
  - loose snow particles when the block starts falling;
  - jump and landing dust puffs;
  - wind snow particles, per-room configurable in `room.json`;
  - parallax/foreground occlusion image for room `0`;
  - foreground grass stamps for `grass1` and `grass2` through
    `src/runtime/foreground_stamps.zig`.
- Room lifecycle/update/draw paths are centralized behind
  `src/runtime/room_systems.zig`, `src/runtime/gameplay_scene.zig`, and the
  frame loop in `src/runtime.zig`: room system loading, room cutscenes, dynamic
  hazards, room actors, room effects, static lethal hazards, chapter flow, and
  per-path scene draws.
  Future chapter cutscenes and moving lethal foreground systems should plug
  into these hooks before a fuller entity registry exists, using falling blocks
  as the current pattern for reusable dynamic hazards.

## Important Current Limitations

- Runtime foreground stamp drawing only supports `grass1` and `grass2`.
  The editor and builder can accept `grass1` through `grass8`, but unsupported
  kinds are skipped in `src/runtime/foreground_stamps.zig`.
- The grass sway pipeline exists, but generated sway quality is still a taste
  problem. Do not assume the current script is visually final.
- The climb and ledge movement has been tuned by observation, but is not a
  full port of Celeste `Player.cs`.
- Dash exists as gated runtime behavior for the prologue bridge ending, but
  chapter 1 dash rules and tuning are not complete yet.
- A dev FPS overlay exists behind `--dev-hud`; collision/player-state debug
  overlays do not exist yet.
- BG tile graphics still share VRAM with the hardware BG map; with the current
  map base at screenblock 29, each room can use up to 928 unique 8bpp tiles
  before additional tile streaming/compression is needed.
- `PLAN.md` still describes the intended modular architecture. The first splits
  moved the root wrapper, generated-data contracts, math helpers, asset embeds,
  audio init, debug FPS overlay, OAM helpers, RNG, camera helpers, collision
  helpers, player state/constants, reusable player collision context, reusable
  player movement controller, reusable player sprite rendering, reusable hair
  rendering, reusable player death/respawn VFX, dash VFX, reusable falling
  block hazards, reusable footstep SFX/surface classification, reusable
  foreground stamps, reusable room wire OBJ fallback, reusable room transition
  helpers, reusable room lifecycle/update hooks, reusable player death/respawn
  flow state, reusable funny car platform actors, reusable dust/snow puff
  particles, reusable wind/snow particles, reusable chimney smoke, reusable
  bird NPC/tutorial prompt actors, reusable tiny bird flock actors, reusable
  Granny NPC sprite rendering, reusable cutscene dialogue box rendering,
  reusable floating cutscene text VFX, reusable cutscene text helpers, gameplay
  scene drawing/effect hooks, frame sync, dummy overworld placeholder screen
  loading, chapter/end-level flow, prologue Granny cutscene scripting, prologue
  bridge/end-platform runtime state, video constants, BG/parallax streaming,
  and room lifecycle hooks out of the monolithic shape.

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

Collision and movement are sensitive to operation order. Keep changes in
`src/runtime/player_controller.zig` and `src/runtime/player_collision.zig`
small:

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
