# Content Engine v2.7：Generated Content Whitelist Slice

## 目标
- 将 v2.6 的 `prologue_01` 单点白名单扩展为“序章 + 武举线”切片白名单。
- 继续保持 fallback_policy=`legacy`，非白名单不启用 generated content。

## 产物
- `data/design/generated_slice_whitelist_config.tsv`
- `data/design/generated_slice_whitelist_binding_map.tsv`
- `data/design/generated_slice_whitelist_acceptance_report.tsv`
- `data/runtime/content_engine_whitelist/generated_slice.full_content_bridge.json`
- `data/runtime/content_engine_whitelist/generated_slice_manifest.json`

## 规则
- slot 发现：`prologue*` 或命中 `wuju/weapon/exam/武举/武器/考试`。
- 每个白名单 slot 覆盖 7 domain。
- `card_pool` 仅 candidate，不写 `CardData`。
- `narrative` 仅 key/hook，不生成正文。
- `route_gate` 仅 candidate，不直接改变正式分流。

## 验收
- `python3 tools/content_engine/generated_slice_whitelist_expander.py`
- `python3 tools/content_engine/generated_slice_whitelist_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`
