# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已恢复；剧情 MVP 已切到安全版 controller；安全版已完成“压缩序章 + 六列行军图 + 地图点击 + 三变量成长 + 战斗占位 + 场景/人物/旧物文本占位 + 结局闭环 + 收益与推进入口收口”。  
> 核心原则：继续走安全线，不恢复旧 `scripts/narrative/*` 复杂链路；不使用 `HScrollContainer`；不改 `MainVisual.tscn`；不改 `battle_controller`；不重构 `web_shell.html`。

---

## 1. 当前目标

叙事 MVP 当前只验证一件事：

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

安全版目标：

```text
剧情 MVP：进入 NarrativeDemo.tscn
当前脚本：res://scripts/narrative_demo_safe_controller.gd
中文显示：复用 BattleFontHelper
行军图：六列文本地图 + 地图按钮
地图状态：▶ 当前 / ● 已走 / ◎ 可前往 / ○ 未开放
叙事变量：军功 / 清望 / 旧案线索
视觉表现：背景 / 人物 / 旧物 / 结局图先用文本占位
战斗表现：请求战斗 / 视为胜利继续 先用文本占位
```

---

## 2. 为什么切到安全线

此前复杂叙事链路出现 Web Parser 风险：

```text
Parser Error: Could not resolve class "NarrativeDemoController"
Parser Error: Identifier "HScrollContainer" not declared in the current scope
```

已采取处理：

```text
临时隔离旧 scripts/narrative/*；
NarrativeDemo.tscn 切到 scripts/narrative_demo_safe_controller.gd；
先恢复 P0 Web 构建稳定；
在 safe controller 内逐步补回 MVP 体验。
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
```

对应提交：

```text
9228e5fc8dffc1a4de022521a84d11aca8a5b174  Ignore legacy narrative scripts for parser stability
90d405523f565a4d5ecf0ab36f247c9893634941  Use parser-safe narrative demo controller
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
[x] 场景文本占位：背景 / 人物 / 旧物 / 结局图
[x] 战斗桥接文本占位：请求战斗 / 视为胜利继续 / node_id / encounter_id
[x] 结局与重开闭环
[x] 收益与推进入口已收口：_apply_choice_delta / _apply_default_map_reward / _advance_to_node
```

对应提交：

```text
72b93d5ecf54199f3c38dcd630a4a4e27155bcc3  Restore safe narrative map and art placeholders
4b440f5f4da75e08ec80ccda07b8942fa264a92e  Add safe narrative map jump buttons
b580c2e58e98ba7dc5779599f0dfce21a510dafe  Apply default rewards on safe map navigation
0d57c595a4938c179bd21a636b9ffd1b5500fa44  Unify safe narrative progression helpers
```

---

## 4. 当前收益与推进规则

### 4.1 普通选择按钮

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

### 4.2 地图点击按钮

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

## 5. 当前仍需推进

```text
[ ] 安全版 Web 回归验收
[ ] 行军图按钮区布局优化，避免按钮横向过挤
[ ] 战斗桥接按钮和普通选择按钮视觉分组
[ ] 场景占位信息分层展示，降低正文拥挤
[ ] 安全恢复图片显示：背景 / 立绘 / 旧物图
[ ] 真实战斗胜利回调接入前调研
```

---

## 6. 下一刀建议：安全版 UI 分层优化

目标：

```text
在不改 Web 外壳、不恢复旧复杂链路的前提下，把当前所有按钮堆在 choices_box 的问题拆开。
```

建议实现：

```text
1. 新增 map_buttons_box：只放行军图按钮
2. 新增 combat_buttons_box：只放请求战斗 / 视为胜利继续
3. choices_box 只放叙事选择按钮
4. 保留现有逻辑，不改节点数据
5. 所有动态控件刷新后继续 BattleFontHelper.enforce(self)
```

验收标准：

```text
[ ] 地图按钮、战斗按钮、叙事选择按钮视觉上分区
[ ] Web 构建稳定
[ ] 序章、行军图、地图点击、战斗占位、结局闭环不受影响
```

---

## 7. 后续路线

### Step 1：安全版 UI 分层优化

```text
优先级最高，当前体验上所有按钮挤在一起，阅读和操作成本高。
```

### Step 2：安全恢复图片展示

```text
只在 safe controller 内做 TextureRect + ResourceLoader.exists；
不恢复旧 narrative_demo_controller.gd；
不使用 HScrollContainer。
```

### Step 3：真实战斗接入前调研

```text
梳理 MainVisual 的启动参数和胜利回调；
不直接改战斗规则；
不破坏现有战斗测试入口。
```

### Step 4：重新评估旧复杂链路

```text
只有在 safe controller 跑稳后，再决定是否把旧 scripts/narrative/* 中的数据化能力逐步迁回。
```

---

## 8. 给 Codex 的下一步指令

```text
请继续在 scripts/narrative_demo_safe_controller.gd 上推进，不要恢复 scripts/narrative/* 旧复杂链路。下一步优先做安全版 UI 分层：新增 map_buttons_box、combat_buttons_box、choices_box 三个区域，让地图按钮、战斗桥接按钮、叙事选择按钮分区展示。不要使用 HScrollContainer，不要改 MainVisual.tscn，不要改 battle_controller，不要重构 web_shell.html。完成后验证：Web 构建稳定，序章、行军图、地图点击、战斗占位、结局闭环都不受影响。
```

---

## 9. 当前一句话结论

```text
剧情 MVP 已从复杂链路切到安全线，并完成“Web 稳定、压缩序章、六列行军图、地图点击、三变量成长、战斗占位、场景占位、结局闭环、收益与推进入口收口”；下一步抓重点做安全版 UI 分层，提升可读性和后续接图/接战斗的扩展空间。
```
