# 《沧海嘀鸣》玩法与单局战斗当前规则源

> 当前战斗总入口已整合到 [BATTLE.md](BATTLE.md)。本文保留为详细规则附录；若有冲突，以 `BATTLE.md` 和当前代码为准。
>
> 版本：current / main / v0.4.4  
> 范围：当前 Godot demo 已落地的战斗玩法、剧情战斗配置、压力规则、数值写入边界。  
> 用途：作为后续 Codex / Claude 修改、策划调参、预览一致性校验、自动采样的详细规则附录。
> 重要原则：本文只记录“当前代码已经落地或明确生效的规则”，不是早期设想稿。

---

## 0. 当前规则源优先级

当文档、旧设计和代码不一致时，按以下优先级判断：

1. `scripts/combat_resolver.gd`：命中、伤害、削势、格挡、崩势预判、招式位移的纯计算内核。
2. `scripts/battle_state_machine.gd`：回合阶段、行动顺序、真实结算写回、回合结束状态推进。
3. `scripts/battle_effect_applier.gd`：规则型副作用写入层，目前负责 reactive 敌方预移动与 pressure_profile 写入。
4. `data/story_battles/*.tsv` + `scripts/story_battle_loader.gd`：正式剧情战斗配置来源。
5. `scripts/card_data.gd` + `battle_controller_core.gd::_build_catalog()`：当前主线卡牌定义与卡牌数值来源。
6. 视觉 wrapper：预览、虚影、箭头、结算动画、日志与状态栏展示。

> 旧阶段性文档已经合并进本文，不再作为单独规则源。

---

## 1. 一句话核心体验

玩家在 9 格距离轴上，通过“主观移动 + 出招 + 看破敌方意图 + 抢先后手/反应破解”，制造命中、擦中、破势、崩势、位移与边界压力，形成敌我双方动态拆招。

当前有两套结算模式：

| 模式 | id | 核心体验 |
|---|---|---|
| 对称式 | `symmetric` | 敌我双方同时决策，按先机、崩势、武境、同境轮换决定先后手 |
| 反应式 | `reactive` | 敌方先移动并亮意图，玩家后响应；玩家通常先结算，可通过崩势打断敌方 |

---

## 2. 战斗空间

### 2.1 9 格距离轴

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

### 2.2 默认站位

正式剧情战斗中，默认站位来自：

```text
data/story_battles/fighter_templates.tsv
```

当前常用默认：

| 阵营 | 默认位置 | 默认朝向 |
|---|---:|---|
| 我方 | 2 | right |
| 对手 | 6 | left |

注意：模板本身不区分敌我。谁站我方、谁站对手，由 `story_encounters.tsv` 决定。

---

## 3. 正式剧情战斗配置管线

当前正式内容管线为：

```text
CardData 主线卡牌定义
→ story_deck_sets 引用卡牌
→ fighter_templates 定义战斗单位
→ fighter_stat_sets 定义数值强度
→ story_encounters 组合双方并指定结算模式与压力规则
```

正式配置目录：

```text
data/story_battles/
  fighter_templates.tsv
  story_deck_sets.tsv
  fighter_stat_sets.tsv
  story_encounters.tsv
```

`scripts/story_battle_loader.gd` 负责读取 TSV 并组装 `FighterData`。

### 3.1 `fighter_templates.tsv`

定义“战斗单位是谁”，不定义敌我身份。

| 字段 | 说明 |
|---|---|
| `fighter_template_id` | 战斗单位模板唯一 ID |
| `display_name` | 展示名 |
| `weapon_style` | 武器风格，如 `spearman` / `blademaster` |
| `default_position` | 默认站位 |
| `default_facing` | 默认朝向 |
| `story_role` | 剧情角色定位 |
| `notes` | 备注 |

当前原则：

```text
模板不分敌我。
同一个 fighter_template 可以在不同 encounter 中作为玩家、对手、师傅、友军或训练对象。
```

### 3.2 `story_deck_sets.tsv`

定义某个战斗单位在某个剧情版本中使用哪些招式。

| 字段 | 说明 |
|---|---|
| `story_deck_id` | 剧情卡组唯一 ID |
| `display_name` | 展示名 |
| `fighter_template_id` | 适用的战斗单位模板 |
| `deck` | 卡组配置，格式为 `card_id:数量,card_id:数量` |
| `tags` | 标签，如 `teaching` / `pressure` / `break_focus` |
| `notes` | 备注 |

示例：

```text
blade_cut:2,blade_press:2,blade_probe:1
```

表示：

```text
blade_cut × 2
blade_press × 2
blade_probe × 1
```

当前规则：

```text
story_deck_sets 只能引用当前主线中已存在的 CardData.id。
TSV 不定义新卡牌，不改卡牌数值。
```

### 3.3 `fighter_stat_sets.tsv`

定义一场战斗中的数值强度。

| 字段 | 说明 |
|---|---|
| `stat_set_id` | 数值套装唯一 ID |
| `display_name` | 展示名 |
| `max_hp` | 最大生命 |
| `max_momentum` | 最大势 |
| `starting_momentum` | 初始势 |
| `starting_realm` | 初始武境 |
| `qinggong` | 轻功移动范围 |
| `notes` | 备注 |

### 3.4 `story_encounters.tsv`

定义一场剧情战斗。只有这一层区分我方和对手。

| 字段 | 说明 |
|---|---|
| `encounter_id` | 剧情遭遇唯一 ID |
| `display_name` | 展示名 |
| `player_template_id` | 我方模板 |
| `player_deck_id` | 我方剧情卡组 |
| `player_stat_set_id` | 我方数值套装 |
| `opponent_template_id` | 对手模板 |
| `opponent_deck_id` | 对手剧情卡组 |
| `opponent_stat_set_id` | 对手数值套装 |
| `settlement_mode` | 结算模式，`symmetric` / `reactive` |
| `pressure_profile` | 压力规则，`none` / `edge_pressure` / `break_resist` |
| `intent_visibility_policy` | 敌方意图可见性，`full` / `realm_based` / `hidden` |
| `notes` | 备注 |

当前开局流程：

```text
选择剧情遭遇
→ encounter 自动决定双方 FighterData、settlement_mode、pressure_profile
→ 进入战斗
```

战斗结束后：

```text
自动返回剧情遭遇选择
```

---

## 3.5 敌方意图可见性

配置字段：

```text
data/story_battles/story_encounters.tsv / intent_visibility_policy
```

可选值：

```text
full / realm_based / hidden
```

规则：

```text
full: 永远显示完整敌方意图
hidden: 永远隐藏敌方具体意图
realm_based:
  非 reactive: 全意图
  reactive:
	我方武境 > 敌方武境: 全意图
	我方武境 = 敌方武境: 只显示类型（攻/守/变）
	我方武境 < 敌方武境: 不可辨
```

全局一键关闭（恢复全意图）：

```text
scripts/battle_intent_visibility.gd
USE_INTENT_VISIBILITY_POLICY = false
```

---

## 4. 旧 enemy_sets 定位

旧目录：

```text
data/enemy_sets/
```

当前定位为：

```text
sandbox / 历史调参池
```

正式剧情战斗不再优先使用 `enemy_sets`。后续新增正式战斗配置，应写入：

```text
data/story_battles/
```

禁止让 `data/enemy_sets/` 重新变成正式剧情配置源。

---

## 5. 卡牌数值来源

当前 `CardData` 本体与主线卡牌数值仍主要来自：

```text
scripts/card_data.gd
scripts/battle_controller_core.gd::_build_catalog()
```

`story_deck_sets.tsv` 只引用卡牌 ID 和数量，不定义卡牌本体。

`CardData` 当前核心字段：

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

后续如果要大规模调招式数值，应新增 `data/cards/card_definitions.tsv`，但当前尚未完成。

---

## 6. FighterData 与 Fighter 战斗态

`FighterData` 是静态初始配置，来自代码或 `StoryBattleLoader`：

```text
id
display_name
weapon_style
max_hp
max_momentum
starting_momentum
starting_realm
preferred_distances
starting_deck
qinggong
start_position
start_facing
```

`Fighter` 是运行时战斗态：

```text
hp
momentum
realm
guard_points
control_state
pending_control_state
combo_window_active
pending_combo_window
position
facing
qinggong
draw_pile
discard_pile
hand
```

当前注意事项：

```text
Fighter.new(data) 后外层仍会 reset_for_battle(HAND_SIZE)。
这会带来一次重复初始化风险，但当前最终状态可用。
后续建议统一 Fighter 初始化与 reset 时机。
```

---

## 7. 每回合高层流程

### 7.1 对称式 symmetric

```text
1. 敌我各自生成/选择意图
2. 玩家选择移动目标
3. 玩家选择招式牌
4. 玩家确认出招
5. BattleStateMachine 计算行动顺序
6. 按顺序依次结算：
   A方行动位移
   A方招式命中/伤害/削势/格挡
   A方招式附带位移
   B方行动位移
   B方招式命中/伤害/削势/格挡
   B方招式附带位移
7. pressure_profile 可能追加规则型副作用
8. 结束回合：清护值，推进崩势/连招窗口，轮换同武境先手权
```

### 7.2 反应式 reactive

```text
1. 敌方生成意图
2. BattleEffectApplier 提交敌方预移动
3. 敌方展示攻击意图
4. 玩家选择移动目标与招式
5. 玩家通常先结算
6. 若敌方被打入 pending 崩势，则敌方本回合攻击可被中断
7. 若未被中断，敌方基于玩家结算后的最终站位重新判断命中
8. pressure_profile 可能追加规则型副作用
9. 回合结束状态推进
```

注意：

```text
reactive 下敌人先移动并亮意图，但敌方最终是否命中，要基于玩家响应后的真实位置重新判定。
```

---

## 8. 行动位移规则

### 8.1 玩家移动

玩家可以在轻功范围内选择移动目标。

```text
可选位置 = 当前格 ± qinggong 范围内的格子 + 当前格
```

不选择位置时：

```text
默认原地
```

再次选择当前位置时：

```text
角色转向
```

### 8.2 敌方移动

敌方意图内也有目标位置或移动意图。

反应式下：

```text
敌方预移动由 BattleEffectApplier.apply_reactive_enemy_pre_move() 写入。
```

对称式预演中，敌方行动位移仍按“相对位移”理解：

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

---

## 9. 行动顺序规则

真实行动顺序由：

```text
BattleStateMachine.get_resolution_order()
```

决定。

### 9.1 对称式顺序

优先级：

```text
先机 > 崩势状态 > 武境 > 同武境轮换
```

同武境下：

```text
player_tie_advantage
```

每回合结束后轮换。

### 9.2 反应式顺序

反应式下：

```text
玩家通常先结算。
若玩家已经崩势且敌方未崩势，则敌方先结算。
```

敌方若在本回合被打入 pending 崩势：

```text
BattleStateMachine.should_cancel_enemy_reactive_action(enemy) == true
```

则敌方攻击中断。

---

## 10. 命中判定规则

由：

```text
CombatResolver.evaluate_range()
```

统一判断。

### 10.1 不需要命中判定的牌

如果：

```text
card == null
或 card.requires_hit_check() == false
```

则视为：

```text
RANGE_HIT
```

### 10.2 朝向判定

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

### 10.3 距离判定

```text
distance = abs(target.position - actor.position)
```

| 条件 | 结果 |
|---|---|
| `min_distance <= distance <= max_distance` | `RANGE_HIT` |
| 距离只差 1 格 | `RANGE_GRAZE` |
| 距离差超过 1 格 | `RANGE_MISS_RANGE` |

---

## 11. 伤害、削势、增势、护值规则

由：

```text
CombatResolver.resolve_card_effect()
```

统一计算。

### 11.1 未命中或行动者崩势

如果行动者崩势，或命中结果不是 `hit / graze`：

```text
伤害 = 0
削势 = 0
增势 = 0
护值 = card.guard
```

即：

```text
未命中不会造成伤害、削势、增势。
格挡值仍按卡牌 guard 生效。
```

### 11.2 擦中

如果结果为：

```text
RANGE_GRAZE
```

则：

```text
伤害 = ceil(原伤害 * 0.5)，至少 1
削势 = max(原削势 - 1, 0)
```

### 11.3 目标崩势时受击

如果目标当前已经崩势，且伤害大于 0：

```text
伤害翻倍
```

### 11.4 护值

伤害结算时：

```text
最终伤害 = max(伤害 - 目标护值, 0)
```

护值在回合结束时清空。

---

## 12. 势与崩势规则

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

当前崩势效果：

```text
崩势者本回合无法行动；
崩势者受击伤害翻倍；
对手获得连招窗口。
```

---

## 13. 招式附带位移规则

由：

```text
CombatResolver.apply_card_movement()
```

统一判断。

### 13.1 触发条件

`move_condition` 当前支持：

| 值 | 触发条件 |
|---|---|
| `none` | 不触发招式位移 |
| `always` | 总是触发 |
| `on_hit` | 仅 `RANGE_HIT` 触发 |
| `on_graze` | 仅 `RANGE_GRAZE` 触发 |
| `on_break` | 目标本次会崩势时触发 |

### 13.2 位移优先级

同一张牌如果同时配置多种招式位移，resolver 优先级为：

```text
target_push_after > target_pull_after > self_move_after
```

### 13.3 自身位移

`self_move_after` 当前被 clamp 到：

```text
-1 / 0 / 1
```

即使字段未来写成 2 或 3，当前真实效果仍最多 1 格。

### 13.4 击退目标

```text
target_push_after > 0
```

目标沿“从行动者指向目标”的方向远离行动者。

### 13.5 拉近目标

```text
target_pull_after > 0
```

目标沿“从目标指向行动者”的方向靠近行动者，且不会穿过行动者。

---

## 14. pressure_profile 压力规则

压力规则配置在：

```text
data/story_battles/story_encounters.tsv
```

字段：

```text
pressure_profile
```

当前合法值由 `BattleEffectApplier.is_valid_pressure_profile()` 校验：

| profile | 说明 |
|---|---|
| `none` | 无额外压力规则 |
| `edge_pressure` | 边界压迫：角色进入 0 位或 8 位边界时额外失 1 势 |
| `break_resist` | 精英稳势：对手第一次 pending 崩势被抵消，势保留为 1 |

### 14.1 edge_pressure

9 格轴中：

```text
0 位 = 左边界
8 位 = 右边界
```

当任意一方进入边界时：

```text
额外失 1 势
```

如果因此势变为 0：

```text
进入 pending 崩势
```

同一回合、同一角色、同一边界位置只触发一次。

当前版本中，`edge_pressure` 对我方和对手都生效。

### 14.2 break_resist

对手拥有 1 次“稳势”。

当对手第一次被打入：

```text
pending_control_state == Fighter.CONTROL_BROKEN
```

时：

```text
取消本次 pending 崩势
对手势保留为 1
本次 reactive 崩势中断不生效
```

该写入由：

```text
BattleEffectApplier.apply_break_resist()
```

完成，并使用：

```text
Fighter.CONTROL_NONE
```

清除 pending 状态。

---

## 15. 数值写入分层

当前分层：

```text
CombatResolver
= 纯计算，不写 Fighter

BattleStateMachine
= 当前核心结算流程，仍写主战斗态

BattleEffectApplier
= 规则型副作用统一写入层

Visual Wrappers
= 调用时机、日志、横幅、状态栏，不直接写 pressure / reactive pre-move 数值
```

### 15.1 BattleEffectApplier 已承接

```text
reactive enemy pre-move
pressure_profile edge_pressure
pressure_profile break_resist
pressure_profile 合法值校验
```

### 15.2 BattleStateMachine 仍承接

`BattleStateMachine.resolve_intent()` 当前仍写：

```text
hp
momentum
guard_points
position
pending_control_state
pending_combo_window
```

这是当前仍未完成统一的核心写入。后续目标是新增：

```text
BattleEffectApplier.apply_resolver_result(...)
```

把核心结算写回也迁出。

---

## 16. 预览规则

### 16.1 虚影

当前视觉规则：

```text
虚影 = 主观行动位置
```

透明度：

```text
默认 80%；
虚影与自身真实位置重叠时 0%。
```

### 16.2 箭头

当前视觉规则：

```text
箭头 = 主观行动位置 → 整回合最终位置
```

箭头起点和终点均为格子正中央。

如果主观位置等于整回合最终位置：

```text
不显示箭头
```

### 16.3 效果预览文本

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

### 16.4 reactive 威胁摘要

反应式模式中，预览区补充显示：

```text
敌方已落位
我方响应是否命中
我方伤害/削势
是否崩势打断
若不能打断，敌方最终是否命中
敌方预计伤害/削势
双方最终预估站位
```

敌方攻击范围可视化继续沿用既有对称式梯形范围表现，不新增另一套危险格 UI。

---

## 17. 战斗结束流程

当前 `MainVisual` 使用：

```text
scripts/battle_controller_visual_story_return.gd
```

战斗结果检测：

```text
player.hp <= 0 或 enemy.hp <= 0
```

结果：

```text
战斗胜利 / 战斗失败 / 两败俱伤
→ 清理本场战斗状态
→ state_machine.reset_for_session()
→ 返回剧情遭遇选择
```

---

## 18. 配置校验

启动时：

```text
StoryBattleLoader.validate_all(card_catalog)
```

会校验：

```text
fighter_templates 是否有空 ID / 重复 ID
story_deck_sets 是否引用不存在的 fighter_template_id
story_deck_sets.deck 是否引用不存在的 CardData.id
fighter_stat_sets 数值字段是否为 int
story_encounters 是否引用不存在的 template / deck / stat
settlement_mode 是否只使用 symmetric / reactive
pressure_profile 是否只使用 none / edge_pressure / break_resist
encounter 中 deck 对应的 fighter_template_id 是否和 encounter 的 template 一致
```

控制台预期：

```text
StoryBattle TSV validation: OK
```

---

## 19. 当前必须保持一致的逻辑

以下模块必须保持一致：

| 模块 | 职责 |
|---|---|
| `CombatResolver` | 纯计算规则内核 |
| `BattleStateMachine` | 核心真实结算流程 |
| `BattleEffectApplier` | 规则型副作用写入 |
| Preview 预演 | 展示预测结果 |
| Sampler / 参数扫描 | 自动对局和调参评估 |

新增规则时，禁止：

```text
只改 UI 预览，不改真实规则；
只改真实规则，不改预览；
在多个 controller wrapper 中重复写一套规则；
在 story_deck_sets.tsv 中发明不存在的 CardData.id；
在 story_encounters.tsv 外部决定谁是玩家、谁是对手。
```

---

## 20. 当前已明确废弃或降级的旧设定

```text
1. data/enemy_sets/ 不再是正式剧情战斗配置源，只保留为 sandbox。
2. 开局不再是“结算模式 → 敌人套装 → 兵器”，而是“选择剧情遭遇”。
3. 招式不再绑定行动位移；行动位移由角色本回合主观选择，招式只负责效果与附带位移。
4. 虚影不表示最终位置，而表示主观行动位置。
5. reactive 敌方预移动和 pressure_profile 不再由 visual wrapper 直接写数值，而是通过 BattleEffectApplier。
```

---

## 21. 后续修改约束

新增或修改单局规则时，按以下顺序推进：

1. 修改 `CombatResolver` 或 `BattleEffectApplier`，保证规则来源明确。
2. 修改真实战斗写回逻辑，确保实际结算正确。
3. 修改预览逻辑，确保虚影、箭头、效果文本一致。
4. 修改 sampler / 自动对局 / 参数扫描，确保调参工具一致。
5. 更新本文。

---

## 22. 下一步建议

1. `v0.4.5 apply_resolver_result`：把 `BattleStateMachine.resolve_intent()` 中 hp / momentum / guard / position 写入抽到 `BattleEffectApplier`。
2. `v0.4.6 card_definitions.tsv`：把卡牌本体数值从 `_build_catalog()` 外置。
3. 将 `preferred_distances` 显式加入 `fighter_templates.tsv`，支持不同枪手/刀客的距离偏好差异。
4. 给 `CombatResolver` 增加最小单元测试：命中、擦中、未命中、击退、拉近、自移、崩势。
5. 将 Preview / Battle / Sampler 的结果 schema 进一步统一。
