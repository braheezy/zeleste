const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    const gba_b = ziggba.GbaBuild.create(b);

    const exe = gba_b.addExecutable(.{
        .name = "zeleste",
        .root_source_file = b.path("src/main.zig"),
    });

    const assets_step = b.step("assets", "Build generated game assets");

    const prologue_m1_bg = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/build_room_bundle.py"),
        b.pathFromRoot("assets/rooms/prologue_a/-1.png"),
        b.pathFromRoot("assets/generated/rooms/prologue_m1"),
    });
    assets_step.dependOn(&prologue_m1_bg.step);

    const prologue_0_bg = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/build_room_bundle.py"),
        b.pathFromRoot("assets/rooms/prologue_a/0.png"),
        b.pathFromRoot("assets/generated/rooms/prologue_0"),
        "--rgb-bits",
        "4",
    });
    assets_step.dependOn(&prologue_0_bg.step);

    const prologue_0b_bg = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/build_room_bundle.py"),
        b.pathFromRoot("assets/rooms/prologue_a/0b.png"),
        b.pathFromRoot("assets/generated/rooms/prologue_0b"),
        "--rgb-bits",
        "4",
    });
    assets_step.dependOn(&prologue_0b_bg.step);

    const pack_player_animations = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_player_obj_tiles.py"),
        "--input",
        b.pathFromRoot("assets/Animations/player"),
        "--output-dir",
        b.pathFromRoot("assets/generated/player"),
        "--animations",
        "idleLoop:idleA",
        "idleLoop:idleB",
        "idleLoop:idleA",
        "idleLoop:idleB",
        "idleLoop:idleC",
        "runSlow",
        "jumpSlow",
        "fallSlow",
        "wallslide",
        "climbup",
        "dangling",
        "climbPull",
    });
    assets_step.dependOn(&pack_player_animations.step);

    const pack_player_sweat = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_player_obj_tiles.py"),
        "--input",
        b.pathFromRoot("assets/Animations/player_sweat"),
        "--output-dir",
        b.pathFromRoot("assets/generated/player_sweat"),
        "--animations",
        "still",
        "climbLoop",
        "jump",
    });
    assets_step.dependOn(&pack_player_sweat.step);

    const pack_falling_block = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_falling_block_obj.py"),
        "--input",
        b.pathFromRoot("assets/rooms/prologue_a/prologue-a-block1.png"),
        "--output-dir",
        b.pathFromRoot("assets/generated/entities/prologue_a"),
    });
    assets_step.dependOn(&pack_falling_block.step);

    const pack_hair = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_hair_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/Animations/hair"),
        "--output-dir",
        b.pathFromRoot("assets/generated/player"),
    });
    assets_step.dependOn(&pack_hair.step);

    const pack_prologue_0_parallax = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_parallax_obj.py"),
        "--input",
        b.pathFromRoot("assets/rooms/prologue_a/0-plx.png"),
        "--output-dir",
        b.pathFromRoot("assets/generated/rooms/prologue_0"),
        "--name",
        "parallax_fg",
    });
    assets_step.dependOn(&pack_prologue_0_parallax.step);

    exe.step.root_module.addAnonymousImport("prologue_m1_bg_tiles.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_m1/bg_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_m1_bg_map.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_m1/bg_map.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_m1_bg_palette.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_m1/bg_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_m1_collision.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_m1/collision.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_m1_spawn.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_m1/spawn.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_m1_falling_blocks.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_m1/falling_blocks.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_bg_tiles.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/bg_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_bg_map.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/bg_map.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_bg_palette.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/bg_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_collision.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/collision.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_spawn.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/spawn.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_falling_blocks.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/falling_blocks.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_parallax_fg_tiles.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/parallax_fg_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0_parallax_fg_palette.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0/parallax_fg_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0b_bg_tiles.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0b/bg_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0b_bg_map.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0b/bg_map.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0b_bg_palette.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0b/bg_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0b_collision.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0b/collision.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0b_spawn.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0b/spawn.bin"),
    });
    exe.step.root_module.addAnonymousImport("prologue_0b_falling_blocks.bin", .{
        .root_source_file = b.path("assets/generated/rooms/prologue_0b/falling_blocks.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_idle_tiles.bin", .{
        .root_source_file = b.path("assets/generated/player/madeline_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_palette.bin", .{
        .root_source_file = b.path("assets/generated/player/madeline_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_hair_anchors.bin", .{
        .root_source_file = b.path("assets/generated/player/madeline_hair_anchors.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_sweat_tiles.bin", .{
        .root_source_file = b.path("assets/generated/player_sweat/madeline_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("player_sweat_palette.bin", .{
        .root_source_file = b.path("assets/generated/player_sweat/madeline_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("hair_tiles.bin", .{
        .root_source_file = b.path("assets/generated/player/hair_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("hair_palette.bin", .{
        .root_source_file = b.path("assets/generated/player/hair_palette.bin"),
    });
    exe.step.root_module.addAnonymousImport("falling_block_tiles.bin", .{
        .root_source_file = b.path("assets/generated/entities/prologue_a/falling_block_tiles.bin"),
    });
    exe.step.root_module.addAnonymousImport("falling_block_palette.bin", .{
        .root_source_file = b.path("assets/generated/entities/prologue_a/falling_block_palette.bin"),
    });

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addArg("zig-out/zeleste.gba");
    mgba.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Builds and runs the ROM in mGBA");
    run_step.dependOn(&exe.step.step);
    run_step.dependOn(&mgba.step);
}
