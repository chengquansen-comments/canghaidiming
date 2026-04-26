# 《沧海嘀鸣》单局战斗当前规则源

> 版本：current / feature/symmetry-gameplay  
> 范围：当前 Godot Web demo 已落地的单局战斗规则  
> 用途：作为后续 Codex 修改、策划调参、预览一致性校验的第一参考文档。  
> 重要原则：本文件记录“代码已经落地的真实规则”，不是早期设想稿。

---

## 0. 当前规则源优先级

当文档、旧设计和代码不一致时，按以下优先级判断：

1. `scripts/combat_resolver.gd`：命中、伤害、削势、格挡、崩势预判、招式位移的核心规则。
2. `scripts/battle_state_machine.gd`：回合阶段、行动顺序、真实结算写回、回合结束状态推进。
3. `scripts/card_data.gd` + `data/cards.json`：卡牌字段、卡牌数值、卡牌标签、位移参数。
4. `scripts/battle_controller_visual_break_preview.gd` / `scripts/battle_controller_visual_resolver_preview.gd`：视觉预览、虚影、箭头、效果预览文本。
5. 历史文档：`docs/carddata_movement_v032_change_list.md`、`docs/balance_rules.md`、`docs/symmetry_gameplay_v031_execution_list.md` 只作为参考，不再直接覆盖当前代码规则。

---

## 1. 一句话核心体验

玩家在 9 格距离轴上，通过“主观移动 + 出招 + 看破敌方意图 + 抢先后手”，制造命中、破势、崩势和位移窗口，形成敌我双方动态拆招。

---

## 2. 战斗空间

### 2.1 距离轴

当前战斗发生在一条 9 格横向轴上：

```text
0 1 2 3 4 5 6 7 8
```

双方都有：

```text
position: int
facing: "left" / "right"
```

距离计算：

```text
distance = abs(enemy.position - player.position)
```

### 2.2 当前默认站位

当前视觉入口会强制把“职业”和“阵营站位”解耦：

| 阵营 | 默认位置 | 默认朝向 |
|---|---:|---|
| 玩家 | 2 | right |
| 敌方 | 6 | left |

这意味着：

```text
选择刀客作为玩家时，刀客仍站左侧；
选择枪手作为敌人时，枪手仍站右侧。
```

---

## 3. 每回合高层流程

当前单回合可以拆为：

```text
1. 读取敌方意图
2. 玩家选择移动目标
3. 玩家选择招式牌
4. 玩家确认出招
5. 计算行动顺序
6. 按行动顺序依次结算：
   A方行动位移
   A方招式命中/伤害/削势/格挡
   A方招式附带位移
   B方行动位移
   B方招式命中/伤害/削势/格挡
   B方招式附带位移
7. 结束回合：清护值，推进崩势/连招窗口，轮换同武境先手权
```

注意：

```text
行动位移不再和招式绑定。
行动位移是本回合单独选择的主观移动。
招式附带位移是卡牌效果，在命中/擦中/崩势等条件满足后触发。
```

---

## 4. 行动位移规则

### 4.1 玩家移动

玩家可以在轻功范围内选择移动目标。

当前基础规则：

```text
可选位置 = 当前格 ± qinggong 范围内的格子 + 当前格
```

例如初始轻功为 1：

```text
当前在 2，则可选 1 / 2 / 3
```

不选择位置时：

```text
默认原地
```

再次选择当前位置时：

```text
角色转向
```

### 4.2 敌方移动

敌方意图内也有目标位置或移动意图。当前预览层将敌方行动位移解释为“相对位移”：

```text
move_delta = intent.target_position - enemy.position
```

真正轮到敌方行动时，基于当时当前位置结算：

```text
enemy_final = current_enemy_position + move_delta
```

示例：

```text
敌人原在 6，意图进 1，所以 move_delta = -1。
我方先手把敌人从 6 击退到 7。
敌人行动时再进 1：7 + (-1) = 6。
```

这是当前预览必须遵守的规则。

---

## 5. 行动顺序规则

真实行动顺序由 `BattleStateMachine.get_resolution_order()` 决定。

优先级如下：

1. 先机：一方有先机，另一方没有，则有先机者先动。
2. 崩势：一方崩势，另一方未崩势，则未崩势者先动。
3. 武境：武境高者先动。
4. 同武境：使用 `player_tie_advantage` 轮流先后手。

伪规则：

```text
先机 > 崩势状态 > 武境 > 同武境轮换
```

同武境下，每回合结束后：

```text
player_tie_advantage = !player_tie_advantage
```

---

## 6. CardData 当前字段

当前卡牌核心字段如下：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String | 卡牌唯一 id |
| `display_name` | String | 展示名 |
| `description` | String | 描述 |
| `min_distance` | int | 最小命中距离 |
| `max_distance` | int | 最大命中距离 |
| `momentum_cost` | int | 消耗势 |
| `role` | String | `momentum` / `damage` / `guard` |
| `gain_momentum` | int | 增己势 |
| `break_momentum` | int | 削敌势 |
| `damage` | int | 伤害 |
| `guard` | int | 护值 |
| `tags` | PackedStringArray | 标签，如先机、回身等 |
| `weapon_style` | String | 武器/套路风格 |
| `requires_facing` | bool | 是否要求面向目标 |
| `self_move_after` | int | 招式后自身位移，当前 clamp 到 -1 / 0 / 1 |
| `target_push_after` | int | 招式后击退目标，当前 clamp 到 0 / 1 |
| `target_pull_after` | int | 招式后拉近目标，当前 clamp 到 0 / 1 |
| `move_condition` | String | 招式位移触发条件 |

---

## 7. 卡牌类型规则

### 7.1 伤害牌

```text
role = damage
```

通常具有：

```text
damage > 0
break_momentum >= 0
gain_momentum >= 0
```

需要命中判定。

### 7.2 势牌

```text
role = momentum
```

通常用于：

```text
增己势
削敌势
节奏转换
```

只要具有 `damage / gain_momentum / break_momentum` 任一效果，就需要命中判定。

### 7.3 格挡牌

```text
role = guard
```

格挡牌当前不走攻击命中判定，视为直接生效：

```text
requires_hit_check() = false
```

---

## 8. 命中判定规则

由 `CombatResolver.evaluate_range()` 统一判断。

### 8.1 不需要命中判定的牌

如果：

```text
card == null
或 card.requires_hit_check() == false
```

则视为：

```text
RANGE_HIT
```

### 8.2 朝向判定

若卡牌要求朝向：

```text
requires_facing = true
```

且卡牌没有：

```text
tag = 回身
```

则必须面向目标，否则：

```text
RANGE_MISS_FACING
```

### 8.3 距离判定

设：

```text
distance = abs(target.position - actor.position)
```

| 条件 | 结果 |
|---|---|
| `min_distance <= distance <= max_distance` | `RANGE_HIT` |
| 距离只差 1 格 | `RANGE_GRAZE` |
| 距离差超过 1 格 | `RANGE_MISS_RANGE` |

---

## 9. 伤害、削势、增势、护值规则

由 `CombatResolver.resolve_card_effect()` 统一判断。

### 9.1 未命中或行动者崩势

如果行动者处于崩势，或命中结果不是 `hit / graze`：

```text
伤害 = 0
削势 = 0
增势 = 0
护值 = card.guard
```

也就是：

```text
未命中不会造成伤害、削势、增势。
格挡值仍按卡牌 guard 生效。
```

### 9.2 擦中

如果结果为：

```text
RANGE_GRAZE
```

则：

```text
伤害 = ceil(原伤害 * 0.5)，至少 1
削势 = max(原削势 - 1, 0)
```

### 9.3 目标崩势时受击

如果目标当前已经处于崩势，且伤害大于 0：

```text
伤害翻倍
```

### 9.4 护值

伤害结算时：

```text
最终伤害 = max(伤害 - 目标护值, 0)
```

护值在回合结束时清空。

---

## 10. 势与崩势规则

### 10.1 势变化

卡牌可以产生：

```text
actor gain_momentum
目标 break_momentum
```

在 resolver 中以 delta 形式记录：

```text
player_momentum_delta
enemy_momentum_delta
```

削势是负值，增势是正值。

### 10.2 崩势判定

如果目标在本次削势前：

```text
momentum > 0
```

且本次削势后：

```text
momentum + momentum_delta <= 0
```

则：

```text
will_break = true
```

真实战斗中，目标势被打到 0 时：

```text
目标 queue_broken_state()
攻击者 queue_combo_window()
```

回合结束后 pending 状态激活。

### 10.3 崩势效果

当前文本规则：

```text
崩势者本回合无法行动；
崩势者受击伤害翻倍；
对手获得连招窗口。
```

---

## 11. 招式附带位移规则

由 `CombatResolver.apply_card_movement()` 统一判断。

### 11.1 触发条件

`move_condition` 当前支持：

| 值 | 触发条件 |
|---|---|
| `none` | 不触发招式位移 |
| `always` | 总是触发 |
| `on_hit` | 仅 `RANGE_HIT` 触发 |
| `on_graze` | 仅 `RANGE_GRAZE` 触发 |
| `on_break` | 目标本次会崩势时触发 |

### 11.2 位移优先级

同一张牌如果同时配置多种招式位移，当前 resolver 优先级为：

```text
target_push_after > target_pull_after > self_move_after
```

即：

```text
先看击退；
否则看拉近；
否则看自身位移。
```

### 11.3 自身位移

当前 `self_move_after` 被 clamp 到：

```text
-1 / 0 / 1
```

实际结算中：

```text
amount > 0：朝目标方向移动 1 格
amount < 0：背离目标方向移动 1 格
```

注意：即使字段值未来写成 2 或 3，当前 `CardData` 初始化也会 clamp 到 1，因此真实效果仍最多 1 格。

### 11.4 击退目标

```text
target_push_after > 0
```

目标沿“从行动者指向目标”的方向远离行动者。

### 11.5 拉近目标

```text
target_pull_after > 0
```

目标沿“从目标指向行动者”的方向靠近行动者。

拉近不会穿过行动者。

---

## 12. 结算顺序的关键约束

当前真实规则必须满足：

```text
先动方行动位移
→ 先动方招式命中判定
→ 先动方伤害/削势/增势/护值
→ 先动方招式附带位移立即写回
→ 后动方基于写回后的真实位置行动
```

因此：

```text
先手击退/拉近/自移会影响后手命中距离。
先手未命中时，不触发 on_hit 招式位移。
```

---

## 13. 预览规则

### 13.1 虚影

当前视觉规则：

```text
虚影 = 主观行动位置
```

也就是：

```text
玩家选择移动到哪里，虚影显示在哪里；
敌人意图移动到哪里，虚影显示在哪里。
```

透明度：

```text
默认 80%；
虚影与自身真实位置重叠时 0%。
```

### 13.2 箭头

当前视觉规则：

```text
箭头 = 主观行动位置 → 整回合最终位置
```

箭头起点和终点均为九宫格格子正中央。

如果主观位置等于整回合最终位置：

```text
不显示箭头
```

### 13.3 效果预览文本

效果预览按行动顺序展示：

```text
行动顺序
我方招式
敌方招式
顺序结算预览
最终汇总
```

顺序结算预览应拆为：

```text
A方移动
A方招式效果
A方招式位移
B方移动
B方招式效果
B方招式位移
```

当前预览已显示预期崩势：

```text
崩势
预期崩势
```

---

## 14. 当前必须保持一致的三套逻辑

以下三者必须尽量一致：

| 模块 | 职责 |
|---|---|
| `CombatResolver` | 规则内核 |
| 真实 Battle 结算 | 写回真实 Fighter 状态 |
| Preview 预演 | 展示预测结果 |

任何新增规则都必须优先进入：

```text
CombatResolver
```

然后再接入：

```text
Battle / Preview / Sampler
```

不要再各写一套独立规则。

---

## 15. 当前已明确废弃或降级的旧设定

### 15.1 9 格距离不再只是静态站位

现在每方行动位移和招式位移都会改变后续结算距离。

### 15.2 招式不再绑定行动位移

移动由角色独立选择，卡牌只负责招式效果和附带位移。

### 15.3 虚影不再表示最终位置

当前虚影表示主观行动位置；最终位置通过箭头终点和效果预览表现。

### 15.4 敌人移动预览不再使用固定绝对格

敌方移动意图按相对位移量处理，必须基于轮到敌方行动时的当前位置结算。

---

## 16. 后续修改约束

新增或修改单局规则时，按以下顺序推进：

1. 修改 `CombatResolver`，确保规则内核唯一。
2. 修改真实战斗写回逻辑，确保实际结算正确。
3. 修改预览逻辑，确保虚影、箭头、效果文本一致。
4. 修改 sampler / 自动对局 / 参数扫描，确保调参工具一致。
5. 更新本文件。

禁止：

```text
只改 UI 预览，不改真实规则；
只改真实规则，不改预览；
只改 cards.json，但不确认 CardData 字段是否支持；
在多个 controller wrapper 中重复写一套规则。
```

---

## 17. 当前下一步建议

1. 把 `battle_controller_visual_resolver_preview.gd` 里的预演逻辑进一步下沉到独立 `PreviewResolver`，减少 wrapper 叠加。
2. 把崩势预览、相对移动预览、箭头终点预览做成自动一致性测试。
3. 为 `CombatResolver` 增加最小单元测试：命中、擦中、未命中、击退、拉近、自移、崩势。
4. 将 `docs/carddata_movement_v032_change_list.md` 标记为历史设计，不再作为第一规则源。
