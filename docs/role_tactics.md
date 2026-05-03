# v0.5.0 Role Tactics

`CardData.role` 的合法语义已收敛为三类：

- `CardData.ROLE_GUARD` (`"guard"`)：守
- `CardData.ROLE_ATTACK` (`"attack"`)：攻
- `CardData.ROLE_FEINT` (`"feint"`)：变

中文显示统一由 `CardData.type_label()` 输出：`守 / 攻 / 变`。

`role` 仅用于：

- UI 标签
- 敌方意图类型展示
- AI 选牌倾向
- 日志与统计字段

`role` 不参与 `CombatResolver` 硬克制，不允许引入守攻变猜拳，不允许基于 `role` 直接改伤害、护值、削势、命中或位移。

旧值 `momentum / damage / defense` 仅作为 `CardData._init()` 的兼容输入保留，并在构造时一次性归一化。

外部数据（如 `data/enemy_manifest.json`、相关 `tables/*.tsv`、动态配置中的卡牌 `role` 字段）也应显式使用 `guard / attack / feint`，不应继续写入 legacy 值。

新卡牌定义必须显式使用：

- `CardData.ROLE_GUARD`
- `CardData.ROLE_ATTACK`
- `CardData.ROLE_FEINT`

## 单局设计空间（v0.5.0）

三类牌在单局中应共同覆盖完整战术空间：

- 攻：打血、削势、控位、锁位、封招、破护、险招。
- 守：格挡、受击回势、免削势、稳位、反击、抗崩势、守后强化。
- 变：换距、回势、下回合加伤、下回合穿护、轻功提升、夺机、诱敌落空收益、解除控制。
