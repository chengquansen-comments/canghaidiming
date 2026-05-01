# 敌人配置运行时消费说明

> 当前战斗总入口已整合到 [BATTLE.md](BATTLE.md)。`enemy_manifest` 现在是旧剧情战斗 / AI / debug 兼容层，不再是正式剧情战斗敌我数值和卡组的主源；若有冲突，以 `BATTLE.md` 和 StoryBattle 配置为准。
>
## 当前目标

让 `data/enemy_manifest.json` 不只保存敌人数值，还实际驱动：

```text
1. 敌人实际持牌 deck
2. 敌人出招意图权重 intent_weights
3. 半血 / 濒死阶段行为 phase_behaviors
```

---

## 已接入文件

```text
data/enemy_manifest.json
scripts/enemy_ai.gd
scripts/battle_controller_visual_scene_manifest.gd
```

---

## 运行时链路

```text
NarrativeBattleContext.get_enemy_config()
→ enemy_manifest.enemies[enemy_id]
→ battle_controller_visual_scene_manifest.gd
→ _enemy_runtime_config_from_manifest()
→ enemy.data.starting_deck
→ enemy.hand / enemy.draw_pile
```

AI 行为链路：

```text
NarrativeBattleContext.get_enemy_config()
→ intent_weights / phase_behaviors
→ EnemyAI.set_manifest_behavior()
→ EnemyAI.choose_intent()
→ _pick_best_card()
→ _manifest_intent_score()
→ _manifest_phase_score()
```

---

## 当前实现方式

### 1. deck 运行时消费

`battle_controller_visual_scene_manifest.gd` 覆盖：

```gdscript
func _enemy_runtime_config_from_manifest(encounter: String, manifest_enemy: Dictionary) -> Dictionary:
    var config = super._enemy_runtime_config_from_manifest(encounter, manifest_enemy)
    var manifest_deck = manifest_enemy.get("deck", [])
    if manifest_deck is Array and not manifest_deck.is_empty():
        config["deck"] = manifest_deck
    return config
```

含义：

```text
优先使用 enemy_manifest.enemies.*.deck。
如果 deck 缺失，才回退父类 / 旧逻辑。
```

---

### 2. intent_weights 运行时消费

`EnemyAI` 新增：

```gdscript
set_manifest_behavior(intent_weights, phase_behaviors)
clear_manifest_behavior()
```

选牌评分时增加：

```text
_manifest_intent_score()
```

映射规则：

```text
gain_posture  → 提高 gain_momentum 牌评分
break_posture → 提高 break_momentum 牌评分
attack        → 提高 damage 牌评分
guard         → 提高 guard 牌评分
feint         → 提高 虚招 / 先机 / 线索 标签牌评分
```

---

### 3. phase_behaviors 运行时消费

`EnemyAI` 新增：

```text
_active_phase_behavior()
_manifest_phase_score()
```

根据当前敌人 HP 比例选择阶段：

```text
hp_ratio <= hp_below
```

当前支持的 intent_bias：

```text
tutorial
desperate_attack
burst_chain
desperate_clue
poke_pressure
guard_then_poke
guard_counter
counter_break
feint_pressure
fallback
```

---

## 验收建议

### deck 验收

修改 `data/enemy_manifest.json` 中某个敌人 deck 里的牌名或伤害，例如：

```json
{"id":"e_s3","name":"配置突刺测试","damage":9}
```

进入对应战斗后，应在敌方持牌 / 实际出牌中看到变化。

### intent_weights 验收

将某敌人：

```json
"intent_weights": {"attack": 1.0, "guard": 0.0, "gain_posture": 0.0, "break_posture": 0.0, "feint": 0.0}
```

预期：敌人更偏向出伤害牌。

将其改为：

```json
"intent_weights": {"attack": 0.0, "guard": 1.0, "gain_posture": 0.0, "break_posture": 0.0, "feint": 0.0}
```

预期：敌人更偏向出防守牌。

### phase_behaviors 验收

把半血阶段设置为：

```json
{"phase":"wounded","hp_below":0.50,"intent_bias":"guard_counter"}
```

预期：敌人半血后更偏防守 / 反击。

---

## 注意

当前仍保留父类和旧逻辑作为 fallback。不要删除 fallback，避免 JSON 配置缺失时战斗白屏。
