# 《大明之沧海嘀鸣》战斗演出层说明

> 版本：v0.3  
> 分支：`main`  
> 状态：Phase 1 已验收通过；Phase 2 / Phase 3 已接入，待统一本地验收  
> 入口场景：`scenes/MainVisual.tscn`  
> 入口脚本：`scripts/battle_controller_visual_presentation.gd`

---

## 1. 目标

当前战斗是回合制卡牌单局，不是实时动作游戏。演出层目标是让结算结果有“武打反馈”，而不是重写动作系统。

当前目标：

```text
确认招式 → 保持旧格位视觉起点 → 角色前冲 / 枪刺 / 刀光 → 目标受击或落空提示 → 真实结算飘字 → 平滑落到结算后格位 → 死亡反馈
```

演出层只负责表现，不负责规则。

---

## 2. 当前接入方式

`MainVisual.tscn` 当前挂载：

```text
res://scripts/battle_controller_visual_presentation.gd
```

该脚本继承：

```text
battle_controller_visual_presentation.gd
→ battle_controller_visual_scene_manifest.gd
→ battle_controller_visual_narrative_formal.gd
→ battle_controller_visual_narrative_context.gd
→ battle_controller_visual_break_preview.gd
→ battle_controller_visual_resolver_preview.gd
→ battle_controller_visual_hot_tuning.gd
→ battle_controller_visual_tuning_panel.gd
→ battle_controller_visual_preview_checked.gd
→ battle_controller_visual_responsive_ui.gd
→ battle_controller_visual_cached_ui.gd
→ battle_controller_visual_ui.gd
→ battle_controller_demo_visual.gd
→ battle_controller_core.gd
```

这样做的目的：

```text
只在最外层加表现，不侵入已有战斗结算、AI、背景 manifest、叙事接敌逻辑。
```

---

## 3. 已实现演出

| 阶段 | 演出 | 说明 | 状态 |
|---|---|---|---|
| Phase 1 | 攻击前冲 | 攻击者向目标方向短距离抢步 | `DONE / PASSED` |
| Phase 1 | 攻击回撤 | 攻击后回到当前格位锚点 | `DONE / PASSED` |
| Phase 1 | 枪刺 | `thrust`，使用直线枪影 / pierce feedback | `DONE / PASSED` |
| Phase 1 | 刀击 | `slash`，使用斜向刀光 / slash feedback | `DONE / PASSED` |
| Phase 1 | 防御 | `guard`，角色轻微下沉并闪亮 | `DONE / PASSED` |
| Phase 1 | 聚势 | `focus`，角色轻微压步并出现“势”飘字 | `DONE / PASSED` |
| Phase 1 | 受击 | 目标闪红、后退、回位 | `DONE / PASSED` |
| Phase 1 | 飘字 | 显示伤害与削势文本 | `DONE / PASSED` |
| Phase 1 | 死亡 | 下沉 + 淡出 | `DONE / PASSED` |
| Phase 2 | 旧格位起点保持 | 结算后用 offset 把角色视觉暂时拉回旧格位 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 2 | 真实格位平滑落点 | 从旧格位视觉 offset tween 到新格位锚点 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 3 | range 结果反馈 | 命中、擦中、距外、背向等结果进入飘字和 FX 色彩 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 3 | 真实结算飘字 | 使用 `_ordered_preview_simulation()` 结果显示实际 damage / break / gain | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 3 | 未中反馈 | 未命中不再强制受击闪红，改为灰色“未中”提示 | `DONE / NEEDS_LOCAL_VERIFY` |

---

## 4. 动画分类规则

当前按卡牌信息自动推断演出类型：

| 条件 | 演出类型 |
|---|---|
| `card.is_guard_card()` | `guard` |
| `card.is_momentum_card()` 且 `damage <= 0` | `focus` |
| `weapon_style` 包含 `枪` 或 `spear` | `thrust` |
| `card.id` 包含 `spear` | `thrust` |
| 其他伤害牌 | `slash` |

当前 `CardData` 还没有显式 `anim` 字段，所以 Phase 4 的数据化暂不强行推进，避免牵动卡牌构建链。后续如果卡牌配置增加 `anim` 字段，应优先读取显式字段，当前规则作为 fallback。

---

## 5. 关键原则

必须保持：

```text
战斗结算决定结果
演出层只消费结果 / 意图 / 卡牌信息
```

禁止：

1. 不要让动画决定伤害。
2. 不要在动画层修改 HP / 势 / 卡牌消耗。
3. 不要改 `enemy_manifest.json`。
4. 不要改 `battle_scene_manifest.json`。
5. 不要改叙事 TSV / JSON。
6. 不要新增第二套战斗背景层。
7. 不要恢复旧 Debug 按钮。
8. 不要把背景路径写死到 GDScript。

---

## 6. 当前实现入口

### 6.1 玩家确认招式

入口：

```gdscript
func _confirm_player_intent() -> void
```

当前流程：

```text
记录结算前 player / enemy slot
读取玩家已选卡牌
读取敌方可见意图卡牌
读取结算顺序 _preview_resolution_order
调用 _ordered_preview_simulation() 得到本次预结算结果
启动表现层 _start_presentation_exchange
调用 super() 继续原结算
call_deferred 后表现层读取结算后 slot，并用 offset 保持旧位置视觉起点
```

### 6.2 角色位置偏移

表现层不直接改角色格位，只维护 presentation offset：

```text
player_presentation_offset
enemy_presentation_offset
```

父类真实格位刷新后，表现层将：

```text
真实格位锚点 + presentation offset
```

作为最终显示位置。

### 6.3 真实位移平滑化

Phase 2 新增逻辑：

```text
old_slot → battle state 结算成 new_slot
表现层计算：old_slot_top_left - new_slot_top_left
先把 offset 设为该差值，让角色视觉上仍停在 old_slot
演出完成后 tween offset → Vector2.ZERO
角色平滑落到 new_slot
```

这让“进身、后撤、推开、拉近”等位移牌不再瞬间跳格。

### 6.4 真实结果反馈

Phase 3 新增逻辑：

```text
表现层复用 _ordered_preview_simulation()
按 side 提取 effect step
读取 range / damage / break / gain / guard
根据 range 决定是否播放受击反馈
飘字显示实际结算值，而不是卡牌面板值
```

当前显示规则：

| range | 表现 |
|---|---|
| `hit` | 正常刀光 / 枪影、受击、红色伤害 / 削势飘字 |
| `graze` | 暗化 FX，显示“擦中”，使用实际减半 / 修正后的数值 |
| `miss_range` | 灰色 FX，显示“距外 / 未中”，不播放受击闪红 |
| `miss_facing` | 灰色 FX，显示“背向 / 未中”，不播放受击闪红 |

---

## 7. 统一验收方式

进入：

```text
Main → 进入视觉版战斗
```

### Phase 1 验收

```text
1. 选择枪手或刀客
2. 进入战斗
3. 选择攻击牌并确认
4. 检查攻击者前冲 / 回撤
5. 检查刀光或枪影
6. 检查目标闪红、后退和飘字
7. 检查敌人攻击时是否反向播放
8. 击杀时检查下沉淡出
```

### Phase 2 验收

```text
1. 选择带位移效果的卡牌，例如进身、击退、拉近、后撤类招式
2. 确认结算后角色是否从旧格位平滑滑到新格位
3. 检查不是瞬间跳格
4. 检查攻击前冲仍叠加在旧格位视觉起点上
5. 检查敌方位移同样平滑
```

### Phase 3 验收

```text
1. 用距离正确的攻击牌，检查正常伤害 / 削势飘字
2. 用差 1 格距离的攻击牌，检查是否出现“擦中”，且数值低于正常命中
3. 用距离过远 / 过近的攻击牌，检查是否出现“距外 / 未中”，且目标不闪红后退
4. 用背向或朝向错误场景，检查是否出现“背向 / 未中”
5. 检查防御牌显示“守”或“守+数值”
6. 检查聚势牌显示“势”或“势+数值”
```

当前验收状态：

```text
Phase 1: PASSED
Phase 2: NEEDS_LOCAL_VERIFY
Phase 3: NEEDS_LOCAL_VERIFY
```

---

## 8. 下一阶段计划

### Phase 4：演出数据化

当前暂不推进。原因：`CardData` 尚无显式动画字段。

后续可以在卡牌配置中增加：

```json
"anim": "slash"
```

或：

```json
"animation": {
  "type": "thrust",
  "lunge": 92,
  "hit_pause": 0.08,
  "fx": "pierce_streak"
}
```

落地时需要同步：

```text
1. CardData 增加 anim / animation 字段
2. 卡牌数据源增加配置列
3. 卡牌构建链读取该字段
4. presentation layer 优先读取显式字段，再 fallback 到当前推断规则
```

### Phase 5：演出节奏调优

在 Phase 2 / Phase 3 验收后，可以继续调：

```text
hit pause
镜头震动幅度
受击回弹时间
飘字位置
枪 / 刀 / 火器差异化
```

---

## 9. 当前最小可维护边界

当前演出层是外层包装脚本，不应下沉到核心战斗规则层。后续如果要扩展，也优先在：

```text
scripts/battle_controller_visual_presentation.gd
```

内完成，除非出现必须数据化的需求。
