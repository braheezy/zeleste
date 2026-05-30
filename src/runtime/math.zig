pub const fixed_shift = 8;
pub const fixed_one: i32 = 1 << fixed_shift;

pub fn pixelToFixed(value: i16) i32 {
    return @as(i32, value) << fixed_shift;
}

pub fn fixedToPixel(value: i32) i16 {
    return @intCast(value >> fixed_shift);
}

pub fn fixedMul(value: i32, mult: i32) i32 {
    return (value * mult) >> fixed_shift;
}

pub fn approach(value: i32, target: i32, amount: i32) i32 {
    if (value < target) {
        const next = value + amount;
        return if (next > target) target else next;
    }
    if (value > target) {
        const next = value - amount;
        return if (next < target) target else next;
    }
    return value;
}

pub fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

pub fn minI32(a: i32, b: i32) i32 {
    return if (a < b) a else b;
}

pub fn minU8(a: u8, b: u8) u8 {
    return if (a < b) a else b;
}

pub fn absI16(value: i16) i16 {
    return if (value < 0) -value else value;
}

pub fn maxI16(a: i16, b: i16) i16 {
    return if (a > b) a else b;
}

pub fn signI32(value: i32) i16 {
    if (value < 0) return -1;
    if (value > 0) return 1;
    return 0;
}

pub fn signI16(value: i16) i16 {
    if (value < 0) return -1;
    if (value > 0) return 1;
    return 0;
}

pub fn sqrtU64(value: u64) u64 {
    var result: u64 = 0;
    var bit: u64 = 1 << 62;
    while (bit > value) : (bit >>= 2) {}
    var remainder = value;
    while (bit != 0) : (bit >>= 2) {
        if (remainder >= result + bit) {
            remainder -= result + bit;
            result = (result >> 1) + bit;
        } else {
            result >>= 1;
        }
    }
    return result;
}

pub fn clampI16(value: i16, min_value: i16, max_value: i16) i16 {
    if (max_value <= min_value) return min_value;
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}
