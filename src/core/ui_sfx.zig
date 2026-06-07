const assets = @import("assets.zig");
const audio = @import("audio.zig");

const sound_ids = assets.sound_ids;
const dialogue_text_volume: u16 = 512;

var save_file_roll_index: u8 = 0;

pub fn titleFirstInput() void {
    play(sound_ids.sfx_ui_main_title_firstinput);
}

pub fn buttonSelect() void {
    play(sound_ids.sfx_ui_main_button_select);
}

pub fn buttonBack() void {
    play(sound_ids.sfx_ui_main_button_back);
}

pub fn buttonInvalid() void {
    play(sound_ids.sfx_ui_main_button_invalid);
}

pub fn menuRollUp() void {
    play(sound_ids.sfx_ui_main_roll_up);
}

pub fn menuRollDown() void {
    play(sound_ids.sfx_ui_main_roll_down);
}

pub fn saveFileOpen() void {
    play(sound_ids.sfx_ui_main_whoosh_savefile_in);
}

pub fn saveFileClose() void {
    play(sound_ids.sfx_ui_main_whoosh_savefile_out);
}

pub fn saveFileRoll() void {
    switch (save_file_roll_index) {
        0 => play(sound_ids.sfx_ui_main_savefile_roll_01),
        1 => play(sound_ids.sfx_ui_main_savefile_roll_02),
        else => play(sound_ids.sfx_ui_main_savefile_roll_03),
    }
    save_file_roll_index = (save_file_roll_index + 1) % 3;
}

pub fn saveFileDelete() void {
    play(sound_ids.sfx_ui_main_savefile_delete);
}

pub fn worldIconRoll(direction: i8) void {
    if (direction < 0) {
        play(sound_ids.sfx_ui_world_icon_roll_left);
    } else {
        play(sound_ids.sfx_ui_world_icon_roll_right);
    }
}

pub fn worldPageFlip(direction: i8) void {
    if (direction < 0) {
        play(sound_ids.sfx_ui_world_icon_flip_left);
    } else {
        play(sound_ids.sfx_ui_world_icon_flip_right);
    }
}

pub fn worldChapterSelect() void {
    play(sound_ids.sfx_ui_world_chapter_level_select);
}

pub fn dialogueBoxIn(madeline: bool) void {
    if (madeline) {
        play(sound_ids.sfx_ui_game_textbox_madeline_in);
    } else {
        play(sound_ids.sfx_ui_game_textbox_other_in);
    }
}

pub fn dialogueBoxOut(madeline: bool) void {
    if (madeline) {
        play(sound_ids.sfx_ui_game_textbox_madeline_out);
    } else {
        play(sound_ids.sfx_ui_game_textbox_other_out);
    }
}

pub fn dialogueAdvance(madeline: bool) void {
    if (madeline) {
        play(sound_ids.sfx_ui_game_textadvance_madeline);
    } else {
        play(sound_ids.sfx_ui_game_textadvance_other);
    }
}

pub fn dialogueText() void {
    const handle = audio.playSoundEffect(sound_ids.sfx_ui_game_text_general);
    if (handle != 0) audio.setSoundEffectVolume(handle, dialogue_text_volume);
}

fn play(sound_id: u16) void {
    _ = audio.playSoundEffect(sound_id);
}
