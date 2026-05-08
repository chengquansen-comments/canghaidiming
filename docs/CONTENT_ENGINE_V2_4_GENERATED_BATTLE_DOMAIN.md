# Content Engine v2.4：prologue_01 Generated Battle Domain

## 阶段定位
- 本阶段在 v2.3 的 reward 白名单正式启用基础上，补充 battle domain（enemy_deck、card_pool）最小正式路径。
- 作用范围仅 `prologue_01`，非白名单仍走 legacy。

## 本阶段实现
- 新增 `GeneratedBattleDomainAdapter`，只读读取 whitelist bridge + runtime preview。
- 在战斗 loadout 构造层增加最小接入：
  - 白名单可读取 generated `enemy_deck` candidate，并标记来源。
  - 白名单可读取 generated `card_pool` candidate，并执行字段兼容检查。
- `card_pool` 当前仅 candidate，不写 `CardData`。
- `enemy_deck` 当前仅战斗准备候选读取，不改 `combat_resolver` 结算语义。

## 安全边界
- fallback_policy 固定 `legacy`。
- 非白名单不启用 generated battle domain。
- 不修改 `combat_resolver` / `battle_state_machine` / `data/story_battles/*.tsv` / `scenes/*.tscn`。
- 不新增全局 `data/runtime/content_engine/*.json`。

## 验收方式
- `godot --headless --path . --script tools/content_engine/generated_battle_domain_formal_probe.gd`
- `python3 tools/content_engine/generated_battle_domain_formal_validator.py`
- `python3 tools/content_engine/content_engine_check.py`
- `python3 tools/content_engine/content_engine_acceptance_runner.py`
- `python3 tools/content_engine/content_engine_acceptance_validator.py`

## 当前结论
- `prologue_01` 可读取 generated enemy_deck + card_pool candidate。
- reward 仍为 `rw_prologue_01`（白名单）。
- 正式流程回滚策略保持 `legacy`。
