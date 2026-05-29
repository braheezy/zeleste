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
