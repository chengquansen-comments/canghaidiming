# Spearman 最低动作包归档

Spearman 最低动作包口径已并入 [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md) 的“Spearman 最低动作包”小节。

保留结论：

- 当前只替换 `spearman`，不同时动 `enemy_spearman` / `blademaster`。
- 目标动作：`idle`、`move_forward`、`attack_light`、`guard`、`hit`、`break`。
- 正式动作 PNG 未全部到位时，`spearman.meta.json` 可以继续引用旧 sheet fallback。
- 动作包到位后必须跑 actor meta / sheet / bundle 校验。
- Web 验收重点是脚底稳定、命中帧清楚、动作切换无白屏或透明闪烁。

后续动作规格、提示词和验收命令直接维护在 [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md)。
