# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已恢复；剧情 MVP 已切到安全版 controller；安全版已完成“压缩序章 + 六列行军图 + 地图点击 + 三变量成长 + 战斗占位 + 场景/人物/旧物文本占位 + 结局闭环 + 收益与推进入口收口 + UI 分层 + 最小图片显示 + 六列地图操作布局 + SVG 占位视觉资源 + 场景信息分层展示”。  
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
行军图：六列文本地图 + 六列地图按钮
地图状态：▶ 当前 / ● 已走 / ◎ 可前往 / ○ 未开放
叙事变量：军功 / 清望 / 旧案线索
视觉表现：ResourceLoader.exists + TextureRect；当前使用 SVG 占位资源走通加载链路
场景信息：scene 文本按句切分为多行 bullet，降低拥挤
战斗表现：请求战斗 / 视为胜利继续 先用文本占位
UI 分层：行军图操作 / 战斗桥接 / 叙事选择 三个区域分开展示
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
[x] 场景文本占位：背景 / 人物 / 旧物 / 结局图
[x] 场景信息分层展示：_format_scene_text 按句切分为 bullet
[x] 战斗桥接文本占位：请求战斗 / 视为胜利继续 / node_id / encounter_id
[x] 结局与重开闭环
[x] 收益与推进入口已收口：_apply_choice_delta / _apply_default_map_reward / _advance_to_node
[x] UI 分层完成：map_buttons_box / combat_buttons_box / choices_box
[x] 最小图片显示：TextureRect + ResourceLoader.exists
[x] 视觉资源路径已切到 SVG 占位资源
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
```

---

### 3.3 SVG 占位视觉资源

已新增：

```text
assets/pixel_battle/backgrounds/narrative_military_order.svg
assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
assets/pixel_battle/relics/relic_ming_firearm.svg
assets/pixel_battle/portraits/transport_officer.svg
assets/pixel_battle/portraits/wakou_leader.svg
assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

对应提交：

```text
2875094edb5fabdefd30f81faa42df796b924d8b  Add narrative military order placeholder art
b6f7e41a2c3d9a8d8c9cb20dc2a6ee71e34b3a4d  Add narrative beach ambush placeholder art
b6f7e41a2c3d9a8d8c9cb20dc2a6ee71e34b3a4d  Add Ming firearm relic placeholder art
52269becca1292119dcddb0a562350b8aa0c8b7e  Add transport officer placeholder portrait
eacdd9a5bc073125c897be4756eb44ccf282ae17  Add wakou leader placeholder portrait
9d51af72c78b5e25f6d28605d960806d1abcc4d0  Add military coverup placeholder art
```

> 注：部分提交 SHA 可能因连续文件创建由工具返回不完整展示；以仓库历史为准。

---

## 4. 当前视觉显示规则

节点现在配置：

```text
visual_path
```

当前安全版规则：

```text
visual_path 为空 → 显示文本占位
ResourceLoader.exists(path) 为 false → 显示文本占位
资源存在且是 Texture2D → TextureRect 显示图片
资源存在但不是 Texture2D → 显示错误占位文本
```

当前配置路径：

```text
military_order → res://assets/pixel_battle/backgrounds/narrative_military_order.svg
beach_ambush → res://assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
ming_firearm → res://assets/pixel_battle/relics/relic_ming_firearm.svg
transport_officer → res://assets/pixel_battle/portraits/transport_officer.svg
wakou_boss → res://assets/pixel_battle/portraits/wakou_leader.svg
military_coverup → res://assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

---

## 5. 当前 UI 分层

当前动态控件已经拆成三个区域：

```text
map_buttons_box：行军图操作，只放地图节点按钮；当前为六列布局
combat_buttons_box：战斗桥接，只放“请求战斗 / 视为胜利继续”或无战斗提示
choices_box：叙事选择，只放当前节点 choices / 序章继续 / 重开叙事
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

## 7. 当前仍需推进

```text
[ ] 安全版 Web 回归验收
[ ] 验证 SVG 是否可被当前 Godot Web 导入为 Texture2D
[ ] 若 SVG 不能作为 Texture2D 正常显示，则改为真实 PNG 占位图
[ ] 六列行军图操作区在 1600×1000 下验收
[ ] 图片显示区域尺寸和正文高度在 1600×1000 下验收
[ ] 真实战斗胜利回调接入前调研
```

---

## 8. 下一刀建议：Web 验收 SVG 视觉链路

目标：

```text
验证 ResourceLoader.exists(svg_path) 和 TextureRect 显示链路在当前 Godot Web 构建中是否可用。
```

验收标准：

```text
[ ] Web 构建稳定
[ ] 进入 NarrativeDemo 不报错
[ ] 进入节点后视觉区域显示 SVG 图，而不是文本占位
[ ] 若显示“视觉资源不是 Texture2D”，则下一刀改用 PNG 占位图
[ ] 地图点击、战斗占位、结局闭环不受影响
```

---

## 9. 后续路线

### Step 1：Web 验收 SVG 视觉链路

```text
优先级最高，确认 Godot Web 对 SVG 资源显示是否可靠。
```

### Step 2：必要时改 PNG 占位图

```text
如果 SVG 无法被 TextureRect 正常显示，则批量替换为 PNG 资源。
```

### Step 3：真实战斗接入前调研

```text
梳理 MainVisual 的启动参数和胜利回调；
不直接改战斗规则；
不破坏现有战斗测试入口。
```

---

## 10. 给 Codex 的下一步指令

```text
请继续在安全线推进，不要恢复 scripts/narrative/* 旧复杂链路。当前已添加 6 个 SVG 占位视觉资源，并将 scripts/narrative_demo_safe_controller.gd 的 visual_path 指向这些 SVG，同时 scene 文本已分层展示。下一步请做 Web 回归验收：确认 ResourceLoader.exists(svg_path) 是否为 true，TextureRect 是否能显示 SVG。如果 SVG 不能作为 Texture2D 正常显示，请改用 PNG 占位图。不要改 MainVisual.tscn，不要改 battle_controller，不要重构 web_shell.html。
```

---

## 11. 当前一句话结论

```text
剧情 MVP 安全线已完成“Web 稳定、压缩序章、六列行军图、六列地图操作、地图点击、三变量成长、战斗占位、场景占位、场景信息分层、结局闭环、收益与推进入口收口、UI 分层、最小图片显示、SVG 占位视觉资源”；下一步抓重点验收 SVG 在 Godot Web 中是否能稳定显示。
```
