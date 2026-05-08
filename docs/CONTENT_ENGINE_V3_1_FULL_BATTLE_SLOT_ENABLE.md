# Content Engine v3.1：全量 Preview Battle Slot 生成内容扩展

## 阶段定位
本阶段将白名单从 v3.0 的 11 个 battle_slot 扩展到 `battle_slots.preview.json` 的全部 16 个 slot。
目标是让 16 个 slot 都具备 7 domain 的 generated candidate 可消费能力，并保持正式流程安全边界。

## 范围与边界
- 覆盖 domain：`battle_slot`、`enemy_deck`、`card_pool`、`reward`、`operation_node`、`narrative`、`route_gate`。
- 仅扩展白名单与桥接数据，不改战斗核心语义。
- 保持 `fallback_policy=legacy`。
- 保持 narrative 仅 `key/hook`，不生成正式正文。
- 保持 route_gate 仅候选，不直接改变正式分流。
- 不写 `data/runtime/content_engine/*.json`。

## 产物
- `data/design/generated_full_battle_slot_whitelist_config.tsv`
- `data/design/generated_full_battle_slot_binding_map.tsv`
- `data/design/generated_full_battle_slot_integration_report.tsv`
- `data/runtime/content_engine_whitelist/generated_full_battle_slots.full_content_bridge.json`
- `data/runtime/content_engine_whitelist/generated_full_battle_slots_manifest.json`

## 关键规则
1. 16 个 preview battle_slot 全部纳入白名单。
2. 每个 slot 覆盖 7 domain。
3. `card_pool_count=72`、`operation_node_count=10`、`narrative_count=28`、`route_gate_count=9`。
4. `prologue_01` 的 reward 仍为 `rw_prologue_01`。
5. 若某 slot 缺 reward，则仅 reward 域回落 legacy，其他域不受影响。

## 验证命令
```bash
python3 tools/content_engine/generated_full_battle_slot_expander.py
python3 tools/content_engine/generated_full_battle_slot_validator.py
python3 tools/content_engine/content_engine_check.py
python3 tools/content_engine/content_engine_acceptance_runner.py
python3 tools/content_engine/content_engine_acceptance_validator.py
```
