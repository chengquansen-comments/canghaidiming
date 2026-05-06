# 攻守变 role 归档

当前 `CardData.role` 口径已并入 [BATTLE.md](BATTLE.md) 的“收式阶与攻守变”小节。

保留结论：

- 合法值只允许 `guard`、`attack`、`feint`。
- 中文显示为“守 / 攻 / 变”。
- role 只用于 UI、敌方意图、AI 倾向、日志和统计。
- role 不参与 `CombatResolver` 硬克制。
- 擦中当前默认关闭：`ENABLE_GRAZE := false`。

后续新增 role 或恢复擦中规则，直接更新 [BATTLE.md](BATTLE.md) 和真实结算链路。
