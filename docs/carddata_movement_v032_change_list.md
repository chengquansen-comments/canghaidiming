# 卡牌位移 v0.3.2 执行清单归档

本文档原为 v0.3.2 卡牌位移和卡牌数据改造清单，现已降级为历史记录。当前战斗配置、位移、朝向和预览规则以 [BATTLE.md](BATTLE.md) 为准。

## 历史目标

v0.3.2 的目标是让招式牌能在结算后改变自身或目标位置，并让预览面板提前展示位移结果。

当时关注的字段包括：

| 字段 | 历史含义 |
|---|---|
| `self_move_after` | 自身结算后前进或后退 |
| `target_push_after` | 击退目标 |
| `target_pull_after` | 拉近目标 |
| `range_min` / `range_max` | 攻击距离范围 |
| `requires_facing` | 是否需要正确朝向 |
| `weapon_type` | 兵器类型 |

## 当前状态

- 9 格位置、朝向和位移规则已经并入战斗总文档。
- 正式剧情战斗的敌我配置主源是 `data/story_battles/*.tsv`。
- 当前卡牌数值仍主要来自 `scripts/card_data.gd` 和 `scripts/battle_controller_core.gd::_build_catalog()`；不要把招式数值塞进 encounter。
- 预览一致性要求已经并入 [UI_PIPELINE.md](UI_PIPELINE.md)：玩家看到的目标格位和朝向必须等于真实结算和演出使用的值。

## 后续维护规则

- 不再扩写本文档。
- 新位移规则先改 [BATTLE.md](BATTLE.md)，再改代码和 TSV。
- 新预览表现先改 [UI_PIPELINE.md](UI_PIPELINE.md)，避免 UI 层重新发明结算规则。
