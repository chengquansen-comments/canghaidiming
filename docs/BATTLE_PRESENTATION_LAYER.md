# 战斗演出层归档

当前战斗演出口径已并入 [BATTLE.md](BATTLE.md) 的“表演节奏”和 [UI_PIPELINE.md](UI_PIPELINE.md) 的“演出管线”。本文原本记录历史 phase、wrapper 链路和调参细节，不再作为当前实现依据。

## 当前以这些为准

| 问题 | 查看 |
|---|---|
| 行动顺序、位移、朝向、表演节奏 | [BATTLE.md](BATTLE.md) |
| 演出管线、死亡反馈、刷新缓存 | [UI_PIPELINE.md](UI_PIPELINE.md) |
| 当前 visual controller 继承链 | [BATTLE.md](BATTLE.md) / [UI_PIPELINE.md](UI_PIPELINE.md) |

保留原则：

- 战斗结算决定结果；演出层只消费真实结果、意图、卡牌信息、最终格位和事件触发的朝向变化。
- 预览、真实结算和演出必须使用同一套 `target_position` / `target_facing`。
- 禁止为规避大文件修改继续新增长期 wrapper。

后续演出规则请直接更新活跃总文档。
