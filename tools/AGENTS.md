This directory contains project-specific asset and annotation tools. Prefer
using these scripts through `zig build assets` or `task` commands when those
exist, instead of running ad hoc conversions.

Before changing these tools, read `../docs/asset-pipeline.md`. If the tool
change affects runtime data layout, also read `../docs/runtime-architecture.md`.
For bespoke cutscene authoring tools, read `../docs/cutscene-tooling.md`.

## Common Commands

- `task collision`: opens the chapter collision/entity/foreground stamp editor.
- `task hair`: opens the player hair anchor editor.
- `task scene`: opens the scene animation editor for scripted NPC placement,
  trigger rectangles, hint placement, and flight paths.
- `task granny-cutscene`: opens the room 2 Granny intro cutscene editor. This
  is a bespoke editor for trigger, actor, player target, camera, dialogue box,
  dialogue, and laugh-text source data.
- `task city-layout`: opens the chapter 1 room layout picker. It saves
  `assets/chapters/1_city/layout.json`, which the manifest builder uses for
  city room world positions.
- `zig build assets`: rebuilds generated ROM assets under `src/generated`.
- `zig build`: compiles the ROM without regenerating assets.

## Tool Directory

- `collision_server.py` and `collision_editor.html`: integrated chapter editor.
  Use this for collision boxes, one-way platforms, respawn points, falling
  blocks, and foreground stamp placement. It auto-discovers chapter images,
  background art, and existing annotations. Saved annotations live beside the
  source image.

- `scene_server.py` and `scene_editor.html`: scene/NPC animation editor. Use
  this for bird origin placement, hint box placement, trigger rectangles, and
  flight path segments. Saved `*_scene.json` files live beside the source room
  image. The room builder folds bird scene data into `bird_npcs.bin`.

- Bespoke cutscene tools: create these only when a specific cutscene needs
  authoring support. Follow `../docs/cutscene-tooling.md`; save source data as
  `<room>_cutscene.json` beside the room image. Prefer a small room-specific UI
  over expanding the generic scene editor too early.

- `granny_cutscene_server.py` and `granny_cutscene_editor.html`: bespoke room 2
  Granny intro editor. It saves
  `assets/chapters/prologue_a/2_cutscene.json`. It discovers Granny animation
  sheets from `assets/animations/granny/` and stores dialogue-page animation
  cues by sheet id. Granny `idle` is an implicit default for dialogue pages
  without an explicit cue. The second zoom beat is stored as `camera_focus_2`
  plus `camera.secondary.afterDialogue`. It does not pack runtime assets yet;
  wire the JSON into the ROM only after the sequence shape is stable.

- `hair_anchor_server.py` and `hair_anchor_editor.html`: player hair anchor
  editor. Use this for per-frame hair root placement and facing direction.
  The runtime draws the root tile plus procedural trailing hair from these
  anchors.

- `city_layout_server.py` and `city_layout_picker.html`: chapter 1 room layout
  picker. Use this to place each captured room PNG over the full city map and
  save `assets/chapters/1_city/layout.json`.

- `build_level_assets.py`: top-level level asset builder. It reads a chapter
  manifest such as `assets/chapters/prologue_a/room.json`, runs room conversion,
  handles optional parallax metadata, and writes `src/generated_rooms.zig`.
  This is normally invoked by `zig build assets`.

- `build_room_bundle.py`: builds one room bundle from a room PNG plus its
  annotation JSON. Outputs tilemap data, collision, respawns, falling block
  data, bridge/generic stamp data, and summary JSON. Grass foreground stamps
  are currently discarded to keep the ROM under budget.

- `convert_room_tilemap_8bpp.py`: converts a source room/background PNG into
  GBA background tiles, map data, and palette data. It includes deduplication
  and validation that reconstructed tiles match the source indices.

- `pack_player_animations.py`: packs Madeline animation PNG frames and hair
  anchor data into runtime player assets.

- `pack_player_obj_tiles.py`: older/direct player OBJ tile packer. Prefer
  `pack_player_animations.py` unless intentionally working on low-level player
  tile packing.

- `pack_hair_obj.py`: packs authored hair root/tile pieces used by the
  procedural hair renderer.

- `pack_falling_block_obj.py`: packs the falling ice block entity art into OBJ
  tiles and palette data.

- `pack_parallax_obj.py`: packs room parallax foreground/occlusion images into
  chunked OBJ assets.

- `split_foreground_tileset.py`: utility module plus standalone splitter for
  downloaded foreground atlases. Many tools import its PNG read/write helpers.

- `extract_player_sprite.py`: helper for extracting individual player sprites
  from source sheets. Use only when adding or debugging raw sprite extraction.

## Generated vs Source

- Treat `assets/chapters/**`, `assets/animations/**`, and annotation JSON files
  as source inputs.
- Treat `src/generated/**` and `src/generated_rooms.zig` as generated outputs.
  Regenerate them with `zig build assets` after source asset or annotation
  changes.
- Do not hand-edit generated binary files.

## Notes

- Foreground stamps are data-driven enough for the editor and room builder, but
  the runtime still needs explicit tile/palette banks for each stamp kind.
  When adding a new stamp family, update generation, packing, room bundle kind
  mapping, and runtime draw/load logic together.
- Collision annotation is for physical gameplay surfaces and simple room
  objects. Scene annotation is for scripted NPC behavior and presentation.
  Keep editor UX simple: direct clicking beats hand-authored JSON.
