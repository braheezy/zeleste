# Runtime Architecture Notes

The runtime is no longer rooted directly in a 7k-line `src/main.zig`.
`src/main.zig` is a small GBA root wrapper that owns the header/exported entry
point and re-exports generated-data contracts required by `src/generated_rooms.zig`.

Current hand-written runtime modules:

- `src/runtime.zig`: thin runtime loop that owns startup, death/respawn timers,
  normal per-frame ordering, camera-shake composition, and high-level calls into
  focused runtime modules.
- `src/runtime/assets.zig`: generated ROM asset embed catalog. Runtime code
  keeps aligned local aliases where existing VRAM/palette casts require them.
- `src/runtime/audio.zig`: maxmod soundbank initialization and VBlank mixer
  hook. Gameplay SFX triggers still live near their current callers.
- `src/runtime/background.zig`: BG0 room map streaming, BG1 parallax streaming,
  static wire stamping into spare BG tile space, and wrapped hardware-map
  helpers.
- `src/runtime/camera.zig`: camera value type and basic player-follow camera
  calculations.
- `src/runtime/chapters/prologue.zig`: prologue chapter facade. Root runtime
  systems import this facade when they need prologue-owned bridge, bird, Granny,
  chimney-smoke, funny-car, room-wire, laugh-text, tiny-bird, or prologue flow
  behavior.
- `src/runtime/chapters/systems.zig`: active chapter system adapter. Shared
  movement, collision, footstep, and room lifecycle code call this switch
  instead of importing chapter files directly; it currently routes the generated
  chapter `0` runtime to prologue systems.
- `src/runtime/chapters/prologue/systems.zig`: prologue room-system hook owner.
  It loads and updates prologue-only room actors, cutscenes, dynamic bridge
  solids, actor-backed one-way platform probes, and bridge footstep/hair state.
- `src/runtime/chapters/prologue/flow.zig`: prologue chapter/session flow
  owner. It owns gameplay room load/display hiding helpers, bridge-ending hold
  and dash unlock state, prologue end-level transition timing, dummy overworld
  handoff, and the chapter 1 city entry path from the placeholder overworld.
- `src/runtime/chapters/prologue/bridge.zig`: prologue bridge/end-platform room
  system. It owns bridge asset loading, chunk collapse state, bridge OBJ
  drawing, ending-hold trigger state, dynamic bridge solids, bridge floor
  probes, dark bridge palette writes, collapse camera shake, and bridge snow
  side effects.
- `src/runtime/chapters/prologue/granny_cutscene.zig`: prologue Granny cutscene
  script. It owns trigger/progress state, player cutscene locking, dialogue
  page/reveal state, dialogue overlay calls, laugh-text lifetime, Granny NPC
  pose/facing selection, room palette mood, cutscene camera shake, and
  death/room-transition cleanup hooks.
- `src/runtime/chapters/prologue/granny_npc.zig`: prologue Granny NPC sprite
  renderer. It owns Granny animation frame caches, palette loading, OBJ
  draw/hide behavior, and fixed sprite offsets while the Granny cutscene chooses
  animation and facing.
- `src/runtime/chapters/prologue/laugh_text.zig`: prologue `HAHA` cutscene VFX.
  It owns the tile upload/cache, fixed object budget, particle state, update
  cadence, camera-follow retarget, draw/hide behavior, and simple start/update/
  draw/stop hooks.
- `src/runtime/chapters/prologue/bird_npc.zig`: prologue bird NPC/tutorial
  prompt actor. It owns per-room bird data loading, the bird state machine, hint
  tile/palette streaming, OBJ drawing/hiding, cache invalidation, and the
  bridge-ending dash-prompt fly-in API.
- `src/runtime/chapters/prologue/tiny_birds.zig`: prologue tiny bird flock
  actor in room `0b`. It owns flock loading, persistent flown state,
  trigger/update behavior, palette/tile uploads, OBJ drawing, and hide behavior.
- `src/runtime/chapters/prologue/chimney_smoke.zig`: prologue Granny-room
  procedural 16x16 OBJ smoke effect. It owns the generated smoke tiles, palette
  color, active-room/origin constants, counter/update cadence, OBJ drawing, and
  hide/reset helpers.
- `src/runtime/chapters/prologue/funny_cars.zig`: prologue funny-car platform
  actor. It owns generic-stamp loading, car state, graphics/palette loading,
  bounce update, car footstep/floor probes, one-way top queries, and OBJ
  drawing.
- `src/runtime/chapters/prologue/room_wires.zig`: prologue OBJ wire fallback.
  It draws generated room wires only when static BG stamping is not possible,
  and borrows unused falling-block and behind-stamp object slots.
- `src/runtime/collision.zig`: reusable static collision geometry helpers for
  solids, spikes, jump-through platforms, and rectangle overlap.
- `src/runtime/cutscene_dialogue.zig`: reusable cutscene dialogue box renderer.
  It owns the 6x3 OBJ box layout, generated 4bpp tile buffer, dialogue render
  cache, name-color rules, box/text pixel drawing, palette bank, and object
  show/hide behavior. Cutscene scripts still choose pages, reveal offsets, and
  placement.
- `src/runtime/dash_effects.zig`: dash afterimage/burst state, generated dash
  burst tile graphics, dash VFX palettes, and dash VFX OBJ drawing.
- `src/runtime/debug_fps.zig`: optional `--dev-hud` FPS object overlay.
- `src/runtime/dust.zig`: reusable dust/snow puff particle system. It owns the
  shared particle OBJ palette colors, generated 8x8 particle tiles, jump,
  landing, wall-slide, and falling-block snow spawns, particle update, clear,
  and draw behavior.
- `src/runtime/falling_blocks.zig`: reusable falling-block dynamic hazard
  system. It owns per-room loaded block state, persistent landed masks,
  graphics/palette loading, OBJ drawing, dynamic-solid queries, player crush
  checks, and update results that let the caller spawn dust/snow without
  coupling the system to the particle implementation.
- `src/runtime/footsteps.zig`: reusable footstep SFX and surface classifier.
  It owns footstep sample rotation, active footstep handle management, dynamic
  floor-provider priority, one-way wood checks, background-pixel surface
  classification, cadence, and volume.
- `src/runtime/frame.zig`: shared frame sync helper. It runs the maxmod GBA
  frame hook, waits for VBlank, and updates the optional debug FPS overlay.
- `src/runtime/foreground_stamps.zig`: reusable foreground decoration and
  occlusion stamp system. It owns per-room grass stamp loading, OBJ tile/palette
  uploads, behind-player and occluding OBJ drawing, and the behind-stamp object
  count used by prologue room wires when sharing spare object slots.
- `src/runtime/gameplay_scene.zig`: gameplay scene draw-order and scene-effect
  owner. It centralizes per-lifecycle draw ordering, shared OBJ sprite loading
  and cache invalidation, wind/snow scene hooks, prologue chimney-smoke scene
  hooks, player object hiding, and object-slot constants shared by room systems.
- `src/runtime/hair.zig`: player hair simulation, palette state, procedural
  hair tile generation, bang tile generation, and hair OBJ drawing. Callers pass
  chapter/cutscene-specific hair state such as the current ending-hair override.
- `src/runtime/oam.zig`: OBJ coordinate conversion and object hiding helper.
- `src/runtime/overworld_placeholder.zig`: dummy overworld screen loader. It
  owns the placeholder overworld asset embeds, map copy, display cut-to-black,
  BG scroll reset, and placeholder BG0 enable path used before entering the
  chapter 1 city stub.
- `src/runtime/player_death.zig`: player death/respawn flow state. It owns
  death-origin tracking, death-intro animation selection, centered death-intro
  offset calculation, respawn-burst origin, player/cutscene cleanup hooks, and
  calls into `src/runtime/player_death_vfx.zig` for drawing.
- `src/runtime/rng.zig`: shared deterministic runtime random generator.
- `src/runtime/room_data.zig`: room graph, parallax, spawn, scene rectangle, and
  cutscene data contracts, plus little-endian readers used by generated room
  data and runtime loaders.
- `src/runtime/room_systems.zig`: room lifecycle/update facade. It owns shared
  room-system loading, transient effect clearing, reusable dynamic hazard
  updates and snow side effects, static room hazard checks, and the shared
  foreground animation counter. Chapter-specific load/update/collision hooks
  route through `src/runtime/chapters/systems.zig`.
- `src/runtime/room_transition.zig`: room transition and spawn helper. It owns
  player spawn construction, left/right/up/down room switching, directional
  respawn selection, room-entry cooldown, cross-room world alignment, side-entry
  floor matching, and room-entry fit/snap logic.
- `src/runtime/video.zig`: shared screen, screenblock, charblock, and wrapped
  hardware-map dimensions.
- `src/runtime/wind_snow.zig`: reusable room wind/snow environmental effect. It
  owns the generated snowflake OBJ tiles, per-room particle state, update/draw
  logic, and fixed OAM/tile budget. `src/runtime/gameplay_scene.zig` supplies
  chapter-specific suppression/particle-limit flags such as the prologue bridge
  collapse.
- `src/runtime/math.zig`: fixed-point and scalar math helpers.
- `src/runtime/player.zig`: player state type plus player constants/enums.
- `src/runtime/player_collision.zig`: player-sized collision context. It
  combines static room collision with dynamic solids, one-way platform actors,
  wall/floor probes, movement sweeps, and embedding resolution.
- `src/runtime/player_controller.zig`: player movement controller. It owns the
  input-to-state update order, dash start/end movement, climb/ledge motion,
  jump/wall-jump handling, animation selection, and footstep update call.
- `src/runtime/player_death_vfx.zig`: player death and respawn burst renderer.
  It owns generated death-burst tiles, fixed OAM slots, death-intro sprite
  drawing, burst/ring drawing, and hide behavior while runtime chooses death
  cause, timing, and respawn flow.
- `src/runtime/player_render.zig`: player body frame cache, normal/tired
  palette handling, sweat frame cache, sweat animation, and player/sweat OBJ
  drawing. Death-intro code still owns its special trajectory but uses this
  module for palette and frame loading.
- `src/runtime/text.zig`: reusable cutscene/dialogue text helpers, including
  string matching, word wrapping, typewriter reveal advancement, and tiny bitmap
  font drawing through a caller-supplied pixel writer.

This file summarizes the boundaries that exist today so future module splits do
not accidentally change gameplay.

## Main Loop Shape

Startup:

1. `loadGameplayRoom` loads the room background and all room systems;
2. load shared wind/snow tiles and debug HUD resources;
3. create player from the room spawn;
4. initialize camera, wind snow, and chimney smoke for that camera;
5. draw the initial gameplay scene through the shared scene helper.

Per-frame normal gameplay:

1. poll input;
2. let `prologue.flow` consume the frame if an end-level/overworld transition
   is active;
3. update room cutscenes and cutscene-owned effects;
4. update player movement or chapter-flow-owned player hold control;
5. update dynamic room hazards that move during player simulation;
6. update room actors such as bridge, cars, bird NPCs, and tiny birds;
7. update player-attached effects such as hair, dust, and dash trails;
8. compute next camera;
9. update camera-dependent room effects such as wind snow and chimney smoke;
10. check end-level, bridge-hold, and static lethal hazards;
11. check room transition;
12. VBlank through `src/runtime/frame.zig`;
13. apply camera and draw the gameplay scene through the shared scene helper.

Death and room transitions temporarily disable BG0/OBJ, load the next room or
respawn state, redraw, then re-enable display. This avoids showing the player
over stale room art.

## Room System Hooks

The current hook layer lives behind `src/runtime/room_systems.zig`, with
`src/runtime.zig` calling the facade from the frame loop. It is the boundary
future chapters should use before a fuller entity registry exists:

- `loadRoomSystems` loads shared room-owned systems after the BG/palette data
  is loaded, then delegates prologue-only actor/cutscene setup through
  `src/runtime/chapters/systems.zig`. Current shared systems include falling
  blocks, foreground stamps, object sprite uploads, and parallax; current
  prologue systems include funny cars, bridge state, bird NPCs, tiny birds,
  room wires, and Granny cutscene reset.
- `updateRoomCutscenes` and `updateRoomCutsceneEffects` are the cutscene entry
  points. `src/runtime/chapters/prologue/granny_cutscene.zig` is the first
  authored script behind these hooks; additional chapter cutscenes should plug
  in here rather than adding direct branches in the main loop.
- Dialogue box tile/object ownership lives in `src/runtime/cutscene_dialogue.zig`;
  text wrapping, reveal advancement, and bitmap font drawing live in
  `src/runtime/text.zig` and should be reused for future chapter
  dialogue/cutscene UI.
- `updateDynamicRoomHazards` is for moving room systems that can kill or crush
  the player during simulation. Falling blocks use it today and report
  side-effect events back to the runtime; future moving foreground hazards
  should follow that load/update/draw/collision/event shape.
- `updateRoomActors` is for non-player room actors and NPCs. The shared facade
  delegates current prologue actors through `src/runtime/chapters/systems.zig`,
  including bird NPCs, Granny cutscene/NPC integration, funny car platforms,
  tiny bird flocks, and bridge actors.
- Player-owned audio hooks such as `src/runtime/footsteps.zig` run from
  `src/runtime/player_controller.zig` because cadence depends on player state
  after collision. Keep chapter-specific terrain probes behind that module
  boundary.
- `updateRoomEffects` is for camera-dependent environmental effects.
- `playerTouchingRoomHazard` centralizes static lethal checks such as spikes
  and death pits.
- `src/runtime/gameplay_scene.zig` preserves the existing object draw ordering
  for initial gameplay, normal gameplay, loaded rooms, respawn, death, and the
  end-level transition.
- `src/runtime/chapters/prologue/flow.zig` owns the current
  prologue-to-overworld-to-city session handoff. Future chapter end screens or
  overworld nodes should use chapter-local flow modules instead of adding phase
  globals to the frame loop.

This is intentionally a compatibility layer, not a final entity system. The
next refactor should keep turning prologue-specific globals into fixed-size
reusable systems with load/update/draw/hazard hooks while preserving GBA object
and tile budgets.

## Data Sources

`generated_rooms.zig` is produced by `tools/build_level_assets.py` and exposes
the room graph and per-room binary blobs. It still imports `root`, so
`src/main.zig` re-exports the room contracts from `src/runtime/room_data.zig`
until the generator is updated to import the contract module directly. Runtime
room fields include:

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

- `src/runtime/collision.zig` checks 8x8 solid collision tiles.
- Horizontal room bounds are solid.
- Below the room is empty so death pits work.
- Above the room is empty so upward transitions can work.
- `src/runtime/player_collision.zig` adds dynamic solids after static collision
  checks for player-sized probes and sweeps.

Dynamic collision:

- `src/runtime/falling_blocks.zig` participates through
  `player_collision.dynamicSolidRectAt` and also exposes footstep-floor probes
  for snow footstep selection.
- Player can stand on and wall-grab dynamic blocks once they are active.

One-way collision:

- One-way platforms are checked on downward movement through the
  `player_collision` one-way top path.
- They are authored in the collision editor separately from full solid tiles.
- Actor-backed platforms plug into the same one-way top query path through
  `src/runtime/chapters/systems.zig`. The current implementation is the
  prologue funny car platform, but future chapters can provide their own actor
  platform probes without entering the static tile collision module.

## Player Movement Guardrails

Avoid large movement refactors without focused testing. Fragile areas:

- `player_controller.tryClimbLedge` must not search far enough to land inside
  hollow/concave annotated shapes. It currently searches only just over the wall
  face.
- `player_controller.updateClimbLedgeMotion` is collision-aware because raw
  interpolation can tunnel into solids.
- `player_collision.resolvePlayerEmbedding` is a last-resort guard, not a
  replacement for correct sweep/collision logic.
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
- `background.applyCamera` keeps full BG scroll and streams logical map entries
  into the wrapped 64x32 hardware BG map only when the camera crosses tile
  boundaries. This supports rooms wider than the hardware map, such as the
  992px-wide prologue room `3`, without rewriting the full map every frame.

Objects:

- Player body, hair, falling blocks, grass, parallax chunks, dust, sweat, and
  wind snow are OBJs.
- Parallax/foreground occlusion chunks are drawn with high visual priority and
  can appear in front of the player.
- `src/runtime/foreground_stamps.zig` draws foreground grass stamps behind or in
  front of the player based on annotation flags.
- `src/runtime/chapters/prologue/room_wires.zig` draws OBJ wires only when
  static BG stamping is not possible. It borrows unused falling-block and
  behind-stamp object slots.

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
transitions and deaths; that persistence now lives with the falling block
system rather than in the shared room-state struct. Keep this distinction clear:

- room asset data is reloaded from generated blobs;
- persistent entity state records gameplay consequences that should survive
  room reloads.

This will eventually need a cleaner session/level state module.
