# Content Engine Tools

This directory contains the first numeric planning tools for Content Engine.

## Scope

v0.1.1 reads `data/design/progression_numeric_config_v1_3.tsv` and generates design-only planning tables:

- `data/design/generated_battle_slot_plan.tsv`
- `data/design/generated_enemy_deck_requirement.tsv`
- `data/design/generated_route_progression_curve.tsv`
- `data/design/generated_operation_node_requirement.tsv`

It does not generate cards, enemy decks, runtime JSON, Godot scenes, or combat code.

## Build

```bash
python3 tools/content_engine/progression_plan_builder.py \
  --config data/design/progression_numeric_config_v1_3.tsv \
  --out-dir data/design
```

If the config file is missing, the builder writes a minimal runnable sample at the requested path and then generates the four planning tables from fallback values.

## Validate

```bash
python3 tools/content_engine/progression_validator.py \
  --design-dir data/design
```

The validator prints `PASS`, `WARN`, and `FAIL` lines. It exits with code `1` when any required check fails.
Operation node ratio (`30%-40%`) is now validated from `generated_operation_node_requirement.tsv`, not only from docs.
This table is also the planned input for `operation_node_generator` and `narrative_node_generator`.

For v0.2, `enemy_archetype_generator` should consume both battle-slot and operation-node structures to avoid overproducing combat-only content.

## v0.2 Archetype Generator

Generate deterministic enemy archetype skeletons:

```bash
python3 tools/content_engine/enemy_archetype_generator.py \
  --design-dir data/design \
  --out data/design/generated_enemy_archetype_pool.tsv
```

Validate generated archetype pool:

```bash
python3 tools/content_engine/enemy_archetype_validator.py \
  --design-dir data/design
```

v0.2 still does not generate concrete decks or card lists. It only produces archetype pool structure for v0.3 deck skeleton work.

## v0.3 Deck Skeleton Generator

Generate deterministic enemy deck skeletons:

```bash
python3 tools/content_engine/enemy_deck_skeleton_generator.py \
  --design-dir data/design \
  --out data/design/generated_enemy_deck_skeleton.tsv
```

Validate generated deck skeletons:

```bash
python3 tools/content_engine/enemy_deck_skeleton_validator.py \
  --design-dir data/design
```

v0.3 still does not fill concrete `card_id` values, generate formal enemy decks, generate formal cards, modify Godot runtime logic, or call an LLM API. It only produces deck skeleton constraints for v0.4 card pool and enemy deck set generation.

## v0.4a Card Pool Generator

Generate deterministic design-layer card pool:

```bash
python3 tools/content_engine/card_pool_generator.py \
  --design-dir data/design \
  --out data/design/generated_card_pool.tsv
```

Validate generated card pool:

```bash
python3 tools/content_engine/card_pool_validator.py \
  --design-dir data/design
```

v0.4a still does not generate runtime card data, does not fill enemy deck sets, does not modify `card_data.gd` / `combat_resolver.gd` / `battle_state_machine.gd`, and does not call an LLM API.

## v0.4b Enemy Deck Sets Generator

Generate deterministic design-layer enemy deck sets:

```bash
python3 tools/content_engine/enemy_deck_sets_generator.py \
  --design-dir data/design \
  --out data/design/generated_enemy_deck_sets.tsv
```

Validate generated enemy deck sets:

```bash
python3 tools/content_engine/enemy_deck_sets_validator.py \
  --design-dir data/design
```

v0.4b still does not write runtime deck data, does not modify runtime combat scripts, and does not call an LLM API.

## v0.5a Battle Reward Generator

Generate deterministic design-layer battle reward plan:

```bash
python3 tools/content_engine/battle_reward_generator.py \
  --design-dir data/design \
  --out data/design/generated_battle_reward_plan.tsv
```

Validate generated reward plan:

```bash
python3 tools/content_engine/battle_reward_validator.py \
  --design-dir data/design
```

v0.5a only produces design-layer reward planning; it does not write runtime reward data and does not modify Godot runtime scripts.

## v0.5b Operation Node Generator

Generate deterministic design-layer operation node plan:

```bash
python3 tools/content_engine/operation_node_generator.py \
  --design-dir data/design \
  --out data/design/generated_operation_node_plan.tsv
```

Validate generated operation node plan:

```bash
python3 tools/content_engine/operation_node_validator.py \
  --design-dir data/design
```

v0.5b only produces design-layer operation nodes; it does not generate narrative text, route gates, or runtime operation data.

## v0.5c Narrative Node Generator

Generate deterministic design-layer narrative node skeleton plan:

```bash
python3 tools/content_engine/narrative_node_generator.py \
  --design-dir data/design \
  --out data/design/generated_narrative_node_plan.tsv
```

Validate generated narrative node skeleton plan:

```bash
python3 tools/content_engine/narrative_node_validator.py \
  --design-dir data/design
```

v0.5c only produces narrative skeleton structure (keys, tags, flags, roles). It does not write formal narrative body text, route gate tables, runtime narrative data, or any combat runtime logic.

## v0.5d Route Gate Generator

Generate deterministic design-layer route gate plan:

```bash
python3 tools/content_engine/route_gate_generator.py \
  --design-dir data/design \
  --out data/design/generated_route_gate_plan.tsv
```

Validate generated route gate plan:

```bash
python3 tools/content_engine/route_gate_validator.py \
  --design-dir data/design
```

v0.5d only produces design-layer route gate structure by aggregating battle reward / operation node / narrative node tags and flags. It does not write runtime route gate data and does not modify Godot combat runtime scripts.

## v0.6a Content Package Manifest

Generate design-layer content package manifest:

```bash
python3 tools/content_engine/content_package_manifest_generator.py \
  --design-dir data/design \
  --out data/design/generated_content_package_manifest.tsv
```

Validate manifest integrity:

```bash
python3 tools/content_engine/content_package_manifest_validator.py \
  --design-dir data/design
```

v0.6a only records design-layer artifacts, dependencies, row counts, checksums, validator status fields, and runtime export blockers. It does not generate runtime data, does not implement a runtime exporter, and does not modify Godot runtime scripts.

## v0.6b Content Package Report

Generate design-layer content package report from manifest:

```bash
python3 tools/content_engine/content_package_report_generator.py \
  --design-dir data/design \
  --out data/design/generated_content_package_report.md
```

Validate report integrity:

```bash
python3 tools/content_engine/content_package_report_validator.py \
  --design-dir data/design
```

v0.6b only reads `generated_content_package_manifest.tsv` and renders a stable Markdown summary of artifact inventory, dependency links, validator status aggregation, runtime blockers, and review risks. It does not rerun validators, does not generate runtime data, and does not modify Godot runtime scripts.

## v0.6c Validator Orchestration

Run all existing design-layer validators through one entrypoint:

```bash
python3 tools/content_engine/content_validator_orchestrator.py \
  --design-dir data/design \
  --out-tsv data/design/generated_validator_summary.tsv \
  --out-md data/design/generated_validator_summary.md
```

Validate validator summary outputs:

```bash
python3 tools/content_engine/content_validator_summary_validator.py \
  --design-dir data/design
```

v0.6c only orchestrates validators, writes `generated_validator_summary.tsv`, `generated_validator_summary.md`, and `data/design/validator_logs/*.log`, and keeps the workflow fully inside the design layer. It does not rerun generators, does not export runtime data, and does not modify Godot runtime scripts.


## v0.6d Content Package Approval Gate

Generate design-layer content package approval table and report:

```bash
python3 tools/content_engine/content_package_approval_generator.py   --design-dir data/design   --out data/design/generated_content_package_approval.tsv   --out-md data/design/generated_content_package_approval_report.md
```

Validate approval outputs:

```bash
python3 tools/content_engine/content_package_approval_validator.py   --design-dir data/design
```

v0.6d only produces an approval template layer from manifest + validator summary. It does not auto-approve any artifact, does not export runtime data, and does not modify Godot runtime scripts.


## v0.7a Runtime Schema Proposal

Generate runtime schema proposal from governance tables:

```bash
python3 tools/content_engine/runtime_schema_proposal_generator.py \
  --design-dir data/design \
  --out data/design/generated_runtime_schema_proposal.tsv \
  --out-md data/design/generated_runtime_schema_proposal.md
```

Validate runtime schema proposal:

```bash
python3 tools/content_engine/runtime_schema_proposal_validator.py \
  --design-dir data/design
```

v0.7a only defines runtime export schema proposal and policy boundaries. It does not create runtime JSON files, does not implement runtime exporter, and does not modify Godot runtime scripts.

## v0.7b Runtime Export Dry-Run

Generate runtime export dry-run decision table and report:

```bash
python3 tools/content_engine/runtime_export_dry_run.py \
  --design-dir data/design \
  --out data/design/generated_runtime_export_dry_run.tsv \
  --out-md data/design/generated_runtime_export_dry_run.md
```

Validate dry-run outputs:

```bash
python3 tools/content_engine/runtime_export_dry_run_validator.py \
  --design-dir data/design
```

v0.7b simulates export decisions from manifest + validator summary + approval + runtime schema proposal. It does not write runtime JSON, does not create `data/runtime/content_engine/`, and does not modify Godot runtime scripts.

## v0.7c Runtime Export Approval Overlay

Prepare manual approval table:

`data/design/runtime_export_approval.tsv`

Generate overlay results:

```bash
python tools/content_engine/runtime_export_approval_overlay.py \
  --design-dir data/design \
  --approval-tsv data/design/runtime_export_approval.tsv \
  --out data/design/generated_runtime_export_approval_overlay.tsv \
  --out-md data/design/generated_runtime_export_approval_overlay.md
```

Validate approval + overlay outputs:

```bash
python tools/content_engine/runtime_export_approval_validator.py \
  --design-dir data/design
```

v0.7c only applies manual approval overlay and waiver gating on top of dry-run inputs. It does not implement runtime exporter, does not write runtime JSON, does not create `data/runtime/content_engine/`, and does not modify Godot runtime scripts.

## v0.7d Runtime Export Diff Report

Generate runtime export diff report from overlay:

```bash
python3 tools/content_engine/runtime_export_diff_report.py \
  --design-dir data/design \
  --overlay data/design/generated_runtime_export_approval_overlay.tsv \
  --out data/design/generated_runtime_export_diff_report.tsv \
  --out-md data/design/generated_runtime_export_diff_report.md
```

Validate diff report outputs:

```bash
python3 tools/content_engine/runtime_export_diff_report_validator.py \
  --design-dir data/design
```

v0.7d only produces design-layer planned export diff records. It does not implement runtime exporter, does not write runtime files, and does not create `data/runtime/content_engine/`.

## v0.8a Runtime Exporter Scaffold (No-Write)

Generate exporter scaffold plan from diff report:

```bash
python3 tools/content_engine/runtime_exporter.py \
  --design-dir data/design \
  --diff-report data/design/generated_runtime_export_diff_report.tsv \
  --out data/design/generated_runtime_exporter_plan.tsv \
  --out-md data/design/generated_runtime_exporter_plan.md
```

Validate exporter scaffold plan:

```bash
python3 tools/content_engine/runtime_exporter_validator.py \
  --design-dir data/design
```

v0.8a keeps exporter in preview-only mode and does not write runtime files. `--write-runtime` is intentionally disabled in this stage.

## v0.8b Runtime Exporter Guarded Write Mode

Generate exporter plan + write-result in default no-write mode:

```bash
python3 tools/content_engine/runtime_exporter.py \
  --design-dir data/design \
  --diff-report data/design/generated_runtime_export_diff_report.tsv \
  --out data/design/generated_runtime_exporter_plan.tsv \
  --out-md data/design/generated_runtime_exporter_plan.md \
  --write-result-out data/design/generated_runtime_exporter_write_result.tsv \
  --write-result-md data/design/generated_runtime_exporter_write_result.md
```

Guarded write (requires both flags):

```bash
python3 tools/content_engine/runtime_exporter.py \
  --write-runtime \
  --confirm-runtime-export
```

Validate no-write outputs:

```bash
python3 tools/content_engine/runtime_exporter_validator.py \
  --design-dir data/design
```

Validate guarded-write outputs:

```bash
python3 tools/content_engine/runtime_exporter_validator.py \
  --design-dir data/design \
  --allow-runtime-files
```

v0.8b keeps no-write as safe default. Runtime write is enabled only when both `--write-runtime` and `--confirm-runtime-export` are present. Guarded write allowlist is limited to:

- `data/runtime/content_engine/card_pool.json`
- `data/runtime/content_engine/battle_reward.json`

This stage only writes runtime content files and does not modify Godot loader/runtime logic.

## v0.8c Runtime Manifest / Checksum / Rollback Report

Generate runtime manifest + checksum report + rollback report:

```bash
python3 tools/content_engine/runtime_export_manifest.py \
  --write-result data/design/generated_runtime_exporter_write_result.tsv \
  --out-manifest data/runtime/content_engine/runtime_manifest.json \
  --out-report data/design/generated_runtime_export_manifest_report.tsv \
  --out-report-md data/design/generated_runtime_export_manifest_report.md \
  --out-rollback-md data/design/generated_runtime_export_rollback_report.md
```

Validate manifest outputs:

```bash
python3 tools/content_engine/runtime_export_manifest_validator.py
```

v0.8c only governs runtime content files and adds audit metadata:

- runtime manifest registry (`runtime_manifest.json`)
- runtime file checksum (`sha256`) and file size tracking
- rollback operation report

This stage does not connect to Godot loader and does not modify Godot runtime or battle logic.

## v0.8d Godot Loader Preflight Report (Analysis-Only)

Generate loader preflight report from runtime manifest + runtime files:

```bash
python3 tools/content_engine/runtime_loader_preflight.py \
  --manifest data/runtime/content_engine/runtime_manifest.json \
  --manifest-report data/design/generated_runtime_export_manifest_report.tsv \
  --card-pool data/runtime/content_engine/card_pool.json \
  --battle-reward data/runtime/content_engine/battle_reward.json \
  --out data/design/generated_runtime_loader_preflight_report.tsv \
  --out-md data/design/generated_runtime_loader_preflight_report.md
```

Validate preflight outputs:

```bash
python3 tools/content_engine/runtime_loader_preflight_validator.py
```

v0.8d is preflight-only:

- no Godot loader implementation
- no `.gd` runtime/loader file changes
- manifest-first read strategy proposal only
- failure mode + fallback strategy proposal only


## v0.8e Read-Only Godot Loader Scaffold

Run static scaffold probe:

```bash
python3 tools/content_engine/runtime_loader_scaffold_probe.py
```

Validate scaffold constraints:

```bash
python3 tools/content_engine/runtime_loader_scaffold_validator.py
```

v0.8e only adds an isolated read-only loader scaffold file:

- `scripts/content_engine_runtime_loader.gd`
- manifest-first entry and whitelist checks
- fail-closed behavior on any validation error
- `integration_status=not_integrated` (not wired into battle/main flow)

This stage does not replace existing card/reward data sources.


## v0.8f Godot Loader Probe / Headless-Only Harness

Run Godot headless probe and generate design-layer report:

```bash
python3 tools/content_engine/runtime_loader_godot_probe.py
```

Validate probe outputs and isolation constraints:

```bash
python3 tools/content_engine/runtime_loader_godot_probe_validator.py
```

v0.8f proves that Godot can call the read-only loader scaffold in headless mode.
It does not integrate loader into battle/main flow and does not replace existing card/reward data sources.


## v0.8g Negative-Case / Fixture Tests

Build isolated fixtures under `data/design/runtime_loader_negative_fixtures/`:

```bash
python3 tools/content_engine/runtime_loader_negative_fixture_builder.py
```

Run fixture probe and generate report:

```bash
python3 tools/content_engine/runtime_loader_negative_fixture_probe.py
```

Validate fixture report and isolation constraints:

```bash
python3 tools/content_engine/runtime_loader_negative_fixture_validator.py
```

v0.8g verifies fail-closed behavior across negative runtime bundle cases without touching formal runtime files.


## v0.8h CI-Friendly Regression Runner

Run unified regression chain:

```bash
python3 tools/content_engine/content_engine_regression_runner.py
```

Validate regression report:

```bash
python3 tools/content_engine/content_engine_regression_validator.py
```

v0.8h aggregates v0.7b->v0.8g checks into one CI-friendly entrypoint and reports step-level execution telemetry.
