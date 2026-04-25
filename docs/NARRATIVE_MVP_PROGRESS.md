# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已恢复；剧情 MVP 已切到安全版 controller；安全版已完成“压缩序章 + 六列行军图 + 地图点击 + 三变量成长 + 战斗占位 + 场景信息分层 + 结局闭环 + UI 分层 + 操作区滚动修复 + 真实战斗 V1 单向跳转 + MainVisual 叙事上下文诊断 + Battle Result 诊断 + 战斗胜利后继续剧情闭环”。  
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

真实战斗 V1.5 接入目标：

```text
剧情战斗节点点击“请求战斗”
→ 写入 encounter_id / source_node_id
→ 跳转 MainVisual.tscn
→ MainVisual 显示叙事上下文诊断
→ MainVisual 继续走现有角色选择入口
→ 战斗结算后显示 Battle Result 诊断
→ 显示“继续剧情”按钮
→ 点击后返回 NarrativeDemo
→ NarrativeDemo 消费 battle result，并按 win 自动推进到下一节点
```

当前仍不做：

```text
不根据 encounter_id 自动换敌人
不绕过角色选择
不改 BattleStateMachine
不改 resolve_intent
不改 finish_round
不做复杂失败惩罚
```

---

## 2. 当前已完成实装

### 2.1 Web 构建稳定修复

```text
[x] 新增 scripts/narrative/.gdignore，临时隔离旧复杂叙事链路
[x] NarrativeDemo.tscn 切到 parser-safe controller
[x] 不再依赖 HScrollContainer
[x] 不再依赖 NarrativeDemoController class_name 解析
[x] 修复 visual diagnostics 中 class_name 作为变量名导致的 Parser Error
[x] 修复 BattleStateMachine preload 名称与父类成员冲突问题
[x] safe controller 已重新构建通过用户验收
```

对应提交：

```text
9228e5fc8dffc1a4de022521a84d11aca8a5b174  Ignore legacy narrative scripts for parser stability
90d405523f565a4d5ecf0ab36f247c9893634941  Use parser-safe narrative demo controller
c30ea1b5a6017ca956ecfbc512b074d484bf731c  Fix visual diagnostics parser variable name
6f68afe348bb66a3ecd052bcd1d5ccd08f48dec1  Fix battle state machine name collision in narrative wrapper
```

---

### 2.2 安全版 NarrativeDemo Controller

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
[x] 请求战斗已升级为跳转 MainVisual.tscn
[x] 从 MainVisual 返回后可消费 battle result
[x] win 后自动给予战斗收益，并推进到下一节点
[x] lose / draw 当前只返回当前节点并提示，不做复杂惩罚
[x] 结局与重开闭环
[x] 收益与推进入口已收口：_apply_choice_delta / _apply_default_map_reward / _advance_to_node
[x] UI 分层完成：map_buttons_box / combat_buttons_box / choices_box
[x] 下方操作区已改为 ScrollContainer，避免选项被挤出屏幕
[x] 最小图片显示：TextureRect + ResourceLoader.exists
[x] 视觉资源路径已切到 SVG 占位资源
[x] 视觉资源诊断：visual_debug_label 显示 path / exists / type / 状态
```

对应近期提交：

```text
07a22f47c6f3bdb693cc082d0f86fd5f4e6d9c9f  Add one-way jump from narrative demo to battle scene
bfe1aeea444afc112740df0c27557557ffdb2693  Make narrative action area scrollable
c139ebfc4504ffe1be72f73f2c3d168028151e34  Consume battle result when returning to narrative demo
```

---

### 2.3 Narrative Battle Context

文件：

```text
scripts/narrative_battle_context.gd
```

作用：

```text
作为叙事与战斗之间的轻量上下文，记录：
encounter_id
source_node_id
source_scene
return_after_battle
last_result
result_ready
```

当前行为：

```text
NarrativeDemo 点击“请求战斗”
→ NarrativeBattleContext.set_request(encounter_id, source_node_id)
→ 进入 MainVisual

MainVisual 战斗进入 RESULT
→ NarrativeBattleContext.set_result(narrative_result)
→ 显示“继续剧情”按钮

点击“继续剧情”
→ 返回 NarrativeDemo
→ NarrativeDemo 根据 source_node_id 和 last_result 消费结果
```

对应提交：

```text
bc38e66a4e06daa3af46376900401c4fa4090ea2  Add battle result state to narrative context
```

---

### 2.4 MainVisual 叙事上下文与结果诊断

文件：

```text
scripts/battle_controller_visual_narrative_context.gd
```

实现方式：

```text
extends res://scripts/battle_controller_visual_break_preview.gd
_ready() 中先 super._ready()
如果 NarrativeBattleContext.has_request()，追加 NarrativeContextDebugLabel
_process 中非侵入式检查 state_machine.phase / player.hp / enemy.hp
当 phase == RESULT，写入 NarrativeBattleContext.last_result
显示 BattleResultDebugLabel
显示“继续剧情”按钮
```

当前结果规则：

```text
player.hp > 0 and enemy.hp <= 0 → narrative_result=win
player.hp <= 0 and enemy.hp > 0 → narrative_result=lose
player.hp <= 0 and enemy.hp <= 0 → narrative_result=draw
其他情况 → narrative_result=unknown
```

对应提交：

```text
97bffadb05c0ee994edb27597319e22c251ef645  Add narrative context wrapper for MainVisual
02301584ac14d56483a2f9c6d1c3052abd40dbea  Use narrative context wrapper for MainVisual
a4777fd2b960aa63e366db88eba5b417b62f09ae  Add battle result diagnostics to narrative wrapper
6f68afe348bb66a3ecd052bcd1d5ccd08f48dec1  Fix battle state machine name collision in narrative wrapper
```

新增本轮提交：

```text
Add continue narrative button after battle result
```

约束：

```text
不绕过角色选择
不根据 encounter_id 自动换敌人
不改战斗规则
不改 BattleStateMachine
只做上下文、结果诊断、继续剧情按钮
```

---

## 3. 当前 UI 修复说明

### 3.1 NarrativeDemo 下方 UI

问题：

```text
下方 UI 显示不全，尤其是“叙事选择”区域容易被挤出屏幕。
```

修复：

```text
map_buttons_box / combat_buttons_box / choices_box 统一放入 action_scroll: ScrollContainer
action_scroll 设置 SIZE_EXPAND_FILL
操作区高度保底 250
每次刷新时 action_scroll.scroll_vertical = 0
```

---

## 4. 当前视觉显示规则

节点现在配置：

```text
visual_path
```

规则：

```text
visual_path 为空 → 显示文本占位；诊断 path=空 / 状态=文本占位
ResourceLoader.exists(path) 为 false → 显示文本占位；诊断 exists=false
资源存在且是 Texture2D → TextureRect 显示图片；诊断 exists=true / type=Texture2D / 状态=已显示
资源存在但不是 Texture2D → 显示错误占位文本；诊断 exists=true / type=<class> / 状态=非 Texture2D
```

---

## 5. 当前收益与推进规则

### 5.1 普通选择按钮

```text
普通 choice 点击
→ _apply_choice_delta(choice)
→ _advance_to_node(node_index + 1, "")
→ _render()
```

### 5.2 地图点击按钮

```text
地图按钮点击
→ 当前节点：只提示，不推进
→ 已走节点：只提示，不推进
→ 未开放节点：只提示，不推进
→ 可前往节点：_apply_default_map_reward(target_index) → _advance_to_node(target_index, hint)
```

### 5.3 战斗结果返回

```text
MainVisual 返回 NarrativeDemo 后：
如果 last_result == win：
    根据原战斗节点类型给予战斗收益
    自动推进到下一节点
如果 last_result == lose：
    停留当前节点，仅提示失败
如果 last_result == draw：
    停留当前节点，仅提示同归于尽
```

---

## 6. 真实战斗接入结论

### 6.1 MainVisual 当前入口

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

### 6.2 Battle Core 当前启动方式

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
当前没有绕过 _show_role_selection；
MainVisual 现有测试入口保持不变。
```

### 6.3 胜负结算点

文件：

```text
scripts/battle_state_machine.gd
```

关键函数：

```text
resolve_intent(intent, actor, target)
finish_round(player, enemy)
```

结论：

```text
HP 归零发生在 resolve_intent()
phase 切到 RESULT 发生在 finish_round()
最小可靠胜负信号是 state_machine.phase == BattlePhase.RESULT
```

---

## 7. 当前仍需推进

```text
[ ] Web 验收：战斗胜利后出现“继续剧情”按钮
[ ] Web 验收：点击“继续剧情”能返回 NarrativeDemo
[ ] Web 验收：win 后 NarrativeDemo 自动推进到下一节点
[ ] Web 验收：MainVisual 原有角色选择入口不受影响
[ ] Web 验收：NarrativeDemo 下方选项完整显示 / 可滚动
[ ] 根据 visual_debug_label 判断 SVG 是否可被当前 Godot Web 导入为 Texture2D
[ ] 若 SVG 不能作为 Texture2D 正常显示，则改为真实 PNG 占位图
[ ] V3：encounter_id → enemy/fighter 映射
[ ] V4：失败/平局叙事分支
```

---

## 8. 下一刀建议：Web 验收战斗回流闭环

目标：

```text
确认“剧情 → 战斗 → 胜利 → 继续剧情 → 回到下一节点”的闭环成立。
```

验收标准：

```text
[ ] 从 NarrativeDemo 战斗节点点击请求战斗
[ ] 进入 MainVisual
[ ] 正常选择角色并打完战斗
[ ] RESULT 后出现“继续剧情”按钮
[ ] 点击按钮返回 NarrativeDemo
[ ] NarrativeDemo 显示“战斗胜利：已返回剧情，并自动推进到下一节点。”
[ ] 地图当前节点已经推进到下一格
[ ] 军功 / 旧案线索按战斗奖励增加
[ ] Web 构建稳定
```

如果按钮遮挡战斗 UI：

```text
下一刀只调整 ContinueNarrativeButton 位置，不改战斗规则。
```

---

## 9. 后续路线

### Step 1：Web 验收战斗回流闭环

```text
确认剧情—战斗—剧情闭环可玩。
```

### Step 2：encounter_id → enemy/fighter 映射

```text
只映射到已有 spearman / blademaster，不新增复杂敌人体系。
```

### Step 3：失败 / 平局叙事分支

```text
先轻量处理失败、平局，不做复杂惩罚系统。
```

---

## 10. 给 Codex 的下一步指令

```text
请继续在安全线推进，不要恢复 scripts/narrative/* 旧复杂链路。当前已补上战斗胜利后的继续剧情闭环：MainVisual RESULT 后显示“继续剧情”按钮，点击返回 NarrativeDemo；NarrativeDemo 消费 NarrativeBattleContext.last_result，如果 win 则给战斗奖励并自动推进到下一节点。下一步请做 Web 回归验收：从 NarrativeDemo 请求战斗，打赢后点击继续剧情，确认回到 NarrativeDemo 且地图推进、变量增加。不要改 BattleStateMachine，不要绕过角色选择，不要根据 encounter_id 自动换敌人。
```

---

## 11. 当前一句话结论

```text
剧情 MVP 安全线已完成并通过 P0；真实战斗接入已从“单向跳转”推进到“胜利后继续剧情闭环”，下一步应 Web 验收剧情—战斗—剧情是否完整成立。
```
