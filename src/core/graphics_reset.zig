const gba = @import("gba");

const object_vram_halfword_offset: usize = 0x8000;
const object_vram_halfword_count: u32 = 0x4000;
const object_palette_color_count: u32 = 256;

pub fn clearObjectGraphics() void {
    gba.display.hideAllObjects();
    gba.mem.memset16(&gba.display.obj_palette.colors[0], 0, object_palette_color_count);
    gba.mem.memset16(&gba.mem.vram[object_vram_halfword_offset], 0, object_vram_halfword_count);
}
