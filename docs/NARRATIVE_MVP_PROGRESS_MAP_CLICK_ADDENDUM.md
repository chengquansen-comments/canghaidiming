# 叙事 MVP 地图点击推进补充记录

> 分支：`feature/symmetry-gameplay`  
> 记录目的：补充 `NARRATIVE_MVP_PROGRESS.md` 中“静态分叉地图节点点击选路”阶段的实际推进情况。  
> 当前原则：地图点击必须复用原有 `choice` 推进链路，不绕过 `requires / requires_flag / delta / flags / ending`。

---

## 1. 本轮已完成

### 1.1 NarrativeState 选路接口

文件：

```text
scripts/narrative/narrative_state.gd
```

已新增：

```text
choice_index_for_next_node(next_node_id)
can_choose_next_node(next_node_id)
choose_next_node(next_node_id)
```

说明：

```text
choose_next_node(next_node_id)
内部仍走 available_choices(current_node()) → choose(index)
不会绕过 choice
不会绕过 requires / requires_flag
不会绕过 delta / flags
不会绕过 ending
```

对应提交：

```text
d9202d91e55bd32614171b546d7cd974afaa5ffa  Add narrative next-node choice helper
```

---

### 1.2 地图点击 Router

文件：

```text
scripts/narrative/narrative_map_click_router.gd
```

已新增：

```text
can_click_node(narrative, node_id)
click_node(narrative, node_id)
click_hint(narrative, node_id)
```

点击状态：

```text
当前节点
已走过
可前往
未开放
```

说明：

```text
click_node(narrative, node_id)
最终调用 NarrativeState.choose_next_node(node_id)
即地图点击和按钮选择共用同一套推进规则
```

对应提交：

```text
ee7fbb796b5cd7be7e39f8f13adcf80f5fbb2b03  Add narrative map click router
```

---

### 1.3 可点击地图 Demo Controller

新增文件：

```text
scripts/narrative/narrative_demo_controller_clickable_map.gd
```

实现方式：

```text
继承 NarrativeDemoController
只覆盖 _build_static_map_node_card(node_entry)
将静态地图节点卡片改为 Button
Button.pressed 接入 _on_static_map_node_pressed(node_id)
点击后通过 NarrativeMapClickRouter.click_hint 判断状态
只有“可前往”节点调用 NarrativeMapClickRouter.click_node
成功后刷新 _render_node()
```

对应提交：

```text
5a7a6fdbcf9b6f5264a4a8c77fb2e79e98ad8b56  Add clickable narrative map demo controller
```

---

### 1.4 NarrativeDemo 场景切换到可点击地图 Controller

修改文件：

```text
scenes/NarrativeDemo.tscn
```

当前脚本指向：

```text
res://scripts/narrative/narrative_demo_controller_clickable_map.gd
```

说明：

```text
不直接大改原 narrative_demo_controller.gd
保留原 controller 作为稳定基类
可点击地图逻辑独立在 clickable_map controller 中
降低 Web 编译和回滚风险
```

对应提交：

```text
1a596731a76dd83943f4d7ee9e43d7a809ddb89f  Use clickable map controller in narrative demo scene
```

---

## 2. 当前完成状态

```text
[x] NarrativeDemo 节点卡片点击调用 NarrativeMapClickRouter
[x] 可前往节点点击后刷新 node / map / choices / variables
[x] 当前节点点击只提示“当前节点”
[x] 已走节点点击只提示“已走过”
[x] 未开放节点点击只提示“未开放”
[x] 推进仍走 NarrativeState.choose_next_node
[x] requires / delta / flags 仍由原 choice 逻辑处理
```

---

## 3. 当前仍需验收

```text
[ ] Web 构建无 GDScript 编译错误
[ ] NarrativeDemo.tscn 能正常进入
[ ] 六列静态分叉地图仍正常显示
[ ] 点击 ◎ 可达节点能推进到对应节点
[ ] 点击 ○ 未开放节点不推进，只提示
[ ] 点击 ● 已走节点不推进，只提示
[ ] 点击 ▶ 当前节点不推进，只提示
[ ] 点击后变量、战斗桥接面板、背景、立绘、choices 均刷新
[ ] narrative-only 路径仍可完整走通
```

---

## 4. 下一刀建议

### Step 1：Web 验收可点击地图

```text
进入剧情 MVP
走完序章
点击地图上的可达节点
验证推进和刷新
点击当前 / 已走 / 未开放节点
验证只提示不推进
```

### Step 2：若通过，再推进真实战斗接入前调研

```text
梳理 MainVisual 的启动参数
梳理战斗胜利回调位置
确认不破坏当前战斗测试入口
```

---

## 5. 给 Codex 的精确指令

```text
请优先验证 scenes/NarrativeDemo.tscn 当前脚本 res://scripts/narrative/narrative_demo_controller_clickable_map.gd 的 Web 编译和运行。重点验证静态分叉地图节点点击：只有“可前往”的节点能推进；当前节点、已走节点、未开放节点只提示不推进；推进必须仍走 NarrativeState.choose_next_node，不允许绕过 choice / requires / delta / flags 逻辑。不要改变 mvp_compressed_narrative.json 的推进逻辑，不要做随机地图生成，不要改 battle_controller，不要改 MainVisual.tscn，不要重构 web_shell.html。
```

---

## 6. 当前一句话结论

```text
地图点击的状态机接口、Router 和 NarrativeDemo 可点击 UI 都已完成；下一步抓重点做 Web 验收，再决定是否进入真实战斗回调接入。
```
