# 《沧海嘀鸣》v0.3.1 对称战斗玩法修改执行 List

> 目标分支：`feature/symmetry-gameplay`  
> 目标仓库：`chengquansen-comments/canghaidiming`  
> 文档目的：把当前战斗流程从“招式自带行动/位移”改为“玩家先选位置/朝向，再选招式，最后确认出招”的可执行改造清单。

---

## 1. 本次改造目标

### 1.1 新核心流程

```text
回合开始
→ 敌方生成意图
→ 玩家抽牌
→ 玩家选择位置
→ 玩家选择朝向
→ 玩家选择招式
→ 预览命中 / 擦中 / 失距 / 背向
→ 确认出招
→ 双方结算
→ 回合结束
```

### 1.2 核心设计变化

旧规则：

```text
招式牌 = 位移 + 攻击 / 防御 / 破势
```

新规则：

```text
行动位置 = 玩家额外选择
招式牌 = 单纯表达攻击、防御、破势、聚势、反制等战斗效果
```

玩家每回合先基于轻功选择落点，再选择朝向和招式。移动不再默认绑定在招式牌上。

---

## 2. 当前不要做的内容

本轮只改战斗单局核心闭环，不做以下内容：

| 暂缓内容 | 原因 |
|---|---|
| 完整大地图 | 当前聚焦战斗验证 |
| 完整剧情系统 | 与本轮单局无关 |
| 装备系统 | 会扩大变量 |
| 二维格子 | 当前一维九格足够验证 |
| 复杂绕背奖励 | 先只做朝向有效/无效 |
| 多敌人战斗 | 先稳定 1v1 |
| 完整虚招系统 | 下一阶段再接 |
| 商业化系统 | 不属于当前 demo 范围 |

---

## 3. 项目结构判断

当前项目入口链路：

```text
project.godot
→ scenes/Main.tscn
→ scripts/main_runtime_router.gd
→ scenes/MainWeb.tscn / scenes/MainDesktop.tscn
→ scenes/MainVisual.tscn
→ scripts/battle_controller_visual_responsive_ui.gd
```

实际战斗视觉控制继承链：

```text
battle_controller_visual_responsive_ui.gd
→ battle_controller_visual_cached_ui.gd
→ battle_controller_visual_ui.gd
→ battle_controller_demo_visual.gd
→ battle_controller_core.gd
```

本轮主要修改：

```text
scripts/fighter_data.gd
scripts/fighter.gd
scripts/card_data.gd
scripts/battle_state_machine.gd
scripts/battle_controller_core.gd
scripts/battle_controller_demo_visual.gd
scripts/battle_controller_visual_ui.gd
scripts/battle_controller_visual_cached_ui.gd
scripts/visual/battle_stage_view.gd
scripts/visual/battle_hud_view.gd
scripts/enemy_ai.gd
```

本轮不要修改：

```text
project.godot
scenes/Main.tscn
scripts/main_runtime_router.gd
scripts/web_runtime_launcher.gd
actor animation runtime 相关脚本
Web smoke battle flag 相关逻辑
```

---

## 4. 数据层修改

## 4.1 FighterData 增加轻功、初始位置、初始朝向

### 修改文件

```text
scripts/fighter_data.gd
```

### 新增字段

```gdscript
var qinggong: int
var starting_position: int
var starting_facing: String
```

### 默认建议

玩家默认：

```gdscript
qinggong = 1
starting_position = 3
starting_facing = "right"
```

敌人默认：

```gdscript
qinggong = 1
starting_position = 5
starting_facing = "left"
```

### `_init()` 增加参数

```gdscript
p_qinggong: int = 1,
p_starting_position: int = 3,
p_starting_facing: String = "right"
```

### 初始化赋值

```gdscript
qinggong = maxi(p_qinggong, 0)
starting_position = clampi(p_starting_position, 0, 8)
starting_facing = p_starting_facing
```

---

## 4.2 Fighter 增加运行时位置、朝向、轻功

### 修改文件

```text
scripts/fighter.gd
```

### 新增字段

```gdscript
var position: int
var facing: String
var qinggong: int
```

### 在 `reset_for_battle()` 初始化

```gdscript
position = data.starting_position
facing = data.starting_facing
qinggong = data.qinggong
```

### 验收标准

```text
[ ] 玩家拥有 position / facing / qinggong
[ ] 敌人拥有 position / facing / qinggong
[ ] reset_for_battle 后位置、朝向、轻功恢复默认
[ ] 不再只靠 current_distance 表示双方关系
```

---

## 5. 卡牌数据修改

## 5.1 CardData 增加兵器类型与朝向要求

### 修改文件

```text
scripts/card_data.gd
```

### 新增字段

```gdscript
var weapon_style: String
var requires_facing: bool
```

### 默认值

```gdscript
weapon_style = "common"
requires_facing = true
```

### `_init()` 增加参数

```gdscript
p_weapon_style: String = "common",
p_requires_facing: bool = true
```

### duplicate_card 必须同步新增字段

确保复制卡牌时不会丢失：

```gdscript
weapon_style
requires_facing
```

### short_summary 建议增加显示

```gdscript
parts.append("兵器 %s" % weapon_style)
if requires_facing:
	parts.append("需正向")
```

### 保留字段

```gdscript
min_distance
max_distance
```

这两个字段继续作为招式攻击距离，不再表达移动能力。

---

## 6. 状态机修改

## 6.1 current_distance 降级为派生缓存

### 修改文件

```text
scripts/battle_state_machine.gd
```

当前不要立刻删除 `current_distance`，因为 UI 仍大量依赖它。先改为由双方位置计算出来的派生值。

### 新增函数

```gdscript
func update_distance_from_positions(player: Fighter, enemy: Fighter) -> void:
	current_distance = absi(player.position - enemy.position)
```

---

## 6.2 修改 begin_battle

如暂时拿不到 player/enemy，则至少把距离限制从 1~3 改为 0~8：

```gdscript
current_distance = clampi(initial_distance, 0, 8)
```

更理想做法是在战斗开始时直接基于双方位置计算：

```gdscript
current_distance = absi(player.position - enemy.position)
```

---

## 6.3 增加朝向判断

```gdscript
func is_facing_target(actor: Fighter, target: Fighter) -> bool:
	if actor.position == target.position:
		return true
	if target.position > actor.position:
		return actor.facing == "right"
	return actor.facing == "left"
```

---

## 6.4 增加距离 + 朝向判定

```gdscript
func evaluate_card_range(card: CardData, actor: Fighter, target: Fighter) -> String:
	var distance := absi(actor.position - target.position)
	var facing_ok := is_facing_target(actor, target)

	if card.requires_facing and not facing_ok and not card.has_tag("回身"):
		return "miss_facing"

	if distance >= card.min_distance and distance <= card.max_distance:
		return "hit"

	if distance == card.min_distance - 1 or distance == card.max_distance + 1:
		return "graze"

	return "miss_range"
```

### 返回值定义

| 返回值 | 含义 |
|---|---|
| `hit` | 正中，完整结算 |
| `graze` | 擦中，伤害减半，削势 -1 |
| `miss_range` | 失距，招式失败 |
| `miss_facing` | 背向，普通招式失败 |

---

## 6.5 修改 resolve_intent

旧逻辑是只基于：

```gdscript
card.is_usable_at(current_distance)
```

新逻辑改为：

```gdscript
var range_result := evaluate_card_range(card, actor, target)
```

### 结算规则

| 结果 | 伤害 | 削势 | 是否消耗势 |
|---|---:|---:|---|
| hit | 100% | 100% | 是 |
| graze | 50% | break_momentum - 1，最低 0 | 是 |
| miss_range | 0 | 0 | 是 |
| miss_facing | 0 | 0 | 是 |

### 文案建议

```text
中平直刺正中目标，造成 5 伤害，削势 2。
中平直刺擦中目标，造成 2 伤害，削势 1。
中平直刺因距离不合而落空。
中平直刺因背向目标而无法命中。
```

---

## 7. 玩家选位流程修改

## 7.1 Core 增加草稿字段

### 修改文件

```text
scripts/battle_controller_core.gd
```

新增：

```gdscript
var draft_player_position: int = -1
var draft_player_facing: String = ""
var position_selected := false
```

---

## 7.2 增加可移动格计算

```gdscript
func get_available_positions(actor: Fighter) -> Array[int]:
	var result: Array[int] = []
	var min_pos := max(0, actor.position - actor.qinggong)
	var max_pos := min(8, actor.position + actor.qinggong)
	for i in range(min_pos, max_pos + 1):
		result.append(i)
	return result
```

玩家初始轻功为 1 时：

```text
可选：当前位置 -1、当前位置、当前位置 +1
```

轻功为 2 时：

```text
可选：当前位置 -2 到 当前位置 +2
```

---

## 7.3 增加朝向辅助函数

```gdscript
func face_target(actor_position: int, target_position: int, current_facing: String) -> String:
	if target_position > actor_position:
		return "right"
	if target_position < actor_position:
		return "left"
	return current_facing
```

```gdscript
func toggle_facing(facing: String) -> String:
	return "left" if facing == "right" else "right"
```

---

## 7.4 增加选择位置逻辑

```gdscript
func _on_stage_slot_pressed(slot: int) -> void:
	if player == null or enemy == null:
		return
	if not get_available_positions(player).has(slot):
		return

	if slot == player.position:
		if position_selected and draft_player_position == slot:
			draft_player_facing = toggle_facing(draft_player_facing)
		else:
			draft_player_position = slot
			draft_player_facing = player.facing
			position_selected = true
	else:
		draft_player_position = slot
		draft_player_facing = face_target(slot, enemy.position, player.facing)
		position_selected = true

	_refresh_ui()
```

### 操作规则

| 操作 | 结果 |
|---|---|
| 点击其他可移动格 | 选择落点，默认朝向敌人 |
| 点击当前位置一次 | 原地 |
| 再次点击当前位置 | 切换朝向 |
| 不选位置直接确认 | 默认原地和当前朝向 |

---

## 7.5 确认出招前补默认位置

```gdscript
if not position_selected:
	draft_player_position = player.position
	draft_player_facing = player.facing
	position_selected = true
```

然后写入真实状态：

```gdscript
player.position = draft_player_position
player.facing = draft_player_facing
state_machine.update_distance_from_positions(player, enemy)
```

---

## 8. 九格 UI 修改

## 8.1 格子从展示改为可点击

### 修改文件

```text
scripts/battle_controller_demo_visual.gd
scripts/battle_controller_visual_ui.gd
scripts/battle_controller_visual_cached_ui.gd
scripts/visual/battle_stage_view.gd
```

当前格子如果设置了：

```gdscript
cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

需要改为：

```gdscript
cell.mouse_filter = Control.MOUSE_FILTER_STOP
```

绑定点击事件：

```gdscript
cell.gui_input.connect(_on_stage_slot_gui_input.bind(i))
```

新增：

```gdscript
func _on_stage_slot_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_stage_slot_pressed(slot)
```

---

## 8.2 格子显示状态

| 状态 | 显示建议 |
|---|---|
| 玩家当前位置 | 蓝色边框 |
| 敌人当前位置 | 红色边框 |
| 可移动格 | 淡蓝底 |
| 已选落点 | 金色边框 |
| 当前朝向 | 左/右箭头 |
| 招式影响范围 | 沿用现有 range 高亮 |

---

## 8.3 修改 current_grid_positions

旧逻辑可能是通过 `current_distance` 和固定锚点反推双方位置。新逻辑应直接读取双方真实位置。

```gdscript
func _current_grid_positions() -> Dictionary:
	var player_slot := player.position if player != null else 3
	var enemy_slot := enemy.position if enemy != null else 5

	if position_selected:
		player_slot = draft_player_position

	return {
		"player": player_slot,
		"enemy": enemy_slot
	}
```

---

## 9. 预览系统修改

### 修改文件

```text
scripts/battle_controller_visual_ui.gd
scripts/battle_controller_visual_cached_ui.gd
scripts/visual/battle_hud_view.gd
```

## 9.1 预览上下文新增字段

```gdscript
{
	"player_position": preview_player_position,
	"enemy_position": enemy.position,
	"player_facing": preview_player_facing,
	"distance": abs(preview_player_position - enemy.position),
	"range_result": range_result,
	"final_damage": final_damage,
	"final_break_momentum": final_break_momentum,
	"posture_after_cost": player.momentum - card.momentum_cost
}
```

## 9.2 预览面板文案

```text
站位：四位 → 五位
朝向：向右
距离：2
命中：正中 / 擦中 / 失距 / 背向
预计伤害：X
预计削势：X
出招后势：X / max
```

## 9.3 确认按钮规则

| 条件 | 是否允许确认 |
|---|---|
| 未选牌 | 不允许 |
| 势不足 | 不允许 |
| 未选位置 | 允许，默认原地 |
| 背向 | 允许，但预览失败 |
| 失距 | 允许，但预览失败 |

不要禁止玩家犯错。失距、背向都是玩法判断的一部分。

---

## 10. 枪手基础招式牌

## 10.1 枪手定位

```text
中远距离控制，优势距离 3~5，被贴身后难受。
```

## 10.2 建议替换当前 spearman deck

| id | 名称 | role | 距离 | cost | damage | break | guard | tags |
|---|---|---|---:|---:|---:|---:|---:|---|
| spear_mid_thrust | 中平直刺 | damage | 3-5 | 2 | 5 | 2 | 0 | 长兵,正面,破势 |
| spear_line_press | 拦枪压线 | momentum | 2-5 | 2 | 2 | 4 | 0 | 长兵,拒止,破势 |
| spear_probe | 枪花虚点 | momentum | 3-6 | 1 | 1 | 1 | 0 | 试探,虚招素材 |
| spear_return | 回马枪 | damage | 2-4 | 3 | 7 | 2 | 0 | 长兵,回身,险招 |
| spear_guard | 架枪拒马 | guard | 0-8 | 2 | 0 | 0 | 7 | 架势,拒止 |
| spear_double | 逼步连刺 | damage | 3-4 | 3 | 6 | 2 | 0 | 长兵,连击 |
| spear_drag | 拖枪卸力 | guard | 0-8 | 2 | 0 | 0 | 5 | 反制,架势 |
| spear_focus | 稳架蓄枪 | momentum | 0-8 | 0 | 0 | 0 | 0 | 聚势,长兵 |

## 10.3 本轮只实现的特殊规则

| 标签 | 本轮效果 |
|---|---|
| 回身 | 背向也可命中 |
| 架势 | 作为 guard 牌展示 |
| 聚势 | 恢复自身势 |
| 拒止 / 反制 / 连击 / 虚招素材 | 先只展示，不接复杂逻辑 |

---

## 11. 刀客基础招式牌

## 11.1 刀客定位

```text
近身压迫，优势距离 0~2，依赖轻功贴身。
```

## 11.2 建议替换当前 blademaster deck

| id | 名称 | role | 距离 | cost | damage | break | guard | tags |
|---|---|---|---:|---:|---:|---:|---:|---|
| blade_front_cut | 迎门斩 | damage | 1-2 | 2 | 6 | 1 | 0 | 短兵,正面 |
| blade_break_guard | 压刀破架 | momentum | 0-2 | 2 | 2 | 4 | 0 | 短兵,破势 |
| blade_wrist_cut | 斜身斩腕 | damage | 1-2 | 3 | 8 | 3 | 0 | 短兵,险招,破势 |
| blade_body_press | 贴身撞刀 | damage | 0-1 | 2 | 4 | 3 | 0 | 短兵,贴身 |
| blade_guard | 横刀守门 | guard | 0-8 | 1 | 0 | 0 | 6 | 架势,短兵 |
| blade_counter | 退步拖刀 | damage | 1-3 | 2 | 5 | 2 | 0 | 反制,回身 |
| blade_back_cut | 翻身背斩 | damage | 0-1 | 3 | 7 | 2 | 0 | 回身,错身 |
| blade_breathe | 收刀换气 | momentum | 0-8 | 0 | 0 | 0 | 0 | 聚势,短兵 |

## 11.3 本轮只实现的特殊规则

| 标签 | 本轮效果 |
|---|---|
| 回身 | 背向也可命中 |
| 聚势 | 恢复自身势 |
| 架势 | 作为 guard 牌展示 |
| 反制 / 错身 / 贴身 | 先只展示，不接复杂逻辑 |

---

## 12. 敌方 AI 修改

### 修改文件

```text
scripts/enemy_ai.gd
```

## 12.1 敌方意图新增位置选择

敌方意图输出结构建议增加：

```gdscript
{
	"target_position": int,
	"target_facing": String,
	"card": CardData
}
```

## 12.2 AI 选位规则

遍历敌人轻功范围内所有可选格：

```text
enemy.position - enemy.qinggong 到 enemy.position + enemy.qinggong
```

对每个候选格计算到玩家的距离，并根据候选卡牌范围评分。

### 评分建议

| 条件 | 分数 |
|---|---:|
| 距离在卡牌范围内 | +5 |
| 距离差 1 | +2 |
| 距离完全不合 | -3 |
| 自己是枪手且距离 3~5 | +3 |
| 自己是刀客且距离 0~2 | +3 |
| 玩家破势且可命中 | +5 |
| 自己势低于 2 | 优先 guard / momentum |

## 12.3 AI 朝向

```gdscript
enemy.facing = face_target(enemy.position, player.position, enemy.facing)
```

## 12.4 意图气泡文案

```text
移至六位｜向左｜中平直刺｜伤害5｜削势2
```

---

## 13. 新结算顺序

```text
1. 双方先确定位置与朝向
2. 更新 current_distance
3. 根据先机 / 崩势 / 武境决定出招顺序
4. 每个 intent 单独检查：
   - 是否有势
   - 是否面向
   - 是否在距离内
   - 正中 / 擦中 / 失距 / 背向
5. 结算伤害、削势、格挡、聚势
6. 判断崩势
7. 回合结束
```

重要限制：

```text
位置移动应在出招前统一落位。
不要做“先出手者先移动，后出手者再移动”。
```

否则会引入同步博弈和时序歧义，影响当前 demo 稳定性。

---

## 14. UI 优先级

## 14.1 P0 必须做

| 项目 | 内容 |
|---|---|
| 九格可点击 | 玩家能选择位置 |
| 可移动范围高亮 | 根据轻功显示 |
| 当前选中格 | 金色或明显边框 |
| 朝向显示 | left / right 箭头 |
| 预览命中 | 正中 / 擦中 / 失距 / 背向 |
| 确认出招 | 写入位置、朝向、卡牌 |

## 14.2 P1 再做

| 项目 | 内容 |
|---|---|
| 敌方目标落点预览 | 高识机时显示 |
| 敌方朝向箭头 | 可视化 |
| 背向提示 | 当前背向，普通招式无法命中 |
| 轻功数值显示 | HUD 显示轻功 1 |

---

## 15. Codex 推荐执行顺序

## Step 1：数据结构补字段

修改：

```text
fighter_data.gd
fighter.gd
card_data.gd
```

验收：

```text
[ ] 项目能启动
[ ] 角色有 position / facing / qinggong
[ ] 卡牌有 requires_facing / weapon_style
```

---

## Step 2：状态机支持位置结算

修改：

```text
battle_state_machine.gd
```

验收：

```text
[ ] distance = abs(player.position - enemy.position)
[ ] resolve_intent 不再只依赖 current_distance
[ ] hit / graze / miss_range / miss_facing 可区分
```

---

## Step 3：玩家可选位置

修改：

```text
battle_controller_core.gd
battle_controller_demo_visual.gd
battle_controller_visual_ui.gd
```

验收：

```text
[ ] 点击九格可以选择位置
[ ] 轻功 1 时只能选左 1 / 原地 / 右 1
[ ] 再次点击当前位置可以转向
[ ] 确认后角色位置变化
```

---

## Step 4：预览面板更新

修改：

```text
battle_controller_visual_ui.gd
battle_controller_visual_cached_ui.gd
scripts/visual/battle_hud_view.gd
```

验收：

```text
[ ] 预览显示站位
[ ] 预览显示朝向
[ ] 预览显示距离
[ ] 预览显示命中结果
[ ] 预览显示预计伤害
[ ] 预览显示预计削势
[ ] 预览显示出招后势
```

---

## Step 5：替换枪手 / 刀客基础牌

修改：

```text
battle_controller_core.gd
```

验收：

```text
[ ] 枪手牌组偏 3~5 距离
[ ] 刀客牌组偏 0~2 距离
[ ] 回身牌能背向命中
[ ] 普通牌背向失败
```

---

## Step 6：敌方 AI 选择位置和招式

修改：

```text
enemy_ai.gd
```

验收：

```text
[ ] 敌人会移动到适合自己招式的位置
[ ] 枪手倾向保持 3~5
[ ] 刀客倾向贴近 0~2
[ ] 敌方意图包含目标位置和招式
```

---

## Step 7：整体 smoke test

测试路径：

```text
Web 启动
→ 开始战斗
→ 选择枪手
→ 点击格子
→ 选牌
→ 确认出招
```

验收清单：

```text
[ ] 不选位置时默认原地
[ ] 点击当前位置第二次会转向
[ ] 背向普通攻击失败
[ ] 回身牌背向可命中
[ ] 轻功 1 只能移动 1 格
[ ] 枪手中远距离强
[ ] 刀客近身强
[ ] 势消耗正常
[ ] 崩势仍可触发
[ ] Web 不报错
```

---

## 16. 可直接给 Codex 的执行提示词

```text
Repo: chengquansen-comments/canghaidiming
Branch: feature/symmetry-gameplay

请在现有 Godot 4.6 项目中修改战斗单局流程：行动不再和招式绑定，玩家每回合先选择位置和朝向，再选择招式牌，最后确认出招。

不要重写项目结构，不要改 project.godot、Main.tscn、main_runtime_router.gd、web_runtime_launcher.gd。当前实际战斗入口是 scenes/MainVisual.tscn，脚本继承链为 battle_controller_visual_responsive_ui.gd → battle_controller_visual_cached_ui.gd → battle_controller_visual_ui.gd → battle_controller_demo_visual.gd → battle_controller_core.gd。

执行要求：
1. FighterData 增加 qinggong、starting_position、starting_facing。
2. Fighter 增加 position、facing、qinggong，并在 reset_for_battle 初始化。
3. CardData 增加 weapon_style、requires_facing，保留 min_distance/max_distance 作为招式距离。
4. BattleStateMachine 不再用 current_distance 作为唯一位置来源，新增 update_distance_from_positions(player, enemy)、is_facing_target、evaluate_card_range。
5. resolve_intent 支持 hit/graze/miss_range/miss_facing。hit 完整结算；graze 伤害减半、削势 -1；miss 不造成效果但仍消耗势。
6. 九格 stage grid 改为可点击。根据 player.qinggong 高亮可选格。玩家初始轻功为 1，可选左 1、原地、右 1。
7. 点击其他格：选择移动目标，并默认朝向敌人。点击当前位置一次：原地。再次点击当前位置：切换朝向。
8. 不选位置直接确认时，默认原地和当前朝向。
9. 预览面板显示站位、朝向、距离、命中结果、预计伤害、预计削势、出招后势。
10. 替换枪手和刀客基础牌：枪手偏 3-5 距离，刀客偏 0-2 距离。实现“回身”标签：背向也可命中。
11. enemy_ai.gd 增加敌方目标位置选择。敌人根据自身轻功、候选卡距离、职业偏好选择 target_position 和 target_facing。
12. 保持 Web demo 可启动，不破坏 smoke_battle 自动入口。

优先保证编译通过和可玩闭环，不要一次加入复杂绕背奖励、二维移动、多敌人或完整虚招系统。
```

---

## 17. 下一刀建议

下一步建议补一份：

```text
《v0.3.1 对称战斗测试用例》
```

重点按枪手 / 刀客列 12 条测试场景，覆盖：

```text
轻功移动
原地默认
再次点击转向
背向失败
回身命中
擦中
失距
破势
枪手远距优势
刀客近身优势
敌方 AI 选位
Web smoke test
```
