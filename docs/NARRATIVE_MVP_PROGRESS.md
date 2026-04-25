# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已恢复；剧情 MVP 已切到安全版 controller；安全版已完成“压缩序章 + 六列行军图 + 地图点击 + 三变量成长 + 战斗占位 + 场景信息分层 + 结局闭环 + UI 分层 + 操作区滚动修复 + 真实战斗 V1 单向跳转 + MainVisual 叙事上下文诊断 + Battle Result 诊断”。  
> 核心原则：继续走安全线，不恢复旧 `scripts/narrative/*` 复杂链路；不使用 `HScrollContainer`；不直接改战斗规则；不破坏现有战斗测试入口；不重构 `web_shell.html`。

---

## 1. 当前目标

叙事 MVP 当前验证：

```text
玩家能在 Web 稳定环境里走完：
倭寇袭村
→ 师父救命
→ 十年后出山
→ 军令巡海
→ 海边伏击
→ 明制火器
→ 失械案押运官
→ 破船 Boss
→ 军门压案
→ 结局
```

真实战斗 V1 接入目标：

```text
剧情战斗节点点击“请求战斗”
→ 写入 encounter_id / source_node_id
→ 单向跳转 MainVisual.tscn
→ MainVisual 显示叙事上下文诊断
→ MainVisual 继续走现有角色选择入口
→ 战斗结算后 MainVisual 显示 Battle Result 诊断
```

当前仍不做：

```text
不自动回 NarrativeDemo
不自动写入剧情变量
不根据 encounter_id 自动换敌人
不绕过角色选择
不改战斗规则
```

---

## 2. 为什么切到安全线

此前复杂叙事链路出现 Web Parser 风险：

```text
Parser Error: Could not resolve class "NarrativeDemoController"
Parser Error: Identifier "HScrollContainer" not declared in the current scope
Parser Error: Expected variable name after "var"（class_name 变量名冲突）
```

已采取处理：

```text
临时隔离旧 scripts/narrative/*；
NarrativeDemo.tscn 切到 scripts/narrative_demo_safe_controller.gd；
先恢复 P0 Web 构建稳定；
在 safe controller 内逐步补回 MVP 体验；
修复 class_name 变量名冲突，改为 resource_class_name。
```

当前有效入口：

```text
scenes/NarrativeDemo.tscn
```

当前有效脚本：

```text
res://scripts/narrative_demo_safe_controller.gd
```

---

## 3. 当前已完成实装

### 3.1 Web 构建稳定修复

```text
[x] 新增 scripts/narrative/.gdignore，临时隔离旧复杂叙事链路
[x] NarrativeDemo.tscn 切到 parser-safe controller
[x] 不再依赖 HScrollContainer
[x] 不再依赖 NarrativeDemoController class_name 解析
[x] 修复 visual diagnostics 中 class_name 作为变量名导致的 Parser Error
[x] safe controller 已重新构建通过用户验收
```

对应提交：

```text
9228e5fc8dffc1a4de022521a84d11aca8a5b174  Ignore legacy narrative scripts for parser stability
90d405523f565a4d5ecf0ab36f247c9893634941  Use parser-safe narrative demo controller
c30ea1b5a6017ca956ecfbc512b074d484bf731c  Fix visual diagnostics parser variable name
```

---

### 3.2 安全版 NarrativeDemo Controller

文件：

```text
scripts/narrative_demo_safe_controller.gd
```

当前已支持：

```text
[x] 压缩序章可播放
[x] 序章中文显示正常
[x] 六列行军图文本展示：军令 / 初遇 / 疑点 / 压迫 / 破船 / 军门
[x] 六列行军图按钮布局：每列一个 VBoxContainer，外层 HBoxContainer
[x] 地图状态标记：▶ 当前 / ● 已走 / ◎ 可前往 / ○ 未开放
[x] 地图按钮可点击
[x] 点击 ◎ 可前往节点可推进
[x] 点击 ▶ 当前节点只提示，不推进
[x] 点击 ● 已走节点只提示，不推进
[x] 点击 ○ 未开放节点只提示，不推进
[x] 地图点击推进后刷新地图、节点、场景占位、choices、变量
[x] 地图点击推进后按节点类型给予默认收益
[x] 三变量保留：军功 / 清望 / 旧案线索
[x] 普通 choices 按各自 delta 修改三变量
[x] 场景信息分层展示：_format_scene_text 按句切分为 bullet
[x] 战斗桥接：请求战斗 / 视为胜利继续 / node_id / encounter_id
[x] 请求战斗已升级为 V1 单向跳转 MainVisual.tscn
[x] 结局与重开闭环
[x] 收益与推进入口已收口：_apply_choice_delta / _apply_default_map_reward / _advance_to_node
[x] UI 分层完成：map_buttons_box / combat_buttons_box / choices_box
[x] 下方操作区已改为 ScrollContainer，避免选项被挤出屏幕
[x] 上方视觉/正文区域已压缩高度，优先保障地图、战斗、叙事选项可见
[x] 最小图片显示：TextureRect + ResourceLoader.exists
[x] 视觉资源路径已切到 SVG 占位资源
[x] 视觉资源诊断：visual_debug_label 显示 path / exists / type / 状态
```

对应提交：

```text
72b93d5ecf54199f3c38dcd630a4a4e27155bcc3  Restore safe narrative map and art placeholders
4b440f5f4da75e08ec80ccda07b8942fa264a92e  Add safe narrative map jump buttons
b580c2e58e98ba7dc5779599f0dfce21a510dafe  Apply default rewards on safe map navigation
0d57c595a4938c179bd21a636b9ffd1b5500fa44  Unify safe narrative progression helpers
9376b50ded1842e29edbf06ccbec41c2c2d80b4c  Split safe narrative demo button sections
0fcc090ec98dcc6cc5fa1b9f8d8c4d6dc7efbcd7  Add safe narrative visual texture display
544de82a3988307d67899ad246b01500799065c7  Render safe narrative map buttons as columns
a07c872bd3ce0b9ba53f5cdb63591a23ee2d1535  Point safe narrative visuals to SVG placeholders
bec8e7efef48734b90608f9bf27ea2e38e9648d4  Format safe narrative scene hints into layers
6d1b8a5129c14a960d2614f69a609886a03339d2  Add safe narrative visual diagnostics
c30ea1b5a6017ca956ecfbc512b074d484bf731c  Fix visual diagnostics parser variable name
07a22f47c6f3bdb693cc082d0f86fd5f4e6d9c9f  Add one-way jump from narrative demo to battle scene
bfe1aeea444afc112740df0c27557557ffdb2693  Make narrative action area scrollable
```

---

### 3.3 Narrative Battle Context

新增文件：

```text
scripts/narrative_battle_context.gd
```

作用：

```text
作为 V1 单向跳转的轻量上下文，记录：
encounter_id
source_node_id
source_scene
return_after_battle=false
```

当前行为：

```text
NarrativeDemo 点击“请求战斗”
→ NarrativeBattleContext.set_request(encounter_id, source_node_id)
→ get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
```

---

### 3.4 MainVisual 叙事上下文诊断

新增 wrapper：

```text
scripts/battle_controller_visual_narrative_context.gd
```

实现方式：

```text
extends res://scripts/battle_controller_visual_break_preview.gd
_ready() 中先 super._ready()
如果 NarrativeBattleContext.has_request()，追加 NarrativeContextDebugLabel
只显示 encounter_id / source_node_id / return_after_battle
```

`scenes/MainVisual.tscn` 当前脚本已从：

```text
res://scripts/battle_controller_visual_break_preview.gd
```

改为：

```text
res://scripts/battle_controller_visual_narrative_context.gd
```

对应提交：

```text
97bffadb05c0ee994edb27597319e22c251ef645  Add narrative context wrapper for MainVisual
02301584ac14d56483a2f9c6d1c3052abd40dbea  Use narrative context wrapper for MainVisual
```

约束：

```text
不绕过角色选择
不根据 encounter_id 自动换敌人
不改战斗规则
只做传参诊断显示
```

---

### 3.5 MainVisual Battle Result 诊断

修改文件：

```text
scripts/battle_controller_visual_narrative_context.gd
```

新增能力：

```text
BattleResultDebugLabel
_process 中非侵入式检查 state_machine.phase / player.hp / enemy.hp
当 phase == BattleStateMachine.BattlePhase.RESULT 时显示 narrative_result
```

当前诊断规则：

```text
player.hp > 0 and enemy.hp <= 0 → narrative_result=win
player.hp <= 0 and enemy.hp > 0 → narrative_result=lose
player.hp <= 0 and enemy.hp <= 0 → narrative_result=draw
其他情况 → narrative_result=unknown
```

对应提交：

```text
a4777fd2b960aa63e366db88eba5b417b62f09ae  Add battle result diagnostics to narrative wrapper
```

约束：

```text
不改 BattleStateMachine
不改 resolve_intent
不改 finish_round
不自动回 NarrativeDemo
不写入叙事变量
不根据 encounter_id 自动换敌人
```

---

## 4. 当前 UI 修复说明

### 4.1 问题

```text
NarrativeDemo 下方 UI 显示不全，尤其是“叙事选择”区域容易被挤出屏幕。
```

### 4.2 修复方式

```text
将 map_buttons_box / combat_buttons_box / choices_box 统一放入 action_scroll: ScrollContainer
action_scroll 设置 SIZE_EXPAND_FILL
操作区高度保底 250
每次刷新时 action_scroll.scroll_vertical = 0
同时压缩：
- title / status / map / scene 字号与高度
- visual_frame 高度
- body_label 高度
```

---

## 5. 当前视觉显示规则

节点现在配置：

```text
visual_path
```

当前安全版规则：

```text
visual_path 为空 → 显示文本占位；诊断 path=空 / 状态=文本占位
ResourceLoader.exists(path) 为 false → 显示文本占位；诊断 exists=false
资源存在且是 Texture2D → TextureRect 显示图片；诊断 exists=true / type=Texture2D / 状态=已显示
资源存在但不是 Texture2D → 显示错误占位文本；诊断 exists=true / type=<class> / 状态=非 Texture2D
```

---

## 6. 当前收益与推进规则

### 6.1 普通选择按钮

```text
普通 choice 点击
→ _apply_choice_delta(choice)
→ _advance_to_node(node_index + 1, "")
→ _render()
```

choice delta 来自节点 choices：

```text
dg：军功变化
dq：清望变化
dc：旧案线索变化
```

### 6.2 地图点击按钮

```text
地图按钮点击
→ 当前节点：只提示，不推进
→ 已走节点：只提示，不推进
→ 未开放节点：只提示，不推进
→ 可前往节点：_apply_default_map_reward(target_index) → _advance_to_node(target_index, hint)
```

默认地图收益规则：

```text
普通战斗：军功 +1，旧案线索 +1
精英战斗：军功 +1，旧案线索 +1
Boss：军功 +2，旧案线索 +1
旧物：旧案线索 +2
结尾：清望 +1
事件：清望 +1
```

---

## 7. 真实战斗接入调研结论

### 7.1 MainVisual 当前入口

当前 `scenes/MainVisual.tscn` 已改挂 wrapper：

```text
res://scripts/battle_controller_visual_narrative_context.gd
```

该 wrapper 继承：

```text
res://scripts/battle_controller_visual_break_preview.gd
```

原始战斗继承链路仍为：

```text
battle_controller_visual_break_preview.gd
→ battle_controller_visual_resolver_preview.gd
→ battle_controller_visual_responsive_ui.gd
→ battle_controller_visual_cached_ui.gd
→ battle_controller_visual_ui.gd
→ battle_controller_demo_visual.gd
→ battle_controller_core.gd
```

### 7.2 Battle Core 当前启动方式

`battle_controller_core.gd` 的 `_ready()` 当前流程为：

```text
_build_catalog()
_build_ui()
state_machine.reset_for_session()
_show_role_selection()
```

含义：

```text
战斗默认从“角色选择入口”开始；
V1 单向跳转不绕过 _show_role_selection；
MainVisual 现有测试入口保持不变。
```

### 7.3 当前 V1 接入方式

已完成：

```text
叙事节点点击“请求战斗”
→ 记录 encounter_id / source_node_id
→ 跳转 MainVisual.tscn
→ MainVisual 显示 NarrativeBattleContext 诊断
→ MainVisual 仍进入现有角色选择/战斗测试链路
→ 战斗进入 RESULT 后显示 Battle Result 诊断
```

暂不做：

```text
战斗结束回到叙事
战斗胜负写回
绕过角色选择
根据 encounter_id 自动配置敌人
```

---

## 8. 真实战斗胜负结算点定位

### 8.1 HP 写入点

文件：

```text
scripts/battle_state_machine.gd
```

关键函数：

```text
resolve_intent(intent, actor, target)
```

当前逻辑：

```text
如果 actor.hp <= 0，则本次 intent 不再执行；
攻击命中后计算 final_damage；
如果 final_damage > 0：
    target.hp = maxi(target.hp - final_damage, 0)
```

结论：

```text
真实 HP 归零发生在 BattleStateMachine.resolve_intent() 内。
```

### 8.2 Result phase 切换点

文件：

```text
scripts/battle_state_machine.gd
```

关键函数：

```text
finish_round(player, enemy)
```

当前逻辑：

```text
phase = BattlePhase.DECLARE if player.hp > 0 and enemy.hp > 0 else BattlePhase.RESULT
```

结论：

```text
胜负判断的最小可靠信号是：state_machine.phase == BattleStateMachine.BattlePhase.RESULT。
```

---

## 9. 当前仍需推进

```text
[ ] Web 验收：NarrativeDemo 下方选项完整显示 / 可滚动
[ ] Web 验收：NarrativeDemo 点击请求战斗能进入 MainVisual
[ ] Web 验收：MainVisual 显示 encounter_id / source_node_id
[ ] Web 验收：MainVisual 原有角色选择入口不受影响
[ ] Web 验收：战斗 RESULT 后显示 Battle Result 诊断
[ ] 根据 visual_debug_label 判断 SVG 是否可被当前 Godot Web 导入为 Texture2D
[ ] 若 SVG 不能作为 Texture2D 正常显示，则改为真实 PNG 占位图
[ ] 继续定位 battle_controller_core.gd 中 RESULT phase 的 UI 处理函数
[ ] V3：encounter_id → enemy/fighter 映射
[ ] V4：战斗结果回写叙事
```

---

## 10. 下一刀建议：Web 验收 Battle Result 诊断

目标：

```text
确认从叙事请求战斗进入 MainVisual 后，战斗 RESULT 可被 wrapper 非侵入式识别。
```

验收标准：

```text
[ ] 从 NarrativeDemo 请求战斗进入 MainVisual
[ ] MainVisual 显示 NarrativeBattleContext 诊断
[ ] 原有角色选择仍可用
[ ] 打完战斗后 BattleResultDebugLabel 显示：
    phase=RESULT
    player_hp=...
    enemy_hp=...
    narrative_result=win/lose/draw
[ ] 原有战斗结算 UI 不受影响
[ ] Web 构建稳定
```

如果诊断遮挡 UI：

```text
下一刀只调整 debug label 位置或折叠方式，不改战斗规则。
```

---

## 11. 后续路线

### Step 1：Web 验收 Battle Result 诊断

```text
确认 RESULT phase 可被 wrapper 稳定捕获。
```

### Step 2：继续定位原生 RESULT UI

```text
找出 battle_controller_core.gd 或子类中如何显示战斗结束 UI。
```

### Step 3：encounter_id → enemy/fighter 映射

```text
只映射到已有 spearman / blademaster，不新增复杂敌人体系。
```

### Step 4：战斗结果回写叙事

```text
只有在 RESULT 诊断稳定后，再做返回 NarrativeDemo 与结果回写。
```

---

## 12. 给 Codex 的下一步指令

```text
请继续在安全线推进，不要恢复 scripts/narrative/* 旧复杂链路。当前已在 scripts/battle_controller_visual_narrative_context.gd 中增加 BattleResultDebugLabel：当 NarrativeBattleContext.has_request() 且 state_machine.phase == BattleStateMachine.BattlePhase.RESULT 时，显示 player.hp / enemy.hp / narrative_result。下一步请做 Web 回归验收：从 NarrativeDemo 请求战斗进入 MainVisual，确认上下文诊断可见、原有角色选择可用、战斗 RESULT 后显示 result 诊断。不要改 BattleStateMachine，不要改 resolve_intent，不要改 finish_round，不要自动回 NarrativeDemo，不要根据 encounter_id 自动换敌人。
```

---

## 13. 当前一句话结论

```text
剧情 MVP 安全线已完成并通过 P0；真实战斗接入已完成 V1 单向跳转、MainVisual 上下文诊断与 Battle Result 非侵入式诊断，下一步应 Web 验收 RESULT 捕获是否稳定。
```
