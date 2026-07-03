const assets = @import("assets.zig");
const audio = @import("audio.zig");

const sound_ids = assets.sound_ids;
const dialogue_text_volume: u16 = 512;

pub const DialogueVoice = enum {
    generic,
    madeline_normal,
    madeline_angry,
    madeline_sad,
    granny_normal,
    granny_mock,
    granny_laugh,
};

var save_file_roll_index: u8 = 0;
var save_file_roll_handle: audio.SoundEffectHandle = 0;
var dialogue_text_handle: audio.SoundEffectHandle = 0;
var dialogue_madeline_normal_index: u8 = 0;
var dialogue_madeline_angry_index: u8 = 0;
var dialogue_madeline_sad_index: u8 = 0;
var dialogue_granny_normal_index: u8 = 0;
var dialogue_granny_mock_index: u8 = 0;
var dialogue_granny_laugh_index: u8 = 0;

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
    cancelSaveFileRoll();
    play(sound_ids.sfx_ui_main_whoosh_savefile_in);
}

pub fn saveFileClose() void {
    cancelSaveFileRoll();
    play(sound_ids.sfx_ui_main_whoosh_savefile_out);
}

pub fn saveFileRoll() void {
    cancelSaveFileRoll();
    const sound_id = switch (save_file_roll_index) {
        0 => sound_ids.sfx_ui_main_savefile_roll_01,
        1 => sound_ids.sfx_ui_main_savefile_roll_02,
        else => sound_ids.sfx_ui_main_savefile_roll_03,
    };
    save_file_roll_handle = audio.playSoundEffect(sound_id);
    save_file_roll_index = (save_file_roll_index + 1) % 3;
}

pub fn saveFileDelete() void {
    cancelSaveFileRoll();
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
    cancelDialogueText();
    if (madeline) {
        play(sound_ids.sfx_ui_game_textbox_madeline_in);
    } else {
        play(sound_ids.sfx_ui_game_textbox_other_in);
    }
}

pub fn dialogueBoxOut(madeline: bool) void {
    cancelDialogueText();
    if (madeline) {
        play(sound_ids.sfx_ui_game_textbox_madeline_out);
    } else {
        play(sound_ids.sfx_ui_game_textbox_other_out);
    }
}

pub fn dialogueAdvance(madeline: bool) void {
    cancelDialogueText();
    if (madeline) {
        play(sound_ids.sfx_ui_game_textadvance_madeline);
    } else {
        play(sound_ids.sfx_ui_game_textadvance_other);
    }
}

pub fn dialogueText(voice: DialogueVoice) void {
    cancelDialogueText();
    dialogue_text_handle = audio.playSoundEffect(dialogueTextSound(voice));
    if (dialogue_text_handle != 0) audio.setSoundEffectVolume(dialogue_text_handle, dialogue_text_volume);
}

fn play(sound_id: u16) void {
    _ = audio.playSoundEffect(sound_id);
}

fn cancelSaveFileRoll() void {
    if (save_file_roll_handle == 0) return;
    _ = audio.cancelSoundEffect(save_file_roll_handle);
    save_file_roll_handle = 0;
}

fn cancelDialogueText() void {
    if (dialogue_text_handle == 0) return;
    _ = audio.cancelSoundEffect(dialogue_text_handle);
    dialogue_text_handle = 0;
}

fn dialogueTextSound(voice: DialogueVoice) u16 {
    return switch (voice) {
        .generic => sound_ids.sfx_ui_game_text_general,
        .madeline_normal => nextMadelineNormal(),
        .madeline_angry => nextMadelineAngry(),
        .madeline_sad => nextMadelineSad(),
        .granny_normal => nextGrannyNormal(),
        .granny_mock => nextGrannyMock(),
        .granny_laugh => nextGrannyLaugh(),
    };
}

fn nextMadelineNormal() u16 {
    const sound_id = switch (dialogue_madeline_normal_index) {
        0 => sound_ids.sfx_madeline_normal_mid_a_01,
        1 => sound_ids.sfx_madeline_normal_mid_a_02,
        2 => sound_ids.sfx_madeline_normal_mid_a_03,
        3 => sound_ids.sfx_madeline_normal_mid_a_04,
        else => sound_ids.sfx_madeline_normal_mid_a_05,
    };
    dialogue_madeline_normal_index = (dialogue_madeline_normal_index + 1) % 5;
    return sound_id;
}

fn nextMadelineAngry() u16 {
    const sound_id = switch (dialogue_madeline_angry_index) {
        0 => sound_ids.sfx_madeline_angry_mid_a_01,
        1 => sound_ids.sfx_madeline_angry_mid_a_02,
        2 => sound_ids.sfx_madeline_angry_mid_a_03,
        3 => sound_ids.sfx_madeline_angry_mid_a_04,
        else => sound_ids.sfx_madeline_angry_mid_a_05,
    };
    dialogue_madeline_angry_index = (dialogue_madeline_angry_index + 1) % 5;
    return sound_id;
}

fn nextMadelineSad() u16 {
    const sound_id = switch (dialogue_madeline_sad_index) {
        0 => sound_ids.sfx_madeline_sad_mid_a_01,
        1 => sound_ids.sfx_madeline_sad_mid_a_02,
        2 => sound_ids.sfx_madeline_sad_mid_a_03,
        3 => sound_ids.sfx_madeline_sad_mid_a_04,
        else => sound_ids.sfx_madeline_sad_mid_a_05,
    };
    dialogue_madeline_sad_index = (dialogue_madeline_sad_index + 1) % 5;
    return sound_id;
}

fn nextGrannyNormal() u16 {
    const sound_id = switch (dialogue_granny_normal_index) {
        0 => sound_ids.sfx_granny_normal_mid_a_01,
        1 => sound_ids.sfx_granny_normal_mid_a_02,
        2 => sound_ids.sfx_granny_normal_mid_a_03,
        3 => sound_ids.sfx_granny_normal_mid_a_04,
        else => sound_ids.sfx_granny_normal_mid_a_05,
    };
    dialogue_granny_normal_index = (dialogue_granny_normal_index + 1) % 5;
    return sound_id;
}

fn nextGrannyMock() u16 {
    const sound_id = switch (dialogue_granny_mock_index) {
        0 => sound_ids.sfx_granny_mock_mid_a_01,
        1 => sound_ids.sfx_granny_mock_mid_a_02,
        2 => sound_ids.sfx_granny_mock_mid_a_03,
        3 => sound_ids.sfx_granny_mock_mid_a_04,
        else => sound_ids.sfx_granny_mock_mid_a_05,
    };
    dialogue_granny_mock_index = (dialogue_granny_mock_index + 1) % 5;
    return sound_id;
}

fn nextGrannyLaugh() u16 {
    const sound_id = switch (dialogue_granny_laugh_index) {
        0 => sound_ids.sfx_granny_laugh_mid_a_01,
        1 => sound_ids.sfx_granny_laugh_mid_a_02,
        2 => sound_ids.sfx_granny_laugh_mid_a_03,
        3 => sound_ids.sfx_granny_laugh_mid_a_04,
        else => sound_ids.sfx_granny_laugh_mid_a_05,
    };
    dialogue_granny_laugh_index = (dialogue_granny_laugh_index + 1) % 5;
    return sound_id;
}
