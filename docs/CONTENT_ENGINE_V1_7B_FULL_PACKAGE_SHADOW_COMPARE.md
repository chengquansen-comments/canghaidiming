# Content Engine v1.7b full package shadow compare + domain switch matrix

## 阶段目标
基于 v1.7 full preview readonly probe 的结果，新增 domain switch matrix，并对 `prologue_01` 执行 full package shadow compare。

## 关键约束
- 7 个 domain 全部 `default_mode=legacy`。
- 7 个 domain 全部 `source_mode=shadow_compare`。
- `enabled_scope` 仅 `prologue_01`。
- `content_engine_enabled=false`，不得全局启用。
- 正式流程仍使用 legacy，不改 gameplay state。

## 输出文件
- `data/design/generated_content_domain_switch_matrix.tsv`
- `data/design/generated_full_package_shadow_compare_report.tsv`

## Shadow Compare 说明
- `battle_slot`：验证 `prologue_01` candidate。
- `reward`：验证 `rw_prologue_01` candidate。
- `enemy_deck`：若无直绑则标记未绑定，不强行推断。
- `card_pool`：只记录候选可用数量，不进入正式 `CardData`。
- `operation_node`：只记录可用数量，不进入正式地图流程。
- `narrative`：只记录 key/hook，不写正文。
- `route_gate`：只记录 candidate，不进入正式路线逻辑。

## 接入
- `content_engine_check.py` 增加 `full_package_shadow_compare_validator` 步骤。
- `content_engine_acceptance_runner.py` 顺序增加 probe 与 validator。
- `content_engine_acceptance_validator.py` 校验 summary 覆盖新 step。
