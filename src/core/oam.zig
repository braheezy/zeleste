const gba = @import("gba");

pub fn hideObject(object_index: usize) void {
    gba.display.objects[object_index] = gba.display.Object.init(.{
        .size = .size_8x8,
        .x = objX(240),
        .y = objY(160),
        .base_tile = 0,
    });
}

pub fn objX(x: i16) u9 {
    if (x < -64) return 240;
    if (x < 0) return @intCast(512 + x);
    if (x > 511) return 511;
    return @intCast(x);
}

pub fn objY(y: i16) u8 {
    if (y < -64) return 160;
    if (y < 0) return @intCast(256 + y);
    if (y > 255) return 255;
    return @intCast(y);
}
