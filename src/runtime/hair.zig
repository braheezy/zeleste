const gba = @import("gba");
const assets = @import("assets.zig");
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const oam = @import("oam.zig");
const player_mod = @import("player.zig");

const Camera = camera_mod.Camera;
const Player = player_mod.State;
const PlayerAnimation = player_mod.Animation;
const HairNode = player_mod.HairNode;
const HairAnchor = player_mod.HairAnchor;

const fixed_one = math.fixed_one;
const pixelToFixed = math.pixelToFixed;
const fixedToPixel = math.fixedToPixel;
const absI32 = math.absI32;
const minI32 = math.minI32;
const minU8 = math.minU8;
const sqrtU64 = math.sqrtU64;
const objX = oam.objX;
const objY = oam.objY;
const hideObject = oam.hideObject;

const hair_palette_data align(4) = assets.hair_palette_data;
const player_hair_anchors_data align(4) = assets.player_hair_anchors_data;

pub const base_tile: u10 = 60;
pub const bang_base_tile: u10 = base_tile + 4;
pub const palette_bank: u4 = 2;
pub const root_object = 33;
pub const object = 34;

const node_count = player_mod.hair_node_count;
const sprite_size = player_mod.hair_sprite_size;

var hair_pixels: [sprite_size * sprite_size]u8 = [_]u8{0} ** (sprite_size * sprite_size);
var hair_tiles: [4]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 4;
var bang_pixels: [64]u8 = [_]u8{0} ** 64;
var bang_tiles: [1]gba.display.Tile4Bpp align(4) = [_]gba.display.Tile4Bpp{gba.display.Tile4Bpp.init([_]u8{0} ** 32)} ** 1;

pub fn loadPalette() void {
    gba.mem.memcpy16(&gba.display.obj_palette.colors[@as(usize, palette_bank) * 16], @ptrCast(&hair_palette_data), 16);
}

pub fn hideObjects() void {
    hideObject(root_object);
    hideObject(object);
}

pub fn update(player: *Player, ending_hair: bool) void {
    const anchor = hairAnchorWorld(player.*);
    const dir = anchor.dir;
    const falling_hair = player.animation == .fall and !ending_hair;
    const climb_hair = player.animation == .climb or player.animation == .dangling or player.animation == .climb_pull or player.animation == .wallslide;
    const run_hair = player.animation == .run;
    const root = hairRootWorld(anchor, player.animation);
    const root_x = root.x;
    const root_y = root.y;
    if (!player.hair_initialized) {
        var index: usize = 0;
        while (index < node_count) : (index += 1) {
            player.hair_nodes[index] = .{
                .x = root_x + @as(i32, dir) * @as(i32, @intCast(index + 1)) * fixed_one,
                .y = root_y + @as(i32, @intCast(index + 1)) * fixed_one * 2,
            };
        }
        player.hair_initialized = true;
    }

    const speed_x = minI32(absI32(player.vx), fixed_one * 2);
    const speed_y = minI32(absI32(player.vy), fixed_one * 4);
    const rest_x: i32 = if (ending_hair)
        @as(i32, dir) * fixed_one
    else if (falling_hair)
        @as(i32, dir) * (fixed_one + @divTrunc(speed_x, 8))
    else if (climb_hair)
        @as(i32, dir) * fixed_one
    else
        @as(i32, dir) * (fixed_one / 2);
    const rest_y: i32 = if (falling_hair)
        -@divTrunc(speed_y, 8)
    else if (ending_hair)
        fixed_one / 2
    else if (player.animation == .jump)
        fixed_one
    else if (climb_hair)
        fixed_one + fixed_one / 2
    else if (run_hair)
        fixed_one + fixed_one * 3 / 4
    else
        fixed_one * 2;
    const desired_dist: i32 = if (ending_hair)
        fixed_one + fixed_one / 2
    else if (run_hair)
        fixed_one + fixed_one * 3 / 4
    else
        fixed_one * 2;

    var prev_x = root_x;
    var prev_y = root_y;
    var index: usize = 0;
    while (index < node_count) : (index += 1) {
        const segment_lift: i32 = if ((falling_hair or ending_hair) and index > 1) fixed_one / 8 else 0;
        const target_x = prev_x + rest_x;
        const target_y = prev_y + rest_y - segment_lift;
        player.hair_nodes[index].x += @divTrunc(target_x - player.hair_nodes[index].x, 4);
        player.hair_nodes[index].y += @divTrunc(target_y - player.hair_nodes[index].y, 4);

        constrainNode(&player.hair_nodes[index], prev_x, prev_y, desired_dist);
        prev_x = player.hair_nodes[index].x;
        prev_y = player.hair_nodes[index].y;
    }
}

pub fn draw(player: Player, camera: Camera, ending_hair: bool) void {
    updatePalette(player);
    const anchor = hairAnchorWorld(player);
    const falling_hair = player.animation == .fall and !ending_hair;
    const climb_hair = player.animation == .climb or player.animation == .dangling or player.animation == .climb_pull or player.animation == .wallslide;
    const run_hair = player.animation == .run;
    const root = hairRootWorld(anchor, player.animation);
    const sprite_x = fixedToPixel(root.x) - camera.x - 8;
    const sprite_offset_y: i16 = if (falling_hair) 5 else 4;
    const sprite_y = fixedToPixel(root.y) - camera.y - sprite_offset_y;
    clearPixels();
    clearBangPixels();

    var points: [node_count + 1]HairNode = undefined;
    points[0] = root;
    var index: usize = 0;
    while (index < node_count) : (index += 1) {
        points[index + 1] = player.hair_nodes[index];
    }
    drawPointChain(&points, sprite_x + camera.x, sprite_y + camera.y, anchor.dir, falling_hair, climb_hair, ending_hair, run_hair);
    packTiles();
    gba.display.memcpyObjectTiles4Bpp(base_tile, &hair_tiles);
    gba.display.objects[object] = gba.display.Object.init(.{
        .size = .size_16x16,
        .x = objX(sprite_x),
        .y = objY(sprite_y),
        .base_tile = base_tile,
        .priority = 1,
        .palette = palette_bank,
    });

    drawBangs(anchor.dir);
    packBangTile();
    gba.display.memcpyObjectTiles4Bpp(bang_base_tile, &bang_tiles);
    gba.display.objects[root_object] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(fixedToPixel(root.x) - camera.x - 4),
        .y = objY(fixedToPixel(root.y) - camera.y - 4),
        .base_tile = bang_base_tile,
        .priority = 0,
        .palette = palette_bank,
    });
}

fn updatePalette(player: Player) void {
    const base_palette: [*]align(2) const gba.ColorRgb555 = @ptrCast(&hair_palette_data);
    const palette_base = @as(usize, palette_bank) * 16;
    if (player.dash_timer > 0) {
        gba.display.obj_palette.colors[palette_base] = base_palette[0];
        gba.display.obj_palette.colors[palette_base + 1] = .black;
        gba.display.obj_palette.colors[palette_base + 2] = gba.ColorRgb555.rgb(22, 23, 24);
        gba.display.obj_palette.colors[palette_base + 3] = .white;
        var white_index: usize = 4;
        while (white_index < 16) : (white_index += 1) {
            gba.display.obj_palette.colors[palette_base + white_index] = base_palette[white_index];
        }
        return;
    }
    if (player.dashes > 0) {
        gba.mem.memcpy16(&gba.display.obj_palette.colors[palette_base], base_palette, 16);
        return;
    }

    gba.display.obj_palette.colors[palette_base] = base_palette[0];
    gba.display.obj_palette.colors[palette_base + 1] = .black;
    gba.display.obj_palette.colors[palette_base + 2] = gba.ColorRgb555.rgb(3, 12, 22);
    gba.display.obj_palette.colors[palette_base + 3] = gba.ColorRgb555.rgb(8, 22, 31);
    var index: usize = 4;
    while (index < 16) : (index += 1) {
        gba.display.obj_palette.colors[palette_base + index] = base_palette[index];
    }
}

fn constrainNode(node: *HairNode, prev_x: i32, prev_y: i32, desired_dist: i32) void {
    const diff_x = node.x - prev_x;
    const diff_y = node.y - prev_y;
    const dist_sq = @as(i64, diff_x) * diff_x + @as(i64, diff_y) * diff_y;
    if (dist_sq == 0) {
        node.y = prev_y + desired_dist;
        return;
    }
    const dist: i32 = @intCast(sqrtU64(@intCast(dist_sq)));
    if (dist <= desired_dist) return;

    node.x = prev_x + @as(i32, @intCast(@divTrunc(@as(i64, diff_x) * desired_dist, dist)));
    node.y = prev_y + @as(i32, @intCast(@divTrunc(@as(i64, diff_y) * desired_dist, dist)));
}

fn hairRootWorld(anchor: HairAnchor, animation: PlayerAnimation) HairNode {
    _ = animation;
    return .{
        .x = anchor.x,
        .y = anchor.y,
    };
}

fn hairAnchorWorld(player: Player) HairAnchor {
    const anchor_offset = @as(usize, player.frame) * 5;
    var anchor_x: i16 = 18;
    var anchor_y: i16 = 19;
    var dir: i16 = -1;
    if (anchor_offset + 4 < player_hair_anchors_data.len) {
        anchor_x = player_hair_anchors_data[anchor_offset];
        anchor_y = player_hair_anchors_data[anchor_offset + 1];
        dir = if (player_hair_anchors_data[anchor_offset + 2] == 0) -1 else 1;
    }
    if (player.facing_left) {
        anchor_x = 31 - anchor_x;
        dir = -dir;
    }
    const body_x = fixedToPixel(player.x) + player_mod.draw_offset_x;
    const body_y = fixedToPixel(player.y) + player_mod.draw_offset_y;
    return .{
        .x = pixelToFixed(body_x + anchor_x),
        .y = pixelToFixed(body_y + anchor_y),
        .dir = dir,
    };
}

fn clearPixels() void {
    var index: usize = 0;
    while (index < hair_pixels.len) : (index += 1) {
        hair_pixels[index] = 0;
    }
}

fn drawPointChain(points: *const [node_count + 1]HairNode, origin_x: i16, origin_y: i16, dir: i16, falling_hair: bool, climb_hair: bool, ending_hair: bool, run_hair: bool) void {
    var index: usize = 0;
    while (index < points.len) : (index += 1) {
        drawDiscWorld(pointDrawX(points, index, dir), points[index].y + fixed_one / 3, origin_x, origin_y, pointShadowRadius(index, falling_hair, climb_hair, ending_hair, run_hair), 2);
    }

    index = 0;
    while (index + 1 < points.len) : (index += 1) {
        const radius = minU8(pointRadius(index, falling_hair, climb_hair, ending_hair, run_hair), pointRadius(index + 1, falling_hair, climb_hair, ending_hair, run_hair));
        drawDiscWorld(@divTrunc(pointDrawX(points, index, dir) + pointDrawX(points, index + 1, dir), 2), @divTrunc(points[index].y + points[index + 1].y, 2), origin_x, origin_y, radius, 3);
    }

    index = 0;
    while (index < points.len) : (index += 1) {
        drawDiscWorld(pointDrawX(points, index, dir), points[index].y, origin_x, origin_y, pointRadius(index, falling_hair, climb_hair, ending_hair, run_hair), 3);
    }

    index = 0;
    while (index < points.len) : (index += 1) {
        drawEdgePixels(pointDrawX(points, index, dir), points[index].y, origin_x, origin_y, dir, pointRadius(index, falling_hair, climb_hair, ending_hair, run_hair));
    }
}

fn pointDrawX(points: *const [node_count + 1]HairNode, index: usize, dir: i16) i32 {
    const forward: i32 = if (dir > 0) -1 else 1;
    const crown_offset = if (index == 0) forward * fixed_one else 0;
    return points[index].x + crown_offset;
}

fn pointRadius(index: usize, falling_hair: bool, climb_hair: bool, ending_hair: bool, run_hair: bool) u8 {
    if (ending_hair) return if (index == 0) 4 else if (index <= 2) 3 else if (index <= 4) 2 else 1;
    if (falling_hair) return if (index == 0) 4 else if (index <= 2) 3 else if (index <= 4) 2 else 1;
    if (climb_hair) return if (index == 0) 3 else if (index <= 2) 2 else if (index <= 4) 1 else 0;
    if (run_hair) return if (index == 0) 4 else if (index <= 2) 3 else if (index <= 3) 2 else if (index <= 5) 1 else 0;
    if (index == 0) return 4;
    if (index <= 2) return 3;
    if (index <= 4) return 2;
    if (index <= 5) return 1;
    return 0;
}

fn pointShadowRadius(index: usize, falling_hair: bool, climb_hair: bool, ending_hair: bool, run_hair: bool) u8 {
    const radius = pointRadius(index, falling_hair, climb_hair, ending_hair, run_hair);
    return if (radius > 0) radius - 1 else 0;
}

fn drawDiscWorld(world_x: i32, world_y: i32, origin_x: i16, origin_y: i16, radius: u8, color: u8) void {
    const center_x = fixedToPixel(world_x) - origin_x;
    const center_y = fixedToPixel(world_y) - origin_y;
    drawDiscLocal(center_x, center_y, radius, color);
}

fn drawEdgePixels(world_x: i32, world_y: i32, origin_x: i16, origin_y: i16, dir: i16, radius: u8) void {
    if (radius < 2) return;
    const center_x = fixedToPixel(world_x) - origin_x;
    const center_y = fixedToPixel(world_y) - origin_y;
    const back: i16 = if (dir > 0) 1 else -1;
    const r: i16 = @intCast(radius);

    setPixel(center_x + back * r, center_y, 2);
    setPixel(center_x + back * (r - 1), center_y + r - 1, 2);
    if (radius >= 3) {
        setPixel(center_x + back * (r - 1), center_y - r + 1, 2);
    }
}

fn drawDiscLocal(center_x: i16, center_y: i16, radius: u8, color: u8) void {
    const r: i16 = @intCast(radius);
    var y: i16 = -r;
    while (y <= r) : (y += 1) {
        var x: i16 = -r;
        while (x <= r) : (x += 1) {
            if (x * x + y * y <= r * r) {
                setPixel(center_x + x, center_y + y, color);
            }
        }
    }
}

fn drawBangs(dir: i16) void {
    const forward: i16 = if (dir > 0) -1 else 1;
    const root_x: i16 = 4;
    const root_y: i16 = 4;

    setBangPixel(root_x + forward * 2, root_y - 1, 2);
    setBangPixel(root_x + forward, root_y, 2);
    setBangPixel(root_x + forward * 2, root_y, 2);
}

fn setPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= sprite_size or y < 0 or y >= sprite_size) return;
    const index: usize = @intCast(y * sprite_size + x);
    hair_pixels[index] = color;
}

fn clearBangPixels() void {
    var index: usize = 0;
    while (index < bang_pixels.len) : (index += 1) {
        bang_pixels[index] = 0;
    }
}

fn setBangPixel(x: i16, y: i16, color: u8) void {
    if (x < 0 or x >= 8 or y < 0 or y >= 8) return;
    const index: usize = @intCast(y * 8 + x);
    bang_pixels[index] = color;
}

fn packTiles() void {
    var tile_y: usize = 0;
    while (tile_y < 2) : (tile_y += 1) {
        var tile_x: usize = 0;
        while (tile_x < 2) : (tile_x += 1) {
            const tile_index = tile_y * 2 + tile_x;
            var byte_index: usize = 0;
            var y: usize = 0;
            while (y < 8) : (y += 1) {
                var x_pair: usize = 0;
                while (x_pair < 4) : (x_pair += 1) {
                    const px_x = tile_x * 8 + x_pair * 2;
                    const px_y = tile_y * 8 + y;
                    const left = hair_pixels[px_y * sprite_size + px_x] & 0x0f;
                    const right = hair_pixels[px_y * sprite_size + px_x + 1] & 0x0f;
                    hair_tiles[tile_index].data_8[byte_index] = left | (right << 4);
                    byte_index += 1;
                }
            }
        }
    }
}

fn packBangTile() void {
    var byte_index: usize = 0;
    var y: usize = 0;
    while (y < 8) : (y += 1) {
        var x_pair: usize = 0;
        while (x_pair < 4) : (x_pair += 1) {
            const px_x = x_pair * 2;
            const left = bang_pixels[y * 8 + px_x] & 0x0f;
            const right = bang_pixels[y * 8 + px_x + 1] & 0x0f;
            bang_tiles[0].data_8[byte_index] = left | (right << 4);
            byte_index += 1;
        }
    }
}
