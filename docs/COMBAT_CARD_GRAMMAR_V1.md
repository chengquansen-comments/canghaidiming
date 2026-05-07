# Combat Card Grammar v1

本文是《大明之沧海嘀鸣》招式牌、玩家卡组、敌人卡组、武器卡组和后续自动平衡验证的统一规范源。它描述后续重构和配表的目标口径，不代表当前运行时已经支持所有字段。

当前原则：如果本文与现有代码冲突，以现有代码为准。本文用于指导后续分阶段迁移，不能反向要求一次性改 `CardData`、结算器、状态机或剧情 TSV。

## 一、卡牌语法目标

Combat Card Grammar v1 的目标：

- 让所有招式牌可以按统一字段批量生产，而不是依赖散落在代码里的临时写法。
- 让玩家基础卡组、敌人卡组、武器卡组共享同一套命名、标签、预算和构筑口径。
- 让数值预算、战术标签、武器身份、敌人 archetype、卡组比例能被 lint / validator / sampler 自动检查。
- 让 Codex / AI 助手后续新增卡牌时有稳定约束，避免一次改动同时牵动运行时、卡表、剧情战斗和采样器。
- 让运行时字段与策划字段分层：当前可结算字段继续服务战斗，未来设想先作为规划或说明，不直接塞进 `CardData`。

## 二、规则源优先级

发生规则冲突时，当前以运行代码为准。建议按以下顺序判断：

| 优先级 | 来源 | 负责范围 |
|---:|---|---|
| 1 | `scripts/combat_resolver.gd` | 命中、距离、朝向、伤害、削势、增势、格挡、结算后位移的纯计算 |
| 2 | `scripts/battle_state_machine.gd` | 回合阶段、结算顺序、崩势打断、真实状态写回、收式连击调用 |
| 3 | `scripts/card_data.gd` | 当前 `CardData` 字段、字段归一化、预算公式、role / move condition 常量 |
| 4 | `scripts/battle_controller_core.gd::_build_catalog()` 及 catalog 拆分文件 | 当前硬编码卡牌 catalog、默认战斗角色和奖励牌 |
| 5 | `data/story_battles/*.tsv` + `scripts/story_battle_loader.gd` | 正式剧情战斗的角色模板、数值、卡组引用和 encounter 组合 |
| 6 | hot tuning / auto battle sampler | 热调试、卡牌数值临时调整、自动采样统计和调参候选 |
| 7 | `docs/COMBAT_CARD_GRAMMAR_V1.md` | 后续重构、配表、validator 和 AI 协作的目标规范 |

补充说明：

- 若本文与代码不一致，以当前代码为准。
- 本文是后续重构和配表的目标规范，不是本次运行时改造需求。
- 新字段必须先进入文档，再进入 validator，再由单独任务逐字段接入运行时。

## 三、CardSpec v1 标准字段

字段分层标记：

- Runtime：当前 `CardData` / resolver / sampler 已直接使用，改错会影响战斗。
- Planning：可先进入未来 JSON / TSV / validator，但不应马上接入运行时。
- Design：只用于策划说明、审查或偏离理由，不参与自动结算。

| 字段 | 类型 | 层级 | 当前运行时支持 | 推荐取值 | 说明 | 示例 |
|---|---|---|---|---|---|---|
| `card_id` | string | Runtime mapping | 近似支持为 `id` | 小写 snake_case | CardSpec 主键；迁移到 `CardData` 时映射为 `id` | `spear_line_thrust` |
| `display_name` | string | Runtime | 是 | 中文短名 | UI 展示名 | `中平长刺` |
| `description` | string | Runtime | 是 | 一句话 | 玩家可读效果说明，不写隐藏倍率 | `中距离枪刺，命中后削势。` |
| `card_class` | enum string | Planning | 否 | `move` / `skill` / `stance` / `special` / `enemy_only` | 卡牌大类，用于构筑和奖励池，不等于当前 `role` | `move` |
| `weapon_style` | enum string | Runtime | 是 | `generic` / `spearman` / `blademaster` / `future_weapon_placeholder` | 武器身份；当前旧代码可能仍见中文 `"枪"` / `"刀"`，迁移时应归一 | `spearman` |
| `weapon_requirement` | string or array | Planning | 否 | `none` / `spearman` / `blademaster` / weapon id array | 使用限制；通用牌写 `none` | `spearman` |
| `is_generic` | bool | Planning | 否 | `true` / `false` | 是否所有武器可引用；必须与 `weapon_style=generic` 一致 | `false` |
| `rarity` | enum string | Planning | 否 | `common` / `rare` / `special` / `boss` | 生产、奖励和预算检查分档 | `common` |
| `role` | enum string | Runtime | 是 | `attack` / `guard` / `feint` | 当前攻守变标签，只用于 UI、AI 倾向和统计，不是硬克制 | `attack` |
| `tactic_role` | enum string | Design | 否 | 见“战术角色 taxonomy” | 玩家感知和 AI 构筑角色 | `control` |
| `tags` | array[string] | Runtime | 是 | snake_case；迁移前兼容中文旧标签 | 运行时已有标签会影响部分逻辑，如 `先机`、`回身`；新标签先走规划层 | `[weapon_spear, role_control]` |
| `min_distance` | int | Runtime | 是 | `0..8` | 命中最小距离；攻击 / 削势牌会检查距离 | `2` |
| `max_distance` | int | Runtime | 是 | `0..8` 且不小于 `min_distance` | 命中最大距离 | `3` |
| `preferred_distance` | int or array[int] | Planning | 否 | `1`、`[2,3]` | AI / 构筑推荐距离，不直接改变命中 | `[2,3]` |
| `requires_facing` | bool | Runtime | 是 | `true` 为默认 | 是否必须面向目标；纯防守可为 `false` | `true` |
| `momentum_cost` | int | Runtime | 是 | `0..4` 常用 | 耗势；预算目标为 `momentum_cost * 4` | `1` |
| `gain_momentum` | int | Runtime | 是 | `0..4` 常用 | 命中有效时增己势；守牌当前也会获得 guard | `1` |
| `break_momentum` | int | Runtime | 是 | `0..4` 常用 | 命中有效时削敌势，可能触发崩势 | `2` |
| `damage` | int | Runtime | 是 | `0..10` 常用 | 命中有效时造成伤害，受 guard 抵消，目标崩势时当前会翻倍 | `4` |
| `guard` | int | Runtime | 是 | `0..10` 常用 | 结算时获得护值；当前未命中也可获得 | `4` |
| `self_move_after` | int | Runtime | 是 | `-1` / `0` / `1` | 结算后自身位移；当前构造会 clamp 到 `-1..1` | `1` |
| `target_push_after` | int | Runtime | 是 | `0` / `1` | 结算后击退目标；当前构造会 clamp 到 `0..1` | `1` |
| `target_pull_after` | int | Runtime | 是 | `0` / `1` | 结算后拉近目标；当前构造会 clamp 到 `0..1` | `1` |
| `move_condition` | enum string | Runtime | 是 | `none` / `always` / `on_hit` / `on_break` / `on_graze` | 位移触发条件；`on_graze` 受擦中开关影响，当前擦中默认关闭 | `on_hit` |
| `combo_from` | array[string] | Planning | 否 | card id array 或 tag | 可接在哪些牌之后；先做 validator / AI 参考 | `[spear_probe_step]` |
| `combo_to` | array[string] | Planning | 否 | card id array 或 tag | 推荐后续牌 | `[spear_dragon_finish]` |
| `combo_tags` | array[string] | Planning | 否 | `combo_opener` / `combo_bridge` / `combo_finisher` | 连招接口标签，不等于当前收式阶 | `[combo_opener]` |
| `combo_step` | int | Planning | 否 | `0..5` | 连招序号；`0` 表示不指定 | `1` |
| `finisher` | bool | Planning | 否 | `true` / `false` | 是否终结牌；允许预算偏离但要写理由 | `false` |
| `combo_bonus_note` | string | Design | 否 | 简短说明 | 解释未来连招收益，不进运行时 | `终结时强化削势。` |
| `ai_weight` | float | Planning | 否 | `0.1..3.0`，默认 `1.0` | AI 抽选 / 选牌权重，不应替代卡组比例 | `1.2` |
| `ai_usage_hint` | string | Design | 否 | 简短说明 | 描述 AI 什么时候用 | `距离 2-3 时优先。` |
| `archetype_tags` | array[string] | Planning | 否 | `pressure_spearman` 等 | 适合哪些敌人 archetype | `[pressure_spearman]` |
| `deck_role` | enum string | Planning | 否 | `core` / `support` / `tech` / `signature` / `boss` | 卡组构筑位置 | `core` |
| `min_copies` | int | Planning | 否 | `0..4` | 推荐最少携带数 | `1` |
| `max_copies` | int | Planning | 否 | `1..4` | 推荐最多携带数；普通 4，签名 1-2 | `3` |
| `power_budget` | int | Planning | 可由运行时公式推导 | 非负整数 | 建议显式写预算，默认公式见 Power Budget v1 | `4` |
| `budget_note` | string | Design | 否 | 简短说明 | 武器签名、强位移、特殊牌的预算说明 | `枪系签名控线牌。` |
| `allowed_deviation` | int | Planning | 否 | `0..6` | 允许偏离 `target_budget` 的绝对值 | `2` |
| `deviation_reason` | string | Design | 否 | 必填条件见预算章节 | 解释为什么超出偏离范围 | `终结牌，卡组限 1。` |
| `implementation_status` | enum string | Planning | 否 | `implemented` / `data_only` / `design_only` / `deprecated` | 标记当前落地状态 | `data_only` |

当前 `CardData` 还包含 `shoushi_rank`。它属于已实现的收式阶运行字段，但本 v1 不把它列为新增 CardSpec 必填项；后续如要重做连招 / 收式关系，应单独补 `shoushi_rank` 与 `combo_*` 的迁移规则。

## 四、字段分层

### Runtime fields

这些字段当前已被 `CardData`、`CombatResolver`、`BattleStateMachine` 或 hot tuning / sampler 直接使用，改错会影响战斗：

```text
id / card_id mapping
display_name
description
min_distance
max_distance
momentum_cost
role
gain_momentum
break_momentum
damage
guard
tags
weapon_style
requires_facing
self_move_after
target_push_after
target_pull_after
move_condition
shoushi_rank
```

### Data planning fields

这些字段可以先写入文档、未来 JSON / TSV 或 validator，但不应在本阶段接入运行时：

```text
card_class
weapon_requirement
is_generic
rarity
preferred_distance
combo_from
combo_to
combo_tags
combo_step
finisher
ai_weight
archetype_tags
deck_role
min_copies
max_copies
power_budget
allowed_deviation
implementation_status
```

### Design-only fields

这些字段只服务策划说明、审查和 AI 协作，不应被运行时读取：

```text
tactic_role
combo_bonus_note
ai_usage_hint
budget_note
deviation_reason
```

本次文档不能要求一次性把所有字段写入 `CardData`。后续如果要扩展 `CardData`，必须单独开任务，逐字段迁移，并同步 validator、采样器、预览和真实结算。

## 五、战斗行为原子语法

### Attack

| 行为原子 | 当前实现 | 对应字段 | 使用边界 |
|---|---|---|---|
| `damage` | 已实现 | `damage` | 代表打血；不要用隐藏倍率表达武器强弱，武器加成应在武器系统单独处理 |
| `break_momentum` | 已实现 | `break_momentum` | 代表削势；不要把所有控场都堆成高削势 |
| `guard_break` | design-only | 未来字段或 tag | 破护不是当前 `break_momentum`，不要混用 |
| `execute` | design-only | 未来字段或 tag | 斩杀 / 处决必须单独设计，不用超高 `damage` 临时代替 |

### Defense

| 行为原子 | 当前实现 | 对应字段 | 使用边界 |
|---|---|---|---|
| `guard` | 已实现 | `guard` | 当前守牌主要加护值；不要用 guard 模拟闪避或免疫 |
| `parry` | design-only | 未来字段或 tag | 防反应独立设计，不等于 `guard + damage` 免费叠加 |
| `evade` | design-only | 未来字段或 tag | 闪避不是 `requires_facing=false`，不要滥用朝向字段 |
| `hyper_armor` | design-only | 未来字段或 tag | 霸体需定义对崩势 / 打断的影响后再实现 |

### Tempo

| 行为原子 | 当前实现 | 对应字段 | 使用边界 |
|---|---|---|---|
| `gain_momentum` | 已实现 | `gain_momentum` | 调息 / 抢势；不要让低耗牌无限正循环 |
| `initiative` | 部分旧标签影响 sampler / 顺序 | 当前有 `先机` tag | 新规范先写 `combo_tags` / design note，不扩大中文标签依赖 |
| `interrupt` | design-only，崩势打断已实现 | 未来字段或 tag | 不要把所有打断都伪装成高 `break_momentum` |
| `counter_window` | design-only | 未来字段或 tag | 反击窗口需要状态机支持后再进运行时 |

### Movement

| 行为原子 | 当前实现 | 对应字段 | 使用边界 |
|---|---|---|---|
| 自身位移 | 已实现 | `self_move_after` + `move_condition` | 当前幅度只建议 `-1..1` |
| 击退 | 已实现 | `target_push_after` + `move_condition` | 枪可常用；刀少用，避免抢武器特色 |
| 拉近 | 已实现 | `target_pull_after` + `move_condition` | 刀可常用；枪少用 |
| 条件位移 | 已实现 | `move_condition` | `on_graze` 当前因擦中关闭而基本不可用 |

同一张牌不建议同时拥有强伤害、强削势、强格挡和强位移。当前 `CombatResolver.apply_card_movement()` 对击退、拉近、自移使用优先级分支；若同时填多个位移字段，实际只会按当前代码分支执行其中一种，未来 validator 应禁止多强位移混填。

### Combo

| 行为原子 | 当前实现 | 对应字段 | 使用边界 |
|---|---|---|---|
| `opener` | 规划层 | `combo_tags` / `tactic_role` | 起手牌应稳定、低成本、不过度爆发 |
| `bridge` | 规划层 | `combo_tags` / `combo_step` | 衔接牌负责调整距离或势，不应比终结更爆 |
| `extender` | 规划层 | `combo_tags` | 延长连段需控制复制数 |
| `finisher` | 规划层 | `finisher=true` | 可预算偏离，但必须写 `deviation_reason` |
| `reset` | design-only | `combo_bonus_note` | 重置连段需等待运行时支持 |
| `punish` | design-only / tactic | `tactic_role=punish` | 惩罚牌不应成为无条件最高效率牌 |

## 六、战术角色 taxonomy

| `tactic_role` | 玩家感知 | 典型字段组合 | 枪适配 | 刀适配 | 通用适配 | AI 使用倾向 |
|---|---|---|---|---|---|---|
| `opener` 起手 | 开局稳妥建立节奏 | 低耗，宽容距离，少量伤害或增势 | 高 | 高 | 中 | 回合前期、资源不足时优先 |
| `pressure` 压制 | 贴住或压线让对方难受 | 伤害 + 削势，可能带进身 / 击退 | 中 | 高 | 低 | 攻击型 AI 高频使用 |
| `poke` 试探 | 小赚、不冒险 | 低耗，低伤害 / 低削势，距离较宽 | 高 | 中 | 高 | 不确定距离时使用 |
| `control` 控距 | 改变或维持理想距离 | 击退、后撤、距离 2-3 | 高 | 低 | 中 | 枪兵和 controller 偏好 |
| `approach` 进身 | 主动贴近 | `self_move_after=1` 或拉近 | 低 | 高 | 中 | 距离过远时使用 |
| `retreat` 后撤 | 脱离贴身压力 | `self_move_after=-1`，可带 guard | 高 | 中 | 中 | HP 低或敌方近身时使用 |
| `guard` 防守 | 稳住不掉血 | `guard>0`，`requires_facing=false` 可选 | 中 | 中 | 高 | 低势、低血、防守型敌人常用 |
| `counter` 反制 | 守中带反击 | guard + 少量伤害 / 削势，parry 未来化 | 中 | 高 | 低 | 敌方逼近或玩家高攻时使用 |
| `break` 崩势 | 打掉敌方势 | `break_momentum` 高，伤害适中 | 高 | 中 | 低 | 目标势低时优先 |
| `burst` 爆发 | 明显打血 | 高 `damage`，高耗，距离限制 | 中 | 高 | 低 | 可击杀或目标崩势时使用 |
| `finisher` 终结 | 连段收尾 / 破局 | 高伤害或高削势，限复制 | 中 | 高 | 低 | combo 末段或优势时使用 |
| `combo_bridge` 连段衔接 | 接上下一式 | 中低效果 + 调距 / 增势 | 中 | 高 | 低 | 有 combo 条件时使用 |
| `feint` 虚招 | 骗招、扰节奏 | design-only，暂不进结算 | 中 | 高 | 中 | 高级敌人少量使用 |
| `punish` 破绽惩罚 | 抓对方失位 / 崩势 | 条件强，平时一般 | 中 | 高 | 低 | 目标背向、崩势、距离错时使用 |
| `recovery` 回势 / 调息 | 修复资源 | `gain_momentum` 或 guard，低伤害 | 中 | 中 | 高 | 势低时优先 |

## 七、武器身份

### `weapon_style` 枚举

| 值 | 含义 |
|---|---|
| `generic` | 通用招式，所有武器可引用 |
| `spearman` | 枪系限定或枪系推荐 |
| `blademaster` | 刀系限定或刀系推荐 |
| `future_weapon_placeholder` | 未来武器占位，不进入当前卡组 |

旧 catalog 中可能存在 `"枪"`、`"刀"` 等中文 `weapon_style`。迁移时应归一到 `spearman` / `blademaster`，但不要在本次文档任务中批量改代码。

### 枪：spearman

核心身份：

- 中距离控线。
- 击退、拒止、削势。
- 保持 2-3 格优势。
- 让敌人难以舒服进身，而不是贴脸爆发。

常见字段：

```yaml
min_distance: 2
max_distance: 3
target_push_after: 1
break_momentum: 2
self_move_after: -1 # 或 0
```

枪牌应避免：大量 `target_pull_after`、过多贴身爆发、把所有牌都做成宽距离高收益。

### 刀：blademaster

核心身份：

- 近身压迫。
- 追身、拉近、连段。
- 防反、爆发。
- 在 1-2 格制造压迫和终结机会。

常见字段：

```yaml
min_distance: 1
max_distance: 2
self_move_after: 1
target_pull_after: 1
damage: 4
combo_tags: [combo_bridge, combo_finisher]
```

刀牌应避免：大量远距离击退、长期 2-3 格控线、高削势且无距离代价。

### 通用：generic

核心身份：

- 基础攻防。
- 调息 / 回势。
- 轻微位移。
- 不抢枪和刀的武器特色。

通用牌应避免：成为所有武器都必带的最强控距、最强爆发或最强崩势牌。

## 八、Power Budget v1

先沿用当前 `CardData.effect_budget()` 与 `docs/balance_rules.md` 的历史口径：

```text
effect_budget = gain_momentum * 2 + break_momentum * 2 + damage + guard
target_budget = momentum_cost * 4
```

设计层修正项先不接入代码：

- 距离窄：可略微增加预算。
- 距离宽：应略微扣预算。
- 强位移：应计入未来预算。
- `combo` / `finisher`：允许偏离，但必须写 `deviation_reason`。
- `weapon signature`：允许偏离，但必须写 `budget_note`。

建议预算范围：

| rarity | 常见 `momentum_cost` | 建议 `effect_budget` | 说明 |
|---|---:|---:|---|
| `common` | 0-2 | 0-8 | 基础卡、教学卡、通用卡 |
| `rare` | 1-3 | 4-12 | 武器特色、构筑核心 |
| `special` | 2-4 | 8-16 | 签名牌、剧情奖励、敌人特殊牌 |
| `boss` | 2-5 | 10-20 | Boss 专用，必须限卡组和说明 |

偏离规则：

- 普通牌建议 `abs(effect_budget - target_budget) <= 2`。
- 武器签名牌建议 `abs(effect_budget - target_budget) <= 4`，并填写 `budget_note`。
- boss / special 可放宽到 `<= 6`，但必须填写 `deviation_reason`，并限制 `max_copies`。
- 只要超出 `allowed_deviation`、同时拥有强伤害和强位移、或作为 `finisher=true`，必须标记 `deviation_reason`。
- 不建议引入隐藏倍率。武器百分比攻击加成应属于武器佩戴系统，不写进单张招式牌预算。

## 九、Deck Grammar

### 玩家基础卡组

建议入战卡组大小先沿用当前主角入战 8 张口径，后续扩容必须单独验证：

| 项目 | 建议 |
|---|---|
| 卡组大小 | 8 张起步；扩到 10-12 前先跑 sampler |
| 通用牌比例 | 25%-40% |
| 武器限定牌比例 | 60%-75% |
| 起手 / 试探 | 20%-30% |
| 防御 | 15%-25% |
| 控距 / 进退 | 15%-25% |
| 爆发 / 终结 | 10%-20% |
| 调息 / 回势 | 10%-20% |

### 武器卡组

- 每个武器拥有独立推荐卡池，例如 `player_spear_basic`、`player_blade_basic`。
- 武器限定牌不能被错误加入不匹配武器卡组。
- 通用牌可以被所有武器引用，但不能覆盖武器特色。
- validator 应检查 `weapon_requirement` 与 deck id / fighter `weapon_style` 是否一致。

### 敌人卡组

- 敌人卡组由 `enemy_archetype` 决定比例，不靠手工随意塞牌。
- 每个敌人卡组要有 `deck_role` 分布：`core`、`support`、`tech`、`signature`。
- 敌人可使用 `enemy_only` 或 `boss` 牌，但必须标注 `implementation_status` 和限制复制数。
- story TSV 仍只引用 card id；不要把卡牌数值写入 encounter。

## 十、Enemy Archetype v1

| archetype | preferred_distance | aggression | guard_frequency | combo_frequency | break_focus | movement_bias | tactic_role ratios | 禁用 / 不鼓励 |
|---|---|---:|---:|---:|---:|---|---|---|
| `pressure_spearman` | `[2,3]` | 0.65 | 0.20 | 0.25 | 0.65 | 击退、后撤、控线 | control 30%, break 25%, poke 20%, guard 15%, finisher 10% | 大量贴身刀牌、拉近牌 |
| `defensive_spearman` | `[2,3]` | 0.35 | 0.45 | 0.15 | 0.45 | 后撤、拒止 | guard 30%, control 30%, poke 20%, break 15%, recovery 5% | 高爆发连段、贴身追击 |
| `fast_blademaster` | `[1,2]` | 0.75 | 0.15 | 0.45 | 0.35 | 进身、拉近 | approach 25%, pressure 25%, combo_bridge 20%, burst 15%, guard 15% | 长距离枪控线、持续后撤 |
| `defensive_blademaster` | `[1,2]` | 0.45 | 0.40 | 0.25 | 0.35 | 防守后进身 | guard 25%, counter 25%, pressure 20%, punish 15%, recovery 15% | 纯远程 poke、无条件高爆发 |
| `berserk_raider` | `[1]` | 0.90 | 0.05 | 0.30 | 0.20 | 强进身 | pressure 35%, burst 30%, approach 20%, finisher 15% | 高 guard、高 recovery、复杂控距 |
| `elite_guard` | `[1,2]` 或 `[2,3]` | 0.50 | 0.45 | 0.30 | 0.55 | 稳位、少量反制 | guard 25%, counter 20%, break 20%, control 20%, punish 15% | 低成本无脑爆发 |
| `boss_controller` | `[2,3]` | 0.60 | 0.30 | 0.45 | 0.65 | 控距、击退、条件终结 | control 25%, break 25%, combo_bridge 15%, finisher 15%, guard 10%, punish 10% | 普通杂兵牌堆叠、无说明超预算牌 |

数值含义：`aggression`、`guard_frequency`、`combo_frequency`、`break_focus` 是 AI 和构筑建议值，范围 `0.0..1.0`，本阶段不接运行时。

## 十一、命名规范

### card_id

使用小写 snake_case，建议格式：

```text
generic_guard
generic_recover
spear_line_thrust
spear_push_cut
blade_close_slash
blade_counter_cut
```

武器前缀：

- `generic_`：通用牌。
- `spear_`：枪牌。
- `blade_`：刀牌。
- `enemy_`：敌人专用牌。
- `boss_`：Boss / special 牌。

### deck_id

使用小写 snake_case，建议格式：

```text
player_spear_basic
player_blade_basic
enemy_pressure_spearman_basic
enemy_fast_blademaster_basic
```

### tag

全部小写 snake_case。推荐前缀：

```text
weapon_xxx
role_xxx
combo_xxx
ai_xxx
story_xxx
```

旧中文标签如 `先机`、`回身` 当前仍可能被运行时读取；迁移时要通过 validator 给出兼容映射，不要直接删除。

## 十二、示例卡

以下示例只写规范，不写入代码。

```yaml
- card_id: generic_guard
  display_name: 稳架
  weapon_style: generic
  weapon_requirement: none
  is_generic: true
  rarity: common
  role: guard
  tactic_role: guard
  min_distance: 0
  max_distance: 3
  preferred_distance: [1, 2]
  requires_facing: false
  momentum_cost: 1
  gain_momentum: 0
  break_momentum: 0
  damage: 0
  guard: 4
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 0
  move_condition: none
  tags: [weapon_generic, role_guard]
  power_budget: 4
  budget_note: 基础通用防守牌。
  implementation_status: data_only

- card_id: generic_recover
  display_name: 调息
  weapon_style: generic
  weapon_requirement: none
  is_generic: true
  rarity: common
  role: feint
  tactic_role: recovery
  min_distance: 0
  max_distance: 4
  preferred_distance: [1, 2, 3]
  requires_facing: false
  momentum_cost: 0
  gain_momentum: 1
  break_momentum: 0
  damage: 0
  guard: 0
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 0
  move_condition: none
  tags: [weapon_generic, role_recovery]
  power_budget: 2
  budget_note: 零耗回势牌，需由卡组复制数控制。
  allowed_deviation: 2
  deviation_reason: 零耗牌预算高于 target，需要限制 max_copies。
  implementation_status: data_only

- card_id: spear_line_thrust
  display_name: 中平线刺
  weapon_style: spearman
  weapon_requirement: spearman
  is_generic: false
  rarity: common
  role: attack
  tactic_role: poke
  min_distance: 2
  max_distance: 3
  preferred_distance: [2, 3]
  requires_facing: true
  momentum_cost: 1
  gain_momentum: 0
  break_momentum: 1
  damage: 2
  guard: 0
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 0
  move_condition: none
  tags: [weapon_spear, role_poke, combo_opener]
  power_budget: 4
  budget_note: 枪系基础试探。
  implementation_status: data_only

- card_id: spear_push_cut
  display_name: 压杆退敌
  weapon_style: spearman
  weapon_requirement: spearman
  is_generic: false
  rarity: rare
  role: attack
  tactic_role: control
  min_distance: 2
  max_distance: 3
  preferred_distance: [2, 3]
  requires_facing: true
  momentum_cost: 1
  gain_momentum: 0
  break_momentum: 2
  damage: 0
  guard: 0
  self_move_after: 0
  target_push_after: 1
  target_pull_after: 0
  move_condition: on_hit
  tags: [weapon_spear, role_control, ai_keep_distance]
  power_budget: 4
  budget_note: 枪系击退签名，位移尚未计入预算。
  implementation_status: data_only

- card_id: spear_retreat_sting
  display_name: 退步回刺
  weapon_style: spearman
  weapon_requirement: spearman
  is_generic: false
  rarity: rare
  role: attack
  tactic_role: retreat
  min_distance: 1
  max_distance: 3
  preferred_distance: [2, 3]
  requires_facing: true
  momentum_cost: 2
  gain_momentum: 0
  break_momentum: 2
  damage: 3
  guard: 0
  self_move_after: -1
  target_push_after: 0
  target_pull_after: 0
  move_condition: on_hit
  tags: [weapon_spear, role_retreat, combo_bridge]
  power_budget: 7
  budget_note: 窄用途脱身牌，允许略低于 target。
  implementation_status: data_only

- card_id: blade_close_slash
  display_name: 贴身快斩
  weapon_style: blademaster
  weapon_requirement: blademaster
  is_generic: false
  rarity: common
  role: attack
  tactic_role: pressure
  min_distance: 1
  max_distance: 2
  preferred_distance: [1, 2]
  requires_facing: true
  momentum_cost: 1
  gain_momentum: 0
  break_momentum: 0
  damage: 4
  guard: 0
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 0
  move_condition: none
  tags: [weapon_blade, role_pressure, combo_opener]
  power_budget: 4
  budget_note: 刀系基础近身输出。
  implementation_status: data_only

- card_id: blade_chase_step
  display_name: 追身斜斩
  weapon_style: blademaster
  weapon_requirement: blademaster
  is_generic: false
  rarity: rare
  role: attack
  tactic_role: approach
  min_distance: 1
  max_distance: 2
  preferred_distance: [1, 2]
  requires_facing: true
  momentum_cost: 1
  gain_momentum: 0
  break_momentum: 0
  damage: 3
  guard: 0
  self_move_after: 1
  target_push_after: 0
  target_pull_after: 0
  move_condition: on_hit
  tags: [weapon_blade, role_approach, combo_bridge]
  power_budget: 3
  budget_note: 进身位移尚未计入预算，伤害略收。
  implementation_status: data_only

- card_id: blade_counter_cut
  display_name: 藏锋反切
  weapon_style: blademaster
  weapon_requirement: blademaster
  is_generic: false
  rarity: rare
  role: guard
  tactic_role: counter
  min_distance: 0
  max_distance: 2
  preferred_distance: [1, 2]
  requires_facing: false
  momentum_cost: 2
  gain_momentum: 0
  break_momentum: 1
  damage: 2
  guard: 4
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 0
  move_condition: none
  tags: [weapon_blade, role_counter]
  power_budget: 8
  budget_note: 防反概念先用已实现字段表达，不追加 parry 运行时。
  implementation_status: data_only

- card_id: enemy_dirty_hook
  display_name: 脏手钩拽
  weapon_style: blademaster
  weapon_requirement: blademaster
  is_generic: false
  rarity: special
  role: attack
  tactic_role: punish
  min_distance: 1
  max_distance: 2
  preferred_distance: [1]
  requires_facing: true
  momentum_cost: 1
  gain_momentum: 0
  break_momentum: 1
  damage: 2
  guard: 0
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 1
  move_condition: on_hit
  tags: [enemy_only, weapon_blade, role_punish, ai_pressure]
  power_budget: 4
  budget_note: 敌人专用拉近牌，服务 fast_blademaster / berserk_raider。
  implementation_status: design_only

- card_id: boss_tide_lock
  display_name: 潮锁三叠
  weapon_style: blademaster
  weapon_requirement: blademaster
  is_generic: false
  rarity: boss
  role: attack
  tactic_role: finisher
  min_distance: 1
  max_distance: 2
  preferred_distance: [1]
  requires_facing: true
  momentum_cost: 3
  gain_momentum: 0
  break_momentum: 3
  damage: 8
  guard: 0
  self_move_after: 0
  target_push_after: 0
  target_pull_after: 0
  move_condition: none
  combo_tags: [combo_finisher]
  finisher: true
  tags: [boss_only, weapon_blade, role_finisher, combo_finisher]
  power_budget: 14
  budget_note: Boss 终结牌，卡组限 1。
  allowed_deviation: 6
  deviation_reason: boss special finisher，需 sampler 验证回合数与卡手率。
  implementation_status: design_only
```

## 十三、迁移计划

### Phase 0

只建立本文档，不改运行时。

### Phase 1

补卡牌 lint / validator，只检查当前 `CardData` 字段与预算：

- id / display name / distance 合法性。
- `min_distance <= max_distance`。
- `momentum_cost`、效果值非负。
- `effect_budget` 与 `target_budget` 偏离。
- 位移字段是否多强混填。

### Phase 2

把现有 `_build_catalog()` 中卡牌按 grammar 重新分类，不大改数值：

- 归一 `weapon_style`。
- 补 tag 命名映射。
- 标注 `implementation_status=implemented`。

### Phase 3

重做玩家基础卡组：

- `player_spear_basic`。
- `player_blade_basic`。
- `generic` / `spear` / `blade` 比例达标。

### Phase 4

重做敌人 archetype 与 `story_deck_sets`：

- 为敌人模板绑定 archetype。
- 用 deck grammar 生成或审查敌人卡组。
- 禁止不匹配武器牌混入。

### Phase 5

接入自动战斗采样，输出：

- 胜率。
- 平均回合。
- 卡手率。
- 距离命中率。
- 崩势率。
- 连招率。

### Phase 6

再考虑把 `combo`、`initiative`、`feint` 等 design-only / planning 字段逐步进入运行时。每个字段单独迁移，并同步真实结算、预览、日志、sampler 和 validator。

## 十四、AI 修改边界

- 不要一次性重写所有卡牌。
- 不要同时改 `CardData`、resolver、state machine、story TSV。
- 每次只做一个迁移阶段。
- 新增字段先写文档，再写 validator，再接运行时。
- 单个 `.gd` 文件不要继续膨胀，遵守 `CODE_ORGANIZATION.md`。
- Godot 报错时遵守 `chatgpt_debugging_rules.md`，先 headless 验证，定位真实根因。
- 每次改动后必须运行：

```bash
git diff --check
HOME=/private/tmp godot --headless --path . --quit scenes/MainVisual.tscn
HOME=/private/tmp godot --headless --quit --path .
```

本文件的存在不授权 AI 批量改 `_build_catalog()`、`data/story_battles/*.tsv`、`combat_resolver.gd` 或 `battle_state_machine.gd`。这些迁移必须按阶段单独执行。
