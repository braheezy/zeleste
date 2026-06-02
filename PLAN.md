# Zeleste High-Level Plan

Zeleste is a Game Boy Advance demake of Celeste built in Zig with ZigGBA. The goal is to preserve the feel, readability, and mood of the full Celeste game as closely as the GBA allows, using the official released source snippets, Celeste Classic, CelesteNES, and Celeste-For-GBA as references. This is not a direct port of any existing engine.

## Goals

- Deliver a faithful GBA-scale Celeste experience, closer in feel and visual identity to the full game than to Celeste Classic alone.
- Prioritize player feel above feature count: movement, collision, camera, state transitions, and input forgiveness must be tuned before broad content work.
- Build a small, maintainable ZigGBA engine for room-based platforming, sprite animation, tilemap rendering, entity simulation, transitions, save data, and audio.
- Use reference projects aggressively for behavior, layout, visual reduction, and pipeline ideas, while writing new Zig-native runtime code.
- Keep the project structured so both humans and coding agents can work safely in parallel with clear ownership boundaries.

## Reference Sources

- `~/personal/celeste-demake/Celeste`
  - Official source excerpts.
  - `Source/Player/Player.cs` is the primary movement reference.
  - `Source/PICO-8/Classic.cs` is useful for compact platformer architecture and classic room-scale constraints.

- `~/personal/celeste-demake/CelesteNES`
  - Strong demake reference for how to preserve full-game visual identity under severe hardware limits.
  - Useful for room layout strategy, entity selection, tile grouping, palette reduction, chapter structure, and how much fidelity is possible on weaker hardware than GBA.

- `~/personal/Celeste-For-GBA`
  - Useful for GBA-specific movement translation attempts, room text formats, and feature scope.
  - Do not port Pixtro-specific architecture. Treat it as a behavior and content reference only.

- `~/personal/gba/ziggba`
  - Runtime SDK and build system.
  - Use examples for display modes, tile backgrounds, sprites, interrupts, text, and build helpers.

## Fidelity Targets

### Movement Feel

Movement is the first pillar. Implement and tune these before trying to build large levels:

- 60 FPS fixed-step simulation.
- Fixed-point position, velocity, and timers.
- Ground movement with acceleration, reduce/friction, and air multiplier.
- Jump buffering and coyote time.
- Variable jump height.
- Dash direction buffering and dash freeze.
- Dash attack window.
- Dash refill rules.
- Wall slide, wall jump, climb, climb jump, stamina, tired state.
- Corner correction for jumps and dashes.
- Wall speed retention.
- Room transition dash/stamina reset rules.
- Death, respawn, and short freeze/feedback loops.

The official `Player.cs` constants should be the starting point, converted into fixed-point values and frame timers. Exact numeric parity is less important than matching observed behavior in common situations.

### Visual Style

The target is closer to full Celeste than PICO-8 Celeste Classic:

- Use GBA tile backgrounds and sprites to preserve the recognizable chapter look.
- Favor authored pixel art reductions over generic reinterpretation.
- Use layered backgrounds when they materially improve the Celeste look: distant mountains, parallax bands, fog/snow/rain, interior silhouettes.
- Preserve key player readability: hair color, dash state, climb/tired feedback, death burst, dash trail where affordable.
- Build room art around metatiles and palette banks, not one-off bitmap screens.
- Use CelesteNES as evidence that a recognizably full-game visual identity is achievable on weaker hardware; the GBA target should be at least as visually expressive.

### Scope

Start with Chapter 1-style gameplay, then expand:

1. Prologue/Chapter 1 movement playground.
2. Chapter 1 with strawberries, springs, spikes, crumble blocks/disappearing platforms, and zip-mover mech blocks; static traffic blocks only if needed.
3. Chapter 2 visual and mechanical slice: dream blocks, Badeline/chaser concepts, space effects.
4. Broader chapters only after the first chapter feels complete.

Avoid starting with the full Celeste entity roster. A smaller set polished to high fidelity is better than many half-implemented mechanics.

## Runtime Architecture

### Current Refactor Checkpoint (May 29, 2026)

The prologue milestone is complete, the dummy overworld handoff reaches the
chapter 1 city stub, and the runtime refactor is underway. Completed splits:

- `src/main.zig` is now only the GBA root/header wrapper and entrypoint.
- Generated room contracts, fixed-point/math helpers, asset embeds, audio init,
  debug FPS overlay, OAM helpers, RNG, camera helpers, video constants,
  BG/parallax streaming, static collision helpers, player state/constants,
  reusable player collision context, reusable player movement controller,
  reusable player sprite rendering, reusable player hair rendering, reusable
  player death/respawn VFX, reusable player death/respawn flow state, dash VFX,
  reusable falling block hazards, reusable footstep SFX/surface classification,
  reusable foreground stamps, reusable room transition helpers, reusable room
  lifecycle/update hooks, reusable dust/snow puff particles, reusable wind/snow
  environmental particles, reusable cutscene dialogue box rendering, reusable
  cutscene text helpers, gameplay scene drawing/effect hooks, active chapter
  system dispatch, room-aware chapter scene hooks, chapter/session flow
  dispatch, fixed scene object slot names, shared gameplay-room loading, shared
  frame sync, and the dummy overworld placeholder screen loader live under
  top-level domain folders: `src/core/`, `src/player/`, `src/world/`,
  `src/room/`, `src/effects/`, `src/cutscene/`, and `src/chapters/`.
  Prologue-specific actors, cutscenes, bridge/end-platform logic, session flow,
  bird prompts, funny cars, room wires, tiny birds, Granny rendering, chimney
  smoke, and laugh text now live under
  `src/chapters/prologue/` behind the `src/chapters/prologue.zig`
  facade. The chapter 1 city stub now has its own
  `src/chapters/city/` module that owns the `chapter 1 / room 1` to
  generated `city_1` mapping and empty systems hooks for future city mechanics.
- `src/game.zig` now delegates room lifecycle, room transitions, death flow,
  player movement, player collision, chapter/end-level flow, frame sync, and
  scene drawing to focused runtime modules while retaining only startup,
  death/respawn timers, and normal frame ordering.

Next refactor targets:

- Treat `src/game.zig` as the frame-loop shell. Future refactors should be
  tactical: death/respawn timer ownership or a fuller entity registry only when
  new chapter work creates real pressure.
- Use the extracted falling block system as the pattern for
  load/update/draw/collision hooks and side-effect event reporting, and the
  foreground stamp system as the pattern for reusable room decoration/occlusion
  ownership. Actor-backed platform probes now route through the active chapter
  system adapter, with prologue funny cars as the first implementation; bird
  NPCs are now the first tutorial-prompt NPC extraction;
  footsteps now own terrain surface classification and SFX sample rotation;
  gameplay scene drawing/effect hooks, frame sync, chapter flow dispatch,
  prologue chapter flow, and the dummy overworld screen loader are now separated
  from the frame loop; room
  transitions, room-system updates, and death/respawn state now have dedicated
  owners; prologue-specific Granny sprite rendering, floating laugh text, the
  Granny cutscene script, bird actors, funny cars, room wires, tiny birds,
  chimney smoke, prologue flow, and bridge runtime are now in the prologue
  chapter folder.
- Keep player movement behavior stable. Future chapter mechanics should reuse
  `src/player/controller.zig`, `src/player/collision.zig`, and room-system
  hooks rather than reintroducing direct room branches in the frame loop.
- Preserve the current prologue, overworld placeholder, and chapter 1 room
  wiring behavior after every pass.

### Core Loop

- `main.zig`
  - GBA header, hardware init, interrupt setup, main loop.
  - Fixed update order: input, game state update, entity update, camera, render prep, VBlank upload.

- `game.zig`
  - Top-level game states: boot, title, chapter select, gameplay, pause, room transition, death/respawn.
  - Owns persistent save state and current chapter/session.

- `input.zig`
  - Raw key polling.
  - Pressed/held/released edge states.
  - Frame-based input buffers for jump, dash, climb, confirm/cancel.

- `time.zig`
  - Frame counters and timer helpers.
  - Convert official second-based constants into frame constants.

### Math And Collision

- `fixed.zig`
  - Fixed-point type and helpers.
  - Suggested start: signed `i32` with 8 or 12 fractional bits.

- `rect.zig`
  - Integer/fixed rectangles and overlap tests.

- `collision.zig`
  - Tile collision queries.
  - Solid, spikes by direction, jump-through, dream block, cassette block, kill volumes.
  - Actor movement helpers: move X, move Y, exact move, sweep/correct, corner correction.

- `actor.zig`
  - Shared moving body behavior for player and selected entities.
  - Keep it small. Player behavior should remain tightly ordered and explicit, following the spirit of the official Player.cs notes.

### Player

- `player.zig`
  - The most important file.
  - Use one explicit state machine: normal, climb, dash, dream_dash, dead, cutscene/dummy.
  - Keep order of operations readable and stable. Do not over-abstract nuanced movement.
  - Comments should explain non-obvious Celeste feel mechanics and cite reference names, not narrate basic code.

- `player_constants.zig`
  - Tuned constants derived from official Celeste and adjusted for fixed-point/frame units.
  - Changes here should be deliberate and recorded in tuning notes.

- `player_render.zig`
  - Sprite selection, hair segments, dash trail, palette state.
  - Separate rendering from movement while keeping the movement update order centralized.

### Rooms And Entities

- `room.zig`
  - Current room metadata, tile layers, spawn point, exits, camera bounds.

- `level.zig`
  - Chapter/room graph, room loading, transition selection, respawn room.

- `entity.zig`
  - Entity slots, type IDs, lifecycle, update/render dispatch.
  - Keep entity memory fixed-size and predictable.

- `entities/`
  - `strawberry.zig`
  - `spring.zig`
  - `dream_block.zig`
  - `spikes.zig`
  - `cassette_block.zig`
  - Add only when the player foundation is ready.

### Rendering

- `video.zig`
  - Display mode setup, background layers, sprite/OAM upload, palette upload.

- `tiles.zig`
  - Tileset and metatile definitions.
  - Runtime tilemap writes and streaming for room transitions.

- `sprite.zig`
  - Animation definitions, object attributes, sprite sheet indexing.

- `camera.zig`
  - Room-locked camera first.
  - Later: smooth camera, look-ahead, transition camera, shake.

Suggested initial rendering path:

- Tile mode with one foreground collision/art layer, one background/deco layer, and object sprites.
- Use 8x8 hardware tiles but author gameplay around 8x8 or 16x16 metatiles.
- Keep visual effects budgeted: dash trails, particles, and parallax should never compromise movement frame rate.

### Overworld / Chapter Select

Use a GBA-native mountain overworld instead of trying to reproduce the original vector/2.5D chapter select.

Proposed first version:

- One tall scrolling pixel-art mountain map, likely `256x512` pixels to start.
- Treat it as one continuous tile background, about one screen wide and a little over three GBA screens tall.
- Place chapter nodes along a winding mountain path.
- Move a Madeline cursor/marker sprite between nodes.
- Smoothly scroll the camera to the selected node.
- Show a compact chapter title/status panel and a small preview image for the selected chapter.
- Keep nodes data-driven: chapter id, map position, title text, completion state, preview asset, and target start room.
- Initial node list: Prologue, Forsaken City, Old Site, Celestial Resort, Golden Ridge, Mirror Temple, Reflection, The Summit, Epilogue.

The visual goal is a readable handheld map: tiled pixel-art mountain, small icons, simple text panels, and optional preview thumbnails. It should evoke the original mountain progress screen without depending on vector art or expensive 3D-like effects.

### Audio

- Use `maxmod-zig`/`mmutil-zig` if it remains the best local path.
- Start with SFX only: jump, dash, death, strawberry, spring.
- Add music after gameplay timing is stable.
- Treat music as chapter mood support, not a blocker for the movement prototype.

### Save Data

- Fixed-size SRAM layout.
- Track chapter completion, berries, cassettes, deaths, time, assist/tuning flags if needed.
- Version the save format from the start.

## Asset And Data Pipeline

Build a Zig or host-side tool pipeline early. The game should not depend on hand-edited binary blobs.

Inputs:

- Aseprite/PNG tilesets and sprites.
- Tiled/LDtk/custom text rooms.
- Palette definitions.
- Entity placement data.
- Dialogue text.
- Audio modules/samples.

Outputs:

- Zig data files or binary blobs imported by Zig.
- Compressed tilemaps where useful.
- Tileset metadata: collision, palette bank, animation tags.
- Entity spawn tables.
- Chapter room graph and transition data.

Pipeline requirements:

- Deterministic output.
- Clear errors for palette overflows, tile count overflow, sprite size overflow, invalid exits, missing spawn points.
- Separate source assets from generated files.
- Generated files should be easy to regenerate with `zig build assets`.

## Methodology For Faithful Demake Work

### Reference-Driven Implementation

For each mechanic:

1. Read official `Player.cs` and identify constants, state transitions, timers, and collision helpers.
2. Check CelesteNES for demake compromises and visual/mechanical approximations.
3. Check Celeste-For-GBA only for GBA-relevant prior attempts.
4. Write a short implementation note before coding if the mechanic is nuanced.
5. Implement the smallest playable slice.
6. Test in emulator with frame stepping or debug overlays.
7. Tune with recorded scenarios.

### Tuning Scenarios

Maintain a small set of rooms designed only for feel verification:

- Flat run and stop.
- Single-tile and multi-tile jumps.
- Wall jump corridor.
- Climb stamina wall.
- Dash into wall, dash over floor, dash upward through corner.
- Spike death and respawn.
- Dream block entry/exit once implemented.
- Room transition in all four directions.

Each scenario should have a clear expected outcome and should be quick to replay.

### Debug Tools

Build these early:

- Hitbox overlay.
- Tile collision overlay.
- Player state/timer display.
- Frame advance or slow mode if feasible.
- Room reload hotkey in debug builds.
- Coordinates, speed, stamina, dash count, coyote/buffer timers.

These tools are not polish. They are how the movement gets faithful.

## Human And Agent Collaboration

### Working Rules

- Humans own taste, fidelity judgment, and final tuning calls.
- Agents can implement bounded systems, converters, debug views, and mechanical translations.
- Any agent touching movement must cite the reference behavior it is implementing and keep changes small.
- Do not let agents perform broad refactors across player movement, collision, and rendering in the same change.
- Keep generated assets and runtime code in separate commits.

### Suggested Ownership Boundaries

- Movement owner: `player.zig`, `player_constants.zig`, `collision.zig`.
- Rendering owner: `video.zig`, `sprite.zig`, `tiles.zig`, palettes.
- Pipeline owner: `tools/`, asset conversion, generated data.
- Content owner: rooms, entities, chapter data.
- Audio owner: soundbank, playback API, SFX triggers.

Agents should be given tasks like:

- "Port jump buffering and coyote timers from Player.cs into player.zig."
- "Create a PNG tileset converter that validates 16-color palette banks."
- "Implement a debug overlay for player state and collision tiles."
- "Add strawberry entity behavior using Celeste-For-GBA and CelesteNES as reference."

Avoid tasks like:

- "Make movement feel good."
- "Port Celeste."
- "Refactor the engine."

Those are too broad and will damage coherence.

## Current Progress

- ZigGBA project skeleton exists and builds `zig-out/zeleste.gba`.
- `zig build run` launches the built ROM in mGBA.
- `zig build assets` regenerates generated assets under `src/generated/**` and writes `src/generated_rooms.zig`.
- Active source room graph lives in `assets/rooms/prologue_a/room.json` with rooms `-1`, `0`, `0b`, and `1`.
- Prologue rooms render as 8bpp scrolling tile backgrounds on BG0 using per-room palettes.
- Annotation JSON now drives collision, one-way platforms, respawn points, falling blocks, and foreground stamp placement.
- Room transitions work left/right/up/down from the room graph, with black transition hiding while room data reloads.
- Death/respawn works for pit deaths, using respawn points selected from room-entry context.
- Player movement uses 8-bit fixed-point position/velocity with tuned run, jump, variable jump, coyote time, jump buffering, wall slide, wall jump, wall grab, climbing, climb ledge hop, stamina, tired state, and palette flashing.
- Madeline sprite packing uses multiple animation folders and `hair_anchors.json` data. Runtime draws bald body frames, an authored hair root tile, and procedural trailing hair.
- The first falling ice block is a persistent room entity with dynamic collision, shaking, falling, and loose snow particles.
- Wind snow particles are procedural and configurable per room through `room.json`.
- Room `0` has a foreground/parallax occlusion image packed into OBJ chunks.
- Foreground grass stamp editing and sway generation exist, but runtime drawing currently supports only `grass1` and `grass2`.
- Project handoff docs now live under `docs/`: `current-status.md`, `runtime-architecture.md`, and `asset-pipeline.md`.
- Runtime refactor has split the old monolithic shape into top-level domain
  folders: `src/core/`, `src/player/`, `src/world/`, `src/room/`,
  `src/effects/`, `src/cutscene/`, and `src/chapters/`. `src/main.zig` is a
  small GBA wrapper and `src/game.zig` is the thin frame-loop shell. Chapter
  systems, chapter flow, room scene drawing, room loading, and fixed scene
  object slots now have explicit adapters for future city mechanics.
- Remaining Milestone 0 gap: keep future splits tactical and driven by chapter
  work; the broad monolithic runtime refactor is largely complete without
  changing movement behavior.

## Milestones

### Milestone 0: Project Skeleton

- ZigGBA project builds a `.gba`.
- mGBA run step works.
- VBlank loop, input polling, blank tilemap, sprite test.
- Basic folder structure and asset generation step exist.

### Milestone 1: Movement Box

- Player rectangle moves in a simple tile room.
- Fixed-point motion, collision, camera lock.
- Jump, variable jump, coyote, buffer.
- Debug overlay for position, velocity, state, and hitbox.

### Milestone 2: Celeste Core Movement

- Dash, dash freeze, dash refill.
- Wall slide, wall jump, climb, stamina.
- Corner correction and wall speed retention.
- Death/respawn.
- Tuned against reference scenarios.

### Milestone 3: First Visual Slice

- Madeline sprite and hair states.
- Chapter 1-style tileset and background.
- Spikes, jump-through platforms, springs.
- Particles and basic SFX.
- One polished room that looks and feels like a real demake.

### Milestone 4: Room Graph

- Multiple rooms with transitions.
- Room-specific spawn and respawn.
- Entity persistence rules for collected items.
- Save data skeleton.

### Milestone 5: Chapter 1 Slice

- Small but complete Chapter 1-inspired route.
- Strawberries.
- Chapter intro/end flow.
- First pass of the mountain overworld/chapter select with nodes, camera scroll, title/status text, and preview thumbnail support.
- Music pass.
- Performance budget verified on emulator and, if available, hardware.

### Milestone 6: Chapter 2 Slice

- Dream blocks.
- Chapter 2 visual treatment.
- Badeline/chaser/cutscene approximations if feasible.
- Expand asset pipeline for chapter-specific tiles and palettes.

## Technical Risks

- Movement feel can drift if collision order is changed casually.
- GBA sprite/tile/palette limits can force art compromises late if the asset pipeline does not validate early.
- Full-game Celeste visuals are possible in spirit, but not as direct asset copies without careful reduction and legal caution.
- Large scrolling rooms and heavy effects can threaten frame time; room-scale layouts are safer.
- Audio tooling can consume time; do not block the first gameplay milestones on full music fidelity.

## Legal And Distribution Notes

This should be treated as a learning/fan demake unless original branding and assets are created. The official Celeste code excerpts are MIT-licensed, but the commercial game, name, characters, art, music, and broader IP are not. If this is ever distributed publicly, plan for original art/audio/branding or explicit permission.

## Immediate Next Steps

1. Continue tuning climb, wall jump, stamina, and collision order against `Player.cs` and observed Celeste behavior.
2. Add dash, dash freeze, dash attack timing, and dash refill.
3. Add a simple debug collision/player overlay before making more complex movement changes.
4. Extend runtime foreground stamp support beyond `grass1` and `grass2` only after the grass art workflow is satisfying.
5. Add `docs/reference-map.md` linking each mechanic to official, NES, and GBA reference files.
6. Keep future refactors tactical and chapter-driven; avoid broad movement/collision/rendering rewrites unless a new mechanic requires the boundary change.
