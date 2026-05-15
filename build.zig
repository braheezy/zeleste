const std = @import("std");
const ziggba = @import("ziggba");
const color = ziggba.color;

pub fn build(b: *std.Build) void {
    const gba_b = ziggba.GbaBuild.create(b);

    const exe = gba_b.addExecutable(.{
        .name = "zeleste",
        .root_source_file = b.path("src/main.zig"),
    });

    const assets_step = b.step("assets", "Build generated game assets");

    const prologue_a_1_bg = b.addSystemCommand(&.{
        "python3",
        "tools/build_room_bundle.py",
        "assets/backgrounds/prologue-a_1.png",
        "assets/generated/rooms/prologue_a_1",
    });
    assets_step.dependOn(&prologue_a_1_bg.step);

    const prologue_a_2_bg = b.addSystemCommand(&.{
        "python3",
        "tools/build_room_bundle.py",
        "assets/backgrounds/prologue-a_2.png",
        "assets/generated/rooms/prologue_a_2",
    });
    assets_step.dependOn(&prologue_a_2_bg.step);

    const extract_player_sprite = b.addSystemCommand(&.{
        "python3",
        "tools/extract_player_sprite.py",
        "madeline-sprites.zip",
        "Raw/player/idle00.png",
        "assets/generated/player/idle00_16x16.png",
    });
    const player_colors = b.allocator.dupe(color.ColorRgba32, &.{
        .transparent,
        .rgb(4, 0, 0),
        .rgb(63, 63, 116),
        .rgb(66, 80, 95),
        .rgb(69, 40, 60),
        .rgb(91, 110, 225),
        .rgb(103, 119, 136),
        .rgb(135, 55, 36),
        .rgb(217, 160, 102),
        .rgb(238, 195, 154),
        .transparent,
        .transparent,
        .transparent,
        .transparent,
        .transparent,
        .transparent,
    }) catch @panic("OOM");
    const player_pal = color.PalettizerNearest.create(b.allocator, player_colors) catch @panic("OOM");
    const player_tiles = gba_b.addConvertImageTiles4BppStep(.{
        .name = "Convert player idle sprite",
        .image_path = "assets/generated/player/idle00_16x16.png",
        .output_path = "assets/generated/player/idle00_tiles.bin",
        .options = .{
            .palettizer = player_pal.pal(),
        },
    });
    player_tiles.step.dependOn(&extract_player_sprite.step);
    const player_palette = gba_b.addSaveQuantizedPalettizerPaletteStep(.{
        .name = "Save player sprite palette",
        .palettizer = player_pal.pal(),
        .output_path = "assets/generated/player/palette.bin",
    });
    assets_step.dependOn(&player_tiles.step);
    assets_step.dependOn(&player_palette.step);

    exe.dependOn(assets_step);
    exe.step.root_module.addAnonymousImport("prologue_a_1_bg_tiles.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_1/bg_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_1_bg_map.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_1/bg_map.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_1_bg_palette.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_1/bg_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_1_collision.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_1/collision.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_2_bg_tiles.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_2/bg_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_2_bg_map.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_2/bg_map.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_2_bg_palette.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_2/bg_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_a_2_collision.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_a_2/collision.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_idle_tiles.bin", .{
        .root_source_file = b.path("assets/generated/player/idle00_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_palette.bin", .{
        .root_source_file = b.path("assets/generated/player/palette.bin"),
    });

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addArg("zig-out/zeleste.gba");
    mgba.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Builds and runs the ROM in mGBA");
    run_step.dependOn(&exe.step.step);
    run_step.dependOn(&mgba.step);
}
