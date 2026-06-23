pub fn startsWith(text: []const u8, prefix: []const u8) bool {
    if (text.len < prefix.len) return false;
    var index: usize = 0;
    while (index < prefix.len) : (index += 1) {
        if (text[index] != prefix[index]) return false;
    }
    return true;
}

pub fn equals(text: []const u8, other: []const u8) bool {
    return text.len == other.len and startsWith(text, other);
}

pub fn contains(text: []const u8, needle: []const u8) bool {
    return findSubstring(text, needle) != null;
}

pub fn findSubstring(text: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (text.len < needle.len) return null;
    var index: usize = 0;
    while (index + needle.len <= text.len) : (index += 1) {
        var matched = true;
        var needle_index: usize = 0;
        while (needle_index < needle.len) : (needle_index += 1) {
            if (text[index + needle_index] != needle[needle_index]) {
                matched = false;
                break;
            }
        }
        if (matched) return index;
    }
    return null;
}

pub fn wrappedNextOffset(text: []const u8, start_offset: usize, max_chars: usize, max_lines: usize) usize {
    var offset = skipSpaces(text, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < text.len) : (line += 1) {
        offset = advanceWrappedOffset(text, wrappedLineEnd(text, offset, max_chars));
    }
    return offset;
}

pub fn wrappedLineEnd(text: []const u8, offset: usize, max_chars: usize) usize {
    const line_start = offset;
    var pos = offset;
    var count: usize = 0;
    var last_space: usize = text.len + 1;
    while (pos < text.len and count < max_chars) : ({
        pos += 1;
        count += 1;
    }) {
        const ch = text[pos];
        if (ch == '\n') break;
        if (ch == ' ') last_space = pos;
    }

    var line_end = pos;
    if (pos < text.len and text[pos] != ' ' and text[pos] != '\n' and count >= max_chars and last_space > line_start and last_space <= text.len) {
        line_end = last_space;
    }
    return line_end;
}

pub fn advanceWrappedOffset(text: []const u8, line_end: usize) usize {
    var offset = line_end;
    if (offset < text.len and text[offset] == '\n') {
        offset += 1;
    }
    return skipSpaces(text, offset);
}

pub fn advanceRevealByWords(text: []const u8, start_offset: usize, target_offset: usize, word_count: u8) usize {
    var offset = skipSpacesUntil(text, start_offset, target_offset);
    var words: u8 = 0;
    while (offset < target_offset and words < word_count) : (words += 1) {
        while (offset < target_offset and text[offset] != ' ' and text[offset] != '\n') : (offset += 1) {}
        offset = skipSpacesUntil(text, offset, target_offset);
    }
    return offset;
}

pub fn skipSpacesUntil(text: []const u8, start: usize, end: usize) usize {
    var offset = start;
    while (offset < end and offset < text.len and text[offset] == ' ') : (offset += 1) {}
    return offset;
}

pub fn skipSpaces(text: []const u8, start: usize) usize {
    var offset = start;
    while (offset < text.len and text[offset] == ' ') : (offset += 1) {}
    return offset;
}

pub fn drawWrappedSmall(
    comptime setPixel: fn (i16, i16, u8) void,
    box_width: i16,
    source: []const u8,
    start_offset: usize,
    x: i16,
    y: i16,
    max_chars: usize,
    max_lines: usize,
    color: u8,
) usize {
    var offset = skipSpaces(source, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < source.len) : (line += 1) {
        const line_start = offset;
        var pos = offset;
        var count: usize = 0;
        var last_space: usize = source.len + 1;
        while (pos < source.len and count < max_chars) : ({
            pos += 1;
            count += 1;
        }) {
            const ch = source[pos];
            if (ch == '\n') break;
            if (ch == ' ') last_space = pos;
        }

        var line_end = pos;
        if (pos < source.len and source[pos] != ' ' and source[pos] != '\n' and count >= max_chars and last_space > line_start and last_space <= source.len) {
            line_end = last_space;
        }
        drawSmallLine(setPixel, box_width, source[line_start..line_end], x, y + @as(i16, @intCast(line * 6)), color);

        offset = line_end;
        if (offset < source.len and source[offset] == '\n') {
            offset += 1;
        }
        offset = skipSpaces(source, offset);
    }
    return offset;
}

pub fn drawWrappedUntil(
    comptime setPixel: fn (i16, i16, u8) void,
    box_width: i16,
    source: []const u8,
    start_offset: usize,
    visible_offset: usize,
    x: i16,
    y: i16,
    max_chars: usize,
    max_lines: usize,
    color: u8,
) void {
    var offset = skipSpaces(source, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < source.len) : (line += 1) {
        const line_start = offset;
        const line_end = wrappedLineEnd(source, offset, max_chars);
        const visible_end = @min(line_end, visible_offset);
        if (visible_end > line_start) {
            drawLine(setPixel, box_width, source[line_start..visible_end], x, y + @as(i16, @intCast(line * 9)), color);
        }
        if (visible_offset <= line_end) break;
        offset = advanceWrappedOffset(source, line_end);
    }
}

pub fn drawWrappedBetween(
    comptime setPixel: fn (i16, i16, u8) void,
    box_width: i16,
    source: []const u8,
    start_offset: usize,
    visible_start_offset: usize,
    visible_end_offset: usize,
    x: i16,
    y: i16,
    max_chars: usize,
    max_lines: usize,
    color: u8,
) void {
    if (visible_end_offset <= visible_start_offset) return;

    var offset = skipSpaces(source, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < source.len) : (line += 1) {
        const line_start = offset;
        const line_end = wrappedLineEnd(source, offset, max_chars);
        const draw_start = @max(line_start, visible_start_offset);
        const draw_end = @min(line_end, visible_end_offset);
        if (draw_end > draw_start) {
            const dx: i16 = @intCast((draw_start - line_start) * 6);
            drawLine(setPixel, box_width, source[draw_start..draw_end], x + dx, y + @as(i16, @intCast(line * 9)), color);
        }
        if (visible_end_offset <= line_end) break;
        offset = advanceWrappedOffset(source, line_end);
    }
}

pub fn drawWrapped(
    comptime setPixel: fn (i16, i16, u8) void,
    box_width: i16,
    source: []const u8,
    start_offset: usize,
    x: i16,
    y: i16,
    max_chars: usize,
    max_lines: usize,
    color: u8,
) usize {
    var offset = skipSpaces(source, start_offset);
    var line: usize = 0;
    while (line < max_lines and offset < source.len) : (line += 1) {
        const line_end = wrappedLineEnd(source, offset, max_chars);
        drawLine(setPixel, box_width, source[offset..line_end], x, y + @as(i16, @intCast(line * 9)), color);
        offset = advanceWrappedOffset(source, line_end);
    }
    return offset;
}

pub fn drawSmallLine(comptime setPixel: fn (i16, i16, u8) void, box_width: i16, source: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (source) |ch| {
        if (cursor >= box_width) break;
        drawSmallGlyph(setPixel, ch, cursor, y, color);
        cursor += 4;
    }
}

pub fn drawSmallLineTight(comptime setPixel: fn (i16, i16, u8) void, box_width: i16, source: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (source) |ch| {
        if (cursor >= box_width) break;
        drawSmallGlyph(setPixel, ch, cursor, y, color);
        cursor += 3;
    }
}

fn drawSmallGlyph(comptime setPixel: fn (i16, i16, u8) void, input: u8, x: i16, y: i16, color: u8) void {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    const rows = smallFontRows(ch);
    for (rows, 0..) |row_bits, row| {
        var col: usize = 0;
        while (col < 3) : (col += 1) {
            if ((row_bits & (@as(u3, 1) << @intCast(2 - col))) != 0) {
                setPixel(x + @as(i16, @intCast(col)), y + @as(i16, @intCast(row)), color);
            }
        }
    }
}

fn smallFontRows(ch: u8) [5]u3 {
    return switch (ch) {
        'A' => .{ 0b010, 0b101, 0b111, 0b101, 0b101 },
        'B' => .{ 0b110, 0b101, 0b110, 0b101, 0b110 },
        'C' => .{ 0b011, 0b100, 0b100, 0b100, 0b011 },
        'D' => .{ 0b110, 0b101, 0b101, 0b101, 0b110 },
        'E' => .{ 0b111, 0b100, 0b110, 0b100, 0b111 },
        'F' => .{ 0b111, 0b100, 0b110, 0b100, 0b100 },
        'G' => .{ 0b011, 0b100, 0b101, 0b101, 0b011 },
        'H' => .{ 0b101, 0b101, 0b111, 0b101, 0b101 },
        'I' => .{ 0b111, 0b010, 0b010, 0b010, 0b111 },
        'J' => .{ 0b001, 0b001, 0b001, 0b101, 0b010 },
        'K' => .{ 0b101, 0b101, 0b110, 0b101, 0b101 },
        'L' => .{ 0b100, 0b100, 0b100, 0b100, 0b111 },
        'M' => .{ 0b101, 0b111, 0b111, 0b101, 0b101 },
        'N' => .{ 0b101, 0b111, 0b111, 0b111, 0b101 },
        'O' => .{ 0b010, 0b101, 0b101, 0b101, 0b010 },
        'P' => .{ 0b110, 0b101, 0b110, 0b100, 0b100 },
        'Q' => .{ 0b010, 0b101, 0b101, 0b111, 0b011 },
        'R' => .{ 0b110, 0b101, 0b110, 0b101, 0b101 },
        'S' => .{ 0b011, 0b100, 0b010, 0b001, 0b110 },
        'T' => .{ 0b111, 0b010, 0b010, 0b010, 0b010 },
        'U' => .{ 0b101, 0b101, 0b101, 0b101, 0b111 },
        'V' => .{ 0b101, 0b101, 0b101, 0b101, 0b010 },
        'W' => .{ 0b101, 0b101, 0b111, 0b111, 0b101 },
        'X' => .{ 0b101, 0b101, 0b010, 0b101, 0b101 },
        'Y' => .{ 0b101, 0b101, 0b010, 0b010, 0b010 },
        'Z' => .{ 0b111, 0b001, 0b010, 0b100, 0b111 },
        '0' => .{ 0b111, 0b101, 0b101, 0b101, 0b111 },
        '1' => .{ 0b010, 0b110, 0b010, 0b010, 0b111 },
        '2' => .{ 0b110, 0b001, 0b010, 0b100, 0b111 },
        '3' => .{ 0b110, 0b001, 0b010, 0b001, 0b110 },
        '4' => .{ 0b101, 0b101, 0b111, 0b001, 0b001 },
        '5' => .{ 0b111, 0b100, 0b110, 0b001, 0b110 },
        '6' => .{ 0b011, 0b100, 0b110, 0b101, 0b010 },
        '7' => .{ 0b111, 0b001, 0b010, 0b010, 0b010 },
        '8' => .{ 0b010, 0b101, 0b010, 0b101, 0b010 },
        '9' => .{ 0b010, 0b101, 0b011, 0b001, 0b110 },
        '.' => .{ 0, 0, 0, 0, 0b010 },
        ',' => .{ 0, 0, 0, 0b010, 0b100 },
        '?' => .{ 0b110, 0b001, 0b010, 0, 0b010 },
        '!' => .{ 0b010, 0b010, 0b010, 0, 0b010 },
        '\'' => .{ 0b010, 0b010, 0, 0, 0 },
        '"' => .{ 0b101, 0b101, 0, 0, 0 },
        '-' => .{ 0, 0, 0b111, 0, 0 },
        '/' => .{ 0b001, 0b001, 0b010, 0b100, 0b100 },
        ':' => .{ 0, 0b010, 0, 0b010, 0 },
        else => .{ 0, 0, 0, 0, 0 },
    };
}

pub fn drawLine(comptime setPixel: fn (i16, i16, u8) void, box_width: i16, source: []const u8, x: i16, y: i16, color: u8) void {
    var cursor = x;
    for (source) |ch| {
        if (cursor >= box_width) break;
        drawGlyph(setPixel, ch, cursor, y, color);
        cursor += 6;
    }
}

fn drawGlyph(comptime setPixel: fn (i16, i16, u8) void, input: u8, x: i16, y: i16, color: u8) void {
    const ch = if (input >= 'a' and input <= 'z') input - 32 else input;
    const rows = fontRows(ch);
    for (rows, 0..) |row_bits, row| {
        var col: usize = 0;
        while (col < 5) : (col += 1) {
            if ((row_bits & (@as(u8, 1) << @intCast(4 - col))) != 0) {
                setPixel(x + @as(i16, @intCast(col)), y + @as(i16, @intCast(row)), color);
            }
        }
    }
}

fn fontRows(ch: u8) [7]u8 {
    return switch (ch) {
        'A' => .{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'B' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 },
        'C' => .{ 0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111 },
        'D' => .{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 },
        'E' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 },
        'F' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 },
        'G' => .{ 0b01111, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110 },
        'H' => .{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
        'I' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111 },
        'J' => .{ 0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100 },
        'K' => .{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
        'L' => .{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 },
        'M' => .{ 0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001 },
        'N' => .{ 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001 },
        'O' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'P' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 },
        'Q' => .{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 },
        'R' => .{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 },
        'S' => .{ 0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110 },
        'T' => .{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
        'U' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
        'V' => .{ 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b01010, 0b00100 },
        'W' => .{ 0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010 },
        'X' => .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001 },
        'Y' => .{ 0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100 },
        'Z' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111 },
        '0' => .{ 0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110 },
        '1' => .{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
        '2' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b10000, 0b10000, 0b11111 },
        '3' => .{ 0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110 },
        '4' => .{ 0b10010, 0b10010, 0b10010, 0b11111, 0b00010, 0b00010, 0b00010 },
        '5' => .{ 0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110 },
        '6' => .{ 0b01111, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
        '7' => .{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
        '8' => .{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
        '9' => .{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b11110 },
        '.' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01100 },
        ',' => .{ 0, 0, 0, 0, 0, 0b01100, 0b01000 },
        '?' => .{ 0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0, 0b00100 },
        '!' => .{ 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0, 0b00100 },
        '\'' => .{ 0b00100, 0b00100, 0b01000, 0, 0, 0, 0 },
        '"' => .{ 0b01010, 0b01010, 0, 0, 0, 0, 0 },
        '-' => .{ 0, 0, 0, 0b11110, 0, 0, 0 },
        ':' => .{ 0, 0b01100, 0b01100, 0, 0b01100, 0b01100, 0 },
        '/' => .{ 0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000 },
        else => .{ 0, 0, 0, 0, 0, 0, 0 },
    };
}
