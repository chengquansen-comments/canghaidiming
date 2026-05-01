# 叙事 MVP 安全线推进记录

> 分支：`feature/symmetry-gameplay`  
> 当前阶段：P0 Web 构建稳定已恢复；剧情 MVP 已切到安全版 controller；地图点击、安全行军图、三变量、战斗占位、场景/人物/旧物文本占位已重新补回。  
> 当前原则：优先保证 Web Parser 稳定；暂不恢复旧 `scripts/narrative/*` 复杂链路；不改 `MainVisual.tscn`，不改 `battle_controller`，不重构 `web_shell.html`。

---

## 1. 为什么切安全线

此前复杂叙事链路出现了 Web Parser 风险：

```text
Parser Error: Could not resolve class "NarrativeDemoController"
Parser Error: Identifier "HScrollContainer" not declared in the current scope
```

处理策略：

```text
先恢复 P0 Web 构建稳定；
临时隔离旧 scripts/narrative/*；
新建不依赖旧链路的安全版 NarrativeDemo controller；
在安全版上逐步补回 MVP 体验。
```

---

## 2. 当前有效入口

```text
scenes/NarrativeDemo.tscn
```

当前脚本：

```text
res://scripts/narrative_demo_safe_controller.gd
```

说明：

```text
该 controller 不依赖 HScrollContainer；
不依赖 scripts/narrative/*；
复用 BattleFontHelper 保障中文字体；
用于当前剧情 MVP Web 稳定验收。
```

---

## 3. 已完成提交记录

```text
9228e5fc8dffc1a4de022521a84d11aca8a5b174  Ignore legacy narrative scripts for parser stability
90d405523f565a4d5ecf0ab36f247c9893634941  Use parser-safe narrative demo controller
72b93d5ecf54199f3c38dcd630a4a4e27155bcc3  Restore safe narrative map and art placeholders
4b440f5f4da75e08ec80ccda07b8942fa264a92e  Add safe narrative map jump buttons
b580c2e58e98ba7dc5779599f0dfce21a510dafe  Apply default rewards on safe map navigation
```

---

## 4. 当前安全版已完成能力

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
[x] Web Parser 稳定，不再依赖旧复杂叙事链路
```

---

## 5. 当前默认收益规则

地图点击推进时，会根据目标节点类型给予默认行军收益：

```text
普通战斗：军功 +1，旧案线索 +1
精英战斗：军功 +1，旧案线索 +1
Boss：军功 +2，旧案线索 +1
旧物：旧案线索 +2
结尾：清望 +1
事件：清望 +1
```

说明：

```text
这是安全版临时规则，目的是避免地图点击推进时三变量完全不变化。
下一步建议统一“普通选择推进”和“地图点击推进”的收益口径。
```

---

## 6. 当前仍需推进

```text
[ ] 统一普通 choices 和地图点击推进的收益入口
[ ] 避免“地图点击默认收益”和“普通选择 delta”形成两套难解释规则
[ ] 将安全版行军图从纯文本进一步升级为更清晰的按钮区布局
[ ] 恢复图片显示，但不能重新引入 HScrollContainer / 旧 scripts/narrative/* 解析风险
[ ] 真实战斗胜利回调接入前调研
```

---

## 7. 下一刀建议：统一推进收益入口

目标：

```text
把选择按钮推进和地图按钮推进都收口到统一方法。
```

建议实现：

```text
_apply_choice_delta(choice)
_apply_default_map_reward(target_index)
_advance_to_node(target_index, reason)
```

落地原则：

```text
普通选择：先应用 choice delta，再推进下一节点；
地图点击：应用默认地图收益，再推进目标节点；
所有推进结束后统一刷新 _render()；
继续不依赖 scripts/narrative/*；
继续不碰 MainVisual / battle_controller / web_shell。
```

验收标准：

```text
[ ] 普通选择推进后变量变化正常
[ ] 地图点击推进后变量变化正常
[ ] 两种推进路径都刷新地图 / 场景 / choices / 战斗占位
[ ] 结局和重开不受影响
[ ] Web 构建稳定
```

---

## 8. 后续路线

### Step 1：统一收益入口

```text
优先级最高，避免当前安全版逻辑继续分叉。
```

### Step 2：安全版 UI 细化

```text
行军图按钮区域更清晰；
战斗桥接按钮和普通选择按钮视觉区分；
场景占位信息分层展示。
```

### Step 3：安全恢复图片展示

```text
只在 safe controller 内做 TextureRect + ResourceLoader.exists；
不恢复旧 narrative_demo_controller.gd；
不使用 HScrollContainer。
```

### Step 4：真实战斗接入前调研

```text
先梳理 MainVisual 的启动参数和胜利回调；
不直接改战斗规则；
不破坏现有战斗测试入口。
```

---

## 9. 给 Codex 的下一步指令

```text
请继续在 scripts/narrative_demo_safe_controller.gd 上推进，不要恢复 scripts/narrative/* 旧复杂链路。下一步优先统一普通 choices 和地图点击推进的收益入口：抽出 _apply_choice_delta(choice)、_apply_default_map_reward(target_index)、_advance_to_node(target_index, reason) 之类的安全方法。普通选择先应用 choice delta，再统一推进；地图点击应用默认收益后统一推进。保持 Web Parser 稳定，不要使用 HScrollContainer，不要改 MainVisual.tscn，不要改 battle_controller，不要重构 web_shell.html。
```

---

## 10. 当前一句话结论

```text
剧情 MVP 已从复杂链路切到安全线，并重新补回“序章、六列行军图、地图点击、三变量、战斗占位、场景占位、结局闭环”；下一步抓重点统一推进收益入口，避免安全版内部产生两套规则。
```
