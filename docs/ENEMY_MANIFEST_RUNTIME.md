# enemy_manifest 运行时兼容归档

当前战斗入口已整合到 [BATTLE.md](BATTLE.md)。`enemy_manifest` 现在只作为旧剧情战斗 / AI / debug 兼容层，不再是正式剧情战斗敌我数值和卡组主源。

## 当前口径

- 正式剧情战斗优先改 `data/story_battles/*.tsv`。
- `data/enemy_manifest.json` 仍可驱动旧链路的敌人 deck、`intent_weights` 和 `phase_behaviors`。
- 旧 fallback 不要删除，避免兼容配置缺失时战斗白屏。

如需新增正式战斗配置，查看 [BATTLE.md](BATTLE.md) 的“配置主源”和“配置流程”。
