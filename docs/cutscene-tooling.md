# Cutscene Tooling

This project should use small bespoke cutscene tools before building a general
timeline editor. A cutscene tool is allowed to be room-specific, but it should
emit data in a shape the runtime can later interpret consistently.

## GBA Pattern

Most GBA-era cutscenes are simple command scripts:

- lock player control;
- move or face actors;
- move the camera;
- show a dialogue box;
- wait for player confirm to advance text;
- set a room/chapter flag;
- unlock player control.

That is the right model here. Spatial authoring should happen visually in HTML.
The dialogue sequence should remain a readable data/script file.

## Bootstrap Flow

When creating a new bespoke cutscene tool:

1. Read the target room image and any existing `*_scene.json` or annotation JSON.
2. Ask the user for, or use their provided, natural-language cutscene summary.
3. Create a first-pass tool with only the objects needed by that cutscene.
4. Let the user drag/edit trigger boxes, actor anchors, player target markers,
   camera targets, dialogue box placement, and optional movement paths.
5. Save source data beside the room image as `<room>_cutscene.json`, for example
   `assets/chapters/prologue_a/2_cutscene.json`.
6. Add the build step only after the JSON shape is stable enough to pack.

Do not add generic "kind" systems until at least two cutscenes need the same
behavior. Reuse UI helpers and data conventions, not premature runtime
abstractions.

## Tool UX Checklist

A bespoke cutscene editor should include:

- room image selector, or hard-code one room if the tool is only for one scene;
- zoom, pan, and grid toggle;
- draggable actor anchors with labels;
- draggable player target markers;
- rectangle drawing for triggers and camera regions;
- dialogue box placement preview;
- ordered dialogue/script list with editable speaker, text, and optional portrait;
- preview step button that highlights the currently selected script command;
- save button that writes JSON into the chapter folder;
- clear/delete controls for every placed object.

Keep the tool direct. Dragging markers and rectangles is better than editing
raw coordinates.

## Source JSON Shape

Use this as the first-pass source format. Bespoke tools may omit unused fields.

```json
{
  "version": 1,
  "id": "granny_intro",
  "room": "2",
  "trigger": { "x": 120, "y": 96, "w": 40, "h": 32 },
  "actors": [
    {
      "id": "granny",
      "kind": "granny",
      "x": 176,
      "y": 112,
      "facing": "left",
      "sprite": "granny"
    }
  ],
  "markers": {
    "madeline_talk": { "x": 144, "y": 120 },
    "camera_focus": { "x": 152, "y": 96 },
    "dialogue_box": { "x": 8, "y": 104, "w": 224, "h": 48 }
  },
  "script": [
    { "op": "lock_player" },
    { "op": "walk_player_to", "marker": "madeline_talk" },
    { "op": "face", "actor": "player", "dir": "right" },
    { "op": "camera_to", "marker": "camera_focus", "frames": 24 },
    {
      "op": "say",
      "speaker": "Madeline",
      "portrait": "madeline_neutral",
      "text": "Excuse me, ma'am?"
    },
    { "op": "set_flag", "flag": "granny_intro_done" },
    { "op": "unlock_player" }
  ]
}
```

For dialogue, keep each `say` entry as one player-advanced text page. The tool
can wrap text visually, but the source string should remain human-readable.

## Runtime Opcodes

Start with a small interpreter:

- `lock_player`
- `unlock_player`
- `walk_player_to`
- `face`
- `play_anim`
- `camera_to`
- `wait_frames`
- `say`
- `set_flag`

The interpreter should run during gameplay update after input polling and before
normal player movement. While a `say` command is active, A/B should advance to
the next text page. Normal player input stays locked.

## Dialogue Box

First-pass dialogue should be tile based:

- draw a rectangular box near the bottom or top of the screen;
- use a small 8x8 or narrower bitmap font;
- reserve space for an optional portrait/face tile on the left;
- show speaker name only if it improves readability;
- advance text on A/B;
- keep line width conservative, roughly 24-28 characters for a full-width box.

Portraits can be OBJ sprites or box-local BG tiles. Prefer simple authored pixel
faces once the text system exists.

## Granny Intro First Pass

For room `2`, the first bespoke tool should support:

- trigger rectangle near Granny's shack;
- Granny actor anchor and facing;
- Madeline talk target;
- camera focus marker;
- dialogue box rectangle;
- ordered dialogue pages for the full Granny exchange.

Do not implement every scripted animation from the original on the first pass.
Get the lock, placement, text, player-advance, and unlock flow working first.

The current editor is `task granny-cutscene`. It writes
`assets/chapters/prologue_a/2_cutscene.json` and intentionally stops at source
authoring. Runtime packing/interpreter work should come after the JSON has been
reviewed in the editor.

The editor discovers Granny animation PNG sheets from `assets/animations/granny/`
and allows dialogue pages to attach a `cue` played while the page is active, plus
an `afterCue` played after the page advances. These cues intentionally reference
source sheet IDs; the later packer should trim opaque frame bounds and build GBA
metasprites rather than requiring the source art to fit square grid cells.
If a dialogue page has no explicit `cue`, the generated script treats Granny as
playing `idle` by default. The editor also supports `camera_focus_2` plus
`camera.secondary.afterDialogue` for a later zoom beat in the same exchange.

## Prologue Room 3 Endscene

This source data replaces the older idea of an optional player-controlled
bridge-ending dash. The intended semantics are deterministic: when Madeline
jumps from the authored takeoff point on the second-to-last bridge platform, the
scene locks input, starts the bird fly-in/dash prompt, drops the old final
platform using the existing bridge-ending data, waits until she reaches the
lower bridge-side `dashCuePoint`, holds her there for the dash cue, then sends
her rightward through `dashTarget`, finishes chapter 0, and loads the overworld.

The source data should stay semantic: `takeoffPlatform` and `takeoffPoint` come
from the authored annotation; `collapsePlatform` and `birdDashPrompt` come from
the previous room 3 `bridgeEnding.platform` and `bridgeEnding.hint` values in
`3_scene.json`; `dashCuePoint` is the low freeze point close to the falling
bridge platform; and `dashTarget` is where the scripted ending dash carries
Madeline. Do not derive the freeze from the first moment the ending trigger
fires, because that catches her too high and too far left.

## Chapter 1 6zb NPC Intro

The current editor is `task city-6zb-cutscene`. It writes
`assets/chapters/1_city/6zb_cutscene.json` and intentionally stops at source
authoring. Runtime packing/interpreter work should come after the JSON has been
reviewed in the editor.

This room can be approached from multiple places, so the source data uses a
`triggers` array instead of a single `trigger` rectangle. All triggers feed the
same first-pass script: lock input, walk Madeline to `madeline_talk`, face the
NPC, focus the camera, play the initial `dialogue` pages, set
`city_6zb_intro_done`, then unlock input. The `postConversations` array stores
the optional Theo talks that can be triggered one after another after the
cutscene flag is set. These are not inserted into the forced cutscene script.
The older flat `postDialogue` field is only kept as a migration fallback for
first-pass editor data.

## Chapter 1 End Outro

The current editor is `task city-end-cutscene`. It writes
`assets/chapters/1_city/end_cutscene.json`; the assets build packs that source
into `src/generated/assets/city/end_cutscene.zig` for the ROM. The source data
keeps the memorial trigger/text separate from the forced outro trigger so the
monument can be tuned independently from the campfire sequence.

This is a first-pass implementation. The script records semantic beats for
turning Madeline left, saying the exhaustion line, walking to the campfire,
showing placeholder campfire and bird sprites, saying the mistake line, wiping
to black, and showing `assets/chapter_endings/city-nap.png`. Later work should
replace the placeholders with authored sitting/campfire/bird animations without
changing the trigger and timing data shape unless the scene needs new beats.
