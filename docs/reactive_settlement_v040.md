# v0.4 反应式结算模式设计案

> 当前战斗总入口已整合到 [BATTLE.md](BATTLE.md)。本文是反应式结算早期设计案，默认模式与落地范围可能已过时；若有冲突，以 `BATTLE.md` 和当前代码为准。
>
> 分支：main  
> 目的：在当前“对称式结算”之外，新增一套可切换的备用结算模式。  
> 定位：主体验候选 / 教学友好模式 / Into the Breach 式反应解题模式。

---

## 1. 模式定义

当前项目同时保留两种结算模式：

| 模式 | ID | 定位 |
|---|---|---|
| 对称式 | `symmetric` | 早期默认模式；当前保留用于对照与旧规则测试。 |
| 反应式 | `reactive` | 当前默认模式。敌方先移动并展示攻击意图，玩家再行动；不看武境决定先后，不坚持敌我完全对称。 |

---

## 2. 反应式模式核心体验

一句话：

```text
敌人先摆出威胁，玩家用移动、出招、击退、拉近、破势来破解局面。
```

玩家每回合思考三件事：

```text
1. 怎么躲开敌方威胁？
2. 怎么同时命中敌人？
3. 能不能打出崩势，中断敌方攻击？
```

---

## 3. 反应式回合流程

建议完整流程如下：

```text
1. 回合开始
2. 敌方 AI 决定移动意图
3. 敌方先执行移动
4. 敌方锁定并展示攻击意图
5. 玩家选择移动
6. 玩家选择招式
7. 玩家确认行动
8. 玩家先结算：
   - 玩家行动位移
   - 玩家招式命中/伤害/削势/增势/护值
   - 玩家招式附带位移
9. 若敌方未被玩家打入崩势，则敌方结算：
   - 敌方招式命中/伤害/削势/增势/护值
   - 敌方招式附带位移
10. 回合结束：清护值，激活 pending 崩势/连招窗口
```

---

## 4. 与对称式模式的差异

| 维度 | 对称式 | 反应式 |
|---|---|---|
| 敌方移动 | 与玩家同回合预演 | 敌方先移动并落位 |
| 敌方意图 | 可隐藏/可见，参与同时博弈 | 移动后展示，作为玩家解题条件 |
| 玩家行动 | 与敌方按顺序结算 | 玩家响应敌方威胁后先结算 |
| 先后手 | 先机/崩势/武境/同境轮换 | 默认玩家结算先于敌方攻击 |
| 武境 | 决定识机权/先后手 | 不决定先后手，可降级为影响意图清晰度 |
| 核心乐趣 | 猜招、抢先、双向拆招 | 看威胁、解题、打断、反击 |
| 适用场景 | 高手对决、精英/Boss | 教学、普通战斗、主模式候选 |

---

## 5. 当前代码接入状态

### 已接入

`BattleStateMachine` 已新增：

```gdscript
SettlementMode.SYMMETRIC
SettlementMode.REACTIVE
```

并新增字符串 ID：

```gdscript
MODE_SYMMETRIC_ID = "symmetric"
MODE_REACTIVE_ID = "reactive"
```

可通过以下接口切换：

```gdscript
state_machine.set_settlement_mode_id("reactive")
state_machine.set_settlement_mode_id("symmetric")
```

当前默认仍是：

```gdscript
SettlementMode.SYMMETRIC
```

避免破坏现有 main 体验。

### 已接入的规则行为

反应式模式下：

```gdscript
get_declaration_order()
```

返回：

```text
敌方 → 玩家
```

用于表达“敌方先移动并展示意图，玩家后响应”。

反应式模式下：

```gdscript
get_resolution_order()
```

默认返回：

```text
玩家 → 敌方
```

也就是玩家响应后先结算。

新增：

```gdscript
should_cancel_enemy_reactive_action(enemy)
```

用于判断玩家先手打出崩势后，敌方本回合攻击是否应取消。

---

## 6. 当前尚未完整接入

本版本是“规则模式脚手架”，不是完整 UI/流程改造。

尚未完成：

```text
1. 敌方先移动的真实 UI 流程
2. 敌方移动后再亮攻击意图的阶段切换
3. 玩家响应阶段的专用预览
4. 反应式模式下敌方被崩势后的攻击取消接入 controller
5. 模式选择 UI
6. sampler / 自动对局 / 调参面板支持 settlement_mode
```

---

## 7. 推荐下一步 Codex 任务

### 任务 1：增加模式切换入口

在 controller 或启动配置中加入：

```gdscript
var settlement_mode_id := "symmetric"
```

并在开局时：

```gdscript
state_machine.set_settlement_mode_id(settlement_mode_id)
```

### 任务 2：实现反应式敌方预行动阶段

新增阶段或流程：

```text
enemy_pre_move
enemy_intent_reveal
player_response
reactive_resolution
```

最低实现：

```text
回合开始时敌方先执行 target_position 移动；
然后刷新 UI，展示敌方攻击意图；
玩家再选择移动和招式。
```

### 任务 3：接入崩势中断

在反应式结算中：

```gdscript
先结算玩家 intent
if state_machine.should_cancel_enemy_reactive_action(enemy):
    跳过敌方攻击
else:
    结算敌方 intent
```

### 任务 4：更新预览

反应式预览不再展示“双方同时行动顺序”，而展示：

```text
敌方已移动位置
敌方威胁范围
玩家响应后：我方命中 / 敌方命中 / 是否打断 / 最终距离
```

---

## 8. 设计边界

反应式模式第一版暂时不要引入：

```text
武境先后手
同武境轮换
复杂先机抢序
敌我完全对称提交
隐藏多层敌方意图
```

保留：

```text
9格距离
朝向
行动位移
招式位移
命中/擦中/未命中
削势
崩势
格挡
枪/刀距离差异
```

---

## 9. 结论

反应式模式是当前单局最值得验证的备用逻辑。它牺牲一部分“同构武斗感”，但换来更强的可读性、教学友好度和策略解题感。

建议后续以可切换模式推进：

```text
默认：symmetric
实验：reactive
```

若 reactive 的 5 分钟体验明显更强，可再考虑将其上升为普通战斗主模式，而将 symmetric 保留给高手、精英和 Boss。
