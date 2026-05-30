var state: u16 = 0xACE1;

pub fn next() u16 {
    const bit = ((state >> 0) ^ (state >> 2) ^ (state >> 3) ^ (state >> 5)) & 1;
    state = (state >> 1) | (bit << 15);
    return state;
}
