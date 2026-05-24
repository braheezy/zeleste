const std = @import("std");
const ziggba = @import("ziggba");

pub fn build(b: *std.Build) void {
    const gba_b = ziggba.GbaBuild.create(b);

    const exe = gba_b.addExecutable(.{
        .name = "zeleste",
        .root_source_file = b.path("src/main.zig"),
    });

    const assets_step = b.step("assets", "Build generated game assets");

    const build_level = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/build_level_assets.py"),
        b.pathFromRoot("assets/rooms/prologue_a/room.json"),
        "--generated-root",
        b.pathFromRoot("src/generated/assets/rooms"),
        "--zig-output",
        b.pathFromRoot("src/generated_rooms.zig"),
        "--rgb-bits",
        "4",
    });
    assets_step.dependOn(&build_level.step);

    const pack_player_animations = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_player_obj_tiles.py"),
        "--input",
        b.pathFromRoot("assets/Animations/player"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/player"),
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
        b.pathFromRoot("src/generated/assets/player_sweat"),
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
        b.pathFromRoot("src/generated/assets/entities/prologue_a"),
    });
    assets_step.dependOn(&pack_falling_block.step);

    const pack_hair = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_hair_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/Animations/hair"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/player"),
    });
    assets_step.dependOn(&pack_hair.step);

    const pack_grass1 = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_foreground_stamp_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/Animations/foreground/grass_generated"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/foreground"),
        "--name",
        "grass1",
    });
    assets_step.dependOn(&pack_grass1.step);

    const pack_grass1_mirror = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_foreground_stamp_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/Animations/foreground/grass_generated_mirror"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/foreground"),
        "--name",
        "grass1_mirror",
    });
    assets_step.dependOn(&pack_grass1_mirror.step);

    const pack_grass2 = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_foreground_stamp_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/Animations/foreground/grass2_generated"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/foreground"),
        "--name",
        "grass2",
    });
    assets_step.dependOn(&pack_grass2.step);

    const pack_grass2_mirror = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_foreground_stamp_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/Animations/foreground/grass2_generated_mirror"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/foreground"),
        "--name",
        "grass2_mirror",
    });
    assets_step.dependOn(&pack_grass2_mirror.step);

    const mgba = b.addSystemCommand(&.{"/Applications/mGBA.app/Contents/MacOS/mGBA"});
    mgba.addArg("zig-out/zeleste.gba");
    mgba.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Builds and runs the ROM in mGBA");
    run_step.dependOn(&exe.step.step);
    run_step.dependOn(&mgba.step);
}
