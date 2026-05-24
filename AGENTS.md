This is a demake of the platformer Celeste to GBA.

- Read and update PLAN.md when large milestones are completed or planned.
- Read docs/current-status.md before changing gameplay behavior.
- Read docs/runtime-architecture.md before changing src/main.zig or room state.
- Read docs/asset-pipeline.md before changing source assets, generated assets,
  room annotations, or build steps.
- Read tools/AGENTS.md before changing asset pipeline scripts or editor tools.
- Keep movement changes small and reference-driven. Do not combine broad
  refactors with player physics, collision, or room-transition fixes.
- Treat src/generated/** and src/generated_rooms.zig as generated outputs.
