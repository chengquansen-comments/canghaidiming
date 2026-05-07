# Content Engine v1.8 whitelist full package candidate path

## 目标
在白名单 `battle_slot=prologue_01` 范围内，构造 full package candidate bundle，仅用于测试 probe 报告，不接入正式流程。

## 核心约束
- `content_engine_enabled=false`
- `selected_reward=legacy`
- `runtime_loader_config=disabled`
- 不写 `data/runtime/`
- 不改 Godot 正式 runtime 流程

## 输出
- `data/design/generated_full_package_candidate_path_report.tsv`

## domain candidate 规则
- `battle_slot`：`prologue_01` candidate。
- `reward`：`rw_prologue_01` candidate。
- `enemy_deck`：若无直绑，标记不可用并注明未绑定。
- `card_pool`：候选数 72，不进入正式 `CardData`。
- `operation_node`：候选数 10，不进入正式地图流程。
- `narrative`：只允许 key/hook，不允许正文。
- `route_gate`：候选数 9，不进入正式路线逻辑。

## 接入
- `content_engine_check.py` 增加 `full_package_candidate_path_validator`。
- `content_engine_acceptance_runner.py` 增加 probe + validator。
- `content_engine_acceptance_validator.py` 校验 summary 覆盖新增 step。
