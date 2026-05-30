# Refactor Agent Prompt

You are a fresh coding agent taking over the Zeleste codebase after the
prologue milestone. Your job is to review the runtime architecture, create your
own refactor plan, and then perform the refactor. Do not treat this document as
a plan. Treat it as the task prompt and build the plan yourself from the code.

The immediate problem is that `src/main.zig` has grown into a roughly 7k-line
single-file prototype. The prologue is considered done, the dummy overworld
transition exists, and chapter 1 city is now where the game begins. Before new
gameplay work continues, split the runtime into clearer modules and improve the
internal abstractions without changing gameplay behavior.

Required first steps:

- Read `AGENTS.md`.
- Read `docs/current-status.md`.
- Read `docs/runtime-architecture.md`.
- Read `docs/asset-pipeline.md`.
- Inspect `src/main.zig`, `src/generated_rooms.zig`, `build.zig`, and the
  relevant asset/tooling code before editing.
- Check `git status --short` and preserve unrelated user work. Do not revert
  changes you did not make.

Primary objective:

Refactor the runtime so it is easier to extend chapter 1 without the whole game
living in `src/main.zig`. Preserve the current visible behavior of the completed
prologue, overworld placeholder, and chapter 1 room wiring.

You should identify the module boundaries yourself. Likely areas to evaluate
include, but are not limited to, player movement/state, collision queries,
camera/room transitions, room asset loading, bridge/end-level transition logic,
cutscenes/NPCs, visual effects, hair rendering/simulation, object drawing,
audio, and generated room data adapters.

Important constraints:

- Do not combine the refactor with gameplay tuning, physics changes, animation
  changes, art changes, or asset annotation changes unless a tiny compatibility
  adjustment is required by the refactor.
- Keep generated files generated. Treat `src/generated/**` and
  `src/generated_rooms.zig` as build outputs.
- Keep movement and collision behavior stable. This code is fragile and should
  be moved with focused care, not redesigned.
- Prefer small, reviewable module extractions over a speculative architecture
  rewrite.
- Preserve GBA memory/tile/palette assumptions. Object indices, palette banks,
  tile ranges, and screenblock choices are part of the runtime contract.
- Update docs when module boundaries or runtime ownership changes.
- Keep build commands working:
  - `zig build assets`
  - `zig build`
  - `zig build -- 0 3`
  - `zig build -- 1 1`

Expected deliverables:

- A refactor plan you create after reading the code.
- Implemented module splits and abstraction cleanup.
- `src/main.zig` substantially reduced and left as orchestration/entrypoint
  rather than the owner of every subsystem.
- Clear documentation updates explaining the new runtime boundaries.
- Passing verification builds.
- A concise final report describing what moved, what behavior was preserved,
  and any remaining risk.

Suggested working style:

Start by mapping the current global state, update functions, draw functions, and
data-loading functions. Then choose seams that let you move cohesive groups with
minimal behavior changes. After each extraction, build. If a boundary needs a
temporary compatibility layer to avoid broad churn, use one and document it.

Do not stop after proposing a plan. Once you have enough context, perform the
refactor and verify it.
