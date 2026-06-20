const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    const mmutil_dep = b.dependency("mmutil_zig", .{});
    const maxmod_dep = b.dependency("maxmod_zig", .{});
    const maxmod_mod = maxmod_dep.module("maxmod");

    const gba_b = ziggba.GbaBuild.create(b);
    const start_args = parseStartArgs(b);
    const player_death_animations = playerDeathAnimationLayout(b);

    const exe = gba_b.addExecutable(.{
        .name = "zeleste",
        .root_source_file = b.path("src/main.zig"),
    });
    const build_options = b.addOptions();
    build_options.addOption(bool, "start_override", start_args.override);
    build_options.addOption(i32, "start_chapter", start_args.chapter);
    build_options.addOption([]const u8, "start_room", start_args.room);
    build_options.addOption(bool, "dev_hud", b.option(bool, "dev-hud", "Show development HUD overlays in release-speed builds.") orelse false);
    build_options.addOption(u16, "player_deadown_first_frame", player_death_animations.deadown_first_frame);
    build_options.addOption(u16, "player_deadown_frame_count", player_death_animations.deadown_frame_count);
    build_options.addOption(u16, "player_deathside_first_frame", player_death_animations.deathside_first_frame);
    build_options.addOption(u16, "player_deathside_frame_count", player_death_animations.deathside_frame_count);
    build_options.addOption(u16, "player_deathup_first_frame", player_death_animations.deathup_first_frame);
    build_options.addOption(u16, "player_deathup_frame_count", player_death_animations.deathup_frame_count);
    exe.step.root_module.addOptions("build_options", build_options);
    exe.step.root_module.addImport("maxmod", maxmod_mod);
    maxmod_mod.addImport("gba", exe.gba_module);

    const assets_step = b.step("assets", "Build generated game assets");
    const ensure_generated_assets_dir = b.addSystemCommand(&.{
        "mkdir",
        "-p",
        b.pathFromRoot("src/generated/assets"),
    });
    const build_soundbank = b.addRunArtifact(mmutil_dep.artifact("mmutil-zig"));
    const soundbank_bin = b.pathFromRoot("src/generated/assets/prologue_soundbank.bin");
    const soundbank_header = b.pathFromRoot("src/generated/assets/prologue_soundbank.h");

    build_soundbank.addArg(b.pathFromRoot("assets/audio/ost/01_prologue.xm"));
    build_soundbank.addArg(b.pathFromRoot("assets/audio/ost/02_first_steps.xm"));
    build_soundbank.addArg(b.pathFromRoot("assets/audio/ost/02_first_steps_8bit.xm"));
    for (soundbank_sfx_files) |file| {
        build_soundbank.addArg(b.pathFromRoot(file));
    }
    build_soundbank.addArg(b.fmt("-o{s}", .{soundbank_bin}));
    build_soundbank.addArg(b.fmt("-h{s}", .{soundbank_header}));
    build_soundbank.step.dependOn(&ensure_generated_assets_dir.step);
    assets_step.dependOn(&build_soundbank.step);

    const build_sound_ids = beginCachedPythonCommand(b, "sound_ids", "tools/soundbank_header_to_zig.py");
    addCacheInputPath(build_sound_ids, soundbank_header);
    addCacheOutput(b, build_sound_ids, "src/generated/assets/prologue_sound_ids.zig");
    finishCachedPythonCommand(b, build_sound_ids, "tools/soundbank_header_to_zig.py");
    build_sound_ids.addArg(soundbank_header);
    build_sound_ids.addArg(b.pathFromRoot("src/generated/assets/prologue_sound_ids.zig"));
    build_sound_ids.step.dependOn(&build_soundbank.step);
    assets_step.dependOn(&build_sound_ids.step);

    const combined_room_manifest = b.pathFromRoot("src/generated/assets/chapters/room_manifest.json");
    const build_room_manifest = beginCachedPythonCommand(b, "room_manifest", "tools/build_chapter_manifest.py");
    addCacheInputDir(b, build_room_manifest, "assets/chapters/prologue_a");
    addCacheInputDir(b, build_room_manifest, "assets/chapters/1_city");
    addCacheOutputPath(build_room_manifest, combined_room_manifest);
    finishCachedPythonCommand(b, build_room_manifest, "tools/build_chapter_manifest.py");
    build_room_manifest.addArg("--base");
    build_room_manifest.addArg(b.pathFromRoot("assets/chapters/prologue_a/room.json"));
    build_room_manifest.addArg("--city-dir");
    build_room_manifest.addArg(b.pathFromRoot("assets/chapters/1_city"));
    build_room_manifest.addArg("--output");
    build_room_manifest.addArg(combined_room_manifest);
    build_room_manifest.step.dependOn(&ensure_generated_assets_dir.step);
    assets_step.dependOn(&build_room_manifest.step);

    const build_level = beginCachedPythonCommand(b, "level_assets", "tools/build_level_assets.py");
    addCacheInput(b, build_level, "tools/build_room_bundle.py");
    addCacheInput(b, build_level, "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_level, "tools/pack_parallax_obj.py");
    addCacheInputPath(build_level, combined_room_manifest);
    addCacheInputDir(b, build_level, "assets/chapters/prologue_a");
    addCacheInputDir(b, build_level, "assets/chapters/1_city");
    addCacheInputDir(b, build_level, "assets/animations/conveyor_belt_platform");
    addCacheInputDir(b, build_level, "assets/spikes");
    addCacheOutputDir(b, build_level, "src/generated/assets/chapters");
    addCacheOutput(b, build_level, "src/generated_rooms.zig");
    finishCachedPythonCommand(b, build_level, "tools/build_level_assets.py");
    build_level.addArg(combined_room_manifest);
    build_level.addArg("--generated-root");
    build_level.addArg(b.pathFromRoot("src/generated/assets/chapters"));
    build_level.addArg("--zig-output");
    build_level.addArg(b.pathFromRoot("src/generated_rooms.zig"));
    build_level.addArg("--rgb-bits");
    build_level.addArg("4");
    build_level.addArg("--chapter-index");
    build_level.addArg("0");
    build_level.step.dependOn(&build_room_manifest.step);
    assets_step.dependOn(&build_level.step);

    const pack_smashable_ice = beginCachedPythonCommand(b, "smashable_ice", "tools/pack_smashable_ice_obj.py");
    addCacheInput(b, pack_smashable_ice, "assets/smashable-ice.png");
    addCacheInputPath(pack_smashable_ice, b.pathFromRoot("src/generated/assets/chapters/prologue_city_5/bg_palette.bin"));
    addCacheOutput(b, pack_smashable_ice, "src/generated/assets/entities/smashable_ice/smashable_ice_tiles.bin");
    addCacheOutput(b, pack_smashable_ice, "src/generated/assets/entities/smashable_ice/smashable_ice_palette.bin");
    addCacheOutput(b, pack_smashable_ice, "src/generated/assets/entities/smashable_ice/smashable_ice_preview.png");
    addCacheOutput(b, pack_smashable_ice, "src/generated/assets/entities/smashable_ice/smashable_ice.json");
    finishCachedPythonCommand(b, pack_smashable_ice, "tools/pack_smashable_ice_obj.py");
    pack_smashable_ice.addArg("--input");
    pack_smashable_ice.addArg(b.pathFromRoot("assets/smashable-ice.png"));
    pack_smashable_ice.addArg("--room-palette");
    pack_smashable_ice.addArg(b.pathFromRoot("src/generated/assets/chapters/prologue_city_5/bg_palette.bin"));
    pack_smashable_ice.addArg("--output-dir");
    pack_smashable_ice.addArg(b.pathFromRoot("src/generated/assets/entities/smashable_ice"));
    pack_smashable_ice.step.dependOn(&build_level.step);
    assets_step.dependOn(&pack_smashable_ice.step);

    const pack_smashable_ice_6c = beginCachedPythonCommand(b, "smashable_ice_6c", "tools/pack_smashable_ice_obj.py");
    addCacheInput(b, pack_smashable_ice_6c, "assets/6c-smashable-wall.png");
    addCacheInputPath(pack_smashable_ice_6c, b.pathFromRoot("src/generated/assets/chapters/prologue_city_6c/bg_palette.bin"));
    addCacheOutput(b, pack_smashable_ice_6c, "src/generated/assets/entities/smashable_ice_6c/smashable_ice_6c_tiles.bin");
    addCacheOutput(b, pack_smashable_ice_6c, "src/generated/assets/entities/smashable_ice_6c/smashable_ice_6c_palette.bin");
    addCacheOutput(b, pack_smashable_ice_6c, "src/generated/assets/entities/smashable_ice_6c/smashable_ice_6c_preview.png");
    addCacheOutput(b, pack_smashable_ice_6c, "src/generated/assets/entities/smashable_ice_6c/smashable_ice_6c.json");
    finishCachedPythonCommand(b, pack_smashable_ice_6c, "tools/pack_smashable_ice_obj.py");
    pack_smashable_ice_6c.addArg("--input");
    pack_smashable_ice_6c.addArg(b.pathFromRoot("assets/6c-smashable-wall.png"));
    pack_smashable_ice_6c.addArg("--room-palette");
    pack_smashable_ice_6c.addArg(b.pathFromRoot("src/generated/assets/chapters/prologue_city_6c/bg_palette.bin"));
    pack_smashable_ice_6c.addArg("--output-dir");
    pack_smashable_ice_6c.addArg(b.pathFromRoot("src/generated/assets/entities/smashable_ice_6c"));
    pack_smashable_ice_6c.addArg("--name");
    pack_smashable_ice_6c.addArg("smashable_ice_6c");
    pack_smashable_ice_6c.step.dependOn(&build_level.step);
    assets_step.dependOn(&pack_smashable_ice_6c.step);

    const pack_smashable_ice_7z = beginCachedPythonCommand(b, "smashable_ice_7z", "tools/pack_smashable_ice_obj.py");
    addCacheInput(b, pack_smashable_ice_7z, "assets/7z-smashable-wall.png");
    addCacheInputPath(pack_smashable_ice_7z, b.pathFromRoot("src/generated/assets/chapters/prologue_city_7z/bg_palette.bin"));
    addCacheOutput(b, pack_smashable_ice_7z, "src/generated/assets/entities/smashable_ice_7z/smashable_ice_7z_tiles.bin");
    addCacheOutput(b, pack_smashable_ice_7z, "src/generated/assets/entities/smashable_ice_7z/smashable_ice_7z_palette.bin");
    addCacheOutput(b, pack_smashable_ice_7z, "src/generated/assets/entities/smashable_ice_7z/smashable_ice_7z_preview.png");
    addCacheOutput(b, pack_smashable_ice_7z, "src/generated/assets/entities/smashable_ice_7z/smashable_ice_7z.json");
    finishCachedPythonCommand(b, pack_smashable_ice_7z, "tools/pack_smashable_ice_obj.py");
    pack_smashable_ice_7z.addArg("--input");
    pack_smashable_ice_7z.addArg(b.pathFromRoot("assets/7z-smashable-wall.png"));
    pack_smashable_ice_7z.addArg("--room-palette");
    pack_smashable_ice_7z.addArg(b.pathFromRoot("src/generated/assets/chapters/prologue_city_7z/bg_palette.bin"));
    pack_smashable_ice_7z.addArg("--output-dir");
    pack_smashable_ice_7z.addArg(b.pathFromRoot("src/generated/assets/entities/smashable_ice_7z"));
    pack_smashable_ice_7z.addArg("--name");
    pack_smashable_ice_7z.addArg("smashable_ice_7z");
    pack_smashable_ice_7z.step.dependOn(&build_level.step);
    assets_step.dependOn(&pack_smashable_ice_7z.step);

    const pack_smashable_dirt = beginCachedPythonCommand(b, "smashable_dirt", "tools/pack_smashable_ice_obj.py");
    addCacheInput(b, pack_smashable_dirt, "assets/smashable-dirt.png");
    addCacheInputPath(pack_smashable_dirt, b.pathFromRoot("src/generated/assets/chapters/prologue_city_6/bg_palette.bin"));
    addCacheOutput(b, pack_smashable_dirt, "src/generated/assets/entities/smashable_dirt/smashable_dirt_tiles.bin");
    addCacheOutput(b, pack_smashable_dirt, "src/generated/assets/entities/smashable_dirt/smashable_dirt_palette.bin");
    addCacheOutput(b, pack_smashable_dirt, "src/generated/assets/entities/smashable_dirt/smashable_dirt_preview.png");
    addCacheOutput(b, pack_smashable_dirt, "src/generated/assets/entities/smashable_dirt/smashable_dirt.json");
    finishCachedPythonCommand(b, pack_smashable_dirt, "tools/pack_smashable_ice_obj.py");
    pack_smashable_dirt.addArg("--input");
    pack_smashable_dirt.addArg(b.pathFromRoot("assets/smashable-dirt.png"));
    pack_smashable_dirt.addArg("--room-palette");
    pack_smashable_dirt.addArg(b.pathFromRoot("src/generated/assets/chapters/prologue_city_6/bg_palette.bin"));
    pack_smashable_dirt.addArg("--output-dir");
    pack_smashable_dirt.addArg(b.pathFromRoot("src/generated/assets/entities/smashable_dirt"));
    pack_smashable_dirt.addArg("--name");
    pack_smashable_dirt.addArg("smashable_dirt");
    pack_smashable_dirt.step.dependOn(&build_level.step);
    assets_step.dependOn(&pack_smashable_dirt.step);

    const build_overworld = beginCachedPythonCommand(b, "overworld_bg", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_overworld, "assets/overworld.png");
    addCacheOutput(b, build_overworld, "src/generated/assets/overworld/bg_tiles.bin");
    addCacheOutput(b, build_overworld, "src/generated/assets/overworld/bg_map.bin");
    addCacheOutput(b, build_overworld, "src/generated/assets/overworld/bg_palette.bin");
    addCacheOutput(b, build_overworld, "src/generated/assets/overworld/metadata.json");
    finishCachedPythonCommand(b, build_overworld, "tools/convert_room_tilemap_8bpp.py");
    build_overworld.addArg(b.pathFromRoot("assets/overworld.png"));
    build_overworld.addArg(b.pathFromRoot("src/generated/assets/overworld/bg_tiles.bin"));
    build_overworld.addArg(b.pathFromRoot("src/generated/assets/overworld/bg_map.bin"));
    build_overworld.addArg(b.pathFromRoot("src/generated/assets/overworld/bg_palette.bin"));
    build_overworld.addArg("--rgb-bits");
    build_overworld.addArg("3");
    build_overworld.addArg("--metadata-output");
    build_overworld.addArg(b.pathFromRoot("src/generated/assets/overworld/metadata.json"));
    assets_step.dependOn(&build_overworld.step);

    const build_splash1 = beginCachedPythonCommand(b, "splash1", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_splash1, "assets/splash1.png");
    addCacheOutput(b, build_splash1, "src/generated/assets/ui/splash1_tiles.bin");
    addCacheOutput(b, build_splash1, "src/generated/assets/ui/splash1_map.bin");
    addCacheOutput(b, build_splash1, "src/generated/assets/ui/splash1_palette.bin");
    addCacheOutput(b, build_splash1, "src/generated/assets/ui/splash1_metadata.json");
    finishCachedPythonCommand(b, build_splash1, "tools/convert_room_tilemap_8bpp.py");
    build_splash1.addArg(b.pathFromRoot("assets/splash1.png"));
    build_splash1.addArg(b.pathFromRoot("src/generated/assets/ui/splash1_tiles.bin"));
    build_splash1.addArg(b.pathFromRoot("src/generated/assets/ui/splash1_map.bin"));
    build_splash1.addArg(b.pathFromRoot("src/generated/assets/ui/splash1_palette.bin"));
    build_splash1.addArg("--rgb-bits");
    build_splash1.addArg("8");
    build_splash1.addArg("--metadata-output");
    build_splash1.addArg(b.pathFromRoot("src/generated/assets/ui/splash1_metadata.json"));
    assets_step.dependOn(&build_splash1.step);

    const build_splash3 = beginCachedPythonCommand(b, "splash3", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_splash3, "assets/splash3.png");
    addCacheOutput(b, build_splash3, "src/generated/assets/ui/splash3_tiles.bin");
    addCacheOutput(b, build_splash3, "src/generated/assets/ui/splash3_map.bin");
    addCacheOutput(b, build_splash3, "src/generated/assets/ui/splash3_palette.bin");
    addCacheOutput(b, build_splash3, "src/generated/assets/ui/splash3_metadata.json");
    finishCachedPythonCommand(b, build_splash3, "tools/convert_room_tilemap_8bpp.py");
    build_splash3.addArg(b.pathFromRoot("assets/splash3.png"));
    build_splash3.addArg(b.pathFromRoot("src/generated/assets/ui/splash3_tiles.bin"));
    build_splash3.addArg(b.pathFromRoot("src/generated/assets/ui/splash3_map.bin"));
    build_splash3.addArg(b.pathFromRoot("src/generated/assets/ui/splash3_palette.bin"));
    build_splash3.addArg("--rgb-bits");
    build_splash3.addArg("4");
    build_splash3.addArg("--metadata-output");
    build_splash3.addArg(b.pathFromRoot("src/generated/assets/ui/splash3_metadata.json"));
    assets_step.dependOn(&build_splash3.step);

    const prepare_file_select = beginCachedPythonCommand(b, "file_select_prepare", "tools/pack_file_select_assets.py");
    addCacheInput(b, prepare_file_select, "assets/bg-file-select.png");
    addCacheInput(b, prepare_file_select, "assets/scroll.png");
    addCacheOutput(b, prepare_file_select, "src/generated/assets/ui/file_select_bg.png");
    addCacheOutput(b, prepare_file_select, "src/generated/assets/ui/file_select_scroll_pixels.bin");
    addCacheOutput(b, prepare_file_select, "src/generated/assets/ui/file_select_scroll_palette.bin");
    addCacheOutput(b, prepare_file_select, "src/generated/assets/ui/file_select_scroll_meta.zig");
    finishCachedPythonCommand(b, prepare_file_select, "tools/pack_file_select_assets.py");
    prepare_file_select.addArg("--background");
    prepare_file_select.addArg(b.pathFromRoot("assets/bg-file-select.png"));
    prepare_file_select.addArg("--scroll");
    prepare_file_select.addArg(b.pathFromRoot("assets/scroll.png"));
    prepare_file_select.addArg("--background-output");
    prepare_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_bg.png"));
    prepare_file_select.addArg("--scroll-pixels-output");
    prepare_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_scroll_pixels.bin"));
    prepare_file_select.addArg("--scroll-palette-output");
    prepare_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_scroll_palette.bin"));
    prepare_file_select.addArg("--scroll-meta-output");
    prepare_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_scroll_meta.zig"));
    prepare_file_select.step.dependOn(&ensure_generated_assets_dir.step);
    assets_step.dependOn(&prepare_file_select.step);

    const build_file_select = beginCachedPythonCommand(b, "file_select_bg", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_file_select, "src/generated/assets/ui/file_select_bg.png");
    addCacheOutput(b, build_file_select, "src/generated/assets/ui/file_select_tiles.bin");
    addCacheOutput(b, build_file_select, "src/generated/assets/ui/file_select_map.bin");
    addCacheOutput(b, build_file_select, "src/generated/assets/ui/file_select_palette.bin");
    addCacheOutput(b, build_file_select, "src/generated/assets/ui/file_select_metadata.json");
    finishCachedPythonCommand(b, build_file_select, "tools/convert_room_tilemap_8bpp.py");
    build_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_bg.png"));
    build_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_tiles.bin"));
    build_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_map.bin"));
    build_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_palette.bin"));
    build_file_select.addArg("--rgb-bits");
    build_file_select.addArg("3");
    build_file_select.addArg("--metadata-output");
    build_file_select.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_metadata.json"));
    build_file_select.step.dependOn(&prepare_file_select.step);
    assets_step.dependOn(&build_file_select.step);

    const pack_file_select_portraits = beginCachedPythonCommand(b, "file_select_portraits", "tools/pack_file_select_portraits.py");
    addCacheInput(b, pack_file_select_portraits, "assets/portraits/tiny-madeline.png");
    addCacheOutput(b, pack_file_select_portraits, "src/generated/assets/ui/file_select_portraits_pixels.bin");
    addCacheOutput(b, pack_file_select_portraits, "src/generated/assets/ui/file_select_portraits_palette.bin");
    addCacheOutput(b, pack_file_select_portraits, "src/generated/assets/ui/file_select_portraits_meta.zig");
    finishCachedPythonCommand(b, pack_file_select_portraits, "tools/pack_file_select_portraits.py");
    pack_file_select_portraits.addArg("--input");
    pack_file_select_portraits.addArg(b.pathFromRoot("assets/portraits/tiny-madeline.png"));
    pack_file_select_portraits.addArg("--pixels-output");
    pack_file_select_portraits.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_portraits_pixels.bin"));
    pack_file_select_portraits.addArg("--palette-output");
    pack_file_select_portraits.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_portraits_palette.bin"));
    pack_file_select_portraits.addArg("--meta-output");
    pack_file_select_portraits.addArg(b.pathFromRoot("src/generated/assets/ui/file_select_portraits_meta.zig"));
    pack_file_select_portraits.step.dependOn(&ensure_generated_assets_dir.step);
    assets_step.dependOn(&pack_file_select_portraits.step);

    const build_title_screen = beginCachedPythonCommand(b, "title_screen", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_title_screen, "assets/title2.png");
    addCacheOutput(b, build_title_screen, "src/generated/assets/ui/title_screen_tiles.bin");
    addCacheOutput(b, build_title_screen, "src/generated/assets/ui/title_screen_map.bin");
    addCacheOutput(b, build_title_screen, "src/generated/assets/ui/title_screen_palette.bin");
    addCacheOutput(b, build_title_screen, "src/generated/assets/ui/title_screen_metadata.json");
    finishCachedPythonCommand(b, build_title_screen, "tools/convert_room_tilemap_8bpp.py");
    build_title_screen.addArg(b.pathFromRoot("assets/title2.png"));
    build_title_screen.addArg(b.pathFromRoot("src/generated/assets/ui/title_screen_tiles.bin"));
    build_title_screen.addArg(b.pathFromRoot("src/generated/assets/ui/title_screen_map.bin"));
    build_title_screen.addArg(b.pathFromRoot("src/generated/assets/ui/title_screen_palette.bin"));
    build_title_screen.addArg("--rgb-bits");
    build_title_screen.addArg("3");
    build_title_screen.addArg("--metadata-output");
    build_title_screen.addArg(b.pathFromRoot("src/generated/assets/ui/title_screen_metadata.json"));
    assets_step.dependOn(&build_title_screen.step);

    const pack_bitmap_font = beginCachedPythonCommand(b, "bitmap_font", "tools/pack_bitmap_font.py");
    addCacheInput(b, pack_bitmap_font, "assets/font.png");
    addCacheOutput(b, pack_bitmap_font, "src/generated/assets/ui/bitmap_font_masks.bin");
    addCacheOutput(b, pack_bitmap_font, "src/generated/assets/ui/bitmap_font_meta.zig");
    finishCachedPythonCommand(b, pack_bitmap_font, "tools/pack_bitmap_font.py");
    pack_bitmap_font.addArg("--input");
    pack_bitmap_font.addArg(b.pathFromRoot("assets/font.png"));
    pack_bitmap_font.addArg("--output");
    pack_bitmap_font.addArg(b.pathFromRoot("src/generated/assets/ui/bitmap_font_masks.bin"));
    pack_bitmap_font.addArg("--meta-output");
    pack_bitmap_font.addArg(b.pathFromRoot("src/generated/assets/ui/bitmap_font_meta.zig"));
    pack_bitmap_font.step.dependOn(&ensure_generated_assets_dir.step);
    assets_step.dependOn(&pack_bitmap_font.step);

    const prepare_overworld_icons = beginCachedPythonCommand(b, "overworld_icons_prepare", "tools/prepare_overworld_icons.py");
    addCacheInputDir(b, prepare_overworld_icons, "assets/icons");
    addCacheInput(b, prepare_overworld_icons, "assets/overworld.png");
    addCacheOutputDir(b, prepare_overworld_icons, "assets/generated/overworld/icons");
    finishCachedPythonCommand(b, prepare_overworld_icons, "tools/prepare_overworld_icons.py");
    prepare_overworld_icons.addArg("--input-dir");
    prepare_overworld_icons.addArg(b.pathFromRoot("assets/icons"));
    prepare_overworld_icons.addArg("--output-dir");
    prepare_overworld_icons.addArg(b.pathFromRoot("assets/generated/overworld/icons"));
    prepare_overworld_icons.addArg("--background");
    prepare_overworld_icons.addArg(b.pathFromRoot("assets/overworld.png"));
    assets_step.dependOn(&prepare_overworld_icons.step);

    const build_overworld_page0 = beginCachedPythonCommand(b, "overworld_page0", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_overworld_page0, "assets/generated/overworld/icons/pages/page_0_bg.png");
    addCacheOutput(b, build_overworld_page0, "src/generated/assets/overworld/page0_tiles.bin");
    addCacheOutput(b, build_overworld_page0, "src/generated/assets/overworld/page0_map.bin");
    addCacheOutput(b, build_overworld_page0, "src/generated/assets/overworld/page0_palette.bin");
    addCacheOutput(b, build_overworld_page0, "src/generated/assets/overworld/page0_metadata.json");
    finishCachedPythonCommand(b, build_overworld_page0, "tools/convert_room_tilemap_8bpp.py");
    build_overworld_page0.addArg(b.pathFromRoot("assets/generated/overworld/icons/pages/page_0_bg.png"));
    build_overworld_page0.addArg(b.pathFromRoot("src/generated/assets/overworld/page0_tiles.bin"));
    build_overworld_page0.addArg(b.pathFromRoot("src/generated/assets/overworld/page0_map.bin"));
    build_overworld_page0.addArg(b.pathFromRoot("src/generated/assets/overworld/page0_palette.bin"));
    build_overworld_page0.addArg("--rgb-bits");
    build_overworld_page0.addArg("3");
    build_overworld_page0.addArg("--metadata-output");
    build_overworld_page0.addArg(b.pathFromRoot("src/generated/assets/overworld/page0_metadata.json"));
    build_overworld_page0.step.dependOn(&prepare_overworld_icons.step);
    assets_step.dependOn(&build_overworld_page0.step);

    const build_overworld_page1 = beginCachedPythonCommand(b, "overworld_page1", "tools/convert_room_tilemap_8bpp.py");
    addCacheInput(b, build_overworld_page1, "assets/generated/overworld/icons/pages/page_1_bg.png");
    addCacheOutput(b, build_overworld_page1, "src/generated/assets/overworld/page1_tiles.bin");
    addCacheOutput(b, build_overworld_page1, "src/generated/assets/overworld/page1_map.bin");
    addCacheOutput(b, build_overworld_page1, "src/generated/assets/overworld/page1_palette.bin");
    addCacheOutput(b, build_overworld_page1, "src/generated/assets/overworld/page1_metadata.json");
    finishCachedPythonCommand(b, build_overworld_page1, "tools/convert_room_tilemap_8bpp.py");
    build_overworld_page1.addArg(b.pathFromRoot("assets/generated/overworld/icons/pages/page_1_bg.png"));
    build_overworld_page1.addArg(b.pathFromRoot("src/generated/assets/overworld/page1_tiles.bin"));
    build_overworld_page1.addArg(b.pathFromRoot("src/generated/assets/overworld/page1_map.bin"));
    build_overworld_page1.addArg(b.pathFromRoot("src/generated/assets/overworld/page1_palette.bin"));
    build_overworld_page1.addArg("--rgb-bits");
    build_overworld_page1.addArg("3");
    build_overworld_page1.addArg("--metadata-output");
    build_overworld_page1.addArg(b.pathFromRoot("src/generated/assets/overworld/page1_metadata.json"));
    build_overworld_page1.step.dependOn(&prepare_overworld_icons.step);
    assets_step.dependOn(&build_overworld_page1.step);

    const pack_overworld_icons = beginCachedPythonCommand(b, "overworld_icons_pack", "tools/pack_overworld_icons.py");
    addCacheInputDir(b, pack_overworld_icons, "assets/generated/overworld/icons");
    addCacheOutput(b, pack_overworld_icons, "src/generated/assets/overworld/overworld_icon_tiles.bin");
    addCacheOutput(b, pack_overworld_icons, "src/generated/assets/overworld/overworld_icon_palettes.bin");
    addCacheOutput(b, pack_overworld_icons, "src/generated/assets/overworld/overworld_icon_meta.zig");
    finishCachedPythonCommand(b, pack_overworld_icons, "tools/pack_overworld_icons.py");
    pack_overworld_icons.addArg("--manifest");
    pack_overworld_icons.addArg(b.pathFromRoot("assets/generated/overworld/icons/manifest.json"));
    pack_overworld_icons.addArg("--output-dir");
    pack_overworld_icons.addArg(b.pathFromRoot("src/generated/assets/overworld"));
    pack_overworld_icons.step.dependOn(&prepare_overworld_icons.step);
    assets_step.dependOn(&pack_overworld_icons.step);

    const pack_player_animations = beginCachedPythonCommand(b, "player_animations", "tools/pack_player_obj_tiles.py");
    addCacheInputDir(b, pack_player_animations, "assets/animations/player");
    addCacheOutput(b, pack_player_animations, "src/generated/assets/player/madeline_tiles.bin");
    addCacheOutput(b, pack_player_animations, "src/generated/assets/player/madeline_hair_anchors.bin");
    addCacheOutput(b, pack_player_animations, "src/generated/assets/player/madeline_palette.bin");
    addCacheOutput(b, pack_player_animations, "src/generated/assets/player/madeline_animations.json");
    finishCachedPythonCommand(b, pack_player_animations, "tools/pack_player_obj_tiles.py");
    pack_player_animations.addArg("--input");
    pack_player_animations.addArg(b.pathFromRoot("assets/animations/player"));
    pack_player_animations.addArg("--output-dir");
    pack_player_animations.addArg(b.pathFromRoot("src/generated/assets/player"));
    pack_player_animations.addArg("--animations");
    pack_player_animations.addArg("idleLoop:idleA");
    pack_player_animations.addArg("idleLoop:idleB");
    pack_player_animations.addArg("idleLoop:idleA");
    pack_player_animations.addArg("idleLoop:idleB");
    pack_player_animations.addArg("idleLoop:idleC");
    pack_player_animations.addArg("runSlow");
    pack_player_animations.addArg("jumpSlow");
    pack_player_animations.addArg("fallSlow");
    pack_player_animations.addArg("wallslide");
    pack_player_animations.addArg("climbup");
    pack_player_animations.addArg("dangling");
    pack_player_animations.addArg("climbPull");
    if (player_death_animations.deadown_frame_count != 0) {
        pack_player_animations.addArg(player_death_animations.deadown_arg);
    }
    if (player_death_animations.deathside_frame_count != 0) {
        pack_player_animations.addArg(player_death_animations.deathside_arg);
    }
    if (player_death_animations.deathup_frame_count != 0) {
        pack_player_animations.addArg(player_death_animations.deathup_arg);
    }
    assets_step.dependOn(&pack_player_animations.step);

    const pack_player_sweat = beginCachedPythonCommand(b, "player_sweat", "tools/pack_player_obj_tiles.py");
    addCacheInputDir(b, pack_player_sweat, "assets/animations/player_sweat");
    addCacheOutput(b, pack_player_sweat, "src/generated/assets/player_sweat/madeline_tiles.bin");
    addCacheOutput(b, pack_player_sweat, "src/generated/assets/player_sweat/madeline_hair_anchors.bin");
    addCacheOutput(b, pack_player_sweat, "src/generated/assets/player_sweat/madeline_palette.bin");
    addCacheOutput(b, pack_player_sweat, "src/generated/assets/player_sweat/madeline_animations.json");
    finishCachedPythonCommand(b, pack_player_sweat, "tools/pack_player_obj_tiles.py");
    pack_player_sweat.addArg("--input");
    pack_player_sweat.addArg(b.pathFromRoot("assets/animations/player_sweat"));
    pack_player_sweat.addArg("--output-dir");
    pack_player_sweat.addArg(b.pathFromRoot("src/generated/assets/player_sweat"));
    pack_player_sweat.addArg("--animations");
    pack_player_sweat.addArg("still");
    pack_player_sweat.addArg("climbLoop");
    pack_player_sweat.addArg("jump");
    assets_step.dependOn(&pack_player_sweat.step);

    const pack_falling_block = beginCachedPythonCommand(b, "falling_block", "tools/pack_falling_block_obj.py");
    addCacheInput(b, pack_falling_block, "assets/chapters/prologue_a/prologue-a-block1.png");
    addCacheOutput(b, pack_falling_block, "src/generated/assets/entities/prologue_a/falling_block_tiles.bin");
    addCacheOutput(b, pack_falling_block, "src/generated/assets/entities/prologue_a/falling_block_palette.bin");
    addCacheOutput(b, pack_falling_block, "src/generated/assets/entities/prologue_a/falling_block.json");
    finishCachedPythonCommand(b, pack_falling_block, "tools/pack_falling_block_obj.py");
    pack_falling_block.addArg("--input");
    pack_falling_block.addArg(b.pathFromRoot("assets/chapters/prologue_a/prologue-a-block1.png"));
    pack_falling_block.addArg("--output-dir");
    pack_falling_block.addArg(b.pathFromRoot("src/generated/assets/entities/prologue_a"));
    assets_step.dependOn(&pack_falling_block.step);

    const pack_bridge = beginCachedPythonCommand(b, "prologue_bridge", "tools/pack_prologue_bridge.py");
    addCacheInputDir(b, pack_bridge, "assets/source/prologue-bridge/chunks_8px");
    addCacheOutput(b, pack_bridge, "src/generated/assets/entities/prologue_bridge/bridge_tiles.bin");
    addCacheOutput(b, pack_bridge, "src/generated/assets/entities/prologue_bridge/bridge_palette.bin");
    addCacheOutput(b, pack_bridge, "src/generated/assets/entities/prologue_bridge/bridge_layout.bin");
    addCacheOutput(b, pack_bridge, "src/generated/assets/entities/prologue_bridge/bridge_groups.bin");
    addCacheOutput(b, pack_bridge, "src/generated/assets/entities/prologue_bridge/bridge.json");
    finishCachedPythonCommand(b, pack_bridge, "tools/pack_prologue_bridge.py");
    pack_bridge.addArg("--input-dir");
    pack_bridge.addArg(b.pathFromRoot("assets/source/prologue-bridge/chunks_8px"));
    pack_bridge.addArg("--output-dir");
    pack_bridge.addArg(b.pathFromRoot("src/generated/assets/entities/prologue_bridge"));
    assets_step.dependOn(&pack_bridge.step);

    const pack_funny_car = beginCachedPythonCommand(b, "funny_car", "tools/pack_funny_car_obj.py");
    addCacheInput(b, pack_funny_car, "assets/chapters/prologue_a/stamps/funny-car.png");
    addCacheOutput(b, pack_funny_car, "src/generated/assets/entities/prologue_a/funny_car_tiles.bin");
    addCacheOutput(b, pack_funny_car, "src/generated/assets/entities/prologue_a/funny_car_palette.bin");
    addCacheOutput(b, pack_funny_car, "src/generated/assets/entities/prologue_a/funny_car.json");
    finishCachedPythonCommand(b, pack_funny_car, "tools/pack_funny_car_obj.py");
    pack_funny_car.addArg("--input");
    pack_funny_car.addArg(b.pathFromRoot("assets/chapters/prologue_a/stamps/funny-car.png"));
    pack_funny_car.addArg("--output-dir");
    pack_funny_car.addArg(b.pathFromRoot("src/generated/assets/entities/prologue_a"));
    assets_step.dependOn(&pack_funny_car.step);

    const pack_disappearing_platform = beginCachedPythonCommand(b, "disappearing_platform", "tools/pack_disappearing_platform_obj.py");
    addCacheInput(b, pack_disappearing_platform, "assets/falling-blocks.png");
    addCacheOutput(b, pack_disappearing_platform, "src/generated/assets/entities/disappearing_platform/disappearing_platform_tiles.bin");
    addCacheOutput(b, pack_disappearing_platform, "src/generated/assets/entities/disappearing_platform/disappearing_platform_palette.bin");
    addCacheOutput(b, pack_disappearing_platform, "src/generated/assets/entities/disappearing_platform/disappearing_platform.json");
    finishCachedPythonCommand(b, pack_disappearing_platform, "tools/pack_disappearing_platform_obj.py");
    pack_disappearing_platform.addArg("--input");
    pack_disappearing_platform.addArg(b.pathFromRoot("assets/falling-blocks.png"));
    pack_disappearing_platform.addArg("--output-dir");
    pack_disappearing_platform.addArg(b.pathFromRoot("src/generated/assets/entities/disappearing_platform"));
    assets_step.dependOn(&pack_disappearing_platform.step);

    const pack_strawberry = beginCachedPythonCommand(b, "strawberry", "tools/pack_strawberry_obj.py");
    addCacheInputDir(b, pack_strawberry, "assets/animations/strawberry");
    addCacheOutputDir(b, pack_strawberry, "src/generated/assets/entities/strawberry");
    finishCachedPythonCommand(b, pack_strawberry, "tools/pack_strawberry_obj.py");
    pack_strawberry.addArg("--input");
    pack_strawberry.addArg(b.pathFromRoot("assets/animations/strawberry"));
    pack_strawberry.addArg("--output-dir");
    pack_strawberry.addArg(b.pathFromRoot("src/generated/assets/entities/strawberry"));
    assets_step.dependOn(&pack_strawberry.step);

    const pack_ghostberry = beginCachedPythonCommand(b, "ghostberry", "tools/pack_strawberry_obj.py");
    addCacheInputDir(b, pack_ghostberry, "assets/animations/ghostberry");
    addCacheOutputDir(b, pack_ghostberry, "src/generated/assets/entities/ghostberry");
    finishCachedPythonCommand(b, pack_ghostberry, "tools/pack_strawberry_obj.py");
    pack_ghostberry.addArg("--input");
    pack_ghostberry.addArg(b.pathFromRoot("assets/animations/ghostberry"));
    pack_ghostberry.addArg("--output-dir");
    pack_ghostberry.addArg(b.pathFromRoot("src/generated/assets/entities/ghostberry"));
    pack_ghostberry.addArg("--name");
    pack_ghostberry.addArg("ghostberry");
    assets_step.dependOn(&pack_ghostberry.step);

    const pack_spring = beginCachedPythonCommand(b, "spring", "tools/pack_spring_obj.py");
    addCacheInputDir(b, pack_spring, "assets/animations/spring");
    addCacheOutput(b, pack_spring, "src/generated/assets/entities/spring/spring_tiles.bin");
    addCacheOutput(b, pack_spring, "src/generated/assets/entities/spring/spring_palette.bin");
    addCacheOutput(b, pack_spring, "src/generated/assets/entities/spring/spring.json");
    finishCachedPythonCommand(b, pack_spring, "tools/pack_spring_obj.py");
    pack_spring.addArg("--input-dir");
    pack_spring.addArg(b.pathFromRoot("assets/animations/spring"));
    pack_spring.addArg("--output-dir");
    pack_spring.addArg(b.pathFromRoot("src/generated/assets/entities/spring"));
    assets_step.dependOn(&pack_spring.step);

    const pack_dash_refill = beginCachedPythonCommand(b, "dash_refill", "tools/pack_dash_refill_obj.py");
    addCacheInputDir(b, pack_dash_refill, "assets/animations/refill");
    addCacheOutput(b, pack_dash_refill, "src/generated/assets/entities/dash_refill/dash_refill_tiles.bin");
    addCacheOutput(b, pack_dash_refill, "src/generated/assets/entities/dash_refill/dash_refill_palette.bin");
    addCacheOutput(b, pack_dash_refill, "src/generated/assets/entities/dash_refill/dash_refill_meta.zig");
    addCacheOutput(b, pack_dash_refill, "src/generated/assets/entities/dash_refill/dash_refill.json");
    finishCachedPythonCommand(b, pack_dash_refill, "tools/pack_dash_refill_obj.py");
    pack_dash_refill.addArg("--input-dir");
    pack_dash_refill.addArg(b.pathFromRoot("assets/animations/refill"));
    pack_dash_refill.addArg("--output-dir");
    pack_dash_refill.addArg(b.pathFromRoot("src/generated/assets/entities/dash_refill"));
    assets_step.dependOn(&pack_dash_refill.step);

    const pack_speech_bubbles = beginCachedPythonCommand(b, "speech_bubbles", "tools/pack_speech_bubbles_obj.py");
    addCacheInput(b, pack_speech_bubbles, "assets/speech-bubble-idle.png");
    addCacheInput(b, pack_speech_bubbles, "assets/speech-bubble-a.png");
    addCacheOutput(b, pack_speech_bubbles, "src/generated/assets/ui/speech_bubble_tiles.bin");
    addCacheOutput(b, pack_speech_bubbles, "src/generated/assets/ui/speech_bubble_palette.bin");
    addCacheOutput(b, pack_speech_bubbles, "src/generated/assets/ui/speech_bubble_meta.zig");
    addCacheOutput(b, pack_speech_bubbles, "src/generated/assets/ui/speech_bubble.json");
    finishCachedPythonCommand(b, pack_speech_bubbles, "tools/pack_speech_bubbles_obj.py");
    pack_speech_bubbles.addArg("--idle");
    pack_speech_bubbles.addArg(b.pathFromRoot("assets/speech-bubble-idle.png"));
    pack_speech_bubbles.addArg("--prompt");
    pack_speech_bubbles.addArg(b.pathFromRoot("assets/speech-bubble-a.png"));
    pack_speech_bubbles.addArg("--output-dir");
    pack_speech_bubbles.addArg(b.pathFromRoot("src/generated/assets/ui"));
    assets_step.dependOn(&pack_speech_bubbles.step);

    const pack_textbox = beginCachedPythonCommand(b, "textbox", "tools/pack_textbox_obj.py");
    addCacheInput(b, pack_textbox, "assets/textbox.png");
    addCacheOutput(b, pack_textbox, "src/generated/assets/ui/textbox_tiles.bin");
    addCacheOutput(b, pack_textbox, "src/generated/assets/ui/textbox_palette.bin");
    addCacheOutput(b, pack_textbox, "src/generated/assets/ui/textbox_meta.zig");
    addCacheOutput(b, pack_textbox, "src/generated/assets/ui/textbox.json");
    finishCachedPythonCommand(b, pack_textbox, "tools/pack_textbox_obj.py");
    pack_textbox.addArg("--input");
    pack_textbox.addArg(b.pathFromRoot("assets/textbox.png"));
    pack_textbox.addArg("--output-dir");
    pack_textbox.addArg(b.pathFromRoot("src/generated/assets/ui"));
    assets_step.dependOn(&pack_textbox.step);

    const pack_cassette = beginCachedPythonCommand(b, "cassette", "tools/pack_cassette_obj.py");
    addCacheInput(b, pack_cassette, "assets/casette-uncollected.png");
    addCacheInput(b, pack_cassette, "assets/casette-collected.png");
    addCacheInput(b, pack_cassette, "assets/animations/bubble/f0.png");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_uncollected_tiles.bin");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_collected_tiles.bin");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_bubble_tiles.bin");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_palette.bin");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_bubble_palette.bin");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_meta.zig");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette.json");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_uncollected_preview.png");
    addCacheOutput(b, pack_cassette, "src/generated/assets/entities/cassette/cassette_collected_preview.png");
    finishCachedPythonCommand(b, pack_cassette, "tools/pack_cassette_obj.py");
    pack_cassette.addArg("--uncollected");
    pack_cassette.addArg(b.pathFromRoot("assets/casette-uncollected.png"));
    pack_cassette.addArg("--collected");
    pack_cassette.addArg(b.pathFromRoot("assets/casette-collected.png"));
    pack_cassette.addArg("--bubble");
    pack_cassette.addArg(b.pathFromRoot("assets/animations/bubble/f0.png"));
    pack_cassette.addArg("--output-dir");
    pack_cassette.addArg(b.pathFromRoot("src/generated/assets/entities/cassette"));
    assets_step.dependOn(&pack_cassette.step);

    const pack_save_icon = beginCachedPythonCommand(b, "save_icon", "tools/pack_save_icon_obj.py");
    addCacheInput(b, pack_save_icon, "assets/save_icon.png");
    addCacheOutput(b, pack_save_icon, "src/generated/assets/ui/save_icon_tiles.bin");
    addCacheOutput(b, pack_save_icon, "src/generated/assets/ui/save_icon_palette.bin");
    addCacheOutput(b, pack_save_icon, "src/generated/assets/ui/save_icon_meta.zig");
    addCacheOutput(b, pack_save_icon, "src/generated/assets/ui/save_icon.json");
    finishCachedPythonCommand(b, pack_save_icon, "tools/pack_save_icon_obj.py");
    pack_save_icon.addArg("--input");
    pack_save_icon.addArg(b.pathFromRoot("assets/save_icon.png"));
    pack_save_icon.addArg("--output-dir");
    pack_save_icon.addArg(b.pathFromRoot("src/generated/assets/ui"));
    assets_step.dependOn(&pack_save_icon.step);

    const pack_hair = beginCachedPythonCommand(b, "hair", "tools/pack_hair_obj.py");
    addCacheInputDir(b, pack_hair, "assets/animations/hair");
    addCacheOutput(b, pack_hair, "src/generated/assets/player/hair_tiles.bin");
    addCacheOutput(b, pack_hair, "src/generated/assets/player/hair_palette.bin");
    addCacheOutput(b, pack_hair, "src/generated/assets/player/hair.json");
    finishCachedPythonCommand(b, pack_hair, "tools/pack_hair_obj.py");
    pack_hair.addArg("--input-dir");
    pack_hair.addArg(b.pathFromRoot("assets/animations/hair"));
    pack_hair.addArg("--output-dir");
    pack_hair.addArg(b.pathFromRoot("src/generated/assets/player"));
    assets_step.dependOn(&pack_hair.step);

    const pack_bird = beginCachedPythonCommand(b, "bird", "tools/pack_bird_assets.py");
    addCacheInput(b, pack_bird, "assets/source/bird/intro.png");
    addCacheInput(b, pack_bird, "assets/source/bird/fly.png");
    addCacheInput(b, pack_bird, "assets/chapters/prologue_a/hold-hint.png");
    addCacheInput(b, pack_bird, "assets/chapters/prologue_a/climb-hint.png");
    addCacheInput(b, pack_bird, "assets/chapters/prologue_a/dash-hint.png");
    addCacheOutputDir(b, pack_bird, "src/generated/assets/bird");
    finishCachedPythonCommand(b, pack_bird, "tools/pack_bird_assets.py");
    pack_bird.addArg("--intro");
    pack_bird.addArg(b.pathFromRoot("assets/source/bird/intro.png"));
    pack_bird.addArg("--fly");
    pack_bird.addArg(b.pathFromRoot("assets/source/bird/fly.png"));
    pack_bird.addArg("--hold-hint");
    pack_bird.addArg(b.pathFromRoot("assets/chapters/prologue_a/hold-hint.png"));
    pack_bird.addArg("--climb-hint");
    pack_bird.addArg(b.pathFromRoot("assets/chapters/prologue_a/climb-hint.png"));
    pack_bird.addArg("--dash-hint");
    pack_bird.addArg(b.pathFromRoot("assets/chapters/prologue_a/dash-hint.png"));
    pack_bird.addArg("--output-dir");
    pack_bird.addArg(b.pathFromRoot("src/generated/assets/bird"));
    assets_step.dependOn(&pack_bird.step);

    const pack_tiny_bird = beginCachedPythonCommand(b, "tiny_bird", "tools/pack_tiny_bird_assets.py");
    addCacheInputDir(b, pack_tiny_bird, "assets/animations/tiny_bird");
    addCacheOutput(b, pack_tiny_bird, "src/generated/assets/tiny_bird/tiny_bird_tiles.bin");
    addCacheOutput(b, pack_tiny_bird, "src/generated/assets/tiny_bird/tiny_bird_palette.bin");
    addCacheOutput(b, pack_tiny_bird, "src/generated/assets/tiny_bird/tiny_bird.json");
    finishCachedPythonCommand(b, pack_tiny_bird, "tools/pack_tiny_bird_assets.py");
    pack_tiny_bird.addArg("--input-dir");
    pack_tiny_bird.addArg(b.pathFromRoot("assets/animations/tiny_bird"));
    pack_tiny_bird.addArg("--output-dir");
    pack_tiny_bird.addArg(b.pathFromRoot("src/generated/assets/tiny_bird"));
    assets_step.dependOn(&pack_tiny_bird.step);

    const pack_granny = beginCachedPythonCommand(b, "granny", "tools/pack_granny_assets.py");
    addCacheInputDir(b, pack_granny, "assets/animations/granny");
    addCacheInputDir(b, pack_granny, "assets/portraits/granny");
    addCacheInputDir(b, pack_granny, "assets/portraits/madeline");
    addCacheOutputDir(b, pack_granny, "src/generated/assets/granny");
    finishCachedPythonCommand(b, pack_granny, "tools/pack_granny_assets.py");
    pack_granny.addArg("--input-dir");
    pack_granny.addArg(b.pathFromRoot("assets/animations/granny"));
    pack_granny.addArg("--portrait-dir");
    pack_granny.addArg(b.pathFromRoot("assets/portraits/granny"));
    pack_granny.addArg("--madeline-portrait-dir");
    pack_granny.addArg(b.pathFromRoot("assets/portraits/madeline"));
    pack_granny.addArg("--output-dir");
    pack_granny.addArg(b.pathFromRoot("src/generated/assets/granny"));
    assets_step.dependOn(&pack_granny.step);

    exe.step.step.dependOn(assets_step);

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addArg("zig-out/zeleste.gba");
    mgba.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Builds and runs the ROM in mGBA");
    run_step.dependOn(&exe.step.step);
    run_step.dependOn(&mgba.step);
}

fn beginCachedPythonCommand(b: *std.Build, job: []const u8, script: []const u8) *std.Build.Step.Run {
    const run = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/run_if_changed.py"),
        "--cache",
        b.pathFromRoot("src/generated/assets/.asset-cache.json"),
        "--job",
        job,
        "--input",
        b.pathFromRoot("tools/run_if_changed.py"),
        "--input",
        b.pathFromRoot(script),
    });
    if (!std.mem.eql(u8, script, "tools/split_foreground_tileset.py")) {
        addCacheInput(b, run, "tools/split_foreground_tileset.py");
    }
    return run;
}

fn finishCachedPythonCommand(b: *std.Build, run: *std.Build.Step.Run, script: []const u8) void {
    run.addArg("--");
    run.addArg("python3");
    run.addArg(b.pathFromRoot(script));
}

fn addCacheInput(b: *std.Build, run: *std.Build.Step.Run, path: []const u8) void {
    run.addArg("--input");
    run.addArg(b.pathFromRoot(path));
}

fn addCacheInputPath(run: *std.Build.Step.Run, path: []const u8) void {
    run.addArg("--input");
    run.addArg(path);
}

fn addCacheInputDir(b: *std.Build, run: *std.Build.Step.Run, path: []const u8) void {
    run.addArg("--input-dir");
    run.addArg(b.pathFromRoot(path));
}

fn addCacheOutput(b: *std.Build, run: *std.Build.Step.Run, path: []const u8) void {
    run.addArg("--output");
    run.addArg(b.pathFromRoot(path));
}

fn addCacheOutputPath(run: *std.Build.Step.Run, path: []const u8) void {
    run.addArg("--output");
    run.addArg(path);
}

fn addCacheOutputDir(b: *std.Build, run: *std.Build.Step.Run, path: []const u8) void {
    run.addArg("--output-dir");
    run.addArg(b.pathFromRoot(path));
}

const soundbank_sfx_files = [_][]const u8{
    "assets/audio/sfx/madeline/foot_00_asphalt_01.wav",
    "assets/audio/sfx/madeline/foot_00_asphalt_02.wav",
    "assets/audio/sfx/madeline/foot_00_asphalt_03.wav",
    "assets/audio/sfx/madeline/foot_00_asphalt_04.wav",
    "assets/audio/sfx/madeline/foot_00_asphalt_05.wav",
    "assets/audio/sfx/madeline/foot_00_asphalt_06.wav",
    "assets/audio/sfx/madeline/foot_00_asphalt_07.wav",
    "assets/audio/sfx/madeline/foot_00_car_01.wav",
    "assets/audio/sfx/madeline/foot_00_car_02.wav",
    "assets/audio/sfx/madeline/foot_00_car_03.wav",
    "assets/audio/sfx/madeline/foot_00_car_04.wav",
    "assets/audio/sfx/madeline/foot_00_car_05.wav",
    "assets/audio/sfx/madeline/foot_00_car_06.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_01.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_02.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_03.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_04.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_05.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_06.wav",
    "assets/audio/sfx/madeline/foot_00_dirt_07.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_01.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_02.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_03.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_04.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_05.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_06.wav",
    "assets/audio/sfx/madeline/foot_00_snowsoft_07.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_01.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_02.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_03.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_04.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_05.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_06.wav",
    "assets/audio/sfx/madeline/foot_00_woodwalkway_07.wav",
    "assets/audio/sfx/madeline/jump.wav",
    "assets/audio/sfx/madeline/jump_wall_left.wav",
    "assets/audio/sfx/madeline/jump_wall_right.wav",
    "assets/audio/sfx/madeline/jump_wall_climblayer_left.wav",
    "assets/audio/sfx/madeline/jump_wall_climblayer_right.wav",
    "assets/audio/sfx/madeline/dash_red_left.wav",
    "assets/audio/sfx/madeline/dash_red_right.wav",
    "assets/audio/sfx/madeline/death.wav",
    "assets/audio/sfx/madeline/grab_00_dirt_01.wav",
    "assets/audio/sfx/madeline/grab_00_dirt_02.wav",
    "assets/audio/sfx/madeline/grab_00_dirt_03.wav",
    "assets/audio/sfx/madeline/grab_00_dirt_04.wav",
    "assets/audio/sfx/madeline/grab_00_dirt_05.wav",
    "assets/audio/sfx/madeline/grab_00_snowsoft_01.wav",
    "assets/audio/sfx/madeline/grab_00_snowsoft_02.wav",
    "assets/audio/sfx/madeline/grab_00_snowsoft_03.wav",
    "assets/audio/sfx/madeline/grab_00_snowsoft_04.wav",
    "assets/audio/sfx/madeline/grab_00_snowsoft_05.wav",
    "assets/audio/sfx/madeline/land_00_asphalt_01.wav",
    "assets/audio/sfx/madeline/land_00_asphalt_02.wav",
    "assets/audio/sfx/madeline/land_00_asphalt_03.wav",
    "assets/audio/sfx/madeline/land_00_asphalt_04.wav",
    "assets/audio/sfx/madeline/land_00_asphalt_05.wav",
    "assets/audio/sfx/madeline/land_00_dirt_01.wav",
    "assets/audio/sfx/madeline/land_00_dirt_02.wav",
    "assets/audio/sfx/madeline/land_00_dirt_03.wav",
    "assets/audio/sfx/madeline/land_00_dirt_04.wav",
    "assets/audio/sfx/madeline/land_00_dirt_05.wav",
    "assets/audio/sfx/madeline/land_00_snowsoft_01.wav",
    "assets/audio/sfx/madeline/land_00_snowsoft_02.wav",
    "assets/audio/sfx/madeline/land_00_snowsoft_03.wav",
    "assets/audio/sfx/madeline/land_00_snowsoft_04.wav",
    "assets/audio/sfx/madeline/land_00_snowsoft_05.wav",
    "assets/audio/sfx/madeline/land_00_woodwalk_01.wav",
    "assets/audio/sfx/madeline/land_00_woodwalk_02.wav",
    "assets/audio/sfx/madeline/land_00_woodwalk_03.wav",
    "assets/audio/sfx/madeline/land_00_woodwalk_04.wav",
    "assets/audio/sfx/madeline/land_00_woodwalk_05.wav",
    "assets/audio/sfx/madeline/climb_ledge_01.wav",
    "assets/audio/sfx/madeline/climb_ledge_02.wav",
    "assets/audio/sfx/madeline/climb_ledge_03.wav",
    "assets/audio/sfx/madeline/climb_ledge_04.wav",
    "assets/audio/sfx/madeline/climb_ledge_05.wav",
    "assets/audio/sfx/misc/strawberry_touch.wav",
    "assets/audio/sfx/misc/strawberry_red_get_1000.wav",
    "assets/audio/sfx/misc/strawberry_red_get_2000.wav",
    "assets/audio/sfx/misc/strawberry_red_get_3000.wav",
    "assets/audio/sfx/misc/strawberry_red_get_4000.wav",
    "assets/audio/sfx/misc/strawberry_red_get_5000.wav",
    "assets/audio/sfx/misc/strawberry_red_get_1up.wav",
    "assets/audio/sfx/misc/strawberry_flyaway.wav",
    "assets/audio/sfx/misc/strawberry_wingflap_01.wav",
    "assets/audio/sfx/misc/strawberry_wingflap_02.wav",
    "assets/audio/sfx/misc/strawberry_wingflap_03.wav",
    "assets/audio/sfx/misc/diamond_touch_01.wav",
    "assets/audio/sfx/misc/diamond_touch_02.wav",
    "assets/audio/sfx/misc/diamond_touch_03.wav",
    "assets/audio/sfx/misc/diamond_return_01.wav",
    "assets/audio/sfx/misc/diamond_return_02.wav",
    "assets/audio/sfx/misc/diamond_return_03.wav",
    "assets/audio/sfx/interface/ui_main_title_firstinput.wav",
    "assets/audio/sfx/interface/ui_main_button_select.wav",
    "assets/audio/sfx/interface/ui_main_button_back.wav",
    "assets/audio/sfx/interface/ui_main_button_invalid.wav",
    "assets/audio/sfx/interface/ui_main_roll_up.wav",
    "assets/audio/sfx/interface/ui_main_roll_down.wav",
    "assets/audio/sfx/interface/ui_main_whoosh_savefile_in.wav",
    "assets/audio/sfx/interface/ui_main_whoosh_savefile_out.wav",
    "assets/audio/sfx/interface/ui_main_savefile_roll_01.wav",
    "assets/audio/sfx/interface/ui_main_savefile_roll_02.wav",
    "assets/audio/sfx/interface/ui_main_savefile_roll_03.wav",
    "assets/audio/sfx/interface/ui_main_savefile_delete.wav",
    "assets/audio/sfx/interface/ui_world_icon_roll_left.wav",
    "assets/audio/sfx/interface/ui_world_icon_roll_right.wav",
    "assets/audio/sfx/interface/ui_world_icon_flip_left.wav",
    "assets/audio/sfx/interface/ui_world_icon_flip_right.wav",
    "assets/audio/sfx/interface/ui_world_chapter_level_select.wav",
    "assets/audio/sfx/interface/ui_game_textbox_madeline_in.wav",
    "assets/audio/sfx/interface/ui_game_textbox_madeline_out.wav",
    "assets/audio/sfx/interface/ui_game_textbox_other_in.wav",
    "assets/audio/sfx/interface/ui_game_textbox_other_out.wav",
    "assets/audio/sfx/interface/ui_game_textadvance_madeline.wav",
    "assets/audio/sfx/interface/ui_game_textadvance_other.wav",
    "assets/audio/sfx/interface/ui_game_text_general.wav",
    "assets/audio/sfx/characters/madeline/madeline_normal_mid_A_01.wav",
    "assets/audio/sfx/characters/madeline/madeline_normal_mid_A_02.wav",
    "assets/audio/sfx/characters/madeline/madeline_normal_mid_A_03.wav",
    "assets/audio/sfx/characters/madeline/madeline_normal_mid_A_04.wav",
    "assets/audio/sfx/characters/madeline/madeline_normal_mid_A_05.wav",
    "assets/audio/sfx/characters/madeline/madeline_angry_mid_A_01.wav",
    "assets/audio/sfx/characters/madeline/madeline_angry_mid_A_02.wav",
    "assets/audio/sfx/characters/madeline/madeline_angry_mid_A_03.wav",
    "assets/audio/sfx/characters/madeline/madeline_angry_mid_A_04.wav",
    "assets/audio/sfx/characters/madeline/madeline_angry_mid_A_05.wav",
    "assets/audio/sfx/characters/madeline/madeline_sad_mid_A_01.wav",
    "assets/audio/sfx/characters/madeline/madeline_sad_mid_A_02.wav",
    "assets/audio/sfx/characters/madeline/madeline_sad_mid_A_03.wav",
    "assets/audio/sfx/characters/madeline/madeline_sad_mid_A_04.wav",
    "assets/audio/sfx/characters/madeline/madeline_sad_mid_A_05.wav",
    "assets/audio/sfx/characters/granny/granny_normal_mid_A_01.wav",
    "assets/audio/sfx/characters/granny/granny_normal_mid_A_02.wav",
    "assets/audio/sfx/characters/granny/granny_normal_mid_A_03.wav",
    "assets/audio/sfx/characters/granny/granny_normal_mid_A_04.wav",
    "assets/audio/sfx/characters/granny/granny_normal_mid_A_05.wav",
    "assets/audio/sfx/characters/granny/granny_mock_mid_A_01.wav",
    "assets/audio/sfx/characters/granny/granny_mock_mid_A_02.wav",
    "assets/audio/sfx/characters/granny/granny_mock_mid_A_03.wav",
    "assets/audio/sfx/characters/granny/granny_mock_mid_A_04.wav",
    "assets/audio/sfx/characters/granny/granny_mock_mid_A_05.wav",
    "assets/audio/sfx/characters/granny/granny_laugh_mid_A_01.wav",
    "assets/audio/sfx/characters/granny/granny_laugh_mid_A_02.wav",
    "assets/audio/sfx/characters/granny/granny_laugh_mid_A_03.wav",
    "assets/audio/sfx/characters/granny/granny_laugh_mid_A_04.wav",
    "assets/audio/sfx/characters/granny/granny_laugh_mid_A_05.wav",
    "assets/audio/sfx/movers/fallingblock_prologue_shake.wav",
    "assets/audio/sfx/movers/fallingblock_prologue_release.wav",
    "assets/audio/sfx/movers/fallingblock_prologue_impact.wav",
    "assets/audio/sfx/movers/zipmover_a_touch_01_001.wav",
    "assets/audio/sfx/movers/zipmover_b_impact_01_001.wav",
    "assets/audio/sfx/movers/zipmover_c_return_01_001.wav",
    "assets/audio/sfx/movers/zipmover_d_reset_01_001.wav",
};

const StartArgs = struct {
    override: bool = false,
    chapter: i32 = -1,
    room: []const u8 = "",
};

const PlayerDeathAnimationLayout = struct {
    deadown_arg: []const u8,
    deadown_first_frame: u16,
    deadown_frame_count: u16,
    deathside_arg: []const u8,
    deathside_first_frame: u16,
    deathside_frame_count: u16,
    deathup_arg: []const u8,
    deathup_first_frame: u16,
    deathup_frame_count: u16,
};

const PlayerAnimationSource = struct {
    arg: []const u8 = "",
    count: u16 = 0,
};

const PlayerAnimationCandidate = struct {
    path: []const u8,
    arg: []const u8,
};

fn playerDeathAnimationLayout(b: *std.Build) PlayerDeathAnimationLayout {
    const base_player_frame_count: u16 = 121;
    const deadown = findAnimationSource(b, &.{
        .{ .path = "assets/animations/player/deadown", .arg = "deadown" },
        .{ .path = "assets/animations/player/deaddown", .arg = "deadown:deaddown" },
        .{ .path = "assets/animations/deadown", .arg = "deadown:../deadown" },
        .{ .path = "assets/animations/deaddown", .arg = "deadown:../deaddown" },
    });
    const deathside = findAnimationSource(b, &.{
        .{ .path = "assets/animations/player/deathside", .arg = "deathside" },
        .{ .path = "assets/animations/player/deadside", .arg = "deathside:deadside" },
        .{ .path = "assets/animations/deathside", .arg = "deathside:../deathside" },
        .{ .path = "assets/animations/deadside", .arg = "deathside:../deadside" },
    });
    const deathup = findAnimationSource(b, &.{
        .{ .path = "assets/animations/player/deathup", .arg = "deathup" },
        .{ .path = "assets/animations/player/deadup", .arg = "deathup:deadup" },
        .{ .path = "assets/animations/deathup", .arg = "deathup:../deathup" },
        .{ .path = "assets/animations/deadup", .arg = "deathup:../deadup" },
    });
    const deathside_first = base_player_frame_count + deadown.count;
    const deathup_first = deathside_first + deathside.count;
    return .{
        .deadown_arg = deadown.arg,
        .deadown_first_frame = base_player_frame_count,
        .deadown_frame_count = deadown.count,
        .deathside_arg = deathside.arg,
        .deathside_first_frame = deathside_first,
        .deathside_frame_count = deathside.count,
        .deathup_arg = deathup.arg,
        .deathup_first_frame = deathup_first,
        .deathup_frame_count = deathup.count,
    };
}

fn findAnimationSource(b: *std.Build, candidates: []const PlayerAnimationCandidate) PlayerAnimationSource {
    for (candidates) |candidate| {
        const count = countAnimationFrames(b, candidate.path);
        if (count != 0) return .{ .arg = candidate.arg, .count = count };
    }
    return .{};
}

fn countAnimationFrames(b: *std.Build, path: []const u8) u16 {
    const io = b.graph.io;
    var dir = std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return 0;
    defer dir.close(io);

    var count: u16 = 0;
    var iterator = dir.iterate();
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.startsWith(u8, entry.name, "f")) continue;
        if (!std.mem.endsWith(u8, entry.name, ".png")) continue;
        count += 1;
    }
    return count;
}

fn parseStartArgs(b: *std.Build) StartArgs {
    const args = b.args orelse return .{};
    if (args.len == 0) return .{};
    if (args.len != 2) {
        std.debug.panic("development start override expects: <chapter> <room>, for example: zig build run -- 0 -1", .{});
    }

    return .{
        .override = true,
        .chapter = std.fmt.parseInt(i32, args[0], 10) catch |err| {
            std.debug.panic("invalid start chapter '{s}': {}", .{ args[0], err });
        },
        .room = b.dupe(args[1]),
    };
}
