# Content Engine v0.5b

## 目标

v0.5b 目标是生成设计层经营节点池：

- `data/design/generated_operation_node_plan.tsv`

该表用于承接 v0.1.1 的经营节点比例约束，并与 v0.5a 奖励曲线联动，形成可校验的经营节点规划。

## 输入文件

```text
data/design/generated_operation_node_requirement.tsv
data/design/generated_battle_reward_plan.tsv
data/design/generated_route_progression_curve.tsv
data/design/progression_numeric_config_v1_3.tsv
```

## 输出文件

```text
data/design/generated_operation_node_plan.tsv
```

## 字段说明

核心字段：

- `operation_node_id`：节点唯一 ID。
- `scope` / `route_type` / `stage`：节点生效范围与阶段。
- `node_type` / `node_subtype`：节点类别与可读身份。
- `operation_role` / `primary_function` / `secondary_function`：节点功能职责。
- `resource_cost_*` / `resource_reward_*`：资源代价与收益。
- `martial_xp_reward` / `weapon_xp_reward` / `military_merit_reward`：成长收益。
- `lightness_reward_type` / `lightness_cap_unlock`：轻功相关收益（稀缺）。
- `card_service_type` / `card_reward_pool`：卡牌服务行为。
- `narrative_hook_tags` / `route_gate_tags`：仅结构标签，不写正式叙事文本。

## 经营节点比例规则

按 requirement 约束：

- 默认经营节点约 `8`
- 总候选控制在 `8-10`
- 经营占比保持在 `30%-40%` 的设计目标区间

当前实现采用：

- 8 个默认节点
- 1 个 rare 节点
- 1 个 route 节点

## 经营节点代价规则

规则落地要点：

- 恢复节点不叠高成长。
- 军功节点绑定清望代价或风险说明。
- 旧案推进节点提高风险等级并挂接 `old_case` 标签。
- 轻功突破节点限定 rare/route 风险，不做常态奖励。
- Boss 准备节点以整备为主，不给大量武道成长。
- 武状元触发节点绑定 `high_military_merit` / `wuzhuangyuan_candidate`。

## 轻功稀缺规则

- `cap_4` 不进入普通经营节点常规池。
- `cap_3` 仅放在 rare lightness/master/old_case 相关节点。
- `rare_breakthrough` 仅允许在 `risk_level=rare|route` 节点出现。

## validator 检查项

`operation_node_validator.py` 检查：

- 文件存在性、ID 唯一性、节点数量区间。
- 必备 `node_subtype` 覆盖（校场、行营、军门、器械所、师门、市井、旧案、休整）。
- lightness 节点数量与 cap 稀缺规则。
- 武状元触发阶段与 route tag 约束。
- old_case 推进与标签约束。
- 高成长与治疗/补给叠加约束。
- 军门军功节点代价约束。
- Boss 准备节点存在性。

## 当前不做

- 不生成叙事文本。
- 不生成 route gate。
- 不写运行时 operation data。
- 不修改 story battle TSV。
- 不接 LLM API。

## 运行 generator

```bash
python3 tools/content_engine/operation_node_generator.py \
  --design-dir data/design \
  --out data/design/generated_operation_node_plan.tsv
```

## 运行 validator

```bash
python3 tools/content_engine/operation_node_validator.py \
  --design-dir data/design
```

## 进入 v0.5c

v0.5c 建议实现 `narrative_node_generator`，仅输出叙事骨架和 hook，不写长文本正文；随后再进入 route gate 组合校验。
