# Content Engine v2.8：Generated Battle Runtime Loadout

## 目标
- 将 11 个白名单 battle_slot 的 generated `enemy_deck + card_pool` 推进为 battle setup 可消费的 loadout candidate。
- 非白名单保持 legacy，fallback_policy 保持 `legacy`。

## 本步范围
- 补齐 `GeneratedBattleDomainAdapter` runtime loadout candidate 输出。
- 在 `battle_controller_visual_narrative_context_loadout` 挂载 `generated_battle_runtime_loadout_candidate`。
- 仅提供只读候选，不写 `CardData`、`battle_state`、`combat_result`。

## 验收产物
- `data/design/generated_battle_runtime_loadout_report.tsv`

## 验收命令
- `godot --headless --path . --script tools/content_engine/generated_battle_runtime_loadout_probe.gd`
- `python3 tools/content_engine/generated_battle_runtime_loadout_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`
