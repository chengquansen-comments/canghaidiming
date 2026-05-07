# Content Engine v0.1 Tools

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
