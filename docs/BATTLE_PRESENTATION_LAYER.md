# 《大明之沧海嘀鸣》战斗演出层说明

> 版本：v0.7  
> 分支：`main`  
> 状态：Phase 1 已验收通过；Phase 2 / Phase 3 / Phase 5 / Phase 6 / Phase 7 / Phase 8 已接入，待统一本地验收  
> 入口场景：`scenes/MainVisual.tscn`  
> 当前入口脚本：`scripts/battle_controller_visual_presentation_assets.gd`

---

## 1. 目标

当前战斗是回合制卡牌单局，不是实时动作游戏。演出层目标是让结算结果有“武打反馈”，而不是重写动作系统。

当前目标：

```text
确认招式 → 保持旧格位视觉起点 → 角色前冲 / 水墨枪线 / 水墨刀光 / 火器闪光与烟雾 → 目标受击或落空提示 → 防御墨盾 / 聚势气纹 → 真实结算飘字 → 破势墨裂 / 命中停顿 → 平滑落到结算后格位 → 死亡反馈
```

演出层只负责表现，不负责规则。

---

## 2. 当前接入方式

`MainVisual.tscn` 当前挂载：

```text
res://scripts/battle_controller_visual_presentation_assets.gd
```

当前继承链路：

```text
battle_controller_visual_presentation_assets.gd
→ battle_controller_visual_presentation.gd
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

其中：

```text
battle_controller_visual_presentation.gd
```

负责 Phase 1 / 2 / 3 / 5 的节奏、结算反馈和位移表现；

```text
battle_controller_visual_presentation_assets.gd
```

负责 Phase 6 / 7 / 8：把部分 ColorRect 临时 FX 替换为 SVG 资产，加载失败时回退到父类 ColorRect 表现。

---

## 3. 已实现演出

| 阶段 | 演出 | 说明 | 状态 |
|---|---|---|---|
| Phase 1 | 攻击前冲 | 攻击者向目标方向短距离抢步 | `DONE / PASSED` |
| Phase 1 | 攻击回撤 | 攻击后回到当前格位锚点 | `DONE / PASSED` |
| Phase 1 | 枪刺 | `thrust`，使用枪影 / pierce feedback | `DONE / PASSED` |
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
| Phase 3 | 未中反馈 | 未命中不再强制受击闪红，改为灰色掠影和提示 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 5 | 命中停顿 | 根据伤害 / 削势 / 破势追加轻重 hit pause | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 5 | 破势墨裂 | 目标破势时出现墨裂 FX 和“破势”提示 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 5 | 擦中轻反馈 | 擦中降低前冲、击退、震动和 FX 强度 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 5 | 火器反馈 | 根据卡牌名称 / weapon_style 推断火器式，播放火光闪烁 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 6 | 火器 SVG FX | `fx_firearm_flash_ink.svg` 替代 ColorRect 火光 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 6 | 破势 SVG FX | `fx_break_ink_crack.svg` 替代 ColorRect 墨裂 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 6 | 未中 SVG FX | `fx_miss_wisp.svg` 替代 ColorRect 掠影 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 6 | 资源加载回退 | SVG 加载失败时自动回退父类 ColorRect 实现 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 7 | 刀光 SVG FX | `fx_slash_ink_arc.svg` 替代父类刀光表现 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 7 | 枪线 SVG FX | `fx_thrust_ink_line.svg` 替代父类枪线表现 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 7 | 命中点 SVG FX | `fx_hit_ink_burst.svg` 替代父类命中点表现 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 8 | 格挡墨盾 | `fx_guard_ink_shield.svg` 叠加在防御动作上 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 8 | 聚势气纹 | `fx_focus_ink_ripple.svg` 叠加在聚势动作上 | `DONE / NEEDS_LOCAL_VERIFY` |
| Phase 8 | 火器烟雾 | `fx_firearm_smoke_wisp.svg` 跟随火器闪光出现 | `DONE / NEEDS_LOCAL_VERIFY` |

---

## 4. FX 资产

当前 FX 资源：

```text
assets/pixel_battle/fx/fx_firearm_flash_ink.svg
assets/pixel_battle/fx/fx_break_ink_crack.svg
assets/pixel_battle/fx/fx_miss_wisp.svg
assets/pixel_battle/fx/fx_slash_ink_arc.svg
assets/pixel_battle/fx/fx_thrust_ink_line.svg
assets/pixel_battle/fx/fx_hit_ink_burst.svg
assets/pixel_battle/fx/fx_guard_ink_shield.svg
assets/pixel_battle/fx/fx_focus_ink_ripple.svg
assets/pixel_battle/fx/fx_firearm_smoke_wisp.svg
```

包装脚本：

```text
scripts/battle_controller_visual_presentation_assets.gd
```

该脚本当前重写：

```gdscript
_play_guard_presentation()
_play_focus_presentation()
_show_slash_cut()
_show_pierce_line()
_show_target_hit_mark()
_show_presentation_firearm_flash()
_show_miss_wisp()
_play_break_ink_fx()
```

原则：

```text
FX 资产化只替换表现，不改变结算、命中、伤害、势、位移。
```

---

## 5. 动画分类规则

当前按卡牌信息自动推断演出类型：

| 条件 | 演出类型 |
|---|---|
| `card.is_guard_card()` | `guard` |
| `card.is_momentum_card()` 且 `damage <= 0` | `focus` |
| `weapon_style` / `id` / `display_name` 包含火器相关词 | `firearm` |
| `weapon_style` 包含 `枪` 或 `spear` | `thrust` |
| `card.id` 包含 `spear` | `thrust` |
| 其他伤害牌 | `slash` |

当前 `CardData` 还没有显式 `anim` 字段，所以 Phase 4 的数据化暂不强行推进，避免牵动卡牌构建链。后续如果卡牌配置增加 `anim` 字段，应优先读取显式字段，当前规则作为 fallback。

---

## 6. 关键原则

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

## 7. 当前实现入口

### 7.1 玩家确认招式

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

### 7.2 角色位置偏移

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

### 7.3 真实位移平滑化

Phase 2 逻辑：

```text
old_slot → battle state 结算成 new_slot
表现层计算：old_slot_top_left - new_slot_top_left
先把 offset 设为该差值，让角色视觉上仍停在 old_slot
演出完成后 tween offset → Vector2.ZERO
角色平滑落到 new_slot
```

### 7.4 真实结果反馈

Phase 3 逻辑：

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
| `hit` | 正常刀光 / 枪影 / 火器闪光、受击、红色伤害 / 削势飘字 |
| `graze` | 暗化 FX，显示“擦中”，使用实际减半 / 修正后的数值，降低前冲与受击强度 |
| `miss_range` | 灰色 FX，显示“距外”，不播放受击闪红，追加掠影 |
| `miss_facing` | 灰色 FX，显示“背向”，不播放受击闪红，追加掠影 |

### 7.5 节奏精修

Phase 5 逻辑：

```text
轻命中：短暂停顿
重伤 / 重削势：更长停顿
破势：最长停顿 + 墨裂 FX + 破势提示
火器：低前冲 + 火光扩散
终结：更大火光 / 更强震动
```

---

## 8. 统一验收方式

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
3. 用距离过远 / 过近的攻击牌，检查是否出现“距外”，且目标不闪红后退
4. 用背向或朝向错误场景，检查是否出现“背向”
5. 检查防御牌显示“守”或“守+数值”
6. 检查聚势牌显示“势”或“势+数值”
```

### Phase 5 验收

```text
1. 普通命中时确认有轻微 hit pause，但不拖沓
2. 高伤害 / 高削势时确认停顿更明显
3. 打空时确认不会触发目标受击闪红，只出现灰色掠影
4. 擦中时确认反馈弱于正常命中
5. 破势时确认出现墨裂 FX 和“破势”提示
6. 火器类招式若存在，确认表现为火光闪烁，而不是刀光 / 枪影
7. 终结类招式确认震动 / 火光 / 命中停顿略强
```

### Phase 6 / 7 / 8 验收

```text
1. MainVisual.tscn 是否挂载 battle_controller_visual_presentation_assets.gd
2. 火器类招式是否显示水墨火光 SVG，而不是纯方块
3. 火器类招式火光后是否有烟雾 SVG
4. 破势时是否显示墨裂 SVG，而不是纯 ColorRect 线条
5. 未中 / 距外 / 背向时是否显示灰色水墨掠影 SVG
6. 刀类攻击是否显示水墨弧形刀光 SVG
7. 枪类攻击是否显示水墨直线枪影 SVG
8. 正常命中时是否显示水墨命中爆点 SVG
9. 防御牌是否额外显示墨盾 SVG
10. 聚势牌是否额外显示气纹 SVG
11. 如果 SVG 资源加载失败，是否仍能回退到父类 ColorRect 效果，不导致报错中断
```

当前验收状态：

```text
Phase 1: PASSED
Phase 2: NEEDS_LOCAL_VERIFY
Phase 3: NEEDS_LOCAL_VERIFY
Phase 5: NEEDS_LOCAL_VERIFY
Phase 6: NEEDS_LOCAL_VERIFY
Phase 7: NEEDS_LOCAL_VERIFY
Phase 8: NEEDS_LOCAL_VERIFY
```

---

## 9. 下一阶段计划

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

### Phase 9：表现层收口与调参

后续建议进入收口，不继续无限堆 FX：

```text
1. 本地统一验收 Phase 2 / 3 / 5 / 6 / 7 / 8
2. 根据实机观感调整大小、透明度、位置和停顿时间
3. 再决定是否进入 CardData 演出字段数据化
```

---

## 10. 当前最小可维护边界

当前演出层是外层包装脚本，不应下沉到核心战斗规则层。后续如果要扩展，也优先在：

```text
scripts/battle_controller_visual_presentation.gd
scripts/battle_controller_visual_presentation_assets.gd
```

内完成，除非出现必须数据化的需求。
