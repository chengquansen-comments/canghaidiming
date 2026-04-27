# v0.4.4 统一数值写入层

> 目标：收敛战斗运行时数值写入，避免 UI wrapper 直接修改真实战斗态。  
> 原则：CombatResolver 只计算；BattleEffectApplier 负责规则型副作用写入；UI 负责触发时机和展示反馈。

---

## 1. 新增文件

```text
scripts/battle_effect_applier.gd
```

职责：

```text
1. reactive enemy pre-move 写入
2. pressure_profile 写入
3. pressure_profile 合法值校验
```

---

## 2. 当前已经迁出的写入

### reactive enemy pre-move

原来在：

```text
scripts/battle_controller_visual_settlement_mode.gd
```

中直接写：

```gdscript
enemy.position = ...
enemy.facing = ...
enemy_intent.set_stance(...)
```

现在改为：

```gdscript
BattleEffectApplier.apply_reactive_enemy_pre_move(...)
```

wrapper 只负责：

```text
1. 判断是否等待玩家输入
2. 调用 applier
3. 根据返回事件写日志 / 横幅
```

---

### pressure_profile

原来在：

```text
scripts/battle_controller_visual_story_return.gd
```

中直接写：

```gdscript
fighter.momentum = ...
fighter.queue_broken_state()
enemy.pending_control_state = ...
```

现在改为：

```gdscript
BattleEffectApplier.apply_pressure_profile(...)
```

wrapper 只负责：

```text
1. 保存 pressure_profile 上下文
2. 调用 applier
3. 根据事件写日志 / 横幅 / 状态栏
```

---

## 3. 支持的 pressure_profile

```text
none
edge_pressure
break_resist
```

合法性由：

```gdscript
BattleEffectApplier.is_valid_pressure_profile(value)
```

校验。

`StoryBattleLoader.validate_all()` 已接入 `pressure_profile` 合法性校验。

---

## 4. 当前仍未完全统一的写入

`BattleStateMachine.resolve_intent()` 仍然承担核心真实结算写回：

```text
hp
momentum
guard_points
position
pending_control_state
pending_combo_window
```

这部分暂时保留，因为它是主结算流程核心，不在 v0.4.4 第一刀中强拆。

后续目标是继续抽出：

```text
BattleEffectApplier.apply_resolver_result(...)
```

让 `BattleStateMachine.resolve_intent()` 也只负责组织流程和日志拼装。

---

## 5. 当前分层

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

---

## 6. 已修正的问题

```text
1. break_resist 不再写 pending_control_state = ""，改由 BattleEffectApplier 写 Fighter.CONTROL_NONE。
2. pressure_profile 增加合法值校验。
3. 状态栏显示当前 pressure_profile。
4. 删除 wrapper 中未使用的 _last_pressure_round。
5. reactive pre-move 写入迁出 wrapper。
6. pressure_profile 写入迁出 wrapper。
```

---

## 7. 后续建议

下一步建议做：

```text
v0.4.5 apply_resolver_result
```

目标：

```text
1. 把 BattleStateMachine.resolve_intent() 中 hp / momentum / guard / position 写入抽出。
2. CombatResolver 继续只算。
3. BattleEffectApplier 统一写回 sim 结果。
4. Preview / Battle / Sampler 使用同一套 result schema。
```
