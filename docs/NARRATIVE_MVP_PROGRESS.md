# 《大明之沧海嘀鸣》叙事 MVP 进度看板

> 当前分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已再次恢复；剧情 MVP 已切到安全版 controller；安全版已完成“压缩序章 + 六列行军图 + 地图点击 + 三变量成长 + 战斗占位 + 场景/人物/旧物文本占位 + 结局闭环 + 收益与推进入口收口 + UI 分层 + 最小图片显示 + 六列地图操作布局 + SVG 占位视觉资源 + 场景信息分层展示 + 视觉资源诊断 + Parser 稳定修复”；真实战斗接入前调研已启动。  
> 核心原则：继续走安全线，不恢复旧 `scripts/narrative/*` 复杂链路；不使用 `HScrollContainer`；不直接改战斗规则；不破坏现有战斗测试入口；不重构 `web_shell.html`。

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
视觉诊断：显示 path / exists / type / 状态，便于 Web 验收
场景信息：scene 文本按句切分为多行 bullet，降低拥挤
战斗表现：请求战斗 / 视为胜利继续 先用文本占位
UI 分层：行军图操作 / 战斗桥接 / 叙事选择 三个区域分开展示
下一阶段：从“战斗占位”推进到“真实战斗最小接入”
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
[x] 场景文本占位：背景 / 人物 / 旧物 / 结局图
[x] 场景信息分层展示：_format_scene_text 按句切分为 bullet
[x] 战斗桥接文本占位：请求战斗 / 视为胜利继续 / node_id / encounter_id
[x] 结局与重开闭环
[x] 收益与推进入口已收口：_apply_choice_delta / _apply_default_map_reward / _advance_to_node
[x] UI 分层完成：map_buttons_box / combat_buttons_box / choices_box
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

---

## 4. 当前视觉显示规则

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

## 7. 真实战斗接入前调研结论

### 7.1 MainVisual 当前入口

当前 `scenes/MainVisual.tscn` 挂载脚本不是早期文档里的 responsive controller，而是：

```text
res://scripts/battle_controller_visual_break_preview.gd
```

继承链路为：

```text
battle_controller_visual_break_preview.gd
→ battle_controller_visual_resolver_preview.gd
→ battle_controller_visual_responsive_ui.gd
→ battle_controller_visual_cached_ui.gd
→ battle_controller_visual_ui.gd
→ battle_controller_demo_visual.gd
→ battle_controller_core.gd
```

含义：

```text
真实接入不能只看 battle_controller_visual_responsive_ui.gd；
MainVisual 当前实际入口是 break preview 层；
任何 narrative 跳转都应以 MainVisual.tscn 当前脚本为准。
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
尚未看到可直接从 encounter_id 启动战斗的公开入口；
第一版不应直接绕过 _show_role_selection，除非补一个明确的 narrative start API。
```

### 7.3 Catalog 与敌人配置现状

`_build_catalog()` 当前核心角色仍是：

```text
spearman
blademaster
```

含义：

```text
当前真实战斗资源和卡组仍围绕枪手 / 刀客；
叙事 encounter_id 应先映射到已有 fighter id，而不是新增复杂敌人体系；
建议第一版映射：
enc_beach_ambush → enemy_spearman / spearman
enc_transport_officer → enemy_blademaster / blademaster
enc_wakou_boss → enemy_blademaster / blademaster
```

### 7.4 当前最小接入判断

第一版建议不要做“完整战斗结束回到叙事”，先做：

```text
叙事节点点击“请求战斗”
→ 记录 encounter_id 到全局/启动上下文
→ 跳转 MainVisual.tscn
→ MainVisual 仍进入现有角色选择/战斗测试链路
```

原因：

```text
风险最小；
不改战斗规则；
不破坏现有战斗测试入口；
先验证叙事到战斗的单向链路。
```

第二版再做：

```text
战斗胜利/失败信号
→ 回到 NarrativeDemo
→ 根据 encounter_id 写入战斗结果
→ 解锁战后 choice
```

---

## 8. 当前仍需推进

```text
[ ] 根据 visual_debug_label 判断 SVG 是否可被当前 Godot Web 导入为 Texture2D
[ ] 若 SVG 不能作为 Texture2D 正常显示，则改为真实 PNG 占位图
[ ] 六列行军图操作区在 1600×1000 下验收
[ ] 图片显示区域尺寸和正文高度在 1600×1000 下验收
[ ] 真实战斗单向跳转接入
[ ] 真实战斗胜利/失败回调接入前继续定位结算函数
```

---

## 9. 下一刀建议：叙事到 MainVisual 的单向跳转

目标：

```text
把 safe controller 里的“请求战斗”从文本占位升级为单向跳转 MainVisual.tscn。
```

建议实现：

```text
1. 新增 scripts/narrative_battle_context.gd，作为轻量全局上下文或可 preload 的静态上下文
2. safe controller 点击“请求战斗”时写入 encounter_id / source_node_id
3. get_tree().change_scene_to_file("res://scenes/MainVisual.tscn")
4. MainVisual 暂不读取上下文，仍保留现有角色选择入口
5. 文档标注：这是 V1 单向链路，不处理战斗后返回
```

验收标准：

```text
[ ] NarrativeDemo 点击请求战斗能进入 MainVisual
[ ] MainVisual 现有角色选择入口不受影响
[ ] 不改战斗规则
[ ] 不破坏 Web 构建
```

---

## 10. 后续路线

### Step 1：真实战斗单向跳转

```text
先打通剧情 → 战斗测试场景，不处理返回。
```

### Step 2：定位战斗胜负结算函数

```text
继续精确定位 HP 归零、battle_active=false、overlay 胜负按钮等逻辑。
```

### Step 3：战斗结果回写叙事

```text
只有在结算函数明确后，再加 battle_finished 信号或全局上下文结果回写。
```

---

## 11. 给 Codex 的下一步指令

```text
请继续在安全线推进，不要恢复 scripts/narrative/* 旧复杂链路。当前已调研 MainVisual：scenes/MainVisual.tscn 当前挂载 res://scripts/battle_controller_visual_break_preview.gd；battle core 的 _ready() 仍默认 _build_catalog()、_build_ui()、reset_for_session()、_show_role_selection()。下一步请做叙事到战斗的 V1 单向跳转：在 safe controller 点击“请求战斗”时记录 encounter_id / source_node_id，然后 change_scene_to_file("res://scenes/MainVisual.tscn")。不要改战斗规则，不要破坏 MainVisual 现有角色选择入口，不要重构 web_shell.html。
```

---

## 12. 当前一句话结论

```text
剧情 MVP 安全线已完成并通过 P0；真实战斗接入前调研确认 MainVisual 当前入口是 break preview 层，第一版应先做 NarrativeDemo → MainVisual 的单向跳转，不直接做战斗结束回到叙事。
```
