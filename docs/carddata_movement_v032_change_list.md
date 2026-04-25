# 《沧海嘀鸣》v0.3.2 招式牌 JSON / CardData 字段修改清单

> 目标分支：`feature/symmetry-gameplay`  
> 文档目标：把 v0.3.2 的“招式命中后位移”设计翻译成 Codex 可执行的字段、规则、结算函数和首批招式牌配置。  
> 当前前提：玩家行动已经拆为“选位 / 朝向 / 出招”，本轮只新增“出招命中后的位移效果”。

---

## 1. 本轮核心目标

v0.3.2 要解决的问题：

```text
9 格距离轴偏短，单纯靠攻击距离区分枪/刀不够。
需要让招式在命中后改变双方位置，从而形成枪手控距、刀客贴身的职业差异。
```

本轮新增：

```text
招式命中后位移
击退敌人
拉近敌人
自身进身
自身后退
位移后刷新距离与朝向
```

---

## 2. 战斗距离重新收敛

| 职业 | 核心攻击区 | 设计关键词 |
|---|---:|---|
| 枪手 | 2-3 | 控距、击退、拒止、压线 |
| 刀客 | 1-2 | 贴身、拉近、追身、压迫 |

说明：

```text
枪手不再是 4-5 格远程炮台，而是 2-3 格控线。
刀客不只是贴脸爆发，而是 1-2 格持续压迫。
```

---

## 3. CardData 字段修改

## 3.1 修改文件

```text
scripts/card_data.gd
```

## 3.2 新增字段

```gdscript
var self_move_after: int = 0
var target_push_after: int = 0
var target_pull_after: int = 0
var move_condition: String = "none"
```

## 3.3 字段含义

| 字段 | 类型 | 含义 |
|---|---|---|
| `self_move_after` | int | 自身出招后位移。`1` 表示向敌人前进，`-1` 表示远离敌人 |
| `target_push_after` | int | 命中后击退目标，目标远离自己 |
| `target_pull_after` | int | 命中后拉近目标，目标靠近自己 |
| `move_condition` | String | 位移触发条件：`none / on_hit / always / on_break / on_graze` |

## 3.4 当前 Demo 推荐只实现

```text
none
on_hit
always
```

暂缓：

```text
on_break
on_graze
```

---

## 4. CardData 初始化参数修改

当前 CardData 构造函数需要在已有字段后追加：

```gdscript
p_self_move_after: int = 0,
p_target_push_after: int = 0,
p_target_pull_after: int = 0,
p_move_condition: String = "none"
```

建议完整结构为：

```gdscript
func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_description: String = "",
	p_min_distance: int = 1,
	p_max_distance: int = 3,
	p_momentum_cost: int = 1,
	p_role: String = ROLE_DAMAGE,
	p_gain_momentum: int = 0,
	p_break_momentum: int = 0,
	p_damage: int = 0,
	p_guard: int = 0,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true,
	p_self_move_after: int = 0,
	p_target_push_after: int = 0,
	p_target_pull_after: int = 0,
	p_move_condition: String = "none"
) -> void:
```

赋值规则：

```gdscript
self_move_after = clampi(p_self_move_after, -1, 1)
target_push_after = clampi(p_target_push_after, 0, 1)
target_pull_after = clampi(p_target_pull_after, 0, 1)
move_condition = p_move_condition
```

如果担心非法字符串，可做白名单：

```gdscript
var allowed_conditions := ["none", "on_hit", "always", "on_break", "on_graze"]
move_condition = p_move_condition if allowed_conditions.has(p_move_condition) else "none"
```

---

## 5. duplicate_card 必须同步新增字段

### 修改文件

```text
scripts/card_data.gd
```

在 `duplicate_card()` 末尾追加：

```gdscript
self_move_after,
target_push_after,
target_pull_after,
move_condition
```

否则运行时抽牌、复制牌库、奖励牌会丢失位移效果。

---

## 6. short_summary 文案修改

### 修改文件

```text
scripts/card_data.gd
```

建议在 `short_summary()` 中追加：

```gdscript
if target_push_after > 0:
	parts.append("击退 %d" % target_push_after)
if target_pull_after > 0:
	parts.append("拉近 %d" % target_pull_after)
if self_move_after > 0:
	parts.append("进身 %d" % self_move_after)
elif self_move_after < 0:
	parts.append("后撤 %d" % absi(self_move_after))
if move_condition != "none":
	parts.append("位移条件 %s" % move_condition)
```

---

## 7. battle_controller_core.gd 的 _ready_card 修改

### 修改文件

```text
scripts/battle_controller_core.gd
```

当前 `_ready_card()` 是代码内构建卡牌的入口。需要在参数末尾追加：

```gdscript
p_self_move_after: int = 0,
p_target_push_after: int = 0,
p_target_pull_after: int = 0,
p_move_condition: String = "none"
```

并传给 `CardData.new(...)`。

建议函数签名：

```gdscript
func _ready_card(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_min_distance: int,
	p_max_distance: int,
	p_cost: int,
	p_role: String,
	p_gain_momentum: int,
	p_break_momentum: int,
	p_damage: int,
	p_guard: int,
	p_tags: PackedStringArray = PackedStringArray(),
	p_weapon_style: String = "",
	p_requires_facing: bool = true,
	p_self_move_after: int = 0,
	p_target_push_after: int = 0,
	p_target_pull_after: int = 0,
	p_move_condition: String = "none"
) -> CardData:
```

---

## 8. 位移结算规则

## 8.1 触发时机

```text
1. 双方根据轻功完成本回合站位
2. 更新距离
3. 按先机 / 武境 / 崩势决定出招顺序
4. 结算招式命中：hit / graze / miss_range / miss_facing
5. 结算伤害、格挡、削势、增势
6. 若满足条件，结算招式位移
7. 更新双方距离、朝向
8. 继续结算下一个意图
```

结论：

```text
位移发生在伤害 / 削势之后。
先手位移会影响后手命中。
```

---

## 8.2 位移触发条件

| range_result | 是否触发 on_hit |
|---|---|
| `hit` | 是 |
| `graze` | 否，后续版本再支持 |
| `miss_range` | 否 |
| `miss_facing` | 否 |

| move_condition | 触发规则 |
|---|---|
| `none` | 不触发 |
| `on_hit` | 只有正中触发 |
| `always` | 不需要命中，防御/聚势牌可用 |
| `on_break` | 本次使目标势归 0 时触发，暂缓 |
| `on_graze` | 擦中也触发，暂缓 |

---

## 9. 位移方向规则

## 9.1 自身向敌人前进：self_move_after = 1

```text
如果 target.position > actor.position：actor.position += 1
如果 target.position < actor.position：actor.position -= 1
如果 target.position == actor.position：不移动
```

## 9.2 自身远离敌人：self_move_after = -1

```text
如果 target.position > actor.position：actor.position -= 1
如果 target.position < actor.position：actor.position += 1
如果 target.position == actor.position：按 actor.facing 的反方向后退
```

同格时：

| actor.facing | 后退方向 |
|---|---|
| `right` | 向左 |
| `left` | 向右 |

## 9.3 击退目标：target_push_after = 1

```text
如果 target.position > actor.position：target.position += 1
如果 target.position < actor.position：target.position -= 1
如果 target.position == actor.position：按 actor.facing 方向击退
```

## 9.4 拉近目标：target_pull_after = 1

```text
如果 target.position > actor.position：target.position -= 1
如果 target.position < actor.position：target.position += 1
如果 target.position == actor.position：不移动
```

---

## 10. 边界与穿越规则

九格范围：

```text
0 1 2 3 4 5 6 7 8
```

统一 clamp：

```gdscript
position = clampi(position, 0, 8)
```

| 情况 | 规则 |
|---|---|
| 击退到 9 | 停在 8 |
| 后退到 -1 | 停在 0 |
| 拉近越过自己 | 不允许越过，只能到同格 |
| 自身前进越过敌人 | 不允许越过，只能到同格 |
| distance = 0 | 合法，表示贴身缠斗 |

---

## 11. 位移后朝向规则

当前 Demo 保持简单：

```text
位移后双方自动相向。
```

建议函数：

```gdscript
func face_target(actor: Fighter, target: Fighter) -> void:
	if target.position > actor.position:
		actor.facing = "right"
	elif target.position < actor.position:
		actor.facing = "left"
```

同格时保持原朝向。

---

## 12. BattleStateMachine 新增函数建议

### 修改文件

```text
scripts/battle_state_machine.gd
```

## 12.1 方向函数

```gdscript
func direction_toward(actor_pos: int, target_pos: int, fallback_facing: String) -> int:
	if target_pos > actor_pos:
		return 1
	if target_pos < actor_pos:
		return -1
	return 1 if fallback_facing == "right" else -1
```

## 12.2 自身位移

```gdscript
func apply_self_move(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount == 0:
		return

	var dir := direction_toward(actor.position, target.position, actor.facing)

	if amount > 0:
		actor.position += dir
	else:
		actor.position -= dir

	actor.position = clampi(actor.position, 0, 8)

	if amount > 0:
		if dir > 0 and actor.position > target.position:
			actor.position = target.position
		if dir < 0 and actor.position < target.position:
			actor.position = target.position
```

## 12.3 击退目标

```gdscript
func apply_push_target(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount <= 0:
		return

	var dir := direction_toward(actor.position, target.position, actor.facing)
	target.position += dir * amount
	target.position = clampi(target.position, 0, 8)
```

## 12.4 拉近目标

```gdscript
func apply_pull_target(actor: Fighter, target: Fighter, amount: int) -> void:
	if amount <= 0:
		return

	var dir := direction_toward(actor.position, target.position, actor.facing)
	target.position -= dir * amount
	target.position = clampi(target.position, 0, 8)

	if dir > 0 and target.position < actor.position:
		target.position = actor.position
	if dir < 0 and target.position > actor.position:
		target.position = actor.position
```

## 12.5 自动朝向

```gdscript
func face_target(actor: Fighter, target: Fighter) -> void:
	if target.position > actor.position:
		actor.facing = "right"
	elif target.position < actor.position:
		actor.facing = "left"
```

---

## 13. 位移结算主函数

### 修改文件

```text
scripts/battle_state_machine.gd
```

新增：

```gdscript
func apply_card_movement(card: CardData, actor: Fighter, target: Fighter, range_result: String, target_broken_this_hit: bool) -> Array[String]:
	var lines: Array[String] = []

	var can_move := false
	match card.move_condition:
		"always":
			can_move = true
		"on_hit":
			can_move = range_result == RANGE_HIT
		"on_graze":
			can_move = range_result == RANGE_HIT or range_result == RANGE_GRAZE
		"on_break":
			can_move = target_broken_this_hit
		_:
			can_move = false

	if not can_move:
		return lines

	var before_actor := actor.position
	var before_target := target.position

	if card.target_push_after > 0:
		apply_push_target(actor, target, card.target_push_after)
	elif card.target_pull_after > 0:
		apply_pull_target(actor, target, card.target_pull_after)
	elif card.self_move_after != 0:
		apply_self_move(actor, target, card.self_move_after)

	face_target(actor, target)
	face_target(target, actor)
	update_distance_from_positions(actor, target)

	if actor.position != before_actor:
		lines.append("%s 位移：%d → %d。" % [actor.data.display_name, before_actor, actor.position])
	if target.position != before_target:
		lines.append("%s 被带动：%d → %d。" % [target.data.display_name, before_target, target.position])

	return lines
```

---

## 14. resolve_intent 接入位置

### 修改文件

```text
scripts/battle_state_machine.gd
```

在 `resolve_intent()` 中：

1. 先完成命中判定；
2. 再结算伤害 / 削势；
3. 记录是否本次使目标势归 0；
4. 最后调用 `apply_card_movement()`。

伪代码：

```gdscript
var target_broken_this_hit := false

# 削势时
if before_break > 0 and target.momentum == 0:
	target_broken_this_hit = true
	target.queue_broken_state()
	actor.queue_combo_window()

# 伤害 / 削势全部结算后
var movement_lines := apply_card_movement(card, actor, target, range_result, target_broken_this_hit)
lines.append_array(movement_lines)
```

注意：

```text
miss_range / miss_facing 不触发 on_hit 位移。
always 位移可以在 guard / momentum 牌上触发。
```

因此 guard 牌不要过早 return，或在 return 前也要检查 `move_condition == "always"`。

---

## 15. 首批推荐落地卡牌

本轮不要一次做 20 张，优先落地 12 张：枪手 6 张，刀客 6 张。

---

# 15.1 枪手 6 张

## 1. spear_mid_thrust：中平直刺

| 字段 | 值 |
|---|---|
| role | damage |
| range | 2-3 |
| cost | 2 |
| damage | 5 |
| break_momentum | 2 |
| weapon_style | 枪 |
| requires_facing | true |
| move_condition | none |

说明：标准输出牌，无位移，作为枪手基准。

---

## 2. spear_line_press：拦枪压线

| 字段 | 值 |
|---|---|
| role | momentum |
| range | 2-3 |
| cost | 2 |
| damage | 2 |
| break_momentum | 4 |
| target_push_after | 1 |
| move_condition | on_hit |
| tags | 长兵, 破势, 控线 |

说明：枪手核心控距牌，命中后击退敌人。

---

## 3. spear_retreat_sting：退枪留锋

| 字段 | 值 |
|---|---|
| role | damage |
| range | 1-2 |
| cost | 2 |
| damage | 4 |
| break_momentum | 1 |
| self_move_after | -1 |
| move_condition | on_hit |
| tags | 长兵, 后撤, 脱身 |

说明：被刀客贴近时的脱身牌。

---

## 4. spear_guard_horse：架枪拒马

| 字段 | 值 |
|---|---|
| role | guard |
| range | 0-8 |
| cost | 2 |
| guard | 7 |
| target_push_after | 1 |
| move_condition | always |
| requires_facing | false |
| tags | 架势, 拒止 |

说明：防守同时拒止，将敌人推开一步。

---

## 5. spear_step_thrust：顺步送枪

| 字段 | 值 |
|---|---|
| role | damage |
| range | 3 |
| cost | 2 |
| damage | 6 |
| break_momentum | 1 |
| self_move_after | 1 |
| move_condition | on_hit |
| tags | 长兵, 进身 |

说明：追击被击退后的敌人，避免枪手打完脱节。

---

## 6. spear_focus：稳架蓄枪

| 字段 | 值 |
|---|---|
| role | momentum |
| range | 0-8 |
| cost | 0 |
| gain_momentum | 3 |
| guard | 2 |
| self_move_after | -1 |
| move_condition | always |
| requires_facing | false |
| tags | 聚势, 架势 |

说明：聚势并后撤，重新建立枪手 2-3 格节奏。

---

# 15.2 刀客 6 张

## 1. blade_front_cut：迎门斩

| 字段 | 值 |
|---|---|
| role | damage |
| range | 1-2 |
| cost | 2 |
| damage | 6 |
| break_momentum | 1 |
| weapon_style | 刀 |
| requires_facing | true |
| move_condition | none |

说明：刀客标准输出牌。

---

## 2. blade_press_break：压刀破架

| 字段 | 值 |
|---|---|
| role | momentum |
| range | 1 |
| cost | 2 |
| damage | 2 |
| break_momentum | 4 |
| target_pull_after | 1 |
| move_condition | on_hit |
| tags | 短兵, 破势, 贴身 |

说明：命中后拉近敌人，防止枪手脱离。

---

## 3. blade_chase_cut：赶步追斩

| 字段 | 值 |
|---|---|
| role | damage |
| range | 2-3 |
| cost | 2 |
| damage | 5 |
| break_momentum | 1 |
| self_move_after | 1 |
| move_condition | on_hit |
| tags | 短兵, 追身 |

说明：刀客被击退后重新追近。

---

## 4. blade_hook_pull：挂刀带步

| 字段 | 值 |
|---|---|
| role | damage |
| range | 1-2 |
| cost | 2 |
| damage | 4 |
| break_momentum | 2 |
| target_pull_after | 1 |
| move_condition | on_hit |
| tags | 短兵, 拉扯 |

说明：拉近敌人，让刀客持续贴压。

---

## 5. blade_body_press：贴身撞刀

| 字段 | 值 |
|---|---|
| role | damage |
| range | 0-1 |
| cost | 2 |
| damage | 4 |
| break_momentum | 3 |
| self_move_after | 1 |
| move_condition | on_hit |
| tags | 短兵, 贴身, 破势 |

说明：进入 distance = 0 的顶撞缠斗。

---

## 6. blade_breathe：收刀换气

| 字段 | 值 |
|---|---|
| role | momentum |
| range | 0-8 |
| cost | 0 |
| gain_momentum | 3 |
| guard | 2 |
| self_move_after | 1 |
| move_condition | always |
| requires_facing | false |
| tags | 聚势, 短兵 |

说明：恢复节奏，同时保持贴近压力。

---

## 16. JSON 配置样例

如果后续把卡牌从代码内配置迁移到 JSON，可采用以下结构。

### 16.1 枪手示例：拦枪压线

```json
{
  "id": "spear_line_press",
  "name": "拦枪压线",
  "type": "momentum",
  "weapon_style": "spear",
  "cost": 2,
  "damage": 2,
  "break_momentum": 4,
  "guard": 0,
  "gain_momentum": 0,
  "range_min": 2,
  "range_max": 3,
  "requires_facing": true,
  "tags": ["长兵", "破势", "控线"],
  "movement": {
    "target_push_after": 1,
    "move_condition": "on_hit"
  },
  "description": "枪杆压住来路，命中后将敌人击退一格。"
}
```

### 16.2 刀客示例：挂刀带步

```json
{
  "id": "blade_hook_pull",
  "name": "挂刀带步",
  "type": "damage",
  "weapon_style": "blade",
  "cost": 2,
  "damage": 4,
  "break_momentum": 2,
  "guard": 0,
  "gain_momentum": 0,
  "range_min": 1,
  "range_max": 2,
  "requires_facing": true,
  "tags": ["短兵", "拉扯"],
  "movement": {
    "target_pull_after": 1,
    "move_condition": "on_hit"
  },
  "description": "刀锋挂带，命中后将敌人拉近一格。"
}
```

---

## 17. 预览面板需要新增内容

### 修改文件

```text
scripts/battle_controller_visual_ui.gd
scripts/battle_controller_visual_cached_ui.gd
scripts/visual/battle_hud_view.gd
```

预览面板需要显示：

```text
当前站位：我方 3，敌方 5
出招距离：2
命中结果：正中
预计效果：伤害 5，削势 2
位移结果：敌方 5 → 6
结算后距离：3
```

建议预览上下文新增：

```gdscript
"movement_text": movement_text,
"before_actor_position": before_actor_position,
"before_target_position": before_target_position,
"after_actor_position": after_actor_position,
"after_target_position": after_target_position,
"distance_after_movement": distance_after_movement
```

---

## 18. 敌方 AI 调整建议

### 修改文件

```text
scripts/enemy_ai.gd
```

AI 评分应考虑位移结果。

## 18.1 枪手偏好

| 条件 | 加分 |
|---|---:|
| 攻击前距离 2-3 | +6 |
| 命中后距离仍为 2-3 | +4 |
| 击退后敌人距离变远 | +2 |
| 自身被迫进入 0-1 | -6 |

## 18.2 刀客偏好

| 条件 | 加分 |
|---|---:|
| 攻击前距离 1-2 | +6 |
| 命中后距离 0-1 | +4 |
| 拉近敌人 | +3 |
| 自身前进追近 | +3 |
| 距离变成 3+ | -5 |

当前 Demo 可以先不做 AI 位移预判，只要招式结算支持位移即可。

---

## 19. 工程实现顺序

## Step 1：CardData 增字段

修改：

```text
scripts/card_data.gd
```

验收：

```text
[ ] self_move_after 存在
[ ] target_push_after 存在
[ ] target_pull_after 存在
[ ] move_condition 存在
[ ] duplicate_card 不丢字段
[ ] short_summary 可显示位移
```

---

## Step 2：_ready_card 支持新字段

修改：

```text
scripts/battle_controller_core.gd
```

验收：

```text
[ ] 代码内卡牌可以配置位移
[ ] 旧卡牌不传新字段也不报错
```

---

## Step 3：BattleStateMachine 接入位移结算

修改：

```text
scripts/battle_state_machine.gd
```

验收：

```text
[ ] hit 后可触发 on_hit 位移
[ ] guard / momentum 牌可触发 always 位移
[ ] graze 默认不触发 on_hit
[ ] miss_range / miss_facing 不触发 on_hit
[ ] 位移后 current_distance 刷新
[ ] 位移后双方自动相向
```

---

## Step 4：替换首批 12 张卡

修改：

```text
scripts/battle_controller_core.gd
```

验收：

```text
[ ] 枪手核心攻击区为 2-3
[ ] 刀客核心攻击区为 1-2
[ ] 枪手有击退 / 后撤 / 进身
[ ] 刀客有拉近 / 追身 / 贴身
```

---

## Step 5：预览面板显示位移结果

修改：

```text
scripts/battle_controller_visual_ui.gd
scripts/battle_controller_visual_cached_ui.gd
scripts/visual/battle_hud_view.gd
```

验收：

```text
[ ] 预览显示位移前位置
[ ] 预览显示位移后位置
[ ] 预览显示结算后距离
[ ] 预览显示“击退 / 拉近 / 前进 / 后退”文案
```

---

## 20. Smoke Test 清单

```text
[ ] 枪手距离 2 使用拦枪压线，命中后敌人被击退 1 格
[ ] 枪手距离 1 使用退枪留锋，命中后自己后退 1 格
[ ] 枪手使用稳架蓄枪，即使不攻击也后退 1 格
[ ] 刀客距离 2 使用挂刀带步，命中后敌人被拉近 1 格
[ ] 刀客距离 3 使用赶步追斩，命中后自己前进 1 格
[ ] 同格时击退按攻击者 facing 方向处理
[ ] 边界 0 / 8 不会越界
[ ] 位移后 current_distance 正确刷新
[ ] 位移后双方自动朝向敌人
[ ] 先手击退可以让后手攻击失距
```

---

## 21. 本版明确不做

| 复杂点 | 本版处理 |
|---|---|
| 交换位置 | 暂缓 |
| 击退 2 格 | 暂缓，统一 1 格 |
| 多段攻击中途位移 | 暂缓 |
| 位移造成撞墙伤害 | 暂缓 |
| 位移造成背向 | 暂缓 |
| 位移被格挡抵消 | 暂缓 |
| 反制敌方位移 | 暂缓 |
| 一牌多个位移 | 暂缓 |
| AI 完整位移预判 | 暂缓 |

---

## 22. 可直接给 Codex 的任务提示词

```text
Repo: chengquansen-comments/canghaidiming
Branch: feature/symmetry-gameplay

请实现 v0.3.2 招式命中后位移系统。

前提：当前项目已实现玩家先选位置/朝向再选招式；Fighter 已有 position/facing/qinggong；CardData 已有 weapon_style/requires_facing；BattleStateMachine 已有 hit/graze/miss_range/miss_facing 判定。

本次任务：
1. CardData 增加 self_move_after、target_push_after、target_pull_after、move_condition 字段。
2. CardData._init、duplicate_card、short_summary 同步这些字段。
3. battle_controller_core.gd 的 _ready_card 支持这些新字段。
4. BattleStateMachine 增加 direction_toward、apply_self_move、apply_push_target、apply_pull_target、face_target、apply_card_movement。
5. resolve_intent 在伤害/削势后调用 apply_card_movement。
6. on_hit 只在 range_result == RANGE_HIT 时触发；always 无需命中。
7. 位移后刷新 current_distance，并让双方自动相向。
8. 替换首批 12 张卡：枪手 6 张、刀客 6 张。枪手核心距离 2-3，刀客核心距离 1-2。
9. 预览面板增加位移前后位置、结算后距离、位移文案。
10. 不做交换位置、击退 2 格、撞墙伤害、多段攻击中途位移、位移造成背向。

优先保证 Godot 项目编译通过和 Web demo 可运行。
```
