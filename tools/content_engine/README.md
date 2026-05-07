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
