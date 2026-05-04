# Refactor Backlog

This backlog tracks structural cleanup work driven by `docs/CODE_ORGANIZATION.md`.

## Principles

- Keep single code files under 25KB whenever possible.
- Start evaluating split opportunities at 20KB.
- Do not keep adding feature logic to files above 25KB.
- Avoid blind refactors of battle core files without smoke coverage.
- Prefer low-risk structural splits: controller orchestration, runtime state helpers, view helpers, formatters, and bridge helpers.
- Do not edit generated `data/*.json` directly; update source tables and rerun `python3 scripts/compile_tables.py`.

## Completed

### Narrative network map split

Status: done.

The former oversized tuned controller was split into focused layers:

- `scripts/narrative_demo_strategic_legacy_controller.gd`
- `scripts/narrative_demo_network_map_controller.gd`
- `scripts/narrative_demo_ui_focus_tuned_controller.gd`
- `scripts/strategic_network_map_runtime.gd`
- `scripts/strategic_network_map_formatter.gd`
- `scripts/strategic_network_battle_bridge.gd`

Notes:

- `narrative_demo_ui_focus_tuned_controller.gd` is no longer the large network-map owner.
- Network state helpers, preview formatting, and battle request fallback are extracted.
- The map overlay path is the primary UI path.

### Settlement mode split

Status: done.

The settlement mode controller was split into:

- `scripts/battle_controller_visual_story_selection.gd`
- `scripts/battle_controller_visual_reactive_round_flow.gd`
- `scripts/battle_controller_visual_reactive_preview_formatter.gd`
- `scripts/battle_controller_visual_settlement_mode.gd`

Notes:

- `battle_controller_visual_settlement_mode.gd` is now a thin UI glue layer.
- `_reactive_resolution_preview()` and `_range_text_safe()` remain as compatibility shims.
- The forced battle visual state sync was reverted; do not reintroduce complex controller compatibility for informal test encounters.

## Current Priority Candidates

### P1: Small / medium files suitable for direct cleanup

- `scripts/narrative_demo_strategic_legacy_controller.gd` — split card reward, ending catalog, or legacy final gate helpers.
- `tools/render_art_prompt.py` — split loader, renderer, and CLI concerns.
- `scripts/auto_battle_sampler.gd` — split sampling, statistics, and report output helpers.
- `scripts/narrative_battle_context.gd` — split player profile, card state, and battle request/result helpers.

### P2: Requires uploaded full file if remote read is truncated

- `scripts/narrative_demo_ui_focus_controller.gd`
- `scripts/battle_controller_visual_presentation.gd`

### P3: High-risk battle files

Do not split these casually without dedicated smoke tests:

- `scripts/battle_controller_core.gd`
- `scripts/battle_controller_visual_ui.gd`
- `scripts/battle_controller_visual_presentation_stepwise.gd`
- `scripts/battle_controller_visual_hot_tuning.gd`
- `scripts/battle_controller_demo_visual.gd`
- `scripts/battle_controller_visual_narrative_context.gd`

## Validation Commands

Run these after structural splits:

```bash
python3 scripts/compile_tables.py
godot --headless --quit --path .
godot --headless --path . --quit scenes/MainVisual.tscn
godot --headless --path . --quit scenes/NarrativeDemo.tscn
git diff --check
python3 tools/audit_file_sizes.py --top 50
```

## Next Recommended Work

1. Clean up stale non-overlay network map rendering functions now that the overlay path is primary.
2. Bring `scripts/narrative_demo_strategic_legacy_controller.gd` below 25KB.
3. Split `tools/render_art_prompt.py` because it is a tool script and lower risk than battle core.
4. Avoid adding compatibility code for informal test encounters that will be removed.
