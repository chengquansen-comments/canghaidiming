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

## 2. 当前未完成

```text
[ ] NarrativeDemo 节点卡片点击调用 NarrativeMapClickRouter
[ ] 可前往节点点击后刷新 node / map / choices / variables
[ ] 当前节点点击只提示“当前节点”
[ ] 已走节点点击只提示“已走过”
[ ] 未开放节点点击只提示“未开放”
```

---

## 3. 下一刀建议

### Step 1：修改 NarrativeDemoController

目标文件：

```text
scripts/narrative/narrative_demo_controller.gd
```

建议修改点：

```text
1. preload scripts/narrative/narrative_map_click_router.gd
2. 将 _build_static_map_node_card 的根控件从 PanelContainer 改为 Button 或包一层 Button
3. Button.pressed.connect(_on_static_map_node_pressed.bind(node_id))
4. 新增 _on_static_map_node_pressed(node_id)
5. 点击后使用 NarrativeMapClickRouter.click_hint 判断提示
6. 只有“可前往”节点调用 NarrativeMapClickRouter.click_node
7. 成功后刷新 _render_node()
```

### Step 2：验收标准

```text
[ ] 点击 ◎ 可达节点能推进到对应节点
[ ] 点击 ○ 未开放节点不推进，只提示
[ ] 点击 ● 已走节点不推进，只提示
[ ] 点击 ▶ 当前节点不推进，只提示
[ ] 推进仍走 NarrativeState.choose_next_node
[ ] requires / delta / flags 仍由原 choice 逻辑处理
```

---

## 4. 给 Codex 的精确指令

```text
请把 NarrativeDemo 的静态分叉地图节点卡片改成可点击控件，并接入 scripts/narrative/narrative_map_click_router.gd。只有 click_hint 为“可前往”的节点允许推进；推进必须调用 NarrativeMapClickRouter.click_node，并最终走 NarrativeState.choose_next_node，不允许绕过 choice / requires / delta / flags 逻辑。当前节点、已走节点、未开放节点点击后只提示，不推进。不要改变 mvp_compressed_narrative.json 的推进逻辑，不要做随机地图生成，不要改 battle_controller，不要改 MainVisual.tscn，不要重构 web_shell.html。
```

---

## 5. 当前一句话结论

```text
地图点击的状态机接口和 Router 已完成；下一步只差把 NarrativeDemo 的节点卡片接成可点击 UI。
```
