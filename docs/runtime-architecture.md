# Runtime Architecture Notes

The runtime is no longer rooted directly in a 7k-line `src/main.zig`.
`src/main.zig` is a small GBA root wrapper that owns the header/exported entry
point and re-exports generated-data contracts required by `src/generated_rooms.zig`.

Current hand-written runtime modules:

- `src/game.zig`: thin runtime loop that owns startup, death/respawn timers,
  normal per-frame ordering, and high-level calls into focused runtime modules.
- `src/core/assets.zig`: generated ROM asset embed catalog. Runtime code
  keeps aligned local aliases where existing VRAM/palette casts require them.
- `src/core/audio.zig`: maxmod soundbank initialization, music/SFX master
  volume steps, active SFX handle tracking, music looping, and VBlank mixer
  hook. Gameplay SFX triggers still live near their current callers.
- `src/world/background.zig`: BG0 room map streaming, BG1 parallax streaming,
  static wire stamping into spare BG tile space, and wrapped hardware-map
  helpers.
- `src/world/camera.zig`: camera value type and basic player-follow camera
  calculations.
- `src/chapters/flow.zig`: chapter/session flow adapter. The frame loop calls
  this instead of importing prologue flow directly. The current implementation
  routes the prologue bridge ending and placeholder overworld handoff while city
  has no active chapter flow yet.
- `src/chapters/systems.zig`: active chapter system adapter. Shared movement,
  collision, footstep, scene drawing, camera shake, death cleanup, and room
  lifecycle code call this switch instead of importing chapter files directly.
  It currently dispatches by generated room id, with `city_*` rooms routed to
  the city stub and all remaining generated rooms routed to prologue systems.
- `src/chapters/city.zig`: chapter 1 city facade. The current city
  runtime is only a stub, but this gives chapter 1 a code owner instead of
  leaving its first room as a prologue hardcode.
- `src/chapters/city/flow.zig`: chapter 1 city entry mapping. It owns
  the authored chapter `1` / room `1` runtime identity and maps it to the
  generated room id `city_1`.
- `src/chapters/city/systems.zig`: city room-system hook stub. It currently
  implements no behavior, but gives chapter 1 a clean place to add city actors,
  cutscenes, platform providers, scene effects, and draw hooks without touching
  the prologue modules or generic runtime loop.
- `src/chapters/prologue/systems.zig`: prologue room-system hook owner.
  It loads and updates prologue-only room actors, cutscenes, dynamic bridge
  solids, actor-backed one-way platform probes, and bridge footstep/hair state.
- `src/chapters/prologue/flow.zig`: prologue chapter/session flow
  owner. It owns bridge-ending hold and dash unlock state, prologue end-level
  transition timing, dummy overworld handoff, and asks the city chapter module
  for the chapter 1 entry room from the placeholder overworld.
- `src/chapters/prologue/bridge.zig`: prologue bridge/end-platform room
  system. It owns bridge asset loading, chunk collapse state, bridge OBJ
  drawing, ending-hold trigger state, dynamic bridge solids, bridge floor
  probes, dark bridge palette writes, collapse camera shake, and bridge snow
  side effects.
- `src/chapters/prologue/granny_cutscene.zig`: prologue Granny cutscene
  script. It owns trigger/progress state, player cutscene locking, dialogue
  page/reveal state, dialogue overlay calls, laugh-text lifetime, Granny NPC
  pose/facing selection, room palette mood, cutscene camera shake, and
  death/room-transition cleanup hooks.
- `src/chapters/prologue/granny_npc.zig`: prologue Granny NPC sprite
  renderer. It owns Granny animation frame caches, palette loading, OBJ
  draw/hide behavior, and fixed sprite offsets while the Granny cutscene chooses
  animation and facing.
- `src/chapters/prologue/laugh_text.zig`: prologue `HAHA` cutscene VFX.
  It owns the tile upload/cache, fixed object budget, particle state, update
  cadence, camera-follow retarget, draw/hide behavior, and simple start/update/
  draw/stop hooks.
- `src/chapters/prologue/bird_npc.zig`: prologue bird NPC/tutorial
  prompt actor. It owns per-room bird data loading, the bird state machine, hint
  tile/palette streaming, OBJ drawing/hiding, cache invalidation, and the
  bridge-ending dash-prompt fly-in API.
- `src/room/tiny_birds.zig`: reusable tiny bird flock actor. It owns flock
  loading, persistent flown state, trigger/update behavior, visual-only puzzle
  clump/spoke animation, palette/tile uploads, OBJ drawing, and hide behavior
  while chapter systems provide room-specific placement data.
- `src/chapters/prologue/chimney_smoke.zig`: prologue Granny-room
  procedural 16x16 OBJ smoke effect. It owns the generated smoke tiles, palette
  color, active-room/origin constants, counter/update cadence, OBJ drawing, and
  hide/reset helpers.
- `src/chapters/prologue/funny_cars.zig`: prologue funny-car platform
  actor. It owns generic-stamp loading, car state, graphics/palette loading,
  bounce update, car footstep/floor probes, one-way top queries, and OBJ
  drawing.
- `src/chapters/prologue/room_wires.zig`: prologue OBJ wire fallback.
  It draws generated room wires only when static BG stamping is not possible,
  and borrows unused falling-block and behind-stamp object slots.
- `src/world/collision.zig`: reusable static collision geometry helpers for
  solids, spikes, jump-through platforms, and rectangle overlap.
- `src/cutscene/dialogue.zig`: reusable cutscene dialogue box renderer.
  It owns the 6x3 OBJ box layout, generated 4bpp tile buffer, dialogue render
  cache, name-color rules, box/text pixel drawing, palette bank, and object
  show/hide behavior. Cutscene scripts still choose pages, reveal offsets, and
  placement.
- `src/player/dash_effects.zig`: dash afterimage/burst state, generated dash
  burst tile graphics, dash VFX palettes, and dash VFX OBJ drawing.
- `src/core/debug_fps.zig`: optional `--dev-hud` FPS object overlay.
- `src/core/audio_debug.zig`: pause-menu Options toggleable SFX watch overlay.
  It reuses the high HUD object slots when enabled, reads active sound IDs from
  `src/core/audio.zig`, maps known IDs to short debug names, and briefly holds
  the last sound name after one-shot UI SFX end.
- `src/effects/dust.zig`: reusable dust/snow puff particle system. It owns the
  shared particle OBJ palette colors, generated 8x8 particle tiles, jump,
  landing, wall-slide, and falling-block snow spawns, particle update, clear,
  and draw behavior.
- `src/room/falling_blocks.zig`: reusable falling-block dynamic hazard
  system. It owns per-room loaded block state, persistent landed masks,
  graphics/palette loading, OBJ drawing, dynamic-solid queries, player crush
  checks, and update results that let the caller spawn dust/snow without
  coupling the system to the particle implementation.
- `src/player/footsteps.zig`: reusable footstep SFX and surface classifier.
  It owns footstep sample rotation, active footstep handle management, dynamic
  floor-provider priority, one-way wood checks, background-pixel surface
  classification, cadence, and volume.
- `src/core/frame.zig`: shared frame sync helper. It runs the maxmod GBA
  frame hook, waits for VBlank, and updates the optional debug FPS overlay.
- `src/room/foreground_stamps.zig`: reusable foreground decoration and
  occlusion stamp system. It owns per-room grass stamp loading, OBJ tile/palette
  uploads, behind-player and occluding OBJ drawing, and the behind-stamp object
  count used by prologue room wires when sharing spare object slots.
- `src/room/gameplay_scene.zig`: gameplay scene draw-order and scene-effect
  owner. It centralizes per-lifecycle draw ordering, shared OBJ sprite loading
  and cache invalidation, wind/snow scene hooks, chapter scene-effect hooks,
  player object hiding, and object-slot constants shared by room systems.
- `src/room/object_slots.zig`: fixed OBJ slot table for shared scene/chapter
  hooks. This is still a static contract, not an allocator, but keeps generic
  scene code from depending on prologue actor modules for slot numbers.
- `src/player/hair.zig`: player hair simulation, palette state, procedural
  hair tile generation, bang tile generation, and hair OBJ drawing. Callers pass
  chapter/cutscene-specific hair state such as the current ending-hair override.
- `src/core/oam.zig`: OBJ coordinate conversion and object hiding helper.
- `src/world/overworld_placeholder.zig`: dummy overworld screen loader. It
  owns the placeholder overworld asset embeds, map copy, display cut-to-black,
  BG scroll reset, and placeholder BG0 enable path used before entering the
  chapter 1 city stub.
- `src/player/death.zig`: player death/respawn flow state. It owns
  death-origin tracking, death-intro animation selection, centered death-intro
  offset calculation, respawn-burst origin, player/cutscene cleanup hooks, and
  calls into `src/player/death_vfx.zig` for drawing.
- `src/core/rng.zig`: shared deterministic runtime random generator.
- `src/world/room_data.zig`: room graph, parallax, spawn, scene rectangle, and
  cutscene data contracts, plus little-endian readers used by generated room
  data and runtime loaders.
- `src/world/room_systems.zig`: room lifecycle/update facade. It owns shared
  room-system loading, transient effect clearing, reusable dynamic hazard
  updates and snow side effects, static room hazard checks, and the shared
  foreground animation counter. Chapter-specific load/update/collision hooks
  route through `src/chapters/systems.zig`.
- `src/world/room_loader.zig`: shared gameplay-room load/display helper. It
  loads BG tiles and palette data, lets the active chapter reset palette state,
  loads room systems, and owns the blacked-out display hide/show path used
  during room transitions and respawns.
- `src/world/room_transition.zig`: room transition and spawn helper. It owns
  player spawn construction, left/right/up/down room switching, directional
  respawn selection, room-entry cooldown, cross-room world alignment, side-entry
  floor matching, and room-entry fit/snap logic.
- `src/core/video.zig`: shared screen, screenblock, charblock, and wrapped
  hardware-map dimensions.
- `src/effects/wind_snow.zig`: reusable room wind/snow environmental effect. It
  owns the generated snowflake OBJ tiles, per-room particle state, update/draw
  logic, and fixed OAM/tile budget. `src/room/gameplay_scene.zig` asks
  `src/chapters/systems.zig` for chapter-specific suppression/particle-limit
  flags such as the prologue bridge collapse.
- `src/core/math.zig`: fixed-point and scalar math helpers.
- `src/player/state.zig`: player state type plus player constants/enums.
- `src/player/collision.zig`: player-sized collision context. It
  combines static room collision with dynamic solids, one-way platform actors,
  wall/floor probes, movement sweeps, and embedding resolution.
- `src/player/controller.zig`: player movement controller. It owns the
  input-to-state update order, dash start/end movement, climb/ledge motion,
  jump/wall-jump handling, animation selection, and footstep update call.
- `src/player/death_vfx.zig`: player death and respawn burst renderer.
  It owns generated death-burst tiles, fixed OAM slots, death-intro sprite
  drawing, burst/ring drawing, and hide behavior while runtime chooses death
  cause, timing, and respawn flow.
- `src/player/render.zig`: player body frame cache, normal/tired
  palette handling, sweat frame cache, sweat animation, and player/sweat OBJ
  drawing. Death-intro code still owns its special trajectory but uses this
  module for palette and frame loading.
- `src/core/text.zig`: reusable cutscene/dialogue text helpers, including
  string matching, word wrapping, typewriter reveal advancement, and tiny bitmap
  font drawing through a caller-supplied pixel writer.

This file summarizes the boundaries that exist today so future module splits do
not accidentally change gameplay.

## Main Loop Shape

Startup:

1. `loadGameplayRoom` loads the room background and all room systems;
2. load shared wind/snow tiles and debug HUD resources;
3. create player from the room spawn;
4. initialize camera, wind snow, and chapter scene effects for that camera;
5. draw the initial gameplay scene through the shared scene helper.

Per-frame normal gameplay:

1. poll input;
2. let `src/chapters/flow.zig` consume the frame if a chapter transition
   is active;
3. update room cutscenes and cutscene-owned effects;
4. update player movement or chapter-flow-owned player hold control;
5. update dynamic room hazards that move during player simulation;
6. update room actors such as bridge, cars, bird NPCs, and tiny birds;
7. update player-attached effects such as hair, dust, and dash trails;
8. compute next camera;
9. update camera-dependent room effects such as wind snow and chapter scene
   effects;
10. check end-level, bridge-hold, and static lethal hazards;
11. check room transition;
12. VBlank through `src/core/frame.zig`;
13. apply camera and draw the gameplay scene through the shared scene helper;
14. draw the optional SFX watch overlay after gameplay OAM has been written.

Death and room transitions temporarily disable BG0/OBJ, load the next room or
respawn state, redraw, then re-enable display. This avoids showing the player
over stale room art.

## Room System Hooks

The current hook layer lives behind `src/world/room_systems.zig`, with
`src/game.zig` calling the facade from the frame loop. It is the boundary
future chapters should use before a fuller entity registry exists:

- `loadRoomSystems` loads shared room-owned systems after the BG/palette data
  is loaded, then delegates chapter actor/cutscene setup through
  `src/chapters/systems.zig`. Current shared systems include falling blocks,
  foreground stamps, object sprite uploads, and parallax; current prologue
  systems include funny cars, bridge state, bird NPCs, tiny birds, room wires,
  and Granny cutscene reset. City systems own Chapter 1 actors such as Theo
  dialogue and `s1` tiny birds, including the visual-only crystal-heart puzzle
  bird cycle.
- `updateRoomCutscenes` and `updateRoomCutsceneEffects` are the cutscene entry
  points. `src/chapters/prologue/granny_cutscene.zig` is the first
  authored script behind these hooks; additional chapter cutscenes should plug
  in here rather than adding direct branches in the main loop.
- Dialogue box tile/object ownership lives in `src/cutscene/dialogue.zig`;
  text wrapping, reveal advancement, and bitmap font drawing live in
  `src/core/text.zig` and should be reused for future chapter
  dialogue/cutscene UI.
- `updateDynamicRoomHazards` is for moving room systems that can kill or crush
  the player during simulation. Falling blocks use it today and report
  side-effect events back to the runtime; future moving foreground hazards
  should follow that load/update/draw/collision/event shape.
- `updateRoomActors` is for non-player room actors and NPCs. The shared facade
  delegates current prologue actors through `src/chapters/systems.zig`,
  including bird NPCs, Granny cutscene/NPC integration, funny car platforms,
  tiny bird flocks, and bridge actors.
- Player-owned audio hooks such as `src/player/footsteps.zig` run from
  `src/player/controller.zig` because cadence depends on player state
  after collision. Keep chapter-specific terrain probes behind that module
  boundary.
- Global audio settings are save-header state rather than per-slot progress:
  the pause menu's Options submenu writes separate music/SFX volume steps and
  the SFX watch toggle, while `src/game.zig` applies the saved volume steps
  immediately after `src/core/audio.zig` initializes.
- `updateRoomEffects` is for camera-dependent environmental effects.
- `playerTouchingRoomHazard` centralizes static lethal checks such as spikes
  and death pits.
- `src/room/gameplay_scene.zig` preserves the existing object draw ordering
  for initial gameplay, normal gameplay, loaded rooms, respawn, death, and the
  end-level transition while routing chapter-owned draw calls through
  `src/chapters/systems.zig`.
- `src/chapters/prologue/flow.zig` owns the current
  prologue-to-overworld-to-city session handoff behind `src/chapters/flow.zig`.
  Future chapter end screens or overworld nodes should use chapter-local flow
  modules instead of adding phase globals to the frame loop.

This is intentionally a compatibility layer, not a final entity system. The
next refactor should keep turning prologue-specific globals into fixed-size
reusable systems with load/update/draw/hazard hooks while preserving GBA object
and tile budgets.

## Data Sources

`generated_rooms.zig` is produced by `tools/build_level_assets.py` and exposes
the room graph and per-room binary blobs. It still imports `root`, so
`src/main.zig` re-exports the room contracts from `src/world/room_data.zig`
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

- `src/world/collision.zig` checks 8x8 solid collision tiles.
- Horizontal room bounds are solid.
- Below the room is empty so death pits work.
- Above the room is empty so upward transitions can work.
- `src/player/collision.zig` adds dynamic solids after static collision
  checks for player-sized probes and sweeps.

Dynamic collision:

- `src/room/falling_blocks.zig` participates through
  `player_collision.dynamicSolidRectAt` and also exposes footstep-floor probes
  for snow footstep selection.
- Player can stand on and wall-grab dynamic blocks once they are active.

One-way collision:

- One-way platforms are checked on downward movement through the
  `player_collision` one-way top path.
- They are authored in the collision editor separately from full solid tiles.
- Actor-backed platforms plug into the same one-way top query path through
  `src/chapters/systems.zig`. The current implementation is the
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
- `src/room/foreground_stamps.zig` draws foreground grass stamps behind or in
  front of the player based on annotation flags.
- `src/chapters/prologue/room_wires.zig` draws OBJ wires only when
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
