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
    for (footstep_sfx_files) |file| {
        build_soundbank.addArg(b.pathFromRoot(file));
    }
    build_soundbank.addArg(b.fmt("-o{s}", .{soundbank_bin}));
    build_soundbank.addArg(b.fmt("-h{s}", .{soundbank_header}));
    build_soundbank.step.dependOn(&ensure_generated_assets_dir.step);
    assets_step.dependOn(&build_soundbank.step);

    const build_sound_ids = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/soundbank_header_to_zig.py"),
        soundbank_header,
        b.pathFromRoot("src/generated/assets/prologue_sound_ids.zig"),
    });
    build_sound_ids.step.dependOn(&build_soundbank.step);
    assets_step.dependOn(&build_sound_ids.step);

    const build_level = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/build_level_assets.py"),
        b.pathFromRoot("assets/chapters/prologue_a/room.json"),
        "--generated-root",
        b.pathFromRoot("src/generated/assets/chapters"),
        "--zig-output",
        b.pathFromRoot("src/generated_rooms.zig"),
        "--rgb-bits",
        "4",
        "--chapter-index",
        "0",
    });
    assets_step.dependOn(&build_level.step);

    const build_overworld = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/convert_room_tilemap_8bpp.py"),
        b.pathFromRoot("assets/overworld.png"),
        b.pathFromRoot("src/generated/assets/overworld/bg_tiles.bin"),
        b.pathFromRoot("src/generated/assets/overworld/bg_map.bin"),
        b.pathFromRoot("src/generated/assets/overworld/bg_palette.bin"),
        "--rgb-bits",
        "3",
        "--metadata-output",
        b.pathFromRoot("src/generated/assets/overworld/metadata.json"),
    });
    assets_step.dependOn(&build_overworld.step);

    const pack_player_animations = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_player_obj_tiles.py"),
        "--input",
        b.pathFromRoot("assets/animations/player"),
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

    const pack_player_sweat = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_player_obj_tiles.py"),
        "--input",
        b.pathFromRoot("assets/animations/player_sweat"),
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
        b.pathFromRoot("assets/chapters/prologue_a/prologue-a-block1.png"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/entities/prologue_a"),
    });
    assets_step.dependOn(&pack_falling_block.step);

    const pack_bridge = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_prologue_bridge.py"),
        "--input-dir",
        b.pathFromRoot("assets/source/prologue-bridge/chunks_8px"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/entities/prologue_bridge"),
    });
    assets_step.dependOn(&pack_bridge.step);

    const pack_funny_car = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_funny_car_obj.py"),
        "--input",
        b.pathFromRoot("assets/chapters/prologue_a/stamps/funny-car.png"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/entities/prologue_a"),
    });
    assets_step.dependOn(&pack_funny_car.step);

    const pack_hair = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_hair_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/animations/hair"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/player"),
    });
    assets_step.dependOn(&pack_hair.step);

    const pack_bird = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_bird_assets.py"),
        "--intro",
        b.pathFromRoot("assets/source/bird/intro.png"),
        "--fly",
        b.pathFromRoot("assets/source/bird/fly.png"),
        "--hold-hint",
        b.pathFromRoot("assets/chapters/prologue_a/hold-hint.png"),
        "--climb-hint",
        b.pathFromRoot("assets/chapters/prologue_a/climb-hint.png"),
        "--dash-hint",
        b.pathFromRoot("assets/chapters/prologue_a/dash-hint.png"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/bird"),
    });
    assets_step.dependOn(&pack_bird.step);

    const pack_tiny_bird = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_tiny_bird_assets.py"),
        "--input-dir",
        b.pathFromRoot("assets/animations/tiny_bird"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/tiny_bird"),
    });
    assets_step.dependOn(&pack_tiny_bird.step);

    const pack_granny = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_granny_assets.py"),
        "--input-dir",
        b.pathFromRoot("assets/animations/granny"),
        "--output-dir",
        b.pathFromRoot("src/generated/assets/granny"),
    });
    assets_step.dependOn(&pack_granny.step);

    const pack_grass1 = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("tools/pack_foreground_stamp_obj.py"),
        "--input-dir",
        b.pathFromRoot("assets/generated/foreground/grass_generated"),
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
        b.pathFromRoot("assets/generated/foreground/grass_generated_mirror"),
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
        b.pathFromRoot("assets/generated/foreground/grass2_generated"),
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
        b.pathFromRoot("assets/generated/foreground/grass2_generated_mirror"),
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

const footstep_sfx_files = [_][]const u8{
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_01.wav",
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_02.wav",
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_03.wav",
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_04.wav",
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_05.wav",
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_06.wav",
    "assets/audio/raw/sfx/madeline/foot_00_asphalt_07.wav",
    "assets/audio/raw/sfx/madeline/foot_00_car_01.wav",
    "assets/audio/raw/sfx/madeline/foot_00_car_02.wav",
    "assets/audio/raw/sfx/madeline/foot_00_car_03.wav",
    "assets/audio/raw/sfx/madeline/foot_00_car_04.wav",
    "assets/audio/raw/sfx/madeline/foot_00_car_05.wav",
    "assets/audio/raw/sfx/madeline/foot_00_car_06.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_01.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_02.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_03.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_04.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_05.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_06.wav",
    "assets/audio/raw/sfx/madeline/foot_00_dirt_07.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_01.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_02.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_03.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_04.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_05.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_06.wav",
    "assets/audio/raw/sfx/madeline/foot_00_snowsoft_07.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_01.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_02.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_03.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_04.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_05.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_06.wav",
    "assets/audio/raw/sfx/madeline/foot_00_woodwalkway_07.wav",
};

const StartArgs = struct {
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
        .chapter = std.fmt.parseInt(i32, args[0], 10) catch |err| {
            std.debug.panic("invalid start chapter '{s}': {}", .{ args[0], err });
        },
        .room = b.dupe(args[1]),
    };
}
