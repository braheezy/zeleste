This directory contains project-specific asset and annotation tools. Prefer
using these scripts through `zig build assets` or `task` commands when those
exist, instead of running ad hoc conversions.

Before changing these tools, read `../docs/asset-pipeline.md`. If the tool
change affects runtime data layout, also read `../docs/runtime-architecture.md`.

## Common Commands

- `task collision`: opens the chapter collision/entity/foreground stamp editor.
- `task hair`: opens the player hair anchor editor.
- `task grass-edit`: opens the generated grass frame editor for manual cleanup
  of generated foreground sway frames in `assets/generated/foreground/`.
- `task grass-sway -- <path> [--preset auto|tiny|small|medium|large] [--no-mirror]`:
  generates sway frames for a foreground grass PNG. The generated stamp name is
  derived from the input file or directory and is written to
  `assets/generated/foreground/` by default.
- `zig build assets`: rebuilds generated ROM assets under `src/generated`.
- `zig build`: compiles the ROM without regenerating assets.

## Tool Directory

- `collision_server.py` and `collision_editor.html`: integrated chapter editor.
  Use this for collision boxes, one-way platforms, respawn points, falling
  blocks, and foreground stamp placement. It auto-discovers chapter images,
  background art, and existing annotations. Saved annotations live beside the
  source image.

- `hair_anchor_server.py` and `hair_anchor_editor.html`: player hair anchor
  editor. Use this for per-frame hair root placement and facing direction.
  The runtime draws the root tile plus procedural trailing hair from these
  anchors.

- `grass_frame_server.py` and `grass_frame_editor.html`: generated grass frame
  editor. Use this after `task grass-sway` for frame-by-frame cleanup when the
  procedural sway is close but visually wrong. It edits generated PNG frames
  directly.

- `build_level_assets.py`: top-level level asset builder. It reads a chapter
  manifest such as `assets/chapters/prologue_a/room.json`, runs room conversion,
  handles optional parallax metadata, and writes `src/generated_rooms.zig`.
  This is normally invoked by `zig build assets`.

- `build_room_bundle.py`: builds one room bundle from a room PNG plus its
  annotation JSON. Outputs tilemap data, collision, respawns, falling block
  data, foreground stamp data, and summary JSON.

- `convert_room_tilemap_8bpp.py`: converts a source room/background PNG into
  GBA background tiles, map data, and palette data. It includes deduplication
  and validation that reconstructed tiles match the source indices.

- `generate_grass_sway.py`: generates foreground grass sway animations from a
  small source PNG. It writes generated frame folders plus GIF previews.
  Supports 8x8, 8x16, 16x8, and 16x16 inputs. The `auto` preset infers
  tiny/small/medium/large sway from opaque height while keeping 42 frames; small
  grass gets fewer distinct sway positions held longer.

- `pack_foreground_stamp_obj.py`: packs generated foreground stamp frames into
  4bpp OBJ tile/palette data. Supports 8x8, 8x16, 16x8, and 16x16 frames.

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
- Collision annotation is currently also where lightweight room entities are
  authored. Keep editor UX simple: direct clicking beats hand-authored JSON.
